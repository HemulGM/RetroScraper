unit SK.Configuration;

interface

uses
  System.SysUtils, System.JSON;

type
  TRetroScraperConfig = class
  private
    FRoot: TJSONObject;
    FCredentials: TJSONObject;
    FBase: string;
  public
    constructor Create(const Base: string);
    constructor CreateSnapshot(Source: TRetroScraperConfig);
    destructor Destroy; override;
    procedure Save;
    procedure SaveCredentials;
    procedure Load(const FileName: string);
    procedure ReplaceWith(Source: TRetroScraperConfig);
    procedure AddPlatform(Catalog: TJSONObject; Frontend: Integer; const IDs: TArray<Integer>; const Folder: string);
    procedure ResetSystemSettings(Index: Integer; Catalog: TJSONObject = nil);
    function DialogFolder(const Key, Current: string): string;
    procedure RememberFolder(const Key, Folder: string);
    function SystemAt(Index: Integer): TJSONObject;
    function EffectiveSystem(Index: Integer): TJSONObject;
    property Root: TJSONObject read FRoot;
    property Credentials: TJSONObject read FCredentials;
    property Base: string read FBase;
  end;

procedure InitializeCultureDefaults(Config: TJSONObject; const Culture: string);

implementation

uses
  System.IOUtils, System.Generics.Collections, SK.Json, SK.Storage, SK.Platform,
  SK.Consts, SK.Catalog, SK.Locale, System.StrUtils, SK.Cache;

function SettingsFile(const Base: string): string;
const
  Names: array[0..2] of string = (ConfigFileName, LegacyConfigFileName,
    'RetroScraper.legacy.config.json');
var
  Name: string;
begin
  for Name in Names do
    if TFile.Exists(TPath.Combine(Base, Name)) then
      Exit(TPath.Combine(Base, Name));
  Result := '';
end;

procedure MergeMissingSettings(Target, Defaults: TJSONObject);
var
  Pair: TJSONPair;
  Value: TJSONValue;
begin
  for Pair in Defaults do
  begin
    Value := Target.GetValue(Pair.JsonString.Value);
    if Value = nil then
      Target.AddPair(Pair.JsonString.Value, Pair.JsonValue.Clone as TJSONValue)
    else if (Value is TJSONObject) and (Pair.JsonValue is TJSONObject) then
      MergeMissingSettings(TJSONObject(Value), TJSONObject(Pair.JsonValue));
  end;
end;

function CurrentMixPath(const Value: string): string;
var
  Normal, Relative, Candidate, Prefix, Root: string;
  Position: Integer;
begin
  Result := Value;
  if (Value = '') or TFile.Exists(Value) then
    Exit;
  Normal := Value.Replace('\', '/');
  if StartsText('Mixes/', Normal) then
    Relative := Normal
  else
  begin
    Position := Pos('/mixes/', Normal.ToLower);
    if Position = 0 then
      Exit;
    Prefix := Normal.Substring(0, Position - 1);
    Root := ExcludeTrailingPathDelimiter(ResourceBase).Replace('\', '/');
    // Only rebase known application trees. A missing custom MIX elsewhere
    // must remain missing, even when its basename matches a bundled template.
    if not SameText(Prefix, Root) and
       not EndsText('/SkraperFMX', Prefix) and
       not EndsText('/RetroScraperFMX', Prefix) and
       not EndsText('/RetroScraper', Prefix) and
       not (EndsText('/sources/Assets/Runtime', Root) and
         SameText(Prefix + '/sources/Assets/Runtime', Root)) then
      Exit;
    Relative := Normal.Substring(Position);
  end;
  Candidate := TPlatformPath.Combine(ResourceBase, Relative);
  if IsPathWithin(Candidate, TPlatformPath.Combine(ResourceBase, 'Mixes')) and
     TFile.Exists(Candidate) then
    Result := TPath.GetFullPath(Candidate);
end;

procedure UpdateMixPaths(Value: TJSONValue);
var
  Pair: TJSONPair;
  Child: TJSONValue;
  Previous, Current: string;
begin
  if Value is TJSONObject then
    for Pair in TJSONObject(Value) do
      if SameText(Pair.JsonString.Value, 'LocalMixFile') and (Pair.JsonValue is TJSONString) then
      begin
        Previous := Pair.JsonValue.Value;
        Current := CurrentMixPath(Previous);
        if Current <> Previous then
          Pair.JsonValue := TJSONString.Create(Current);
      end
      else
        UpdateMixPaths(Pair.JsonValue)
  else if Value is TJSONArray then
    for Child in TJSONArray(Value) do
      UpdateMixPaths(Child);
end;

procedure InitializeCultureDefaults(Config: TJSONObject; const Culture: string);
var
  Parts: TArray<string>;
  Code, Language, Country, Regions: string;
  I: Integer;
  Languages, RegionList: TJSONArray;
  Region: string;
begin
  Code := Culture.Trim.Replace('_', '-').Split(['.', '@'])[0].ToLower;
  if (Code = '') or (Code = 'c') or (Code = 'posix') then
    Code := 'en-us';
  Parts := Code.Split(['-']);
  Language := Parts[0];
  Country := '';
  for I := 1 to High(Parts) do
    if (Length(Parts[I]) = 2) or (Length(Parts[I]) = 3) then
      Country := Parts[I];
  if Country = '' then
  begin
    if MatchText(Language, ['ru', 'de', 'fr', 'it', 'es', 'pt', 'nl', 'pl', 'se', 'dk']) then
      Country := Language
    else if Language = 'ja' then
      Country := 'jp';
  end;
  if MatchText(Country, ['be', 'ch']) then
    Regions := Language + ',eu,us,jp,wor,ss'
  else if MatchText(Country, ['fr', 'de', 'nl', 'du', 'dk', 'it', 'se', 'es', 'sp',
      'gr', 'at', 'pt', 'pl', 'fi', 'no', 'cz', 'hu', 'ie']) then
    Regions := Country + ',eu,us,jp,wor,ss'
  else if MatchText(Country, ['bo', 'br', 'cl', 'ag', 'ar', 'mx', 'py', 'uy']) then
    Regions := Country + ',ame,us,jp,wor,ss'
  else if Country = 'us' then
    Regions := 'us,jp,wor,ss'
  else if Country = 'jp' then
    Regions := 'jp,us,wor,ss'
  else if Country <> '' then
    Regions := Country + ',us,jp,wor,ss'
  else
    Regions := 'eu,us,jp,wor,ss';
  Languages := TJSONArray.Create.Add(Language);
  if Language <> 'en' then
    Languages.Add('en');
  JSet(Config, 'Culture', TJSONString.Create(UILocaleCode(UILocaleIndex(Code))));
  JSet(Config, 'AllSystems.Miscellaneous.Languages', Languages);
  RegionList := TJSONArray.Create;
  for Region in Regions.Split([',']) do
    RegionList.Add(Region);
  JSet(Config, 'AllSystems.Miscellaneous.Regions', RegionList);
end;

procedure CopyLegacyState(const Source, Destination: string);
var
  Relative, Input, Output, FileName: string;
begin
  if SamePath(Source, Destination) then
    Exit;
  for Relative in ['Resources/systems.json', 'State/MediaIndex', 'Logs'] do
  begin
    Input := TPlatformPath.Combine(Source, Relative);
    Output := TPlatformPath.Combine(Destination, Relative);
    if TFile.Exists(Input) then
    begin
      if not TFile.Exists(Output) then
      begin
        EnsureDirectory(ExtractFilePath(Output));
        TFile.Copy(Input, Output, False);
      end;
    end
    else if TDirectory.Exists(Input) and not DirectoryLink(Input) then
      // These directories contain only immediate state/log files; do not follow links.
      for FileName in TDirectory.GetFiles(Input) do
        if not DirectoryLink(FileName) and
          not TFile.Exists(TPlatformPath.Combine(Output, TPath.GetFileName(FileName))) then
        begin
          EnsureDirectory(Output);
          TFile.Copy(FileName, TPlatformPath.Combine(Output, TPath.GetFileName(FileName)), False);
        end;
  end;
end;

constructor TRetroScraperConfig.Create(const Base: string);
var
  Secret, PreviousFile, PreviousBase: string;
  Parsed: TJSONValue;
  Defaults: TJSONObject;
  Fresh: Boolean;
begin
  inherited Create;
  FBase := IncludeTrailingPathDelimiter(Base);
  CheckWritablePath(FBase);
  ForceDirectories(FBase);
  // Adopt old filenames and the former portable layout without overwriting
  // either the source configuration or a newer configuration in Data.
  PreviousBase := '';
  PreviousFile := SettingsFile(FBase);
  if (PreviousFile = '') and SamePath(FBase, UserDataBase) then
  begin
    PreviousFile := SettingsFile(LegacyWritableBase);
    if PreviousFile = '' then
      PreviousFile := SettingsFile(TPlatformPath.Combine(ExtractFilePath(ParamStr(0)), 'Data'));
    if PreviousFile = '' then
      PreviousFile := SettingsFile(ExtractFilePath(ParamStr(0)));
  end;
  {$IFDEF MSWINDOWS}
  if (PreviousFile = '') and SameText(TPath.GetFileName(ExcludeTrailingPathDelimiter(FBase)), 'Data') then
    PreviousFile := SettingsFile(TDirectory.GetParent(ExcludeTrailingPathDelimiter(FBase)));
  {$ENDIF}
  if (PreviousFile <> '') and not TFile.Exists(FBase + ConfigFileName) then
  begin
    TFile.Copy(PreviousFile, FBase + ConfigFileName);
    CopyLegacyState(ExtractFilePath(PreviousFile), FBase);
    PreviousBase := ExtractFilePath(PreviousFile);
    {$IFDEF MSWINDOWS}
    if not SameText(PreviousBase, FBase) and TFile.Exists(PreviousBase + CredentialsFileName) and
       not TFile.Exists(FBase + CredentialsFileName) then
      TFile.Copy(PreviousBase + CredentialsFileName, FBase + CredentialsFileName);
    {$ENDIF}
  end;
  Fresh := not TFile.Exists(FBase + ConfigFileName);
  if Fresh then
  begin
    Defaults := ReadJSON(TPlatformPath.Combine(AppBase, DefaultConfigPath));
    if Defaults = nil then
      raise Exception.Create('Default configuration is missing from application resources');
    try
      InitializeCultureDefaults(Defaults, CommandLineCulture(SystemCulture));
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
  ApplyCachePolicy(FRoot);
  FCredentials := TJSONObject.Create;
  Secret := LoadSecret(FBase + CredentialsFileName);
  {$IFNDEF MSWINDOWS}
  if (Secret = '') and (PreviousBase <> '') and not SamePath(PreviousBase, FBase) then
  begin
    Secret := LoadSecret(PreviousBase + CredentialsFileName);
    if Secret <> '' then
      SaveSecret(FBase + CredentialsFileName, Secret);
  end;
  {$ENDIF}
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

constructor TRetroScraperConfig.CreateSnapshot(Source: TRetroScraperConfig);
begin
  inherited Create;
  FBase := Source.FBase;
  FRoot := Source.FRoot.Clone as TJSONObject;
  FCredentials := Source.FCredentials.Clone as TJSONObject;
end;

procedure TRetroScraperConfig.ReplaceWith(Source: TRetroScraperConfig);
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

destructor TRetroScraperConfig.Destroy;
begin
  FCredentials.Free;
  FRoot.Free;
  inherited;
end;

procedure TRetroScraperConfig.Load(const FileName: string);
var
  NewRoot, Defaults: TJSONObject;
  Sys: TJSONValue;

  procedure RemoveObsoleteMetadataOption(SystemConfig: TJSONValue);
  var
    Metadata: TJSONValue;
  begin
    Metadata := JValue(SystemConfig, 'MetaData');
    if Metadata is TJSONObject then
      TJSONObject(Metadata).RemovePair('ParseRomFileName').Free;
  end;

begin
  NewRoot := ReadJSON(FileName);
  if (NewRoot = nil) or not (JValue(NewRoot, 'AllSystems') is TJSONObject) or
    not (JValue(NewRoot, 'Systems') is TJSONArray) then
  begin
    NewRoot.Free;
    raise Exception.Create('Invalid RetroScraper configuration: ' + FileName);
  end;
  RemoveObsoleteMetadataOption(JValue(NewRoot, 'AllSystems'));
  for Sys in TJSONArray(JValue(NewRoot, 'Systems')) do
    RemoveObsoleteMetadataOption(Sys);
  if JInt(NewRoot, 'ConfigVersion') < ConfigSchemaVersion then
  begin
    if (JValue(NewRoot, 'IsConfigured') = nil) and
       (TJSONArray(JValue(NewRoot, 'Systems')).Count > 0) then
      JSet(NewRoot, 'IsConfigured', TJSONBool.Create(True));
    Defaults := ReadJSON(TPlatformPath.Combine(AppBase, DefaultConfigPath));
    try
      if Defaults <> nil then
        MergeMissingSettings(NewRoot, Defaults);
    finally
      Defaults.Free;
    end;
    JSet(NewRoot, 'ConfigVersion', TJSONNumber.Create(ConfigSchemaVersion));
  end;
  if (JValue(NewRoot, 'CacheLimitGB') = nil) or
    (JInt(NewRoot, 'CacheLimitGB', 10) < 0) or
    (JInt(NewRoot, 'CacheLimitGB', 10) > 1048576) then
    JSet(NewRoot, 'CacheLimitGB', TJSONNumber.Create(10));
  // Imported settings must not turn a stale/unsafe cache path into a startup failure.
  try
    ValidateCacheFolder(JStr(NewRoot, 'CacheFolder'));
  except
    on E: EArgumentException do
      JSet(NewRoot, 'CacheFolder', TJSONString.Create(''));
  end;
  UpdateMixPaths(NewRoot);
  FRoot.Free;
  FRoot := NewRoot;
end;

procedure TRetroScraperConfig.ResetSystemSettings(Index: Integer; Catalog: TJSONObject);
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

function TRetroScraperConfig.DialogFolder(const Key, Current: string): string;
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

procedure TRetroScraperConfig.RememberFolder(const Key, Folder: string);
begin
  if (Folder <> '') and TDirectory.Exists(Folder) then
    JSet(FRoot, 'MRU.' + Key, TJSONString.Create(TPath.GetFullPath(Folder)));
end;

procedure TRetroScraperConfig.Save;
begin
  ValidateCacheFolder(JStr(FRoot, 'CacheFolder'));
  WriteJSON(FBase + ConfigFileName, FRoot);
  ApplyCachePolicy(FRoot);
end;

procedure TRetroScraperConfig.SaveCredentials;
begin
  SaveSecret(FBase + CredentialsFileName, FCredentials.ToJSON)
end;

function TRetroScraperConfig.SystemAt(Index: Integer): TJSONObject;
begin
  if Index < 0 then
    Result := FRoot.GetValue<TJSONObject>('AllSystems')
  else
    Result := FRoot.GetValue<TJSONArray>('Systems').Items[Index] as TJSONObject;
end;

function TRetroScraperConfig.EffectiveSystem(Index: Integer): TJSONObject;
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

procedure TRetroScraperConfig.AddPlatform(Catalog: TJSONObject; Frontend: Integer; const IDs: TArray<Integer>; const Folder: string);
var
  S: TJSONObject;
  A: TJSONArray;
  V: TJSONValue;
begin
  A := Root.GetValue<TJSONArray>('Systems');
  for V in A do
    if SamePath(JStr(V, 'GamesAndRoms.Path'), Folder) then
      Exit;
  S := SystemAt(-1).Clone as TJSONObject;
  try
    JSet(S, 'UniqueId', TJSONString.Create(TGUID.NewGuid.ToString));
    ConfigurePlatform(S, SystemAt(-1), Catalog, Frontend, IDs, Folder);
    A.AddElement(S);
  except
    S.Free;
    raise
  end;
end;

end.

