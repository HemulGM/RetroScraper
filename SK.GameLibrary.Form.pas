unit SK.GameLibrary.Form;

interface

uses
  System.SysUtils, System.Classes, System.JSON, System.Generics.Collections,
  System.Types, System.UITypes, Xml.XMLIntf, FMX.Types, FMX.Forms, FMX.Controls,
  FMX.Controls.Presentation, FMX.Layouts, FMX.StdCtrls, FMX.Edit, FMX.ListBox,
  FMX.Memo, FMX.Memo.Types, FMX.ScrollBox, FMX.Objects, FMX.TabControl,
  FMX.Dialogs, SK.GameLibrary, FMX.Graphics;

type
  TGameFieldEditor = class(TLayout)
  private
    function GetText: string;
    procedure SetText(const Value: string);
    procedure BindControls;
  public
    Field: TLibraryField;
    HeaderLayout, ValueColumn, InputFrame, EditorArea, InputControlFrame: TLayout;
    ErrorFrame: TRectangle;
    CaptionLabel, ErrorLabel, MediaNote: TLabel;
    HelpText, ErrorText: string;
    InfoButton: TButton;
    InfoIcon: FMX.Objects.TPath;
    HelpMemo: TMemo;
    ValueEdit: TEdit;
    ValueMemo: TMemo;
    MediaImage: TImage;
    PreviewLoading: Boolean;
    MediaCommands: TLayout;
    ReplaceMediaButton, ClearMediaButton: TButton;
    property Text: string read GetText write SetText;
  end;

  TFormGameLibrary = class(TForm)
    Surface: TRectangle;
    RootLayout: TLayout;
    Header: TLayout;
    TitleLabel, CountLabel, PlatformLabel, GameTitleLabel, GamePlatformLabel: TLabel;
    PlatformHeader, EditorPanel, GameHeader, TabActions: TLayout;
    CommandButtons: TGridPanelLayout;
    FieldsTabButton, XMLTabButton: TButton;
    FieldsTabLine, XMLTabLine: TRectangle;
    HeaderIcon: FMX.Objects.TPath;
    FooterDivider, LibraryDivider: TRectangle;
    FieldRowTemplate: TGameFieldEditor;
    Commands: TLayout;
    SaveButton, ScrapeButton, CloseButton: TButton;
    Body: TLayout;
    GamesPanel: TLayout;
    SearchEdit: TEdit;
    GameList: TListBox;
    EditorTabs: TTabControl;
    FieldsTab, XMLTab: TTabItem;
    FieldsBody, FieldsContent: TLayout;
    FieldsScroll: TVertScrollBox;
    StatusLabel: TLabel;
    XMLMemo: TMemo;
    MediaDialog: TOpenDialog;
    FieldInfoIconTemplate: FMX.Objects.TPath;
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure FormCloseQuery(Sender: TObject; var CanClose: Boolean);
    procedure SearchChanged(Sender: TObject);
    procedure GameChanged(Sender: TObject);
    procedure ValueChanged(Sender: TObject);
    procedure XMLChanged(Sender: TObject);
    procedure TabChanged(Sender: TObject);
    procedure EditorTabClick(Sender: TObject);
    procedure SaveClick(Sender: TObject);
    procedure ScrapeClick(Sender: TObject);
    procedure MediaClick(Sender: TObject);
    procedure InfoClick(Sender: TObject);
    procedure CloseClick(Sender: TObject);
  private
    FLibrary: TGameLibrary;
    FDraft: IXMLDocument;
    FFields: TObjectList<TLibraryField>;
    FEditors: TList<TGameFieldEditor>;
    FSelected: Integer;
    FLoading, FDirty, FXMLDirty: Boolean;
    FRequestedRom, FPlatformTitle: string;
    procedure BuildGames;
    procedure LoadGameCover(Picture: TImage; const Paths: TArray<string>; Index: Integer);
    procedure BuildFields;
    procedure LoadGame(Index: Integer);
    procedure UpdateMedia(Editor: TGameFieldEditor);
    procedure UpdateFieldsHeight;
    procedure UpdateButtons;
    procedure ApplyXML;
    function SaveGame: Boolean;
    procedure ValidateEditor(Editor: TGameFieldEditor);
    function ResolveUnsaved: Boolean;
    procedure ReportError(E: Exception);
  public
    procedure LoadPlatform(Config: TJSONObject; const PlatformTitle: string);
    function FieldEditor(const FieldName: string): TGameFieldEditor;
    function FieldCount: Integer;
    function ValidateDraft: Boolean;
    property RequestedRom: string read FRequestedRom;
  end;

implementation

uses
  System.IOUtils, System.StrUtils, Xml.XMLDoc, FMX.DialogService.Sync,
  SK.Platform, SK.Locale, System.Generics.Defaults, System.Math, HGM.FMX.Image;

{$R *.fmx}

function FieldCaption(const Name: string): string;
begin
  Result := Name;
  if MatchText(Name, ['name', 'Title', '@name']) then
    Result := L('Название')
  else if MatchText(Name, ['desc', 'Notes', 'description']) then
    Result := L('Описание')
  else if SameText(Name, 'developer') then
    Result := L('Разработчик')
  else if SameText(Name, 'publisher') then
    Result := L('Издатель')
  else if SameText(Name, 'players') then
    Result := L('Число игроков')
  else if MatchText(Name, ['rating', 'StarRatingFloat']) then
    Result := L('Рейтинг')
  else if MatchText(Name, ['releasedate', 'ReleaseDate']) then
    Result := L('Дата выпуска')
  else if SameText(Name, 'genre') then
    Result := L('Жанр')
  else if SameText(Name, 'region') then
    Result := L('Регион')
  else if SameText(Name, 'favorite') then
    Result := L('Избранное')
  else if MatchText(Name, ['hidden', 'Hide']) then
    Result := L('Скрытая игра')
  else if SameText(Name, 'image') then
    Result := L('Изображение')
  else if SameText(Name, 'thumbnail') then
    Result := L('Миниатюра')
  else if SameText(Name, 'box') then
    Result := L('Обложка')
  else if MatchText(Name, ['logo', 'marquee']) then
    Result := L('Логотип')
  else if MatchText(Name, ['video', 'VideoPath']) then
    Result := L('Видео')
  else if MatchText(Name, ['manual', 'ManualPath']) then
    Result := L('Руководство')
  else if MatchText(Name, ['path', 'ApplicationPath', 'rom/@name']) then
    Result := L('Путь ROM');
end;

procedure TFormGameLibrary.FormCreate(Sender: TObject);
begin
  FSelected := -1;
  FEditors := TList<TGameFieldEditor>.Create;
  FFields := TObjectList<TLibraryField>.Create(True);
  ApplyLocale(Self);
  UpdateButtons;
end;

procedure TFormGameLibrary.FormDestroy(Sender: TObject);
begin
  FLoading := True;
  FieldsContent.DeleteChildren;
  GameList.Clear;
  FEditors.Free;
  FFields.Free;
  FDraft := nil;
  FLibrary.Free;
end;

procedure TFormGameLibrary.LoadPlatform(Config: TJSONObject; const PlatformTitle: string);
begin
  FLibrary := TGameLibrary.Create(Config);
  Caption := L('Библиотека игр') + ' · ' + PlatformTitle;
  FPlatformTitle := PlatformTitle;
  PlatformLabel.Text := PlatformTitle;
  GamePlatformLabel.Text := PlatformTitle;
  StatusLabel.Text := FLibrary.FileName;
  BuildGames;
  if GameList.Count > 0 then
    GameList.ItemIndex := 0;
end;

procedure TFormGameLibrary.BuildGames;
var
  I, SelectedItem: Integer;
  Filter, Text, Path: string;
  Item: TListBoxItem;
  Picture: TImage;
  Labels: TLayout;
  LabelText: TLabel;
  Node: IXMLNode;
  FieldName: string;
  CoverPaths: TArray<string>;
begin
  FLoading := True;
  GameList.BeginUpdate;
  try
    GameList.Clear;
    SelectedItem := -1;
    Filter := SearchEdit.Text.Trim.ToLower;
    for I := 0 to FLibrary.Games.Count - 1 do
    begin
      Text := FLibrary.Title(I);
      if (Filter <> '') and not (Text.ToLower.Contains(Filter) or
        FLibrary.Games[I].RomPath.ToLower.Contains(Filter)) then
        Continue;
      Item := TListBoxItem.Create(GameList);
      Item.Parent := GameList;
      Item.Tag := I;
      Item.Height := 86;
      Item.Text := '';
      Item.StyleLookup := 'listboxitemstyle';
      Item.Padding.Rect := RectF(10, 8, 10, 8);
      Picture := TImage.Create(Item);
      Picture.Name := 'GameCover';
      Picture.Parent := Item;
      Picture.Align := TAlignLayout.Left;
      Picture.Width := 48;
      Picture.Margins.Right := 12;
      Picture.WrapMode := TImageWrapMode.Fit;
      Picture.HitTest := False;
      CoverPaths := nil;
      for FieldName in ['box', 'image', 'thumbnail', 'ImagePath', 'BoxFrontImagePath'] do
      begin
        Node := FLibrary.Games[I].Node.ChildNodes.FindNode(FieldName);
        if (Node = nil) or (Node.Text.Trim = '') then
          Continue;
        try
          Path := FLibrary.MediaPath(Node.Text);
          if Path <> '' then
            CoverPaths := CoverPaths + [Path];
        except
          // Skip malformed media paths and try the remaining cover fields.
        end;
      end;
      Picture.Visible := False;
      LoadGameCover(Picture, CoverPaths, 0);
      Labels := TLayout.Create(Item);
      Labels.Parent := Item;
      Labels.Align := TAlignLayout.Client;
      Labels.HitTest := False;
      LabelText := TLabel.Create(Item);
      LabelText.Parent := Labels;
      LabelText.Align := TAlignLayout.Top;
      LabelText.Height := 30;
      LabelText.Text := Text;
      LabelText.HitTest := False;
      LabelText.TextSettings.Trimming := TTextTrimming.Character;
      LabelText.TextSettings.WordWrap := False;
      LabelText := TLabel.Create(Item);
      LabelText.Parent := Labels;
      LabelText.Align := TAlignLayout.Top;
      LabelText.Height := 24;
      LabelText.Text := TPath.GetFileName(FLibrary.Games[I].RomPath);
      LabelText.Opacity := 0.7;
      LabelText.HitTest := False;
      LabelText.TextSettings.WordWrap := False;
      LabelText.TextSettings.Trimming := TTextTrimming.Character;
      if I = FSelected then
        SelectedItem := GameList.Count - 1;
    end;
    GameList.ItemIndex := SelectedItem;
    CountLabel.Text := L('%d игр · показано %d', [FLibrary.Games.Count, GameList.Count]);
  finally
    GameList.EndUpdate;
    FLoading := False
  end;
end;

procedure TFormGameLibrary.LoadGameCover(Picture: TImage; const Paths: TArray<string>; Index: Integer);
begin
  if Index >= Length(Paths) then
    Exit;
  // Picture owns the request lifetime, including when search rebuilds the list.
  Picture.Bitmap.LoadFromFileAsync(Picture, Paths[Index], 48, 70,
    procedure(Success: Boolean)
    begin
      if Success then
        Picture.Visible := True
      else
        LoadGameCover(Picture, Paths, Index + 1);
    end);
end;

procedure TFormGameLibrary.SearchChanged(Sender: TObject);
begin
  if FLoading or (FLibrary = nil) then
    Exit;
  BuildGames;
end;

procedure TFormGameLibrary.LoadGame(Index: Integer);
begin
  FSelected := Index;
  GameTitleLabel.Text := FLibrary.Title(Index);
  FDraft := FLibrary.Draft(Index);
  FDirty := False;
  FXMLDirty := False;
  FLoading := True;
  try
    EditorTabs.ActiveTab := FieldsTab;
    XMLMemo.Text := FDraft.DocumentElement.XML;
  finally
    FLoading := False
  end;
  BuildFields;
  UpdateButtons;
  StatusLabel.Text := FLibrary.Games[Index].RomPath;
end;

procedure TFormGameLibrary.GameChanged(Sender: TObject);
var
  Index: Integer;
begin
  if FLoading or (GameList.Selected = nil) then
    Exit;
  Index := GameList.Selected.Tag;
  if Index = FSelected then
    Exit;
  if not ResolveUnsaved then
  begin
    BuildGames;
    Exit
  end;
  LoadGame(Index);
end;

function TGameFieldEditor.GetText: string;
begin
  if ValueMemo.Visible then
    Result := ValueMemo.Text
  else
    Result := ValueEdit.Text;
end;

procedure TGameFieldEditor.SetText(const Value: string);
begin
  if ValueMemo.Visible then
    ValueMemo.Text := Value
  else
    ValueEdit.Text := Value;
end;

function TFormGameLibrary.FieldEditor(const FieldName: string): TGameFieldEditor;
var
  Editor: TGameFieldEditor;
begin
  Result := nil;
  for Editor in FEditors do
    if Editor.Field.Caption = FieldName then
      Exit(Editor);
end;

function TFormGameLibrary.FieldCount: Integer;
begin
  Result := FEditors.Count
end;

function TemplatePart(Root: TFmxObject; const PartName: string): TFmxObject;
var
  Child, Found: TFmxObject;
begin
  if Root.StyleName = PartName then
    Exit(Root);
  if Root.Children <> nil then
    for Child in Root.Children do
    begin
      Found := TemplatePart(Child, PartName);
      if Found <> nil then
        Exit(Found);
    end;
  Result := nil;
end;

procedure TGameFieldEditor.BindControls;
begin
  HeaderLayout := TLayout(TemplatePart(Self, 'fieldheader'));
  ValueColumn := TLayout(TemplatePart(Self, 'fieldvaluecolumn'));
  InputFrame := TLayout(TemplatePart(Self, 'fieldinputframe'));
  EditorArea := TLayout(TemplatePart(Self, 'fieldeditorarea'));
  InputControlFrame := TLayout(TemplatePart(Self, 'fieldinputcontrols'));
  ErrorFrame := TRectangle(TemplatePart(Self, 'fielderrorframe'));
  CaptionLabel := TLabel(TemplatePart(Self, 'fieldcaption'));
  ErrorLabel := TLabel(TemplatePart(Self, 'fielderror'));
  InfoButton := TButton(TemplatePart(Self, 'fieldinfo'));
  InfoIcon := FMX.Objects.TPath(TemplatePart(Self, 'fieldinfoicon'));
  HelpMemo := TMemo(TemplatePart(Self, 'fieldhelp'));
  ValueEdit := TEdit(TemplatePart(Self, 'fieldedit'));
  ValueMemo := TMemo(TemplatePart(Self, 'fieldmemo'));
  MediaImage := TImage(TemplatePart(Self, 'fieldmediaimage'));
  MediaCommands := TLayout(TemplatePart(Self, 'fieldmediacommands'));
  ReplaceMediaButton := TButton(TemplatePart(Self, 'fieldreplace'));
  ClearMediaButton := TButton(TemplatePart(Self, 'fieldclear'));
  MediaNote := TLabel(TemplatePart(Self, 'fieldmedianote'));
  if (HeaderLayout = nil) or (ValueColumn = nil) or (InputFrame = nil) or
    (EditorArea = nil) or (InputControlFrame = nil) or (ErrorFrame = nil) or
    (CaptionLabel = nil) or (ErrorLabel = nil) or
    (InfoButton = nil) or (InfoIcon = nil) or (HelpMemo = nil) or
    (ValueEdit = nil) or (ValueMemo = nil) or (MediaImage = nil) or
    (MediaCommands = nil) or (ReplaceMediaButton = nil) or
    (ClearMediaButton = nil) or (MediaNote = nil) then
    raise Exception.Create('The game field FMX template is incomplete');
end;

function FieldOrder(Field: TLibraryField): Integer;
begin
  Result := 100;
  if MatchText(Field.Caption, ['name', 'Title', '@name']) then
    Exit(0);
  if MatchText(Field.Caption, ['desc', 'Notes', 'description']) then
    Exit(1);
  if MatchText(Field.Caption, ['rating', 'StarRatingFloat']) then
    Exit(2);
  if MatchText(Field.Caption, ['releasedate', 'ReleaseDate']) then
    Exit(3);
  if SameText(Field.Caption, 'players') then
    Exit(4);
  if SameText(Field.Caption, 'box') then
    Exit(5);
  if MatchText(Field.Caption, ['image', 'ImagePath', 'BoxFrontImagePath']) then
    Exit(6);
  if Field.IsMedia then
    Exit(10);
  if SameText(Field.Caption, 'developer') then
    Exit(20);
  if SameText(Field.Caption, 'publisher') then
    Exit(21);
  if SameText(Field.Caption, 'genre') then
    Exit(22);
  if SameText(Field.Caption, 'region') then
    Exit(23);
  if SameText(Field.Caption, 'classification') then
    Exit(24);
  if SameText(Field.Caption, 'favorite') then
    Exit(25);
  if MatchText(Field.Caption, ['hidden', 'Hide']) then
    Exit(26);
  if Field.Rule(1) = lrRomPath then
    Exit(30);
  if MatchText(Field.Caption, ['hash', 'crc', 'md5', 'sha1']) then
    Exit(40);
  if Field.Caption.StartsWith('@') then
    Exit(90);
end;

procedure TFormGameLibrary.BuildFields;
var
  I: Integer;
  F: TLibraryField;
  Editor: TGameFieldEditor;
begin
  FLoading := True;
  FieldsScroll.ApplyStyleLookup;
  FieldsContent.BeginUpdate;
  try
    FieldsContent.DeleteChildren;
    FEditors.Clear;
    LibraryFields(FDraft.DocumentElement, FFields);
    FFields.Sort(TComparer<TLibraryField>.Construct(
      function(const A, B: TLibraryField): Integer
      begin
        Result := CompareValue(FieldOrder(A), FieldOrder(B));
        if Result = 0 then
          Result := CompareText(A.Caption, B.Caption);
      end));
    for I := 0 to FFields.Count - 1 do
    begin
      F := FFields[I];
      Editor := TGameFieldEditor(FieldRowTemplate.Clone(FieldsContent));
      Editor.BindControls;
      Editor.Parent := FieldsContent;
      Editor.Align := TAlignLayout.Top;
      Editor.Visible := True;
      Editor.Field := F;
      FEditors.Add(Editor);
      Editor.BeginUpdate;
      try
        Editor.CaptionLabel.Text := FieldCaption(F.Caption);
        Editor.CaptionLabel.Hint := F.Caption;
        Editor.CaptionLabel.ShowHint := True;
        Editor.HelpText := F.Help(FLibrary.Kind);
        Editor.InfoButton.Visible := Editor.HelpText <> '';
        Editor.InfoButton.Tag := I;
        Editor.InfoButton.Hint := L('Формат и допустимые значения');
        Editor.InfoButton.OnClick := InfoClick;
        Editor.HelpMemo.Text := Editor.HelpText;
        Editor.HelpMemo.Visible := False;
        Editor.ValueMemo.Visible := MatchText(F.Node.NodeName, ['desc', 'Notes', 'description']) or
          F.Value.Contains(#10) or F.Value.Contains(#13);
        Editor.ValueEdit.Visible := not Editor.ValueMemo.Visible;
        Editor.ValueMemo.Tag := I;
        Editor.ValueEdit.Tag := I;
        Editor.Text := F.Value;
        Editor.ValueMemo.OnChangeTracking := ValueChanged;
        Editor.ValueEdit.OnChangeTracking := ValueChanged;
        ValidateEditor(Editor);
        Editor.MediaCommands.Visible := F.IsMedia;
        Editor.MediaNote.Visible := F.IsMedia;
        Editor.MediaImage.Visible := False;
        if F.IsMedia then
        begin
          Editor.ReplaceMediaButton.Text := L('Выбрать файл…');
          Editor.ClearMediaButton.Text := L('Очистить');
          Editor.ReplaceMediaButton.Tag := I;
          Editor.ClearMediaButton.Tag := I;
          Editor.ReplaceMediaButton.OnClick := MediaClick;
          Editor.ClearMediaButton.OnClick := MediaClick;
          UpdateMedia(Editor);
        end;
      finally
        Editor.EndUpdate
      end;
    end;
    UpdateFieldsHeight;
  finally
    FieldsContent.EndUpdate;
    FLoading := False
  end;
  FieldsScroll.RealignContent;
  FieldsScroll.ViewportPosition := PointF(0, 0);
end;

procedure TFormGameLibrary.UpdateFieldsHeight;
var
  Editor: TGameFieldEditor;
  H, Total: Single;
begin
  Total := 0;
  for Editor in FEditors do
  begin
    if Editor.ValueMemo.Visible then
      H := Editor.ValueMemo.Height
    else
      H := Editor.ValueEdit.Height;
    Editor.InputControlFrame.Height := H;
    if Editor.ErrorLabel.Visible then
      H := H + Editor.ErrorLabel.Height;
    if Editor.HelpMemo.Visible then
      H := Max(H, 128);
    Editor.InputFrame.Height := H;
    if Editor.MediaCommands.Visible then
      H := H + Editor.MediaCommands.Height + Editor.MediaNote.Height;
    if Editor.MediaImage.Visible then
      H := Max(H, 140);
    Editor.Height := H;
    Total := Total + H + Editor.Margins.Top + Editor.Margins.Bottom;
  end;
  FieldsContent.Height := Total;
end;

procedure TFormGameLibrary.ValueChanged(Sender: TObject);
var
  I: Integer;
  Editor: TGameFieldEditor;
begin
  if FLoading then
    Exit;
  I := TControl(Sender).Tag;
  if (I < 0) or (I >= FEditors.Count) then
    Exit;
  Editor := FEditors[I];
  Editor.Field.SetValue(Editor.Text);
  FDirty := True;
  if MatchText(Editor.Field.Caption, ['name', 'Title', '@name']) then
    if Editor.Text.Trim <> '' then
      GameTitleLabel.Text := Editor.Text
    else
      GameTitleLabel.Text := TPath.GetFileNameWithoutExtension(FLibrary.Games[FSelected].RomPath);
  ValidateEditor(Editor);
  if Editor.Field.IsMedia then
  begin
    UpdateMedia(Editor);
  end;
  UpdateFieldsHeight;
  UpdateButtons;
end;

procedure TFormGameLibrary.XMLChanged(Sender: TObject);
begin
  if FLoading then
    Exit;
  FXMLDirty := True;
  FDirty := True;
  UpdateButtons;
end;

procedure TFormGameLibrary.ApplyXML;
begin
  if not FXMLDirty then
    Exit;
  FDraft := ParseGameXML(XMLMemo.Text, FLibrary.Kind);
  FXMLDirty := False;
  BuildFields;
end;

procedure TFormGameLibrary.EditorTabClick(Sender: TObject);
begin
  if Sender = FieldsTabButton then
    EditorTabs.ActiveTab := FieldsTab
  else
    EditorTabs.ActiveTab := XMLTab;
  FieldsTabLine.Visible := EditorTabs.ActiveTab = FieldsTab;
  XMLTabLine.Visible := EditorTabs.ActiveTab = XMLTab;
end;

procedure TFormGameLibrary.TabChanged(Sender: TObject);
begin
  FieldsTabLine.Visible := EditorTabs.ActiveTab = FieldsTab;
  XMLTabLine.Visible := EditorTabs.ActiveTab = XMLTab;
  if FLoading or (FDraft = nil) then
    Exit;
  if EditorTabs.ActiveTab = XMLTab then
  begin
    FLoading := True;
    try
      XMLMemo.Text := FDraft.DocumentElement.XML
    finally
      FLoading := False
    end;
  end
  else
  try
    ApplyXML
  except
    on E: Exception do
    begin
      FLoading := True;
      try
        EditorTabs.ActiveTab := XMLTab
      finally
        FLoading := False
      end;
      ReportError(E);
    end;
  end;
end;

procedure TFormGameLibrary.UpdateMedia(Editor: TGameFieldEditor);
var
  Path: string;
begin
  // Cancel before clearing/reusing the bitmap: an older request may already be queued.
  Editor.MediaImage.Bitmap.RemoveCallback(Editor.MediaImage);
  Editor.PreviewLoading := False;
  Editor.MediaImage.Bitmap.SetSize(0, 0);
  Editor.MediaImage.Visible := False;
  Editor.MediaNote.Text := '';
  try
    Path := FLibrary.MediaPath(Editor.Field.Value)
  except
    on E: Exception do
    begin
      Editor.MediaNote.Text := L('Некорректный путь к файлу.');
      Exit;
    end;
  end;
  if Path = '' then
    Editor.MediaNote.Text := L('Медиа не задано')
  else if MatchText(TPath.GetExtension(Path), ['.png', '.jpg', '.jpeg', '.bmp', '.gif']) then
  begin
    // Reserve preview space while loading so successful completion does not move fields.
    Editor.MediaImage.Visible := True;
    Editor.MediaNote.Text := L('Загрузка превью…');
    Editor.PreviewLoading := True;
    Editor.MediaImage.Bitmap.LoadFromFileAsync(Editor.MediaImage, Path, 208, 280,
      procedure(Success: Boolean)
      begin
        Editor.PreviewLoading := False;
        Editor.MediaImage.Visible := Success;
        if Success then
          Editor.MediaNote.Text := ''
        else
          Editor.MediaNote.Text := L('Не удалось загрузить превью: файл отсутствует или формат не поддерживается.');
        UpdateFieldsHeight;
      end);
  end
  else if not TFile.Exists(Path) then
    Editor.MediaNote.Text := L('Файл медиа не найден')
  else
    Editor.MediaNote.Text := TPath.GetFileName(Path);
end;

procedure TFormGameLibrary.UpdateButtons;
var
  HasGame: Boolean;
  Errors: Integer;
  Editor: TGameFieldEditor;
begin
  HasGame := FSelected >= 0;
  Errors := 0;
  if not FXMLDirty then
    for Editor in FEditors do
      if Editor.ErrorText <> '' then
        Inc(Errors);
  EditorTabs.Enabled := HasGame;
  FieldsTabButton.Enabled := HasGame;
  XMLTabButton.Enabled := HasGame;
  FieldsTabLine.Visible := EditorTabs.ActiveTab = FieldsTab;
  XMLTabLine.Visible := EditorTabs.ActiveTab = XMLTab;
  SaveButton.Enabled := HasGame and FDirty and (Errors = 0);
  ScrapeButton.Enabled := HasGame;
  StatusLabel.StyledSettings := StatusLabel.StyledSettings - [TStyledSetting.FontColor];
  if Errors > 0 then
  begin
    StatusLabel.TextSettings.FontColor := $FFFF8E8E;
    StatusLabel.Text := L('Исправьте ошибки перед сохранением: %d.', [Errors]);
  end
  else
  begin
    StatusLabel.TextSettings.FontColor := $FFBDBDBD;
    if FDirty then
      StatusLabel.Text := L('Есть несохранённые изменения');
  end;
end;

procedure TFormGameLibrary.MediaClick(Sender: TObject);
var
  I: Integer;
  Editor: TGameFieldEditor;
begin
  I := TControl(Sender).Tag;
  if (I < 0) or (I >= FEditors.Count) then
    Exit;
  Editor := FEditors[I];
  if Sender = Editor.ClearMediaButton then
    Editor.Text := ''
  else
  begin
    MediaDialog.Filter := L('Все файлы') + '|*.*';
    if not MediaDialog.Execute then
      Exit;
    try
      Editor.Text := FLibrary.MediaReference(MediaDialog.FileName)
    except
      on E: Exception do
        ReportError(E)
    end;
  end;
  UpdateMedia(Editor);
  UpdateFieldsHeight;
end;

procedure TFormGameLibrary.InfoClick(Sender: TObject);
var
  I: Integer;
  Editor: TGameFieldEditor;
begin
  I := TControl(Sender).Tag;
  if (I < 0) or (I >= FEditors.Count) then
    Exit;
  Editor := FEditors[I];
  if Editor.HelpMemo = nil then
    Exit;
  Editor.HelpMemo.Visible := not Editor.HelpMemo.Visible;
  Editor.InfoButton.IsPressed := Editor.HelpMemo.Visible;
  UpdateFieldsHeight;
end;

procedure TFormGameLibrary.ValidateEditor(Editor: TGameFieldEditor);
begin
  FLibrary.ValidateField(Editor.Field, Editor.ErrorText);
  Editor.ErrorLabel.Text := Editor.ErrorText;
  Editor.ErrorLabel.Visible := Editor.ErrorText <> '';
  Editor.ErrorFrame.Visible := Editor.ErrorText <> '';
end;

function TFormGameLibrary.ValidateDraft: Boolean;
var
  Errors: TStringList;
  Editor, FirstError: TGameFieldEditor;
begin
  Errors := TStringList.Create;
  try
    Result := FLibrary.Validate(FDraft, Errors);
    FirstError := nil;
    for Editor in FEditors do
    begin
      ValidateEditor(Editor);
      if (FirstError = nil) and (Editor.ErrorText <> '') then
        FirstError := Editor;
    end;
    UpdateFieldsHeight;
    UpdateButtons;
    if not Result then
    begin
      EditorTabs.ActiveTab := FieldsTab;
      FieldsScroll.RealignContent;
      if FirstError <> nil then
      begin
        if FirstError.Position.Y < FieldsScroll.ViewportPosition.Y then
          FieldsScroll.ViewportPosition := PointF(0, FirstError.Position.Y)
        else if FirstError.Position.Y + FirstError.Height > FieldsScroll.ViewportPosition.Y + FieldsScroll.ViewportRect.Height then
          FieldsScroll.ViewportPosition := PointF(0,
            Max(FirstError.Position.Y, FirstError.Position.Y + FirstError.Height - FieldsScroll.ViewportRect.Height));
        if FirstError.ValueEdit.Visible then
          FirstError.ValueEdit.SetFocus
        else
          FirstError.ValueMemo.SetFocus;
      end;
      StatusLabel.Text := L('Исправьте ошибки перед сохранением: %d.', [Errors.Count]);
      if FirstError = nil then
        StatusLabel.Text := Errors[0];
    end;
  finally
    Errors.Free
  end;
end;

function TFormGameLibrary.SaveGame: Boolean;
begin
  ApplyXML;
  Result := ValidateDraft;
  if not Result then
    Exit;
  FLibrary.Save(FSelected, FDraft);
  FDirty := False;
  BuildGames;
  UpdateButtons;
  StatusLabel.Text := L('Игра сохранена. Резервная копия создана рядом с библиотекой.');
end;

procedure TFormGameLibrary.SaveClick(Sender: TObject);
begin
  try
    SaveGame
  except
    on E: Exception do
      ReportError(E)
  end;
end;

function TFormGameLibrary.ResolveUnsaved: Boolean;
var
  Answer: TModalResult;
begin
  Result := True;
  if not FDirty then
    Exit;
  Answer := TDialogServiceSync.MessageDialog(L('Сохранить изменения выбранной игры?'),
    TMsgDlgType.mtConfirmation, [TMsgDlgBtn.mbYes, TMsgDlgBtn.mbNo, TMsgDlgBtn.mbCancel],
    TMsgDlgBtn.mbYes, 0);
  Result := Answer <> mrCancel;
  if Answer = mrYes then
  try
    Result := SaveGame
  except
    on E: Exception do
    begin
      ReportError(E);
      Result := False
    end
  end;
end;

procedure TFormGameLibrary.ScrapeClick(Sender: TObject);
begin
  if (FSelected < 0) or not ResolveUnsaved then
    Exit;
  FRequestedRom := FLibrary.Games[FSelected].RomPath;
  if not (TFile.Exists(FRequestedRom) or TDirectory.Exists(FRequestedRom)) then
  begin
    FRequestedRom := '';
    StatusLabel.Text := L('ROM выбранной игры не найден');
    Exit;
  end;
  FDirty := False;
  ModalResult := mrOK;
end;

procedure TFormGameLibrary.ReportError(E: Exception);
begin
  StatusLabel.Text := E.Message;
  TDialogServiceSync.ShowMessage(E.Message);
end;

procedure TFormGameLibrary.FormCloseQuery(Sender: TObject; var CanClose: Boolean);
begin
  CanClose := ResolveUnsaved
end;

procedure TFormGameLibrary.CloseClick(Sender: TObject);
begin
  Close
end;

initialization
  RegisterFmxClasses([TGameFieldEditor]);

end.

