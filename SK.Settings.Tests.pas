unit SK.Settings.Tests;

interface

uses
  System.Classes;

procedure RunSettingsSessionTests(Report: TStrings);

implementation

uses
  System.SysUtils, System.JSON, System.Generics.Collections, System.IOUtils,
  SK.Configuration, SK.Settings.Session, SK.Json, SK.Platform, SK.Services.Catalog,
  SK.Consts;

procedure RunSettingsSessionTests(Report: TStrings);
var
  Config, Migrated: TRetroScraperConfig;
  Session: TSettingsSession;
  Catalog, Bound, RunConfig, OriginalRoot, OriginalCredentials: TJSONObject;
  Checked: TDictionary<string, Boolean>;
  A: TJSONArray;
  Path, BeforeRoot, BeforeCredentials, MasterMedia: string;
  MediaIndex: Integer;

  procedure Check(Condition: Boolean; const Name: string);
  begin
    if not Condition then
      raise Exception.Create('FAIL: ' + Name);
    Report.Add('PASS: ' + Name);
  end;

begin
  Config := nil;
  Session := nil;
  Checked := nil;
  Catalog := TJSONObject.ParseJSONValue('{"systemes":[' +
    '{"id":1,"type":"Console","extensions":"rom","noms":{"nom_us":"Console"}},' +
    '{"id":40,"type":"Flipper","noms":{"nom_us":"Pinball"}}]}') as TJSONObject;
  try
    Config := TRetroScraperConfig.Create(TPlatformPath.Combine(WritableBase,
        'tests/settings-session-' + TGUID.NewGuid.ToString.Trim(['{', '}'])));
    Session := TSettingsSession.Create(Config);
    Checked := TDictionary<string, Boolean>.Create;
    Config.AddPlatform(Catalog, 4, TArray<Integer>.Create(1),
      TPlatformPath.Combine(Config.Base, 'roms/one'));
    Config.AddPlatform(Catalog, 4, TArray<Integer>.Create(1),
      TPlatformPath.Combine(Config.Base, 'roms/one'));
    Config.AddPlatform(Catalog, 4, TArray<Integer>.Create(1),
      TPlatformPath.Combine(Config.Base, 'roms/two'));
    Check(Config.Root.GetValue<TJSONArray>('Systems').Count = 2,
      'Configuration adds distinct platform folders without duplicate entries');
    Check(SelectablePlatformCount(Catalog) = 1,
      'Shared catalog service excludes unsupported platform categories');
    Check(SelectablePlatformCount(nil) = 0,
      'Shared catalog service accepts a missing offline catalog');

    JSet(Config.SystemAt(-1), 'Medias', TJSONArray.Create
      .Add(TJSONObject.Create.AddPair('OutputFolder', 'first'))
      .Add(TJSONObject.Create.AddPair('OutputFolder', 'second'))
      .Add(TJSONObject.Create.AddPair('OutputFolder', 'third')));
    JSet(Config.SystemAt(0), 'Overriden', TJSONNumber.Create(0));
    Path := 'Media.OutputFolder';
    Bound := Session.BindingObject(0, 1, Path, False);
    Check((Path = 'OutputFolder') and (JStr(Bound, Path) = 'second'),
      'Reading inherited media resolves the global value');
    MasterMedia := Config.SystemAt(-1).GetValue<TJSONArray>('Medias').ToJSON;
    Path := 'Media.OutputFolder';
    Bound := Session.BindingObject(0, 1, Path, True);
    JSet(Bound, Path, TJSONString.Create('local second'));
    Check((JInt(Config.SystemAt(0), 'Overriden') and 8 <> 0) and
      (Config.SystemAt(-1).GetValue<TJSONArray>('Medias').ToJSON = MasterMedia),
      'Editing inherited media creates a local override without changing global media');
    Session.EnsureGroup(0, 'GamesAndRoms', 2);
    Check(JStr(Config.SystemAt(0), 'GamesAndRoms.Path') =
      TPlatformPath.Combine(Config.Base, 'roms/one'),
      'Creating a ROM-settings override preserves the platform folder');

    MediaIndex := 1;
    Check(Session.MoveMedia(0, MediaIndex, -1, True) and (MediaIndex = 0),
      'Moving media to the beginning keeps the edited item selected');
    A := Config.SystemAt(0).GetValue<TJSONArray>('Medias');
    Check((JStr(A.Items[0], 'OutputFolder') = 'local second') and
      (JStr(A.Items[1], 'OutputFolder') = 'first') and
      (JStr(A.Items[2], 'OutputFolder') = 'third') and
      (Config.SystemAt(-1).GetValue<TJSONArray>('Medias').ToJSON = MasterMedia),
      'Media movement preserves other items and global media');
    JSet(Config.SystemAt(0), 'Medias', TJSONArray.Create);
    MediaIndex := 0;
    Check(not Session.MoveMedia(0, MediaIndex, 1, False),
      'Moving an empty media list makes no selection change');

    Path := '@Culture';
    Check((Session.BindingObject(0, 0, Path, False) = Config.Root) and (Path = 'Culture'),
      'Global setting bindings resolve outside platform overrides');
    Path := '!ssid';
    Check((Session.BindingObject(0, 0, Path, True) = Config.Credentials) and (Path = 'ssid'),
      'Credential bindings resolve to the separate credential document');

    Check(Session.ParseSecondarySystems(0, Catalog, '1, 40', A),
      'Secondary platform IDs are validated against the shared catalog');
    try
      Check((A.Count = 1) and (A.Items[0].Value = '40'),
        'Secondary platform IDs exclude the primary platform');
    finally
      A.Free;
    end;
    Check(not Session.ParseSecondarySystems(0, Catalog, '1, invalid', A) and (A = nil),
      'Invalid secondary platform input returns no partial value');

    OriginalRoot := Config.Root;
    OriginalCredentials := Config.Credentials;
    BeforeRoot := Config.Root.ToJSON;
    BeforeCredentials := Config.Credentials.ToJSON;
    Session.BeginEdit;
    JSet(Config.Root, 'Culture', TJSONString.Create('en'));
    JSet(Config.Credentials, 'ssid', TJSONString.Create('changed'));
    Session.BeginEdit;
    Check(Session.Rollback and (Config.Root = OriginalRoot) and
      (Config.Credentials = OriginalCredentials) and
      (Config.Root.ToJSON = BeforeRoot) and (Config.Credentials.ToJSON = BeforeCredentials),
      'Rollback restores settings and credentials while preserving live document references');
    Check(not Session.Rollback, 'A completed rollback releases the edit snapshot');
    Session.BeginEdit;
    JSet(Config.Root, 'Culture', TJSONString.Create('en'));
    Session.DiscardSnapshot;
    Check(not Session.Rollback and (JStr(Config.Root, 'Culture') = 'en'),
      'Committing an edit retains changes and releases the previous snapshot');

    Checked.Add(Session.SystemKey(0), True);
    Checked.Add(Session.SystemKey(1), False);
    RunConfig := Session.CreateRunConfig(Checked);
    try
      A := RunConfig.GetValue<TJSONArray>('Systems');
      Check((A.Count = 1) and
        (JStr(A.Items[0], 'GamesAndRoms.Path') = JStr(Config.SystemAt(0), 'GamesAndRoms.Path')),
        'Scrape configuration includes only checked platform folders');
      JSet(A.Items[0] as TJSONObject, 'GamesAndRoms.Path', TJSONString.Create('worker-only'));
      Check(JStr(Config.SystemAt(0), 'GamesAndRoms.Path') <> 'worker-only',
        'Scrape configuration is detached from the editable configuration');
    finally
      RunConfig.Free;
    end;
    BeforeRoot := Config.Root.ToJSON;
    ReplaceJSONObject(Config.Root, Config.Root);
    Check(Config.Root.ToJSON = BeforeRoot, 'Replacing a JSON object with itself preserves its data');

    Path := TPlatformPath.Combine(Config.Base, 'legacy-brand');
    ForceDirectories(Path);
    WriteJSON(TPlatformPath.Combine(Path, LegacyConfigFileName), Config.Root);
    Migrated := TRetroScraperConfig.Create(Path);
    try
      Check((JStr(Migrated.Root, 'Culture') = JStr(Config.Root, 'Culture')) and
        (Migrated.Root.GetValue<TJSONArray>('Systems').ToJSON =
          Config.Root.GetValue<TJSONArray>('Systems').ToJSON) and
        TFile.Exists(TPlatformPath.Combine(Path, ConfigFileName)) and
        TFile.Exists(TPlatformPath.Combine(Path, LegacyConfigFileName)) and
        (TFile.ReadAllText(TPlatformPath.Combine(Path, ConfigFileName)) =
          TFile.ReadAllText(TPlatformPath.Combine(Path, LegacyConfigFileName))),
        'RetroScraper adopts the legacy configuration and preserves the original file');
      JSet(Migrated.Root, 'Culture', TJSONString.Create('de'));
      Migrated.Save;
    finally
      Migrated.Free;
    end;
    Migrated := TRetroScraperConfig.Create(Path);
    try
      Check((JStr(Migrated.Root, 'Culture') = 'de') and
        (Migrated.Root.GetValue<TJSONArray>('Systems').Count = 2),
        'RetroScraper keeps saved changes and platform folders when a legacy file also exists');
    finally
      Migrated.Free;
    end;
  finally
    Checked.Free;
    Session.Free;
    Config.Free;
    Catalog.Free;
  end;
end;

end.

