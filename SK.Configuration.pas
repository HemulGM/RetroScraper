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
  SK.Consts, SK.Catalog, SK.Locale, System.StrUtils;

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

constructor TRetroScraperConfig.Create(const Base: string);
var
  Secret: string;
  Parsed: TJSONValue;
  Defaults, Previous: TJSONObject;
  Fresh: Boolean;
begin
  inherited Create;
  FBase := IncludeTrailingPathDelimiter(Base);
  ForceDirectories(FBase);
  // Adopt the previous portable configuration once; keep the original as a backup.
  if not TFile.Exists(FBase + ConfigFileName) and
    TFile.Exists(FBase + LegacyConfigFileName) then
    TFile.Copy(FBase + LegacyConfigFileName, FBase + ConfigFileName);
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
  NewRoot: TJSONObject;
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
  JSet(NewRoot, 'ConfigVersion', TJSONNumber.Create(ConfigSchemaVersion));
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
  WriteJSON(FBase + ConfigFileName, FRoot);
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

