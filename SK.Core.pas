unit SK.Core;

interface

uses
  System.SysUtils, System.Classes, System.Generics.Collections, System.JSON,
  System.IOUtils, System.Net.HttpClient, System.Net.URLClient,
  System.NetEncoding, System.Hash, System.DateUtils, SK.Platform;

type
  EScreenScraper = class(Exception);

  EScreenScraperFatal = class(EScreenScraper)
  private
    FStatusCode: Integer;
  public
    constructor CreateStatus(StatusCode: Integer; const MessageText: string);
    property StatusCode: Integer read FStatusCode;
  end;

  TScreenScraperNetworkQueue = class
  private
    FWaiting: TList<TObject>;
    FLimit, FActive: Integer;
    FStopped: Boolean;
    FStopReason: string;
    function GetPendingCount: Integer;
    function GetStopped: Boolean;
    function GetStopReason: string;
  public
    constructor Create(Limit: Integer);
    destructor Destroy; override;
    procedure SetLimit(Limit: Integer);
    procedure Acquire(const Cancel: TFunc<Boolean>);
    procedure Release;
    procedure Stop(const Reason: string);
    property PendingCount: Integer read GetPendingCount;
    property Stopped: Boolean read GetStopped;
    property StopReason: string read GetStopReason;
  end;

  TSkraperConfig = class
  private
    FRoot: TJSONObject;
    FCredentials: TJSONObject;
    FBase: string;
  public
    constructor Create(const Base: string);
    constructor CreateSnapshot(Source: TSkraperConfig);
    destructor Destroy; override;
    procedure Save;
    procedure SaveCredentials;
    procedure Load(const FileName: string);
    procedure ReplaceWith(Source: TSkraperConfig);
    procedure ResetSystemSettings(Index: Integer; Catalog: TJSONObject = nil);
    function DialogFolder(const Key, Current: string): string;
    procedure RememberFolder(const Key, Folder: string);
    function SystemAt(Index: Integer): TJSONObject;
    function EffectiveSystem(Index: Integer): TJSONObject;
    property Root: TJSONObject read FRoot;
    property Credentials: TJSONObject read FCredentials;
    property Base: string read FBase;
  end;

  TScreenScraper = class
  private
    FHttp: THTTPClient;
    FCredentials: TJSONObject;
    FCache: string;
    function NetworkGet(const URL: string; Stream: TStream = nil; CountRequest: Boolean = False): IHTTPResponse;
    procedure ReceiveData(const Sender: TObject; AContentLength, AReadCount: Int64; var Abort: Boolean);
    function RequestUnlocked(const Endpoint, Params: string; Cacheable: Boolean): TJSONObject;
    procedure DownloadUnlocked(const URL, FileName: string);
    procedure CheckCancellation;
    procedure WaitRetry(Delay: Cardinal);
    function AuthURL(const URL: string): string;
    function CredentialValue(const Key: string): string;
  public
    ScopeSystemID: Integer;
    CacheDays: Integer;
    Offline: Boolean;
    Retries: Integer;
    Requests: Integer;
    CacheHits: Integer;
    IsCancelled: TFunc<Boolean>;
    NetworkQueue: TScreenScraperNetworkQueue;
    Diagnostic: TProc<string>;
    constructor Create(Credentials: TJSONObject; const Cache: string);
    destructor Destroy; override;
    function Request(const Endpoint, Params: string; Cacheable: Boolean = True): TJSONObject;
    procedure Download(const URL, FileName: string);
    function Authenticate: TJSONObject;
    function Systems: TJSONObject;
  end;

function AccountCredentialValue(Credentials: TJSONObject; const Key: string): string;

procedure CheckScreenScraperHTTPStatus(StatusCode: Integer; const Context: string);

function SharedResourceLock(const Key: string): TObject;

function JStr(Obj: TJSONValue; const Path: string; const Default: string = ''): string;

function JInt(Obj: TJSONValue; const Path: string; Default: Integer = 0): Integer;

function JBool(Obj: TJSONValue; const Path: string; Default: Boolean = False): Boolean;

function JValue(Obj: TJSONValue; const Path: string): TJSONValue;

procedure JSet(Obj: TJSONObject; const Path: string; Value: TJSONValue);

function Encode(const S: string): string;

function AppBase: string;

function ReadJSON(const FileName: string): TJSONObject;

procedure WriteJSON(const FileName: string; Obj: TJSONValue);

procedure SanitizeResponse(Obj: TJSONValue);

procedure CommitFile(const Temporary, Destination: string);

implementation

uses
  SK.Consts, SK.Catalog, SK.Cache, System.RegularExpressions;

var
  ResourceGuard: TObject;
  ResourceLocks: TObjectDictionary<string, TObject>;

function SharedResourceLock(const Key: string): TObject;
begin
  TMonitor.Enter(ResourceGuard);
  try
    if not ResourceLocks.TryGetValue(Key, Result) then
    begin
      Result := TObject.Create;
      ResourceLocks.Add(Key, Result)
    end;
  finally
    TMonitor.Exit(ResourceGuard)
  end;
end;

procedure CommitFile(const Temporary, Destination: string);
begin
  AtomicReplace(Temporary, Destination)
end;

procedure SanitizeResponse(Obj: TJSONValue);
var
  P: TJSONPair;
  V: TJSONValue;
  I: Integer;
  S: string;
begin
  if Obj is TJSONObject then
  begin
    TJSONObject(Obj).RemovePair('header').Free;
    for I := TJSONObject(Obj).Count - 1 downto 0 do
    begin
      P := TJSONObject(Obj).Pairs[I];
      if P.JsonValue is TJSONString then
      begin
        S := P.JsonValue.Value;
        if S.StartsWith('http') then
        begin
          S := TRegEx.Replace(S, '([?&])(devid|devpassword|ssid|sspassword)=[^&]*', '$1', [roIgnoreCase]);
          while S.Contains('&&') do
            S := S.Replace('&&', '&');
          S := S.Replace('?&', '?').TrimRight(['?', '&']);
          if S <> P.JsonValue.Value then
            JSet(TJSONObject(Obj), P.JsonString.Value, TJSONString.Create(S));
        end;
      end
      else
        SanitizeResponse(P.JsonValue);
    end;
  end
  else if Obj is TJSONArray then
    for V in TJSONArray(Obj) do
      SanitizeResponse(V);
end;

function AppBase: string;
begin
  Result := ResourceBase
end;

function Encode(const S: string): string;
begin
  Result := TNetEncoding.URL.EncodeQuery(S);
end;

function JValue(Obj: TJSONValue; const Path: string): TJSONValue;
var
  Part: string;
begin
  Result := Obj;
  if Path = '' then
    Exit;
  for Part in Path.Split(['.']) do
  begin
    if not (Result is TJSONObject) then
      Exit(nil);
    Result := TJSONObject(Result).GetValue(Part);
  end;
end;

function JStr(Obj: TJSONValue; const Path, Default: string): string;
var
  V: TJSONValue;
begin
  V := JValue(Obj, Path);
  if (V = nil) or (V is TJSONNull) then
    Result := Default
  else
    Result := V.Value;
end;

function JInt(Obj: TJSONValue; const Path: string; Default: Integer): Integer;
begin
  Result := StrToIntDef(JStr(Obj, Path), Default);
end;

function JBool(Obj: TJSONValue; const Path: string; Default: Boolean): Boolean;
begin
  Result := SameText(JStr(Obj, Path, BoolToStr(Default, True)), 'true');
end;

procedure JSet(Obj: TJSONObject; const Path: string; Value: TJSONValue);
var
  Parts: TArray<string>;
  I: Integer;
  V: TJSONValue;
  P: TJSONPair;
begin
  Parts := Path.Split(['.']);
  for I := 0 to High(Parts) - 1 do
  begin
    V := Obj.GetValue(Parts[I]);
    if not (V is TJSONObject) then
    begin
      P := Obj.RemovePair(Parts[I]);
      P.Free;
      V := TJSONObject.Create;
      Obj.AddPair(Parts[I], V);
    end;
    Obj := TJSONObject(V);
  end;
  P := Obj.RemovePair(Parts[High(Parts)]);
  P.Free;
  Obj.AddPair(Parts[High(Parts)], Value);
end;

function ReadJSON(const FileName: string): TJSONObject;
var
  V: TJSONValue;
begin
  Result := nil;
  if not TFile.Exists(FileName) then
    Exit;
  V := TJSONObject.ParseJSONValue(TFile.ReadAllText(FileName, TEncoding.UTF8));
  if V is TJSONObject then
    Result := TJSONObject(V)
  else
    V.Free;
end;

procedure WriteJSON(const FileName: string; Obj: TJSONValue);
var
  Temporary: string;
  Lock: TObject;
begin
  if Obj = nil then
    raise EArgumentNilException.Create('JSON document');
  ForceDirectories(ExtractFilePath(FileName));
  Temporary := FileName + '.' + TGUID.NewGuid.ToString + '.tmp';
  Lock := SharedResourceLock('json|' + PathKey(FileName));
  TMonitor.Enter(Lock);
  try
    TFile.WriteAllText(Temporary, Obj.Format(2), TEncoding.UTF8);
    if TFile.Exists(FileName) then
      TFile.Copy(FileName, FileName + '.bak', True);
    CommitFile(Temporary, FileName);
  finally
    try
      if TFile.Exists(Temporary) then
        TFile.Delete(Temporary);
    finally
      TMonitor.Exit(Lock)
    end;
  end;
end;

constructor TSkraperConfig.Create(const Base: string);
var
  Secret: string;
  Parsed: TJSONValue;
  Defaults, Previous: TJSONObject;
  Fresh: Boolean;
begin
  inherited Create;
  FBase := IncludeTrailingPathDelimiter(Base);
  ForceDirectories(FBase);
  Previous := ReadJSON(FBase + ConfigFileName);
  try
    Fresh := (Previous = nil) or (JInt(Previous, 'ConfigVersion') <> ConfigSchemaVersion)
  finally
    Previous.Free
  end;
  if Fresh then
  begin
    Defaults := ReadJSON(TPlatformPath.Combine(AppBase, DefaultConfigPath));
    if Defaults = nil then
      raise Exception.Create('Default configuration is missing from application resources');
    try
      JSet(Defaults, 'Systems', TJSONArray.Create);
      JSet(Defaults, 'AllSystems.GamesAndRoms.Path', TJSONString.Create(''));
      JSet(Defaults, 'IsConfigured', TJSONBool.Create(False));
      JSet(Defaults, 'ConfigVersion', TJSONNumber.Create(ConfigSchemaVersion));
      WriteJSON(FBase + ConfigFileName, Defaults);
    finally
      Defaults.Free
    end;
  end;
  Load(FBase + ConfigFileName);
  FCredentials := TJSONObject.Create;
  Secret := LoadSecret(FBase + CredentialsFileName);
  if Secret <> '' then
  begin
    Parsed := TJSONObject.ParseJSONValue(Secret);
    if not (Parsed is TJSONObject) then
    begin
      Parsed.Free;
      raise Exception.Create('Invalid saved credentials')
    end;
    FCredentials.Free;
    FCredentials := TJSONObject(Parsed);
  end;
end;

constructor TSkraperConfig.CreateSnapshot(Source: TSkraperConfig);
begin
  inherited Create;
  FBase := Source.FBase;
  FRoot := Source.FRoot.Clone as TJSONObject;
  FCredentials := Source.FCredentials.Clone as TJSONObject;
end;

procedure TSkraperConfig.ReplaceWith(Source: TSkraperConfig);
var
  RootCopy, CredentialCopy: TJSONObject;
begin
  RootCopy := Source.FRoot.Clone as TJSONObject;
  try
    CredentialCopy := Source.FCredentials.Clone as TJSONObject
  except
    RootCopy.Free;
    raise
  end;
  FRoot.Free;
  FCredentials.Free;
  FRoot := RootCopy;
  FCredentials := CredentialCopy;
end;

destructor TSkraperConfig.Destroy;
begin
  FCredentials.Free;
  FRoot.Free;
  inherited;
end;

procedure TSkraperConfig.Load(const FileName: string);
var
  NewRoot: TJSONObject;
  Sys: TJSONValue;
begin
  NewRoot := ReadJSON(FileName);
  if (NewRoot = nil) or not (JValue(NewRoot, 'AllSystems') is TJSONObject) or
    not (JValue(NewRoot, 'Systems') is TJSONArray) then
  begin
    NewRoot.Free;
    raise Exception.Create('Invalid Skraper configuration: ' + FileName);
  end;
  if JValue(NewRoot, 'AllSystems.MetaData.ParseRomFileName') = nil then
    JSet(NewRoot, 'AllSystems.MetaData.ParseRomFileName', TJSONBool.Create(True));
  for Sys in TJSONArray(JValue(NewRoot, 'Systems')) do
    if (JValue(Sys, 'MetaData') is TJSONObject) and (JValue(Sys, 'MetaData.ParseRomFileName') = nil) then
      JSet(Sys as TJSONObject, 'MetaData.ParseRomFileName', TJSONBool.Create(True));
  JSet(NewRoot, 'ConfigVersion', TJSONNumber.Create(ConfigSchemaVersion));
  FRoot.Free;
  FRoot := NewRoot;
end;

procedure TSkraperConfig.ResetSystemSettings(Index: Integer; Catalog: TJSONObject);
var
  I: Integer;
  Sys: TJSONObject;
  A: TJSONArray;
  Loaded: TJSONObject;
begin
  Loaded := nil;
  try
    if Catalog = nil then
    begin
      Loaded := ReadJSON(TPlatformPath.Combine(FBase, SystemsCatalogPath));
      if Loaded = nil then
        Loaded := ReadJSON(TPlatformPath.Combine(AppBase, SystemsCatalogPath));
      Catalog := Loaded;
    end;
    A := FRoot.GetValue<TJSONArray>('Systems');
    for I := 0 to A.Count - 1 do
    begin
      if (Index >= 0) and (I <> Index) then
        Continue;
      Sys := A.Items[I] as TJSONObject;
      ConfigurePlatform(Sys, SystemAt(-1), Catalog, JInt(FRoot, 'FrontEnd.Type'),
        PlatformIDs(Sys), JStr(Sys, 'GamesAndRoms.Path'));
    end;
  finally
    Loaded.Free
  end;
end;

function TSkraperConfig.DialogFolder(const Key, Current: string): string;
var
  Candidate: string;
begin
  Candidate := Current.Trim;
  if not Candidate.Contains('%') then
  begin
    if TDirectory.Exists(Candidate) then
      Exit(Candidate);
    if TFile.Exists(Candidate) then
      Exit(ExtractFilePath(Candidate));
    Candidate := ExtractFilePath(Candidate);
    if (Candidate <> '') and TDirectory.Exists(Candidate) then
      Exit(Candidate);
  end;
  Candidate := JStr(FRoot, 'MRU.' + Key);
  if (Candidate <> '') and TDirectory.Exists(Candidate) then
    Exit(Candidate);
  Candidate := JStr(FRoot, 'AllSystems.GamesAndRoms.Path');
  if (Candidate <> '') and TDirectory.Exists(Candidate) then
    Exit(Candidate);
  Result := '';
end;

procedure TSkraperConfig.RememberFolder(const Key, Folder: string);
begin
  if (Folder <> '') and TDirectory.Exists(Folder) then
    JSet(FRoot, 'MRU.' + Key, TJSONString.Create(TPath.GetFullPath(Folder)));
end;

procedure TSkraperConfig.Save;
begin
  WriteJSON(FBase + ConfigFileName, FRoot);
end;

procedure TSkraperConfig.SaveCredentials;
begin
  SaveSecret(FBase + CredentialsFileName, FCredentials.ToJSON)
end;

function TSkraperConfig.SystemAt(Index: Integer): TJSONObject;
begin
  if Index < 0 then
    Result := FRoot.GetValue<TJSONObject>('AllSystems')
  else
    Result := FRoot.GetValue<TJSONArray>('Systems').Items[Index] as TJSONObject;
end;

function TSkraperConfig.EffectiveSystem(Index: Integer): TJSONObject;
var
  Src, Master: TJSONObject;
  I: Integer;
  V: TJSONValue;
begin
  Src := SystemAt(Index);
  Result := Src.Clone as TJSONObject;
  if Index < 0 then
    Exit;
  Master := SystemAt(-1);
  for I := 0 to High(SettingsGroups) do
    if JInt(Src, 'Overriden') and SettingsGroupBits[I] = 0 then
    begin
      V := JValue(Master, SettingsGroups[I]);
      if V <> nil then
        JSet(Result, SettingsGroups[I], V.Clone as TJSONValue);
    end;
  JSet(Result, 'GamesAndRoms.Path', TJSONString.Create(JStr(Src, 'GamesAndRoms.Path')));
end;

constructor TScreenScraperNetworkQueue.Create(Limit: Integer);
begin
  inherited Create;
  FWaiting := TList<TObject>.Create;
  SetLimit(Limit);
end;

destructor TScreenScraperNetworkQueue.Destroy;
begin
  // The coordinator joins its workers before disposing of their shared queue.
  FWaiting.Free;
  inherited;
end;

procedure TScreenScraperNetworkQueue.SetLimit(Limit: Integer);
begin
  TMonitor.Enter(Self);
  try
    if Limit < 1 then
      Limit := 1;
    FLimit := Limit;
  finally
    TMonitor.Exit(Self);
  end;
end;

function TScreenScraperNetworkQueue.GetPendingCount: Integer;
begin
  TMonitor.Enter(Self);
  try
    Result := FWaiting.Count;
  finally
    TMonitor.Exit(Self);
  end;
end;

function TScreenScraperNetworkQueue.GetStopped: Boolean;
begin
  TMonitor.Enter(Self);
  try
    Result := FStopped;
  finally
    TMonitor.Exit(Self);
  end;
end;

function TScreenScraperNetworkQueue.GetStopReason: string;
begin
  TMonitor.Enter(Self);
  try
    Result := FStopReason;
  finally
    TMonitor.Exit(Self);
  end;
end;

procedure TScreenScraperNetworkQueue.Acquire(const Cancel: TFunc<Boolean>);
var
  Ticket: TObject;
begin
  Ticket := TObject.Create;
  try
    TMonitor.Enter(Self);
    try
      FWaiting.Add(Ticket);
    finally
      TMonitor.Exit(Self);
    end;
    repeat
      if Assigned(Cancel) and Cancel() then
        raise EAbort.Create('Cancelled');
      TMonitor.Enter(Self);
      try
        if FStopped then
          raise EAbort.Create('Network queue stopped');
        if (FActive < FLimit) and (FWaiting[0] = Ticket) then
        begin
          FWaiting.Delete(0);
          Inc(FActive);
          Exit;
        end;
      finally
        TMonitor.Exit(Self);
      end;
      TThread.Sleep(CancellationPollMs);
    until False;
  finally
    TMonitor.Enter(Self);
    try
      FWaiting.Remove(Ticket);
    finally
      TMonitor.Exit(Self);
    end;
    Ticket.Free;
  end;
end;

procedure TScreenScraperNetworkQueue.Release;
begin
  TMonitor.Enter(Self);
  try
    Dec(FActive);
  finally
    TMonitor.Exit(Self);
  end;
end;

procedure TScreenScraperNetworkQueue.Stop(const Reason: string);
begin
  TMonitor.Enter(Self);
  try
    if not FStopped then
    begin
      FStopped := True;
      FStopReason := Reason;
    end;
  finally
    TMonitor.Exit(Self);
  end;
end;

constructor TScreenScraper.Create(Credentials: TJSONObject; const Cache: string);
begin
  inherited Create;
  FCredentials := Credentials.Clone as TJSONObject;
  FCache := Cache;
  FHttp := THTTPClient.Create;
  FHttp.ConnectionTimeout := HTTPConnectionTimeoutMs;
  FHttp.ResponseTimeout := HTTPResponseTimeoutMs;
  FHttp.OnReceiveData := ReceiveData;
  FHttp.UserAgent := AppUserAgent;
  Retries := HTTPRetryCount;
  CacheDays := DefaultCacheDays;
end;

procedure TScreenScraper.CheckCancellation;
begin
  if Assigned(IsCancelled) and IsCancelled() then
    raise EAbort.Create('Cancelled');
end;

function TScreenScraper.NetworkGet(const URL: string; Stream: TStream; CountRequest: Boolean): IHTTPResponse;
var
  Context: string;
begin
  if NetworkQueue <> nil then
    NetworkQueue.Acquire(IsCancelled);
  try
    CheckCancellation;
    if CountRequest then
      Inc(Requests);
    if Stream = nil then
      Result := FHttp.Get(URL)
    else
      Result := FHttp.Get(URL, Stream);
    CheckCancellation;
    try
      if Stream = nil then
        Context := 'ScreenScraper'
      else
        Context := 'Media';
      CheckScreenScraperHTTPStatus(Result.StatusCode, Context);
    except
      on E: EScreenScraperFatal do
      begin
        // Stop admission before releasing this slot, so queued requests never
        // race ahead of the worker reporting a fatal response to its coordinator.
        if NetworkQueue <> nil then
          NetworkQueue.Stop(E.Message);
        raise;
      end;
    end;
  finally
    if NetworkQueue <> nil then
      NetworkQueue.Release;
  end;
end;

procedure TScreenScraper.WaitRetry(Delay: Cardinal);
var
  Started, Elapsed: UInt64;
begin
  Started := TThread.GetTickCount64;
  repeat
    CheckCancellation;
    Elapsed := TThread.GetTickCount64 - Started;
    if Elapsed >= Delay then
      Exit;
    if Delay - Elapsed > CancellationPollMs then
      TThread.Sleep(CancellationPollMs)
    else
      TThread.Sleep(Delay - Elapsed);
  until False;
end;

procedure TScreenScraper.ReceiveData(const Sender: TObject; AContentLength, AReadCount: Int64; var Abort: Boolean);
begin
  Abort := Assigned(IsCancelled) and IsCancelled();
end;

function AccountCredentialValue(Credentials: TJSONObject; const Key: string): string;
begin
  if JBool(Credentials, 'anonymous') then
  begin
    if Key = 'ssid' then
      Exit('_anonymous_');
    if Key = 'sspassword' then
      Exit('_no_paswword_');
  end;
  Result := JStr(Credentials, Key);
end;

function TScreenScraper.CredentialValue(const Key: string): string;
begin
  Result := AccountCredentialValue(FCredentials, Key)
end;

function TScreenScraper.AuthURL(const URL: string): string;
var
  Key: string;
begin
  Result := URL;
  for Key in ScreenScraperCredentialKeys do
    if not Result.ToLower.Contains(Key + '=') then
    begin
      if Result.Contains('?') then
        Result := Result + '&'
      else
        Result := Result + '?';
      Result := Result + Key + '=' + Encode(CredentialValue(Key));
    end;
end;

destructor TScreenScraper.Destroy;
begin
  FHttp.Free;
  FCredentials.Free;
  inherited;
end;

constructor EScreenScraperFatal.CreateStatus(StatusCode: Integer; const MessageText: string);
begin
  inherited Create(MessageText);
  FStatusCode := StatusCode;
end;

procedure CheckScreenScraperHTTPStatus(StatusCode: Integer; const Context: string);
begin
  case StatusCode of
    HTTPUnauthorized, HTTPForbidden:
      raise EScreenScraperFatal.CreateStatus(StatusCode, Context + ' rejected the account or application credentials (HTTP ' + StatusCode.ToString + ').');
    HTTPServerLocked:
      raise EScreenScraperFatal.CreateStatus(StatusCode, Context + ' server is unavailable or locked (HTTP 423). Retry later.');
    HTTPUpgradeRequired:
      raise EScreenScraperFatal.CreateStatus(StatusCode, Context + ' requires an application update (HTTP 426).');
    HTTPTooManyRequests:
      raise EScreenScraperFatal.CreateStatus(StatusCode, Context + ' request limit reached (HTTP 429). Retry later.');
    HTTPDailyQuotaExceeded:
      raise EScreenScraperFatal.CreateStatus(StatusCode, Context + ' daily scrape quota reached (HTTP 430). Retry after the quota resets.');
    HTTPFailedRequestQuotaExceeded:
      raise EScreenScraperFatal.CreateStatus(StatusCode, Context + ' failed-request quota reached (HTTP 431). Retry after the quota resets.');
  end;
end;

function TScreenScraper.Request(const Endpoint, Params: string; Cacheable: Boolean): TJSONObject;
var
  Lock: TObject;
begin
  Lock := SharedResourceLock('api|' + FCache + '|' + Endpoint + '?' + Params);
  CheckCancellation;
  while not TMonitor.Enter(Lock, ResourceLockPollMs) do
    CheckCancellation;
  try
    CheckCancellation;
    Result := RequestUnlocked(Endpoint, Params, Cacheable);
  finally
    TMonitor.Exit(Lock)
  end;
end;

function TScreenScraper.RequestUnlocked(const Endpoint, Params: string; Cacheable: Boolean): TJSONObject;
var
  URL, FileName, Key, S: string;
  Response: IHTTPResponse;
  Attempt: Integer;
  V: TJSONValue;
begin
  Result := nil;
  FileName := TPlatformPath.Combine(FCache, THashSHA2.GetHashString(Endpoint + '?' + Params) + '.json');
  if Cacheable and (CacheDays <> 0) and TFile.Exists(FileName) and
    ((CacheDays >= UnlimitedCacheDays) or (DaysBetween(Now, TFile.GetLastWriteTime(FileName)) < CacheDays)) then
  begin
    Result := ReadJSON(FileName);
    if Result <> nil then
    begin
      RegisterCacheFile(TDirectory.GetParent(TDirectory.GetParent(FCache)), ScopeSystemID, 'api', FileName);
      Inc(CacheHits);
      if Assigned(Diagnostic) then
        Diagnostic('API cache hit: ' + Endpoint);
      Exit;
    end;
  end;
  if Offline then
    raise EScreenScraper.Create('Offline cache miss: ' + Endpoint);
  URL := ScreenScraperAPIBaseURL + Endpoint + '?output=json&softname=' + Encode(AppBrand);
  for Key in ScreenScraperCredentialKeys do
  begin
    S := CredentialValue(Key);
    if S = '' then
      raise EScreenScraper.Create('Missing ScreenScraper credential: ' + Key);
    URL := URL + '&' + Key + '=' + Encode(S);
  end;
  if Params <> '' then
    URL := URL + '&' + Params;
  for Attempt := 0 to Retries do
  begin
    if Assigned(Diagnostic) then
      Diagnostic('API request: ' + Endpoint + ', attempt=' + (Attempt + 1).ToString);
    if Assigned(IsCancelled) and IsCancelled() then
      raise EAbort.Create('Cancelled');
    try
      Response := NetworkGet(URL, nil, True);
    except
      on E: EAbort do
        raise;
      on E: EScreenScraperFatal do
        raise;
      on E: Exception do
      begin
        if Assigned(IsCancelled) and IsCancelled() then
          raise EAbort.Create('Cancelled');
        if Attempt = Retries then
          raise EScreenScraper.Create('ScreenScraper connection failed. Check network access.');
        WaitRetry(APIBackoffMs * (Attempt + 1));
        Continue;
      end;
    end;
    CheckCancellation;
    if Response.StatusCode = HTTPNotFound then
      Exit;
    if Response.StatusCode <> HTTPOK then
    begin
      if Attempt = Retries then
        raise EScreenScraper.Create('ScreenScraper HTTP ' + Response.StatusCode.ToString);
      WaitRetry(APIBackoffMs * (Attempt + 1));
      Continue;
    end;
    S := Response.ContentAsString(TEncoding.UTF8);
    V := TJSONObject.ParseJSONValue(S);
    if not (V is TJSONObject) then
    begin
      V.Free;
      raise EScreenScraper.Create('ScreenScraper returned a non-JSON response. Service may be unavailable.');
    end;
    Result := TJSONObject(V);
    // Never cache the server header: it can echo the credential-bearing URL.
    SanitizeResponse(Result);
    if Cacheable and (CacheDays <> 0) then
    begin
      WriteJSON(FileName, Result);
      RegisterCacheFile(TDirectory.GetParent(TDirectory.GetParent(FCache)), ScopeSystemID, 'api', FileName);
    end;
    Exit;
  end;
end;

procedure TScreenScraper.Download(const URL, FileName: string);
var
  Lock: TObject;
begin
  Lock := SharedResourceLock('download|' + PathKey(FileName));
  CheckCancellation;
  while not TMonitor.Enter(Lock, ResourceLockPollMs) do
    CheckCancellation;
  try
    CheckCancellation;
    if Assigned(IsCancelled) and IsCancelled() then
      raise EAbort.Create('Cancelled');
    if not TFile.Exists(FileName) then
      DownloadUnlocked(URL, FileName);
  finally
    TMonitor.Exit(Lock)
  end;
end;

procedure TScreenScraper.DownloadUnlocked(const URL, FileName: string);
var
  Stream: TFileStream;
  Response: IHTTPResponse;
  Parsed: TURI;
  Attempt: Integer;
begin
  if Offline then
    raise EScreenScraper.Create('Offline media cache miss');
  Parsed := TURI.Create(URL);
  if not SameText(Parsed.Scheme, 'https') or not
    (SameText(Parsed.Host, ScreenScraperMediaHost) or Parsed.Host.ToLower.EndsWith('.' + ScreenScraperMediaHost)) then
    raise EScreenScraper.Create('Unexpected media host.');
  ForceDirectories(ExtractFilePath(FileName));
  try
    for Attempt := 0 to Retries do
    begin
      if Assigned(IsCancelled) and IsCancelled() then
        raise EAbort.Create('Cancelled');
      Stream := TFileStream.Create(FileName + '.part', fmCreate);
      try
        Response := nil;
        try
          Response := NetworkGet(AuthURL(URL), Stream);
        except
          on E: EAbort do
            raise;
          on E: EScreenScraperFatal do
            raise;
          on E: Exception do
          begin
            if Assigned(IsCancelled) and IsCancelled() then
              raise EAbort.Create('Cancelled');
            if Attempt = Retries then
              raise EScreenScraper.Create('Media connection failed. Check network access.');
          end;
        end;
        if Assigned(IsCancelled) and IsCancelled() then
          raise EAbort.Create('Cancelled');
        if Response <> nil then
        begin
          if Response.StatusCode = HTTPOK then
            Break;
          if (Attempt = Retries) or (Response.StatusCode = HTTPNotFound) then
            raise EScreenScraper.Create('Media HTTP ' + Response.StatusCode.ToString);
        end;
      finally
        Stream.Free;
      end;
      WaitRetry(MediaBackoffMs * (Attempt + 1));
    end;
    CommitFile(FileName + '.part', FileName);
  finally
    if TFile.Exists(FileName + '.part') then
      TFile.Delete(FileName + '.part');
  end;
end;

function TScreenScraper.Authenticate: TJSONObject;
begin
  Result := Request(UserInfoEndpoint, '', False);
end;

function TScreenScraper.Systems: TJSONObject;
begin
  Result := Request(SystemsEndpoint, '', True);
end;

initialization
  ResourceGuard := TObject.Create;
  ResourceLocks := TObjectDictionary<string, TObject>.Create([doOwnsValues]);

finalization
  ResourceLocks.Free;
  ResourceGuard.Free;

end.

