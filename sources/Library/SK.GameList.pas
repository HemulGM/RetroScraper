unit SK.GameList;

interface

uses
  System.SysUtils, System.Classes, System.JSON, System.Generics.Collections,
  Xml.XMLIntf, SK.Scenarios;

type
  TGameListWriter = class
  private
    FScenario: TScenarioRequest;
    FDoc: IXMLDocument;
    FRoot: IXMLNode;
    FFile, FRomRoot, FPlatform: string;
    FKind, FBehavior, FSystemID: Integer;
    FOptimize, FPreserveMissingMedia, FPreserveHeader, FOnlyNew: Boolean;
    FFolderMode: Integer;
    FFolderSources: TObjectDictionary<string, TStringList>;
    FIndex: TDictionary<string, IXMLNode>;
    procedure AddScenarioField(Item: TJSONObject);
    function NodeKey(Node: IXMLNode): string;
    function NormalizeKey(const Value: string): string;
  public
    constructor Create(Config: TJSONObject);
    destructor Destroy; override;
    function ContainsGame(const FileName: string): Boolean;
    function NeedsScenarioUpdate(const FileName: string): Boolean;
    procedure Add(Item: TJSONObject);
    procedure Save(Cancel: TFunc<Boolean> = nil);
    function PrepareFolders(Cancel: TFunc<Boolean> = nil): TArray<string>;
    property Document: IXMLDocument read FDoc;
  end;

implementation

uses
  SK.Xml, System.IOUtils, System.StrUtils, System.RegularExpressions,
  System.DateUtils, System.Zip, System.NetEncoding, System.Hash, Xml.XMLDoc, System.Variants,
  SK.Artwork.Folders, SK.Consts, SK.Input, SK.Json, SK.Storage, SK.Platform,
  SK.Output;

constructor TGameListWriter.Create(Config: TJSONObject);
var
  I: Integer;
  K: string;
  Bytes: TBytes;
  Zip: TZipFile;
begin
  inherited Create;
  FScenario := TScenarioRequest.FromConfig(Config);
  FIndex := TDictionary<string, IXMLNode>.Create;
  FFolderSources := TObjectDictionary<string, TStringList>.Create([doOwnsValues]);
  FSystemID := JInt(Config, 'SystemId');
  FFolderMode := JInt(Config, 'GameList.Folders');
  FRomRoot := JStr(Config, 'GamesAndRoms.Path');
  FPlatform := JStr(Config, 'GamesAndRoms.Platform', TPath.GetFileName(FRomRoot));
  FKind := JInt(Config, 'GameList.Type', 1);
  FBehavior := JInt(Config, 'GameList.Behavior');
  FPreserveHeader := JBool(Config, 'GameList.PreserveHeader');
  FOnlyNew := JBool(Config, 'GameList.OnlyNew');
  if FScenario.Active then
  begin
    FBehavior := 2;
    FPreserveHeader := True;
    FOnlyNew := False;
    FFolderMode := 0;
  end;
  if FOnlyNew then
  begin
    // An incremental run must merge even when replacement is configured.
    FBehavior := 2;
    FPreserveHeader := True;
  end;
  FOptimize := JBool(Config, 'GameList.Optimize');
  FPreserveMissingMedia := JBool(Config, 'GameList.PreserveMissingMedia');
  FFile := ResolveOutput(JStr(Config, 'GameList.OutputFile', 'gamelist.xml'), FRomRoot, FRomRoot);
  FDoc := TXMLDocument.Create(nil);
  FDoc.Active := True;
  FDoc.Encoding := 'utf-8';
  if (FBehavior in [2, 3]) and TFile.Exists(FFile) then
    if FFile.EndsWith('.zip', True) then
    begin
      Zip := TZipFile.Create;
      try
        Zip.Open(FFile, zmRead);
        if Zip.FileCount > 0 then
        begin
          Zip.Read(0, Bytes);
          FDoc.LoadFromXML(TEncoding.UTF8.GetString(Bytes));
        end;
      finally
        Zip.Free;
      end;
    end
    else
      FDoc.LoadFromFile(FFile);
  FRoot := FDoc.DocumentElement;
  case FKind of
    2:
      K := 'LaunchBox';
    3:
      K := 'datafile';
  else
    K := 'gameList';
  end;
  if FRoot = nil then
    FRoot := FDoc.AddChild(K)
  else if FRoot.NodeName <> K then
    raise Exception.Create('Existing gamelist format does not match selected format.');
  for I := 0 to FRoot.ChildNodes.Count - 1 do
  begin
    K := NodeKey(FRoot.ChildNodes[I]);
    if K <> '' then
      FIndex.AddOrSetValue(NormalizeKey(K), FRoot.ChildNodes[I]);
  end;
end;

destructor TGameListWriter.Destroy;
begin
  FFolderSources.Free;
  FIndex.Free;
  inherited;
end;

function TGameListWriter.NormalizeKey(const Value: string): string;
begin
  Result := NativePath(Value);
  if Result = '' then
    Exit;
  if not TPath.IsPathRooted(Result) then
    Result := TPlatformPath.Combine(FRomRoot, Result);
  Result := PathKey(Result);
end;

function TGameListWriter.NodeKey(Node: IXMLNode): string;
var
  R: IXMLNode;
begin
  case FKind of
    2:
      if Node.NodeName = 'Game' then
        Result := XmlChildText(Node, 'ApplicationPath')
      else
        Result := '';
    3:
      begin
        R := Node.ChildNodes.FindNode('rom');
        if (R <> nil) and R.HasAttribute('name') then
          Result := R.Attributes['name']
        else
          Result := '';
      end;
  else
    Result := XmlChildText(Node, 'path');
  end;
end;

function TGameListWriter.ContainsGame(const FileName: string): Boolean;
var
  Node: IXMLNode;
begin
  Result := FIndex.TryGetValue(NormalizeKey(FileName), Node);
  if Result then
    if FKind = 2 then
      Result := Node.NodeName = 'Game'
    else
      Result := Node.NodeName = 'game';
end;

function TGameListWriter.NeedsScenarioUpdate(const FileName: string): Boolean;
var
  Node, FieldNode: IXMLNode;
  FieldName, Value: string;
  I: Integer;

  function HasFile(const Path: string): Boolean;
  var
    FullName: string;
  begin
    FullName := NativePath(Path);
    if FullName.Trim = '' then
      Exit(False);
    if not TPath.IsPathRooted(FullName) then
      FullName := TPlatformPath.Combine(FRomRoot, FullName);
    Result := TFile.Exists(FullName) and (TFile.GetSize(FullName) > 0);
  end;

begin
  Result := True;
  if not FScenario.Active or (FScenario.Mode = scmForce) then
    Exit;
  if not FIndex.TryGetValue(NormalizeKey(FileName), Node) then
    Exit;
  FieldName := ScenarioXmlField(FScenario.Field, FKind);
  if FieldName = '@name' then
    Exit(not Node.HasAttribute('name') or (VarToStr(Node.Attributes['name']).Trim = ''));
  FieldNode := Node.ChildNodes.FindNode(FieldName);
  if FieldNode = nil then
    Exit;
  if FScenario.Field = 'maps' then
  begin
    if FieldNode.ChildNodes.Count = 0 then
      Exit;
    for I := 0 to FieldNode.ChildNodes.Count - 1 do
      if not HasFile(VarToStr(FieldNode.ChildNodes[I].Attributes['path'])) then
        Exit;
    Exit(False);
  end;
  Value := FieldNode.Text.Trim;
  if ScenarioMediaField(FScenario.Field) then
    Result := not HasFile(Value)
  else
    Result := Value = '';
end;

procedure TGameListWriter.AddScenarioField(Item: TJSONObject);
var
  Node, FieldNode, MapNode, RomNode: IXMLNode;
  Key, FieldName, SourceField, Value: string;
  Maps, Map: TJSONValue;
begin
  if not NeedsScenarioUpdate(JStr(Item, 'path')) then
    Exit;
  SourceField := FScenario.Field;
  if SourceField = 'hash' then
    SourceField := 'crc';
  Maps := JValue(Item, SourceField);
  if Maps = nil then
    Exit;
  Value := Maps.Value;
  if FScenario.Field = 'maps' then
  begin
    if not (Maps is TJSONArray) or (TJSONArray(Maps).Count = 0) then
      Exit;
  end
  else if Value.Trim = '' then
    Exit; // An unavailable response must never erase an existing value.
  Key := JStr(Item, 'path');
  if not FIndex.TryGetValue(NormalizeKey(Key), Node) then
  begin
    if FKind = 2 then
    begin
      Node := FRoot.AddChild('Game');
      SetXmlChildText(Node, 'ApplicationPath', Key);
      SetXmlChildText(Node, 'ID', TGUID.NewGuid.ToString.Trim(['{', '}']));
    end
    else
    begin
      Node := FRoot.AddChild('game');
      Key := './' + ExtractRelativePath(IncludeTrailingPathDelimiter(FRomRoot), Key).Replace('\', '/');
      if FKind = 3 then
      begin
        RomNode := Node.AddChild('rom');
        RomNode.Attributes['name'] := Key;
      end
      else
        SetXmlChildText(Node, 'path', Key);
    end;
    FIndex.Add(NormalizeKey(JStr(Item, 'path')), Node);
  end;
  FieldName := ScenarioXmlField(FScenario.Field, FKind);
  if FieldName = '@name' then
  begin
    Node.Attributes['name'] := Value;
    Exit;
  end;
  if FScenario.Field = 'maps' then
  begin
    FieldNode := Node.ChildNodes.FindNode(FieldName);
    if FieldNode = nil then
      FieldNode := Node.AddChild(FieldName);
    FieldNode.ChildNodes.Clear;
    for Map in TJSONArray(Maps) do
    begin
      MapNode := FieldNode.AddChild('map');
      Value := JStr(Map, 'path');
      if TPath.IsPathRooted(Value) then
        Value := './' + ExtractRelativePath(IncludeTrailingPathDelimiter(FRomRoot), Value).Replace('\', '/');
      MapNode.Attributes['path'] := Value;
      MapNode.Attributes['title'] := JStr(Map, 'title');
    end;
    Exit;
  end;
  if (FKind = 1) and ScenarioMediaField(FScenario.Field) and TPath.IsPathRooted(Value) then
    Value := './' + ExtractRelativePath(IncludeTrailingPathDelimiter(FRomRoot), Value).Replace('\', '/');
  if FScenario.Field = 'releasedate' then
    if FKind = 3 then
      Value := Copy(Value, 1, 4)
    else if (FKind = 2) and (Length(Value) >= 8) then
      Value := Copy(Value, 1, 4) + '-' + Copy(Value, 5, 2) + '-' + Copy(Value, 7, 2) + 'T00:00:00';
  if (FKind = 2) and (FScenario.Field = 'rating') then
    Value := FloatToStr(StrToFloatDef(Value, 0, TFormatSettings.Invariant) * 5, TFormatSettings.Invariant);
  SetXmlChildText(Node, FieldName, Value);
end;

procedure TGameListWriter.Add(Item: TJSONObject);
var
  Node, R, MapNode, Additional: IXMLNode;
  Map: TJSONValue;
  Key, Field, Value: string;
  Pair: TJSONPair;
  Dir, Image: string;
  Images: TStringList;
  NodeIndex: Integer;
  OldFavorite, OldHidden, HasAdditional: Boolean;
begin
  if FKind = 0 then
    Exit;
  if FScenario.Active then
  begin
    AddScenarioField(Item);
    Exit;
  end;
  if FOnlyNew and ContainsGame(JStr(Item, 'path')) then
    Exit;
  Key := JStr(Item, 'path');
  if FKind <> 2 then
    Key := './' + ExtractRelativePath(IncludeTrailingPathDelimiter(FRomRoot), Key).Replace('\', '/');
  if JBool(Item, 'exclude') then
    Exit;
  if (FKind = 1) and (FFolderMode > 0) then
  begin
    Dir := ExtractFileDir(JStr(Item, 'path'));
    Image := JStr(Item, 'image', JStr(Item, 'thumbnail', JStr(Item, 'box')));
    if (Image <> '') and not TPath.IsPathRooted(Image) then
      Image := TPath.GetFullPath(TPlatformPath.Combine(FRomRoot, NativePath(Image)));
    while not SamePath(Dir, FRomRoot) and IsPathWithin(Dir, FRomRoot) do
    begin
      if not FFolderSources.TryGetValue(Dir, Images) then
      begin
        Images := TStringList.Create;
        FFolderSources.Add(Dir, Images);
      end;
      if (Image <> '') and (Images.IndexOf(Image) < 0) then
        Images.Add(Image);
      Dir := ExtractFileDir(Dir);
    end;
  end;
  if not FIndex.TryGetValue(NormalizeKey(Key), Node) then
  begin
    if FKind = 2 then
      Node := FRoot.AddChild('Game')
    else
      Node := FRoot.AddChild('game');
    FIndex.Add(NormalizeKey(Key), Node);
  end;
  OldFavorite := SameText(XmlChildText(Node, 'favorite'), 'true') or SameText(XmlChildText(Node, 'Favorite'), 'true');
  OldHidden := SameText(XmlChildText(Node, 'hidden'), 'true') or SameText(XmlChildText(Node, 'Hide'), 'true');
  if FKind = 1 then
    for Field in ['image', 'thumbnail', 'box', 'logo', 'marquee', 'video', 'manual', 'maps', 'map', 'tips', 'p2k'] do
    begin
      R := Node.ChildNodes.FindNode(Field);
      if (R <> nil) and (not FPreserveMissingMedia or (JValue(Item, Field) <> nil)) then
        Node.ChildNodes.Remove(R);
    end;
  if FKind = 3 then
  begin
    Node.Attributes['name'] := JStr(Item, 'name');
    SetXmlChildText(Node, 'description', JStr(Item, 'desc'));
    SetXmlChildText(Node, 'manufacturer', JStr(Item, 'publisher'));
    SetXmlChildText(Node, 'year', Copy(JStr(Item, 'releasedate'), 1, 4));
    R := Node.ChildNodes.FindNode('rom');
    if R = nil then
      R := Node.AddChild('rom');
    R.Attributes['name'] := Key;
    R.Attributes['size'] := JStr(Item, 'size', '0');
    for Field in ['crc', 'md5', 'sha1'] do
      if JStr(Item, Field) <> '' then
        R.Attributes[Field] := JStr(Item, Field).ToLower;
    Exit;
  end;
  if FKind = 2 then
  begin
    SetXmlChildText(Node, 'ApplicationPath', Key);
    SetXmlChildText(Node, 'Title', JStr(Item, 'name'));
    SetXmlChildText(Node, 'Notes', JStr(Item, 'desc'));
    SetXmlChildText(Node, 'Developer', JStr(Item, 'developer'));
    SetXmlChildText(Node, 'Publisher', JStr(Item, 'publisher'));
    SetXmlChildText(Node, 'Genre', JStr(Item, 'genre'));
    SetXmlChildText(Node, 'Favorite', LowerCase(BoolToStr(OldFavorite or JBool(Item, 'favorite'), True)));
    SetXmlChildText(Node, 'Hide', LowerCase(BoolToStr(OldHidden or JBool(Item, 'hidden'), True)));
    SetXmlChildText(Node, 'Platform', FPlatform);
    SetXmlChildText(Node, 'Region', JStr(Item, 'region'));
    if not FPreserveMissingMedia or (JValue(Item, 'video') <> nil) then
      SetXmlChildText(Node, 'VideoPath', JStr(Item, 'video'));
    if not FPreserveMissingMedia or (JValue(Item, 'manual') <> nil) then
      SetXmlChildText(Node, 'ManualPath', JStr(Item, 'manual'));
    if XmlChildText(Node, 'ID') = '' then
      SetXmlChildText(Node, 'ID', TGUID.NewGuid.ToString.Trim(['{', '}']));
    if XmlChildText(Node, 'DateAdded') = '' then
      SetXmlChildText(Node, 'DateAdded', DateToISO8601(Now, False));
    SetXmlChildText(Node, 'DateModified', DateToISO8601(Now, False));
    SetXmlChildText(Node, 'Source', 'ScreenScraper.fr');
    SetXmlChildText(Node, 'UseDosBox', LowerCase(BoolToStr(FSystemID = SystemIDDOS, True)));
    SetXmlChildText(Node, 'UseScummVM', LowerCase(BoolToStr(FSystemID = SystemIDScummVM, True)));
    HasAdditional := False;
    for NodeIndex := 0 to FRoot.ChildNodes.Count - 1 do
    begin
      Additional := FRoot.ChildNodes[NodeIndex];
      if (Additional.NodeName = 'AdditionalApplication') and (XmlChildText(Additional, 'GameID') = XmlChildText(Node, 'ID')) and
        SamePath(XmlChildText(Additional, 'ApplicationPath'), Key) then
      begin
        HasAdditional := True;
        Break
      end;
    end;
    if not HasAdditional then
    begin
      Additional := FRoot.AddChild('AdditionalApplication');
      SetXmlChildText(Additional, 'ApplicationPath', Key);
      SetXmlChildText(Additional, 'GameID', XmlChildText(Node, 'ID'));
      SetXmlChildText(Additional, 'Id', TGUID.NewGuid.ToString.Trim(['{', '}']));
      SetXmlChildText(Additional, 'Name', JStr(Item, 'name'));
      SetXmlChildText(Additional, 'UseDosBox', LowerCase(BoolToStr(FSystemID = SystemIDDOS, True)));
      for Field in ['AutoRunAfter', 'AutoRunBefore', 'UseEmulator', 'WaitForExit', 'SideA', 'SideB'] do
        SetXmlChildText(Additional, Field, 'false');
      SetXmlChildText(Additional, 'PlayCount', '0');
      SetXmlChildText(Additional, 'Priority', '0');
    end;
    SetXmlChildText(Node, 'StarRatingFloat', FloatToStr(StrToFloatDef(JStr(Item, 'rating'), 0, TFormatSettings.Invariant) * 5, TFormatSettings.Invariant));
    Value := JStr(Item, 'releasedate');
    if Length(Value) >= 8 then
      SetXmlChildText(Node, 'ReleaseDate', Copy(Value, 1, 4) + '-' + Copy(Value, 5, 2) + '-' + Copy(Value, 7, 2) + 'T00:00:00');
    Exit;
  end;
  for Pair in Item do
  begin
    Field := Pair.JsonString.Value;
    if (Field = 'maps') and (Pair.JsonValue is TJSONArray) then
    begin
      R := Node.ChildNodes.FindNode('maps');
      if R = nil then
        R := Node.AddChild('maps');
      R.ChildNodes.Clear;
      for Map in TJSONArray(Pair.JsonValue) do
      begin
        MapNode := R.AddChild('map');
        Value := JStr(Map, 'path');
        if TPath.IsPathRooted(Value) then
          Value := './' + ExtractRelativePath(IncludeTrailingPathDelimiter(FRomRoot), Value).Replace('\', '/');
        MapNode.Attributes['path'] := Value;
        MapNode.Attributes['title'] := JStr(Map, 'title');
      end;
      Continue;
    end;
    Value := Pair.JsonValue.Value;
    if Field = 'favorite' then
      Value := LowerCase(BoolToStr(OldFavorite or JBool(Item, Field), True));
    if Field = 'hidden' then
      Value := LowerCase(BoolToStr(OldHidden or JBool(Item, Field), True));
    if MatchText(Field, ['exclude', 'filename', 'size', 'crc', 'md5', 'sha1', 'id']) then
      Continue;
    if Field = 'path' then
      Value := Key
    else if MatchText(Field, ['image', 'thumbnail', 'marquee', 'box', 'logo', 'video', 'manual', 'map', 'tips', 'p2k']) and TPath.IsPathRooted(Value) then
      Value := './' + ExtractRelativePath(IncludeTrailingPathDelimiter(FRomRoot), Value).Replace('\', '/');
    SetXmlChildText(Node, Field, Value);
  end;
  if JStr(Item, 'crc') <> '' then
    SetXmlChildText(Node, 'hash', JStr(Item, 'crc'));
  if JStr(Item, 'md5') <> '' then
    SetXmlChildText(Node, 'md5', JStr(Item, 'md5'));
  if JStr(Item, 'id') <> '' then
  begin
    Node.Attributes['id'] := JStr(Item, 'id');
    Node.Attributes['source'] := 'ScreenScraper.fr';
  end;
end;

function TGameListWriter.PrepareFolders(Cancel: TFunc<Boolean>): TArray<string>;
var
  Pair: TPair<string, TStringList>;
  Node: IXMLNode;
  Key, ImageFile: string;
  Files: TList<string>;
begin
  Files := TList<string>.Create;
  try
    for Pair in FFolderSources do
    begin
      if Assigned(Cancel) and Cancel() then
        raise EAbort.Create('Cancelled');
      Key := './' + ExtractRelativePath(IncludeTrailingPathDelimiter(FRomRoot), Pair.Key).Replace('\', '/');
      if FOnlyNew and FIndex.ContainsKey(NormalizeKey(Key)) then
        Continue;
      if not FIndex.TryGetValue(NormalizeKey(Key), Node) then
      begin
        Node := FRoot.AddChild('folder');
        FIndex.Add(NormalizeKey(Key), Node);
      end;
      SetXmlChildText(Node, 'path', Key);
      SetXmlChildText(Node, 'name', ExtractFileName(Pair.Key));
      ImageFile := TPlatformPath.Combine(FRomRoot, NativePath('media\folders\') + THashSHA2.GetHashString(Key) + '.png');
      RenderFolderArtwork(ImageFile, ExtractFileName(Pair.Key), Pair.Value, FFolderMode, Cancel);
      Files.Add(ImageFile);
      SetXmlChildText(Node, 'image', './' + ExtractRelativePath(IncludeTrailingPathDelimiter(FRomRoot), ImageFile).Replace('\', '/'));
    end;
    Result := Files.ToArray;
  finally
    Files.Free;
  end;
end;

procedure TGameListWriter.Save(Cancel: TFunc<Boolean>);
var
  Zip: TZipFile;
  Bytes: TBytes;
  Header: IXMLNode;
begin
  if FKind = 0 then
    Exit;
  if (FKind = 3) and not FPreserveHeader then
  begin
    Header := FRoot.ChildNodes.FindNode('header');
    if Header = nil then
      Header := FRoot.AddChild('header', 0);
    SetXmlChildText(Header, 'name', FPlatform);
    SetXmlChildText(Header, 'description', 'Information from ScreenScraper.fr database');
    SetXmlChildText(Header, 'author', AppBrand);
    SetXmlChildText(Header, 'version', '1.0');
    SetXmlChildText(Header, 'date', DateToISO8601(Now, False));
    SetXmlChildText(Header, 'url', ScreenScraperWebsite);
  end;
  if Assigned(Cancel) and Cancel() then
    raise EAbort.Create('Cancelled');
  ForceDirectories(ExtractFilePath(FFile));
  if not FOptimize then
    FDoc.Options := FDoc.Options + [doNodeAutoIndent];
  if FFile.EndsWith('.zip', True) then
  begin
    Zip := TZipFile.Create;
    try
      Zip.Open(FFile + '.tmp', zmWrite);
      Bytes := TEncoding.UTF8.GetBytes(FDoc.XML.Text);
      Zip.Add(Bytes, 'gamelist.xml');
    finally
      Zip.Free;
    end;
  end
  else
    FDoc.SaveToFile(FFile + '.tmp');
  if Assigned(Cancel) and Cancel() then
  begin
    TFile.Delete(FFile + '.tmp');
    raise EAbort.Create('Cancelled');
  end;
  if (FBehavior in [0, 2]) and TFile.Exists(FFile) then
    TFile.Copy(FFile, FFile + '.' + FormatDateTime('yyyymmdd-hhnnss-zzz', Now) + '.bak', False);
  if Assigned(Cancel) and Cancel() then
  begin
    TFile.Delete(FFile + '.tmp');
    raise EAbort.Create('Cancelled');
  end;
  CommitFile(FFile + '.tmp', FFile);
end;

end.

