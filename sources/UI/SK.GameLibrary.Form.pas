unit SK.GameLibrary.Form;

interface

uses
  SK.UI.FieldEditor, System.SysUtils, System.Classes, System.JSON,
  System.Generics.Collections, System.Types, System.UITypes, Xml.XMLIntf,
  FMX.Types, FMX.Forms, FMX.Controls, FMX.Controls.Presentation, FMX.Layouts,
  FMX.StdCtrls, FMX.Edit, FMX.ListBox, FMX.Memo, FMX.Memo.Types, FMX.ScrollBox,
  FMX.Objects, FMX.TabControl, FMX.Dialogs, SK.GameLibrary, FMX.Graphics, SK.Engine, Player.FMX;

type
  TGameFieldEditor = SK.UI.FieldEditor.TGameFieldEditor;

  TFormGameLibrary = class(TForm)
    LibraryRoot: TLayout;
    Surface: TRectangle;
    RootLayout: TLayout;
    Header: TLayout;
    TitleLabel, CountLabel, PlatformLabel, GameTitleLabel, GamePlatformLabel: TLabel;
    EditorPanel, TabActions: TLayout;
    CommandButtons: TGridPanelLayout;
    SpeedButtonFieldsTab, SpeedButtonXMLTab, SpeedButtonOverviewTab: TSpeedButton;
    RectangleOverviewTabLine: TRectangle;
    TabItemOverview: TTabItem;
    VertScrollBoxOverview: TVertScrollBox;
    LayoutOverviewContent, LayoutOverviewTop, LayoutOverviewMedia: TLayout;
    LayoutOverviewPicture, LayoutOverviewBox, LayoutVideoStage, LayoutVideoTransport: TLayout;
    LayoutVideoSurface, LayoutVideoOverlay: TLayout;
    RectangleVideoTransportBackground: TRectangle;
    GridPanelLayoutOverviewTop, GridPanelLayoutOverviewDetails: TGridPanelLayout;
    LayoutOverviewMediaTabs, LayoutOverviewFlags, LayoutVideoButtons: TLayout;
    LayoutOverviewBoxOverlay, LayoutOverviewBoxBottom: TLayout;
    LayoutOverviewName, LayoutOverviewDate, LayoutOverviewPlayers, LayoutOverviewRating: TLayout;
    LayoutOverviewPublisher, LayoutOverviewDeveloper, LayoutOverviewGenre: TLayout;
    LayoutOverviewRom, LayoutOverviewRegion, LayoutOverviewPlayCount, LayoutOverviewLastPlayed: TLayout;
    LabelOverviewName, LabelOverviewDate, LabelOverviewPlayers, LabelOverviewRating: TLabel;
    LabelOverviewPublisher, LabelOverviewDeveloper, LabelOverviewGenre: TLabel;
    LabelOverviewRom, LabelOverviewRegion, LabelOverviewPlayCount, LabelOverviewLastPlayed: TLabel;
    SpeedButtonPicture, SpeedButtonVideo: TSpeedButton;
    RectanglePictureLine, RectangleVideoLine: TRectangle;
    ImageOverviewPicture, ImageOverviewBox: TImage;
    LabelOverviewMediaStatus, LabelVideoTime: TLabel;
    MemoOverviewDescription: TMemo;
    EditOverviewName, EditOverviewDate, EditOverviewPlayers, EditOverviewRating: TEdit;
    EditOverviewPublisher, EditOverviewDeveloper, EditOverviewGenre: TEdit;
    EditOverviewRom, EditOverviewRegion, EditOverviewPlayCount, EditOverviewLastPlayed: TEdit;
    CheckBoxOverviewFavorite, CheckBoxOverviewHidden, CheckBoxOverviewKid: TCheckBox;
    ButtonVideoPlayback: TButton;
    LayoutVideoPlaybackIcon: TLayout;
    PathVideoPlay, PathVideoPause: FMX.Objects.TPath;
    TrackBarVideoSeek: TTrackBar;
    FieldsTabLine, XMLTabLine: TRectangle;
    HeaderIcon: FMX.Objects.TPath;
    FooterDivider, LibraryDivider: TRectangle;
    FieldRowTemplate: TLayout;
    Commands: TLayout;
    SaveButton, ScrapeButton, CloseButton: TButton;
    Body: TLayout;
    GamesPanel: TLayout;
    SearchEdit: TEdit;
    GameList: TListBox;
    EditorTabs: TTabControl;
    FieldsTab, XMLTab: TTabItem;
    FieldsContent: TLayout;
    FieldsScroll: TVertScrollBox;
    StatusLabel: TLabel;
    ScrapeProgressLayout: TLayout;
    ScrapeProgress: TProgressBar;
    ScrapeActivity: TAniIndicator;
    ScrapeTimer: TTimer;
    LibraryLoadTimer: TTimer;
    XMLMemo: TMemo;
    MediaDialog: TOpenDialog;
    procedure OverviewChanged(Sender: TObject);
    procedure VideoPointerChanged(Sender: TObject);
    procedure OverviewTabClick(Sender: TObject);
    procedure OverviewMediaClick(Sender: TObject);
    procedure VideoPlaybackClick(Sender: TObject);
    procedure VideoSeekChanged(Sender: TObject);
    procedure LibraryLoadTimerTimer(Sender: TObject);
    procedure GameListViewportChanged(Sender: TObject; const OldViewportPosition,
      NewViewportPosition: TPointF; const ContentSizeChanged: Boolean);
    procedure GameListResized(Sender: TObject);
    procedure ScrapeTimerTimer(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure FormCloseQuery(Sender: TObject; var CanClose: Boolean);
    procedure SearchChanged(Sender: TObject);
    procedure GameChanged(Sender: TObject);
    procedure ValueChanged(Sender: TObject);
    procedure XMLChanged(Sender: TObject);
    procedure TabChanged(Sender: TObject);
    procedure FieldsTabClick(Sender: TObject);
    procedure XMLTabClick(Sender: TObject);
    procedure SaveClick(Sender: TObject);
    procedure ScrapeClick(Sender: TObject);
    procedure ReplaceMediaClick(Sender: TObject);
    procedure ClearMediaClick(Sender: TObject);
    procedure InfoClick(Sender: TObject);
    procedure CloseClick(Sender: TObject);
  private
    FPlayer: TPlayerControl;
    FVideoPath, FOpenedVideoPath: string;
    FVideoSelected, FUpdatingVideo: Boolean;
    FOnReturn: TNotifyEvent;
    FLibrary: TGameLibrary;
    FLibraryLoad: IGameLibraryLoad;
    FLibraryLoading: Boolean;
    FBuildIndex: Integer;
    FDraft: IXMLDocument;
    FFields: TObjectList<TLibraryField>;
    FEditors: TList<TGameFieldEditor>;
    FSelected: Integer;
    FLoading, FDirty, FXMLDirty: Boolean;
    FUpdatingFieldsHeight: Boolean;
    FRequestedRom, FPlatformTitle: string;
    FGameItems: TDictionary<Integer, TListBoxItem>;
    FVisibleGameItems: TList<TListBoxItem>;
    FSearchFilter: string;
    FFirstCover, FLastCover: Integer;
    FScrapeWorker: TScrapeWorker;
    FOnCreateScrapeWorker: TFunc<string, TScrapeWorker>;
    procedure SyncTabs;
    procedure ClearOverview;
    procedure UpdateOverviewFields;
    procedure SyncDraftXML;
    function OverviewFieldName(Control: TComponent): string;
    function OverviewDateValue(const Value, FieldName: string): string;
    procedure SetOverviewMediaStatus(const Text: string);
    procedure UpdatePlaybackButton;
    procedure UpdateVideoOverlay;
    procedure UpdateOverview;
    procedure UpdateOverviewMedia;
    procedure CloseOverviewVideo;
    procedure PlayerChanged(Sender: TObject);
    procedure PlayerError(Sender: TObject; const MessageText: string);
    function OverviewValue(const Names: array of string): string;
    function OverviewMediaPath(const Names: array of string): string;
    procedure LoadOverviewImage(Image: TImage; const Names: array of string);
    procedure ReleaseFieldEditors;
    procedure ReleaseGameItems;
    procedure ReloadScrapedGame;
    procedure BuildGames;
    procedure FilterGames;
    procedure UpdateGameCard(Index: Integer);
    procedure UpdateVisibleCovers;
    procedure RequestGameCover(Item: TListBoxItem);
    procedure LoadGameCover(Picture: TImage; const Paths: TArray<string>; Index: Integer);
    procedure BuildFields;
    procedure LoadGame(Index: Integer);
    procedure UpdateMedia(Editor: TGameFieldEditor);
    procedure UpdateFieldsHeight;
    procedure HelpLabelResize(Sender: TObject);
    procedure UpdateButtons;
    procedure ApplyXML;
    function SaveGame: Boolean;
    procedure ValidateEditor(Editor: TGameFieldEditor);
    function ResolveUnsaved: Boolean;
    procedure ReportError(E: Exception);
  public
    procedure AttachTo(Host: TControl);
    property OnReturn: TNotifyEvent read FOnReturn write FOnReturn;
    procedure LoadPlatform(Config: TJSONObject; const PlatformTitle: string);
    function FieldEditor(const FieldName: string): TGameFieldEditor;
    function FieldCount: Integer;
    function ValidateDraft: Boolean;
    property LibraryLoading: Boolean read FLibraryLoading;
    property RequestedRom: string read FRequestedRom;
    property OnCreateScrapeWorker: TFunc<string, TScrapeWorker>
      read FOnCreateScrapeWorker write FOnCreateScrapeWorker;
  end;

implementation

uses
  System.IOUtils, SK.Main, System.StrUtils, Xml.XMLDoc, FMX.DialogService.Sync,
  SK.Platform, SK.Locale, System.Generics.Defaults, System.Math, HGM.FMX.Image, FMX.BehaviorManager,
  SK.UI.Scraping, Player.Types, System.DateUtils, System.Variants, System.TypInfo;

{$R *.fmx}

procedure TFormGameLibrary.FormCreate(Sender: TObject);
var
  I: Integer;
begin
  // Memo exposes ScrollAnimation only at runtime, including the field template.
  for I := 0 to ComponentCount - 1 do
    if Components[I] is TMemo then
      TMemo(Components[I]).ScrollAnimation := TBehaviorBoolean.True;
  FSelected := -1;
  FLastCover := -1;
  FGameItems := TDictionary<Integer, TListBoxItem>.Create;
  FVisibleGameItems := TList<TListBoxItem>.Create;
  FEditors := TList<TGameFieldEditor>.Create;
  FFields := TObjectList<TLibraryField>.Create(True);
  FPlayer := TPlayerControl.Create(Self);
  FPlayer.Name := 'PlayerControlOverview';
  FPlayer.Parent := LayoutVideoSurface;
  FPlayer.HitTest := False;
  FPlayer.Align := TAlignLayout.Client;
  FPlayer.OnPositionChanged := PlayerChanged;
  FPlayer.OnError := PlayerError;
  ApplyLocale(Self);
  UpdateButtons;
end;

procedure TFormGameLibrary.FormDestroy(Sender: TObject);
begin
  FPlayer.OnPositionChanged := nil;
  FPlayer.OnError := nil;
  CloseOverviewVideo;
  ImageOverviewPicture.Bitmap.RemoveCallback(ImageOverviewPicture);
  ImageOverviewBox.Bitmap.RemoveCallback(ImageOverviewBox);
  FOnReturn := nil;
  LibraryLoadTimer.Enabled := False;
  if FLibraryLoad <> nil then
    FLibraryLoad.Cancel;
  FLibraryLoad := nil;
  ScrapeTimer.Enabled := False;
  FScrapeWorker.Free;
  FOnCreateScrapeWorker := nil;
  FLoading := True;
  FVisibleGameItems.Free;
  FGameItems.Free;
  FieldsContent.DeleteChildren;
  GameList.Clear;
  FEditors.Free;
  FFields.Free;
  FDraft := nil;
  FLibrary.Free;
end;

procedure TFormGameLibrary.LoadPlatform(Config: TJSONObject; const PlatformTitle: string);
begin
  if FLibraryLoad <> nil then
    FLibraryLoad.Cancel;
  FLibraryLoad := nil;
  LibraryLoadTimer.Enabled := False;
  FLoading := True;
  try
    try
      CloseOverviewVideo;
      ImageOverviewPicture.Bitmap.RemoveCallback(ImageOverviewPicture);
      ImageOverviewBox.Bitmap.RemoveCallback(ImageOverviewBox);
      FSelected := -1;
      FDirty := False;
      FXMLDirty := False;
      FDraft := nil;
      ClearOverview;
      ReleaseFieldEditors;
      FEditors.Clear;
      FFields.Clear;
      FGameItems.Clear;
      FVisibleGameItems.Clear;
      ReleaseGameItems;
      FreeAndNil(FLibrary);
      FBuildIndex := 0;
      FFirstCover := 0;
      FLastCover := -1;
      FSearchFilter := #0;
      Caption := L('Библиотека игр') + ' · ' + PlatformTitle;
      FPlatformTitle := PlatformTitle;
      PlatformLabel.Text := PlatformTitle;
      GamePlatformLabel.Text := PlatformTitle;
      GameTitleLabel.Text := '';
      CountLabel.Text := L('Загрузка…');
      FLibraryLoading := True;
      UpdateButtons;
      ScrapeProgress.Value := 0;
      ScrapeProgress.Max := 1;
      StatusLabel.Text := L('Загрузка библиотеки…');
      FLibraryLoad := LoadGameLibraryAsync(Config);
      LibraryLoadTimer.Enabled := True;
    except
      FLibraryLoading := False;
      UpdateButtons;
      raise;
    end;
  finally
    FLoading := False;
  end;
end;

procedure TFormGameLibrary.LibraryLoadTimerTimer(Sender: TObject);
var
  Data: TGameLibrary;
  Error: string;
begin
  if not FLibraryLoading then
    Exit;
  try
    if FLibraryLoad <> nil then
    begin
      if not FLibraryLoad.Poll(Data, Error) then
        Exit;
      FLibraryLoad := nil;
      if Error <> '' then
        raise Exception.Create(Error);
      if Data = nil then
        raise EAbort.Create('');
      FLibrary := Data;
      ScrapeProgress.Max := Max(1, FLibrary.Games.Count);
    end;
    BuildGames;
    CountLabel.Text := L('%d / %d', [FBuildIndex, FLibrary.Games.Count]);
    ScrapeProgress.Value := FBuildIndex;
    if FBuildIndex < FLibrary.Games.Count then
      Exit;
    LibraryLoadTimer.Enabled := False;
    FLibraryLoading := False;
    FilterGames;
    UpdateButtons;
    StatusLabel.Text := FLibrary.FileName;
    if FVisibleGameItems.Count > 0 then
      GameList.ItemIndex := FVisibleGameItems[0].Index;
  except
    on E: Exception do
    begin
      LibraryLoadTimer.Enabled := False;
      FLibraryLoading := False;
      UpdateButtons;
      CountLabel.Text := L('Не удалось загрузить библиотеку');
      StatusLabel.Text := E.Message;
    end;
  end;
end;

procedure TFormGameLibrary.BuildGames;
var
  I, BatchCount: Integer;
  Started: UInt64;
  Text: string;
  Item: TListBoxItem;
  Picture: TImage;
  Labels: TLayout;
  LabelText: TLabel;
begin
  FLoading := True;
  GameList.BeginUpdate;
  try
    Started := TThread.GetTickCount64;
    BatchCount := 0;
    while FBuildIndex < FLibrary.Games.Count do
    begin
      I := FBuildIndex;
      Text := FLibrary.Title(I);
      Item := TListBoxItem.Create(GameList);
      Item.Parent := GameList;
      Item.Tag := I;
      Item.TagString := Text.ToLower + #10 + FLibrary.Games[I].RomPath.ToLower;
      FGameItems.Add(I, Item);
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
      Picture.Visible := False;
      Labels := TLayout.Create(Item);
      Labels.Parent := Item;
      Labels.Align := TAlignLayout.Client;
      Labels.HitTest := False;
      LabelText := TLabel.Create(Item);
      LabelText.Parent := Labels;
      LabelText.Align := TAlignLayout.Top;
      LabelText.Height := 30;
      LabelText.Name := 'GameName';
      LabelText.Text := Text;
      LabelText.HitTest := False;
      LabelText.TextSettings.Trimming := TTextTrimming.Character;
      LabelText.TextSettings.WordWrap := False;
      LabelText := TLabel.Create(Item);
      LabelText.Parent := Labels;
      LabelText.Align := TAlignLayout.Top;
      LabelText.Height := 24;
      LabelText.Name := 'GameRom';
      LabelText.Text := TPath.GetFileName(FLibrary.Games[I].RomPath);
      LabelText.Opacity := 0.7;
      LabelText.HitTest := False;
      LabelText.TextSettings.WordWrap := False;
      LabelText.TextSettings.Trimming := TTextTrimming.Character;
      Inc(FBuildIndex);
      Inc(BatchCount);
      // Bound both work and time per tick so paint, input and close events can run.
      if (BatchCount >= 64) or (TThread.GetTickCount64 - Started >= 8) then
        Break;
    end;
  finally
    GameList.EndUpdate;
    FLoading := False
  end;
end;

procedure TFormGameLibrary.FilterGames;
var
  Filter: string;
  Item, SelectedItem: TListBoxItem;
  I: Integer;
  Matches: Boolean;
begin
  Filter := SearchEdit.Text.Trim.ToLower;
  if Filter = FSearchFilter then
    Exit;
  FLoading := True;
  GameList.BeginUpdate;
  try
    FVisibleGameItems.Clear;
    // Keep existing preview requests and decoded bitmaps when changing the filter.
    FFirstCover := 0;
    FLastCover := -1;
    for I := 0 to GameList.Count - 1 do
    begin
      Item := GameList.ListItems[I];
      Matches := (Filter = '') or Item.TagString.Contains(Filter);
      if Item.Visible <> Matches then
        Item.Visible := Matches;
      if Matches then
        FVisibleGameItems.Add(Item);
    end;
    if FGameItems.TryGetValue(FSelected, SelectedItem) and SelectedItem.Visible then
      GameList.ItemIndex := SelectedItem.Index
    else
      GameList.ItemIndex := -1;
    CountLabel.Text := L('%d игр · показано %d',
      [FLibrary.Games.Count, FVisibleGameItems.Count]);
    FSearchFilter := Filter;
  finally
    GameList.EndUpdate;
    GameList.ViewportPosition := PointF(0, 0);
    FLoading := False;
  end;
  UpdateVisibleCovers;
end;

procedure TFormGameLibrary.UpdateGameCard(Index: Integer);
var
  Item: TListBoxItem;
  Picture: TImage;
begin
  if not FGameItems.TryGetValue(Index, Item) then
    Exit;
  TLabel(Item.FindComponent('GameName')).Text := FLibrary.Title(Index);
  Item.TagString := FLibrary.Title(Index).ToLower + #10 +
    FLibrary.Games[Index].RomPath.ToLower;
  FSearchFilter := #0;
  TLabel(Item.FindComponent('GameRom')).Text := TPath.GetFileName(FLibrary.Games[Index].RomPath);
  Picture := TImage(Item.FindComponent('GameCover'));
  Picture.Bitmap.RemoveCallback(Picture);
  Picture.Bitmap.SetSize(0, 0);
  Picture.Visible := False;
  Picture.Tag := 0;
  UpdateVisibleCovers;
end;

procedure TFormGameLibrary.RequestGameCover(Item: TListBoxItem);
var
  Picture: TImage;
  Node: IXMLNode;
  FieldName, Path: string;
  Paths: TArray<string>;
begin
  Picture := TImage(Item.FindComponent('GameCover'));
  if Picture.Tag <> 0 then
    Exit;
  Picture.Tag := 1;
  Paths := nil;
  for FieldName in ['box', 'image', 'thumbnail', 'ImagePath', 'BoxFrontImagePath'] do
  begin
    Node := FLibrary.Games[Item.Tag].Node.ChildNodes.FindNode(FieldName);
    if (Node = nil) or (Node.Text.Trim = '') then
      Continue;
    try
      Path := FLibrary.MediaPath(Node.Text);
      if (Path <> '') and not MatchText(Path, Paths) then
        Paths := Paths + [Path];
    except
      // Skip malformed media paths and try the remaining cover fields.
    end;
  end;
  LoadGameCover(Picture, Paths, 0);
end;

procedure TFormGameLibrary.UpdateVisibleCovers;
var
  First, Last, I: Integer;
  Picture: TImage;
begin
  if FLoading or FLibraryLoading or (FLibrary = nil) or (FVisibleGameItems.Count = 0) then
    Exit;
  // All rows have the same height. Include one neighboring row on either side.
  First := Max(0, Floor(GameList.ViewportPosition.Y / 86) - 1);
  Last := Min(FVisibleGameItems.Count - 1,
    Ceil((GameList.ViewportPosition.Y + GameList.Height) / 86));
  for I := FFirstCover to FLastCover do
    if (I < FVisibleGameItems.Count) and ((I < First) or (I > Last)) then
    begin
      Picture := TImage(FVisibleGameItems[I].FindComponent('GameCover'));
      if Picture.Tag = 1 then
      begin
        Picture.Bitmap.RemoveCallback(Picture);
        Picture.Tag := 0;
      end;
    end;
  FFirstCover := First;
  FLastCover := Last;
  for I := First to Last do
    RequestGameCover(FVisibleGameItems[I]);
end;

procedure TFormGameLibrary.GameListViewportChanged(Sender: TObject;
  const OldViewportPosition, NewViewportPosition: TPointF; const ContentSizeChanged: Boolean);
begin
  UpdateVisibleCovers;
end;

procedure TFormGameLibrary.GameListResized(Sender: TObject);
begin
  UpdateVisibleCovers;
end;

procedure TFormGameLibrary.LoadGameCover(Picture: TImage; const Paths: TArray<string>; Index: Integer);
begin
  if Index >= Length(Paths) then
  begin
    Picture.Tag := 2;
    Exit;
  end;
  // Picture owns the request lifetime; filtering preserves it and its bitmap.
  Picture.Bitmap.LoadFromFileAsync(Picture, Paths[Index], 48, 70,
    procedure(Success: Boolean)
    begin
      if Success then
      begin
        Picture.Tag := 2;
        Picture.Visible := True;
      end
      else
        LoadGameCover(Picture, Paths, Index + 1);
    end);
end;

procedure TFormGameLibrary.SearchChanged(Sender: TObject);
begin
  if FLoading or FLibraryLoading or (FLibrary = nil) then
    Exit;
  FilterGames;
end;

procedure TFormGameLibrary.LoadGame(Index: Integer);
begin
  CloseOverviewVideo;
  FSelected := Index;
  GameTitleLabel.Text := FLibrary.Title(Index);
  FDraft := FLibrary.Draft(Index);
  FDirty := False;
  FXMLDirty := False;
  FLoading := True;
  try
    XMLMemo.Text := FDraft.DocumentElement.XML;
  finally
    FLoading := False
  end;
  BuildFields;
  UpdateOverview;
  UpdateButtons;
  StatusLabel.Text := FLibrary.Games[Index].RomPath;
end;

procedure TFormGameLibrary.GameChanged(Sender: TObject);
var
  Index: Integer;
  Item: TListBoxItem;
begin
  if FLoading or FLibraryLoading or (GameList.Selected = nil) then
    Exit;
  Index := GameList.Selected.Tag;
  if Index = FSelected then
    Exit;
  if not ResolveUnsaved then
  begin
    FLoading := True;
    try
      if FGameItems.TryGetValue(FSelected, Item) then
        GameList.ItemIndex := Item.Index;
    finally
      FLoading := False;
    end;
    Exit
  end;
  LoadGame(Index);
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
    ReleaseFieldEditors;
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
      Editor := TGameFieldEditor.CreateFromTemplate(FieldsContent, FieldRowTemplate);
      Editor.Parent := FieldsContent;
      Editor.Align := TAlignLayout.Top;
      Editor.Visible := True;
      Editor.Field := F;
      FEditors.Add(Editor);
      Editor.BeginUpdate;
      try
        Editor.CaptionLabel.Text := FieldCaption(F.Caption);
        Editor.HelpText := F.Help(FLibrary.Kind);
        Editor.CaptionLabel.Hint := Editor.HelpText;
        Editor.CaptionLabel.ShowHint := Editor.HelpText <> '';
        Editor.InfoButton.Visible := Editor.HelpText <> '';
        Editor.InfoButton.Tag := I;
        Editor.InfoButton.Hint := L('hint.field_help');
        Editor.InfoButton.OnClick := InfoClick;
        Editor.HelpLabel.Text := Editor.HelpText;
        Editor.HelpLabel.Visible := False;
        Editor.HelpLabel.OnResize := HelpLabelResize;
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
          Editor.ReplaceMediaButton.OnClick := ReplaceMediaClick;
          Editor.ClearMediaButton.OnClick := ClearMediaClick;
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
  if FUpdatingFieldsHeight or (FEditors = nil) then
    Exit;
  FUpdatingFieldsHeight := True;
  try
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
      if Editor.HelpLabel.Visible then
        H := H + Editor.HelpLabel.Height + Editor.HelpLabel.Margins.Top +
          Editor.HelpLabel.Margins.Bottom;
      Editor.InputFrame.Height := H;
      if Editor.MediaCommands.Visible then
        H := H + Editor.MediaCommands.Height + Editor.MediaNote.Height;
      if Editor.MediaImage.Visible then
        H := Max(H, 140);
      Editor.Height := H;
      Total := Total + H + Editor.Margins.Top + Editor.Margins.Bottom;
    end;
    FieldsContent.Height := Total;
  finally
    FUpdatingFieldsHeight := False;
  end;
end;

procedure TFormGameLibrary.HelpLabelResize(Sender: TObject);
begin
  if not FLoading then
    UpdateFieldsHeight;
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
  SyncDraftXML;
  UpdateOverviewFields;
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
  UpdateOverviewFields;
  UpdateButtons;
end;

procedure TFormGameLibrary.SyncDraftXML;
var
  WasLoading: Boolean;
begin
  if (FDraft = nil) or FXMLDirty then
    Exit;
  WasLoading := FLoading;
  FLoading := True;
  try
    XMLMemo.Text := FDraft.DocumentElement.XML;
  finally
    FLoading := WasLoading;
  end;
end;

function TFormGameLibrary.OverviewFieldName(Control: TComponent): string;
var
  Names: TArray<string>;
  Name: string;
  Root: IXMLNode;
begin
  Result := '';
  if Control = EditOverviewName then
    Names := ['name', 'Title', '@name']
  else if Control = MemoOverviewDescription then
    Names := ['desc', 'Notes', 'description']
  else if Control = EditOverviewDate then
    Names := ['releasedate', 'ReleaseDate', 'year']
  else if Control = EditOverviewPlayers then
    Names := ['players', 'MaxPlayers']
  else if Control = EditOverviewRating then
    Names := ['rating', 'StarRatingFloat']
  else if Control = EditOverviewPublisher then
    Names := ['publisher', 'Publisher', 'manufacturer']
  else if Control = EditOverviewDeveloper then
    Names := ['developer', 'Developer']
  else if Control = EditOverviewGenre then
    Names := ['genre', 'Genre']
  else if Control = EditOverviewRegion then
    Names := ['region', 'Region']
  else if Control = EditOverviewPlayCount then
    Names := ['playcount', 'PlayCount']
  else if Control = EditOverviewLastPlayed then
    Names := ['lastplayed', 'LastPlayedDate']
  else if Control = CheckBoxOverviewFavorite then
    Names := ['favorite', 'Favorite']
  else if Control = CheckBoxOverviewHidden then
    Names := ['hidden', 'Hide']
  else if Control = CheckBoxOverviewKid then
    Names := ['kidgame'];
  if Length(Names) = 0 then
    Exit;
  Root := FDraft.DocumentElement;
  for Name in Names do
    if Name.StartsWith('@') then
    begin
      if Root.HasAttribute(Name.Substring(1)) then
        Exit(Name);
    end
    else if Root.ChildNodes.FindNode(Name) <> nil then
      Exit(Name);
  Result := Names[0];
  if FLibrary.Kind = 2 then
  begin
    if Length(Names) > 1 then
      Result := Names[1];
  end
  else if FLibrary.Kind = 3 then
    if Control = EditOverviewName then
      Result := '@name'
    else if Control = MemoOverviewDescription then
      Result := 'description'
    else if Control = EditOverviewDate then
      Result := 'year'
    else if Control = EditOverviewPublisher then
      Result := 'manufacturer';
end;

function TFormGameLibrary.OverviewDateValue(const Value, FieldName: string): string;
var
  Date: TDateTime;
begin
  Result := Value;
  if SameText(FieldName, 'year') or (Value.Trim = '') then
    Exit;
  if TryStrToDate(Value, Date) then
  begin
    if FLibrary.Kind = 2 then
      Result := FormatDateTime('yyyy-mm-dd', Date)
    else
      Result := FormatDateTime('yyyymmdd"T"hhnnss', Date);
  end;
  // Raw storage dates and incomplete/invalid input pass through to the normal validator.
end;

procedure TFormGameLibrary.OverviewChanged(Sender: TObject);
var
  Name, Value: string;
  Node: IXMLNode;
  Editor, MatchingEditor: TGameFieldEditor;
  WasLoading: Boolean;
begin
  if FLoading or (FDraft = nil) or (FSelected < 0) then
    Exit;
  Name := OverviewFieldName(TComponent(Sender));
  if Name = '' then
    Exit;
  if Sender is TEdit then
    Value := TEdit(Sender).Text
  else if Sender is TMemo then
    Value := TMemo(Sender).Text
  else if Sender is TCheckBox then
    Value := LowerCase(BoolToStr(TCheckBox(Sender).IsChecked, True))
  else
    Exit;
  if (Sender = EditOverviewDate) or (Sender = EditOverviewLastPlayed) then
    Value := OverviewDateValue(Value, Name);
  if Name.StartsWith('@') then
    FDraft.DocumentElement.Attributes[Name.Substring(1)] := Value
  else
  begin
    Node := FDraft.DocumentElement.ChildNodes.FindNode(Name);
    if Node = nil then
      Node := FDraft.DocumentElement.AddChild(Name);
    Node.Text := Value;
  end;
  FDirty := True;
  MatchingEditor := nil;
  for Editor in FEditors do
    if SameText(Editor.Field.Caption, Name) then
    begin
      MatchingEditor := Editor;
      Break;
    end;
  if MatchingEditor = nil then
    BuildFields
  else
  begin
    WasLoading := FLoading;
    FLoading := True;
    try
      MatchingEditor.Text := Value;
    finally
      FLoading := WasLoading;
    end;
    ValidateEditor(MatchingEditor);
    UpdateFieldsHeight;
  end;
  if Sender = EditOverviewName then
    if Value.Trim <> '' then
      GameTitleLabel.Text := Value
    else
      GameTitleLabel.Text := TPath.GetFileNameWithoutExtension(FLibrary.Games[FSelected].RomPath);
  SyncDraftXML;
  UpdateButtons;
end;

procedure TFormGameLibrary.SyncTabs;
begin
  SpeedButtonOverviewTab.IsPressed := EditorTabs.ActiveTab = TabItemOverview;
  SpeedButtonFieldsTab.IsPressed := EditorTabs.ActiveTab = FieldsTab;
  SpeedButtonXMLTab.IsPressed := EditorTabs.ActiveTab = XMLTab;
  RectangleOverviewTabLine.Visible := SpeedButtonOverviewTab.IsPressed;
  FieldsTabLine.Visible := SpeedButtonFieldsTab.IsPressed;
  XMLTabLine.Visible := SpeedButtonXMLTab.IsPressed;
end;

procedure TFormGameLibrary.OverviewTabClick(Sender: TObject);
begin
  EditorTabs.ActiveTab := TabItemOverview;
  SyncTabs;
end;

procedure TFormGameLibrary.FieldsTabClick(Sender: TObject);
begin
  EditorTabs.ActiveTab := FieldsTab;
  SyncTabs;
end;

procedure TFormGameLibrary.XMLTabClick(Sender: TObject);
begin
  EditorTabs.ActiveTab := XMLTab;
  SyncTabs;
end;

procedure TFormGameLibrary.TabChanged(Sender: TObject);
begin
  SyncTabs;
  if EditorTabs.ActiveTab <> TabItemOverview then
    CloseOverviewVideo;
  if FLoading or (FDraft = nil) then
    Exit;
  try
    if EditorTabs.ActiveTab = XMLTab then
    begin
      // Do not overwrite a still-unapplied XML draft on repeated selection.
      if not FXMLDirty then
      begin
        FLoading := True;
        try
          XMLMemo.Text := FDraft.DocumentElement.XML;
        finally
          FLoading := False;
        end;
      end;
    end
    else
    begin
      ApplyXML;
      if EditorTabs.ActiveTab = TabItemOverview then
        UpdateOverview;
    end;
  except
    on E: Exception do
    begin
      FLoading := True;
      try
        EditorTabs.ActiveTab := XMLTab;
      finally
        FLoading := False;
        SyncTabs;
      end;
      ReportError(E);
    end;
  end;
end;

function TFormGameLibrary.OverviewValue(const Names: array of string): string;
var
  Name: string;
  Node: IXMLNode;
begin
  Result := '';
  if FDraft = nil then
    Exit;
  for Name in Names do
  begin
    if Name.StartsWith('@') then
      Result := VarToStr(FDraft.DocumentElement.Attributes[Name.Substring(1)])
    else
    begin
      Node := FDraft.DocumentElement.ChildNodes.FindNode(Name);
      if Node <> nil then
        Result := Node.Text;
    end;
    if Result.Trim <> '' then
      Exit;
  end;
end;

function TFormGameLibrary.OverviewMediaPath(const Names: array of string): string;
var
  Name, Value: string;
begin
  Result := '';
  for Name in Names do
  begin
    Value := OverviewValue([Name]);
    if Value.Trim = '' then
      Continue;
    try
      Value := FLibrary.MediaPath(Value);
      if TFile.Exists(Value) then
        Exit(Value);
    except
      // Invalid references do not prevent the remaining metadata from displaying.
    end;
  end;
end;

procedure TFormGameLibrary.LoadOverviewImage(Image: TImage; const Names: array of string);
var
  Path: string;
begin
  Image.Bitmap.RemoveCallback(Image);
  Image.Bitmap.SetSize(0, 0);
  Image.Visible := False;
  Path := OverviewMediaPath(Names);
  if Path = '' then
    Exit;
  Image.Bitmap.LoadFromFileAsync(Image, Path, 900, 600,
    procedure(Success: Boolean)
    begin
      Image.Visible := Success;
      if (Image = ImageOverviewPicture) and not FVideoSelected then
        if Success then
          SetOverviewMediaStatus('')
        else
          SetOverviewMediaStatus(L('Не удалось загрузить превью: файл отсутствует или формат не поддерживается.'));
    end);
end;

procedure TFormGameLibrary.ClearOverview;
var
  I: Integer;
  Component: TComponent;
  WasLoading: Boolean;
begin
  WasLoading := FLoading;
  FLoading := True;
  try
    CloseOverviewVideo;
    FVideoPath := '';
    for I := 0 to ComponentCount - 1 do
    begin
      Component := Components[I];
      if (Component is TEdit) and string(Component.Name).StartsWith('EditOverview') then
        TEdit(Component).Text := '';
    end;
    MemoOverviewDescription.Text := '';
    CheckBoxOverviewFavorite.IsChecked := False;
    CheckBoxOverviewHidden.IsChecked := False;
    CheckBoxOverviewKid.IsChecked := False;
    ImageOverviewPicture.Bitmap.RemoveCallback(ImageOverviewPicture);
    ImageOverviewBox.Bitmap.RemoveCallback(ImageOverviewBox);
    ImageOverviewPicture.Bitmap.SetSize(0, 0);
    ImageOverviewBox.Bitmap.SetSize(0, 0);
    ImageOverviewPicture.Visible := False;
    ImageOverviewBox.Visible := False;
    SetOverviewMediaStatus('');
  finally
    FLoading := WasLoading;
  end;
end;

procedure TFormGameLibrary.UpdateOverviewFields;
var
  Value: string;
  Date: TDateTime;
  Y, M, D: Integer;
  WasLoading: Boolean;
  RomNode: IXMLNode;
begin
  if (FDraft = nil) or (FSelected < 0) then
    Exit;
  WasLoading := FLoading;
  FLoading := True;
  try
    EditOverviewName.Text := OverviewValue(['name', 'Title', '@name']);
    if EditOverviewName.Text.Trim <> '' then
      GameTitleLabel.Text := EditOverviewName.Text
    else
      GameTitleLabel.Text := TPath.GetFileNameWithoutExtension(FLibrary.Games[FSelected].RomPath);
    MemoOverviewDescription.Text := OverviewValue(['desc', 'Notes', 'description']);
    Value := OverviewValue(['releasedate', 'ReleaseDate', 'year']);
    if (Length(Value) >= 8) and (Value[5] <> '-') and
      TryStrToInt(Copy(Value, 1, 4), Y) and TryStrToInt(Copy(Value, 5, 2), M) and
      TryStrToInt(Copy(Value, 7, 2), D) and TryEncodeDate(Y, M, D, Date) then
      Value := FormatDateTime('dd/mm/yyyy', Date)
    else if TryISO8601ToDate(Value, Date, False) then
      Value := FormatDateTime('dd/mm/yyyy', Date);
    EditOverviewDate.Text := Value;
    EditOverviewPlayers.Text := OverviewValue(['players', 'MaxPlayers']);
    EditOverviewRating.Text := OverviewValue(['rating', 'StarRatingFloat']);
    EditOverviewPublisher.Text := OverviewValue(['publisher', 'Publisher', 'manufacturer']);
    EditOverviewDeveloper.Text := OverviewValue(['developer', 'Developer']);
    EditOverviewGenre.Text := OverviewValue(['genre', 'Genre']);
    Value := OverviewValue(['path', 'ApplicationPath']);
    if FLibrary.Kind = 3 then
    begin
      RomNode := FDraft.DocumentElement.ChildNodes.FindNode('rom');
      if RomNode <> nil then
        Value := VarToStr(RomNode.Attributes['name']);
    end;
    try
      EditOverviewRom.Text := FLibrary.MediaPath(Value);
    except
      EditOverviewRom.Text := Value;
    end;
    EditOverviewRegion.Text := OverviewValue(['region', 'Region']);
    EditOverviewPlayCount.Text := OverviewValue(['playcount', 'PlayCount']);
    EditOverviewLastPlayed.Text := OverviewValue(['lastplayed', 'LastPlayedDate']);
    CheckBoxOverviewFavorite.IsChecked := MatchText(OverviewValue(['favorite', 'Favorite']), ['true', '1']);
    CheckBoxOverviewHidden.IsChecked := MatchText(OverviewValue(['hidden', 'Hide']), ['true', '1']);
    CheckBoxOverviewKid.IsChecked := MatchText(OverviewValue(['kidgame']), ['true', '1']);
  finally
    FLoading := WasLoading;
  end;
end;

procedure TFormGameLibrary.UpdateOverview;
begin
  UpdateOverviewFields;
  LoadOverviewImage(ImageOverviewPicture, ['image', 'ScreenshotImagePath', 'ImagePath', 'thumbnail', 'box', 'BoxFrontImagePath']);
  // EmulationStation's image is commonly a complete mix with its own box and logo.
  // Add a separate box only when displaying a standalone LaunchBox screenshot.
  if (OverviewMediaPath(['image']) = '') and
    (OverviewMediaPath(['ScreenshotImagePath']) <> '') then
    LoadOverviewImage(ImageOverviewBox, ['box', 'BoxFrontImagePath'])
  else
  begin
    ImageOverviewBox.Bitmap.RemoveCallback(ImageOverviewBox);
    ImageOverviewBox.Bitmap.SetSize(0, 0);
    ImageOverviewBox.Visible := False;
  end;
  FVideoPath := OverviewMediaPath(['video', 'VideoPath']);
  UpdateOverviewMedia;
end;

procedure TFormGameLibrary.SetOverviewMediaStatus(const Text: string);
begin
  LabelOverviewMediaStatus.Text := Text;
  LabelOverviewMediaStatus.Visible := Text <> '';
end;

procedure TFormGameLibrary.UpdatePlaybackButton;
var
  Active, Playing: Boolean;
begin
  Active := (FPlayer <> nil) and (FOpenedVideoPath <> '') and FVideoSelected and
    (EditorTabs.ActiveTab = TabItemOverview) and
    (FPlayer.Snapshot.State in [TPlayerState.Ready, TPlayerState.Playing,
      TPlayerState.Paused, TPlayerState.Ended]);
  Playing := Active and (FPlayer.Snapshot.State = TPlayerState.Playing);
  ButtonVideoPlayback.Enabled := Active;
  PathVideoPlay.Visible := not Playing;
  PathVideoPause.Visible := Playing;
  if Playing then
    ButtonVideoPlayback.Hint := L('Пауза')
  else
    ButtonVideoPlayback.Hint := L('Смотреть');
end;

procedure TFormGameLibrary.CloseOverviewVideo;
begin
  FOpenedVideoPath := '';
  LayoutVideoTransport.Visible := False;
  if FPlayer <> nil then
    FPlayer.Close;
  UpdatePlaybackButton;
  TrackBarVideoSeek.Enabled := False;
  LabelVideoTime.Text := '';
end;

procedure TFormGameLibrary.UpdateVideoOverlay;

  function InVideo(Control: IControl): Boolean;
  var
    Obj: TFmxObject;
  begin
    Result := False;
    if Control = nil then
      Exit;
    Obj := Control.GetObject;
    while Obj <> nil do
    begin
      if Obj = LayoutVideoStage then
        Exit(True);
      Obj := Obj.Parent;
    end;
  end;

begin
  LayoutVideoTransport.Visible := FVideoSelected and
    (EditorTabs.ActiveTab = TabItemOverview) and (FOpenedVideoPath <> '') and
    (LayoutVideoStage.Root <> nil) and
    (InVideo(LayoutVideoStage.Root.GetHovered) or InVideo(LayoutVideoStage.Root.GetCaptured));
end;

procedure TFormGameLibrary.VideoPointerChanged(Sender: TObject);
begin
  UpdateVideoOverlay;
end;

procedure TFormGameLibrary.UpdateOverviewMedia;
begin
  SpeedButtonPicture.IsPressed := not FVideoSelected;
  SpeedButtonVideo.IsPressed := FVideoSelected;
  RectanglePictureLine.Visible := not FVideoSelected;
  RectangleVideoLine.Visible := FVideoSelected;
  LayoutOverviewPicture.Visible := not FVideoSelected;
  LayoutVideoStage.Visible := FVideoSelected;
  SetOverviewMediaStatus('');
  if FVideoSelected and (EditorTabs.ActiveTab = TabItemOverview) then
  begin
    if FVideoPath = '' then
    begin
      CloseOverviewVideo;
      SetOverviewMediaStatus(L('Файл медиа не найден'));
    end
    else if FOpenedVideoPath <> FVideoPath then
    begin
      CloseOverviewVideo;
      try
        FOpenedVideoPath := FVideoPath;
        FPlayer.Open(FVideoPath, True);
      except
        on E: Exception do
        begin
          FOpenedVideoPath := '';
          PlayerError(Self, E.Message);
        end;
      end;
    end;
  end
  else
  begin
    CloseOverviewVideo;
    if not FVideoSelected and ImageOverviewPicture.Bitmap.IsEmpty then
      SetOverviewMediaStatus(L('Медиа не задано'));
  end;
  UpdateVideoOverlay;
end;

procedure TFormGameLibrary.OverviewMediaClick(Sender: TObject);
begin
  FVideoSelected := Sender = SpeedButtonVideo;
  UpdateOverviewMedia;
end;

procedure TFormGameLibrary.PlayerError(Sender: TObject; const MessageText: string);
begin
  SetOverviewMediaStatus(MessageText);
  UpdatePlaybackButton;
  TrackBarVideoSeek.Enabled := False;
end;

procedure TFormGameLibrary.PlayerChanged(Sender: TObject);
var
  Active: Boolean;
begin
  UpdateVideoOverlay;
  Active := FVideoSelected and (EditorTabs.ActiveTab = TabItemOverview) and
    (FPlayer.Snapshot.State in [TPlayerState.Ready, TPlayerState.Playing,
      TPlayerState.Paused, TPlayerState.Ended]);
  UpdatePlaybackButton;
  TrackBarVideoSeek.Enabled := Active and (FPlayer.DurationSeconds > 0);
  if not Active then
    Exit;
  FUpdatingVideo := True;
  try
    TrackBarVideoSeek.Max := Max(0.01, FPlayer.DurationSeconds);
    TrackBarVideoSeek.Value := FPlayer.PositionSeconds;
  finally
    FUpdatingVideo := False;
  end;
  LabelVideoTime.Text := Format('%d:%2.2d / %d:%2.2d',
    [Trunc(FPlayer.PositionSeconds) div 60, Trunc(FPlayer.PositionSeconds) mod 60,
     Trunc(FPlayer.DurationSeconds) div 60, Trunc(FPlayer.DurationSeconds) mod 60]);
end;

procedure TFormGameLibrary.VideoPlaybackClick(Sender: TObject);
begin
  if not ButtonVideoPlayback.Enabled then
    Exit;
  if FPlayer.Snapshot.State = TPlayerState.Playing then
    FPlayer.Pause
  else
    FPlayer.Play;
end;

procedure TFormGameLibrary.VideoSeekChanged(Sender: TObject);
begin
  if not FUpdatingVideo and TrackBarVideoSeek.Enabled then
    FPlayer.Seek(TrackBarVideoSeek.Value);
end;

procedure ReleaseLibraryControl(Control: TControl);
var
  Captured: IControl;
  Obj: TFmxObject;

  procedure DetachEvents(Item: TFmxObject);
  var
    I, Count: Integer;
    Props: PPropList;
  begin
    Item.Name := '';
    if Item is TControl then
      TControl(Item).TagObject := nil;
    if Item is TImage then
      TImage(Item).Bitmap.RemoveCallback(Item);
    Count := GetPropList(Item.ClassInfo, [tkMethod], nil);
    GetMem(Props, Count * SizeOf(Pointer));
    try
      GetPropList(Item.ClassInfo, [tkMethod], Props);
      for I := 0 to Count - 1 do
        if string(Props[I].Name).StartsWith('On') then
          SetMethodProp(Item, Props[I], Default(TMethod));
    finally
      FreeMem(Props);
    end;
    for I := 0 to Item.ChildrenCount - 1 do
      DetachEvents(Item.Children[I]);
  end;

begin
  if Control.Root <> nil then
  begin
    Captured := Control.Root.GetCaptured;
    if Captured <> nil then
    begin
      Obj := Captured.GetObject;
      while (Obj <> nil) and (Obj <> Control) do
        Obj := Obj.Parent;
      if Obj = Control then
        Control.Root.SetCaptured(nil);
    end;
  end;
  DetachEvents(Control);
  Control.Parent := nil;
  Control.Release;
end;

procedure TFormGameLibrary.ReleaseFieldEditors;
var
  Editor: TGameFieldEditor;
begin
  for Editor in FEditors do
  begin
    Editor.Field := nil;
    ReleaseLibraryControl(Editor);
  end;
  FEditors.Clear;
end;

procedure TFormGameLibrary.ReleaseGameItems;
begin
  GameList.BeginUpdate;
  try
    while GameList.Count > 0 do
      ReleaseLibraryControl(GameList.ListItems[GameList.Count - 1]);
  finally
    GameList.EndUpdate;
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
  HasGame, Scraping, Busy: Boolean;
  Errors: Integer;
  Editor: TGameFieldEditor;
begin
  Scraping := FScrapeWorker <> nil;
  Busy := Scraping or FLibraryLoading;
  if Busy then
    CloseOverviewVideo;
  CloseButton.Enabled := True;
  HasGame := (FSelected >= 0) and not Busy;
  GamesPanel.Enabled := not Busy;
  ScrapeProgressLayout.Visible := Busy;
  ScrapeActivity.Enabled := Busy;
  if Scraping then
    CloseButton.Text := L('Отменить')
  else if Assigned(FOnReturn) then
    CloseButton.Text := L('Назад')
  else
    CloseButton.Text := L('Закрыть');
  Errors := 0;
  if not FXMLDirty then
    for Editor in FEditors do
      if Editor.ErrorText <> '' then
        Inc(Errors);
  EditorTabs.Enabled := HasGame;
  SpeedButtonOverviewTab.Enabled := HasGame;
  SpeedButtonFieldsTab.Enabled := HasGame;
  SpeedButtonXMLTab.Enabled := HasGame;
  SyncTabs;
  SaveButton.Enabled := HasGame and FDirty and (Errors = 0);
  ScrapeButton.Enabled := HasGame and Assigned(FOnCreateScrapeWorker);
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

procedure TFormGameLibrary.ReplaceMediaClick(Sender: TObject);
var
  I: Integer;
  Editor: TGameFieldEditor;
begin
  I := TControl(Sender).Tag;
  if (I < 0) or (I >= FEditors.Count) then
    Exit;
  Editor := FEditors[I];
  MediaDialog.Filter := L('Все файлы') + '|*.*';
  if not MediaDialog.Execute then
    Exit;
  try
    Editor.Text := FLibrary.MediaReference(MediaDialog.FileName)
  except
    on E: Exception do
      ReportError(E)
  end;
  UpdateMedia(Editor);
  UpdateFieldsHeight;
end;

procedure TFormGameLibrary.ClearMediaClick(Sender: TObject);
var
  I: Integer;
  Editor: TGameFieldEditor;
begin
  I := TControl(Sender).Tag;
  if (I < 0) or (I >= FEditors.Count) then
    Exit;
  Editor := FEditors[I];
  Editor.Text := '';
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
  if Editor.HelpLabel = nil then
    Exit;
  Editor.HelpLabel.Visible := not Editor.HelpLabel.Visible;
  Editor.InfoButton.IsPressed := Editor.HelpLabel.Visible;
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
  UpdateGameCard(FSelected);
  GameTitleLabel.Text := FLibrary.Title(FSelected);
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
  if (FScrapeWorker <> nil) or (FSelected < 0) or
    not Assigned(FOnCreateScrapeWorker) or not ResolveUnsaved then
    Exit;
  FRequestedRom := FLibrary.Games[FSelected].RomPath;
  if not (TFile.Exists(FRequestedRom) or TDirectory.Exists(FRequestedRom)) then
  begin
    FRequestedRom := '';
    StatusLabel.Text := L('ROM выбранной игры не найден');
    Exit;
  end;
  try
    FScrapeWorker := FOnCreateScrapeWorker(FRequestedRom);
    if FScrapeWorker = nil then
      Exit;
    ScrapeProgress.Value := 0;
    UpdateButtons;
    StatusLabel.Text := StageText('Starting');
    FScrapeWorker.Start;
    ScrapeTimer.Enabled := True;
  except
    on E: Exception do
    begin
      FreeAndNil(FScrapeWorker);
      UpdateButtons;
      ReportError(E);
    end;
  end;
end;

procedure TFormGameLibrary.ReloadScrapedGame;
begin
  FLibrary.ReloadGame(FSelected);
  LoadGame(FSelected);
  UpdateGameCard(FSelected);
end;

procedure TFormGameLibrary.ScrapeTimerTimer(Sender: TObject);
var
  Status: TScrapeStatus;
  Lines: TStringList;
begin
  if FScrapeWorker = nil then
    Exit;
  Lines := TStringList.Create;
  try
    FScrapeWorker.Snapshot(Status, Lines);
  finally
    Lines.Free;
  end;
  ScrapeProgress.Max := Max(1, Status.MediaTotal);
  ScrapeProgress.Value := Status.CurrentMedia;
  StatusLabel.Text := StageText(Status.Stage);
  if Status.MediaTotal > 0 then
    StatusLabel.Text := StatusLabel.Text + Format(' · %d / %d',
      [Status.CurrentMedia, Status.MediaTotal]);
  // Finished is checked on the thread as well: status can precede thread cleanup.
  if not FScrapeWorker.Finished then
    Exit;
  ScrapeTimer.Enabled := False;
  FreeAndNil(FScrapeWorker);
  try
    ReloadScrapedGame;
    UpdateButtons;
    if Status.LastError <> '' then
      StatusLabel.Text := Status.LastError
    else if Status.Cancelled or (Status.Errors > 0) then
      StatusLabel.Text := StageText(Status.Stage)
    else if Status.Found = 0 then
      StatusLabel.Text := L('Игра не найдена')
    else
      StatusLabel.Text := StageText('Completed');
  except
    on E: Exception do
    begin
      UpdateButtons;
      ReportError(E);
    end;
  end;
end;

procedure TFormGameLibrary.ReportError(E: Exception);
begin
  StatusLabel.Text := E.Message;
  TDialogServiceSync.ShowMessage(E.Message);
end;

procedure TFormGameLibrary.FormCloseQuery(Sender: TObject; var CanClose: Boolean);
begin
  CanClose := FScrapeWorker = nil;
  if CanClose then
    CanClose := ResolveUnsaved
  else
  begin
    FScrapeWorker.Terminate;
    CloseButton.Enabled := False;
  end;
  if CanClose then
  begin
    CloseOverviewVideo;
    LibraryLoadTimer.Enabled := False;
    if FLibraryLoad <> nil then
      FLibraryLoad.Cancel;
    FLibraryLoad := nil;
    FLibraryLoading := False;
    ScrapeActivity.Enabled := False;
    ScrapeProgressLayout.Visible := False;
  end;
end;

procedure TFormGameLibrary.CloseClick(Sender: TObject);
var
  CanReturn: Boolean;
begin
  if not Assigned(FOnReturn) then
    Exit;
  FormCloseQuery(Self, CanReturn);
  if CanReturn then
    FOnReturn(Self);
end;

procedure TFormGameLibrary.AttachTo(Host: TControl);
begin
  LibraryRoot.Parent := Host;
  CloseButton.Text := L('Назад');
end;

end.

