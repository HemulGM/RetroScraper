unit SK.Features.Tests;

interface

uses
  System.Classes;

procedure RunFeatureTests(Report: TStrings);

procedure RunDirectoryDetectionSelfTests;

implementation

uses {$IFDEF MSWINDOWS}
  Winapi.Windows, {$ENDIF}
  System.SysUtils, System.IOUtils, System.JSON, System.Hash, System.Types,
  System.Generics.Collections, FMX.Graphics, FMX.Forms, FMX.Types, SK.Core,
  SK.Catalog, SK.Frontend, SK.Cache, SK.Locale, SK.Preview, SK.Platform,
  SK.Consts, SK.Engine, SK.Main, SK.Setup, SK.GameLibrary.Tests, SK.Parity.Tests;

procedure RunDirectoryDetectionRegressions(Report: TStrings);
var
  Catalog: TJSONObject;
  Found: TArray<TDetectedPlatform>;
  IDs: TArray<Integer>;
  Root, LinkFixture: string;
  Frontend: Integer;
  Cancelled: Boolean;
  Settings: TSkraperConfig;
  Setup: TFormSetup;

  procedure Check(Condition: Boolean; const Name: string);
  begin
    if not Condition then
      raise Exception.Create('FAIL: ' + Name);
    Report.Add('PASS: ' + Name);
  end;

  procedure MakeFolder(const Name: string);
  begin
    ForceDirectories(TPlatformPath.Combine(Root, Name))
  end;

begin
  Root := TPlatformPath.Combine(WritableBase, 'tests/detection-' + TGUID.NewGuid.ToString);
  ForceDirectories(Root);
  Catalog := TJSONObject.ParseJSONValue('{"systemes":[' +
    '{"id":20,"type":"Console","noms":{"nom_recalbox":"standard","nom_retropie":"retro-only","nom_launchbox":"launch-only","noms_commun":"Common / Name,Shared,MSX2"}},' +
    '{"id":10,"parentid":20,"type":"Console","noms":{"nom_recalbox":"standard","noms_commun":"Shared,MSX2+"}},' +
    '{"id":30,"type":"Console","noms":{"nom_recalbox":"standard","noms_commun":"Shared"}},' +
    '{"id":40,"type":"Flipper","noms":{"nom_recalbox":"pinball","noms_commun":"Pinball Test"}},' +
    '{"id":168,"type":"Arcade","noms":{"nom_recalbox":"non-game","noms_commun":"Non Game"}},' +
    '{"id":50,"type":"Console","noms":{"nom_eu":"regional-only"}}]}') as TJSONObject;
  try
    MakeFolder('standard');
    MakeFolder('retro-only');
    MakeFolder('STANDARD');
    MakeFolder('launch-only');
    MakeFolder('regional-only');
    MakeFolder('Pinball Test');
    MakeFolder('non-game');
    MakeFolder('standard/Shared');
    MakeFolder('.hidden/Common - Name');
    {$IFDEF MSWINDOWS}
    Check(SetFileAttributes(PChar(TPlatformPath.Combine(Root, '.hidden')),
        FILE_ATTRIBUTE_HIDDEN or FILE_ATTRIBUTE_SYSTEM), 'Detection fixture has hidden/system attributes');
    {$ENDIF}
    for Frontend := 0 to 1 do
    begin
      Found := DetectPlatforms(Catalog, Root, Frontend, True, False);
      Check((Length(Found) = 1) and (Length(Found[0].IDs) = 2) and
        (Found[0].IDs[0] = 20) and (Found[0].IDs[1] = 30),
        'Original standard scan uses exact Recalbox aliases on the first level: ' + Frontend.ToString);
    end;
    for Frontend := 2 to 4 do
    begin
      Found := DetectPlatforms(Catalog, Root, Frontend, False, False);
      Check(Length(Found) = 0, 'Original generic scan ignores frontend-only, regional, flipper and non-game names: ' + Frontend.ToString);
    end;
    MakeFolder('Common - Name/Shared');
    Found := DetectPlatforms(Catalog, Root, 4, False, False);
    Check((Length(Found) = 1) and (Found[0].IDs[0] = 20), 'Common names replace slashes and recognize empty platform folders');
    Found := DetectPlatforms(Catalog, Root, 4, True, False);
    Check(Length(Found) = 4, 'Generic recursive scan includes hidden/system trees and children of recognized folders');
    Found := DetectPlatforms(Catalog, Root, 1, True, True);
    Check(Length(Found) = 5, 'Inclusive scan combines standard and common passes without duplicate paths');
    IDs := LookupPlatforms(Catalog, 'MSX2+', 4, True, False);
    Check((Length(IDs) = 1) and (IDs[0] = 20), 'Equal fuzzy scores keep the first common alias even when a later alias spells the folder exactly');
    IDs := LookupPlatforms(Catalog, 'Common - Name', 4, False, False);
    Check((Length(IDs) = 1) and (IDs[0] = 20), 'Exact aliases use original slash-to-hyphen conversion');
    Cancelled := False;
    try
      DetectPlatforms(Catalog, Root, 4, True, False,
        function: Boolean
        begin
          Result := True
        end)
    except
      on E: EAbort do
        Cancelled := True
    end;
    Check(Cancelled, 'Both scanning passes respect cancellation');
    Settings := TSkraperConfig.Create(TPlatformPath.Combine(Root, 'settings'));
    try
      JSet(Settings.Root, 'FrontEnd.Type', TJSONNumber.Create(1));
      Setup := TFormSetup.Create(nil);
      try
        Setup.Configure(Settings, Catalog, True);
        Setup.WizardOffline.IsChecked := True;
        Setup.ApplyButtonClick(nil);
        Check(not Setup.RecursiveCheck.IsChecked and not Setup.SearchAllCheck.IsChecked and
          not Setup.RecursiveCheck.Enabled, 'Wizard starts with standard, nonrecursive detection');
        Setup.SearchAllCheck.IsChecked := True;
        Setup.SelectionChanged(nil);
        Check(Setup.RecursiveCheck.Enabled, 'Inclusive scanning enables recursive detection');
        Setup.FrontEndCombo.ItemIndex := 2;
        Setup.SelectionChanged(nil);
        Check(not Setup.SearchAllCheck.Visible and Setup.RecursiveCheck.Enabled,
          'Generic frontend scanning always uses common names and exposes recursion');
      finally
        Setup.Free
      end;
    finally
      Settings.Free
    end;
    LinkFixture := GetEnvironmentVariable('SKRAPERFMX_DIRECTORY_LINK_FIXTURE');
    if LinkFixture <> '' then
    begin
      Check(IsPathWithin(LinkFixture, TPlatformPath.Combine(WritableBase, 'tests')),
        'Directory link fixture stays in the test workspace');
      Check(DirectoryIdentity(TPlatformPath.Combine(LinkFixture, 'native')) =
        DirectoryIdentity(TPlatformPath.Combine(LinkFixture, 'linked')),
        'Directory identity follows junctions and symlinks');
      Found := DetectPlatforms(Catalog, LinkFixture, 4, True, False);
      Check(Length(Found) = 4, 'Recursive detection follows separate link paths and stops only ancestor cycles');
    end;
  finally
    {$IFDEF MSWINDOWS}
    SetFileAttributes(PChar(TPlatformPath.Combine(Root, '.hidden')), FILE_ATTRIBUTE_NORMAL);{$ENDIF}
    Catalog.Free;
  end;
end;

procedure RunDirectoryDetectionSelfTests;
var
  Report: TStringList;
begin
  Report := TStringList.Create;
  try
    try
      RunDirectoryDetectionRegressions(Report);
      Report.Add('ALL DIRECTORY DETECTION TESTS PASSED');
    except
      on E: Exception do
      begin
        Report.Add(E.ClassName + ': ' + E.Message);
        ExitCode := 1
      end;
    end;
    ForceDirectories(TPlatformPath.Combine(WritableBase, 'tests/output'));
    Report.SaveToFile(TPlatformPath.Combine(WritableBase,
        'tests/output/directory-detection-results.txt'), TEncoding.UTF8);
  finally
    Report.Free
  end;
end;

procedure RunFeatureTests(Report: TStrings);
var
  Catalog, Master, Target, Config, Source, Media, Credentials, Response: TJSONObject;
  A: TJSONArray;
  IDs: TArray<Integer>;
  Found: TArray<TDetectedPlatform>;
  Sources: TDictionary<string, string>;
  Folder, Cache, Path, Expected, Epoch, Before: string;
  I, Count: Integer;
  Cancelled: Boolean;
  Settings: TSkraperConfig;
  Worker: TScrapeWorker;
  Status: TScrapeStatus;
  Lines: TStringList;
  Started: UInt64;
  Main: TFormMain;
  Setup: TFormSetup;
  Bitmap: TBitmap;

  procedure Check(Condition: Boolean; const Name: string);
  begin
    if not Condition then
      raise Exception.Create('FAIL: ' + Name);
    Report.Add('PASS: ' + Name);
  end;

  procedure PutFile(const Relative: string);
  begin
    Path := TPlatformPath.Combine(Cache, Relative);
    ForceDirectories(ExtractFilePath(Path));
    TFile.WriteAllText(Path, 'fixture', TEncoding.UTF8);
  end;

begin
  RunDirectoryDetectionRegressions(Report);
  RunGameLibraryTests(Report);
  RunSelectedParityTests(Report);
  Folder := TPlatformPath.Combine(WritableBase, 'tests/features-' + TGUID.NewGuid.ToString.Trim(['{', '}']));
  ForceDirectories(Folder);
  Catalog := TJSONObject.ParseJSONValue('{"systemes":[' +
    '{"id":1,"parentid":0,"type":"Console","romtype":"rom","extensions":"md,bin","noms":{"nom_us":"Sega Mega Drive","nom_eu":"Mega / Drive: EU","nom_retropie":"megadrive","noms_commun":"Sega Mega Drive,Multi Platform,megadrive"}},' +
    '{"id":2,"parentid":0,"type":"Console","extensions":"sms","noms":{"nom_us":"Master System","nom_retropie":"megadrive","noms_commun":"Multi Platform,megadrive"}},' +
    '{"id":3,"parentid":1,"extensions":"32x","noms":{"nom_us":"Child","nom_retropie":"megadrive","noms_commun":"Multi Platform"}},' +
    '{"id":4,"parentid":0,"type":"Arcade","extensions":"zip","noms":{"nom_us":"Arcade","nom_recalbox":"mame","noms_commun":"mame"}},' +
    '{"id":5,"parentid":0,"type":"Console","romtype":"ISO","extensions":"cue,iso","noms":{"nom_us":"CD console"}}]}') as TJSONObject;
  Master := ReadJSON(TPlatformPath.Combine(AppBase, DefaultConfigPath));
  Config := TJSONObject.Create;
  Target := TJSONObject.Create;
  Credentials := TJSONObject.Create;
  try
    Source := JValue(Master, 'AllSystems').Clone as TJSONObject;
    Master.Free;
    Master := Source;
    JSet(Master, 'Miscellaneous.Regions', TJSONArray.Create.Add('eu').Add('us'));
    IDs := LookupPlatforms(Catalog, 'megadrive', 1, True, False);
    Check((Length(IDs) = 2) and (IDs[0] = 1) and (IDs[1] = 2), 'Platform lookup keeps independent secondary databases and removes descendants');
    IDs := LookupPlatforms(Catalog, 'Sega-Mega-Drive', 4, True, True);
    Check((Length(IDs) = 1) and (IDs[0] = 1), 'Generic platform detection normalizes punctuation and whitespace');
    IDs := LookupPlatforms(Catalog, 'Sega Mega Driv', 4, True, True);
    Check((Length(IDs) = 1) and (IDs[0] = 1), 'Generic platform detection accepts close folder-name variants');
    IDs := LookupPlatforms(Catalog, 'totally unrelated', 4, True, True);
    Check(Length(IDs) = 0, 'Fuzzy platform matching rejects unrelated folders');
    ForceDirectories(TPlatformPath.Combine(Folder, 'roms/group/megadrive'));
    ForceDirectories(TPlatformPath.Combine(Folder, 'roms/.hidden/mame'));
    Found := DetectPlatforms(Catalog, TPlatformPath.Combine(Folder, 'roms'), 1, False, True);
    Check(Length(Found) = 0, 'Nonrecursive platform detection does not include nested platforms');
    Found := DetectPlatforms(Catalog, TPlatformPath.Combine(Folder, 'roms'), 1, True, True);
    Check(Length(Found) = 2, 'Recursive detection finds nested platforms including hidden trees');
    Cancelled := False;
    try
      DetectPlatforms(Catalog, TPlatformPath.Combine(Folder, 'roms'), 1, True, True,
        function: Boolean
        begin
          Result := True
        end);
    except
      on E: EAbort do
        Cancelled := True
    end;
    Check(Cancelled, 'Platform detection has a cancellation boundary');

    Settings := TSkraperConfig.Create(TPlatformPath.Combine(Folder, 'wizard'));
    try
      JSet(Settings.Root, 'Systems', TJSONArray.Create);
      JSet(Settings.Root, 'FrontEnd.Type', TJSONNumber.Create(1));
      JSet(Settings.Root, 'AllSystems.GamesAndRoms.Path', TJSONString.Create(TPlatformPath.Combine(Folder, 'roms')));
      Setup := TFormSetup.Create(nil);
      try
        Setup.Configure(Settings, Catalog, True);
        Setup.WizardOffline.IsChecked := True;
        Setup.ApplyButtonClick(nil);
        Check(not Setup.RecursiveCheck.IsChecked and not Setup.SearchAllCheck.IsChecked,
          'Detection options default to nonrecursive standard scanning like the original wizard');
        Setup.SearchAllCheck.IsChecked := True;
        Setup.RecursiveCheck.IsChecked := True;
        Setup.ApplyButtonClick(nil);
        Check(Setup.Scanning and not Setup.ApplyButton.Enabled, 'Wizard detection runs asynchronously with editing disabled');
        Started := TThread.GetTickCount64;
        while Setup.Scanning and (TThread.GetTickCount64 - Started < 10000) do
          CheckSynchronize(20);
        Check(Setup.WizardSummaryLayout.Visible and (Settings.Root.GetValue<TJSONArray>('Systems').Count = 0),
          'Wizard reviews detected systems before changing the library');
        Setup.ApplyButtonClick(nil);
        Report.Add('Wizard scan: root=' + Setup.RootEdit.Text + ', count=' +
          Settings.Root.GetValue<TJSONArray>('Systems').Count.ToString);
        for I := 0 to Settings.Root.GetValue<TJSONArray>('Systems').Count - 1 do
          Report.Add('Wizard platform: ' + JInt(Settings.SystemAt(I), 'SystemId').ToString +
            ', secondary=' + JValue(Settings.SystemAt(I), 'SecondarySystemIds').ToJSON);
        Count := 0;
        for I := 0 to Settings.Root.GetValue<TJSONArray>('Systems').Count - 1 do
          if (JInt(Settings.SystemAt(I), 'SystemId') = 1) and
            (JValue(Settings.SystemAt(I), 'SecondarySystemIds').ToJSON = '[2]') then
            Inc(Count);
        Check(not Setup.Scanning and (Settings.Root.GetValue<TJSONArray>('Systems').Count = 2) and
          (Count = 1), 'Wizard commits detected primary and secondary systems on the UI thread');
      finally
        Setup.Free
      end;
      JSet(Settings.Root, 'Systems', TJSONArray.Create);
      Setup := TFormSetup.Create(nil);
      try
        Setup.Configure(Settings, Catalog, True);
        Before := Settings.Root.ToJSON;
        Setup.WizardOffline.IsChecked := True;
        Setup.ApplyButtonClick(nil);
        Setup.SearchAllCheck.IsChecked := True;
        Setup.RecursiveCheck.IsChecked := True;
        Setup.ApplyButtonClick(nil);
        Setup.CancelButtonClick(nil);
        Started := TThread.GetTickCount64;
        while Setup.Scanning and (TThread.GetTickCount64 - Started < 10000) do
          CheckSynchronize(20);
        Check(not Setup.Scanning and (Settings.Root.ToJSON = Before), 'Cancelling wizard detection leaves all configuration groups unchanged');
      finally
        Setup.Free
      end;
    finally
      Settings.Free
    end;

    JSet(Target, 'UniqueId', TJSONString.Create('preserved-identity'));
    ConfigurePlatform(Target, Master, Catalog, 0, TArray<Integer>.Create(4, 2), Folder);
    Check((JInt(Target, 'Miscellaneous.Method') = 2) and (JInt(Target, 'MetaData.NameDecorations') = 2048), 'Arcade creation selects filename matching and clone-type decoration');
    Check((JInt(Target, 'Overriden') = 22) and (JStr(Target, 'UniqueId') = 'preserved-identity'), 'Platform defaults preserve identity and set the correct override groups');
    Check(JValue(Target, 'GamesAndRoms.FileExtensions').ToJSON.Contains('sms') and
      (TJSONArray(JValue(Target, 'SecondarySystemIds')).Count = 1), 'System defaults merge extensions from secondary databases');
    ConfigurePlatform(Target, Master, Catalog, 0, TArray<Integer>.Create(5), Folder);
    Check((JInt(Target, 'Miscellaneous.Method') = 2) and (JInt(Target, 'MetaData.NameDecorations') = 0), 'CD defaults select filename matching without arcade decoration');
    ConfigurePlatform(Target, Master, Catalog, 0, TArray<Integer>.Create(1), Folder);
    Check(JInt(Target, 'Overriden') = 2, 'Ordinary console inherits global metadata and matching settings');

    for I := 0 to 4 do
    begin
      A := FrontendMedia(I);
      try
        case I of
          0:
            Count := 8;
          1, 3:
            Count := 3;
          2:
            Count := 12;
        else
          Count := 2
        end;
        Check(A.Count = Count, 'Frontend profile media count: ' + I.ToString);
      finally
        A.Free
      end;
    end;
    Check(DefaultMediaFolder(2, 0, 4).EndsWith('Box - Spine') and
      DefaultMediaFolder(2, 0, 7).EndsWith('Box - Full') and
      DefaultMediaFolder(2, 0, 8).EndsWith('Cart - Front') and
      DefaultMediaFolder(2, 0, 13).EndsWith('Steam Banner'), 'LaunchBox media subtypes have dedicated folders');
    JSet(Config, 'AllSystems', Master.Clone as TJSONValue);
    JSet(Config, 'FrontEnd.Type', TJSONNumber.Create(4));
    ApplyFrontendDefaults(Config, True);
    Check((JInt(Config, 'AllSystems.GameList.Type') = 3) and
      (TJSONArray(JValue(Config, 'AllSystems.Medias')).Count = 2), 'Generic profile creates Logiqx and its own media presets');
    JSet(Target, 'GameList.OutputFile', TJSONString.Create('%ROMROOTFOLDER%/%SCREENSCRAPERPLATFORM%.dat'));
    JSet(Target, 'Miscellaneous.Regions', TJSONArray.Create.Add('eu'));
    ResolveFrontendPaths(Target, JValue(Config, 'FrontEnd') as TJSONObject, Catalog);
    Check(JStr(Target, 'GameList.OutputFile').EndsWith('Mega - Drive- EU.dat'), 'ScreenScraper platform macro uses regional name and safe filename characters');
    JSet(Target, 'GamesAndRoms.Platform', TJSONString.Create('My / Library'));
    JSet(Target, 'GameList.OutputFile', TJSONString.Create('%FRONTENDROOTFOLDER%/%PLATFORM%/%SCREENSCRAPERPLATFORM%.xml'));
    JSet(Config, 'FrontEnd.Type', TJSONNumber.Create(2));
    JSet(Config, 'FrontEnd.HomePath', TJSONString.Create(Folder));
    ResolveFrontendPaths(Target, JValue(Config, 'FrontEnd') as TJSONObject, Catalog);
    Check(not JStr(Target, 'GameList.OutputFile').Contains('%') and
      JStr(Target, 'GameList.OutputFile').Contains('My - Library'), 'Both platform macros expand correctly for LaunchBox');

    JSet(Target, 'Medias', TJSONArray.Create);
    Check(EnsureRecalboxMedia(Target) = 3, 'Recalbox adds screenshot or mix, box, and logo');
    Check(EnsureRecalboxMedia(Target) = 0, 'Recalbox required-media preparation is idempotent');
    Source := TJSONObject.Create;
    try
      JSet(Source, 'Medias', FrontendMedia(1));
      AppendSystemMedia(Target, Source);
      Check(TJSONArray(JValue(Target, 'Medias')).Count = 6, 'Media copy appends to the existing destination list');
      JSet(TJSONArray(JValue(Source, 'Medias')).Items[0] as TJSONObject, 'OutputFolder', TJSONString.Create('changed'));
      Check(JStr(TJSONArray(JValue(Target, 'Medias')).Items[3], 'OutputFolder') <> 'changed', 'Copied media are independent deep clones');
    finally
      Source.Free
    end;

    Cache := TPlatformPath.Combine(Folder, 'cache-test');
    ForceDirectories(Cache);
    PutFile('Cache/api/system1.json');
    RegisterCacheFile(Cache, 1, 'api', Path);
    PutFile('Cache/api/system2.json');
    RegisterCacheFile(Cache, 2, 'api', Path);
    PutFile('Cache/media/only1.png');
    RegisterCacheFile(Cache, 1, 'media', Path);
    PutFile('Sources/media/shared.png');
    RegisterCacheFile(Cache, 1, 'media', Path);
    RegisterCacheFile(Cache, 2, 'media', Path);
    PutFile('Sources/media/only1.png');
    RegisterCacheFile(Cache, 1, 'media', Path);
    PutFile('State/MediaSources/one.json');
    RegisterCacheFile(Cache, 1, 'source-index', Path);
    PutFile('roms/media/output.png');
    RegisterCacheFile(Cache, 1, 'media', Path);
    PutFile('State/MediaIndex/output.json');
    JSet(Config, 'Systems', TJSONArray.Create);
    ClearSystemCache(Cache, Config, 1, False, True);
    Check(TFile.Exists(TPlatformPath.Combine(Cache, 'Cache/api/system1.json')), 'Media-only cache clearing preserves metadata');
    Check(not TFile.Exists(TPlatformPath.Combine(Cache, 'Cache/media/only1.png')) and
      not TFile.Exists(TPlatformPath.Combine(Cache, 'Sources/media/only1.png')) and
      not TFile.Exists(TPlatformPath.Combine(Cache, 'State/MediaSources/one.json')), 'Scoped media cleanup includes original sources and provenance indexes');
    Check(TFile.Exists(TPlatformPath.Combine(Cache, 'Sources/media/shared.png')), 'Scoped cleanup retains media owned by another system');
    Check(TFile.Exists(TPlatformPath.Combine(Cache, 'roms/media/output.png')) and
      TFile.Exists(TPlatformPath.Combine(Cache, 'State/MediaIndex/output.json')), 'Cache clearing never removes game outputs or output cleanup provenance');
    Epoch := MediaCacheEpoch(Cache, 1);
    Check((Epoch <> '') and (MediaCacheEpoch(Cache, 2) = ''), 'Media clearing invalidates only the selected bootstrap generation');
    ClearSystemCache(Cache, Config, 1, True, False);
    Check(not TFile.Exists(TPlatformPath.Combine(Cache, 'Cache/api/system1.json')) and
      TFile.Exists(TPlatformPath.Combine(Cache, 'Cache/api/system2.json')), 'Metadata cache clears only the selected system');
    ClearSystemCache(Cache, Config, 2, False, True);
    Check(not TFile.Exists(TPlatformPath.Combine(Cache, 'Sources/media/shared.png')), 'Shared cache file is removed after its final owner clears it');
    PutFile('Cache/media/unindexed.png');
    ClearSystemCache(Cache, Config, 0, True, True);
    Check(not TFile.Exists(TPlatformPath.Combine(Cache, 'Cache/media/unindexed.png')) and
      TFile.Exists(TPlatformPath.Combine(Cache, 'roms/media/output.png')), 'Global cache cleanup includes unindexed cache files and preserves outputs');
    Check(MediaCacheEpoch(Cache, 999) <> '', 'Global cache invalidation applies to systems configured later');

    JSet(Credentials, 'anonymous', TJSONBool.Create(True));
    Check((AccountCredentialValue(Credentials, 'ssid') = '_anonymous_') and
      (AccountCredentialValue(Credentials, 'sspassword') = '_no_paswword_'), 'Anonymous account uses the original API contract without stored user credentials');
    JSet(Credentials, 'ssid', TJSONString.Create('saved-user'));
    Check(AccountCredentialValue(Credentials, 'ssid') = '_anonymous_', 'Anonymous mode does not transmit a saved user login');
    JSet(Credentials, 'anonymous', TJSONBool.Create(False));
    Check(AccountCredentialValue(Credentials, 'ssid') = 'saved-user', 'Leaving anonymous mode restores the saved account');

    Cache := TPlatformPath.Combine(Folder, 'pipeline');
    ForceDirectories(TPlatformPath.Combine(Cache, 'roms'));
    TFile.WriteAllText(TPlatformPath.Combine(Cache, 'roms/Test.rom'), 'fixture');
    JSet(Config, 'AllSystems', Master.Clone as TJSONValue);
    JSet(Config, 'Anonymous', TJSONBool.Create(True));
    JSet(Config, 'FrontEnd.Type', TJSONNumber.Create(4));
    ConfigurePlatform(Target, Master, Catalog, 4, TArray<Integer>.Create(1, 2), TPlatformPath.Combine(Cache, 'roms'));
    JSet(Target, 'Miscellaneous.Method', TJSONNumber.Create(2));
    JSet(Target, 'Miscellaneous.SaveFCRCMissing', TJSONBool.Create(False));
    JSet(Target, 'GamesAndRoms.FileExtensions', TJSONArray.Create.Add('rom'));
    JSet(Target, 'GameList.Type', TJSONNumber.Create(3));
    JSet(Target, 'GameList.OutputFile', TJSONString.Create(TPlatformPath.Combine(Cache, 'roms/games.dat')));
    JSet(Target, 'Medias', TJSONArray.Create);
    JSet(Target, 'Overriden', TJSONNumber.Create(31));
    A := TJSONArray.Create;
    A.AddElement(Target.Clone as TJSONValue);
    JSet(Config, 'Systems', A);
    Response := TJSONObject.ParseJSONValue('{"response":{}}') as TJSONObject;
    try
      WriteJSON(TPlatformPath.Combine(Cache, 'Cache/api/' + THashSHA2.GetHashString('jeuInfos.php?systemeid=1&romtype=jeu&romnom=Test') + '.json'), Response)
    finally
      Response.Free
    end;
    Response := TJSONObject.ParseJSONValue('{"response":{"jeu":{"id":42,"romid":7,"systeme":{"id":2},"noms":[{"region":"us","text":"Secondary match"}],"rom":{"romregions":"us"}}}}') as TJSONObject;
    try
      WriteJSON(TPlatformPath.Combine(Cache, 'Cache/api/' + THashSHA2.GetHashString('jeuInfos.php?systemeid=2&romtype=jeu&romnom=Test') + '.json'), Response)
    finally
      Response.Free
    end;
    Worker := TScrapeWorker.Create(Config, Credentials, Cache, 0, True, 2);
    Lines := TStringList.Create;
    try
      Worker.Start;
      Started := TThread.GetTickCount64;
      while not Worker.Finished and (TThread.GetTickCount64 - Started < 30000) do
        CheckSynchronize(20);
      if not Worker.Finished then
        Worker.Terminate;
      Worker.WaitFor;
      Worker.Snapshot(Status, Lines);
      Check((Status.Errors = 0) and (Status.Found = 1) and (Status.Requests = 0), 'Secondary database fallback completes a real offline scraping pipeline');
      Check((Length(Status.Engines) = 1) and (Status.Completed = 1), 'Anonymous pipeline uses one worker and no account-validation requests');
    finally
      Worker.Free;
      Lines.Free
    end;

    Sources := PreviewSources(Catalog, Target, 0);
    try
      Check(Sources.ContainsKey('box-2D-back') and Sources.ContainsKey('support-texture') and
        Sources.ContainsKey('system:bezel-4-3') and Sources.ContainsKey('genre:pictoliste#1'), 'Preview prepares extended game and system sample media');
      Check((Sources['@systemid'] = '1') and (Sources['@parent:3'] = '1') and
        Sources.ContainsKey('@name') and Sources.ContainsKey('@minplayers'), 'Preview supplies selected system, ancestry, and text metadata');
    finally
      Sources.Free
    end;
    Media := TJSONObject.ParseJSONValue('{"Type":0,"Image":3}') as TJSONObject;
    try
      Check(MediaPreview(Media, Target, Catalog, 0, Folder).EndsWith('snesbox2Dfront.png'), 'Box preview uses the box sample instead of a screenshot');
      JSet(Media, 'Image', TJSONNumber.Create(10));
      Check(MediaPreview(Media, Target, Catalog, 0, Folder).EndsWith('sneswheel.png'), 'Wheel preview uses the wheel sample');
      Path := TPlatformPath.Combine(Folder, 'conditional.xml');
      TFile.WriteAllText(Path, '<ImageComposition><Info LongName="Conditional sample"/>' +
        '<Viewport Width="200" Height="100"/><Drawings><Item Type="Text" Text="%NAME%" ' +
        'IfSystem="IsInTheListOrAncestors:1" TextColor="#FFFFFFFF"><Display Width="100%" Height="100%"/></Item>' +
        '</Drawings></ImageComposition>', TEncoding.UTF8);
      Check(MixTitle(Path) = 'Conditional sample', 'Media editor reads the user mix display name');
      JSet(Media, 'Type', TJSONNumber.Create(2));
      JSet(Media, 'LocalMixFile', TJSONString.Create(Path));
      JSet(Target, 'SystemId', TJSONNumber.Create(3));
      Expected := MediaPreview(Media, Target, Catalog, 0, TPlatformPath.Combine(Folder, 'preview'));
      Bitmap := TBitmap.Create;
      try
        Bitmap.LoadFromFile(Expected);
        Check((Bitmap.Width = 320) and (Bitmap.Height = 160), 'Conditional text mix preview preserves viewport aspect ratio and selected-system ancestry');
        JSet(Media, 'ResizeWidth', TJSONBool.Create(True));
        JSet(Media, 'ResizeHeight', TJSONBool.Create(True));
        JSet(Media, 'KeepRatio', TJSONBool.Create(False));
        JSet(Media, 'ResizeWidthValue', TJSONNumber.Create(100));
        JSet(Media, 'ResizeHeightValue', TJSONNumber.Create(100));
        Expected := MediaPreview(Media, Target, Catalog, 0, TPlatformPath.Combine(Folder, 'preview'));
        Bitmap.LoadFromFile(Expected);
        Check(Bitmap.Width = Bitmap.Height, 'Preview reflects deliberate output stretching when aspect ratio is disabled');
      finally
        Bitmap.Free
      end;
    finally
      Media.Free
    end;

    Settings := TSkraperConfig.Create(TPlatformPath.Combine(Folder, 'preferences'));
    try
      Settings.RememberFolder('GameAndRomFolder', Folder);
      Settings.RememberFolder('GamelistFolder', Cache);
      JSet(Settings.Root, 'Culture', TJSONString.Create('en'));
      JSet(Settings.Root, 'SampleSet', TJSONNumber.Create(4));
      A := TJSONArray.Create;
      A.AddElement(Target.Clone as TJSONValue);
      JSet(Settings.Root, 'Systems', A);
      Settings.ResetSystemSettings(0, Catalog);
      Check((JInt(Settings.SystemAt(0), 'SystemId') = 3) and
        (JStr(Settings.SystemAt(0), 'UniqueId') = 'preserved-identity'), 'System reset preserves identity and rebuilds catalogue defaults');
      Settings.Save;
      Settings.Load(TPlatformPath.Combine(Settings.Base, ConfigFileName));
      Check(SamePath(Settings.DialogFolder('GameAndRomFolder', '%ROMROOTFOLDER%'), Folder) and
        SamePath(Settings.DialogFolder('GamelistFolder', 'missing'), Cache), 'Last folders survive save and reload and resolve macro-based dialog fields');
      Check((JStr(Settings.Root, 'Culture') = 'en') and (JInt(Settings.Root, 'SampleSet') = 4), 'Language and preview sample selection survive configuration reload');
    finally
      Settings.Free
    end;

    SetLocale('en-US');
    Check((CurrentLocale = 'en') and (L('НАЗВАНИЕ ИГРЫ') = 'GAME NAME') and
      (L('Поток %d', [2]) = 'Thread 2'), 'Localization normalizes culture codes and translates runtime format strings');
    Main := TFormMain.Create(nil);
    Setup := TFormSetup.Create(nil);
    try
      Main.UILanguage.ItemIndex := 1;
      Check(Main.NavLibrary.Text.Trim = 'Library', 'Changing language translates existing FMX controls');
      Main.UILanguage.ItemIndex := 0;
      Check(Main.NavLibrary.Text.Trim = 'Библиотека', 'Switching language back restores the original labels');
      Check((Main.EditSecondarySystems <> nil) and (Main.MediaPreviewImage <> nil) and
        (Main.CheckBoxAnonymous <> nil), 'Secondary systems, media preview, and anonymous account controls stream from FMX');
      Main.UILanguage.ItemIndex := 1;
      Setup.StyleBook := Main.StyleBookWinUI3;
      ApplyLocale(Setup);
      Setup.LoadCatalog(Catalog);
      Setup.FrontEndCombo.ItemIndex := 2;
      Setup.SelectionChanged(nil);
      Main.PageTabControl.TabIndex := 2;
      Main.SettingsTabControl.ActiveTab := Main.TabMedia;
      Check(Main.PageTitle.Text = 'Settings', 'Runtime page titles follow the selected interface language');
      Main.PanelScrollMediaOuter.ViewportPosition := PointF(0, 180);
      Main.ClientWidth := 1400;
      Main.ClientHeight := 900;
      Application.ProcessMessages;
      Bitmap := TBitmap.Create(1400, 900);
      try
        if Bitmap.Canvas.BeginScene then
        try
          Main.PaintTo(Bitmap.Canvas)
        finally
          Bitmap.Canvas.EndScene
        end;
        Bitmap.SaveToFile(TPlatformPath.Combine(WritableBase, 'tests/features-media-en.png'));
      finally
        Bitmap.Free
      end;
      Main.SettingsTabControl.ActiveTab := Main.TabAccount;
      Application.ProcessMessages;
      Bitmap := TBitmap.Create(1400, 900);
      try
        if Bitmap.Canvas.BeginScene then
        try
          Main.PaintTo(Bitmap.Canvas)
        finally
          Bitmap.Canvas.EndScene
        end;
        Bitmap.SaveToFile(TPlatformPath.Combine(WritableBase, 'tests/features-account-en.png'));
      finally
        Bitmap.Free
      end;
      Check((Setup.RecursiveCheck <> nil) and (Setup.SearchAllCheck <> nil) and
        (Setup.FrontendHomeEdit <> nil), 'Setup streams recursive detection, nonstandard matching, and frontend-home controls');
      Check(Setup.FrontendHomeLabel.AbsoluteRect.Bottom <= Setup.FrontendHomeEdit.AbsoluteRect.Top, 'LaunchBox home label stays above its input after frontend visibility changes');
      Bitmap := TBitmap.Create(Round(Setup.ClientWidth), Round(Setup.ClientHeight));
      try
        if Bitmap.Canvas.BeginScene then
        try
          Setup.PaintTo(Bitmap.Canvas)
        finally
          Bitmap.Canvas.EndScene
        end;
        Bitmap.SaveToFile(TPlatformPath.Combine(WritableBase, 'tests/features-setup-en.png'));
      finally
        Bitmap.Free
      end;
    finally
      Setup.Free;
      Main.Free;
      SetLocale('ru')
    end;
  finally
    Credentials.Free;
    Target.Free;
    Config.Free;
    Master.Free;
    Catalog.Free
  end;
end;

end.

