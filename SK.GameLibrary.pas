unit SK.GameLibrary;

interface

uses
  System.SysUtils, System.Classes, System.JSON, System.Generics.Collections,
  Xml.XMLIntf, SK.GameList, SK.Output, SK.Input;

type
  TLibraryRule = (lrText, lrBoolean, lrRating, lrStars, lrDate, lrISODate,
    lrPlayers, lrInteger, lrCRC, lrMD5, lrSHA1, lrRomPath, lrMediaPath, lrYear, lrGUID);

  EGameLibraryValidation = class(Exception);

  TLibraryGame = class
  public
    RomPath: string;
    Node: IXMLNode;
  end;

  TLibraryField = class
  public
    Node: IXMLNode;
    Attribute, Caption: string;
    function Value: string;
    procedure SetValue(const Text: string);
    function IsMedia: Boolean;
    function Rule(Kind: Integer): TLibraryRule;
    function Help(Kind: Integer): string;
    function Validate(Kind: Integer; const RomRoot: string; out Error: string): Boolean;
  end;

  TGameLibrary = class
  private
    FConfig: TJSONObject;
    FWriter: TGameListWriter;
    FGames: TObjectList<TLibraryGame>;
    FFileName, FRoot, FRevision: string;
    FKind: Integer;
    function Revision: string;
    function NodePath(Node: IXMLNode): string;
  public
    constructor Create(Config: TJSONObject; Cancel: TFunc<Boolean> = nil);
    destructor Destroy; override;
    function Title(Index: Integer): string;
    function Draft(Index: Integer): IXMLDocument;
    procedure Save(Index: Integer; const Doc: IXMLDocument);
    procedure ReloadGame(Index: Integer);
    function ValidateField(Field: TLibraryField; out Error: string): Boolean;
    function Validate(const Doc: IXMLDocument; Errors: TStrings): Boolean;
    function MediaPath(const Value: string): string;
    function MediaReference(const FileName: string): string;
    property Games: TObjectList<TLibraryGame> read FGames;
    property FileName: string read FFileName;
    property Kind: Integer read FKind;
  end;

type
  IGameLibraryLoad = interface
    ['{D527FB88-0AF5-4E60-B5E2-0AE77ADAD129}']
    procedure Cancel;
    function Poll(out Data: TGameLibrary; out Error: string): Boolean;
  end;

function LoadGameLibraryAsync(Config: TJSONObject): IGameLibraryLoad;

function ParseGameXML(const XML: string; Kind: Integer): IXMLDocument;

procedure LibraryFields(const Node: IXMLNode; Fields: TObjectList<TLibraryField>);

implementation

uses
  SK.Xml, System.IOUtils, System.Hash, System.Variants, System.StrUtils,
  Xml.XMLDoc, SK.Json, SK.Platform, SK.Locale, System.RegularExpressions,
  System.DateUtils, System.Math, System.SyncObjs;

type
  TGameLibraryLoad = class(TInterfacedObject, IGameLibraryLoad)
  private
    FCancelled, FFinished: Integer;
    FData: TGameLibrary;
    FError: string;
    function IsCancelled: Boolean;
  public
    destructor Destroy; override;
    procedure Execute(Config: TJSONObject);
    procedure Cancel;
    function Poll(out Data: TGameLibrary; out Error: string): Boolean;
  end;

destructor TGameLibraryLoad.Destroy;
begin
  FData.Free;
  inherited;
end;

function TGameLibraryLoad.IsCancelled: Boolean;
begin
  Result := TInterlocked.CompareExchange(FCancelled, 0, 0) <> 0;
end;

procedure TGameLibraryLoad.Cancel;
begin
  TInterlocked.Exchange(FCancelled, 1);
end;

procedure TGameLibraryLoad.Execute(Config: TJSONObject);
begin
  try
    try
      BeginWorkerPlatform;
      try
        if IsCancelled then
          Exit;
        FData := TGameLibrary.Create(Config,
          function: Boolean
          begin
            Result := IsCancelled;
          end);
      finally
        EndWorkerPlatform;
      end;
    except
      on E: EAbort do
        ;
      on E: Exception do
        FError := E.Message;
    end;
  finally
    TInterlocked.Exchange(FFinished, 1);
  end;
end;

function TGameLibraryLoad.Poll(out Data: TGameLibrary; out Error: string): Boolean;
begin
  Data := nil;
  Error := '';
  Result := TInterlocked.CompareExchange(FFinished, 0, 0) <> 0;
  if Result then
  begin
    Data := FData;
    FData := nil;
    Error := FError;
  end;
end;

function LoadGameLibraryAsync(Config: TJSONObject): IGameLibraryLoad;
var
  Loader: TGameLibraryLoad;
  Lease: IGameLibraryLoad;
  WorkConfig: TJSONObject;
  Worker: TThread;
begin
  Loader := TGameLibraryLoad.Create;
  Result := Loader;
  Lease := Result;
  WorkConfig := Config.Clone as TJSONObject;
  try
    Worker := TThread.CreateAnonymousThread(
      procedure
      begin
        try
          // The lease owns the result even if its window closes while reading files.
          if Lease <> nil then
            Loader.Execute(WorkConfig);
        finally
          WorkConfig.Free;
        end;
      end);
  except
    WorkConfig.Free;
    raise;
  end;
  Worker.Start;
end;

function ParseGameXML(const XML: string; Kind: Integer): IXMLDocument;
var
  Expected: string;
begin
  Result := TXMLDocument.Create(nil);
  Result.LoadFromXML(XML);
  Result.Active := True;
  Expected := 'game';
  if Kind = 2 then
    Expected := 'Game';
  if (Result.DocumentElement = nil) or (Result.DocumentElement.NodeName <> Expected) then
    raise Exception.Create(L('XML должен содержать одну запись игры: ') + Expected);
end;

function TLibraryField.Value: string;
begin
  if Attribute <> '' then
    Result := VarToStr(Node.Attributes[Attribute])
  else
    Result := Node.Text;
end;

procedure TLibraryField.SetValue(const Text: string);
begin
  if Attribute <> '' then
    Node.Attributes[Attribute] := Text
  else
    Node.Text := Text;
end;

function TLibraryField.IsMedia: Boolean;
begin
  Result := ((Attribute = '') and MatchText(Node.NodeName, ['image', 'thumbnail', 'box', 'logo', 'marquee',
      'video', 'manual', 'tips', 'p2k', 'VideoPath', 'ManualPath', 'ImagePath',
      'ScreenshotImagePath', 'BoxFrontImagePath', 'ClearLogoImagePath'])) or
    (SameText(Node.NodeName, 'map') and ((Attribute = '') or SameText(Attribute, 'path')));
end;

function TLibraryField.Rule(Kind: Integer): TLibraryRule;
var
  Name: string;
begin
  Result := lrText;
  if IsMedia then
    Exit(lrMediaPath);
  if (Kind = 3) and SameText(Node.NodeName, 'rom') and (Attribute <> '') then
  begin
    if SameText(Attribute, 'name') then
      Exit(lrRomPath);
    if SameText(Attribute, 'crc') then
      Exit(lrCRC);
    if SameText(Attribute, 'md5') then
      Exit(lrMD5);
    if SameText(Attribute, 'sha1') then
      Exit(lrSHA1);
    if SameText(Attribute, 'size') then
      Exit(lrInteger);
    Exit;
  end;
  // Custom nested XML fields do not inherit restrictions from similarly named metadata.
  if (Attribute <> '') or Caption.Contains('/') then
    Exit;
  Name := Node.NodeName;
  if MatchText(Name, ['path', 'ApplicationPath']) then
    Exit(lrRomPath);
  if MatchText(Name, ['favorite', 'hidden', 'Hide', 'kidgame', 'broken', 'UseDosBox', 'UseScummVM']) then
    Exit(lrBoolean);
  if SameText(Name, 'rating') then
    Exit(lrRating);
  if SameText(Name, 'StarRatingFloat') then
    Exit(lrStars);
  if MatchText(Name, ['ReleaseDate', 'DateAdded', 'DateModified', 'LastPlayedDate']) and (Kind = 2) then
    Exit(lrISODate);
  if MatchText(Name, ['releasedate', 'lastplayed']) then
    Exit(lrDate);
  if SameText(Name, 'players') then
    Exit(lrPlayers);
  if MatchText(Name, ['genreid', 'playcount']) then
    Exit(lrInteger);
  if MatchText(Name, ['hash', 'crc']) then
    Exit(lrCRC);
  if SameText(Name, 'md5') then
    Exit(lrMD5);
  if SameText(Name, 'sha1') then
    Exit(lrSHA1);
  if (Kind = 3) and SameText(Name, 'year') then
    Exit(lrYear);
  if (Kind = 2) and SameText(Name, 'ID') then
    Exit(lrGUID);
end;

function TLibraryField.Help(Kind: Integer): string;
begin
  case Rule(Kind) of
    lrBoolean:
      Result := L('Допустимые значения: true — да, false — нет. Например: true.');
    lrRating:
      Result := L('Рейтинг от 0 до 1 включительно. Дробная часть через точку. Например: 0.85.');
    lrStars:
      Result := L('Рейтинг от 0 до 5 включительно. Дробная часть через точку. Например: 4.5.');
    lrDate:
      Result := L('Дата и время в формате YYYYMMDDThhmmss. Например: 19950311T000000. Проверяются существование даты и время от 00:00:00 до 23:59:59.');
    lrISODate:
      Result := L('Дата ISO 8601: YYYY-MM-DD или YYYY-MM-DDThh:mm:ss. Например: 1995-03-11T00:00:00. Допустимы дробные секунды и часовой пояс Z или +05:00.');
    lrPlayers:
      Result := L('Число игроков: положительное целое, диапазон или нижняя граница. Например: 1, 1-4, 4+. В диапазоне первое число не должно превышать второе.');
    lrInteger:
      Result := L('Неотрицательное целое число без дробной части. Например: 0 или 123.');
    lrCRC:
      Result := L('CRC32: ровно 8 шестнадцатеричных символов 0–9, A–F. Например: CBF43926. Регистр не важен.');
    lrMD5:
      Result := L('MD5: ровно 32 шестнадцатеричных символа 0–9, A–F. Например: 25f9e794323b453885f5181f1b624d0b. Регистр не важен.');
    lrSHA1:
      Result := L('SHA-1: ровно 40 шестнадцатеричных символов 0–9, A–F. Например: f7c3bc1d808e04732adf679965ccc34ca7ae3441. Регистр не важен.');
    lrRomPath:
      Result := L('Обязательный путь к ROM: абсолютный или относительно папки платформы. Например: ./Game.zip. Маски * и ?, URL и переносы строк недопустимы.');
    lrMediaPath:
      Result := L('Локальный путь к медиа: абсолютный или относительно папки платформы. Например: ./media/image.png. Кнопка выбора файла подставит путь автоматически. Маски и URL недопустимы.');
    lrYear:
      Result := L('Год: четыре цифры от 0001 до 9999. Например: 1995.');
    lrGUID:
      Result := L('Идентификатор LaunchBox в формате GUID. Например: 12345678-1234-1234-1234-123456789abc. Фигурные скобки допустимы.');
  else
    Result := '';
    if (Attribute = '') and not Caption.Contains('/') then
    begin
      if SameText(Node.NodeName, 'region') then
        Result := L('Регион игры: текст или список кодов через запятую. Примеры: us, eu, jp, wor. Дополнительные коды зависят от базы данных и фронтенда.')
      else if SameText(Node.NodeName, 'classification') then
        Result := L('Возрастная категория выбранной системы классификации. Например: PEGI 12 или E. Значение сохраняется как текст; перечень зависит от системы.')
      else if SameText(Node.NodeName, 'genre') then
        Result := L('Название жанра или несколько жанров через запятую. Например: Action, Adventure. Значение сохраняется как текст.');
    end;
  end;
  if Rule(Kind) = lrMediaPath then
  begin
    if MatchText(Node.NodeName, ['image', 'thumbnail', 'box', 'logo', 'marquee', 'ImagePath',
        'ScreenshotImagePath', 'BoxFrontImagePath', 'ClearLogoImagePath']) then
      Result := Result + sLineBreak + L('Форматы изображений: PNG, JPG, JPEG, BMP, GIF, WebP, SVG.')
    else if MatchText(Node.NodeName, ['video', 'VideoPath']) then
      Result := Result + sLineBreak + L('Форматы видео: MP4, AVI, MKV, MOV, WebM, WMV, M4V, MPG, MPEG.');
  end;
  if (Result <> '') and (Rule(Kind) <> lrRomPath) then
    Result := Result + sLineBreak + L('Пустое значение допустимо: поле не задано.');
end;

function MatchGroup(const M: TMatch; Index: Integer): string;
begin
  if Index < M.Groups.Count then
    Result := M.Groups[Index].Value
  else
    Result := '';
end;

function TLibraryField.Validate(Kind: Integer; const RomRoot: string; out Error: string): Boolean;
var
  S, Path, Ext: string;
  R: TLibraryRule;
  N, Last: Int64;
  Number: Double;
  M: TMatch;
  Date, Time: TDateTime;
  G: TGUID;
  Y, Month, Day, H, Minute, Second, Count: Integer;
begin
  Error := '';
  S := Value.Trim;
  R := Rule(Kind);
  if (R in [lrRomPath, lrMediaPath]) and (Value.Contains(#10) or Value.Contains(#13) or Value.Contains(#0)) then
  begin
    Error := L('Путь содержит недопустимые символы, маску или URL.');
    Exit(False);
  end;
  if not (R in [lrText, lrRomPath, lrMediaPath]) and (Value <> S) then
  begin
    Error := L('Удалите пробелы в начале и конце значения.');
    Exit(False);
  end;
  if S = '' then
  begin
    if R = lrRomPath then
      Error := L('Укажите путь ROM игры');
    Exit(Error = '');
  end;
  case R of
    lrBoolean:
      if not MatchText(S, ['true', 'false']) then
        Error := L('Введите true или false.');
    lrRating, lrStars:
      begin
        Last := 1;
        if R = lrStars then
          Last := 5;
        if not TRegEx.IsMatch(S, '^[0-9]+(?:\.[0-9]+)?$') or
          not TryStrToFloat(S, Number, TFormatSettings.Invariant) or IsNan(Number) or IsInfinite(Number) then
          Error := L('Введите число с дробной частью через точку.')
        else if (Number < 0) or (Number > Last) then
          Error := L('Допустимый диапазон: от 0 до %d.', [Last]);
      end;
    lrInteger:
      if not TRegEx.IsMatch(S, '^[0-9]+$') or not TryStrToInt64(S, N) or (N < 0) then
        Error := L('Введите неотрицательное целое число.');
    lrPlayers:
      begin
        M := TRegEx.Match(S, '^([1-9][0-9]*)(?:-([1-9][0-9]*)|\+)?$');
        if not M.Success or not TryStrToInt64(MatchGroup(M, 1), N) then
          Error := L('Введите число игроков, диапазон 1-4 или нижнюю границу 4+.')
        else if MatchGroup(M, 2) <> '' then
          if not TryStrToInt64(MatchGroup(M, 2), Last) or (Last < N) then
            Error := L('Конец диапазона игроков должен быть не меньше начала.');
      end;
    lrCRC, lrMD5, lrSHA1:
      begin
        case R of
          lrCRC:
            Count := 8;
          lrMD5:
            Count := 32;
        else
          Count := 40
        end;
        if (Length(S) <> Count) or not TRegEx.IsMatch(S, '^[0-9a-fA-F]+$') then
          Error := L('Требуется ровно %d символов 0–9, A–F.', [Count]);
      end;
    lrDate, lrISODate:
      begin
        if R = lrDate then
          M := TRegEx.Match(S, '^([0-9]{4})([0-9]{2})([0-9]{2})T([0-9]{2})([0-9]{2})([0-9]{2})$')
        else
          M := TRegEx.Match(S, '^([0-9]{4})-([0-9]{2})-([0-9]{2})(?:T([0-9]{2}):([0-9]{2}):([0-9]{2})(?:\.[0-9]{1,7})?(?:Z|[+-][0-9]{2}:[0-9]{2})?)?$');
        if not M.Success then
        begin
          if R = lrDate then
            Error := L('Формат даты: YYYYMMDDThhmmss.')
          else
            Error := L('Формат даты: YYYY-MM-DD или дата и время ISO 8601.');
        end
        else
        begin
          Y := StrToInt(MatchGroup(M, 1));
          Month := StrToInt(MatchGroup(M, 2));
          Day := StrToInt(MatchGroup(M, 3));
          H := StrToIntDef(MatchGroup(M, 4), 0);
          Minute := StrToIntDef(MatchGroup(M, 5), 0);
          Second := StrToIntDef(MatchGroup(M, 6), 0);
          if not TryEncodeDate(Y, Month, Day, Date) then
            Error := L('Такой календарной даты не существует.')
          else if not TryEncodeTime(H, Minute, Second, 0, Time) then
            Error := L('Время должно быть от 00:00:00 до 23:59:59.')
          else if R = lrISODate then
          begin
            M := TRegEx.Match(S, '[+-]([0-9]{2}):([0-9]{2})$');
            if M.Success and ((StrToInt(MatchGroup(M, 1)) > 23) or (StrToInt(MatchGroup(M, 2)) > 59)) then
              Error := L('Некорректное смещение часового пояса.');
          end;
        end;
      end;
    lrYear:
      if not TRegEx.IsMatch(S, '^[0-9]{4}$') or not TryStrToInt64(S, N) or (N < 1) then
        Error := L('Введите год: четыре цифры от 0001 до 9999.');
    lrGUID:
      begin
        Path := S;
        if (Length(Path) = 36) then
          Path := '{' + Path + '}';
        try
          G := StringToGUID(Path)
        except
          on E: EConvertError do
            Error := L('Введите идентификатор GUID.')
        end;
      end;
    lrRomPath, lrMediaPath:
      begin
        try
          Path := NativePath(S);
          if S.Contains(#10) or S.Contains(#13) or S.Contains('://') or
            not TPath.HasValidPathChars(Path, False) then
            Error := L('Путь содержит недопустимые символы, маску или URL.')
          else
          begin
            if not TPath.IsPathRooted(Path) then
              Path := TPlatformPath.Combine(RomRoot, Path);
            Path := TPath.GetFullPath(Path);
            if R = lrMediaPath then
            begin
              Ext := TPath.GetExtension(Path).ToLower;
              if MatchText(Node.NodeName, ['image', 'thumbnail', 'box', 'logo', 'marquee', 'ImagePath',
                  'ScreenshotImagePath', 'BoxFrontImagePath', 'ClearLogoImagePath']) and
                not MatchText(Ext, ['.png', '.jpg', '.jpeg', '.bmp', '.gif', '.webp', '.svg']) then
                Error := L('Для изображения выберите PNG, JPG, JPEG, BMP, GIF, WebP или SVG.')
              else if MatchText(Node.NodeName, ['video', 'VideoPath']) and
                not MatchText(Ext, ['.mp4', '.avi', '.mkv', '.mov', '.webm', '.wmv', '.m4v', '.mpg', '.mpeg']) then
                Error := L('Для видео выберите MP4, AVI, MKV, MOV, WebM, WMV, M4V, MPG или MPEG.');
            end;
          end;
        except
          on E: Exception do
            Error := L('Некорректный путь к файлу.')
        end;
      end;
  end;
  Result := Error = '';
end;

function TGameLibrary.ValidateField(Field: TLibraryField; out Error: string): Boolean;
begin
  Result := Field.Validate(FKind, FRoot, Error)
end;

function TGameLibrary.Validate(const Doc: IXMLDocument; Errors: TStrings): Boolean;
var
  Fields: TObjectList<TLibraryField>;
  Field: TLibraryField;
  Error: string;
  HasPath: Boolean;
begin
  Errors.Clear;
  Fields := TObjectList<TLibraryField>.Create(True);
  try
    LibraryFields(Doc.DocumentElement, Fields);
    HasPath := False;
    for Field in Fields do
    begin
      if Field.Rule(FKind) = lrRomPath then
        HasPath := True;
      if not ValidateField(Field, Error) then
        Errors.Add(Field.Caption + ': ' + Error);
    end;
    if not HasPath then
      Errors.Add(L('Укажите путь ROM игры'));
    Result := Errors.Count = 0;
  finally
    Fields.Free
  end;
end;

procedure LibraryFields(const Node: IXMLNode; Fields: TObjectList<TLibraryField>);

  procedure Visit(N: IXMLNode; const Prefix: string);
  var
    I, J, Ordinal: Integer;
    C: IXMLNode;
    F: TLibraryField;
    Key: string;
  begin
    for I := 0 to N.AttributeNodes.Count - 1 do
    begin
      F := TLibraryField.Create;
      F.Node := N;
      F.Attribute := N.AttributeNodes[I].NodeName;
      F.Caption := Prefix + '@' + F.Attribute;
      Fields.Add(F);
    end;
    if (N.ChildNodes.Count = 0) or N.IsTextElement or
      ((N.ChildNodes.Count = 1) and (N.ChildNodes[0].NodeType = ntCData)) then
    begin
      F := TLibraryField.Create;
      F.Node := N;
      F.Caption := Prefix.TrimRight(['/']);
      Fields.Add(F);
    end;
    for I := 0 to N.ChildNodes.Count - 1 do
    begin
      C := N.ChildNodes[I];
      if C.NodeType <> ntElement then
        Continue;
      Ordinal := 1;
      for J := 0 to I - 1 do
        if N.ChildNodes[J].NodeName = C.NodeName then
          Inc(Ordinal);
      Key := C.NodeName;
      if Ordinal > 1 then
        Key := Key + '[' + Ordinal.ToString + ']';
      Visit(C, Prefix + Key + '/');
    end;
  end;

begin
  Fields.Clear;
  Visit(Node, '');
end;

function TGameLibrary.Revision: string;
begin
  if TFile.Exists(FFileName) then
    Result := THashSHA2.GetHashStringFromFile(FFileName)
  else
    Result := '';
end;

function TGameLibrary.MediaPath(const Value: string): string;
begin
  Result := '';
  if Value.Trim = '' then
    Exit;
  Result := NativePath(Value);
  if not TPath.IsPathRooted(Result) then
    Result := TPlatformPath.Combine(FRoot, Result);
  Result := TPath.GetFullPath(Result);
end;

function TGameLibrary.MediaReference(const FileName: string): string;
begin
  if not TFile.Exists(FileName) then
    raise Exception.Create(L('Файл медиа не найден'));
  // Keep the chosen file intact; the game references it, like scraped media.
  if FKind = 2 then
    Result := TPath.GetFullPath(FileName)
  else
    Result := './' + ExtractRelativePath(IncludeTrailingPathDelimiter(FRoot),
      TPath.GetFullPath(FileName)).Replace('\', '/');
end;

function TGameLibrary.NodePath(Node: IXMLNode): string;
var
  C: IXMLNode;
begin
  case FKind of
    2:
      Result := XmlChildText(Node, 'ApplicationPath');
    3:
      begin
        C := Node.ChildNodes.FindNode('rom');
        if (C <> nil) and C.HasAttribute('name') then
          Result := VarToStr(C.Attributes['name'])
        else
          Result := '';
      end;
  else
    Result := XmlChildText(Node, 'path');
  end;
  Result := MediaPath(Result);
end;

constructor TGameLibrary.Create(Config: TJSONObject; Cancel: TFunc<Boolean>);
var
  N, RootNode: IXMLNode;
  G: TLibraryGame;
  I: Integer;
  Path, Key: string;
  Index: TDictionary<string, Boolean>;
  Doc: IXMLDocument;
begin
  inherited Create;
  FGames := TObjectList<TLibraryGame>.Create(True);
  FConfig := Config.Clone as TJSONObject;
  FRoot := JStr(Config, 'GamesAndRoms.Path');
  if not TDirectory.Exists(FRoot) then
    raise Exception.Create(L('Папка ROM не найдена'));
  FKind := JInt(Config, 'GameList.Type', 1);
  if FKind = 0 then
  begin
    FKind := 1;
    JSet(FConfig, 'GameList.Type', TJSONNumber.Create(1));
    JSet(FConfig, 'GameList.OutputFile', TJSONString.Create(TPlatformPath.Combine(FRoot, 'gamelist.xml')));
  end;
  FFileName := ResolveOutput(JStr(FConfig, 'GameList.OutputFile', 'gamelist.xml'), FRoot, FRoot);
  FRevision := Revision;
  JSet(FConfig, 'GameList.Behavior', TJSONNumber.Create(2));
  JSet(FConfig, 'GameList.Folders', TJSONNumber.Create(0));
  JSet(FConfig, 'GameList.PreserveHeader', TJSONBool.Create(True));
  FWriter := TGameListWriter.Create(FConfig);
  RootNode := FWriter.Document.DocumentElement;
  Index := TDictionary<string, Boolean>.Create;
  try
    for I := 0 to RootNode.ChildNodes.Count - 1 do
    begin
      if Assigned(Cancel) and Cancel() then
        raise EAbort.Create('Library loading cancelled');
      N := RootNode.ChildNodes[I];
      if not (((FKind = 2) and (N.NodeName = 'Game')) or
        ((FKind <> 2) and (N.NodeName = 'game'))) then
        Continue;
      Path := NodePath(N);
      if Path = '' then
        Continue;
      G := TLibraryGame.Create;
      G.RomPath := Path;
      G.Node := N;
      FGames.Add(G);
      Index.AddOrSetValue(PathKey(Path), True);
    end;
    for Path in ScanInputs(FConfig, Cancel) do
    begin
      if Assigned(Cancel) and Cancel() then
        raise EAbort.Create('Library loading cancelled');
      Key := PathKey(Path);
      if Index.ContainsKey(Key) then
        Continue;
      Doc := TXMLDocument.Create(nil);
      Doc.Active := True;
      if FKind = 2 then
        N := Doc.AddChild('Game')
      else
        N := Doc.AddChild('game');
      case FKind of
        2:
          begin
            N.AddChild('ApplicationPath').Text := Path;
            N.AddChild('Title').Text := TPath.GetFileNameWithoutExtension(Path);
          end;
        3:
          begin
            N.Attributes['name'] := TPath.GetFileNameWithoutExtension(Path);
            N.AddChild('rom').Attributes['name'] := './' + ExtractRelativePath(
                IncludeTrailingPathDelimiter(FRoot), Path).Replace('\', '/');
          end;
      else
        N.AddChild('path').Text := './' + ExtractRelativePath(IncludeTrailingPathDelimiter(FRoot), Path).Replace('\', '/');
        N.AddChild('name').Text := TPath.GetFileNameWithoutExtension(Path);
      end;
      G := TLibraryGame.Create;
      G.RomPath := Path;
      G.Node := N;
      FGames.Add(G);
      Index.Add(Key, True);
    end;
  finally
    Index.Free
  end;
end;

destructor TGameLibrary.Destroy;
begin
  FGames.Free;
  FWriter.Free;
  FConfig.Free;
  inherited
end;

function TGameLibrary.Title(Index: Integer): string;
begin
  case FKind of
    2:
      Result := XmlChildText(FGames[Index].Node, 'Title');
    3:
      Result := VarToStr(FGames[Index].Node.Attributes['name']);
  else
    Result := XmlChildText(FGames[Index].Node, 'name');
  end;
  if Result = '' then
    Result := TPath.GetFileNameWithoutExtension(FGames[Index].RomPath);
end;

function TGameLibrary.Draft(Index: Integer): IXMLDocument;
var
  N: IXMLNode;
  Field: string;
begin
  Result := ParseGameXML(FGames[Index].Node.XML, FKind);
  N := Result.DocumentElement;
  // Empty supported fields are editable even when the list hasn't been scraped yet.
  if FKind = 1 then
    for Field in ['name', 'desc', 'developer', 'publisher', 'players', 'rating', 'releasedate', 'genre', 'genreid', 'classification', 'region', 'favorite', 'hidden', 'image', 'thumbnail', 'box', 'logo', 'marquee', 'video', 'manual', 'tips', 'p2k', 'hash', 'md5'] do
      if N.ChildNodes.FindNode(Field) = nil then
        N.AddChild(Field).Text := '';
  if FKind = 2 then
    for Field in ['Title', 'Notes', 'Developer', 'Publisher', 'Genre', 'Favorite', 'Hide', 'Platform', 'Region', 'VideoPath', 'ManualPath', 'StarRatingFloat', 'ReleaseDate', 'ImagePath'] do
      if N.ChildNodes.FindNode(Field) = nil then
        N.AddChild(Field).Text := '';
end;

procedure CopyLibraryContents(const Source, Target: IXMLNode);
var
  I: Integer;
  C, A: IXMLNode;
begin
  for I := 0 to Source.AttributeNodes.Count - 1 do
  begin
    A := Source.AttributeNodes[I];
    Target.SetAttributeNS(A.NodeName, A.NamespaceURI, A.NodeValue);
  end;
  for I := 0 to Source.ChildNodes.Count - 1 do
  begin
    A := Source.ChildNodes[I];
    case A.NodeType of
      ntElement:
        C := Target.OwnerDocument.CreateElement(A.NodeName, A.NamespaceURI);
      ntProcessingInstr:
        C := Target.OwnerDocument.CreateNode(A.NodeName, ntProcessingInstr, VarToStr(A.NodeValue));
    else
      C := Target.OwnerDocument.CreateNode(A.Text, A.NodeType);
    end;
    // Omni XML requires a parent before adding multiple element children.
    Target.ChildNodes.Add(C);
    if A.NodeType = ntElement then
      CopyLibraryContents(A, C);
  end;
end;

procedure TGameLibrary.ReloadGame(Index: Integer);
var
  Writer: TGameListWriter;
  Nodes: TArray<IXMLNode>;
  Known: TDictionary<string, Integer>;
  Root, Node: IXMLNode;
  I, GameIndex: Integer;
  NewRevision: string;
begin
  if (Index < 0) or (Index >= FGames.Count) then
    raise EArgumentOutOfRangeException.Create('Game index');
  // Refresh the XML snapshot without rescanning ROMs or recreating game objects.
  NewRevision := Revision;
  Writer := TGameListWriter.Create(FConfig);
  Known := TDictionary<string, Integer>.Create;
  try
    SetLength(Nodes, FGames.Count);
    for I := 0 to FGames.Count - 1 do
      Known.AddOrSetValue(PathKey(FGames[I].RomPath), I);
    Root := Writer.Document.DocumentElement;
    for I := 0 to Root.ChildNodes.Count - 1 do
    begin
      Node := Root.ChildNodes[I];
      if not (((FKind = 2) and (Node.NodeName = 'Game')) or
        ((FKind <> 2) and (Node.NodeName = 'game'))) then
        Continue;
      if Known.TryGetValue(PathKey(NodePath(Node)), GameIndex) then
        Nodes[GameIndex] := Node;
    end;
    // Undocumented ROMs keep their in-memory node until first successful scrape/save.
    for I := 0 to FGames.Count - 1 do
      if Nodes[I] <> nil then
        FGames[I].Node := Nodes[I];
    FWriter.Free;
    FWriter := Writer;
    Writer := nil;
    FRevision := NewRevision;
  finally
    Known.Free;
    Writer.Free;
  end;
end;

procedure TGameLibrary.Save(Index: Integer; const Doc: IXMLDocument);
var
  Parsed: IXMLDocument;
  N, Old, RootNode: IXMLNode;
  I, Position: Integer;
  Path: string;
  Errors: TStringList;
begin
  if Revision <> FRevision then
    raise Exception.Create(L('Библиотека изменена другим процессом. Закройте окно и откройте библиотеку заново.'));
  Parsed := ParseGameXML(Doc.DocumentElement.XML, FKind);
  Errors := TStringList.Create;
  try
    if not Validate(Parsed, Errors) then
      raise EGameLibraryValidation.Create(Errors.Text.Trim);
  finally
    Errors.Free
  end;
  Path := NodePath(Parsed.DocumentElement);
  if Path = '' then
    raise Exception.Create(L('Укажите путь ROM игры'));
  for I := 0 to FGames.Count - 1 do
    if (I <> Index) and SamePath(FGames[I].RomPath, Path) then
      raise Exception.Create(L('Игра с таким путём ROM уже есть в библиотеке'));
  RootNode := FWriter.Document.DocumentElement;
  Old := FGames[Index].Node;
  Position := RootNode.ChildNodes.IndexOf(Old);
  N := FWriter.Document.CreateElement(Parsed.DocumentElement.NodeName, Parsed.DocumentElement.NamespaceURI);
  if Position >= 0 then
    RootNode.ChildNodes.Remove(Old);
  try
    if Position >= 0 then
      RootNode.ChildNodes.Insert(Position, N)
    else
      RootNode.ChildNodes.Add(N);
    CopyLibraryContents(Parsed.DocumentElement, N);
    FWriter.Save;
  except
    if RootNode.ChildNodes.IndexOf(N) >= 0 then
      RootNode.ChildNodes.Remove(N);
    if Position >= 0 then
      RootNode.ChildNodes.Insert(Position, Old);
    raise;
  end;
  FGames[Index].Node := N;
  FGames[Index].RomPath := Path;
  FRevision := Revision;
end;

end.
