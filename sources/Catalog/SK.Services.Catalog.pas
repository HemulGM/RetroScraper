unit SK.Services.Catalog;

interface

uses
  System.SysUtils, System.JSON, SK.ScreenScraper;

type
  TCatalogResourceStage = (crConnecting, crCatalog, crArtwork);

  TCatalogProgress = reference to procedure(Stage: TCatalogResourceStage; Platforms, Done, Total: Integer);

  TAccountConnection = record
    Verified: Boolean;
    ThreadsText, QuotaText, MessageText: string;
  end;

function SelectablePlatformCount(Catalog: TJSONObject): Integer;

function AuthenticateAccount(API: TScreenScraper; Anonymous: Boolean): TAccountConnection;

// Returns an owned catalog object, independent of the HTTP response.
function FetchPlatformCatalog(API: TScreenScraper): TJSONObject;

// The wizard decides when to persist the returned catalog after accepting changes.
function LoadCatalogResources(Credentials, Settings: TJSONObject; const Base: string; Cancel: TFunc<Boolean>; Progress: TCatalogProgress): TJSONObject;

// Preserves successful authentication if optional catalog/artwork refresh fails.
function CheckAccountConnection(Credentials, Settings: TJSONObject; const Base: string; ArtworkProgress: TProc<Integer, Integer> = nil): TAccountConnection;

implementation

uses
  SK.Json, SK.Platform, SK.Consts, SK.Locale, SK.Catalog, SK.Artwork, SK.Cache;

function SelectablePlatformCount(Catalog: TJSONObject): Integer;
var
  V: TJSONValue;
begin
  Result := 0;
  if JValue(Catalog, 'systemes') is TJSONArray then
    for V in TJSONArray(JValue(Catalog, 'systemes')) do
      if SelectablePlatform(V) then
        Inc(Result);
end;

function AuthenticateAccount(API: TScreenScraper; Anonymous: Boolean): TAccountConnection;
var
  User: TJSONObject;
begin
  Result := Default(TAccountConnection);
  Result.ThreadsText := '—';
  Result.QuotaText := '—';
  if Anonymous then
    Exit;
  User := API.Authenticate;
  try
    if JValue(User, 'response.ssuser') = nil then
      raise EScreenScraper.Create('No user information returned');
    Result.Verified := True;
    Result.ThreadsText := JStr(User, 'response.ssuser.maxthreads', '—');
    Result.QuotaText := JStr(User, 'response.ssuser.requeststoday', '—') + ' / ' +
      JStr(User, 'response.ssuser.maxrequestsperday', '—');
    Result.MessageText := L('Авторизация выполнена');
  finally
    User.Free;
  end;
end;

function FetchPlatformCatalog(API: TScreenScraper): TJSONObject;
var
  Response: TJSONObject;
begin
  Response := API.Systems;
  try
    if not (JValue(Response, 'response.systemes') is TJSONArray) then
      raise EScreenScraper.Create('No platforms returned');
    Result := JValue(Response, 'response').Clone as TJSONObject;
  finally
    Response.Free;
  end;
end;

function LoadCatalogResources(Credentials, Settings: TJSONObject; const Base: string; Cancel: TFunc<Boolean>; Progress: TCatalogProgress): TJSONObject;
var
  API: TScreenScraper;
  Count: Integer;
begin
  Result := nil;
  API := TScreenScraper.Create(Credentials, CacheLocation(Settings, 'Cache/api'));
  try
    API.IsCancelled := Cancel;
    if Assigned(Progress) then
      Progress(crConnecting, 0, 0, 0);
    AuthenticateAccount(API, JBool(Credentials, 'anonymous'));
    if Assigned(Progress) then
      Progress(crCatalog, 0, 0, 0);
    Result := FetchPlatformCatalog(API);
    try
      Count := SelectablePlatformCount(Result);
      if Assigned(Progress) then
        Progress(crArtwork, Count, 0, Count * 4);
      RefreshPlatformArtwork(Result, Settings, Credentials, Base, False, Cancel,
        procedure(Done, Total: Integer)
        begin
          if Assigned(Progress) and ((Done mod 8 = 0) or (Done = Total)) then
            Progress(crArtwork, Count, Done, Total);
        end);
    except
      FreeAndNil(Result);
      raise;
    end;
  finally
    API.Free;
  end;
end;

function CheckAccountConnection(Credentials, Settings: TJSONObject; const Base: string; ArtworkProgress: TProc<Integer, Integer>): TAccountConnection;
var
  API: TScreenScraper;
  Catalog: TJSONObject;
  ArtworkCount: Integer;
begin
  Result := Default(TAccountConnection);
  Result.ThreadsText := '—';
  Result.QuotaText := '—';
  API := nil;
  Catalog := nil;
  try
    try
      API := TScreenScraper.Create(Credentials, CacheLocation(Settings, 'Cache/api'));
      Result := AuthenticateAccount(API, JBool(Credentials, 'anonymous'));
      try
        Catalog := FetchPlatformCatalog(API);
        if JBool(Credentials, 'anonymous') then
        begin
          Result.Verified := True;
          Result.ThreadsText := '1';
          Result.QuotaText := L('Без аккаунта');
          Result.MessageText := L('Анонимное подключение выполнено');
        end;
        WriteJSON(TPlatformPath.Combine(Base, SystemsCatalogPath), Catalog);
        try
          ArtworkCount := RefreshPlatformArtwork(Catalog, Settings, Credentials, Base,
            False, nil, ArtworkProgress);
          Result.MessageText := Result.MessageText + L(' — изображений платформ: %d', [ArtworkCount]);
        except
          on E: Exception do
            Result.MessageText := Result.MessageText + L(' — изображения платформ недоступны');
        end;
      except
        on E: Exception do
          Result.MessageText := Result.MessageText + L(' — каталог систем недоступен');
      end;
    except
      on E: Exception do
        Result.MessageText := E.Message;
    end;
  finally
    Catalog.Free;
    API.Free;
  end;
end;

end.

