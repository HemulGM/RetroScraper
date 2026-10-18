unit SK.Cache;

interface

uses
  System.SysUtils, System.JSON;

// Empty CacheFolder means no persistent cache. Work files are session-scoped.
function CacheBase(Config: TJSONObject): string;
function CacheLocation(Config: TJSONObject; const Relative: string): string;
function CacheWorkBase(Config: TJSONObject): string;
procedure ValidateCacheFolder(const Folder: string);
function CacheLimitBytes(Config: TJSONObject): Int64;
procedure ApplyCachePolicy(Config: TJSONObject);
// A lease protects cache files for the duration of an operation.
function CacheActivity(const Path: string): IInterface;
function TrimCacheToLimit(const Base: string; LimitBytes: Int64): Int64;

procedure RegisterCacheFile(const Base: string; SystemID: Integer; const Kind, Path: string);

function MediaCacheEpoch(const Base: string; SystemID: Integer): string;

procedure ClearSystemCache(const Base: string; Config: TJSONObject; SystemID: Integer; Information, Media: Boolean; Progress: TProc<Integer, Integer> = nil);

implementation

uses
  System.Classes, System.IOUtils, System.Hash, System.Generics.Collections,
  SK.Json, SK.Storage, SK.Platform, SK.Catalog, System.SyncObjs,
  System.Generics.Defaults;

type
  TCachePolicy = class
    Root: string;
    Limit: Int64;
    Active: Integer;
    Dirty, Enabled: Boolean;
    NextCheck: UInt64;
    Pins: TDictionary<string, Integer>;
    constructor Create;
    destructor Destroy; override;
  end;

  TCacheCandidate = record
    Path: string;
    Size: Int64;
    Age: TDateTime;
  end;

  TCacheActivity = class(TInterfacedObject)
  private
    FKey, FPath: string;
  public
    constructor Create(const Key, Path: string);
    destructor Destroy; override;
  end;

var
  PolicyGuard: TObject;
  Policies: TObjectDictionary<string, TCachePolicy>;
  MaintenanceWake: TEvent;
  MaintenanceThread: TThread;
  MaintenanceStopping: Boolean;

function CacheLimitBytes(Config: TJSONObject): Int64;
var
  GB: Integer;
begin
  GB := JInt(Config, 'CacheLimitGB', 10);
  if (GB < 0) or (GB > 1048576) then
    GB := 10;
  Result := Int64(GB) * 1024 * 1024 * 1024;
end;

constructor TCachePolicy.Create;
begin
  inherited;
  Pins := TDictionary<string, Integer>.Create;
end;

destructor TCachePolicy.Destroy;
begin
  Pins.Free;
  inherited;
end;

constructor TCacheActivity.Create(const Key, Path: string);
begin
  inherited Create;
  FKey := Key;
  FPath := Path;
end;

destructor TCacheActivity.Destroy;
var
  Policy: TCachePolicy;
  Count: Integer;
begin
  if PolicyGuard <> nil then
  begin
    TMonitor.Enter(PolicyGuard);
    try
      if Policies.TryGetValue(FKey, Policy) then
      begin
        Dec(Policy.Active);
        if Policy.Pins.TryGetValue(FPath, Count) then
          if Count <= 1 then Policy.Pins.Remove(FPath)
          else Policy.Pins[FPath] := Count - 1;
        if not MaintenanceStopping then
          MaintenanceWake.SetEvent;
      end;
    finally
      TMonitor.Exit(PolicyGuard);
    end;
  end;
  inherited;
end;

function CacheActivity(const Path: string): IInterface;
var
  Pair: TPair<string, TCachePolicy>;
  Key, Pin: string;
  Count: Integer;
begin
  Result := nil;
  if Path = '' then
    Exit;
  Key := '';
  TMonitor.Enter(PolicyGuard);
  try
    for Pair in Policies do
      if Pair.Value.Enabled and
        (SamePath(Path, Pair.Value.Root) or IsPathWithin(Path, Pair.Value.Root)) and
        (Length(Pair.Key) > Length(Key)) then
        Key := Pair.Key;
    if Key <> '' then
    begin
      Inc(Policies[Key].Active);
      Pin := PathKey(Path);
      if not Policies[Key].Pins.TryGetValue(Pin, Count) then
        Count := 0;
      Policies[Key].Pins.AddOrSetValue(Pin, Count + 1);
      Result := TCacheActivity.Create(Key, Pin);
    end;
  finally
    TMonitor.Exit(PolicyGuard);
  end;
end;

function CacheFilePinned(Policy: TCachePolicy; const Path: string): Boolean;
var
  Pair: TPair<string, Integer>;
begin
  Result := False;
  for Pair in Policy.Pins do
    if SamePath(Path, Pair.Key) or IsPathWithin(Path, Pair.Key) then
      Exit(True);
end;

function ManagedCachePath(const Base, Path: string): Boolean;
var
  Folder, Root: string;
begin
  Result := False;
  for Folder in ['Cache', 'Sources/media', 'State/CacheOwners',
    'State/CacheInvalidations', 'State/MediaSources', 'State/PlatformArtwork'] do
  begin
    Root := TPlatformPath.Combine(Base, Folder);
    if IsPathWithin(Path, Root) then
      Exit(True);
  end;
end;

procedure CacheChanged(const Path: string);
var
  Pair: TPair<string, TCachePolicy>;
begin
  TMonitor.Enter(PolicyGuard);
  try
    if MaintenanceStopping then
      Exit;
    for Pair in Policies do
      if Pair.Value.Enabled and ManagedCachePath(Pair.Value.Root, Path) then
        Pair.Value.Dirty := True;
    MaintenanceWake.SetEvent;
  finally
    TMonitor.Exit(PolicyGuard);
  end;
end;

function TrimCacheToLimit(const Base: string; LimitBytes: Int64): Int64;
var
  Pending: TStack<string>;
  Candidates: TList<TCacheCandidate>;
  Folder, Path, Key: string;
  Candidate: TCacheCandidate;
  Total: Int64;
  Policy: TCachePolicy;
  Lock: TObject;
  Interrupted: Boolean;
begin
  Result := 0;
  if (Base = '') or (LimitBytes <= 0) or not TDirectory.Exists(Base) then
    Exit;
  CheckWritablePath(Base);
  Key := PathKey(Base);
  Lock := SharedResourceLock('cache-budget|' + Key);
  TMonitor.Enter(Lock);
  try
    Pending := TStack<string>.Create;
    Candidates := TList<TCacheCandidate>.Create;
    try
      for Folder in ['Cache', 'Sources/media', 'State/CacheOwners',
        'State/CacheInvalidations', 'State/MediaSources', 'State/PlatformArtwork'] do
      begin
        Path := TPlatformPath.Combine(Base, Folder);
        if TDirectory.Exists(Path) and not DirectoryLink(Path) then
          Pending.Push(Path);
      end;
      Total := 0;
      while Pending.Count > 0 do
      begin
        if MaintenanceStopping then
          Exit;
        Folder := Pending.Pop;
        try
          for Path in TDirectory.GetDirectories(Folder) do
            if not DirectoryLink(Path) then
              Pending.Push(Path);
          for Path in TDirectory.GetFiles(Folder) do
            if not DirectoryLink(Path) then
            try
              if MaintenanceStopping then
                Exit;
              Candidate.Path := Path;
              Candidate.Size := TFile.GetSize(Path);
              Candidate.Age := TFile.GetLastWriteTimeUtc(Path);
              Inc(Total, Candidate.Size);
              // Incomplete downloads/writes are not eviction candidates.
              if not Path.EndsWith('.part', True) and not Path.EndsWith('.tmp', True) then
                Candidates.Add(Candidate);
            except
              on E: Exception do ;
            end;
        except
          on E: Exception do ;
        end;
      end;
      if Total <= LimitBytes then
        Exit;
      Candidates.Sort(TComparer<TCacheCandidate>.Construct(
        function(const A, B: TCacheCandidate): Integer
        begin
          if A.Age < B.Age then Result := -1
          else if A.Age > B.Age then Result := 1
          else Result := CompareText(A.Path, B.Path);
        end));
      Interrupted := False;
      for Candidate in Candidates do
      begin
        if (Total <= LimitBytes) or MaintenanceStopping then
          Break;
        // An operation can begin while the filesystem is being scanned.
        // Serialize each delete with lease acquisition, never with the full scan.
        TMonitor.Enter(PolicyGuard);
        try
          if Policies.TryGetValue(Key, Policy) and (not Policy.Enabled or (Policy.Limit = 0)) then
            Break;
          if Policies.TryGetValue(Key, Policy) and CacheFilePinned(Policy, Candidate.Path) then
          begin
            Policy.Dirty := True;
            Interrupted := True;
            Continue;
          end;
          try
            CheckWritablePath(Candidate.Path);
            if TFile.Exists(Candidate.Path) and
              (TFile.GetLastWriteTimeUtc(Candidate.Path) = Candidate.Age) then
            begin
              TFile.Delete(Candidate.Path);
              Dec(Total, Candidate.Size);
              Inc(Result, Candidate.Size);
            end;
          except
            // Locked/inaccessible files must not prevent trying other old entries.
            on E: Exception do ;
          end;
        finally
          TMonitor.Exit(PolicyGuard);
        end;
      end;
      if Interrupted then
        MaintenanceWake.SetEvent;
    finally
      Candidates.Free;
      Pending.Free;
    end;
  finally
    TMonitor.Exit(Lock);
  end;
end;

procedure MaintainCaches;
var
  Work: TList<TPair<string, Int64>>;
  Pair: TPair<string, TCachePolicy>;
  Item: TPair<string, Int64>;
begin
  Work := TList<TPair<string, Int64>>.Create;
  try
    while not MaintenanceStopping do
    begin
      MaintenanceWake.WaitFor(1000);
      Work.Clear;
      TMonitor.Enter(PolicyGuard);
      try
        for Pair in Policies do
          if Pair.Value.Enabled and Pair.Value.Dirty and (Pair.Value.Limit > 0) and
            (TThread.GetTickCount64 >= Pair.Value.NextCheck) then
          begin
            Pair.Value.Dirty := False;
            // Batch disk scans during downloads instead of scanning on each write.
            Pair.Value.NextCheck := TThread.GetTickCount64 + 30000;
            Work.Add(TPair<string, Int64>.Create(Pair.Value.Root, Pair.Value.Limit));
          end;
      finally
        TMonitor.Exit(PolicyGuard);
      end;
      for Item in Work do
        try
          TrimCacheToLimit(Item.Key, Item.Value);
        except
          // Cache housekeeping must never terminate scraping or the UI thread.
          on E: Exception do ;
        end;
    end;
  finally
    Work.Free;
  end;
end;

procedure ApplyCachePolicy(Config: TJSONObject);
var
  Root, Key: string;
  Policy: TCachePolicy;
  Pair: TPair<string, TCachePolicy>;
  NewLimit: Int64;
  Changed: Boolean;
begin
  Root := CacheBase(Config);
  Key := '';
  if Root <> '' then
    Key := PathKey(Root);
  TMonitor.Enter(PolicyGuard);
  try
    for Pair in Policies do
      if Pair.Key <> Key then
      begin
        Pair.Value.Enabled := False;
        Pair.Value.Limit := 0;
        Pair.Value.Dirty := False;
      end;
    if Key = '' then
      Exit;
    if not Policies.TryGetValue(Key, Policy) then
    begin
      Policy := TCachePolicy.Create;
      Policy.Root := Root;
      Policies.Add(Key, Policy);
    end;
    NewLimit := CacheLimitBytes(Config);
    Changed := not Policy.Enabled or (Policy.Limit <> NewLimit);
    Policy.Enabled := True;
    Policy.Limit := NewLimit;
    if Changed then
    begin
      Policy.Dirty := True;
      Policy.NextCheck := 0;
    end;
    if MaintenanceThread = nil then
    begin
      MaintenanceThread := TThread.CreateAnonymousThread(MaintainCaches);
      MaintenanceThread.FreeOnTerminate := False;
      MaintenanceThread.Start;
    end;
    MaintenanceWake.SetEvent;
  finally
    TMonitor.Exit(PolicyGuard);
  end;
end;

procedure ValidateCacheFolder(const Folder: string);
begin
  if Folder.Trim = '' then
    Exit;
  if not TPath.IsPathRooted(NativePath(Folder.Trim)) then
    raise EArgumentException.Create('Select an absolute cache folder');
  CheckWritablePath(Folder.Trim);
end;

function CacheBase(Config: TJSONObject): string;
begin
  Result := JStr(Config, 'CacheFolder').Trim;
  if Result = '' then
    Exit;
  ValidateCacheFolder(Result);
  Result := TPath.GetFullPath(NativePath(Result));
end;

function CacheLocation(Config: TJSONObject; const Relative: string): string;
begin
  Result := CacheBase(Config);
  if Result <> '' then
    Result := TPlatformPath.Combine(Result, Relative);
end;

function CacheWorkBase(Config: TJSONObject): string;
begin
  Result := CacheBase(Config);
  if Result = '' then
    Result := SessionTemporaryBase;
end;

function OwnerFolder(const Base: string): string;
begin
  Result := TPlatformPath.Combine(Base, 'State/CacheOwners')
end;

function AllowedCachePath(const Base, Path, Kind: string): Boolean;
begin
  Result := ((Kind = 'api') and IsPathWithin(Path, TPlatformPath.Combine(Base, 'Cache/api'))) or
    ((Kind = 'hashes') and IsPathWithin(Path, TPlatformPath.Combine(Base, 'Cache/hashes'))) or
    ((Kind = 'media') and (IsPathWithin(Path, TPlatformPath.Combine(Base, 'Cache/media')) or
    IsPathWithin(Path, TPlatformPath.Combine(Base, 'Sources/media')))) or
    ((Kind = 'source-index') and IsPathWithin(Path, TPlatformPath.Combine(Base, 'State/MediaSources')));
end;

procedure RegisterCacheFile(const Base: string; SystemID: Integer; const Kind, Path: string);
var
  FileName: string;
  Lock: TObject;
  Obj: TJSONObject;
  A: TJSONArray;
  V: TJSONValue;
  Found: Boolean;
begin
  if (Base = '') or not AllowedCachePath(Base, Path, Kind) or not TFile.Exists(Path) then
    Exit;
  FileName := TPlatformPath.Combine(OwnerFolder(Base), THashSHA2.GetHashString(PathKey(Path)) + '.json');
  Lock := SharedResourceLock('cache-owner|' + PathKey(FileName));
  TMonitor.Enter(Lock);
  try
    Obj := ReadJSON(FileName);
    if Obj = nil then
      Obj := TJSONObject.Create;
    try
      if not (JValue(Obj, 'systems') is TJSONArray) then
        JSet(Obj, 'systems', TJSONArray.Create);
      A := TJSONArray(JValue(Obj, 'systems'));
      Found := False;
      for V in A do
        if StrToIntDef(V.Value, -1) = SystemID then
          Found := True;
      if Found then
        Exit;
      A.Add(SystemID);
      JSet(Obj, 'path', TJSONString.Create(Path));
      JSet(Obj, 'kind', TJSONString.Create(Kind));
      WriteJSON(FileName, Obj);
    finally
      Obj.Free
    end;
  finally
    TMonitor.Exit(Lock)
  end;
end;

function MediaCacheEpoch(const Base: string; SystemID: Integer): string;
var
  Obj: TJSONObject;
  Global: string;
begin
  Obj := ReadJSON(TPlatformPath.Combine(Base, 'State/CacheInvalidations/all.json'));
  try
    Global := JStr(Obj, 'media')
  finally
    Obj.Free
  end;
  Obj := ReadJSON(TPlatformPath.Combine(Base, 'State/CacheInvalidations/' + SystemID.ToString + '.json'));
  try
    Result := JStr(Obj, 'media')
  finally
    Obj.Free
  end;
  if Global <> '' then
    Result := Global + '|' + Result;
end;

procedure DiscoverLegacy(const Base: string; Config: TJSONObject);
var
  Files: TArray<string>;
  FileName, Root, Path, Key, Ext: string;
  Response, Source: TJSONObject;
  S, M: TJSONValue;
  Pair: TJSONPair;
  IDs: TArray<Integer>;
  ID, Actual: Integer;
  Pending: TStack<string>;
  Folders: TArray<string>;
begin
  // Index older releases without modifying their gamelists or output media.
  if TDirectory.Exists(TPlatformPath.Combine(Base, 'Cache/api')) then
  begin
    Files := TDirectory.GetFiles(TPlatformPath.Combine(Base, 'Cache/api'), '*.json');
    for FileName in Files do
    begin
      Response := ReadJSON(FileName);
      try
        Actual := JInt(Response, 'response.jeu.systeme.id');
        if Actual <= 0 then
          Continue;
        if JValue(Config, 'Systems') is TJSONArray then
          for S in TJSONArray(JValue(Config, 'Systems')) do
          begin
            IDs := PlatformIDs(S as TJSONObject);
            for ID in IDs do
              if ID = Actual then
              begin
                RegisterCacheFile(Base, JInt(S, 'SystemId'), 'api', FileName);
                if JValue(Response, 'response.jeu.medias') is TJSONArray then
                  for M in TJSONArray(JValue(Response, 'response.jeu.medias')) do
                  begin
                    Key := THashSHA2.GetHashString(JStr(M, 'url'));
                    Ext := JStr(M, 'format', 'png').ToLower;
                    RegisterCacheFile(Base, JInt(S, 'SystemId'), 'media', TPlatformPath.Combine(Base, 'Cache/media/' + Key + '.' + Ext));
                    RegisterCacheFile(Base, JInt(S, 'SystemId'), 'media', TPlatformPath.Combine(Base, 'Sources/media/' + Key + '.' + Ext));
                  end;
                Break;
              end;
          end;
      finally
        Response.Free
      end;
    end;
  end;
  if not (JValue(Config, 'Systems') is TJSONArray) then
    Exit;
  for S in TJSONArray(JValue(Config, 'Systems')) do
  begin
    Root := JStr(S, 'GamesAndRoms.Path');
    if (Root = '') or not TDirectory.Exists(Root) then
      Continue;
    Pending := TStack<string>.Create;
    try
      Pending.Push(Root);
      while Pending.Count > 0 do
      begin
        Path := Pending.Pop;
        try
          Files := TDirectory.GetFiles(Path);
          Folders := TDirectory.GetDirectories(Path);
        except
          // Recorded cache owners remain usable when an old ROM root is inaccessible.
          on E: Exception do
            Continue;
        end;
        for Root in Folders do
          if not DirectoryLink(Root) and not HiddenEntry(Root) then
            Pending.Push(Root);
        // Composite inputs use the directory itself as the source-index identity.
        SetLength(Files, Length(Files) + 1);
        Files[High(Files)] := Path;
        for Path in Files do
        begin
          Key := THashSHA2.GetHashString(PathKey(Path));
          RegisterCacheFile(Base, JInt(S, 'SystemId'), 'hashes', TPlatformPath.Combine(Base, 'Cache/hashes/' + Key + '.json'));
          FileName := TPlatformPath.Combine(Base, 'State/MediaSources/' + Key + '.json');
          Source := ReadJSON(FileName);
          if Source = nil then
            Continue;
          try
            RegisterCacheFile(Base, JInt(S, 'SystemId'), 'source-index', FileName);
            for Pair in Source do
              RegisterCacheFile(Base, JInt(S, 'SystemId'), 'media', JStr(Pair.JsonValue, 'path'));
          finally
            Source.Free
          end;
        end;
      end;
    finally
      Pending.Free
    end;
  end;
end;

procedure DeleteCachedFile(const Path: string);
begin
  CheckWritablePath(Path);
  if TFile.Exists(Path) then
  begin
    TFile.Delete(Path);
    NotifyCacheFileChanged(Path);
  end;
  if TFile.Exists(Path + '.bak') then
    TFile.Delete(Path + '.bak');
end;

procedure ClearSystemCache(const Base: string; Config: TJSONObject; SystemID: Integer; Information, Media: Boolean; Progress: TProc<Integer, Integer>);
var
  Files: TArray<string>;
  FileName, Kind, Path, Folder: string;
  Obj: TJSONObject;
  A: TJSONArray;
  I, J: Integer;
  Selected, Relevant: Boolean;
  Activity: IInterface;
begin
  if (Base = '') or (not Information and not Media) then
    Exit;
  CheckWritablePath(Base);
  Activity := CacheActivity(Base);
  DiscoverLegacy(Base, Config);
  Files := nil;
  if TDirectory.Exists(OwnerFolder(Base)) then
    Files := TDirectory.GetFiles(OwnerFolder(Base), '*.json');
  for I := 0 to High(Files) do
  begin
    FileName := Files[I];
    Obj := ReadJSON(FileName);
    try
      Kind := JStr(Obj, 'kind');
      Path := JStr(Obj, 'path');
      Relevant := (Information and ((Kind = 'api') or ((Kind = 'hashes') and Media))) or
        (Media and ((Kind = 'media') or (Kind = 'source-index')));
      if Relevant and AllowedCachePath(Base, Path, Kind) and (JValue(Obj, 'systems') is TJSONArray) then
      begin
        A := TJSONArray(JValue(Obj, 'systems'));
        Selected := SystemID = 0;
        for J := A.Count - 1 downto 0 do
          if (SystemID = 0) or (StrToIntDef(A.Items[J].Value, -1) = SystemID) then
          begin
            A.Remove(J).Free;
            Selected := True
          end;
        if Selected then
          if A.Count = 0 then
          begin
            DeleteCachedFile(Path);
            DeleteCachedFile(FileName)
          end
          else
            WriteJSON(FileName, Obj);
      end;
    finally
      Obj.Free
    end;
    if Assigned(Progress) then
      Progress(I + 1, Length(Files));
  end;
  // Global scope includes unindexed leftovers and the catalogue's API cache.
  if SystemID = 0 then
    for Folder in ['Cache/api', 'Cache/hashes', 'Cache/media', 'Sources/media', 'State/MediaSources', 'Cache/preview', 'State/PlatformArtwork'] do
      if ((Information and (Folder = 'Cache/api')) or
        (Information and Media and (Folder = 'Cache/hashes')) or
        (Media and ((Folder = 'Cache/media') or (Folder = 'Sources/media') or (Folder = 'State/MediaSources') or (Folder = 'Cache/preview') or (Folder = 'State/PlatformArtwork')))) and
        TDirectory.Exists(TPlatformPath.Combine(Base, Folder)) then
      begin
        // Only files inside explicitly known cache directories; never follow directory links.
        CheckWritablePath(TPlatformPath.Combine(Base, Folder));
        for Path in TDirectory.GetFiles(TPlatformPath.Combine(Base, Folder)) do
        begin
          CheckWritablePath(Path);
          TFile.Delete(Path);
          NotifyCacheFileChanged(Path);
        end;
      end;
  if Media then
  begin
    Obj := TJSONObject.Create;
    try
      Obj.AddPair('media', TGUID.NewGuid.ToString);
      if SystemID > 0 then
        WriteJSON(TPlatformPath.Combine(Base, 'State/CacheInvalidations/' + SystemID.ToString + '.json'), Obj)
      else
        WriteJSON(TPlatformPath.Combine(Base, 'State/CacheInvalidations/all.json'), Obj);
    finally
      Obj.Free
    end;
  end;
  if Assigned(Progress) then
    Progress(Length(Files), Length(Files));
end;

initialization
  PolicyGuard := TObject.Create;
  Policies := TObjectDictionary<string, TCachePolicy>.Create([doOwnsValues]);
  MaintenanceWake := TEvent.Create(nil, False, False, '');
  CacheFileActivity := function(Path: string): IInterface
    begin
      Result := CacheActivity(Path);
    end;
  CacheFileChanged := procedure(Path: string)
    begin
      CacheChanged(Path);
    end;

finalization
  CacheFileChanged := nil;
  CacheFileActivity := nil;
  MaintenanceStopping := True;
  MaintenanceWake.SetEvent;
  if MaintenanceThread <> nil then
  begin
    MaintenanceThread.WaitFor;
    MaintenanceThread.Free;
  end;
  Policies.Free;
  MaintenanceWake.Free;
  FreeAndNil(PolicyGuard);

end.
