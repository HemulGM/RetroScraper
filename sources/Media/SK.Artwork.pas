unit SK.Artwork;

interface

uses
  System.SysUtils, System.JSON;

// Base is the persistent user-data directory, independent of CacheFolder.
function PlatformArtwork(const Base: string; SystemID: Integer; const Kind: string;
  Catalog: TJSONObject = nil; const LegacyBase: string = ''): string;
procedure MigratePlatformArtwork(Catalog: TJSONObject; const Base, LegacyBase: string);
function PlatformUpdateDue(const Base: string; NowUTC: TDateTime): Boolean;
procedure RecordPlatformUpdatePrompt(const Base: string; NowUTC: TDateTime);

function RefreshPlatformArtwork(Catalog, Settings, Credentials: TJSONObject; const Base: string; Offline: Boolean = False; Cancel: TFunc<Boolean> = nil; Progress: TProc<Integer, Integer> = nil): Integer;

implementation

uses
  System.Classes, System.IOUtils, System.Hash, System.StrUtils, System.DateUtils, SK.Json,
  SK.ScreenScraper, SK.Storage, SK.Metadata, SK.Catalog, SK.Platform, SK.Cache;

function IndexFile(const Base: string; SystemID: Integer): string;
begin
  Result := TPlatformPath.Combine(Base, 'PlatformArtwork/index/' + SystemID.ToString + '.json');
end;

function ImageFolder(const Base: string): string;
begin
  Result := TPlatformPath.Combine(Base, 'PlatformArtwork/media');
end;

function UpdateStateFile(const Base: string): string;
begin
  Result := TPlatformPath.Combine(Base, 'PlatformArtwork/update.json');
end;

function PlatformUpdateDue(const Base: string; NowUTC: TDateTime): Boolean;
var
  State: TJSONObject;
  Last, Stamp: TDateTime;
  Key: string;
begin
  State := ReadJSON(UpdateStateFile(Base));
  try
    Last := 0;
    for Key in ['lastPromptUTC', 'lastSuccessUTC'] do
      if TryISO8601ToDate(JStr(State, Key), Stamp, True) and (Stamp > Last) then
        Last := Stamp;
    Result := (Last = 0) or (NowUTC >= Last + 14);
  finally
    State.Free;
  end;
end;

procedure RecordUpdateTime(const Base, Key: string; NowUTC: TDateTime);
var
  State: TJSONObject;
  Lock: TObject;
begin
  Lock := SharedResourceLock('platform-update|' + PathKey(Base));
  TMonitor.Enter(Lock);
  try
    State := ReadJSON(UpdateStateFile(Base));
    if State = nil then
      State := TJSONObject.Create;
    try
      JSet(State, Key, TJSONString.Create(DateToISO8601(NowUTC, True)));
      WriteJSON(UpdateStateFile(Base), State);
    finally
      State.Free;
    end;
  finally
    TMonitor.Exit(Lock);
  end;
end;

procedure RecordPlatformUpdatePrompt(const Base: string; NowUTC: TDateTime);
begin
  RecordUpdateTime(Base, 'lastPromptUTC', NowUTC);
end;

function PlatformArtwork(const Base: string; SystemID: Integer; const Kind: string;
  Catalog: TJSONObject; const LegacyBase: string): string;
var
  Obj: TJSONObject;
  Activity: IInterface;
  Entries, Media: TJSONValue;
  MediaType, OldBase: string;
  Lock: TObject;

  function AdoptImage(const Source: string): string;
  var
    Destination: string;
  begin
    Result := '';
    if (Source = '') or not TFile.Exists(Source) then
      Exit;
    if IsPathWithin(Source, ImageFolder(Base)) then
      Exit(Source);
    if not IsPathWithin(Source, TPlatformPath.Combine(OldBase, 'Cache/media')) then
      Exit;
    Destination := TPlatformPath.Combine(ImageFolder(Base), TPath.GetFileName(Source));
    EnsureDirectory(ExtractFilePath(Destination));
    if not TFile.Exists(Destination) then
    begin
      TFile.Copy(Source, Destination + '.tmp', True);
      CommitFile(Destination + '.tmp', Destination);
    end;
    Result := Destination;
  end;

  function CachedImage(Entry: TJSONValue): string;
  var
    URL, Ext, Name: string;
  begin
    Result := '';
    URL := JStr(Entry, 'url');
    Ext := JStr(Entry, 'format', 'png').ToLower;
    if (URL = '') or not MatchText(Ext, ['png', 'jpg', 'jpeg', 'bmp']) then
      Exit;
    Name := THashSHA2.GetHashString(URL) + '.' + Ext;
    Result := AdoptImage(TPlatformPath.Combine(ImageFolder(Base), Name));
    if Result = '' then
      Result := AdoptImage(TPlatformPath.Combine(OldBase, 'Cache/media/' + Name));
  end;

begin
  Result := '';
  OldBase := LegacyBase;
  if OldBase = '' then
    OldBase := Base;
  Activity := CacheActivity(OldBase);
  // Migration and refresh share a lock, including images shared by platforms.
  Lock := SharedResourceLock('platform-artwork|' + PathKey(Base));
  TMonitor.Enter(Lock);
  try
    Obj := ReadJSON(IndexFile(Base, SystemID));
    try
      Result := AdoptImage(JStr(Obj, Kind));
    finally
      Obj.Free;
    end;
    if Result = '' then
    begin
      Obj := ReadJSON(TPlatformPath.Combine(OldBase, 'State/PlatformArtwork/' + SystemID.ToString + '.json'));
      try
        Result := AdoptImage(JStr(Obj, Kind));
      finally
        Obj.Free;
      end;
    end;
    if (Result = '') and (Catalog <> nil) then
    begin
      MediaType := Kind;
      if Kind = 'logo' then
        MediaType := 'logo-monochrome';
      Entries := JValue(CatalogSystem(Catalog, SystemID), 'medias');
      Result := CachedImage(SelectMedia(Entries, MediaType, 'system', '', 'us,eu,jp,wor', '', 0, False));
      if (Result = '') and (Entries is TJSONArray) then
        for Media in TJSONArray(Entries) do
          if SameText(JStr(Media, 'type'), MediaType) or
            ((Kind = 'wheel') and SameText(JStr(Media, 'type'), 'wheel-hd')) then
          begin
            Result := CachedImage(Media);
            if Result <> '' then
              Break;
          end;
    end;
    if Result <> '' then
    begin
      Obj := ReadJSON(IndexFile(Base, SystemID));
      if Obj = nil then
        Obj := TJSONObject.Create;
      try
        if JStr(Obj, Kind) <> Result then
        begin
          JSet(Obj, Kind, TJSONString.Create(Result));
          WriteJSON(IndexFile(Base, SystemID), Obj);
        end;
      finally
        Obj.Free;
      end;
    end;
  finally
    TMonitor.Exit(Lock);
  end;
end;

procedure MigratePlatformArtwork(Catalog: TJSONObject; const Base, LegacyBase: string);
var
  S: TJSONValue;
  Kind: string;
  Activity: IInterface;
begin
  Activity := CacheActivity(LegacyBase);
  if JValue(Catalog, 'systemes') is TJSONArray then
    for S in TJSONArray(JValue(Catalog, 'systemes')) do
      if SelectablePlatform(S) then
        for Kind in ['wheel', 'logo', 'photo', 'icon'] do
          PlatformArtwork(Base, JInt(S, 'id'), Kind, Catalog, LegacyBase);
end;

function RefreshPlatformArtwork(Catalog, Settings, Credentials: TJSONObject; const Base: string; Offline: Boolean; Cancel: TFunc<Boolean>; Progress: TProc<Integer, Integer>): Integer;
const
  Kinds: array[0..3] of string = ('wheel', 'logo', 'photo', 'icon');
  Types: array[0..3] of string = ('wheel', 'logo-monochrome', 'photo', 'icon');
var
  API: TScreenScraper;
  Systems, S, Media: TJSONValue;
  Index: TJSONObject;
  Priority, URL, Ext, FileName, Staging, LegacyBase: string;
  I, Done, Total: Integer;
  Lock: TObject;

  function ValidImage(const Path: string): Boolean;
  var
    Stream: TFileStream;
    Digest: string;
    ExpectedSize: Int64;
  begin
    Result := False;
    if not TFile.Exists(Path) then
      Exit;
    ExpectedSize := StrToInt64Def(JStr(Media, 'size'), 0);
    if (TFile.GetSize(Path) = 0) or
      ((ExpectedSize > 0) and (TFile.GetSize(Path) <> ExpectedSize)) then
      Exit;
    Digest := JStr(Media, 'md5');
    if Digest <> '' then
    begin
      Stream := TFileStream.Create(Path, fmOpenRead or fmShareDenyWrite);
      try
        if not SameText(THashMD5.GetHashString(Stream), Digest) then
          Exit;
      finally
        Stream.Free;
      end;
    end;
    Result := True;
  end;

  procedure AcquireImage;
  var
    Attempt: Integer;
  begin
    FileName := TPlatformPath.Combine(ImageFolder(Base), THashSHA2.GetHashString(URL) + '.' + Ext);
    if not ValidImage(FileName) then
    begin
      // Keep the previous image and index usable if download or validation fails.
      Staging := FileName + '.refresh';
      try
        for Attempt := 0 to 1 do
        begin
          if TFile.Exists(Staging) then
            TFile.Delete(Staging);
          API.Download(URL, Staging);
          if ValidImage(Staging) then
            Break;
        end;
        if not ValidImage(Staging) then
          raise EScreenScraper.Create('Platform image checksum or size mismatch');
        CommitFile(Staging, FileName);
      finally
        if TFile.Exists(Staging) then
          TFile.Delete(Staging);
      end;
    end;
    JSet(Index, Kinds[I], TJSONString.Create(FileName));
    Inc(Result);
  end;

begin
  Result := 0;
  Done := 0;
  Total := 0;
  Systems := JValue(Catalog, 'systemes');
  if not (Systems is TJSONArray) then
    Exit;
  for S in TJSONArray(Systems) do
    if SelectablePlatform(S) then
      Inc(Total, Length(Kinds));
  Priority := JoinValues(Settings, 'Miscellaneous.Regions', 'us,eu,jp,wor');
  LegacyBase := CacheBase(Settings);
  if LegacyBase = '' then
    LegacyBase := Base;
  API := TScreenScraper.Create(Credentials, CacheLocation(Settings, 'Cache/api'));
  try
    API.Offline := Offline;
    API.IsCancelled := Cancel;
    for S in TJSONArray(Systems) do
    begin
      if not SelectablePlatform(S) then
        Continue;
      for I := 0 to High(Kinds) do
      begin
        if Assigned(Cancel) and Cancel() then
          raise EAbort.Create('Cancelled');
        PlatformArtwork(Base, JInt(S, 'id'), Kinds[I], Catalog, LegacyBase);
      end;
      Lock := SharedResourceLock('platform-artwork|' + PathKey(Base));
      while not TMonitor.Enter(Lock, 100) do
        if Assigned(Cancel) and Cancel() then
          raise EAbort.Create('Cancelled');
      try
        Index := ReadJSON(IndexFile(Base, JInt(S, 'id')));
        if Index = nil then
          Index := TJSONObject.Create;
        try
          for I := 0 to High(Kinds) do
          begin
            if Assigned(Cancel) and Cancel() then
              raise EAbort.Create('Cancelled');
            Media := SelectMedia(JValue(S, 'medias'), Types[I], 'system', '', Priority, '', 0, False);
            if Media <> nil then
            begin
              URL := JStr(Media, 'url');
              Ext := JStr(Media, 'format', 'png').ToLower;
              if (URL <> '') and MatchText(Ext, ['png', 'jpg', 'jpeg', 'bmp']) then
                AcquireImage;
            end;
            Inc(Done);
            if Assigned(Progress) then
              Progress(Done, Total);
          end;
          WriteJSON(IndexFile(Base, JInt(S, 'id')), Index);
        finally
          Index.Free;
        end;
      finally
        TMonitor.Exit(Lock);
      end;
    end;
    if (Total > 0) and not Offline then
      RecordUpdateTime(Base, 'lastSuccessUTC', TTimeZone.Local.ToUniversalTime(Now));
  finally
    API.Free;
  end;
end;

end.
