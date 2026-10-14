unit SK.Cache;

interface

uses
  System.SysUtils, System.JSON;

procedure RegisterCacheFile(const Base: string; SystemID: Integer; const Kind, Path: string);

function MediaCacheEpoch(const Base: string; SystemID: Integer): string;

procedure ClearSystemCache(const Base: string; Config: TJSONObject; SystemID: Integer; Information, Media: Boolean; Progress: TProc<Integer, Integer> = nil);

implementation

uses
  System.Classes, System.IOUtils, System.Hash, System.Generics.Collections,
  SK.Core, SK.Platform, SK.Catalog;

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
  if not AllowedCachePath(Base, Path, Kind) or not TFile.Exists(Path) then
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
  if TFile.Exists(Path) then
    TFile.Delete(Path);
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
begin
  if not Information and not Media then
    Exit;
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
    for Folder in ['Cache/api', 'Cache/hashes', 'Cache/media', 'Sources/media', 'State/MediaSources'] do
      if ((Information and (Folder = 'Cache/api')) or
        (Information and Media and (Folder = 'Cache/hashes')) or
        (Media and ((Folder = 'Cache/media') or (Folder = 'Sources/media') or (Folder = 'State/MediaSources')))) and
        TDirectory.Exists(TPlatformPath.Combine(Base, Folder)) then
      begin
        // Only files inside explicitly known cache directories; never follow directory links.
        for Path in TDirectory.GetFiles(TPlatformPath.Combine(Base, Folder)) do
          TFile.Delete(Path);
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

end.

