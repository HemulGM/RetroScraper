unit SK.Engine;

interface

uses
  System.SysUtils, System.Classes, System.JSON, System.IOUtils, System.Hash,
  System.Generics.Collections, System.SyncObjs, System.Zip, System.StrUtils,
  SK.Scrape.Types, Xml.XMLDoc, Xml.XMLIntf, SK.Platform, SK.Json,
  SK.ScreenScraper, SK.Storage, SK.Scenarios;

type
  TEngineStatus = SK.Scrape.Types.TEngineStatus;

  TInputQueue = SK.Scrape.Types.TInputQueue;

  TScrapeStatus = SK.Scrape.Types.TScrapeStatus;

  TResumePlatform = class
  public
    Inputs: TArray<string>;
    Completed, Produced, CleanupRoots: TDictionary<string, Boolean>;
    Results: TObjectList<TJSONObject>;
    Missing: TStringList;
    Saved: Boolean;
    constructor Create;
    destructor Destroy; override;
    function Clone: TResumePlatform;
  end;

  TScrapeWorker = class(TThread)
  private
    FScenario: TScenarioRequest;
    FConfig, FCredentials, FSystemCatalog: TJSONObject;
    FBase, FCacheBase, FWorkBase: string;
    FTargetRom: string;
    FLogFile: string;
    FSelected, FPreviewSlot: Integer;
    FPreviewRevision: Int64;
    FLock: TObject;
    FLog: TStringList;
    FStatus: TScrapeStatus;
    FAPI: TScreenScraper;
    FNetworkQueue: TScreenScraperNetworkQueue;
    FOwnsNetworkQueue: Boolean;
    FEngineLimit: Integer;
    FQuotaTick: UInt64;
    FOffline: Boolean;
    FPlanReady: Boolean;
    FVerbose: Boolean;
    FQueue: TInputQueue;
    FTaskSystem: TJSONObject;
    FResults: TObjectList<TJSONObject>;
    FMissing: TStringList;
    FScanned: TDictionary<string, TArray<string>>;
    FResumePlatforms: TObjectDictionary<string, TResumePlatform>;
    FCompletedInputs: TDictionary<string, Boolean>;
    FPreviewFiles: TList<string>;
    FNextPreviewTick: UInt64;
    FProduced: TDictionary<string, Boolean>;
    FCleanupRoots: TDictionary<string, Boolean>;
    function HasPendingWork: Boolean;
    function ResumeInputs(Sys: TJSONObject): TArray<string>;
    procedure PrepareTargetSystem(Sys: TJSONObject);
    function FilterNewInputs(Sys: TJSONObject; const Files: TArray<string>): TArray<string>;
    procedure CaptureQuota(User: TJSONObject);
    procedure RefreshQuota;
    procedure LockResource(Lock: TObject);
    procedure QueuePreview(const FileName: string);
    procedure RunInputQueue(Sys: TJSONObject);
    procedure PublishImage(const FileName: string);
    procedure SetStage(const Value: string);
    procedure SaveMediaIndex(Sys: TJSONObject; const Doc: IXMLDocument; AllowCleanup: Boolean);
    procedure Log(const S: string);
    procedure Trace(const S: string);
    procedure ScrapeSystem(Sys: TJSONObject);
    function FetchMedia(Game: TJSONObject; Sys: TJSONObject; const RomFile: string; Node: IXMLNode): Integer;
  protected
    procedure Execute; override;
    procedure DoTerminate; override;
  public
    constructor Create(Config, Credentials: TJSONObject; const Base: string; Selected: Integer; Offline: Boolean = False; OfflineEngines: Integer = 1; const TargetRom: string = ''; NetworkQueue: TScreenScraperNetworkQueue = nil);
    destructor Destroy; override;
    procedure Snapshot(out Status: TScrapeStatus; Lines: TStrings);
    function CreateContinuation(Credentials: TJSONObject = nil; NetworkQueue: TScreenScraperNetworkQueue = nil): TScrapeWorker;
  end;

procedure HashStream(Stream: TStream; out CRC, MD5, SHA1: string; Cancel: TFunc<Boolean> = nil);

implementation

uses
  SK.Xml, SK.Consts, SK.Input, System.RegularExpressions, System.Math,
  System.Generics.Defaults, System.DateUtils, System.Types, System.Variants,
  SK.Mix, SK.GameList, SK.Metadata, SK.Output, SK.Frontend, SK.Cache, SK.Catalog,
  SK.Locale, FMX.Graphics;

constructor TResumePlatform.Create;
begin
  inherited;
  Completed := TDictionary<string, Boolean>.Create;
  Produced := TDictionary<string, Boolean>.Create;
  CleanupRoots := TDictionary<string, Boolean>.Create;
  Results := TObjectList<TJSONObject>.Create(True);
  Missing := TStringList.Create;
end;

destructor TResumePlatform.Destroy;
begin
  Missing.Free;
  Results.Free;
  Completed.Free;
  Produced.Free;
  CleanupRoots.Free;
  inherited;
end;

function TResumePlatform.Clone: TResumePlatform;
var
  Key: string;
  Item: TJSONObject;
begin
  Result := TResumePlatform.Create;
  try
    Result.Inputs := Copy(Inputs);
    Result.Saved := Saved;
    for Key in Completed.Keys do Result.Completed.Add(Key, True);
    for Key in Produced.Keys do Result.Produced.Add(Key, True);
    for Key in CleanupRoots.Keys do Result.CleanupRoots.Add(Key, True);
    for Item in Results do Result.Results.Add(Item.Clone as TJSONObject);
    Result.Missing.Assign(Missing);
  except
    Result.Free;
    raise;
  end;
end;

function TScrapeWorker.HasPendingWork: Boolean;
var
  State: TResumePlatform;
begin
  Result := False;
  if FTaskSystem <> nil then Exit;
  if not FPlanReady or (FResumePlatforms = nil) or (FResumePlatforms.Count = 0) then
    Exit(Terminated or (FStatus.Errors > 0));
  for State in FResumePlatforms.Values do
    if not State.Saved then Exit(True);
end;

function TScrapeWorker.ResumeInputs(Sys: TJSONObject): TArray<string>;
var
  State: TResumePlatform;
  Key, FileName: string;
  Count: Integer;
begin
  Key := THashSHA2.GetHashString(Sys.ToJSON);
  if not FResumePlatforms.TryGetValue(Key, State) then
  begin
    State := TResumePlatform.Create;
    try
      if FTargetRom <> '' then
        State.Inputs := TArray<string>.Create(FTargetRom)
      else
        State.Inputs := ScanInputs(Sys,
          function: Boolean
          begin
            Result := Terminated;
          end);
      if FTargetRom = '' then
        State.Inputs := FilterNewInputs(Sys, State.Inputs);
      FResumePlatforms.Add(Key, State);
    except
      State.Free;
      raise;
    end;
  end;
  Result := nil;
  if State.Saved then Exit;
  SetLength(Result, Length(State.Inputs));
  Count := 0;
  for FileName in State.Inputs do
    if not State.Completed.ContainsKey(PathKey(FileName)) then
    begin
      Result[Count] := FileName;
      Inc(Count);
    end;
  SetLength(Result, Count);
end;

function TScrapeWorker.CreateContinuation(Credentials: TJSONObject; NetworkQueue: TScreenScraperNetworkQueue): TScrapeWorker;
var
  Key: string;
begin
  if not Finished or not HasPendingWork then
    raise EInvalidOpException.Create('No stopped scrape is available to continue');
  if Credentials = nil then Credentials := FCredentials;
  Result := TScrapeWorker.Create(FConfig, Credentials, FBase, FSelected, FOffline, FEngineLimit, FTargetRom, NetworkQueue);
  try
    for Key in FResumePlatforms.Keys do
      Result.FResumePlatforms.Add(Key, FResumePlatforms[Key].Clone);
    Result.Log(SK.Locale.L('Scraping resumed; completed games will be skipped.'));
  except
    Result.Free;
    raise;
  end;
end;

procedure TScrapeWorker.CaptureQuota(User: TJSONObject);
begin
  if JValue(User, 'response.ssuser') = nil then
    Exit;
  TMonitor.Enter(FLock);
  try
    FStatus.QuotaText := JStr(User, 'response.ssuser.requeststoday', '—') + ' / ' +
      JStr(User, 'response.ssuser.maxrequestsperday', '—');
    FStatus.KOQuotaText := JStr(User, 'response.ssuser.requestskotoday', '—') + ' / ' +
      JStr(User, 'response.ssuser.maxrequestskoperday', '—');
    FStatus.QuotaUpdated := Now;
  finally
    TMonitor.Exit(FLock)
  end;
  FQuotaTick := TThread.GetTickCount64;
end;

procedure TScrapeWorker.RefreshQuota;
var
  User: TJSONObject;
  BeforeRequests: Integer;
begin
  if FOffline or Terminated or (FTaskSystem <> nil) or JBool(FCredentials, 'anonymous') then
    Exit;
  if (FQuotaTick <> 0) and (TThread.GetTickCount64 - FQuotaTick < QuotaRefreshIntervalMs) then
    Exit;
  FQuotaTick := TThread.GetTickCount64;
  BeforeRequests := FAPI.Requests;
  try
    try
      User := FAPI.Authenticate;
      try
        CaptureQuota(User);
      finally
        User.Free
      end;
    except
      // Cancellation must reach the coordinator so it stops its child workers.
      on E: EAbort do
        raise;
      on E: EScreenScraperFatal do
        raise;
      on E: Exception do
        Log(SK.Locale.L('Не удалось обновить лимиты ScreenScraper.'));
    end;
  finally
    TMonitor.Enter(FLock);
    try
      Inc(FStatus.Requests, FAPI.Requests - BeforeRequests);
    finally
      TMonitor.Exit(FLock)
    end;
  end;
end;

procedure HashStream(Stream: TStream; out CRC, MD5, SHA1: string; Cancel: TFunc<Boolean>);
begin
  HashInputStream(Stream, CRC, MD5, SHA1, Cancel)
end;

constructor TScrapeWorker.Create(Config, Credentials: TJSONObject; const Base: string; Selected: Integer; Offline: Boolean; OfflineEngines: Integer; const TargetRom: string; NetworkQueue: TScreenScraperNetworkQueue);
begin
  inherited Create(True);
  FreeOnTerminate := False;
  FLock := TObject.Create;
  if (Config = nil) or (Credentials = nil) then
    raise EArgumentNilException.Create('Worker configuration and credentials are required');
  FScenario := TScenarioRequest.FromConfig(Config);
  FConfig := Config.Clone as TJSONObject;
  FCredentials := Credentials.Clone as TJSONObject;
  JSet(FCredentials, 'anonymous', TJSONBool.Create(JBool(Config, 'Anonymous', JBool(Credentials, 'anonymous'))));
  FBase := IncludeTrailingPathDelimiter(Base);
  CheckWritablePath(FBase);
  ApplyCachePolicy(FConfig);
  FCacheBase := CacheBase(FConfig);
  FWorkBase := CacheWorkBase(FConfig);
  FSystemCatalog := ReadJSON(TPlatformPath.Combine(FBase, SystemsCatalogPath));
  if FSystemCatalog = nil then
    FSystemCatalog := ReadJSON(TPlatformPath.Combine(AppBase, SystemsCatalogPath));
  FSelected := Selected;
  FTargetRom := TargetRom;
  if (FTargetRom <> '') and (Selected < 0) then
    raise EArgumentException.Create('Select a platform for single-game scraping');
  FOffline := Offline;
  FEngineLimit := Max(1, OfflineEngines);
  if not FOffline then
    FEngineLimit := Max(MinimumScrapeWorkers, FEngineLimit);
  FNetworkQueue := NetworkQueue;
  if FNetworkQueue = nil then
  begin
    FOwnsNetworkQueue := True;
    FNetworkQueue := TScreenScraperNetworkQueue.Create(1);
  end;
  FLog := TStringList.Create;
  FProduced := TDictionary<string, Boolean>.Create;
  FCleanupRoots := TDictionary<string, Boolean>.Create;
  FResults := TObjectList<TJSONObject>.Create(True);
  FMissing := TStringList.Create;
  FScanned := TDictionary<string, TArray<string>>.Create;
  FResumePlatforms := TObjectDictionary<string, TResumePlatform>.Create([doOwnsValues]);
  FCompletedInputs := TDictionary<string, Boolean>.Create;
  FPreviewFiles := TList<string>.Create;
  FStatus.Started := Now;
  FStatus.Running := True;
end;

destructor TScrapeWorker.Destroy;
begin
  // RTL also handles partially constructed and never-started threads.
  ShutdownThread;
  if FOwnsNetworkQueue then
    FNetworkQueue.Free;
  FTaskSystem.Free;
  FResults.Free;
  FMissing.Free;
  FScanned.Free;
  FResumePlatforms.Free;
  FCompletedInputs.Free;
  FPreviewFiles.Free;
  FConfig.Free;
  FCredentials.Free;
  FSystemCatalog.Free;
  FLog.Free;
  FProduced.Free;
  FCleanupRoots.Free;
  FLock.Free;
  inherited;
end;

procedure TScrapeWorker.LockResource(Lock: TObject);
begin
  if Terminated then
    raise EAbort.Create('Cancelled');
  while not TMonitor.Enter(Lock, ResourceLockPollMs) do
    if Terminated then
      raise EAbort.Create('Cancelled');
end;

procedure TScrapeWorker.Log(const S: string);
begin
  TMonitor.Enter(FLock);
  try
    FLog.Add(FormatDateTime('hh:nn:ss', Now) + '  ' + S);
  finally
    TMonitor.Exit(FLock);
  end;
  // Only the owning worker writes this file; snapshots never wait for disk IO.
  if FLogFile = '' then
    Exit;
  try
    TFile.AppendAllText(FLogFile, FormatDateTime('yyyy-mm-dd hh:nn:ss', Now) + ' ' + S + sLineBreak, TEncoding.UTF8);
  except
    on E: Exception do
    begin
      FLogFile := '';
      TMonitor.Enter(FLock);
      try
        FLog.Add(SK.Locale.L('Warning: file logging disabled: %s', [E.Message]));
      finally
        TMonitor.Exit(FLock)
      end;
    end;
  end;
end;

procedure TScrapeWorker.Trace(const S: string);
begin
  if FVerbose then
    Log('TRACE: ' + S);
end;

procedure TScrapeWorker.DoTerminate;
begin
  // Creation can fail before the lock exists; RTL still invokes DoTerminate.
  if FLock = nil then
    Exit;
  // TThread skips Execute when cancelled before the thread starts.
  TMonitor.Enter(FLock);
  try
    if FatalException <> nil then
    begin
      Inc(FStatus.Errors);
      if FatalException is Exception then
        FStatus.LastError := Exception(FatalException).Message
      else
        FStatus.LastError := FatalException.ClassName;
      FStatus.Stage := 'Failed';
    end;
    if not FStatus.Finished then
    begin
      FStatus.Running := False;
      FStatus.Finished := True;
      FStatus.Cancelled := Terminated;
      FStatus.CanResume := HasPendingWork;
      FStatus.FinishedAt := Now;
      if Terminated then
        FStatus.Stage := 'Cancelled'
      else if FatalException = nil then
        FStatus.Stage := 'Stopped';
    end;
  finally
    TMonitor.Exit(FLock)
  end;
  inherited;
end;

procedure TScrapeWorker.SetStage(const Value: string);
begin
  TMonitor.Enter(FLock);
  try
    FStatus.Stage := Value;
  finally
    TMonitor.Exit(FLock)
  end;
end;

procedure TScrapeWorker.QueuePreview(const FileName: string);
begin
  if MatchText(TPath.GetExtension(FileName), PreviewImageExtensions) then
    FPreviewFiles.Add(FileName);
end;

procedure TScrapeWorker.PublishImage(const FileName: string);
var
  Data: TBytes;
  Preview: TBitmap;
  Stream: TMemoryStream;
begin
  if not MatchText(TPath.GetExtension(FileName), PreviewImageExtensions) then
    Exit;
  // Decode and shrink on the worker. The UI only receives a small immutable PNG.
  try
    Preview := TBitmap.Create;
    try
      Preview.LoadThumbnailFromFile(FileName, MixPreviewWidth, MixPreviewHeight, False);
      if Preview.IsEmpty then
        Exit;
      Stream := TMemoryStream.Create;
      try
        Preview.SaveToStream(Stream);
        SetLength(Data, Stream.Size);
        Stream.Position := 0;
        Stream.ReadBuffer(Data, Length(Data));
      finally
        Stream.Free;
      end;
    finally
      Preview.Free;
    end;
  except
    Exit
  end;
  TMonitor.Enter(FLock);
  try
    Inc(FPreviewRevision);
    FStatus.PreviewData[FPreviewSlot] := Data;
    FStatus.PreviewSource[FPreviewSlot] := FileName;
    FStatus.PreviewRevision[FPreviewSlot] := FPreviewRevision;
    FPreviewSlot := (FPreviewSlot + 1) mod 3;
  finally
    TMonitor.Exit(FLock)
  end;
end;

procedure TScrapeWorker.Snapshot(out Status: TScrapeStatus; Lines: TStrings);
begin
  TMonitor.Enter(FLock);
  try
    Status := FStatus;
    Lines.Assign(FLog);
    FLog.Clear;
  finally
    TMonitor.Exit(FLock);
  end;
end;

procedure Put(Node: IXMLNode; const Name, Value: string);
begin
  SetXmlChildText(Node, Name, Value, True);
end;

function TScrapeWorker.FetchMedia(Game: TJSONObject; Sys: TJSONObject; const RomFile: string; Node: IXMLNode): Integer;
var
  Configs, Available: TJSONValue;
  C: TJSONValue;
  Kind, Folder, Ext, Dest, Region, URL, Link, Template: string;
  T, Idx, W, H, MediaIndex: Integer;
  Sources: TDictionary<string, string>;
  Item: TJSONValue;
  Content, BaseName, OutputName: string;
  Maps, MapNode: IXMLNode;
  TextData: TJSONObject;
  Pair: TJSONPair;
  Parts: TArray<string>;
  ReuseMedia, SourceIndexDirty: Boolean;
  SourceIndex: TJSONObject;
  SourceIndexFile, LastSourceKey: string;
  MediaLeases: IInterfaceList;

  procedure PinFile(const Path: string);
  begin
    if Path <> '' then
      MediaLeases.Add(CacheActivity(Path));
  end;

  function FileDigest(const Path: string): string;
  var
    Stream: TFileStream;
  begin
    Stream := TFileStream.Create(Path, fmOpenRead or fmShareDenyWrite);
    try
      Result := THashMD5.GetHashString(Stream);
    finally
      Stream.Free
    end;
  end;

  function UsableFile(const Path: string): Boolean;
  begin
    Result := (Path <> '') and TFile.Exists(Path);
    if Result then
      Result := TFile.GetSize(Path) > 0;
  end;

  procedure CopySource(const Source, Target: string);
  var
    Temporary: string;
  begin
    Temporary := Target + '.' + TGUID.NewGuid.ToString + '.tmp';
    try
      TFile.Copy(Source, Temporary, False);
      CommitFile(Temporary, Target);
    finally
      if TFile.Exists(Temporary) then
        TFile.Delete(Temporary);
    end;
  end;

  procedure RememberSource(const Key, Path: string);
  var
    Entry: TJSONObject;
    Digest: string;
  begin
    if (Key = '') or not UsableFile(Path) then
      Exit;
    Digest := FileDigest(Path);
    RegisterCacheFile(FWorkBase, JInt(Sys, 'SystemId'), 'media', Path);
    if SameText(JStr(SourceIndex, Key + '.md5'), Digest) and
      SamePath(JStr(SourceIndex, Key + '.path'), Path) then
      Exit;
    Entry := TJSONObject.Create;
    Entry.AddPair('path', Path);
    Entry.AddPair('md5', Digest);
    JSet(SourceIndex, Key, Entry);
    SourceIndexDirty := True;
  end;

  function ExistingSource(Media: TJSONValue; const Key: string): string;
  var
    Entry: TJSONValue;
    Candidate, SlotFolder, SlotName, Extension, Digest, SlotKind: string;
    Slot, Earlier, ImageIndex, SlotType: Integer;
    SlotConfig: TJSONValue;
  begin
    Result := '';
    Entry := JValue(SourceIndex, Key);
    Candidate := JStr(Entry, 'path');
    PinFile(Candidate);
    if UsableFile(Candidate) and (JStr(Entry, 'md5') <> '') then
      if SameText(FileDigest(Candidate), JStr(Entry, 'md5')) then
        Exit(Candidate);
    Extension := JStr(Media, 'format', 'png').ToLower;
    if not MatchText(Extension, ReusableMediaFormats) then
      Exit;
    // Sources are shared across ROMs. A newly matched game may need an image
    // already acquired for another ROM even though its own index has no entry.
    Candidate := TPlatformPath.Combine(FWorkBase, NativePath('Sources\media\') + Key + '.' + Extension);
    PinFile(Candidate);
    Digest := JStr(Media, 'md5');
    if (Digest <> '') and UsableFile(Candidate) then
      if SameText(FileDigest(Candidate), Digest) then
        Exit(Candidate);
    // Explicit cache clearing also invalidates bootstrap from old output images.
    if MediaCacheEpoch(FWorkBase, JInt(Sys, 'SystemId')) <> '' then
      Exit;
    // Bootstrap files produced before the source index existed using configured slots.
    for Slot := 0 to TJSONArray(Configs).Count - 1 do
    begin
      SlotConfig := TJSONArray(Configs).Items[Slot];
      SlotType := JInt(SlotConfig, 'Type');
      if SlotType = 0 then
      begin
        ImageIndex := JInt(SlotConfig, 'Image', -1);
        SlotKind := '';
        if (ImageIndex >= 0) and (ImageIndex <= High(ScreenScraperImageTypes)) then
          SlotKind := ScreenScraperImageTypes[ImageIndex]
        else if (ImageIndex >= Low(ScreenScraperExtendedImageTypes)) and
          (ImageIndex <= High(ScreenScraperExtendedImageTypes)) then
          SlotKind := ScreenScraperExtendedImageTypes[ImageIndex];
        if SlotKind.Contains(':') then
        begin
          if not SameText(SlotKind.Substring(0, SlotKind.IndexOf(':')), JStr(Media, 'parent')) then
            Continue;
          SlotKind := SlotKind.Substring(SlotKind.IndexOf(':') + 1);
        end;
        if SlotKind.Contains('#') then
          SlotKind := SlotKind.Substring(0, SlotKind.IndexOf('#'));
        if (SlotKind = '') or not SameText(SlotKind, JStr(Media, 'type')) then
          Continue;
      end
      else if not (((SlotType = 3) and SameText(JStr(Media, 'type'), 'video')) or
        ((SlotType = 4) and SameText(JStr(Media, 'type'), 'video-normalized')) or
        ((SlotType = 5) and SameText(JStr(Media, 'type'), 'manuel'))) then
        Continue;
      SlotFolder := ResolveOutput(JStr(SlotConfig, 'OutputFolder', NativePath('%ROMROOTFOLDER%\media\images')),
        JStr(Sys, 'GamesAndRoms.Path'), RomFile);
      SlotName := ChangeFileExt(ExtractRelativePath(IncludeTrailingPathDelimiter(JStr(Sys, 'GamesAndRoms.Path')), RomFile), '');
      if JStr(SlotConfig, 'OutputFolder').ToUpper.Contains('%ROMFOLDER%') then
        SlotName := TPath.GetFileNameWithoutExtension(RomFile);
      for Earlier := 0 to Slot - 1 do
        if SamePath(ResolveOutput(JStr(TJSONArray(Configs).Items[Earlier], 'OutputFolder', NativePath('%ROMROOTFOLDER%\media\images')),
            JStr(Sys, 'GamesAndRoms.Path'), RomFile), SlotFolder) then
        begin
          SlotName := SlotName + '-media' + (Slot + 1).ToString;
          Break
        end;
      if JBool(SlotConfig, 'Optimize') and JBool(SlotConfig, 'LinkToNode', True) and (JInt(Sys, 'GameList.Type') <> 2) then
      begin
        Digest := JStr(Media, 'md5');
        if Digest = '' then
          Continue;
        SlotName := 'media-' + Digest.ToLower;
      end;
      Candidate := TPlatformPath.Combine(SlotFolder, SlotName + '.' + Extension);
      PinFile(Candidate);
      if not UsableFile(Candidate) then
        Continue;
      if SamePath(Candidate, JStr(Entry, 'path')) and (JStr(Entry, 'md5') <> '') then
        if not SameText(FileDigest(Candidate), JStr(Entry, 'md5')) then
          Continue;
      // Without provenance, filename and size cannot identify the media source.
      // Resized legacy files must be reacquired; indexed sources were checked above.
      if JBool(SlotConfig, 'ResizeWidth') or JBool(SlotConfig, 'ResizeHeight') then
        Continue;
      Digest := JStr(Media, 'md5');
      if (Digest = '') or not SameText(FileDigest(Candidate), Digest) then
        Continue;
      if (StrToInt64Def(JStr(Media, 'size'), 0) > 0) and
        (TFile.GetSize(Candidate) <> StrToInt64Def(JStr(Media, 'size'), 0)) then
        Continue;
      Exit(Candidate);
    end;
  end;

  procedure DownloadEntry(Media: TJSONValue; out FileName: string);
  var
    CacheLock: TObject;
    Attempt: Integer;
    Existing, Persistent, Key: string;

    function ValidMedia: Boolean;
    var
      Stream: TFileStream;
      Expected: string;
      ExpectedSize: Int64;
    begin
      Result := False;
      if not TFile.Exists(FileName) then
        Exit;
      ExpectedSize := StrToInt64Def(JStr(Media, 'size'), 0);
      if (TFile.GetSize(FileName) = 0) or ((ExpectedSize > 0) and (TFile.GetSize(FileName) <> ExpectedSize)) then
        Exit;
      Expected := JStr(Media, 'md5');
      if Expected = '' then
        Exit(True);
      Stream := TFileStream.Create(FileName, fmOpenRead or fmShareDenyWrite);
      try
        Result := SameText(THashMD5.GetHashString(Stream), Expected);
      finally
        Stream.Free
      end;
    end;

  begin
    FileName := '';
    URL := JStr(Media, 'url');
    if URL = '' then
      Exit;
    Key := THashSHA2.GetHashString(URL);
    LastSourceKey := Key;
    if ReuseMedia then
    begin
      Existing := ExistingSource(Media, Key);
      if Existing <> '' then
      begin
        Persistent := TPlatformPath.Combine(FWorkBase, NativePath('Sources\media\') + Key + TPath.GetExtension(Existing));
        PinFile(Persistent);
        CacheLock := SharedResourceLock('source|' + PathKey(Persistent));
        LockResource(CacheLock);
        try
          EnsureDirectory(ExtractFilePath(Persistent));
          if not SamePath(Existing, Persistent) then
            if not UsableFile(Persistent) or not SameText(FileDigest(Persistent), FileDigest(Existing)) then
              CopySource(Existing, Persistent);
          FileName := Persistent;
          RememberSource(Key, FileName);
        finally
          TMonitor.Exit(CacheLock)
        end;
        FProduced.AddOrSetValue(PathKey(FileName), True);
        Exit;
      end;
    end;
    Ext := JStr(Media, 'format', 'png').ToLower;
    if not MatchText(Ext, DownloadMediaFormats) then
      Ext := 'bin';
    FileName := TPlatformPath.Combine(FWorkBase, NativePath('Cache\media\') + THashSHA2.GetHashString(URL) + '.' + Ext);
    if FCacheBase = '' then
      FileName := TPlatformPath.Combine(FWorkBase, 'Downloads/' + TGUID.NewGuid.ToString + '.' + Ext);
    PinFile(FileName);
    CacheLock := SharedResourceLock('download|' + PathKey(FileName));
    LockResource(CacheLock);
    try
      if (FCacheBase <> '') and not (FScenario.Active and (FScenario.Mode = scmForce)) and ValidMedia then
        Exit;
      for Attempt := 0 to 1 do
      begin
        if TFile.Exists(FileName) then
          TFile.Delete(FileName);
        SetStage('Downloading media');
        FAPI.Download(URL, FileName);
        if ValidMedia then
        begin
          TMonitor.Enter(FLock);
          try
            Inc(FStatus.Downloaded);
          finally
            TMonitor.Exit(FLock)
          end;
          Exit;
        end;
      end;
      TFile.Delete(FileName);
      raise EScreenScraper.Create('Downloaded media checksum or size mismatch');
    finally
      TMonitor.Exit(CacheLock);
      RegisterCacheFile(FWorkBase, JInt(Sys, 'SystemId'), 'media', FileName);
      if ReuseMedia and ValidMedia then
      begin
        Persistent := TPlatformPath.Combine(FWorkBase, NativePath('Sources\media\') + Key + '.' + Ext);
        PinFile(Persistent);
        CacheLock := SharedResourceLock('source|' + PathKey(Persistent));
        LockResource(CacheLock);
        try
          EnsureDirectory(ExtractFilePath(Persistent));
          if not UsableFile(Persistent) or not SameText(FileDigest(Persistent), FileDigest(FileName)) then
            CopySource(FileName, Persistent);
          FileName := Persistent;
          RememberSource(Key, FileName);
        finally
          TMonitor.Exit(CacheLock)
        end;
      end;
    end;
  end;

  procedure Acquire(const MediaType: string; out FileName: string);
  var
    Match, Entries, SystemInfo, CatalogSystems: TJSONValue;
    Priority, ActualType, ParentType, ParentID: string;
    MediaNumber: Integer;
  begin
    FileName := '';
    TMonitor.Enter(FLock);
    try
      Inc(FStatus.MediaRequested);
    finally
      TMonitor.Exit(FLock)
    end;
    Entries := Available;
    ActualType := MediaType;
    ParentType := 'jeu';
    ParentID := '';
    if MediaType.Contains(':') then
    begin
      ParentType := MediaType.Substring(0, MediaType.IndexOf(':'));
      ActualType := MediaType.Substring(MediaType.IndexOf(':') + 1);
    end;
    if ActualType.Contains('#') then
    begin
      MediaNumber := StrToIntDef(ActualType.Substring(ActualType.IndexOf('#') + 1), 1) - 1;
      ActualType := ActualType.Substring(0, ActualType.IndexOf('#'));
      if (ParentType = 'genre') and (MediaNumber >= 0) then
        ParentID := (MediaNumber + 1).ToString
      else
        Exit;
    end;
    if ParentType = 'system' then
    begin
      Entries := nil;
      CatalogSystems := JValue(FSystemCatalog, 'systemes');
      if CatalogSystems is TJSONArray then
        for SystemInfo in TJSONArray(CatalogSystems) do
          if JStr(SystemInfo, 'id') = JStr(Game, 'systeme.id', JStr(Sys, 'SystemId')) then
          begin
            Entries := JValue(SystemInfo, 'medias');
            Break
          end;
    end;
    if not (Entries is TJSONArray) then
      Exit;
    Priority := RegionPriority(Game, Sys, RomFile);
    Match := SelectMedia(Entries, ActualType, ParentType, ParentID, Priority,
      JStr(Sys, 'Miscellaneous.Classification', 'PEGI'), JInt(Game, 'rom.romnumsupport'), JBool(Sys, 'Miscellaneous.StrictRegionList'));
    if Match = nil then
      Exit;
    DownloadEntry(Match, FileName);
    if FileName <> '' then
    begin
      TMonitor.Enter(FLock);
      try
        Inc(FStatus.MediaFound);
      finally
        TMonitor.Exit(FLock)
      end;
    end;
  end;

  procedure PublishMedia(var FileName: string; const RelativeName: string);
  var
    FinalName, Digest, Extension: string;
    Stream: TFileStream;
    Lock: TObject;
  begin
    if Terminated then
      raise EAbort.Create('Cancelled');
    if T = 7 then
      Extension := '.p2k.cfg'
    else
      Extension := TPath.GetExtension(FileName);
    if JBool(C, 'Optimize') and JBool(C, 'LinkToNode', True) and (JInt(Sys, 'GameList.Type') <> 2) and (T <> 7) then
    begin
      Stream := TFileStream.Create(FileName, fmOpenRead or fmShareDenyWrite);
      try
        Digest := THashMD5.GetHashString(Stream).ToLower;
      finally
        Stream.Free
      end;
      FinalName := TPlatformPath.Combine(Folder, 'media-' + Digest + Extension);
    end
    else
      FinalName := TPlatformPath.Combine(Folder, RelativeName + Extension);
    EnsureDirectory(ExtractFilePath(FinalName));
    Lock := SharedResourceLock('publish|' + PathKey(FinalName));
    LockResource(Lock);
    try
      if Terminated then
        raise EAbort.Create('Cancelled');
      if ReuseMedia and UsableFile(FinalName) and
        SameText(FileDigest(FileName), FileDigest(FinalName)) then
        TFile.Delete(FileName)
      else
        CommitFile(FileName, FinalName);
      FileName := FinalName;
      if not (T in [1, 2, 6, 7]) and not ReuseMedia then
        RememberSource(LastSourceKey, FinalName);
    finally
      TMonitor.Exit(Lock)
    end;
  end;

begin
  Result := 0;
  Configs := JValue(Sys, 'Medias');
  Available := JValue(Game, 'medias');
  if not (Configs is TJSONArray) then
    Exit;
  MediaLeases := TInterfaceList.Create;
  ReuseMedia := (FCacheBase <> '') and JBool(Sys, 'Miscellaneous.ReuseExistingMedia');
  SourceIndexFile := TPlatformPath.Combine(FWorkBase, NativePath('State\MediaSources\') +
    THashSHA2.GetHashString(PathKey(RomFile)) + '.json');
  PinFile(SourceIndexFile);
  SourceIndexDirty := False;
  SourceIndex := ReadJSON(SourceIndexFile);
  if SourceIndex = nil then
    SourceIndex := TJSONObject.Create;
  if JStr(SourceIndex, '_epoch') <> MediaCacheEpoch(FWorkBase, JInt(Sys, 'SystemId')) then
  begin
    SourceIndex.Free;
    SourceIndex := TJSONObject.Create;
  end;
  JSet(SourceIndex, '_epoch', TJSONString.Create(MediaCacheEpoch(FWorkBase, JInt(Sys, 'SystemId'))));
  RegisterCacheFile(FWorkBase, JInt(Sys, 'SystemId'), 'source-index', SourceIndexFile);
  try
    for MediaIndex := 0 to TJSONArray(Configs).Count - 1 do
    begin
      C := TJSONArray(Configs).Items[MediaIndex];
      if FScenario.Active and (MediaNode(TJSONArray(Configs), MediaIndex) <> FScenario.Field) then
        Continue;
      LastSourceKey := '';
      TMonitor.Enter(FLock);
      try
        FStatus.CurrentMedia := MediaIndex + 1;
        FStatus.MediaTotal := TJSONArray(Configs).Count;
        FStatus.Stage := 'Preparing media';
      finally
        TMonitor.Exit(FLock)
      end;
      if Terminated then
        Exit;
      T := JInt(C, 'Type');
      Kind := '';
      Link := 'image';
      case T of
        0:
          begin
            Idx := JInt(C, 'Image');
            if (Idx >= 0) and (Idx <= 16) then
              Kind := ScreenScraperImageTypes[Idx]
            else if (Idx >= Low(ScreenScraperExtendedImageTypes)) and
              (Idx <= High(ScreenScraperExtendedImageTypes)) then
              Kind := ScreenScraperExtendedImageTypes[Idx];
            if Idx in [10, 11, 12] then
              Link := 'marquee'
            else if Idx in [3, 6] then
              Link := 'box';
          end;
        3:
          begin
            Kind := 'video';
            Link := 'video';
          end;
        4:
          begin
            Kind := 'video-normalized';
            Link := 'video';
          end;
        5:
          begin
            Kind := 'manuel';
            Link := 'manual';
          end;
        6:
          begin
            Kind := 'tips';
            Link := 'tips';
          end;
        7:
          begin
            Kind := 'p2k';
            Link := 'p2k';
          end;
        8:
          begin
            Kind := 'maps';
            Link := 'map';
          end;
      end;
      Link := MediaNode(TJSONArray(Configs), MediaIndex);
      Folder := JStr(C, 'OutputFolder', NativePath('%ROMROOTFOLDER%\media\images'));
      Folder := ResolveOutput(Folder, JStr(Sys, 'GamesAndRoms.Path'), RomFile);
      EnsureDirectory(Folder);
      if JBool(C, 'EmptyOutputFolder') then
        FCleanupRoots.AddOrSetValue(IncludeTrailingPathDelimiter(PathKey(Folder)), True);
      OutputName := ChangeFileExt(ExtractRelativePath(IncludeTrailingPathDelimiter(JStr(Sys, 'GamesAndRoms.Path')), RomFile), '');
      if JStr(C, 'OutputFolder').ToUpper.Contains('%ROMFOLDER%') then
        OutputName := TPath.GetFileNameWithoutExtension(RomFile);
      if T = 7 then
        OutputName := TPath.GetFileNameWithoutExtension(RomFile);
    // Only disambiguate slots targeting the same folder. Paths never depend on the absolute ROM root.
      if T <> 7 then
        for Idx := 0 to MediaIndex - 1 do
          if SamePath(ResolveOutput(JStr(TJSONArray(Configs).Items[Idx], 'OutputFolder', NativePath('%ROMROOTFOLDER%\media\images')),
              JStr(Sys, 'GamesAndRoms.Path'), RomFile), Folder) then
          begin
            OutputName := OutputName + '-media' + IntToStr(MediaIndex + 1);
            Break;
          end;
    // Compose/download into a unique staging file, then publish complete content atomically.
      BaseName := 'stage-' + TGUID.NewGuid.ToString.Trim(['{', '}']);
      try
        Dest := '';
        if T = 8 then
        begin
          Idx := 0;
          Maps := nil;
          if Available is TJSONArray then
            for Item in TJSONArray(Available) do
              if SameText(JStr(Item, 'type'), 'maps') then
              begin
                if Terminated then
                  raise EAbort.Create('Cancelled');
                TMonitor.Enter(FLock);
                try
                  Inc(FStatus.MediaRequested);
                finally
                  TMonitor.Exit(FLock)
                end;
                DownloadEntry(Item, URL);
                if URL = '' then
                  Continue;
                TMonitor.Enter(FLock);
                try
                  Inc(FStatus.MediaFound);
                finally
                  TMonitor.Exit(FLock)
                end;
                Inc(Idx);
                Dest := TPlatformPath.Combine(Folder, BaseName + '-map' + Idx.ToString + TPath.GetExtension(URL));
                TFile.Copy(URL, Dest, True);
                PublishMedia(Dest, OutputName + '-map' + Idx.ToString);
                FProduced.AddOrSetValue(PathKey(Dest), True);
                Inc(Result);
                QueuePreview(Dest);
                TMonitor.Enter(FLock);
                try
                  Inc(FStatus.Saved);
                finally
                  TMonitor.Exit(FLock)
                end;
                if Link = 'maps' then
                begin
                  if Maps = nil then
                  begin
                    Maps := Node.ChildNodes.FindNode('maps');
                    if Maps = nil then
                      Maps := Node.AddChild('maps');
                  end;
                  MapNode := Maps.AddChild('map');
                  MapNode.Attributes['path'] := Dest;
                  MapNode.Attributes['title'] := JStr(Item, 'title', JStr(Item, 'nom', JStr(Item, 'region', 'Map ' + Idx.ToString)));
                end;
              end;
          Continue;
        end
        else if T in [6, 7] then
        begin
          Content := '';
          if T = 7 then
          begin
            Content := JStr(Game, 'sp2kcfg');
            Ext := '.p2k.cfg';
          end
          else
          begin
            Ext := '.ini';
            Content := TipsContent(Game, Sys);
          end;
          if Content = '' then
            Continue;
          Dest := TPlatformPath.Combine(Folder, BaseName + Ext);
          TFile.WriteAllText(Dest, Content, TEncoding.UTF8);
        end
        else if T in [1, 2] then
        begin
          Sources := TDictionary<string, string>.Create;
          try
            if T = 2 then
              Template := JStr(C, 'LocalMixFile')
            else
            begin
              Idx := JInt(C, 'InternalMix');
              if (Idx < 0) or (Idx > 6) then
                Idx := 3;
              Template := TPlatformPath.Combine(AppBase, NativePath('Mixes\') + BuiltInMixFiles[Idx]);
            end;
            for Region in RequiredMixMedia(Template, JStr(Sys, 'SystemId')) do
            begin
              if (Region = 'region1') or (Region = 'region2') then
              begin
                Content := OrderedRomRegions(Game, Sys, RomFile);
                if Region = 'region1' then
                  Idx := 0
                else
                  Idx := 1;
                if Idx < Length(Content.Split([','])) then
                begin
                  Dest := AppBase + NativePath('Resources\RetroScraperLibrary2.Properties.Flags\flag_') + Content.Split([','])[Idx].Trim + '.png';
                  if TFile.Exists(Dest) then
                    Sources.AddOrSetValue(Region, Dest);
                end;
              end
              else
              begin
                Acquire(Region, Dest);
                if Dest <> '' then
                  Sources.AddOrSetValue(Region, Dest);
              end;
            end;
            Sources.AddOrSetValue('@systemid', JStr(Sys, 'SystemId'));
            if JValue(FSystemCatalog, 'systemes') is TJSONArray then
              for Item in TJSONArray(JValue(FSystemCatalog, 'systemes')) do
                Sources.AddOrSetValue('@parent:' + JStr(Item, 'id'), JStr(Item, 'parentid', '0'));
            TextData := DescribeGame(Game, Sys, RomFile);
            try
              for Pair in TextData do
                Sources.AddOrSetValue('@' + Pair.JsonString.Value, JStr(TextData, Pair.JsonString.Value));
              Sources.AddOrSetValue('@name', TRegEx.Replace(JStr(TextData, 'name'), '\s*[\(\[].*?[\)\]]', '').Trim);
              Sources.AddOrSetValue('@description', JStr(TextData, 'desc'));
              for Content in ['genre', 'region'] do
              begin
                Parts := JStr(TextData, Content).Split([',']);
                for Idx := 0 to High(Parts) do
                  Sources.AddOrSetValue('@' + Content + Idx.ToString, Parts[Idx].Trim);
              end;
              Content := JStr(TextData, 'players');
              Parts := Content.Split(['-']);
              Sources.AddOrSetValue('@minplayers', '?');
              Sources.AddOrSetValue('@maxplayers', '?');
              if Length(Parts) = 2 then
              begin
                Sources['@minplayers'] := Parts[0];
                Sources['@maxplayers'] := Parts[1]
              end
              else if Content.EndsWith('+') then
              begin
                Sources['@minplayers'] := Content.TrimRight(['+']);
                Sources['@maxplayers'] := '+'
              end
              else if StrToIntDef(Content, -1) >= 0 then
              begin
                Sources['@minplayers'] := Content;
                Sources['@maxplayers'] := Content
              end;
              Content := JStr(TextData, 'releasedate');
              if Length(Content) >= 8 then
                Sources.AddOrSetValue('@releasedate', DateToStr(EncodeDate(StrToIntDef(Copy(Content, 1, 4), 2000), StrToIntDef(Copy(Content, 5, 2), 1), StrToIntDef(Copy(Content, 7, 2), 1))));
            finally
              TextData.Free
            end;
            Dest := TPlatformPath.Combine(Folder, BaseName + MixExtension(Template));
            W := 0;
            H := 0;
            SetStage('Composing mix');
            RenderMix(Template, Sources, Dest, W, H);
            if JBool(C, 'ResizeWidth') or JBool(C, 'ResizeHeight') then
            begin
              if JBool(C, 'ResizeWidth') then
                W := JInt(C, 'ResizeWidthValue', DefaultMediaWidth);
              if JBool(C, 'ResizeHeight') then
                H := JInt(C, 'ResizeHeightValue', DefaultMediaHeight);
              ResizeImage(Dest, Dest, W, H, JBool(C, 'KeepRatio', True));
            end;
          finally
            Sources.Free;
          end;
        end
        else
        begin
          Acquire(Kind, Dest);
          if Dest = '' then
            Continue;
          Ext := TPath.GetExtension(Dest);
          URL := Dest;
          Dest := TPlatformPath.Combine(Folder, BaseName + Ext);
          if (T = 0) and (JBool(C, 'ResizeWidth') or JBool(C, 'ResizeHeight')) then
          begin
            W := 0;
            H := 0;
            if JBool(C, 'ResizeWidth') then
              W := JInt(C, 'ResizeWidthValue', DefaultMediaWidth);
            if JBool(C, 'ResizeHeight') then
              H := JInt(C, 'ResizeHeightValue', DefaultMediaHeight);
            ResizeImage(URL, Dest, W, H, JBool(C, 'KeepRatio', True));
          end
          else
            TFile.Copy(URL, Dest, True);
        end;
        PublishMedia(Dest, OutputName);
        FProduced.AddOrSetValue(PathKey(Dest), True);
        Inc(Result);
        QueuePreview(Dest);
        TMonitor.Enter(FLock);
        try
          Inc(FStatus.Saved);
        finally
          TMonitor.Exit(FLock)
        end;
        if (Link <> '') and JBool(C, 'LinkToNode', True) and (Node.ChildNodes.FindNode(Link) = nil) then
          Put(Node, Link, './' + ExtractRelativePath(IncludeTrailingPathDelimiter(JStr(Sys, 'GamesAndRoms.Path')), Dest).Replace('\', '/'));
      except
        on E: EAbort do
        begin
          if (Dest <> '') and TPath.GetFileName(Dest).StartsWith(BaseName) and TFile.Exists(Dest) then
            TFile.Delete(Dest);
          raise;
        end;
        on E: Exception do
        begin
          if E is EScreenScraperFatal then
            raise;
          if (Dest <> '') and TPath.GetFileName(Dest).StartsWith(BaseName) and TFile.Exists(Dest) then
            TFile.Delete(Dest);
          Log(SK.Locale.L('Media error: %s', [E.Message]));
          TMonitor.Enter(FLock);
          try
            Inc(FStatus.Errors);
            FStatus.LastError := E.Message;
          finally
            TMonitor.Exit(FLock);
          end;
        end;
      end;
    end;
  finally
    try
      if SourceIndexDirty then
      begin
        WriteJSON(SourceIndexFile, SourceIndex);
        RegisterCacheFile(FWorkBase, JInt(Sys, 'SystemId'), 'source-index', SourceIndexFile);
      end;
    finally
      SourceIndex.Free
    end;
  end;
end;

procedure TScrapeWorker.RunInputQueue(Sys: TJSONObject);
var
  Files: TArray<string>;
  FileName, Folder, CRC, MD5, SHA1, Params, RomName, Extra, Rel: string;
  OutputLock: TObject;
  Hashes: TRomHashes;
  FallbackResponse: TJSONObject;
  Response, Game, Item: TJSONObject;
  Doc: IXMLDocument;
  Node: IXMLNode;
  i, Method: Integer;
  Size: Int64;
  Missing: TStringList;
  SearchIDs: TList<string>;
  SearchID: string;
  Secondary: TJSONValue;
  StartErrors, MapIndex: Integer;
  MapsArray: TJSONArray;
  MapItem: TJSONObject;
begin
  FProduced.Clear;
  FVerbose := JBool(Sys, 'Miscellaneous.VerboseLogs');
  FAPI.Diagnostic :=
    procedure(MessageText: string)
    begin
      Trace(MessageText)
    end;
  FAPI.LookupMiss :=
    procedure(MessageText: string)
    begin
      Log(MessageText)
    end;
  FCleanupRoots.Clear;
  TMonitor.Enter(FLock);
  try
    StartErrors := FStatus.Errors;
  finally
    TMonitor.Exit(FLock);
  end;
  Folder := JStr(Sys, 'GamesAndRoms.Path');
  Files := FQueue.Files;
  Missing := FMissing;
  try
    TMonitor.Enter(FLock);
    try
      Inc(FStatus.Total, Length(Files));
      FStatus.CurrentTotal := Length(Files);
      FStatus.CurrentCompleted := 0;
      FStatus.CurrentSystem := TPath.GetFileName(Folder);
      FStatus.CurrentSystemID := JStr(Sys, 'SystemId');
    finally
      TMonitor.Exit(FLock);
    end;
    FAPI.ScopeSystemID := JInt(Sys, 'SystemId');
    FAPI.CacheDays := JInt(Sys, 'Miscellaneous.CacheTTLInDays', 3);
    FAPI.Retries := JInt(Sys, 'Miscellaneous.HttpMaxRetries', 2);
    Method := JInt(Sys, 'Miscellaneous.Method');
    while FQueue.Pop(FileName) do
    begin
      if Terminated then
        Break;
      TMonitor.Enter(FLock);
      try
        FStatus.CurrentFile := TPath.GetFileName(FileName);
        FStatus.CurrentMedia := 0;
        FStatus.MediaTotal := 0;
        FStatus.Stage := 'Hashing ROM';
      finally
        TMonitor.Exit(FLock);
      end;
      Response := nil;
      Item := nil;
      try
        try
          RomName := TPath.GetFileName(FileName);
          Trace('Processing ROM: ' + RomName);
          CRC := '';
          MD5 := '';
          SHA1 := '';
          Size := 0;
          if Method <> 2 then
          begin
            Trace('Computing ROM hashes');
            Hashes := ComputeInputHashes(Sys, FileName, CacheLocation(FConfig, 'Cache/hashes'),
              function: Boolean
              begin
                Result := Terminated
              end);
            RegisterCacheFile(FWorkBase, JInt(Sys, 'SystemId'), 'hashes',
              TPlatformPath.Combine(FWorkBase, 'Cache/hashes/' + THashSHA2.GetHashString(PathKey(FileName)) + '.json'));
            RomName := Hashes.Name;
            CRC := Hashes.CRC;
            MD5 := Hashes.MD5;
            SHA1 := Hashes.SHA1;
            Size := Hashes.Size;
          end;
          if Terminated then
            Break;
          SetStage('Requesting metadata');
          SearchIDs := TList<string>.Create;
          try
            SearchIDs.Add(JStr(Sys, 'SystemId'));
            if JValue(Sys, 'SecondarySystemIds') is TJSONArray then
              for Secondary in TJSONArray(JValue(Sys, 'SecondarySystemIds')) do
                if SearchIDs.IndexOf(Secondary.Value) < 0 then
                  SearchIDs.Add(Secondary.Value);
            for SearchID in SearchIDs do
            begin
              if Terminated then
                raise EAbort.Create('Cancelled');
              Params := 'systemeid=' + Encode(SearchID);
              if Method <> 2 then
                Response := FAPI.Request(GameInfoEndpoint, Params + '&romtype=rom&romnom=' + Encode(CleanRomName(RomName)) +
                  '&romtaille=' + Size.ToString + '&crc=' + CRC + '&md5=' + MD5 + '&sha1=' + SHA1);
              if JValue(Response, 'response.jeu') = nil then
                FreeAndNil(Response);
              if (Method <> 1) and (Response = nil) then
              begin
                FallbackResponse := nil;
                for Extra in GameNameQueries(RomName) do
                begin
                  FallbackResponse := FAPI.Request(GameInfoEndpoint, Params + '&romtype=jeu&romnom=' + Encode(CleanRomName(Extra)));
                  if JValue(FallbackResponse, 'response.jeu') <> nil then
                    Break;
                  FreeAndNil(FallbackResponse);
                end;
                if FallbackResponse <> nil then
                begin
                  Response.Free;
                  Response := FallbackResponse
                end;
              end;
              if JValue(Response, 'response.jeu') <> nil then
                Break;
              FreeAndNil(Response);
            end;
          finally
            SearchIDs.Free;
          end;
          Game := JValue(Response, 'response.jeu') as TJSONObject;
          Item := DescribeGame(Game, Sys, FileName);
          if FScenario.Active then
            JSet(Item, 'exclude', TJSONBool.Create(False));
          JSet(Item, 'size', TJSONNumber.Create(Size));
          JSet(Item, 'crc', TJSONString.Create(CRC));
          JSet(Item, 'md5', TJSONString.Create(MD5));
          JSet(Item, 'sha1', TJSONString.Create(SHA1));
          if (Game <> nil) and (JInt(Game, 'romid') = 0) and (Method <> 2) then
            Missing.Add(Format('%-67s %s %15d %s %s', [RomName, CRC, Size, MD5, SHA1]));
          if Game = nil then
          begin
            Missing.Add(Format('%-67s %s %15d %s %s', [RomName, CRC, Size, MD5, SHA1]));
            TMonitor.Enter(FLock);
            try
              Inc(FStatus.Missing);
            finally
              TMonitor.Exit(FLock);
            end;
            Log(SK.Locale.L('Not found: %s', [RomName]));
          end
          else
          begin
            TMonitor.Enter(FLock);
            try
              Inc(FStatus.Found);
            finally
              TMonitor.Exit(FLock);
            end;
            if not JBool(Item, 'exclude') then
            begin
              Doc := TXMLDocument.Create(nil);
              Doc.Active := True;
              Node := Doc.AddChild('game');
              OutputLock := SharedResourceLock('output|' + JStr(Sys, 'GamesAndRoms.Path') + '|' + JStr(Game, 'id'));
              LockResource(OutputLock);
              try
                FPreviewFiles.Clear;
                if not FScenario.Active or ScenarioMediaField(FScenario.Field) then
                  FetchMedia(Game, Sys, FileName, Node);
                if (FPreviewFiles.Count > 0) and (TThread.GetTickCount64 >= FNextPreviewTick) then
                begin
                  PublishImage(FPreviewFiles[Random(FPreviewFiles.Count)]);
                  FNextPreviewTick := TThread.GetTickCount64 + UInt64(PreviewIntervalMs + Random(PreviewJitterMs));
                end;
              finally
                TMonitor.Exit(OutputLock)
              end;
              for i := 0 to Node.ChildNodes.Count - 1 do
              begin
                if Node.ChildNodes[i].NodeName = 'maps' then
                begin
                  MapsArray := TJSONArray.Create;
                  for MapIndex := 0 to Node.ChildNodes[i].ChildNodes.Count - 1 do
                  begin
                    MapItem := TJSONObject.Create;
                    MapItem.AddPair('path', VarToStr(Node.ChildNodes[i].ChildNodes[MapIndex].Attributes['path']));
                    MapItem.AddPair('title', VarToStr(Node.ChildNodes[i].ChildNodes[MapIndex].Attributes['title']));
                    MapsArray.AddElement(MapItem);
                  end;
                  JSet(Item, 'maps', MapsArray);
                  Continue;
                end;
                Rel := Node.ChildNodes[i].Text;
                if Rel.StartsWith('./') then
                  Rel := TPath.GetFullPath(TPlatformPath.Combine(Folder, Rel.Substring(2).Replace('/', '\')));
                JSet(Item, Node.ChildNodes[i].NodeName, TJSONString.Create(Rel));
              end;
              TMonitor.Enter(FLock);
              try
                FStatus.CurrentMedia := FStatus.MediaTotal;
              finally
                TMonitor.Exit(FLock);
              end;
            end;
            Log(SK.Locale.L('Completed: %s', [JStr(Item, 'name')]));
          end;
          if not Terminated then
          begin
            if (Game <> nil) or not JBool(Sys, 'GameList.PreserveMissingMedia') then
              FResults.Add(Item.Clone as TJSONObject);
            FCompletedInputs.AddOrSetValue(PathKey(FileName), True);
          end;
          TMonitor.Enter(FLock);
          try
            if JBool(Item, 'favorite') then
              Inc(FStatus.Favorites);
            if JBool(Item, 'hidden') then
              Inc(FStatus.Hidden);
          finally
            TMonitor.Exit(FLock);
          end;
        except
          on E: EAbort do
          begin
            Terminate;
            Break;
          end;
          on E: Exception do
          begin
            Log(SK.Locale.L('Error: %s — %s', [RomName, E.Message]));
            Trace(E.ClassName + ': ' + E.StackTrace);
            TMonitor.Enter(FLock);
            try
              Inc(FStatus.Errors);
              FStatus.LastError := E.Message;
            finally
              TMonitor.Exit(FLock);
            end;
            if E is EScreenScraperFatal then
            begin
              FQueue.Stop(E.Message);
              Terminate;
            end;
          end;
        end;
      finally
        Response.Free;
        Item.Free;
        TMonitor.Enter(FLock);
        try
          if not Terminated then
          begin
            Inc(FStatus.Completed);
            Inc(FStatus.CurrentCompleted);
          end;
          FStatus.Requests := FAPI.Requests;
          FStatus.Cached := FAPI.CacheHits;
        finally
          TMonitor.Exit(FLock);
        end;
      end;
    end;
  finally
    // Results remain owned by this engine until the coordinator merges them.
  end;
end;

procedure TScrapeWorker.ScrapeSystem(Sys: TJSONObject);
var
  Workers: TObjectList<TScrapeWorker>;
  Child: TScrapeWorker;
  Queue: TInputQueue;
  Files, FolderFiles: TArray<string>;
  BaseStatus, Combined, ChildStatus: TScrapeStatus;
  Seen: TArray<Int64>;
  Lines, Missing: TStringList;
  Writer: TGameListWriter;
  i, StartErrors, BaseAPIRequests: Integer;
  Done: Boolean;
  Path: string;
  Item: TJSONObject;
  Results: TObjectList<TJSONObject>;
  State: TResumePlatform;
  Collected: Boolean;

  procedure CollectResults;
  var
    Worker: TScrapeWorker;
    Item: TJSONObject;
    Path: string;
  begin
    if Collected then Exit;
    for Worker in Workers do
    begin
      for Path in Worker.FCompletedInputs.Keys do State.Completed.AddOrSetValue(Path, True);
      for Item in Worker.FResults do State.Results.Add(Item.Clone as TJSONObject);
      for Path in Worker.FMissing do
        if State.Missing.IndexOf(Path) < 0 then State.Missing.Add(Path);
      for Path in Worker.FProduced.Keys do State.Produced.AddOrSetValue(Path, True);
      for Path in Worker.FCleanupRoots.Keys do State.CleanupRoots.AddOrSetValue(Path, True);
    end;
    for Item in State.Results do Results.Add(Item);
    Missing.Assign(State.Missing);
    for Path in State.Produced.Keys do FProduced.AddOrSetValue(Path, True);
    for Path in State.CleanupRoots.Keys do FCleanupRoots.AddOrSetValue(Path, True);
    Collected := True;
  end;

  procedure Aggregate;
  var
    J, K: Integer;
    Path: string;
  begin
    if FNetworkQueue.Stopped then
      Queue.Stop(FNetworkQueue.StopReason);
    if Queue.Stopped then
      Terminate;
    try
      RefreshQuota;
    except
      on E: EAbort do
      begin
        if not FNetworkQueue.Stopped then
          raise;
        Queue.Stop(FNetworkQueue.StopReason);
        Terminate;
      end;
    end;
    Combined := BaseStatus;
    Inc(Combined.Requests, FAPI.Requests - BaseAPIRequests);
    Combined.Engines := nil;
    SetLength(Combined.Engines, Workers.Count);
    Combined.CurrentCompleted := 0;
    for J := 0 to Workers.Count - 1 do
    begin
      Workers[J].Snapshot(ChildStatus, Lines);
      for Path in Lines do
        if Path.Length > 10 then
          Log(Path.Substring(10))
        else
          Log(Path);
      Inc(Combined.Completed, ChildStatus.Completed);
      Inc(Combined.CurrentCompleted, ChildStatus.Completed);
      Inc(Combined.Found, ChildStatus.Found);
      Inc(Combined.Missing, ChildStatus.Missing);
      Inc(Combined.Errors, ChildStatus.Errors);
      Inc(Combined.Downloaded, ChildStatus.Downloaded);
      Inc(Combined.Saved, ChildStatus.Saved);
      Inc(Combined.Requests, ChildStatus.Requests);
      Inc(Combined.Cached, ChildStatus.Cached);
      Inc(Combined.Favorites, ChildStatus.Favorites);
      Inc(Combined.Hidden, ChildStatus.Hidden);
      Inc(Combined.MediaFound, ChildStatus.MediaFound);
      Inc(Combined.MediaRequested, ChildStatus.MediaRequested);
      Combined.Engines[J].Stage := ChildStatus.Stage;
      Combined.Engines[J].FileName := ChildStatus.CurrentFile;
      Combined.Engines[J].SystemName := ChildStatus.CurrentSystem;
      Combined.Engines[J].CurrentMedia := ChildStatus.CurrentMedia;
      Combined.Engines[J].MediaTotal := ChildStatus.MediaTotal;
      Combined.Engines[J].Running := ChildStatus.Running;
      if ChildStatus.Running then
      begin
        Combined.CurrentFile := ChildStatus.CurrentFile;
        Combined.Stage := ChildStatus.Stage
      end;
      if ChildStatus.LastError <> '' then
        Combined.LastError := ChildStatus.LastError;
      for K := 0 to 2 do
        if ChildStatus.PreviewRevision[K] > Seen[J * 3 + K] then
        begin
          Seen[J * 3 + K] := ChildStatus.PreviewRevision[K];
          TMonitor.Enter(FLock);
          try
            Inc(FPreviewRevision);
            FStatus.PreviewData[FPreviewSlot] := ChildStatus.PreviewData[K];
            FStatus.PreviewSource[FPreviewSlot] := ChildStatus.PreviewSource[K];
            FStatus.PreviewRevision[FPreviewSlot] := FPreviewRevision;
            FPreviewSlot := (FPreviewSlot + 1) mod 3;
          finally
            TMonitor.Exit(FLock)
          end;
        end;
      if ChildStatus.Cancelled then
        Terminate;
    end;
    if Queue.Stopped then
    begin
      Combined.LastError := Queue.StopReason;
      Terminate;
    end;
    TMonitor.Enter(FLock);
    try
      Combined.QuotaText := FStatus.QuotaText;
      Combined.KOQuotaText := FStatus.KOQuotaText;
      Combined.QuotaUpdated := FStatus.QuotaUpdated;
      Combined.PreviewData := FStatus.PreviewData;
      Combined.PreviewSource := FStatus.PreviewSource;
      Combined.PreviewRevision := FStatus.PreviewRevision;
      FStatus := Combined;
    finally
      TMonitor.Exit(FLock)
    end;
  end;

begin
  State := FResumePlatforms[THashSHA2.GetHashString(Sys.ToJSON)];
  if State.Saved then Exit;
  Files := FScanned[THashSHA2.GetHashString(Sys.ToJSON)];
  if (JBool(Sys, 'GameList.OnlyNew') or FScenario.Active) and (Length(Files) = 0) and
    (State.Results.Count = 0) then
  begin
    Log(SK.Locale.L('No games need updating; existing gamelist preserved.'));
    State.Saved := True;
    Exit;
  end;
  TMonitor.Enter(FLock);
  try
    FStatus.CurrentSystem := TPath.GetFileName(JStr(Sys, 'GamesAndRoms.Path'));
    FStatus.CurrentSystemID := JStr(Sys, 'SystemId');
    FStatus.CurrentTotal := Length(Files) + InputFolderCount(Sys, Files);
    FStatus.CurrentCompleted := 0;
    BaseStatus := FStatus;
    BaseAPIRequests := FAPI.Requests;
    StartErrors := FStatus.Errors;
  finally
    TMonitor.Exit(FLock)
  end;
  FProduced.Clear;
  FCleanupRoots.Clear;
  Queue := TInputQueue.Create(Files);
  Workers := TObjectList<TScrapeWorker>.Create(True);
  Lines := TStringList.Create;
  Missing := TStringList.Create;
  Results := TObjectList<TJSONObject>.Create(False);
  Writer := nil;
  Collected := False;
  try
    Writer := TGameListWriter.Create(Sys);
    for i := 0 to Min(FEngineLimit, Max(1, Length(Files))) - 1 do
    begin
      Child := TScrapeWorker.Create(FConfig, FCredentials, FBase, FSelected, FOffline, FEngineLimit, '', FNetworkQueue);
      Workers.Add(Child);
      Child.FQueue := Queue;
      Child.FTaskSystem := Sys.Clone as TJSONObject;
    end;
    SetLength(Seen, Workers.Count * 3);
    for Child in Workers do
      Child.Start;
    repeat
      Done := True;
      for Child in Workers do
      begin
        if Terminated then
          Child.Terminate;
        if not Child.Finished then
          Done := False;
      end;
      Aggregate;
      if not Done then
        Sleep(WorkerPollMs);
    until Done;
    Aggregate;
    CollectResults;
    Results.Sort(TComparer<TJSONObject>.Construct(
      function(const A, B: TJSONObject): Integer
      begin
        Result := CompareText(JStr(A, 'path'), JStr(B, 'path'))
      end));
    if not Terminated then
    begin
      for Item in Results do
      begin
        if Terminated then
          raise EAbort.Create('Cancelled');
        Writer.Add(Item);
      end;
      SetStage('Saving game list');
      StopLocalFrontend(JValue(FConfig, 'FrontEnd') as TJSONObject,
        procedure(S: string)
        begin
          Log(S)
        end,
        function: Boolean
        begin
          Result := Terminated
        end);
      if Terminated then
        raise EAbort.Create('Cancelled');
      FolderFiles := Writer.PrepareFolders(
        function: Boolean
        begin
          Result := Terminated
        end);
      for Path in FolderFiles do
        FProduced.AddOrSetValue(PathKey(Path), True);
      Writer.Save(
        function: Boolean
        begin
          Result := Terminated
        end);
      TMonitor.Enter(FLock);
      try
        Inc(FStatus.Total, Length(FolderFiles) - InputFolderCount(Sys, Files));
        Inc(FStatus.CurrentTotal, Length(FolderFiles) - InputFolderCount(Sys, Files));
        Inc(FStatus.Completed, Length(FolderFiles));
        Inc(FStatus.CurrentCompleted, Length(FolderFiles));
        Inc(FStatus.Saved, Length(FolderFiles));
      finally
        TMonitor.Exit(FLock)
      end;
      SaveMediaIndex(Sys, Writer.Document, not FScenario.Active and (FTargetRom = '') and
        not JBool(Sys, 'GameList.OnlyNew') and (FStatus.Errors = StartErrors));
      if (FTargetRom = '') and JBool(Sys, 'Miscellaneous.SaveFCRCMissing') then
        Missing.SaveToFile(ChangeFileExt(JStr(Sys, 'GameList.OutputFile'), '.Missing.FCRC.txt'), TEncoding.UTF8);
      State.Saved := True;
      Log(SK.Locale.L('Gamelist saved.'));
    end
    else
      Log(SK.Locale.L('Cancelled; existing gamelist preserved.'));
  finally
    for Child in Workers do
    begin
      Child.Terminate;
      if Child.Suspended then
        Child.Start
    end;
    for Child in Workers do
      Child.WaitFor;
    CollectResults;
    Results.Free;
    Writer.Free;
    Missing.Free;
    Lines.Free;
    Workers.Free;
    Queue.Free;
  end;
end;

procedure TScrapeWorker.SaveMediaIndex(Sys: TJSONObject; const Doc: IXMLDocument; AllowCleanup: Boolean);
var
  FileName, Root, Path, Value: string;
  Previous, Current: TJSONObject;
  A: TJSONArray;
  V: TJSONValue;
  Allowed: Boolean;

  procedure Preserve(Node: IXMLNode);
  var
    i: Integer;
    S: string;
  begin
    if Node = nil then
      Exit;
    if (Node.ChildNodes.Count = 0) and MatchText(Node.NodeName, ['image', 'box', 'thumbnail', 'logo', 'marquee', 'video', 'manual', 'tips', 'p2k', 'map', 'VideoPath', 'ManualPath']) then
    begin
      S := Node.Text;
      if SameText(Node.NodeName, 'map') and Node.HasAttribute('path') then
        S := Node.Attributes['path'];
      if (S <> '') and not TPath.IsPathRooted(S) then
        S := TPlatformPath.Combine(JStr(Sys, 'GamesAndRoms.Path'), NativePath(S));
      if TPath.IsPathRooted(S) and TFile.Exists(S) then
        FProduced.AddOrSetValue(PathKey(S), True);
    end;
    for i := 0 to Node.ChildNodes.Count - 1 do
      Preserve(Node.ChildNodes[i]);
  end;

begin
  if Terminated then
    Exit;
  Preserve(Doc.DocumentElement);
  FileName := TPlatformPath.Combine(FBase, NativePath('State\MediaIndex\') + THashSHA2.GetHashString(PathKey(JStr(Sys, 'GamesAndRoms.Path'))) + '.json');
  Previous := ReadJSON(FileName);
  Current := TJSONObject.Create;
  try
    if (Previous <> nil) and (JValue(Previous, 'files') is TJSONArray) then
      for V in TJSONArray(JValue(Previous, 'files')) do
      begin
        Path := PathKey(V.Value);
        if FProduced.ContainsKey(Path) then
          Continue;
        Allowed := False;
        for Root in FCleanupRoots.Keys do
          if IsPathWithin(Path, Root) then
          begin
            Allowed := True;
            Break;
          end;
      // Only files recorded by this application are candidates; unrelated files remain untouched.
        Allowed := Allowed and MatchText(TPath.GetExtension(Path), ['.png', '.jpg', '.jpeg', '.mp4', '.avi', '.mkv', '.mov', '.pdf', '.ini', '.cfg']);
        if Terminated then
          Exit;
        if Allowed and AllowCleanup and TFile.Exists(Path) then
        begin
          TFile.Delete(Path);
          Log(SK.Locale.L('Removed unused media: %s', [Path]));
        end
        else
          FProduced.AddOrSetValue(Path, True);
      end;
    A := TJSONArray.Create;
    for Value in FProduced.Keys do
      A.Add(Value);
    Current.AddPair('files', A);
    WriteJSON(FileName, Current);
  finally
    Previous.Free;
    Current.Free;
  end;
end;

procedure TScrapeWorker.PrepareTargetSystem(Sys: TJSONObject);
begin
  if FScenario.Active then
  begin
    FScenario.PrepareSystem(Sys);
    Exit;
  end;
  JSet(Sys, 'GameList.OnlyNew', TJSONBool.Create((FTargetRom = '') and JBool(FConfig, 'OnlyNew')));
  if (FTargetRom = '') and not JBool(Sys, 'GameList.OnlyNew') then
    Exit;
  if FTargetRom <> '' then
  begin
    if not (TFile.Exists(FTargetRom) or TDirectory.Exists(FTargetRom)) then
      raise Exception.Create(SK.Locale.L('ROM выбранной игры не найден'));
    if not IsPathWithin(FTargetRom, JStr(Sys, 'GamesAndRoms.Path')) then
      raise Exception.Create(SK.Locale.L('ROM находится вне папки выбранной платформы'));
  end;
  if JInt(Sys, 'GameList.Type', 1) = 0 then
  begin
    JSet(Sys, 'GameList.Type', TJSONNumber.Create(1));
    JSet(Sys, 'GameList.OutputFile', TJSONString.Create(TPlatformPath.Combine(JStr(Sys, 'GamesAndRoms.Path'), 'gamelist.xml')));
  end;
  JSet(Sys, 'GameList.Behavior', TJSONNumber.Create(2));
  if FTargetRom <> '' then
    JSet(Sys, 'GameList.Folders', TJSONNumber.Create(0));
  JSet(Sys, 'GameList.PreserveMissingMedia', TJSONBool.Create(True));
  JSet(Sys, 'GameList.PreserveHeader', TJSONBool.Create(True));
end;

function TScrapeWorker.FilterNewInputs(Sys: TJSONObject; const Files: TArray<string>): TArray<string>;
var
  Existing: TGameListWriter;
  FileName: string;
  Count: Integer;
begin
  Result := Files;
  if not JBool(Sys, 'GameList.OnlyNew') and not FScenario.Active then
    Exit;
  Existing := TGameListWriter.Create(Sys);
  try
    SetLength(Result, Length(Files));
    Count := 0;
    for FileName in Files do
    begin
      if Terminated then
        raise EAbort.Create('Cancelled');
      if (FScenario.Active and Existing.NeedsScenarioUpdate(FileName)) or
        (not FScenario.Active and not Existing.ContainsGame(FileName)) then
      begin
        Result[Count] := FileName;
        Inc(Count);
      end;
    end;
    SetLength(Result, Count);
    if FScenario.Active then
      Log(SK.Locale.L('Scenario %s (%s): %d games to update, %d skipped.',
        [FScenario.ID, FScenario.Field, Count, Length(Files) - Count]))
    else
      Log(SK.Locale.L('Only new: %d new games, %d already listed.', [Count, Length(Files) - Count]));
  finally
    Existing.Free;
  end;
end;

procedure TScrapeWorker.Execute;
var
  InputFiles: TArray<string>;
  Systems: TJSONArray;
  i, J: Integer;
  Sys, Master, User: TJSONObject;
  Value: TJSONValue;
begin
  BeginWorkerPlatform;
  try
    FAPI := TScreenScraper.Create(FCredentials, CacheLocation(FConfig, 'Cache/api'));
    FAPI.NetworkQueue := FNetworkQueue;
    FAPI.Offline := FOffline;
    try
      FAPI.IsCancelled :=
        function: Boolean
        begin
          Result := Terminated;
          if not Result and (FQueue <> nil) then
            Result := FQueue.Stopped;
        end;
      if Terminated then
        raise EAbort.Create('Cancelled');
      if FTaskSystem <> nil then
      begin
        RunInputQueue(FTaskSystem);
        Exit;
      end;
      if not FOffline and not JBool(FCredentials, 'anonymous') then
      begin
        SetStage('Authenticating');
        Log(SK.Locale.L('Authenticating with ScreenScraper…'));
        User := FAPI.Authenticate;
        try
          if JValue(User, 'response.ssuser') = nil then
            raise EScreenScraper.Create('Account validation failed.');
          FNetworkQueue.SetLimit(JInt(User, 'response.ssuser.maxthreads', 1));
          FEngineLimit := Max(MinimumScrapeWorkers, JInt(User, 'response.ssuser.maxthreads', 1));
          CaptureQuota(User);
        finally
          User.Free;
        end;
      end;
      TMonitor.Enter(FLock);
      try
        FStatus.Requests := FAPI.Requests;
      finally
        TMonitor.Exit(FLock)
      end;
      Systems := FConfig.GetValue<TJSONArray>('Systems');
      Master := FConfig.GetValue<TJSONObject>('AllSystems');
      TMonitor.Enter(FLock);
      try
        if FSelected >= 0 then
          FStatus.SystemsTotal := 1
        else
          FStatus.SystemsTotal := Systems.Count;
      finally
        TMonitor.Exit(FLock);
      end;
      SetStage('Scanning ROMs');
      for i := 0 to Systems.Count - 1 do
      begin
        if Terminated then
          raise EAbort.Create('Cancelled');
        if (FSelected >= 0) and (FSelected <> i) then
          Continue;
        Sys := Systems.Items[i].Clone as TJSONObject;
        try
          for J := 0 to High(SettingsGroups) do
            if JInt(Sys, 'Overriden') and SettingsGroupBits[J] = 0 then
            begin
              Value := JValue(Master, SettingsGroups[J]);
              if Value <> nil then
                JSet(Sys, SettingsGroups[J], Value.Clone as TJSONValue);
            end;
          JSet(Sys, 'GamesAndRoms.Path', TJSONString.Create(JStr(Systems.Items[i], 'GamesAndRoms.Path')));
          if (JValue(FConfig, 'FrontEnd.Type') <> nil) and (JInt(FConfig, 'FrontEnd.Type') = 0) then
            EnsureRecalboxMedia(Sys);
          ResolveFrontendPaths(Sys, JValue(FConfig, 'FrontEnd') as TJSONObject, FSystemCatalog);
          PrepareTargetSystem(Sys);
          InputFiles := ResumeInputs(Sys);
          FScanned.AddOrSetValue(THashSHA2.GetHashString(Sys.ToJSON), InputFiles);
          TMonitor.Enter(FLock);
          try
            Inc(FStatus.Total, Length(InputFiles) + InputFolderCount(Sys, InputFiles));
          finally
            TMonitor.Exit(FLock)
          end;
        finally
          Sys.Free
        end;
      end;
      FPlanReady := True;
      for i := 0 to Systems.Count - 1 do
      begin
        if Terminated then
          Break;
        if (FSelected >= 0) and (FSelected <> i) then
          Continue;
        Sys := Systems.Items[i].Clone as TJSONObject;
        try
          for J := 0 to High(SettingsGroups) do
            if JInt(Sys, 'Overriden') and SettingsGroupBits[J] = 0 then
            begin
              Value := JValue(Master, SettingsGroups[J]);
              if Value <> nil then
                JSet(Sys, SettingsGroups[J], Value.Clone as TJSONValue);
            end;
          JSet(Sys, 'GamesAndRoms.Path', TJSONString.Create(JStr(Systems.Items[i], 'GamesAndRoms.Path')));
          FLogFile := '';
          FVerbose := JBool(Sys, 'Miscellaneous.VerboseLogs');
          Trace('Preparing platform ' + JStr(Sys, 'SystemId') + ', matching method=' +
            JInt(Sys, 'Miscellaneous.Method').ToString);
          if JBool(Sys, 'Miscellaneous.SaveLogs') then
          begin
            try
              EnsureDirectory(FBase + 'Logs');
              FLogFile := TPlatformPath.Combine(FBase, NativePath('Logs\') + FormatDateTime('yyyymmdd-hhnnss', Now) + '-' + JStr(Sys, 'SystemId') + '.log');
              Log(SK.Locale.L('Scraping log started.'));
            except
              on E: Exception do
                Log(SK.Locale.L('Warning: file logging unavailable: %s', [E.Message]));
            end;
          end;
          try
            if (JValue(FConfig, 'FrontEnd.Type') <> nil) and (JInt(FConfig, 'FrontEnd.Type') = 0) then
              EnsureRecalboxMedia(Sys);
            ResolveFrontendPaths(Sys, JValue(FConfig, 'FrontEnd') as TJSONObject, FSystemCatalog);
            PrepareTargetSystem(Sys);
            ScrapeSystem(Sys);
          except
            on E: EAbort do
              Terminate;
            on E: Exception do
            begin
              if E is EScreenScraperFatal then
                Terminate;
              Log(SK.Locale.L('System error: %s', [E.Message]));
              TMonitor.Enter(FLock);
              try
                Inc(FStatus.Errors);
                FStatus.LastError := E.Message;
              finally
                TMonitor.Exit(FLock);
              end;
            end;
          end;
          TMonitor.Enter(FLock);
          try
            if not Terminated then
              Inc(FStatus.SystemsCompleted);
          finally
            TMonitor.Exit(FLock);
          end;
        finally
          Sys.Free;
        end;
      end;
      FQuotaTick := 0;
      RefreshQuota;
    except
      on E: EAbort do
        Terminate;
      on E: Exception do
      begin
        if E is EScreenScraperFatal then
          Terminate;
        Log(SK.Locale.L('Stopped: %s', [E.Message]));
        TMonitor.Enter(FLock);
        try
          Inc(FStatus.Errors);
          FStatus.LastError := E.Message;
        finally
          TMonitor.Exit(FLock);
        end;
      end;
    end;
  finally
    FreeAndNil(FAPI);
    TMonitor.Enter(FLock);
    try
      FStatus.Running := False;
      FStatus.Finished := True;
      FStatus.FinishedAt := Now;
      if Terminated then
        FStatus.Stage := 'Cancelled'
      else if FStatus.Errors > 0 then
        FStatus.Stage := 'Completed with errors'
      else
        FStatus.Stage := 'Completed';
      FStatus.Cancelled := Terminated;
      FStatus.CanResume := HasPendingWork;
    finally
      TMonitor.Exit(FLock);
    end;
    EndWorkerPlatform;
  end;
end;

end.

