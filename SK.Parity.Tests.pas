unit SK.Parity.Tests;

interface

uses System.Classes;

procedure RunSelectedParityTests(Report: TStrings);
procedure RunSelectedParitySelfTests;
procedure RunEditVisibilitySelfTests;
procedure RunEditVisibilityRegressions(Report: TStrings);
procedure RunWizardConceptSelfTests;

implementation

uses System.SysUtils, System.IOUtils, System.JSON, System.Hash, System.Types,
  System.Generics.Collections, FMX.Forms, FMX.Graphics, FMX.Types, FMX.Edit, FMX.Edit.Style.New,
  FMX.Controls, FMX.StdCtrls, System.Math,
  SK.Platform, SK.Core, SK.Consts, SK.Data, SK.Catalog, SK.Artwork, SK.Engine,
  SK.Setup, SK.Main, SK.Locale, SK.Preview;

procedure RunSelectedParityTests(Report: TStrings);
var Root, Before, BeforeCredentials, Path, URL, Kind, Parent, Actual, Culture: string;
  Settings: TSkraperConfig; Setup: TFormSetup; Main, StyleHost: TFormMain;
  Catalog, Old, Imported, Game, Item, Entry, Slot, Response, Target: TJSONObject;
  SystemMedia, GameMedia, Slots: TJSONArray; Bitmap: TBitmap;
  Sources: TDictionary<string, string>; Worker: TScrapeWorker;
  Status: TScrapeStatus; Lines: TStringList; Queue: TInputQueue;
  I, Code, Done: Integer; Started: UInt64; Rejected: Boolean;

  procedure Check(OK: Boolean; const Name: string);
  begin
    if not OK then raise Exception.Create('FAIL: ' + Name);
    Report.Add('PASS: ' + Name);
  end;

  procedure PaintWizard(const Name: string);
  var Picture: TBitmap;
  begin
    Application.ProcessMessages;
    Picture := TBitmap.Create(Round(Setup.ClientWidth), Round(Setup.ClientHeight));
    try
      if Picture.Canvas.BeginScene then
      try Setup.PaintTo(Picture.Canvas) finally Picture.Canvas.EndScene end;
      Picture.SaveToFile(TPlatformPath.Combine(WritableBase, 'tests/output/parity-' + Name + '.png'));
    finally Picture.Free end;
  end;

begin
  ForceDirectories(TPlatformPath.Combine(WritableBase, 'tests/output'));
  Root := TPlatformPath.Combine(WritableBase, 'tests/parity-' + TGUID.NewGuid.ToString);
  Settings := TSkraperConfig.Create(Root);
  Catalog := TJSONObject.ParseJSONValue('{"systemes":[' +
    '{"id":1,"type":"Console","extensions":"rom","noms":{"nom_us":"Console One","nom_recalbox":"console"}},' +
    '{"id":2,"type":"Arcade","noms":{"nom_us":"Arcade Two","nom_recalbox":"arcade"}},' +
    '{"id":168,"type":"Arcade","noms":{"nom_us":"Non-game"}},' +
    '{"id":40,"type":"Flipper","noms":{"nom_us":"Pinball"}}]}') as TJSONObject;
  try
    Check(not JBool(Settings.Root, 'IsConfigured') and
      (TJSONArray(JValue(Settings.Root, 'Systems')).Count = 0) and
      (JStr(Settings.Root, 'AllSystems.GamesAndRoms.Path') = ''), 'G07: fresh configuration is empty on every platform');
    Old := Settings.Root.Clone as TJSONObject;
    try
      JSet(Old, 'ConfigVersion', TJSONNumber.Create(1));
      JSet(Old, 'IsConfigured', TJSONBool.Create(True));
      JSet(Old, 'AllSystems.GamesAndRoms.Path', TJSONString.Create('H:\ROMS'));
      JSet(Old, 'Systems', TJSONArray.Create.Add(TJSONObject.Create.AddPair('SystemId', TJSONNumber.Create(1))));
      WriteJSON(TPlatformPath.Combine(Root, 'old/' + ConfigFileName), Old);
    finally Old.Free end;
    Settings.Free; Settings := TSkraperConfig.Create(TPlatformPath.Combine(Root, 'old'));
    Check(not JBool(Settings.Root, 'IsConfigured') and
      (TJSONArray(JValue(Settings.Root, 'Systems')).Count = 0), 'G01/G07: obsolete FMX settings are discarded');
    Imported := ReadJSON(TPlatformPath.Combine(AppBase, DefaultConfigPath));
    try
      JSet(Imported, 'ConfigVersion', TJSONNumber.Create(0));
      JSet(Imported, 'AllSystems.MetaData.NameCase', TJSONNumber.Create(1));
      JSet(Imported, 'AllSystems.MetaData.DescriptionCase', TJSONNumber.Create(1));
      JSet(Imported, 'AllSystems.MetaData.GenreCase', TJSONNumber.Create(1));
      JSet(Imported, 'AllSystems.MetaData.MoveArticles', TJSONBool.Create(False));
      JSet(Imported, 'AllSystems.MetaData.NameDecorations', TJSONNumber.Create(0));
      JSet(Imported, 'AllSystems.Miscellaneous.Languages', TJSONArray.Create.Add('en'));
      WriteJSON(TPlatformPath.Combine(Root, 'original-import.json'), Imported);
    finally Imported.Free end;
    Settings.Load(TPlatformPath.Combine(Root, 'original-import.json'));
    Game := TJSONObject.ParseJSONValue('{"id":42,"noms":[{"region":"us","text":"Mixed Name"}],' +
      '"synopsis":[{"langue":"en","text":"Mixed Description"}],' +
      '"genres":[{"noms":[{"langue":"en","text":"Mixed Genre"}]}]}') as TJSONObject;
    try
      for I := 0 to 2 do
      begin
        JSet(Settings.SystemAt(-1), 'MetaData.NameCase', TJSONNumber.Create(I));
        JSet(Settings.SystemAt(-1), 'MetaData.DescriptionCase', TJSONNumber.Create(I));
        JSet(Settings.SystemAt(-1), 'MetaData.GenreCase', TJSONNumber.Create(I));
        Item := DescribeGame(Game, Settings.SystemAt(-1), 'Mixed Name.rom');
        try
          case I of
            0: Check((JStr(Item, 'name') = 'Mixed Name') and (JStr(Item, 'desc') = 'Mixed Description') and
              (JStr(Item, 'genre') = 'Mixed Genre'), 'G01: imported case 0 preserves text');
            1: Check((JStr(Item, 'name') = 'MIXED NAME') and (JStr(Item, 'desc') = 'MIXED DESCRIPTION') and
              (JStr(Item, 'genre') = 'MIXED GENRE'), 'G01: imported case 1 uppercases name, description and genre');
            2: Check((JStr(Item, 'name') = 'mixed name') and (JStr(Item, 'desc') = 'mixed description') and
              (JStr(Item, 'genre') = 'mixed genre'), 'G01: imported case 2 lowercases name, description and genre');
          end;
        finally Item.Free end;
      end;
    finally Game.Free end;

    for Code in TArray<Integer>.Create(423, 426, 431) do
      for Parent in TArray<string>.Create('ScreenScraper', 'Media') do
      begin
        Rejected := False; Queue := TInputQueue.Create(TArray<string>.Create('one.rom', 'two.rom'));
        try
          Queue.Pop(Path);
          try CheckScreenScraperHTTPStatus(Code, Parent)
          except on E: EScreenScraperFatal do
            begin Rejected := E.StatusCode = Code; Queue.Stop(E.Message) end end;
          Check(Rejected and Queue.Stopped and not Queue.Pop(Path),
            'G02: ' + Parent + ' HTTP ' + Code.ToString + ' stops the shared queue');
        finally Queue.Free end;
      end;

    SystemMedia := TJSONArray.Create; GameMedia := TJSONArray.Create; Slots := TJSONArray.Create;
    Bitmap := TBitmap.Create(8, 8);
    try
      Bitmap.Clear($FF3498DB);
      for I := Low(ScreenScraperExtendedImageTypes) to High(ScreenScraperExtendedImageTypes) do
      begin
        Kind := ScreenScraperExtendedImageTypes[I]; Parent := 'jeu'; Actual := Kind;
        if Kind.Contains(':') then
        begin Parent := Kind.Substring(0, Kind.IndexOf(':')); Actual := Kind.Substring(Kind.IndexOf(':') + 1) end;
        if Actual.Contains('#') then Actual := Actual.Substring(0, Actual.IndexOf('#'));
        URL := 'https://screenscraper.fr/parity-fixture/image' + I.ToString;
        Path := TPlatformPath.Combine(Settings.Base, 'Cache/media/' + THashSHA2.GetHashString(URL) + '.png');
        ForceDirectories(ExtractFilePath(Path)); Bitmap.SaveToFile(Path);
        Entry := TJSONObject.Create.AddPair('type', Actual).AddPair('parent', Parent).
          AddPair('subparent', 'PEGI').AddPair('format', 'png').AddPair('region', 'us').AddPair('url', URL);
        if Parent = 'system' then SystemMedia.AddElement(Entry) else GameMedia.AddElement(Entry);
        Slot := TJSONObject.Create.AddPair('Type', TJSONNumber.Create(0)).AddPair('Image', TJSONNumber.Create(I)).
          AddPair('OutputFolder', TPlatformPath.Combine(Settings.Base, 'exports/image' + I.ToString)).
          AddPair('ResizeWidth', TJSONBool.Create(False)).AddPair('ResizeHeight', TJSONBool.Create(False)).
          AddPair('Optimize', TJSONBool.Create(False)).AddPair('LinkToNode', TJSONBool.Create(False));
        Slots.AddElement(Slot);
      end;
    finally Bitmap.Free end;
    JSet(TJSONArray(JValue(Catalog, 'systemes')).Items[0] as TJSONObject, 'medias', SystemMedia);
    Done := RefreshPlatformArtwork(Catalog, Settings.SystemAt(-1), Settings.Credentials, Settings.Base, True);
    Check(Done = 4, 'G09: wheel, logo, photo and icon load through the offline cache');
    for Kind in TArray<string>.Create('wheel', 'logo', 'photo', 'icon') do
      Check(PlatformArtwork(Settings.Base, 1, Kind) <> '', 'G09: platform ' + Kind + ' has a usable cache index');
    Entry := SystemMedia.Items[2] as TJSONObject;
    JSet(Entry, 'md5', TJSONString.Create('00000000000000000000000000000000'));
    Rejected := False;
    try RefreshPlatformArtwork(Catalog, Settings.SystemAt(-1), Settings.Credentials, Settings.Base, True)
    except on E: EScreenScraper do Rejected := True end;
    Check(Rejected and (PlatformArtwork(Settings.Base, 1, 'wheel') = ''),
      'G09: a changed checksum invalidates the old cached artwork');
    Entry.RemovePair('md5').Free;
    Bitmap := TBitmap.Create(8, 8);
    try Bitmap.Clear($FF3498DB); Bitmap.SaveToFile(TPlatformPath.Combine(Settings.Base,
      'Cache/media/' + THashSHA2.GetHashString(JStr(Entry, 'url')) + '.png'))
    finally Bitmap.Free end;
    RefreshPlatformArtwork(Catalog, Settings.SystemAt(-1), Settings.Credentials, Settings.Base, True);
    Rejected := False;
    try RefreshPlatformArtwork(Catalog, Settings.SystemAt(-1), Settings.Credentials, Settings.Base, True,
      function: Boolean begin Result := True end)
    except on E: EAbort do Rejected := True end;
    Check(Rejected, 'G09: artwork refresh respects cancellation');

    StyleHost := TFormMain.Create(nil);
    Setup := TFormSetup.Create(nil);
    try
      Setup.StyleBook := StyleHost.StyleBookWinUI3;
      Setup.Configure(Settings, Catalog, False);
      Check(Setup.SystemList.Items.Count = 2, 'G08: manual catalogue excludes flipper and ID 168');
      Check(not Setup.SystemList.ListItems[0].ItemData.Bitmap.IsEmpty, 'G09: catalogue displays the cached platform icon');
      Setup.ShowCategories.IsChecked := True;
      Check(Setup.SystemList.Items.Count = 4, 'G10: categories group eligible platforms');
      Setup.ToggleCategory(Setup.SystemList.ListItems[0]); CheckSynchronize;
      Check(Setup.SystemList.Items.Count = 3, 'G10: category folding preserves other categories');
      Setup.PlatformSearch.Text := 'Console';
      Check((Setup.SystemList.Items.Count = 2) and (JInt(TJSONValue(Setup.SystemList.Items.Objects[1]), 'id') = 1),
        'G10: grouped search matches platform names');
    finally Setup.Free; StyleHost.Free end;

    JSet(Settings.Root, 'Systems', TJSONArray.Create.Add(TJSONObject.Create.AddPair('SystemId', TJSONNumber.Create(999))));
    ForceDirectories(TPlatformPath.Combine(Root, 'roms/console'));
    Before := Settings.Root.ToJSON; BeforeCredentials := Settings.Credentials.ToJSON;
    StyleHost := TFormMain.Create(nil);
    Setup := TFormSetup.Create(nil);
    try
      Setup.StyleBook := StyleHost.StyleBookWinUI3;
      SetLocale('de'); ApplyLocale(Setup);
      Setup.Configure(Settings, Catalog, True); PaintWizard('wizard-account-de');
      Check(Setup.WizardAccountLayout.Visible and not Setup.SetupSourceLayout.Visible,
        'G06: full wizard starts with account and resources');
      Setup.WizardLogin.Text := 'new-fixture-login'; Setup.WizardOffline.IsChecked := True; Setup.ApplyButtonClick(nil);
      Setup.FrontEndCombo.ItemIndex := 1; Setup.RootEdit.Text := TPlatformPath.Combine(Root, 'roms');
      Setup.SelectionChanged(nil); Setup.ApplyButtonClick(nil);
      Started := TThread.GetTickCount64;
      while Setup.Scanning and (TThread.GetTickCount64 - Started < 10000) do CheckSynchronize(20);
      Check(not Setup.Scanning and Setup.WizardSummaryLayout.Visible and (Setup.WizardSummary.Count = 1) and
        ((Setup.WizardSummary.ListItems[0].FindComponent('SummaryPlatform') as TLabel).Text = 'Console One') and
        ((Setup.WizardSummary.ListItems[0].FindComponent('SummaryFolder') as TLabel).Text = TPlatformPath.Combine(Root, 'roms/console')),
        'G06: detection ends with a reviewable summary');
      Check((Settings.Root.ToJSON = Before) and (Settings.Credentials.ToJSON = BeforeCredentials),
        'G06: account, scan and summary leave the original configuration unchanged');
      PaintWizard('wizard-summary-de');
      Setup.CancelButtonClick(nil);
    finally Setup.Free; StyleHost.Free end;
    Check((Settings.Root.ToJSON = Before) and (Settings.Credentials.ToJSON = BeforeCredentials),
      'G06: cancelling the summary preserves the old library and credentials');
    Setup := TFormSetup.Create(nil);
    try
      Setup.Configure(Settings, Catalog, True); Setup.WizardLogin.Text := 'committed-fixture-login';
      Setup.WizardOffline.IsChecked := True; Setup.ApplyButtonClick(nil);
      Setup.FrontEndCombo.ItemIndex := 1; Setup.RootEdit.Text := TPlatformPath.Combine(Root, 'roms');
      Setup.SelectionChanged(nil); Setup.ApplyButtonClick(nil);
      Started := TThread.GetTickCount64;
      while Setup.Scanning and (TThread.GetTickCount64 - Started < 10000) do CheckSynchronize(20);
      Setup.ApplyButtonClick(nil);
      Check(JBool(Settings.Root, 'IsConfigured') and (TJSONArray(JValue(Settings.Root, 'Systems')).Count = 1) and
        (JInt(Settings.SystemAt(0), 'SystemId') = 1), 'G06: saving replaces the old library with detected platforms');
      Check(JStr(Settings.Credentials, 'ssid') = 'committed-fixture-login',
        'G06: saving commits the reviewed credentials together with the library');
    finally Setup.Free end;

    Target := Settings.SystemAt(0);
    ForceDirectories(TPlatformPath.Combine(Settings.Base, 'roms'));
    TFile.WriteAllText(TPlatformPath.Combine(Settings.Base, 'roms/Test.rom'), 'fixture', TEncoding.UTF8);
    JSet(Settings.Root, 'Anonymous', TJSONBool.Create(True));
    JSet(Settings.Root, 'FrontEnd.Type', TJSONNumber.Create(4));
    JSet(Target, 'GamesAndRoms.Path', TJSONString.Create(TPlatformPath.Combine(Settings.Base, 'roms')));
    JSet(Target, 'GamesAndRoms.FileExtensions', TJSONArray.Create.Add('rom'));
    JSet(Target, 'Miscellaneous.Method', TJSONNumber.Create(2));
    JSet(Target, 'Miscellaneous.SaveFCRCMissing', TJSONBool.Create(False));
    JSet(Target, 'Miscellaneous.Classification', TJSONString.Create('PEGI'));
    JSet(Target, 'Medias', Slots); JSet(Target, 'Overriden', TJSONNumber.Create(31));
    JSet(Target, 'GameList.Type', TJSONNumber.Create(1));
    JSet(Target, 'GameList.OutputFile', TJSONString.Create(TPlatformPath.Combine(Settings.Base, 'roms/gamelist.xml')));
    WriteJSON(TPlatformPath.Combine(Settings.Base, SystemsCatalogPath), Catalog);
    Response := TJSONObject.ParseJSONValue('{"response":{"jeu":{"id":42,"romid":7,"systeme":{"id":1},' +
      '"noms":[{"region":"us","text":"Test"}],"rom":{"romregions":"us"}}}}') as TJSONObject;
    try
      JSet(JValue(Response, 'response.jeu') as TJSONObject, 'medias', GameMedia);
      WriteJSON(TPlatformPath.Combine(Settings.Base, 'Cache/api/' +
        THashSHA2.GetHashString('jeuInfos.php?systemeid=1&romtype=jeu&romnom=Test') + '.json'), Response);
    finally Response.Free end;
    for I := 0 to 1 do
    begin
      JSet(Target, 'Miscellaneous.VerboseLogs', TJSONBool.Create(I = 1));
      Worker := TScrapeWorker.Create(Settings.Root, Settings.Credentials, Settings.Base, 0, True, 2);
      Lines := TStringList.Create;
      try
        Worker.Start; Started := TThread.GetTickCount64;
        while not Worker.Finished and (TThread.GetTickCount64 - Started < 30000) do CheckSynchronize(20);
        if not Worker.Finished then Worker.Terminate;
        Worker.WaitFor; Worker.Snapshot(Status, Lines);
        Lines.SaveToFile(TPlatformPath.Combine(Root, 'pipeline-' + I.ToString + '.log'), TEncoding.UTF8);
        Check((Status.Errors = 0) and (Status.Found = 1) and (Status.Requests = 0) and (Status.Saved = 28),
          'G17: all extended standalone images 17..44 export in the real offline pipeline');
        Check(Lines.Text.Contains('TRACE:') = (I = 1), 'G05: VerboseLogs controls pipeline diagnostics: ' + I.ToString);
        Check(not Lines.Text.Contains('devpassword=') and not Lines.Text.Contains('sspassword='),
          'G05: diagnostics do not expose authentication parameters');
      finally Worker.Free; Lines.Free end;
    end;
    for I := 17 to 44 do Check(TFile.Exists(TPlatformPath.Combine(Settings.Base,
      'exports/image' + I.ToString + '/Test.png')), 'G17: exported image ' + I.ToString);
    Sources := PreviewSources(Catalog, Target, 0);
    try
      for I := 17 to 44 do
      begin
        Slot := TJSONObject.Create.AddPair('Type', TJSONNumber.Create(0)).AddPair('Image', TJSONNumber.Create(I));
        try Check((MediaPreview(Slot, Target, Catalog, 0, Root) <> '') and
          (MediaPreview(Slot, Target, Catalog, 0, Root) = Sources[ScreenScraperExtendedImageTypes[I]]),
          'G17: extended image preview ' + I.ToString)
        finally Slot.Free end;
      end;
    finally Sources.Free end;

    Main := TFormMain.Create(nil);
    try
      Check(Main.RadioBoxNameCaseUpper.Hint.EndsWith('|1') and Main.RadioBoxNameCaseLower.Hint.EndsWith('|2') and
        Main.RadioBoxDescriptionCaseUpper.Hint.EndsWith('|1') and Main.RadioBoxGenreCaseLower.Hint.EndsWith('|2'),
        'G01: FMX radio bindings use the original enum');
      Check(Main.UILanguage.Items.Count = 7, 'G11: all seven interface languages are selectable');
      for I := 0 to 6 do
      begin
        Culture := UILocaleCode(I); Main.UILanguage.ItemIndex := I;
        Check((CurrentLocale = Culture) and (Main.NavLibrary.Text.Trim = SK.Locale.L('Библиотека').Trim),
          'G11: live interface translation: ' + Culture);
        SetLocale(Culture + '-fixture');
        Check(CurrentLocale = Culture, 'G11: culture normalization: ' + Culture);
      end;
    finally Main.Free; SetLocale('ru') end;
    RunEditVisibilityRegressions(Report);
  finally Catalog.Free; Settings.Free end;
end;

procedure RunSelectedParitySelfTests;
var Report: TStringList;
begin
  Report := TStringList.Create;
  try
    try RunSelectedParityTests(Report); Report.Add('ALL SELECTED PARITY TESTS PASSED')
    except on E: Exception do begin Report.Add(E.ClassName + ': ' + E.Message); ExitCode := 1 end end;
    ForceDirectories(TPlatformPath.Combine(WritableBase, 'tests/output'));
    Report.SaveToFile(TPlatformPath.Combine(WritableBase, 'tests/output/selected-parity-results.txt'), TEncoding.UTF8);
  finally Report.Free end;
end;

procedure RunWizardConceptSelfTests;
var Report: TStringList; Setup: TFormSetup; Host: TFormMain; Settings: TSkraperConfig;
  Catalog: TJSONObject; Picture: TBitmap; Root, Culture, Before, ScanRoot, Folder: string;
  I, ID: Integer; Started: UInt64; NameCell, FolderCell: TLabel; HoverPoint: TPointF;

  procedure Check(OK: Boolean; const Name: string);
  begin
    if not OK then raise Exception.Create('FAIL: ' + Name);
    Report.Add('PASS: ' + Name);
  end;

  procedure Capture(const Name: string);
  begin
    Application.ProcessMessages;
    Picture := TBitmap.Create(Round(Setup.ClientWidth), Round(Setup.ClientHeight));
    try
      if Picture.Canvas.BeginScene then
      try Setup.PaintTo(Picture.Canvas) finally Picture.Canvas.EndScene end;
      Picture.SaveToFile(TPlatformPath.Combine(Root, Name + '.png'));
    finally Picture.Free end;
  end;

begin
  Report := TStringList.Create; Setup := nil; Host := nil; Settings := nil; Catalog := nil;
  Root := TPlatformPath.Combine(WritableBase, 'tests/output/wizard-concept');
  ForceDirectories(Root);
  try
    try
      Settings := TSkraperConfig.Create(TPlatformPath.Combine(Root, 'config'));
      Catalog := ReadJSON(TPlatformPath.Combine(AppBase, SystemsCatalogPath));
      Host := TFormMain.Create(nil); Setup := TFormSetup.Create(nil);
      JSet(Settings.Credentials, 'devid', TJSONString.Create('APP_ID'));
      JSet(Settings.Credentials, 'devpassword', TJSONString.Create('concept-secret'));
      JSet(Settings.Credentials, 'ssid', TJSONString.Create('RetroPlayer'));
      JSet(Settings.Credentials, 'sspassword', TJSONString.Create('concept-password'));
      Before := Settings.Root.ToJSON;
      Setup.StyleBook := Host.StyleBookWinUI3; Setup.Configure(Settings, Catalog, True);
      Setup.Focused := Setup.WizardHelpButton; Setup.Show;
      Capture('01-idle');
      Check(not Setup.WizardStep1LineActive.Visible and not Setup.WizardStep2LineActive.Visible,
        'First stage leaves both connectors unfilled');
      Check(Setup.WizardHeaderLayout.AbsoluteRect.Bottom - Setup.WizardSteps.AbsoluteRect.Bottom >= 7.9,
        'Step indicator has breathing room above the page content');
      Check((Setup.WizardStep1Circle.AbsoluteRect.Right < Setup.WizardStep2Circle.AbsoluteRect.Left) and
        (Setup.WizardStep2Circle.AbsoluteRect.Right < Setup.WizardStep3Circle.AbsoluteRect.Left), 'Wizard steps are separate aligned columns');
      Check((Setup.WizardUserCard.AbsoluteRect.Right < Setup.WizardResourcesCard.AbsoluteRect.Left) and
        SameValue(Setup.WizardUserCard.AbsoluteRect.Top, Setup.WizardResourcesCard.AbsoluteRect.Top, 1), 'Wizard cards match the two-column concept');
      Check(SameValue(Setup.WizardApplicationCard.AbsoluteRect.Bottom, Setup.WizardResourcesCard.AbsoluteRect.Bottom, 1),
        'Resource card ends level with the application card');
      Check(Setup.WizardOffline.AbsoluteRect.Bottom <= Setup.SetupCommandsLayout.AbsoluteRect.Top,
        'Offline option stays above the fixed footer');
      Check(SameValue(Setup.WizardLogin.Height, 40, 1) and SameValue(Setup.WizardPassword.Height, 40, 1),
        'Wizard inputs use the concept height');
      Setup.PasswordRevealClick(Setup.WizardPasswordReveal);
      Check(not Setup.WizardPassword.Password and Setup.WizardPasswordEye.Visible, 'Password reveal button works');
      Setup.PasswordRevealClick(Setup.WizardPasswordReveal);
      Setup.PasswordRevealClick(Setup.WizardDeveloperPasswordReveal);
      Check(not Setup.WizardDeveloperPassword.Password, 'Application password reveal button works');
      Setup.ShowWizardPage(1); Setup.ShowWizardPage(0);
      Check(Setup.WizardPassword.Password and Setup.WizardDeveloperPassword.Password, 'Leaving account step restores password masking');
      Setup.WizardAnonymous.IsChecked := True;
      Check(not Setup.WizardLogin.Enabled and Setup.WizardDeveloper.Enabled, 'Anonymous mode disables only user credentials');
      Setup.WizardAnonymous.IsChecked := False;
      Setup.ShowResourceStatus(wrConnecting, 0, 0, 0);
      Check(not Setup.ApplyButton.Enabled and not Setup.WizardLogin.Enabled, 'Connection locks account editing and Next');
      Setup.ShowResourceStatus(wrCatalog, 0, 0, 0);
      Check(Setup.WizardConnectCheck.Visible and not Setup.WizardCatalogCheck.Visible, 'Catalogue stage preserves successful connection');
      Setup.ShowResourceStatus(wrArtwork, 243, 88, 972);
      Check(Setup.WizardConnectCheck.Visible and Setup.WizardCatalogCheck.Visible and Setup.WizardMediaSpin.Enabled and
        (Round(Setup.WizardMediaProgress.Value) = 88) and (Round(Setup.WizardMediaProgress.Max) = 972) and
        Setup.WizardMediaCount.Text.Contains('9%'), 'Artwork stage shows live 88 / 972 and 9 percent progress');
      Check(not Setup.ApplyButton.Enabled and not Setup.WizardPasswordReveal.Enabled and Setup.CancelButton.Enabled,
        'Download keeps Cancel available and disables Next and password reveal');
      Capture('02-downloading-ru');
      for I := 0 to 6 do
      begin
        Culture := UILocaleCode(I); SetLocale(Culture); ApplyLocale(Setup);
        Setup.ShowWizardPage(0); Setup.ShowResourceStatus(wrArtwork, 243, 88, 972);
        Capture('02-downloading-' + Culture);
        Check(Setup.WizardResourcesInfoRow.AbsoluteRect.Bottom <= Setup.WizardResourcesCard.AbsoluteRect.Bottom,
          'Resource information fits the card: ' + Culture);
        Setup.ShowWizardPage(1); Application.ProcessMessages;
        TCanvasManager.MeasureCanvas.Font.Assign(Setup.ApplyButton.TextSettings.Font);
        Check(TCanvasManager.MeasureCanvas.TextWidth(Setup.ApplyButton.Text) + 32 <= Setup.ApplyButton.Width,
          'Find platforms caption fits with horizontal padding: ' + Culture);
        Setup.ShowWizardPage(0);
      end;
      SetLocale('ru'); ApplyLocale(Setup);
      Setup.ShowResourceStatus(wrReady, 243, 972, 972);
      Check((Setup.TitleLabel.Text = SK.Locale.L('Настройка библиотеки')) and (Setup.ApplyButton.Text = SK.Locale.L('Далее')),
        'Runtime localization preserves the wizard heading and Next command');
      Check(Setup.ApplyButton.Enabled and Setup.WizardMediaCheck.Visible and not Setup.WizardMediaSpin.Enabled,
        'Resource completion unlocks Next and stops the activity indicator');
      Capture('03-ready');
      Setup.ShowResourceStatus(wrFailed, 0, 0, 0);
      Check(Setup.ApplyButton.Enabled and Setup.WizardLogin.Enabled, 'Resource failure permits editing and retry');
      Setup.ShowResourceStatus(wrIdle, 0, 0, 0); Setup.WizardDeveloperPassword.Text := '';
      Setup.ApplyButtonClick(nil);
      Check(Setup.WizardAccountInfo.Text = SK.Locale.L('Заполните данные подключения или выберите настройку без подключения.'),
        'Missing credentials are explained in the resource card without a network request');
      Check(not Setup.WizardMediaProgress.Visible, 'Connection validation never shows a fake artwork download');
      Capture('04-validation-error');
      Setup.WizardDeveloperPassword.Text := 'concept-secret';
      Setup.ShowResourceStatus(wrOffline, 243, 0, 0);
      Check(not Setup.WizardMediaProgress.Visible and not Setup.WizardConnectCheck.Visible,
        'Offline state never claims an authenticated network connection');
      Setup.ShowWizardPage(1); Capture('04-platforms');
      Check(Setup.WizardStep1LineActive.Visible and not Setup.WizardStep2LineActive.Visible and
        SameValue(Setup.WizardStep1LineActive.Width, Setup.WizardStep1LineLayout.Width, 0.1),
        'Second stage completely fills only the first connector');
      Check(Setup.SetupCommandsLayout.AbsoluteRect.Top - Setup.PlatformPanel.AbsoluteRect.Bottom >= 15.9,
        'Platform card keeps a sixteen-pixel gap above the footer');
      Setup.ShowWizardPage(2); Capture('05-summary-empty');
      Check(Setup.WizardStep1LineActive.Visible and Setup.WizardStep2LineActive.Visible and
        SameValue(Setup.WizardStep1LineActive.Width, Setup.WizardStep1LineLayout.Width, 0.1) and
        SameValue(Setup.WizardStep2LineActive.Width, Setup.WizardStep2LineLayout.Width, 0.1),
        'Final stage completely fills both connectors');
      ScanRoot := TPlatformPath.Combine(Root,
        'roms/Recalbox library with a long directory name to verify the two-column ROM folder presentation');
      for Folder in ['megadrive', 'nes', 'snes'] do ForceDirectories(TPlatformPath.Combine(ScanRoot, Folder));
      Setup.ShowWizardPage(1); Setup.FrontEndCombo.ItemIndex := 1;
      Setup.RootEdit.Text := ScanRoot; Setup.DetectCheck.IsChecked := True;
      Setup.SelectionChanged(nil); Setup.ApplyButtonClick(nil);
      Started := TThread.GetTickCount64;
      while Setup.Scanning and (TThread.GetTickCount64 - Started < 10000) do
      begin CheckSynchronize(20); Application.ProcessMessages end;
      Check(not Setup.Scanning and Setup.WizardSummaryLayout.Visible and (Setup.WizardSummary.Count = 3),
        'Scanning three platform folders produces three summary rows');
      for I := 0 to Setup.WizardSummary.Count - 1 do
      begin
        NameCell := Setup.WizardSummary.ListItems[I].FindComponent('SummaryPlatform') as TLabel;
        FolderCell := Setup.WizardSummary.ListItems[I].FindComponent('SummaryFolder') as TLabel;
        Folder := System.IOUtils.TPath.GetFileName(FolderCell.Text);
        ID := 0;
        if Folder = 'megadrive' then ID := 1 else if Folder = 'nes' then ID := 3 else if Folder = 'snes' then ID := 4;
        Check((ID <> 0) and (NameCell.Text = PlatformName(Catalog, Settings.SystemAt(-1), ID)) and
          (FolderCell.Text = TPlatformPath.Combine(ScanRoot, Folder)), 'Summary pairs platform and exact ROM folder: ' + Folder);
        Check(Setup.WizardSummary.ListItems[I].Hint.Contains(FolderCell.Text) and not FolderCell.TextSettings.WordWrap and
          (FolderCell.TextSettings.Trimming = TTextTrimming.Character), 'Long ROM folder remains available in the row hint: ' + Folder);
      end;
      for I := 0 to 6 do
      begin
        Culture := UILocaleCode(I); SetLocale(Culture); ApplyLocale(Setup); Setup.ShowWizardPage(2);
        Capture('05-summary-' + Culture);
        Check((Setup.WizardSummaryPlatformColumn.Text = SK.Locale.L('Платформа')) and
          (Setup.WizardSummaryFolderColumn.Text = SK.Locale.L('Папка ROM')) and (Setup.WizardSummary.Count = 3),
          'Summary columns localize without duplicating scan results: ' + Culture);
      end;
      SetLocale('ru'); ApplyLocale(Setup); Setup.ShowWizardPage(2); Capture('05-summary');
      NameCell := Setup.WizardSummary.ListItems[0].FindComponent('SummaryPlatform') as TLabel;
      FolderCell := Setup.WizardSummary.ListItems[0].FindComponent('SummaryFolder') as TLabel;
      Check(NameCell.AbsoluteRect.Right < FolderCell.AbsoluteRect.Left,
        'Summary cells occupy separate columns');
      HoverPoint := Setup.WizardSummary.AbsoluteToLocal(FolderCell.AbsoluteRect.CenterPoint);
      Setup.SummaryMouseMove(Setup.WizardSummary, [], HoverPoint.X, HoverPoint.Y);
      Check(Setup.WizardSummary.ShowHint and not Setup.WizardSummary.ParentShowHint and
        Setup.WizardSummary.Hint.Contains(FolderCell.Text),
        'Hovering a summary row exposes its complete ROM path through the list hint');
      Check(Setup.WizardSummaryCard.AbsoluteRect.Bottom <= Setup.SetupCommandsLayout.AbsoluteRect.Top - 15.9,
        'Summary list stays above the footer with a sixteen-pixel gap');
      Setup.ShowWizardPage(1); Setup.ShowWizardPage(0); Application.ProcessMessages;
      Check(not Setup.WizardStep1LineActive.Visible and not Setup.WizardStep2LineActive.Visible,
        'Going back clears connectors for stages no longer reached');
      Setup.CancelButtonClick(nil);
      Check(Settings.Root.ToJSON = Before, 'Visual state changes and cancellation leave configuration unchanged');
      Report.Add('ALL WIZARD CONCEPT TESTS PASSED');
    except on E: Exception do begin Report.Add(E.ClassName + ': ' + E.Message); ExitCode := 1 end end;
    Report.SaveToFile(TPlatformPath.Combine(Root, 'results.txt'), TEncoding.UTF8);
  finally Setup.Free; Host.Free; Catalog.Free; Settings.Free; Report.Free; SetLocale('ru') end;
end;

procedure RunEditVisibilityRegressions(Report: TStrings);
var Setup: TFormSetup; Host: TFormMain; Settings: TSkraperConfig;
  Catalog: TJSONObject; Picture: TBitmap; Edit: TEdit; Styled: TStyledEdit;
  Content: TControl; Pixels: TBitmapData;
  R: TRectF; Color: Cardinal; Count, X, Y, Stage: Integer; Root, StageName: string;
begin
  Root := TPlatformPath.Combine(WritableBase, 'tests/output/edit-visibility');
  ForceDirectories(Root);
  Settings := TSkraperConfig.Create(TPlatformPath.Combine(Root, 'config'));
  Catalog := ReadJSON(TPlatformPath.Combine(AppBase, SystemsCatalogPath));
  Host := TFormMain.Create(nil); Setup := TFormSetup.Create(nil);
  try
    JSet(Settings.Credentials, 'devid', TJSONString.Create('Fixture developer'));
    JSet(Settings.Credentials, 'devpassword', TJSONString.Create('Fixture secret'));
    JSet(Settings.Credentials, 'ssid', TJSONString.Create('Fixture login'));
    JSet(Settings.Credentials, 'sspassword', TJSONString.Create('Fixture password'));
    Setup.StyleBook := Host.StyleBookWinUI3;
    Setup.Configure(Settings, Catalog, True);
    Setup.Focused := Setup.ApplyButton;
    Setup.Show;
    Application.ProcessMessages;
    for Stage := 0 to 5 do
    begin
      case Stage of
        0: StageName := 'initial';
        1: begin
          StageName := 'reopened';
          Setup.ShowWizardPage(1); Setup.ShowWizardPage(0);
        end;
        2: begin
          StageName := 'resized'; Setup.ClientWidth := 760;
        end;
        3: begin
          StageName := 'updated-hidden';
          Setup.ClientWidth := 940; Setup.ShowWizardPage(1);
          Setup.WizardDeveloper.Text := 'Changed developer';
          Setup.WizardDeveloperPassword.Text := 'Changed secret';
          Setup.WizardLogin.Text := 'Changed login';
          Setup.WizardPassword.Text := 'Changed password';
          Setup.ShowWizardPage(0);
        end;
        4: begin
          StageName := 'focused';
          for Edit in TArray<TEdit>.Create(Setup.WizardDeveloper, Setup.WizardDeveloperPassword,
            Setup.WizardLogin, Setup.WizardPassword) do Edit.SetFocus;
          Setup.ApplyButton.SetFocus;
        end;
        5: begin
          StageName := 'cleared';
          for Edit in TArray<TEdit>.Create(Setup.WizardDeveloper, Setup.WizardDeveloperPassword,
            Setup.WizardLogin, Setup.WizardPassword) do Edit.Text := '';
        end;
      end;
      Application.ProcessMessages;
      Picture := TBitmap.Create(Round(Setup.ClientWidth), Round(Setup.ClientHeight));
      try
        if Picture.Canvas.BeginScene then
        try Setup.PaintTo(Picture.Canvas) finally Picture.Canvas.EndScene end;
        Picture.SaveToFile(TPlatformPath.Combine(Root, StageName + '.png'));
        if not Picture.Map(TMapAccess.Read, Pixels) then raise Exception.Create('Cannot read pixels');
        try
          for Edit in TArray<TEdit>.Create(Setup.WizardDeveloper, Setup.WizardDeveloperPassword,
            Setup.WizardLogin, Setup.WizardPassword) do
          begin
            Styled := Edit.PresentationProxy.Receiver as TStyledEdit;
            Content := Styled.Content;
            R := Edit.AbsoluteRect; R.Inflate(-8, -3);
            if Edit.ButtonsContent.ChildrenCount > 0 then R.Right := R.Right - 36;
            Count := 0;
            for Y := Max(0, Ceil(R.Top + 2)) to Min(Picture.Height - 1, Floor(R.Bottom - 2)) do
              for X := Max(0, Ceil(R.Left + 2)) to Min(Picture.Width - 1, Floor(R.Right - 2)) do
              begin
                Color := Pixels.GetPixel(X, Y);
                if ((Color shr 16) and $FF > 150) and ((Color shr 8) and $FF > 150) and
                  (Color and $FF > 150) then Inc(Count);
              end;
            Report.Add(Format('%s %s: model length=%d, content %.1fx%.1f, first=%d, last=%d, light pixels=%d',
              [StageName, Edit.Name, Edit.Text.Length, Content.Width, Content.Height,
               Styled.Editor.LinesLayout.FirstVisibleLineIndex, Styled.Editor.LinesLayout.LastVisibleLineIndex, Count]));
            if ((Stage < 5) and (Count < 20)) or ((Stage = 5) and (Count <> 0)) then
              raise Exception.Create('FAIL: FMX edit text rendering: ' + StageName + ' ' + Edit.Name);
            if Edit.IsFocused then raise Exception.Create('FAIL: Rendering changed focus');
            Report.Add('PASS: FMX edit text rendering: ' + StageName + ' ' + Edit.Name);
          end;
        finally Picture.Unmap(Pixels) end;
      finally Picture.Free end;
    end;
  finally Setup.Free; Host.Free; Catalog.Free; Settings.Free end;
end;

procedure RunEditVisibilitySelfTests;
var Report: TStringList; Root: string;
begin
  Report := TStringList.Create;
  Root := TPlatformPath.Combine(WritableBase, 'tests/output/edit-visibility');
  ForceDirectories(Root);
  try
    try RunEditVisibilityRegressions(Report); Report.Add('ALL EDIT VISIBILITY TESTS PASSED')
    except on E: Exception do begin Report.Add(E.ClassName + ': ' + E.Message); ExitCode := 1 end end;
    Report.SaveToFile(TPlatformPath.Combine(Root, 'results.txt'), TEncoding.UTF8);
  finally Report.Free end;
end;

end.
