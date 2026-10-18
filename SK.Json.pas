unit SK.Json;

interface

uses
  System.SysUtils, System.JSON;

function JStr(Obj: TJSONValue; const Path: string; const Default: string = ''): string;

function JInt(Obj: TJSONValue; const Path: string; Default: Integer = 0): Integer;

function JBool(Obj: TJSONValue; const Path: string; Default: Boolean = False): Boolean;

function JValue(Obj: TJSONValue; const Path: string): TJSONValue;

procedure JSet(Obj: TJSONObject; const Path: string; Value: TJSONValue);

function ReadJSON(const FileName: string): TJSONObject;

procedure WriteJSON(const FileName: string; Obj: TJSONValue);

procedure ReplaceJSONObject(Target, Source: TJSONObject);

implementation

uses
  System.Classes, System.IOUtils, System.Generics.Collections, SK.Platform,
  SK.Storage;

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
  EnsureDirectory(ExtractFilePath(FileName));
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

procedure ReplaceJSONObject(Target, Source: TJSONObject);
var
  Copy: TJSONObject;
  Pair: TJSONPair;
begin
  Copy := Source.Clone as TJSONObject;
  try
    while Target.Count > 0 do
      Target.RemovePair(Target.Pairs[0].JsonString.Value).Free;
    while Copy.Count > 0 do
    begin
      Pair := Copy.RemovePair(Copy.Pairs[0].JsonString.Value);
      Target.AddPair(Pair);
    end;
  finally
    Copy.Free;
  end;
end;

end.

