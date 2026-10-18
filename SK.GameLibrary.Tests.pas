unit SK.GameLibrary.Tests;

interface

uses
  System.Classes;

procedure RunGameLibraryTests(Report: TStrings);

procedure RunGameLibrarySelfTests;

implementation

uses
  System.SysUtils, System.IOUtils, System.JSON, System.Hash, System.Types, System.Math,
  System.UITypes, System.Generics.Collections, System.Zip, System.StrUtils, Xml.XMLDoc,
  Xml.XMLIntf, FMX.Forms, FMX.Graphics, FMX.Types, FMX.BehaviorManager, SK.Json,
  SK.Platform, SK.GameLibrary, SK.GameLibrary.Form, SK.Engine, SK.Main,
  HGM.FMX.Image, FMX.Objects, FMX.ListBox, FMX.StdCtrls;

procedure RunGameLibraryTests(Report: TStrings);
var
  Base, Roms, ListFile, Before, Other, Path: string;
  Sys, Config, Credentials, Response: TJSONObject;
  Systems: TJSONArray;
  LibraryData: TGameLibrary;
  Draft, Doc: IXMLDocument;
  Fields: TObjectList<TLibraryField>;
  F: TLibraryField;
  Worker: TScrapeWorker;
  Status: TScrapeStatus;
  Lines: TStringList;
  Window, LazyWindow: TFormGameLibrary;
  SelectedCard, OtherCard: TListBoxItem;
  LazyConfig: TJSONObject;
  ScrollBefore: TPointF;
  Main: TFormMain;
  Bitmap: TBitmap;
  Zip: TZipFile;
  Bytes: TBytes;
  I, N: Integer;
  Raised, Found: Boolean;
  Started: UInt64;

  procedure Check(Condition: Boolean; const Name: string);
  begin
    if not Condition then
      raise Exception.Create('FAIL: ' + Name);
    Report.Add('PASS: ' + Name);
    Report.SaveToFile(TPlatformPath.Combine(Base, 'progress.txt'), TEncoding.UTF8);
  end;

  procedure WaitUntil(const Ready: TFunc<Boolean>; const Name: string);
  var
    Tick: UInt64;
  begin
    Tick := TThread.GetTickCount64;
    while not Ready() and (TThread.GetTickCount64 - Tick < 5000) do
    begin
      Application.ProcessMessages;
      CheckSynchronize(10);
    end;
    Check(Ready(), Name);
  end;

  procedure WaitPreview(Editor: TGameFieldEditor);
  begin
    WaitUntil(
      function: Boolean
      begin
        Result := not Editor.PreviewLoading
      end,
          'Preview finishes for ' + Editor.Field.Caption);
  end;

  procedure TestAsyncImages;
  var
    Owner, RemovedOwner: TComponent;
    Image, RemovedImage: TBitmap;
    Done, Success, OnUI, CancelledCallback, RemovedCallback: Boolean;
  begin
    Owner := TComponent.Create(nil);
    Image := TBitmap.Create;
    RemovedOwner := nil;
    RemovedImage := nil;
    try
      Done := False;
      Success := False;
      OnUI := False;
      Image.LoadFromFileAsync(Owner, TPlatformPath.Combine(Roms, 'replacement.png'), 48, 70,
        procedure(Loaded: Boolean)
        begin
          Done := True;
          Success := Loaded;
          OnUI := TThread.CurrentThread.ThreadID = MainThreadID;
        end);
      Check(not Done and Image.IsEmpty, 'Async decoding returns before assigning UI pixels');
      WaitUntil(
        function: Boolean
        begin
          Result := Done
        end, 'Async file decode completes');
      Check(Success and OnUI and (Image.Width = 48) and (Image.Height = 32),
        'Async thumbnails preserve aspect ratio and deliver on the UI thread');
      CancelledCallback := False;
      RemovedCallback := False;
      Image.LoadFromFileAsync(Owner, TPlatformPath.Combine(Roms, 'replacement.png'),
        procedure(Loaded: Boolean)
        begin
          CancelledCallback := True
        end);
      Image.RemoveCallback(Owner);
      RemovedOwner := TComponent.Create(nil);
      RemovedImage := TBitmap.Create;
      RemovedImage.LoadFromFileAsync(RemovedOwner, TPlatformPath.Combine(Roms, 'replacement.png'),
        procedure(Loaded: Boolean)
        begin
          RemovedCallback := True
        end);
      FreeAndNil(RemovedOwner);
      FreeAndNil(RemovedImage);
      Done := False;
      Success := True;
      Image.LoadFromFileAsync(Owner, TPlatformPath.Combine(Roms, 'missing.png'),
        procedure(Loaded: Boolean)
        begin
          Done := True;
          Success := Loaded
        end);
      WaitUntil(
        function: Boolean
        begin
          Result := Done
        end, 'Missing async image completes with a result');
      Check(not Success and not CancelledCallback and not RemovedCallback,
        'Missing files fail safely and canceled or destroyed owners receive no callback');
      Done := False;
      Success := True;
      Image.LoadFromFileAsync(Owner, TPlatformPath.Combine(Roms, 'old.png'),
        procedure(Loaded: Boolean)
        begin
          Done := True;
          Success := Loaded
        end);
      WaitUntil(
        function: Boolean
        begin
          Result := Done
        end, 'Corrupt async image completes with a result');
      Check(not Success, 'Corrupt image decoding reports failure without escaping into the UI');
    finally
      RemovedOwner.Free;
      RemovedImage.Free;
      Owner.Free;
      Image.Free
    end;
  end;

  function GameIndex(const FileName: string): Integer;
  var
    J: Integer;
  begin
    Result := -1;
    for J := 0 to LibraryData.Games.Count - 1 do
      if SamePath(LibraryData.Games[J].RomPath, TPlatformPath.Combine(Roms, FileName)) then
        Exit(J);
  end;

  procedure RunTarget(const FileName: string; Cancelled: Boolean = False);
  begin
    Worker := TScrapeWorker.Create(Config, Credentials, Base, 0, True, 2, TPlatformPath.Combine(Roms, FileName));
    Lines := TStringList.Create;
    try
      if Cancelled then
        Worker.Terminate;
      Worker.Start;
      Started := TThread.GetTickCount64;
      while not Worker.Finished and (TThread.GetTickCount64 - Started < 15000) do
        CheckSynchronize(20);
      if not Worker.Finished then
        Worker.Terminate;
      Worker.WaitFor;
      Worker.Snapshot(Status, Lines);
      Lines.SaveToFile(TPlatformPath.Combine(Base, FileName + '.log'), TEncoding.UTF8);
    finally
      Worker.Free;
      Lines.Free
    end;
  end;

  procedure CheckField(const XML, FieldName: string; Kind: Integer; Expected: Boolean; const Name: string);
  var
    TestDoc: IXMLDocument;
    TestFields: TObjectList<TLibraryField>;
    TestField: TLibraryField;
    Error: string;
    HasField, Valid: Boolean;
  begin
    TestDoc := ParseGameXML(XML, Kind);
    TestFields := TObjectList<TLibraryField>.Create(True);
    try
      LibraryFields(TestDoc.DocumentElement, TestFields);
      HasField := False;
      for TestField in TestFields do
        if TestField.Caption = FieldName then
        begin
          HasField := True;
          Valid := TestField.Validate(Kind, Roms, Error);
          Check((Valid = Expected) and (Valid = (Error = '')), Name);
          Break;
        end;
      if not HasField then
        raise Exception.Create('Missing test field: ' + FieldName);
    finally
      TestFields.Free
    end;
  end;

begin
  Base := TPlatformPath.Combine(WritableBase, 'tests/library-' + TGUID.NewGuid.ToString.Trim(['{', '}']));
  Roms := TPlatformPath.Combine(Base, 'roms');
  ForceDirectories(Roms);
  ListFile := TPlatformPath.Combine(Roms, 'gamelist.xml');
  CheckField('<game><rating>0.85</rating></game>', 'rating', 1, True, 'Unit rating accepts decimal values');
  CheckField('<game><rating>1</rating></game>', 'rating', 1, True, 'Unit rating includes its upper bound');
  CheckField('<game><rating>1.1</rating></game>', 'rating', 1, False, 'Unit rating rejects values above one');
  CheckField('<game><rating>-0.1</rating></game>', 'rating', 1, False, 'Unit rating rejects negative values');
  CheckField('<game><rating>0,8</rating></game>', 'rating', 1, False, 'Rating rejects a locale-dependent decimal comma');
  CheckField('<game><rating>NaN</rating></game>', 'rating', 1, False, 'Rating rejects non-finite values');
  CheckField('<game><rating>1e309</rating></game>', 'rating', 1, False, 'Rating rejects exponential overflow');
  CheckField('<game><rating/></game>', 'rating', 1, True, 'Optional numeric field may be empty');
  CheckField('<Game><StarRatingFloat>5</StarRatingFloat></Game>', 'StarRatingFloat', 2, True, 'LaunchBox rating uses a five-star scale');
  CheckField('<Game><StarRatingFloat>5.01</StarRatingFloat></Game>', 'StarRatingFloat', 2, False, 'LaunchBox rating rejects values above five');
  CheckField('<game><favorite>false</favorite></game>', 'favorite', 1, True, 'Boolean field accepts false');
  CheckField('<game><favorite>yes</favorite></game>', 'favorite', 1, False, 'Boolean field rejects arbitrary text');
  CheckField('<game><players>1-4</players></game>', 'players', 1, True, 'Player count accepts ordered ranges');
  CheckField('<game><players>4+</players></game>', 'players', 1, True, 'Player count accepts a lower bound');
  CheckField('<game><players>4-1</players></game>', 'players', 1, False, 'Player count rejects reversed ranges');
  CheckField('<game><players>0</players></game>', 'players', 1, False, 'Player count must be positive when specified');
  CheckField('<game><playcount>-1</playcount></game>', 'playcount', 1, False, 'Play count cannot be negative');
  CheckField('<game><playcount>999999999999999999999999</playcount></game>', 'playcount', 1, False, 'Integer overflow is rejected');
  CheckField('<game><releasedate>20240229T235959</releasedate></game>', 'releasedate', 1, True, 'Date validation accepts a real leap day');
  CheckField('<game><releasedate>20230229T000000</releasedate></game>', 'releasedate', 1, False, 'Date validation rejects an impossible leap day');
  CheckField('<game><releasedate>20240101T240000</releasedate></game>', 'releasedate', 1, False, 'Date validation rejects hour twenty-four');
  CheckField('<Game><ReleaseDate>2024-02-29T12:00:00+05:00</ReleaseDate></Game>', 'ReleaseDate', 2, True, 'ISO date supports an explicit timezone');
  CheckField('<Game><ReleaseDate>2024-02-31</ReleaseDate></Game>', 'ReleaseDate', 2, False, 'ISO date rejects an impossible calendar date');
  CheckField('<Game><ReleaseDate>2024-02-29T12:00:00+05:99</ReleaseDate></Game>', 'ReleaseDate', 2, False, 'ISO date rejects an invalid timezone');
  CheckField('<game><md5>25f9e794323b453885f5181f1b624d0b</md5></game>', 'md5', 1, True, 'MD5 accepts a complete hexadecimal checksum');
  CheckField('<game><md5>invalid</md5></game>', 'md5', 1, False, 'MD5 rejects malformed checksums');
  CheckField('<game><sha1>f7c3bc1d808e04732adf679965ccc34ca7ae3441</sha1></game>', 'sha1', 1, True, 'SHA-1 accepts forty hexadecimal digits');
  CheckField('<game><hash>CBF43926</hash></game>', 'hash', 1, True, 'CRC32 accepts eight hexadecimal digits');
  CheckField('<game><rom name="A.rom" crc="abc"/></game>', 'rom/@crc', 3, False, 'DAT ROM attributes use the same checksum validation');
  CheckField('<game><path/></game>', 'path', 1, False, 'ROM path cannot be empty');
  CheckField('<game><path>./*.rom</path></game>', 'path', 1, False, 'ROM path cannot contain a wildcard');
  CheckField('<game><image>https://example.com/image.png</image></game>', 'image', 1, False, 'Media must reference a local path');
  CheckField('<game><image>./image.exe</image></game>', 'image', 1, False, 'Image field rejects an incompatible file extension');
  CheckField('<game><image>./media/image.png</image></game>', 'image', 1, True, 'Image field accepts a relative image path');
  CheckField('<game><video>./video.jpg</video></game>', 'video', 1, False, 'Video field rejects an image extension');
  CheckField('<Game><ID>12345678-1234-1234-1234-123456789abc</ID></Game>', 'ID', 2, True, 'LaunchBox GUID accepts its canonical spelling');
  CheckField('<Game><ID>invalid</ID></Game>', 'ID', 2, False, 'LaunchBox GUID rejects malformed identifiers');
  CheckField('<game><custom><rating>custom scale</rating></custom></game>', 'custom/rating', 1, True, 'Custom nested fields keep free-form values');
  TFile.WriteAllText(TPlatformPath.Combine(Roms, 'A.rom'), 'A');
  TFile.WriteAllText(TPlatformPath.Combine(Roms, 'B.rom'), 'B');
  TFile.WriteAllText(TPlatformPath.Combine(Roms, 'C.rom'), 'C');
  TFile.WriteAllText(TPlatformPath.Combine(Roms, 'old.png'), 'old-media');
  Bitmap := TBitmap.Create(96, 64);
  try
    Bitmap.Clear($FF60CDFF);
    Bitmap.SaveToFile(TPlatformPath.Combine(Roms, 'replacement.png'))
  finally
    Bitmap.Free
  end;
  TFile.WriteAllText(ListFile, '<gameList><game id="42" custom="keep"><path>./A.rom</path>' +
    '<name>Alpha</name><desc><![CDATA[Original description]]></desc><favorite>true</favorite>' +
    '<image>./old.png</image><maps><map path="./map.png" title="Level 1"/></maps>' +
    '<customflag>preserved</customflag></game>' +
    '<game id="99"><path>./B.rom</path><name>Beta</name><hidden>true</hidden>' +
    '<custom><child value="untouched"/></custom></game><folder><path>./sub</path><name>Folder</name></folder></gameList>', TEncoding.UTF8);
  Sys := TJSONObject.Create;
  Config := TJSONObject.Create;
  Credentials := TJSONObject.Create;
  try
    JSet(Sys, 'SystemId', TJSONNumber.Create(1));
    JSet(Sys, 'Overriden', TJSONNumber.Create(31));
    JSet(Sys, 'GamesAndRoms.Path', TJSONString.Create(Roms));
    JSet(Sys, 'GamesAndRoms.FileExtensions', TJSONArray.Create.Add('rom'));
    JSet(Sys, 'GamesAndRoms.Platform', TJSONString.Create('Test platform'));
    JSet(Sys, 'GameList.Type', TJSONNumber.Create(1));
    JSet(Sys, 'GameList.OutputFile', TJSONString.Create(ListFile));
    JSet(Sys, 'GameList.Behavior', TJSONNumber.Create(0));
    JSet(Sys, 'GameList.Folders', TJSONNumber.Create(1));
    JSet(Sys, 'Miscellaneous.Method', TJSONNumber.Create(2));
    JSet(Sys, 'Medias', TJSONArray.Create);
    LibraryData := TGameLibrary.Create(Sys);
    Fields := TObjectList<TLibraryField>.Create(True);
    try
      Check(LibraryData.Games.Count = 3, 'Platform library merges existing records and unscraped ROMs without listing folders');
      N := GameIndex('A.rom');
      Other := LibraryData.Games[GameIndex('B.rom')].Node.XML;
      Draft := LibraryData.Draft(N);
      LibraryFields(Draft.DocumentElement, Fields);
      Found := False;
      for F in Fields do
      begin
        if F.Caption = 'desc' then
        begin
          Check(F.Value = 'Original description', 'CDATA description is editable');
          F.SetValue('Новое описание & details');
        end;
        if F.Caption = 'image' then
          F.SetValue(LibraryData.MediaReference(TPlatformPath.Combine(Roms, 'replacement.png')));
        if F.Caption = 'favorite' then
          F.SetValue('false');
        if F.Caption = 'maps/map/@title' then
          F.SetValue('New level');
        if F.Caption = 'video' then
          Found := F.IsMedia;
      end;
      Check(Found, 'Empty supported media fields are offered in the field editor');
      Before := TFile.ReadAllText(ListFile);
      Draft.DocumentElement.ChildNodes['rating'].Text := '2';
      Raised := False;
      try
        LibraryData.Save(N, Draft)
      except
        on E: EGameLibraryValidation do
          Raised := True
      end;
      Check(Raised and (TFile.ReadAllText(ListFile) = Before), 'Model validation prevents invalid data from reaching disk');
      Check(Length(TDirectory.GetFiles(Roms, 'gamelist.xml.*.bak')) = 0, 'Validation failure does not create a backup or partially save a game');
      Draft.DocumentElement.ChildNodes['rating'].Text := '';
      LibraryData.Save(N, Draft);
      Doc := LoadXMLDocument(ListFile);
      Check(Doc.DocumentElement.ChildNodes[0].ChildNodes['desc'].Text = 'Новое описание & details', 'Single-game edit persists Unicode and XML escaping');
      Check(Doc.DocumentElement.ChildNodes[0].ChildNodes['favorite'].Text = 'false', 'Editor can unset favorite');
      Check(Doc.DocumentElement.ChildNodes[0].ChildNodes['image'].Text = './replacement.png', 'Media replacement persists a relative reference');
      Check(TFile.ReadAllText(TPlatformPath.Combine(Roms, 'old.png')) = 'old-media', 'Replacement does not delete or overwrite the previous media file');
      Check(Doc.DocumentElement.ChildNodes[0].ChildNodes['maps'].ChildNodes['map'].Attributes['title'] = 'New level', 'Nested media attributes are editable');
      Check(Doc.DocumentElement.ChildNodes[1].XML = Other, 'Editing one game preserves every field of another game');
      Check((Doc.DocumentElement.ChildNodes.Count = 3) and
        (Doc.DocumentElement.ChildNodes[2].NodeName = 'folder'), 'Saving one game leaves unselected unscraped ROMs and folders untouched');
      Check(Length(TDirectory.GetFiles(Roms, 'gamelist.xml.*.bak')) = 1, 'Single-game save creates a backup');
      Before := TFile.ReadAllText(ListFile);
      TFile.WriteAllText(ListFile, Before.Replace('Beta', 'External update'), TEncoding.UTF8);
      Raised := False;
      try
        LibraryData.Save(N, Draft)
      except
        on E: Exception do
          Raised := True
      end;
      Check(Raised and TFile.ReadAllText(ListFile).Contains('External update'), 'Editor detects external library changes instead of overwriting them');
      TFile.WriteAllText(ListFile, Before, TEncoding.UTF8);
    finally
      Fields.Free;
      LibraryData.Free
    end;

    Raised := False;
    try
      Draft := ParseGameXML('<gameList/>', 1)
    except
      on E: Exception do
        Raised := True
    end;
    Check(Raised, 'XML editor rejects a full library in place of a game record');

    JSet(Config, 'AllSystems', Sys.Clone as TJSONValue);
    Systems := TJSONArray.Create;
    Systems.AddElement(Sys.Clone as TJSONValue);
    JSet(Config, 'Systems', Systems);
    JSet(Config, 'Anonymous', TJSONBool.Create(True));
    JSet(Config, 'FrontEnd.Type', TJSONNumber.Create(4));
    Response := TJSONObject.ParseJSONValue('{"response":{"jeu":{"id":42,"romid":7,"noms":[{"region":"us","text":"Scraped Alpha"}],"rom":{"romregions":"us"}}}}') as TJSONObject;
    try
      WriteJSON(TPlatformPath.Combine(Base, 'Cache/api/' + THashSHA2.GetHashString('jeuInfos.php?systemeid=1&romtype=jeu&romnom=A') + '.json'), Response);
    finally
      Response.Free
    end;
    Before := TFile.ReadAllText(ListFile);
    RunTarget('A.rom');
    Check((Status.Errors = 0) and (Status.Total = 1) and (Status.Completed = 1) and
      (Status.Found = 1) and (Status.Requests = 0), 'Single-game scraping processes exactly one selected ROM from offline cache');
    Doc := LoadXMLDocument(ListFile);
    Check(Doc.DocumentElement.ChildNodes[0].ChildNodes['name'].Text = 'Scraped Alpha', 'Targeted scraping updates the selected game');
    Check((Doc.DocumentElement.ChildNodes[1].XML = Other) and
      (Doc.DocumentElement.ChildNodes.Count = 3), 'Targeted scraping overrides destructive list behavior and preserves other games and folders');
    Check(Doc.DocumentElement.ChildNodes[0].ChildNodes['image'].Text = './replacement.png', 'Targeted scraping preserves media absent from the response');
    Check((JInt(Sys, 'GameList.Behavior') = 0) and (JInt(Sys, 'GameList.Folders') = 1), 'Targeted overrides do not modify stored settings');

    Before := TFile.ReadAllText(ListFile);
    RunTarget('A.rom', True);
    Check(Status.Cancelled and (TFile.ReadAllText(ListFile) = Before), 'Cancelled targeted scrape preserves the original library');
    Response := TJSONObject.ParseJSONValue('{"response":{}}') as TJSONObject;
    try
      WriteJSON(TPlatformPath.Combine(Base, 'Cache/api/' + THashSHA2.GetHashString('jeuInfos.php?systemeid=1&romtype=jeu&romnom=A') + '.json'), Response)
    finally
      Response.Free
    end;
    RunTarget('A.rom');
    Doc := LoadXMLDocument(ListFile);
    Check((Status.Missing = 1) and (Doc.DocumentElement.ChildNodes[0].ChildNodes['name'].Text = 'Scraped Alpha'), 'A not-found targeted result preserves the existing game');
    RunTarget('Missing.rom');
    Check((Status.Errors > 0) and (Status.Completed = 0), 'Targeted scrape refuses missing ROM files');

    TestAsyncImages;
    Main := TFormMain.Create(nil);
    Window := TFormGameLibrary.Create(nil);
    try
      Window.StyleBook := Main.StyleBookWinUI3;
      Window.FieldsScroll.ScrollAnimation := TBehaviorBoolean.False;
      Window.LoadPlatform(Sys, 'Test platform');
      // Rebuild lists and field owners repeatedly before delivering queued previews.
      for I := 1 to 5 do
      begin
        Window.SearchEdit.Text := 'B.rom';
        Window.GameList.ItemIndex := 0;
        Window.SearchEdit.Text := '';
        Window.GameList.ItemIndex := 0;
      end;
      WaitPreview(Window.FieldEditor('image'));
      Check(Window.GameTitleLabel.Text = 'Scraped Alpha',
        'Rapid game selection and filtering preserve the final game while previews load');
      Check((Window.GameTitleLabel.Text = 'Scraped Alpha') and
        (Window.PlatformLabel.Text = 'Test platform'), 'Concept layout displays the selected game and platform headers');
      Check(Window.FieldEditor('name').Index < Window.FieldEditor('@id').Index,
        'Primary game metadata precedes technical XML attributes');
      Check(Window.FieldsTabLine.Visible and not Window.XMLTabLine.Visible,
        'Field navigation marks the active tab correctly');
      Check((Window.FieldEditor('rating').InfoButton <> nil) and
        (Window.FieldEditor('rating').InfoIcon.Data.Count > 0), 'Constrained fields receive a Fluent information button');
      Check(not Window.FieldEditor('desc').InfoButton.Visible, 'Free-form description does not get irrelevant restrictions');
      Window.InfoClick(Window.FieldEditor('rating').InfoButton);
      Check(Window.FieldEditor('rating').HelpLabel.Visible and
        Window.FieldEditor('rating').HelpText.Contains('0.85'), 'Information button expands allowed values and an example');
      Window.InfoClick(Window.FieldEditor('rating').InfoButton);
      Check(not Window.FieldEditor('rating').HelpLabel.Visible, 'Information can be collapsed without changing the game');
      Before := TFile.ReadAllText(ListFile);
      Window.FieldEditor('rating').Text := '3';
      Check(Window.FieldEditor('rating').ErrorLabel.Visible and not Window.ValidateDraft,
        'Invalid field values are identified inline');
      Window.SaveClick(nil);
      Check((TFile.ReadAllText(ListFile) = Before) and not Window.SaveButton.Enabled,
        'Invalid form save preserves disk contents and the unsaved draft');
      Window.InfoClick(Window.FieldEditor('rating').InfoButton);
      Window.ClientWidth := 1280;
      Window.ClientHeight := 850;
      Window.ValidateDraft;
      Application.ProcessMessages;
      Check(Window.FieldEditor('rating').ValueEdit.AbsoluteRect.Left >
        Window.FieldEditor('rating').CaptionLabel.AbsoluteRect.Right,
        'Concept layout places input next to its label');
      Check((Window.FieldEditor('rating').HelpLabel.AbsoluteRect.Top >=
        Window.FieldEditor('rating').ValueEdit.AbsoluteRect.Bottom) and
        SameValue(Window.FieldEditor('rating').HelpLabel.AbsoluteRect.Left,
          Window.FieldEditor('rating').ValueEdit.AbsoluteRect.Left, 1),
        'Expanded help appears below the field input without narrowing it');
      Check(Window.FieldEditor('rating').InfoButton.Height <= 40,
        'Information button remains compact when help is expanded');
      Bitmap := TBitmap.Create(1280, 850);
      try
        if Bitmap.Canvas.BeginScene then
        try
          Window.PaintTo(Bitmap.Canvas)
        finally
          Bitmap.Canvas.EndScene
        end;
        Bitmap.SaveToFile(TPlatformPath.Combine(WritableBase, 'tests/library-validation.png'));
      finally
        Bitmap.Free
      end;
      Window.InfoClick(Window.FieldEditor('rating').InfoButton);
      Window.FieldEditor('rating').Text := '0.8';
      Check(not Window.FieldEditor('rating').ErrorLabel.Visible and Window.ValidateDraft,
        'Correcting a value clears its validation error');
      Window.SaveClick(nil);
      Before := TFile.ReadAllText(ListFile);
      Window.EditorTabs.ActiveTab := Window.XMLTab;
      Window.XMLMemo.Text := Window.XMLMemo.Text.Replace('<rating>0.8</rating>', '<rating>5</rating>');
      Window.XMLChanged(nil);
      Window.SaveClick(nil);
      Check((TFile.ReadAllText(ListFile) = Before) and Window.FieldEditor('rating').ErrorLabel.Visible,
        'XML editing cannot bypass field validation');
      Window.FieldEditor('rating').Text := '0.8';
      Window.SaveClick(nil);
      Check((Window.GameList.Count = 3) and (Window.FieldCount > 20), 'Game library form streams and exposes all fields from FMX');
      Window.SearchEdit.Text := 'B.rom';
      Window.SearchChanged(nil);
      Check(Window.GameList.Count = 1, 'Game library search finds a ROM filename');
      Window.GameList.ItemIndex := 0;
      Window.GameChanged(nil);
      Check(Window.XMLMemo.Text.Contains('Beta'), 'Game selection loads its own editable XML');
      Window.SearchEdit.Text := '';
      Window.SearchChanged(nil);
      Window.GameList.ItemIndex := 0;
      Window.GameChanged(nil);
      Window.FieldEditor('desc').Text := 'Edited through the form';
      Window.FieldEditor('developer').Text := 'Edited developer';
      Check(Window.SaveButton.Enabled, 'Editing a field marks the selected game dirty');
      Window.SaveClick(nil);
      Doc := LoadXMLDocument(ListFile);
      Check(Doc.DocumentElement.ChildNodes[0].ChildNodes['desc'].Text.Trim = 'Edited through the form', 'Form edit and save update the selected record');
      Check(Doc.DocumentElement.ChildNodes[0].ChildNodes['developer'].Text = 'Edited developer', 'Vertical editor saves changes to several fields together');
      Window.EditorTabs.ActiveTab := Window.XMLTab;
      Window.XMLMemo.Text := Window.XMLMemo.Text.Replace('<customflag>preserved</customflag>', '<customflag>XML edit</customflag>');
      Window.XMLChanged(nil);
      Window.SaveClick(nil);
      Doc := LoadXMLDocument(ListFile);
      Check(Doc.DocumentElement.ChildNodes[0].ChildNodes['customflag'].Text = 'XML edit', 'Advanced XML edits persist custom game fields');
      Window.EditorTabs.ActiveTab := Window.FieldsTab;
      // replacement.png was created before any asynchronous preview requests.
      Window.FieldEditor('image').Text := './replacement.png';
      Window.ValueChanged(Window.FieldEditor('image').ValueEdit);
      Check(Window.FieldEditor('image').PreviewLoading and Window.FieldEditor('image').MediaImage.Bitmap.IsEmpty,
        'Media preview starts asynchronously with cleared previous pixels');
      Window.FieldEditor('image').Text := './missing.png';
      Window.FieldEditor('image').Text := './replacement.png';
      WaitPreview(Window.FieldEditor('image'));
      Check(not Window.FieldEditor('image').MediaImage.Bitmap.IsEmpty and
        (Window.FieldEditor('image').MediaNote.Text = ''), 'Only the latest media path supplies the preview');
      Window.FieldEditor('image').Text := './missing.png';
      WaitPreview(Window.FieldEditor('image'));
      Check(Window.FieldEditor('image').MediaImage.Bitmap.IsEmpty and
        not Window.FieldEditor('image').MediaImage.Visible and
        (Window.FieldEditor('image').MediaNote.Text <> ''), 'Missing media clears the preview and shows an inline error');
      Window.FieldEditor('image').Text := './replacement.png';
      Window.FieldEditor('image').Text := '';
      Check(not Window.FieldEditor('image').PreviewLoading and Window.FieldEditor('image').MediaImage.Bitmap.IsEmpty,
        'Clearing media cancels its pending preview immediately');
      Window.FieldEditor('image').Text := './replacement.png';
      Window.FieldEditor('box').Text := './replacement.png';
      WaitPreview(Window.FieldEditor('image'));
      WaitPreview(Window.FieldEditor('box'));
      Check(not Window.FieldEditor('image').MediaImage.Bitmap.IsEmpty and
        Window.FieldEditor('image').ReplaceMediaButton.Enabled,
        'Media row shows the local image and enables replacement');
      Window.FieldEditor('box').Text := './missing.png';
      Window.SaveClick(nil);
      WaitUntil(
        function: Boolean
        begin
          Result := not TImage(Window.GameList.ListItems[0].FindComponent('GameCover')).Bitmap.IsEmpty;
        end, 'List cover falls back to another image when the preferred media is missing');
      Check(TImage(Window.GameList.ListItems[0].FindComponent('GameCover')).Bitmap.Width = 48,
        'List covers are decoded as bounded thumbnails');
      Window.FieldEditor('box').Text := './replacement.png';
      WaitPreview(Window.FieldEditor('box'));
      Window.SaveClick(nil);
      Doc := LoadXMLDocument(ListFile);
      Check(Doc.DocumentElement.ChildNodes[0].ChildNodes['image'].Text = './replacement.png', 'Media reference survives form editing without added line breaks');
      Window.ClientWidth := 1120;
      Window.ClientHeight := 740;
      Application.ProcessMessages;
      Report.Add(Format('Editor geometry: content %.0fx%.0f, scroll %.0fx%.0f',
          [Window.FieldsContent.Width, Window.FieldsContent.Height, Window.FieldsScroll.Width, Window.FieldsScroll.Height]));
      Check(Window.FieldsContent.Width > 500, 'Vertical editor uses the full available field width');
      Check((Window.SaveButton.AbsoluteRect.Right < Window.ScrapeButton.AbsoluteRect.Left) and
        (Window.ScrapeButton.AbsoluteRect.Right < Window.CloseButton.AbsoluteRect.Left),
        'Footer actions follow the concept order');
      Check(Window.FieldEditor('rating').ValueEdit.Width > 250,
        'Field input remains usable at the minimum window width');
      Check(Window.FieldsContent.Height > Window.FieldsScroll.Height, 'All field editors are accessible through vertical scrolling');
      Check(Window.FieldEditor('desc').AbsoluteRect.Bottom < Window.FieldEditor('developer').AbsoluteRect.Top,
        'Description and developer rows do not overlap');
      Window.FieldsScroll.ViewportPosition := PointF(0,
        Window.FieldsContent.Height - Window.FieldsScroll.ViewportRect.Height);
      Application.ProcessMessages;
      Check(Window.FieldEditor('md5').AbsoluteRect.Bottom <= Window.FieldsScroll.AbsoluteRect.Bottom + 1,
        'Vertical scrolling reaches the last editable field');
      Started := Round(Window.FieldsScroll.ViewportPosition.Y);
      Window.FieldEditor('md5').Text := '25f9e794323b453885f5181f1b624d0b';
      Check(Abs(Window.FieldsScroll.ViewportPosition.Y - Started) < 1,
        'Editing a field preserves the current scroll position');
      Window.SaveClick(nil);
      Window.FieldsScroll.ViewportPosition := PointF(0, 0);
      Window.ClientWidth := 1280;
      Window.ClientHeight := 850;
      Application.ProcessMessages;
      Bitmap := TBitmap.Create(1280, 850);
      try
        if Bitmap.Canvas.BeginScene then
        try
          Window.PaintTo(Bitmap.Canvas)
        finally
          Bitmap.Canvas.EndScene
        end;
        Bitmap.SaveToFile(TPlatformPath.Combine(WritableBase, 'tests/library-editor.png'));
      finally
        Bitmap.Free
      end;
      // Exercise the library button through the same asynchronous worker contract as main.
      Window.OnCreateScrapeWorker :=
        function(Rom: string): TScrapeWorker
        begin
          Result := TScrapeWorker.Create(Config, Credentials, Base, 0, True, 1, Rom);
        end;
      Response := TJSONObject.ParseJSONValue('{"response":{"jeu":{"id":42,"romid":7,"noms":[{"region":"us","text":"Inline Alpha"}],"rom":{"romregions":"us"}}}}') as TJSONObject;
      try
        WriteJSON(TPlatformPath.Combine(Base, 'Cache/api/' + THashSHA2.GetHashString('jeuInfos.php?systemeid=1&romtype=jeu&romnom=A') + '.json'), Response);
      finally
        Response.Free;
      end;
      Doc := LoadXMLDocument(ListFile);
      Other := Doc.DocumentElement.ChildNodes[1].XML;
      SelectedCard := Window.GameList.ListItems[0];
      OtherCard := Window.GameList.ListItems[1];
      Window.ModalResult := mrNone;
      Window.ScrapeClick(nil);
      Check((Window.ModalResult = mrNone) and Window.ScrapeProgressLayout.Visible and
        Window.ScrapeActivity.Enabled and not Window.ScrapeButton.Enabled and
        not Window.GamesPanel.Enabled and not Window.EditorTabs.Enabled,
        'Library scrape stays in the editor and shows progress while preventing concurrent edits');
      Window.ScrapeClick(nil);
      WaitUntil(
        function: Boolean
        begin
          Window.ScrapeTimerTimer(nil);
          Result := not Window.ScrapeTimer.Enabled;
        end, 'Inline library scrape completes');
      Check((Window.GameTitleLabel.Text = 'Inline Alpha') and
        (Window.FieldEditor('name').Text = 'Inline Alpha') and
        Window.XMLMemo.Text.Contains('Inline Alpha') and
        (Window.GameList.Selected.Tag = 0),
        'Inline scrape refreshes selected game fields, XML, title and list');
      Check((Window.GameList.ListItems[0] = SelectedCard) and
        (Window.GameList.ListItems[1] = OtherCard) and
        (TLabel(SelectedCard.FindComponent('GameName')).Text = 'Inline Alpha'),
        'Scraping updates the selected card without recreating any list rows');
      Check(Window.ScrapeButton.Enabled and Window.EditorTabs.Enabled and
        Window.GamesPanel.Enabled and not Window.ScrapeProgressLayout.Visible and
        not Window.ScrapeActivity.Enabled and (Window.ModalResult = mrNone),
        'Inline scrape restores the editor without closing the library');
      Doc := LoadXMLDocument(ListFile);
      Check(Doc.DocumentElement.ChildNodes[1].XML = Other,
        'Inline scrape preserves other library games');
      Window.FieldEditor('name').Text := 'Edited after inline scrape';
      Window.SaveClick(nil);
      Doc := LoadXMLDocument(ListFile);
      Check(Doc.DocumentElement.ChildNodes[0].ChildNodes['name'].Text = 'Edited after inline scrape',
        'Library revision is refreshed so edits can be saved after scraping');
      Check((Window.GameList.ListItems[0] = SelectedCard) and
        (Window.GameList.ListItems[1] = OtherCard) and
        (TLabel(SelectedCard.FindComponent('GameName')).Text = 'Edited after inline scrape'),
        'Saving updates only the selected card and preserves other row objects');
      Response := TJSONObject.ParseJSONValue('{"response":{}}') as TJSONObject;
      try
        WriteJSON(TPlatformPath.Combine(Base, 'Cache/api/' + THashSHA2.GetHashString('jeuInfos.php?systemeid=1&romtype=jeu&romnom=A') + '.json'), Response);
      finally
        Response.Free;
      end;
      Before := TFile.ReadAllText(ListFile);
      Window.ScrapeClick(nil);
      WaitUntil(
        function: Boolean
        begin
          Window.ScrapeTimerTimer(nil);
          Result := not Window.ScrapeTimer.Enabled;
        end, 'Inline not-found scrape completes');
      Doc := LoadXMLDocument(ListFile);
      Check((Window.FieldEditor('name').Text = 'Edited after inline scrape') and
        (Doc.DocumentElement.ChildNodes[0].ChildNodes['name'].Text = 'Edited after inline scrape') and
        (Doc.DocumentElement.ChildNodes[1].XML = Other) and Window.ScrapeButton.Enabled,
        'Inline not-found result preserves fields and restores controls');
      Window.FieldEditor('name').Text := 'Edited after not-found scrape';
      Window.SaveClick(nil);
      Doc := LoadXMLDocument(ListFile);
      Check(Doc.DocumentElement.ChildNodes[0].ChildNodes['name'].Text = 'Edited after not-found scrape',
        'Edits can be saved after a not-found scrape');
      Before := TFile.ReadAllText(ListFile);
      Window.OnCreateScrapeWorker :=
        function(Rom: string): TScrapeWorker
        begin
          Result := TScrapeWorker.Create(Config, Credentials, Base, 0, True, 1, Rom);
          Result.Terminate;
        end;
      Window.ScrapeClick(nil);
      Found := True;
      Window.FormCloseQuery(nil, Found);
      Check(not Found, 'Closing during a scrape waits for worker cancellation');
      WaitUntil(
        function: Boolean
        begin
          Window.ScrapeTimerTimer(nil);
          Result := not Window.ScrapeTimer.Enabled;
        end, 'Inline cancelled scrape completes');
      Check((TFile.ReadAllText(ListFile) = Before) and Window.CloseButton.Enabled and
        Window.ScrapeButton.Enabled and (Window.ModalResult = mrNone),
        'Cancelled inline scrape preserves the library and restores actions');
      // A larger list must only request visible previews, including after scrolling.
      LazyConfig := Sys.Clone as TJSONObject;
      LazyWindow := nil;
      try
        Path := TPlatformPath.Combine(Roms, 'lazy-library.xml');
        Doc := TXMLDocument.Create(nil);
        Doc.Active := True;
        Doc.AddChild('gameList');
        for I := 0 to 199 do
        begin
          with Doc.DocumentElement.AddChild('game') do
          begin
            AddChild('path').Text := './lazy-' + I.ToString + '.rom';
            AddChild('name').Text := 'Lazy game ' + I.ToString;
            AddChild('image').Text := './replacement.png';
          end;
        end;
        Doc.SaveToFile(Path);
        JSet(LazyConfig, 'GameList.OutputFile', TJSONString.Create(Path));
        LazyWindow := TFormGameLibrary.Create(nil);
        LazyWindow.StyleBook := Main.StyleBookWinUI3;
        LazyWindow.GameList.ScrollAnimation := TBehaviorBoolean.False;
        Started := TThread.GetTickCount64;
        LazyWindow.LoadPlatform(LazyConfig, 'Lazy previews');
        Report.Add(Format('200-game library load: %d ms', [TThread.GetTickCount64 - Started]));
        N := 0;
        for I := 0 to LazyWindow.GameList.Count - 1 do
          if TImage(LazyWindow.GameList.ListItems[I].FindComponent('GameCover')).Tag <> 0 then
            Inc(N);
        Check((N > 0) and (N < 15) and
          (TImage(LazyWindow.GameList.ListItems[100].FindComponent('GameCover')).Tag = 0),
          'Opening a large library requests only visible previews and adjacent rows');
        LazyWindow.GameList.ApplyStyleLookup;
        LazyWindow.GameList.RealignContent;
        LazyWindow.GameList.ViewportPosition := PointF(0, 86 * 40);
        WaitUntil(
          function: Boolean
          begin
            Result := not TImage(LazyWindow.GameList.ListItems[40].FindComponent('GameCover')).Bitmap.IsEmpty;
          end, 'Scrolling loads previews for newly visible games');
        Check(TImage(LazyWindow.GameList.ListItems[100].FindComponent('GameCover')).Tag = 0,
          'Scrolling does not queue previews for distant rows');
        SelectedCard := LazyWindow.GameList.ListItems[40];
        OtherCard := LazyWindow.GameList.ListItems[41];
        LazyWindow.GameList.ItemIndex := 40;
        ScrollBefore := LazyWindow.GameList.ViewportPosition;
        LazyWindow.FieldEditor('name').Text := 'Renamed visible game';
        LazyWindow.SaveClick(nil);
        Check((LazyWindow.GameList.ListItems[40] = SelectedCard) and
          (LazyWindow.GameList.ListItems[41] = OtherCard) and
          (Abs(LazyWindow.GameList.ViewportPosition.Y - ScrollBefore.Y) < 1) and
          (TLabel(SelectedCard.FindComponent('GameName')).Text = 'Renamed visible game') and
          (TLabel(OtherCard.FindComponent('GameName')).Text = 'Lazy game 41'),
          'Saving a scrolled game preserves scroll position and all list cards');
        LazyWindow.GameList.ViewportPosition := PointF(0, 0);
        WaitUntil(
          function: Boolean
          begin
            Result := not TImage(LazyWindow.GameList.ListItems[0].FindComponent('GameCover')).Bitmap.IsEmpty;
          end, 'Returning to the start retains or reloads its previews');
      finally
        LazyWindow.Free;
        LazyConfig.Free;
      end;
      Window.ValueChanged(Window.FieldEditor('image').ValueEdit);
      Check(Window.FieldEditor('image').PreviewLoading, 'Window destruction is exercised with a pending preview');
    finally
      Window.Free;
      Main.Free
    end;
    Application.ProcessMessages;

    // The same editor retains format-specific and unknown fields in LaunchBox and DAT.
    for I in [2, 3] do
    begin
      Path := TPlatformPath.Combine(Roms, 'format-' + I.ToString + '.xml');
      JSet(Sys, 'GameList.Type', TJSONNumber.Create(I));
      JSet(Sys, 'GameList.OutputFile', TJSONString.Create(Path));
      if I = 2 then
        TFile.WriteAllText(Path, '<LaunchBox><Game><ApplicationPath>' + TPlatformPath.Combine(Roms, 'A.rom') +
          '</ApplicationPath><Title>LB</Title><Custom>untouched</Custom></Game>' +
          '<AdditionalApplication><Name>Helper</Name></AdditionalApplication></LaunchBox>', TEncoding.UTF8)
      else
        TFile.WriteAllText(Path, '<datafile><header><author>Custom author</author></header>' +
          '<game name="DAT"><rom name="./A.rom" crc="abcdef12"/><custom>untouched</custom></game></datafile>', TEncoding.UTF8);
      LibraryData := TGameLibrary.Create(Sys);
      try
        N := GameIndex('A.rom');
        Draft := LibraryData.Draft(N);
        if I = 2 then
          Draft.DocumentElement.ChildNodes['Title'].Text := 'Edited LB'
        else
          Draft.DocumentElement.Attributes['name'] := 'Edited DAT';
        LibraryData.Save(N, Draft);
        LibraryData.ReloadGame(N);
        Check(LibraryData.Title(N) = IfThen(I = 2, 'Edited LB', 'Edited DAT'),
          'Refreshing one game supports library format ' + I.ToString);
        Doc := LoadXMLDocument(Path);
        if I = 2 then
          Check(Doc.DocumentElement.ChildNodes[1].ChildNodes['Name'].Text = 'Helper', 'LaunchBox edit preserves additional applications')
        else
          Check(Doc.DocumentElement.ChildNodes[0].ChildNodes['author'].Text = 'Custom author', 'DAT edit preserves the existing header');
      finally
        LibraryData.Free
      end;
    end;

    Path := TPlatformPath.Combine(Roms, 'gamelist.zip');
    Zip := TZipFile.Create;
    try
      Zip.Open(Path, zmWrite);
      Zip.Add(TEncoding.UTF8.GetBytes(Before), 'gamelist.xml')
    finally
      Zip.Free
    end;
    JSet(Sys, 'GameList.Type', TJSONNumber.Create(1));
    JSet(Sys, 'GameList.OutputFile', TJSONString.Create(Path));
    LibraryData := TGameLibrary.Create(Sys);
    try
      N := GameIndex('A.rom');
      Draft := LibraryData.Draft(N);
      Draft.DocumentElement.ChildNodes['name'].Text := 'Edited ZIP';
      LibraryData.Save(N, Draft);
      Zip := TZipFile.Create;
      try
        Zip.Open(Path, zmRead);
        Zip.Read('gamelist.xml', Bytes)
      finally
        Zip.Free
      end;
      Check(TEncoding.UTF8.GetString(Bytes).Contains('Edited ZIP'), 'Compressed gamelist supports a single-game edit');
      LibraryData.ReloadGame(N);
      Check(LibraryData.Title(N) = 'Edited ZIP', 'Refreshing one game supports compressed gamelists');
    finally
      LibraryData.Free
    end;
  finally
    Credentials.Free;
    Config.Free;
    Sys.Free
  end;
end;

procedure RunGameLibrarySelfTests;
var
  Report: TStringList;
begin
  Report := TStringList.Create;
  try
    try
      RunGameLibraryTests(Report);
      Report.Add('ALL LIBRARY TESTS PASSED');
    except
      on E: Exception do
      begin
        Report.Add(E.ClassName + ': ' + E.Message);
        ExitCode := 1
      end;
    end;
    Report.SaveToFile(TPlatformPath.Combine(WritableBase, 'tests/library-results.txt'), TEncoding.UTF8);
  finally
    Report.Free
  end;
end;

end.

