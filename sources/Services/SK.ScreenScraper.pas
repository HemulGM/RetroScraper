unit SK.ScreenScraper;

interface

uses
  System.SysUtils, System.Classes, System.Generics.Collections, System.JSON,
  System.Net.HttpClient, System.Net.URLClient;

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

  TScreenScraper = class
  private
    FHttp: THTTPClient;
    FCredentials: TJSONObject;
    FCache: string;
    procedure ReportLookupMiss(const Endpoint, Params: string; FromCache: Boolean);
    function NetworkGet(const URL: string; Stream: TStream = nil; CountRequest: Boolean = False): IHTTPResponse;
    procedure ReceiveData(const Sender: TObject; AContentLength, AReadCount: Int64; var Abort: Boolean);
    function RequestUnlocked(const Endpoint, Params: string; Cacheable: Boolean): TJSONObject;
    procedure DownloadUnlocked(const URL, FileName: string);
    procedure CheckCancellation;
    procedure WaitRetry(Delay: Cardinal);
    function AuthURL(const URL: string): string;
    function CredentialValue(const Key: string): string;
  protected
    function MetadataGet(const URL: string; out Body: string): Integer; virtual;
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
    LookupMiss: TProc<string>;
    constructor Create(Credentials: TJSONObject; const Cache: string);
    destructor Destroy; override;
    function Request(const Endpoint, Params: string; Cacheable: Boolean = True): TJSONObject;
    procedure Download(const URL, FileName: string);
    function Authenticate: TJSONObject;
    function Systems: TJSONObject;
  end;

function AccountCredentialValue(Credentials: TJSONObject; const Key: string): string;

function HasApplicationCredentials: Boolean;

procedure CheckScreenScraperHTTPStatus(StatusCode: Integer; const Context: string);

function Encode(const S: string): string;

procedure SanitizeResponse(Obj: TJSONValue);

implementation

uses
  System.IOUtils, System.NetEncoding, System.Hash, System.DateUtils,
  System.RegularExpressions, SK.Json, SK.Storage, SK.Platform, SK.Consts,
  SK.Cache, SK.Locale;

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

function Encode(const S: string): string;
begin
  Result := TNetEncoding.URL.EncodeQuery(S);
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

{$I SK.ScreenScraper.Application.inc}

function HasApplicationCredentials: Boolean;
begin
  Result := (ScreenScraperApplicationID <> '') and (ScreenScraperApplicationPassword <> '');
end;

function AccountCredentialValue(Credentials: TJSONObject; const Key: string): string;
begin
  if ((Key = 'devid') or (Key = 'devpassword')) and
    ((JStr(Credentials, 'devid').Trim = '') or (JStr(Credentials, 'devpassword') = '')) and
    HasApplicationCredentials then
  begin
    if Key = 'devid' then
      Exit(TNetEncoding.Base64.Decode(ScreenScraperApplicationID));
    Exit(TNetEncoding.Base64.Decode(ScreenScraperApplicationPassword));
  end;
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
  Activity: IInterface;
begin
  if FCache <> '' then
    Activity := CacheActivity(TPlatformPath.Combine(FCache,
      THashSHA2.GetHashString(Endpoint + '?' + Params) + '.json'));
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

procedure TScreenScraper.ReportLookupMiss(const Endpoint, Params: string; FromCache: Boolean);
var
  Source, MessageText: string;
begin
  if FromCache then
    Source := L('negative cache (HTTP 404)')
  else
    Source := L('server HTTP 404');
  MessageText := L('Lookup miss: %s — %s; no ROM/game matched the supplied platform and identification.',
    [Endpoint + '?' + Params, Source]);
  if Assigned(LookupMiss) then
    LookupMiss(MessageText)
  else if Assigned(Diagnostic) then
    Diagnostic(MessageText);
end;

function TScreenScraper.MetadataGet(const URL: string; out Body: string): Integer;
var
  Response: IHTTPResponse;
begin
  Body := '';
  Response := NetworkGet(URL, nil, True);
  Result := Response.StatusCode;
  if Result = HTTPOK then
    Body := Response.ContentAsString(TEncoding.UTF8);
end;

function TScreenScraper.RequestUnlocked(const Endpoint, Params: string; Cacheable: Boolean): TJSONObject;
var
  URL, FileName, Key, S: string;
  StatusCode: Integer;
  Attempt: Integer;
  Negative: Boolean;
  Age: TDateTime;
  V: TJSONValue;
begin
  Result := nil;
  FileName := '';
  if FCache <> '' then
    FileName := TPlatformPath.Combine(FCache, THashSHA2.GetHashString(Endpoint + '?' + Params) + '.json');
  if (FCache <> '') and Cacheable and (CacheDays <> 0) and TFile.Exists(FileName) then
  begin
    Result := ReadJSON(FileName);
    if Result <> nil then
    begin
      Negative := JBool(Result, '_screenscraper_not_found');
      Age := Now - TFile.GetLastWriteTime(FileName);
      // Negative entries live for one week independently of positive-cache TTL.
      if (Negative and ((Age < 0) or (Age >= 7))) or
        (not Negative and (CacheDays < UnlimitedCacheDays) and
          (DaysBetween(Now, TFile.GetLastWriteTime(FileName)) >= CacheDays)) then
        FreeAndNil(Result)
      else
      begin
        RegisterCacheFile(TDirectory.GetParent(TDirectory.GetParent(FCache)), ScopeSystemID, 'api', FileName);
        Inc(CacheHits);
        if Negative then
        begin
          FreeAndNil(Result);
          ReportLookupMiss(Endpoint, Params, True);
          Exit;
        end;
        if Assigned(Diagnostic) then
          Diagnostic(L('API cache hit: %s', [Endpoint]));
        Exit;
      end;
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
      Diagnostic(L('API request: %s, attempt=%d', [Endpoint, Attempt + 1]));
    if Assigned(IsCancelled) and IsCancelled() then
      raise EAbort.Create('Cancelled');
    try
      StatusCode := MetadataGet(URL, S);
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
    if StatusCode = HTTPNotFound then
    begin
      if Endpoint = GameInfoEndpoint then
      begin
        ReportLookupMiss(Endpoint, Params, False);
        if (FCache <> '') and Cacheable and (CacheDays <> 0) then
        begin
          V := TJSONObject.Create;
          try
            JSet(TJSONObject(V), '_screenscraper_not_found', TJSONBool.Create(True));
            WriteJSON(FileName, TJSONObject(V));
            RegisterCacheFile(TDirectory.GetParent(TDirectory.GetParent(FCache)), ScopeSystemID, 'api', FileName);
          finally
            V.Free;
          end;
        end;
      end;
      Exit;
    end;
    if StatusCode <> HTTPOK then
    begin
      if Attempt = Retries then
        raise EScreenScraper.Create('ScreenScraper HTTP ' + StatusCode.ToString);
      WaitRetry(APIBackoffMs * (Attempt + 1));
      Continue;
    end;
    V := TJSONObject.ParseJSONValue(S);
    if not (V is TJSONObject) then
    begin
      V.Free;
      raise EScreenScraper.Create('ScreenScraper returned a non-JSON response. Service may be unavailable.');
    end;
    Result := TJSONObject(V);
    // Never cache the server header: it can echo the credential-bearing URL.
    SanitizeResponse(Result);
    if (FCache <> '') and Cacheable and (CacheDays <> 0) then
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
  Activity: IInterface;
begin
  Activity := CacheActivity(FileName);
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
  CheckWritablePath(FileName);
  Parsed := TURI.Create(URL);
  if not SameText(Parsed.Scheme, 'https') or not
    (SameText(Parsed.Host, ScreenScraperMediaHost) or Parsed.Host.ToLower.EndsWith('.' + ScreenScraperMediaHost)) then
    raise EScreenScraper.Create('Unexpected media host.');
  EnsureDirectory(ExtractFilePath(FileName));
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

end.

