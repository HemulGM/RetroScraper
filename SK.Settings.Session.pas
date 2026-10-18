unit SK.Settings.Session;

interface

uses
  System.SysUtils, System.JSON, System.Generics.Collections, SK.Configuration;

type
  // Borrows the configuration; owns only the edit snapshots.
  TSettingsSession = class
  private
    FConfig: TRetroScraperConfig;
    FRootSnapshot, FCredentialSnapshot: TJSONObject;
  public
    constructor Create(Config: TRetroScraperConfig);
    destructor Destroy; override;
    procedure BeginEdit;
    procedure DiscardSnapshot;
    function Rollback: Boolean;
    procedure EnsureGroup(SystemIndex: Integer; const Group: string; Bit: Integer);
    function BindingObject(SystemIndex, MediaIndex: Integer; var Path: string; WriteAccess: Boolean): TJSONObject;
    procedure MarkOverride(SystemIndex: Integer; const Path: string);
    function SystemKey(Index: Integer): string;
    function CreateRunConfig(CheckedSystems: TDictionary<string, Boolean>): TJSONObject;
    function PrepareRequiredMedia: Integer;
    function MoveMedia(SystemIndex: Integer; var MediaIndex: Integer; Direction: Integer; ToEdge: Boolean): Boolean;
    procedure UpdateMediaOutput(SystemIndex, MediaIndex: Integer);
    function ParseSecondarySystems(SystemIndex: Integer; Catalog: TJSONObject; const Text: string; out Value: TJSONArray): Boolean;
  end;

implementation

uses
  System.Math, SK.Catalog, SK.Json, SK.Consts, SK.Frontend;

function SettingGroup(const Path: string; out Group: string): Integer;
var
  I: Integer;
begin
  Group := Path.Split(['.'])[0];
  if Group = 'Media' then
    Group := 'Medias';
  Result := 0;
  for I := 0 to High(SettingsGroups) do
    if Group = SettingsGroups[I] then
      Exit(SettingsGroupBits[I]);
end;

constructor TSettingsSession.Create(Config: TRetroScraperConfig);
begin
  inherited Create;
  FConfig := Config;
end;

destructor TSettingsSession.Destroy;
begin
  DiscardSnapshot;
  inherited;
end;

procedure TSettingsSession.BeginEdit;
var
  RootCopy, CredentialCopy: TJSONObject;
begin
  if FRootSnapshot <> nil then
    Exit;
  RootCopy := FConfig.Root.Clone as TJSONObject;
  try
    CredentialCopy := FConfig.Credentials.Clone as TJSONObject;
  except
    RootCopy.Free;
    raise;
  end;
  FRootSnapshot := RootCopy;
  FCredentialSnapshot := CredentialCopy;
end;

procedure TSettingsSession.DiscardSnapshot;
begin
  FreeAndNil(FRootSnapshot);
  FreeAndNil(FCredentialSnapshot);
end;

function TSettingsSession.Rollback: Boolean;
begin
  Result := FRootSnapshot <> nil;
  if not Result then
    Exit;
  ReplaceJSONObject(FConfig.Root, FRootSnapshot);
  ReplaceJSONObject(FConfig.Credentials, FCredentialSnapshot);
  DiscardSnapshot;
end;

procedure TSettingsSession.EnsureGroup(SystemIndex: Integer; const Group: string; Bit: Integer);
var
  Sys: TJSONObject;
  Path: string;
begin
  if SystemIndex < 0 then
    Exit;
  Sys := FConfig.SystemAt(SystemIndex);
  if JInt(Sys, 'Overriden') and Bit = 0 then
  begin
    Path := JStr(Sys, 'GamesAndRoms.Path');
    JSet(Sys, Group, JValue(FConfig.SystemAt(-1), Group).Clone as TJSONValue);
    if Group = 'GamesAndRoms' then
      JSet(Sys, 'GamesAndRoms.Path', TJSONString.Create(Path));
    JSet(Sys, 'Overriden', TJSONNumber.Create(JInt(Sys, 'Overriden') or Bit));
  end;
end;

function TSettingsSession.BindingObject(SystemIndex, MediaIndex: Integer; var Path: string; WriteAccess: Boolean): TJSONObject;
var
  A: TJSONArray;
  Group: string;
  Bit: Integer;
begin
  if Path.StartsWith('@') then
  begin
    Delete(Path, 1, 1);
    Exit(FConfig.Root);
  end;
  if Path.StartsWith('!') then
  begin
    Delete(Path, 1, 1);
    Exit(FConfig.Credentials);
  end;
  if WriteAccess then
  begin
    Bit := SettingGroup(Path, Group);
    if Bit <> 0 then
      EnsureGroup(SystemIndex, Group, Bit);
  end;
  Result := FConfig.SystemAt(SystemIndex);
  if Path.StartsWith('Media.') then
  begin
    Delete(Path, 1, 6);
    if not WriteAccess and (SystemIndex >= 0) and (JInt(Result, 'Overriden') and 8 = 0) then
      Result := FConfig.SystemAt(-1);
    A := Result.GetValue<TJSONArray>('Medias');
    if (MediaIndex < 0) or (MediaIndex >= A.Count) then
      Exit(nil);
    Result := A.Items[MediaIndex] as TJSONObject;
  end;
end;

procedure TSettingsSession.MarkOverride(SystemIndex: Integer; const Path: string);
var
  Group: string;
  Bit: Integer;
  Sys: TJSONObject;
begin
  if (SystemIndex < 0) or (Path = 'Overriden') or Path.StartsWith('@') or Path.StartsWith('!') then
    Exit;
  Bit := SettingGroup(Path, Group);
  if Bit = 0 then
    Exit;
  Sys := FConfig.SystemAt(SystemIndex);
  JSet(Sys, 'Overriden', TJSONNumber.Create(JInt(Sys, 'Overriden') or Bit));
end;

function TSettingsSession.SystemKey(Index: Integer): string;
begin
  Result := JStr(FConfig.SystemAt(Index), 'SystemId') + '|' +
    JStr(FConfig.SystemAt(Index), 'GamesAndRoms.Path').ToLower;
end;

function TSettingsSession.CreateRunConfig(CheckedSystems: TDictionary<string, Boolean>): TJSONObject;
var
  I: Integer;
  Checked: Boolean;
  Selected, Source: TJSONArray;
begin
  Result := FConfig.Root.Clone as TJSONObject;
  try
    Selected := TJSONArray.Create;
    // Attach immediately so the clone owns the array if copying a system fails.
    JSet(Result, 'Systems', Selected);
    Source := FConfig.Root.GetValue<TJSONArray>('Systems');
    for I := 0 to Source.Count - 1 do
      if CheckedSystems.TryGetValue(SystemKey(I), Checked) and Checked then
        Selected.AddElement(Source.Items[I].Clone as TJSONValue);
  except
    Result.Free;
    raise;
  end;
end;

function TSettingsSession.PrepareRequiredMedia: Integer;
var
  V: TJSONValue;
begin
  Result := 0;
  if JInt(FConfig.Root, 'FrontEnd.Type') <> 0 then
    Exit;
  Inc(Result, EnsureRecalboxMedia(FConfig.SystemAt(-1)));
  for V in FConfig.Root.GetValue<TJSONArray>('Systems') do
    if JInt(V, 'Overriden') and 8 <> 0 then
      Inc(Result, EnsureRecalboxMedia(V as TJSONObject));
end;

function TSettingsSession.MoveMedia(SystemIndex: Integer; var MediaIndex: Integer; Direction: Integer; ToEdge: Boolean): Boolean;
var
  A, B: TJSONArray;
  I, J, Target: Integer;
begin
  EnsureGroup(SystemIndex, 'Medias', 8);
  A := FConfig.SystemAt(SystemIndex).GetValue<TJSONArray>('Medias');
  Result := (MediaIndex >= 0) and (MediaIndex < A.Count);
  if not Result then
    Exit;
  if ToEdge then
  begin
    if Direction < 0 then
      Target := 0
    else
      Target := A.Count - 1;
  end
  else
    Target := MediaIndex + Direction;
  Target := EnsureRange(Target, 0, A.Count - 1);
  B := TJSONArray.Create;
  try
    for I := 0 to A.Count - 1 do
    begin
      J := I;
      if I = Target then
        J := MediaIndex
      else if (Target < MediaIndex) and (I > Target) and (I <= MediaIndex) then
        J := I - 1
      else if (Target > MediaIndex) and (I >= MediaIndex) and (I < Target) then
        J := I + 1;
      B.AddElement(A.Items[J].Clone as TJSONValue);
    end;
  except
    B.Free;
    raise;
  end;
  JSet(FConfig.SystemAt(SystemIndex), 'Medias', B);
  MediaIndex := Target;
end;

procedure TSettingsSession.UpdateMediaOutput(SystemIndex, MediaIndex: Integer);
var
  Existing, Other: TJSONArray;
  Media: TJSONObject;
  I: Integer;
begin
  Existing := FConfig.SystemAt(SystemIndex).GetValue<TJSONArray>('Medias');
  Media := Existing.Items[MediaIndex] as TJSONObject;
  Other := TJSONArray.Create;
  try
    for I := 0 to Existing.Count - 1 do
      if I <> MediaIndex then
        Other.AddElement(Existing.Items[I].Clone as TJSONValue);
    JSet(Media, 'OutputFolder', TJSONString.Create(DefaultMediaFolder(JInt(FConfig.Root, 'FrontEnd.Type'),
          JInt(Media, 'Type'), JInt(Media, 'Image'), Other)));
  finally
    Other.Free;
  end;
end;

function TSettingsSession.ParseSecondarySystems(SystemIndex: Integer; Catalog: TJSONObject; const Text: string; out Value: TJSONArray): Boolean;
var
  Token: string;
  ID: Integer;
begin
  Value := TJSONArray.Create;
  Result := False;
  try
    for Token in Text.Split([',']) do
      if Token.Trim <> '' then
      begin
        if not TryStrToInt(Token.Trim, ID) or (ID <= 0) or (CatalogSystem(Catalog, ID) = nil) then
          Exit;
        if ID <> JInt(FConfig.SystemAt(SystemIndex), 'SystemId') then
          Value.Add(ID);
      end;
    Result := True;
  finally
    if not Result then
      FreeAndNil(Value);
  end;
end;

end.

