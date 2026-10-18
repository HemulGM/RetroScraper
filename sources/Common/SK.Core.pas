unit SK.Core;

interface

// Compatibility facade. Application modules import the specific owners directly.

uses
  System.JSON, SK.Json, SK.Configuration, SK.ScreenScraper, SK.Storage;

type
  EScreenScraper = SK.ScreenScraper.EScreenScraper;

  EScreenScraperFatal = SK.ScreenScraper.EScreenScraperFatal;

  TScreenScraperNetworkQueue = SK.ScreenScraper.TScreenScraperNetworkQueue;

  TScreenScraper = SK.ScreenScraper.TScreenScraper;

  TRetroScraperConfig = SK.Configuration.TRetroScraperConfig;

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

function AccountCredentialValue(Credentials: TJSONObject; const Key: string): string;
begin
  Result := SK.ScreenScraper.AccountCredentialValue(Credentials, Key);
end;

procedure CheckScreenScraperHTTPStatus(StatusCode: Integer; const Context: string);
begin
  SK.ScreenScraper.CheckScreenScraperHTTPStatus(StatusCode, Context);
end;

function SharedResourceLock(const Key: string): TObject;
begin
  Result := SK.Storage.SharedResourceLock(Key);
end;

function JStr(Obj: TJSONValue; const Path, Default: string): string;
begin
  Result := SK.Json.JStr(Obj, Path, Default);
end;

function JInt(Obj: TJSONValue; const Path: string; Default: Integer): Integer;
begin
  Result := SK.Json.JInt(Obj, Path, Default);
end;

function JBool(Obj: TJSONValue; const Path: string; Default: Boolean): Boolean;
begin
  Result := SK.Json.JBool(Obj, Path, Default);
end;

function JValue(Obj: TJSONValue; const Path: string): TJSONValue;
begin
  Result := SK.Json.JValue(Obj, Path);
end;

procedure JSet(Obj: TJSONObject; const Path: string; Value: TJSONValue);
begin
  SK.Json.JSet(Obj, Path, Value);
end;

function Encode(const S: string): string;
begin
  Result := SK.ScreenScraper.Encode(S);
end;

function AppBase: string;
begin
  Result := SK.Storage.AppBase;
end;

function ReadJSON(const FileName: string): TJSONObject;
begin
  Result := SK.Json.ReadJSON(FileName);
end;

procedure WriteJSON(const FileName: string; Obj: TJSONValue);
begin
  SK.Json.WriteJSON(FileName, Obj);
end;

procedure SanitizeResponse(Obj: TJSONValue);
begin
  SK.ScreenScraper.SanitizeResponse(Obj);
end;

procedure CommitFile(const Temporary, Destination: string);
begin
  SK.Storage.CommitFile(Temporary, Destination);
end;

end.

