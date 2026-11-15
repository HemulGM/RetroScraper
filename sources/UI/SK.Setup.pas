unit SK.Setup;

interface

uses
  System.SysUtils, System.Types, System.UITypes, System.Classes, System.JSON,
  System.Generics.Collections, System.Threading, FMX.Types, FMX.Controls,
  FMX.Controls.Presentation, FMX.Forms, FMX.Objects, FMX.StdCtrls, FMX.Edit,
  FMX.ListBox, FMX.Dialogs, FMX.Layouts, SK.Configuration, SK.Catalog,
  FMX.ScrollBox, FMX.Ani, FMX.Graphics, FMX.TreeView, FMX.ImgList,
  System.ImageList;

type
  TWizardResourceStage = (wrIdle, wrConnecting, wrCatalog, wrArtwork, wrReady, wrOffline, wrFailed);

  TFormSetup = class(TForm)
    SetupRoot: TLayout;
    SetupActionLayout: TLayout;
    SetupCommandsLayout: TLayout;
    SetupBodyLayout: TLayout;
    SetupSourceLayout: TLayout;
    SetupFolderLayout: TLayout;
    SetupSurface: TRectangle;
    TitleLabel: TLabel;
    WizardMediaProgressLayout: TLayout;
    WizardMediaProgressTrack: TRectangle;
    WizardMediaProgressFill: TRectangle;
    WizardFooterDivider: TRectangle;
    WizardHeaderLayout: TLayout;
    WizardSubtitle: TLabel;
    WizardSteps: TGridPanelLayout;
    WizardStep1: TLayout;
    WizardStep1Circle: TCircle;
    WizardStep1Number: TLabel;
    WizardStep1Text: TLabel;
    WizardStep1Line: TRectangle;
    WizardStep1LineActive: TRectangle;
    WizardStep2: TLayout;
    WizardStep2Circle: TCircle;
    WizardStep2Number: TLabel;
    WizardStep2Text: TLabel;
    WizardStep2Line: TRectangle;
    WizardStep2LineActive: TRectangle;
    WizardStep3: TLayout;
    WizardStep3Circle: TCircle;
    WizardStep3Number: TLabel;
    WizardStep3Text: TLabel;
    WizardConnectionLayout: TLayout;
    WizardResourcesColumn: TLayout;
    WizardResourcesCard: TRectangle;
    WizardResourcesTitle: TLabel;
    WizardConnectRow: TLayout;
    WizardConnectCircle: TCircle;
    WizardConnectCheck: FMX.Objects.TPath;
    WizardConnectTextLayout: TLayout;
    WizardConnectTitle: TLabel;
    WizardConnectDetail: TLabel;
    WizardCatalogRow: TLayout;
    WizardCatalogCircle: TCircle;
    WizardCatalogCheck: FMX.Objects.TPath;
    WizardCatalogTextLayout: TLayout;
    WizardCatalogTitle: TLabel;
    WizardCatalogDetail: TLabel;
    WizardMediaRow: TLayout;
    WizardMediaGlyphLayout: TLayout;
    WizardMediaCircle: TCircle;
    WizardMediaCheck: FMX.Objects.TPath;
    WizardMediaSpinner: TArc;
    WizardMediaSpin: TFloatAnimation;
    WizardMediaTextLayout: TLayout;
    WizardMediaTitle: TLabel;
    WizardMediaCount: TLabel;
    WizardMediaProgress: TProgressBar;
    WizardMediaNote: TLabel;
    WizardResourcesDivider: TRectangle;
    WizardResourcesInfoRow: TLayout;
    WizardResourcesInfoIcon: FMX.Objects.TPath;
    WizardUserCard: TRectangle;
    WizardUserTitle: TLabel;
    WizardPasswordReveal: TEditButton;
    WizardPasswordEyeOff: FMX.Objects.TPath;
    WizardPasswordEye: FMX.Objects.TPath;
    WizardAnonymousHint: TLabel;
    WizardApplicationCard: TRectangle;
    WizardApplicationTitle: TLabel;
    WizardDeveloperPasswordReveal: TEditButton;
    WizardDeveloperPasswordEyeOff: FMX.Objects.TPath;
    WizardDeveloperPasswordEye: FMX.Objects.TPath;

    FrontEndLabel: TLabel;
    FrontEndCombo: TComboBox;
    RootLabel: TLabel;
    RootEdit: TEdit;
    BrowseButton: TButton;
    BrowseIcon: FMX.Objects.TPath;
    SystemLabel: TLabel;
    PlatformPanel: TRectangle;
    PlatformSearch: TEdit;
    SystemList: TTreeView;
    PlatformIcons: TImageList;
    PlatformCount: TLabel;
    EmptyLabel: TLabel;
    DetectCheck: TCheckBox;
    RecursiveCheck: TCheckBox;
    SearchAllCheck: TCheckBox;
    FrontendHomePanel: TLayout;
    FrontendHomeLabel: TLabel;
    FrontendHomeRow: TLayout;
    FrontendHomeEdit: TEdit;
    FrontendHomeBrowse: TButton;
    FrontendHomeBrowseIcon: FMX.Objects.TPath;
    HelpLabel: TLabel;
    ApplyButton: TButton;
    CancelButton: TButton;
    BackButton: TButton;
    WizardAccountLayout: TVertScrollBox;
    WizardAccountFields: TLayout;
    WizardAccountInfo, WizardDeveloperLabel, WizardDeveloperPasswordLabel, WizardLoginLabel, WizardPasswordLabel: TLabel;
    WizardDeveloper, WizardDeveloperPassword, WizardLogin, WizardPassword: TEdit;
    WizardAnonymous, WizardOffline, ShowCategories: TCheckBox;
    WizardSummaryLayout: TLayout;
    WizardSummaryInfo: TLabel;
    WizardSummary: TListBox;
    WizardSummaryFrontend, WizardSummaryRoot, WizardSummaryHome, WizardSummaryCount: TLabel;
    WizardSummaryCard: TRectangle;
    WizardSummaryHeader: TGridPanelLayout;
    WizardSummaryPlatformColumn, WizardSummaryFolderColumn: TLabel;
    WizardSummaryDivider: TRectangle;
    procedure BackButtonClick(Sender: TObject);
    procedure FormResize(Sender: TObject);
    procedure PasswordRevealClick(Sender: TObject);
    procedure DeveloperPasswordRevealClick(Sender: TObject);
    procedure WizardOptionsChanged(Sender: TObject);
    procedure WizardEditApplyStyle(Sender: TObject);
    procedure ProgressResize(Sender: TObject);
    procedure SummaryMouseMove(Sender: TObject; Shift: TShiftState; X, Y: Single);
    procedure ToggleCategory(Sender: TObject);
    procedure FrontendHomeBrowseClick(Sender: TObject);
    procedure CancelButtonClick(Sender: TObject);
    procedure FormCloseQuery(Sender: TObject; var CanClose: Boolean);
    procedure FormCreate(Sender: TObject);
    procedure SearchChanged(Sender: TObject);
    procedure SelectionChanged(Sender: TObject);
    procedure BrowseButtonClick(Sender: TObject);
    procedure ApplyButtonClick(Sender: TObject);
  private
    FOnCompleted: TNotifyEvent;
    FEmbedded, FCompleted: Boolean;
    FFiltering, FLoadingIcons: Boolean;
    FArtworkBase: string;
    FIconIndexes: TDictionary<Integer, Integer>;
    FConfig: TRetroScraperConfig;
    FCatalog: TJSONObject;
    FCopyMode, FWizard, FScanning: Boolean;
    FScanCancelled: Integer;
    FScanTask: ITask;
    FScanFound: TArray<TDetectedPlatform>;
    FScanError: string;
    FMediaSources: TObjectList<TJSONObject>;
    FOriginalConfig, FWorkingConfig: TRetroScraperConfig;
    FOwnedCatalog, FPendingCatalog: TJSONObject;
    FWizardPage: Integer;
    FResourceDone, FResourceTotal: Integer;
    FResourceStage, FResourcePlatforms, FResourceFailureStage: Integer;
    FWizardFound: TArray<TDetectedPlatform>;
    procedure Complete(Result: TModalResult);
    procedure StartWizardResources;
    procedure FinishWizardResources;
    procedure UpdateWizardProgress;
    procedure PublishResourceStatus(Stage: TWizardResourceStage; Platforms, Done, Total: Integer);
    procedure UpdateWizardSteps;
    procedure BuildWizardSummary;
    procedure MaskPasswords;
    procedure SaveCategories;
    procedure ClearPlatformRows;
    procedure LoadVisibleIcons;
    procedure PlatformViewportChanged(Sender: TObject; const OldViewportPosition, NewViewportPosition: TPointF; const ContentSizeChanged: Boolean);
    function SelectedSystem: TJSONValue;
    procedure FinishDetection;
    procedure UpdateSelection;
    procedure AddSystem(const IDs: TArray<Integer>; const Folder: string);
    procedure CommitDetected(const Found: TArray<TDetectedPlatform>);
    procedure StartDetection;
  public
    destructor Destroy; override;
    procedure AttachTo(Host: TControl);
    procedure ConfigureMedia(Config: TRetroScraperConfig; Catalog: TJSONObject; TargetIndex: Integer);
    function SelectedMedia: TJSONObject;
    property OnCompleted: TNotifyEvent read FOnCompleted write FOnCompleted;
    procedure Configure(Config: TRetroScraperConfig; Catalog: TJSONObject; Wizard: Boolean);
    procedure ShowWizardPage(Page: Integer);
    procedure ShowResourceStatus(Stage: TWizardResourceStage; Platforms, Done, Total: Integer);
    property Scanning: Boolean read FScanning;
    procedure LoadCatalog(Catalog: TJSONObject);
  end;

implementation

uses
  SK.Locale, Sk.Main, SK.Frontend, SK.Json, System.SyncObjs, System.StrUtils,
  System.IOUtils, SK.Platform, SK.Services.Catalog, SK.Consts, SK.ScreenScraper,
  FMX.BehaviorManager, SK.Artwork, System.Math, SK.Cache;
{$R *.fmx}

type
  TWizardEditAccess = class(TEdit);

  TSetupTreeAccess = class(TTreeView);

  TSetupControlAccess = class(TControl);

var
  ExpandedPlatformCategories: TDictionary<string, Boolean>;

procedure TFormSetup.WizardEditApplyStyle(Sender: TObject);
begin
  // The shared WinUI style otherwise imposes its compact 32-pixel height.
  TWizardEditAccess(Sender).SetAdjustType(TAdjustType.None);
  TEdit(Sender).Height := 40;
end;

procedure TFormSetup.FormCreate(Sender: TObject);
begin
  FIconIndexes := TDictionary<Integer, Integer>.Create;
  SystemList.OnViewportPositionChange := PlatformViewportChanged;
  FrontEndCombo.ListBox.ScrollAnimation := TBehaviorBoolean.True;
  ApplyLocale(Self);
  ShowWizardPage(0);
end;

procedure TFormSetup.FormResize(Sender: TObject);
begin
  if WizardResourcesColumn <> nil then
    WizardResourcesColumn.Width := Round(WizardConnectionLayout.Width * 0.418);
  if WizardStep1 <> nil then
  begin
    if SetupRoot.Width >= 1120 then
    begin
      WizardStep1.Padding.Left := 90;
      WizardStep2.Padding.Left := 24;
      WizardStep3.Padding.Left := 32
    end
    else
    begin
      WizardStep1.Padding.Left := 0;
      WizardStep2.Padding.Left := 0;
      WizardStep3.Padding.Left := 0
    end;
  end;
  ProgressResize(nil);
  LoadVisibleIcons;
end;

procedure TFormSetup.ProgressResize(Sender: TObject);
begin
  if (WizardMediaProgressFill <> nil) and (WizardMediaProgressLayout <> nil) then
    WizardMediaProgressFill.Width := Max(0, WizardMediaProgressLayout.Width - 2) *
      EnsureRange(FResourceDone / Max(1, FResourceTotal), 0.0, 1.0);
end;

procedure TFormSetup.MaskPasswords;
begin
  WizardPassword.Password := True;
  WizardDeveloperPassword.Password := True;
  WizardPasswordEye.Visible := False;
  WizardPasswordEyeOff.Visible := True;
  WizardDeveloperPasswordEye.Visible := False;
  WizardDeveloperPasswordEyeOff.Visible := True;
end;

procedure TFormSetup.PasswordRevealClick(Sender: TObject);
begin
  if FScanning or (FResourceStage in [Ord(wrConnecting), Ord(wrCatalog), Ord(wrArtwork)]) then
    Exit;
  WizardPassword.Password := not WizardPassword.Password;
  WizardPasswordEyeOff.Visible := WizardPassword.Password;
  WizardPasswordEye.Visible := not WizardPassword.Password;
end;

procedure TFormSetup.DeveloperPasswordRevealClick(Sender: TObject);
begin
  if FScanning or (FResourceStage in [Ord(wrConnecting), Ord(wrCatalog), Ord(wrArtwork)]) then
    Exit;
  WizardDeveloperPassword.Password := not WizardDeveloperPassword.Password;
  WizardDeveloperPasswordEyeOff.Visible := WizardDeveloperPassword.Password;
  WizardDeveloperPasswordEye.Visible := not WizardDeveloperPassword.Password;
end;

procedure TFormSetup.WizardOptionsChanged(Sender: TObject);
begin
  UpdateSelection
end;

procedure TFormSetup.UpdateWizardSteps;
var
  I: Integer;
  Circle: TCircle;
  Number, Caption: TLabel;
begin
  for I := 0 to 2 do
  begin
    case I of
      0:
        begin
          Circle := WizardStep1Circle;
          Number := WizardStep1Number;
          Caption := WizardStep1Text
        end;
      1:
        begin
          Circle := WizardStep2Circle;
          Number := WizardStep2Number;
          Caption := WizardStep2Text
        end;
    else
      begin
        Circle := WizardStep3Circle;
        Number := WizardStep3Number;
        Caption := WizardStep3Text
      end;
    end;
    Circle.Fill.Kind := TBrushKind.None;
    Circle.Stroke.Color := $FF777777;
    Number.TextSettings.FontColor := $FFB7BFC8;
    Caption.TextSettings.FontColor := $FFB7BFC8;
    if I <= FWizardPage then
    begin
      Circle.Fill.Kind := TBrushKind.Solid;
      Circle.Fill.Color := $FF4CC9F0;
      Circle.Stroke.Color := $FF4CC9F0;
      Number.TextSettings.FontColor := $FF161616;
      Caption.TextSettings.FontColor := $FF4CC9F0;
    end;
  end;
  WizardStep1LineActive.Visible := FWizardPage >= 1;
  WizardStep2LineActive.Visible := FWizardPage >= 2;
end;

destructor TFormSetup.Destroy;
begin
  FOnCompleted := nil;
  FFiltering := True;
  TInterlocked.Exchange(FScanCancelled, 1);
  if FScanTask <> nil then
    FScanTask.Wait;
  TThread.RemoveQueuedEvents(nil, FinishDetection);
  TThread.RemoveQueuedEvents(nil, FinishWizardResources);
  TThread.RemoveQueuedEvents(nil, UpdateWizardProgress);
  SaveCategories;
  SystemList.OnViewportPositionChange := nil;
  SystemList.Clear;
  FreeAndNil(FIconIndexes);
  FMediaSources.Free;
  FPendingCatalog.Free;
  FOwnedCatalog.Free;
  FWorkingConfig.Free;
  inherited;
end;

procedure TFormSetup.Configure(Config: TRetroScraperConfig; Catalog: TJSONObject; Wizard: Boolean);
begin
  FCompleted := False;
  ModalResult := mrNone;
  FreeAndNil(FWorkingConfig);
  FreeAndNil(FOwnedCatalog);
  FOriginalConfig := Config;
  if Wizard then
  begin
    FWorkingConfig := TRetroScraperConfig.CreateSnapshot(Config);
    FConfig := FWorkingConfig;
    if Catalog <> nil then
      FOwnedCatalog := Catalog.Clone as TJSONObject
    else
      FOwnedCatalog := TJSONObject.Create;
    Catalog := FOwnedCatalog;
  end
  else
    FConfig := Config;
  FWizard := Wizard;
  FCopyMode := False;
  FrontendHomeEdit.Text := JStr(Config.Root, 'FrontEnd.HomePath');
  FrontEndCombo.ItemIndex := JInt(Config.Root, 'FrontEnd.Type');
  RootEdit.Text := Config.DialogFolder('GameAndRomFolder', JStr(Config.Root, 'AllSystems.GamesAndRoms.Path'));
  RecursiveCheck.IsChecked := False;
  SearchAllCheck.IsChecked := False;
  DetectCheck.IsChecked := Wizard;
  WizardApplicationCard.Visible := not HasApplicationCredentials;
  WizardDeveloper.Text := JStr(Config.Credentials, 'devid');
  WizardDeveloperPassword.Text := JStr(Config.Credentials, 'devpassword');
  WizardLogin.Text := JStr(Config.Credentials, 'ssid');
  WizardPassword.Text := JStr(Config.Credentials, 'sspassword');
  WizardAnonymous.IsChecked := JBool(Config.Root, 'Anonymous');
  WizardOffline.IsChecked := False;
  FScanError := '';
  MaskPasswords;
  LoadCatalog(Catalog);
  ShowWizardPage(0);
  ShowResourceStatus(wrIdle, 0, 0, 0);
end;

procedure TFormSetup.SummaryMouseMove(Sender: TObject; Shift: TShiftState; X, Y: Single);
var
  Row: TListBoxItem;
begin
  // List items do not intercept mouse events; keep selection and scrolling on the list.
  Row := WizardSummary.ItemByPoint(X, Y);
  if Row <> nil then
    WizardSummary.Hint := Row.Hint
  else
    WizardSummary.Hint := '';
end;

procedure TFormSetup.BuildWizardSummary;
var
  Item: TDetectedPlatform;
  ID: Integer;
  Name: string;
  Row: TListBoxItem;
  Grid: TGridPanelLayout;

  procedure AddCell(const ComponentName, Text: string; Color: TAlphaColor);
  var
    Cell: TLabel;
  begin
    Cell := TLabel.Create(Row);
    Cell.Name := ComponentName;
    Cell.Parent := Grid;
    Cell.Align := TAlignLayout.Client;
    Cell.Margins.Rect := RectF(12, 4, 12, 4);
    Cell.StyledSettings := [TStyledSetting.Family];
    Cell.TextSettings.Font.Size := 14;
    Cell.TextSettings.FontColor := Color;
    Cell.TextSettings.WordWrap := False;
    Cell.TextSettings.Trimming := TTextTrimming.Character;
    Cell.Text := Text;
    Cell.HitTest := False;
  end;

begin
  WizardSummaryFrontend.Text := FrontEndLabel.Text + ': ';
  if FrontEndCombo.ItemIndex >= 0 then
    WizardSummaryFrontend.Text := WizardSummaryFrontend.Text + FrontEndCombo.Items[FrontEndCombo.ItemIndex];
  WizardSummaryRoot.Text := RootLabel.Text + ': ' + RootEdit.Text;
  WizardSummaryRoot.Hint := RootEdit.Text;
  WizardSummaryHome.Visible := FrontEndCombo.ItemIndex = 2;
  WizardSummaryHome.Text := FrontendHomeLabel.Text + ': ' + FrontendHomeEdit.Text;
  WizardSummaryHome.Hint := FrontendHomeEdit.Text;
  WizardSummaryCount.Text := SK.Locale.L('Найдено платформ: %d', [Length(FWizardFound)]);
  WizardSummary.BeginUpdate;
  try
    WizardSummary.Clear;
    WizardSummary.Hint := '';
    for Item in FWizardFound do
    begin
      Name := '';
      for ID in Item.IDs do
      begin
        if Name <> '' then
          Name := Name + ', ';
        Name := Name + PlatformName(FCatalog, FConfig.SystemAt(-1), ID);
      end;
      Row := TListBoxItem.Create(WizardSummary);
      Row.Parent := WizardSummary;
      Row.Height := 44;
      Row.Hint := Name + sLineBreak + Item.Folder;
      Row.ShowHint := True;
      Grid := TGridPanelLayout.Create(Row);
      Grid.Name := 'SummaryColumns';
      Grid.Parent := Row;
      Grid.Align := TAlignLayout.Contents;
      Grid.HitTest := False;
      Grid.ColumnCollection.Assign(WizardSummaryHeader.ColumnCollection);
      Grid.RowCollection.Assign(WizardSummaryHeader.RowCollection);
      AddCell('SummaryPlatform', Name, $FFF3F3F3);
      AddCell('SummaryFolder', Item.Folder, $FFB7BFC8);
    end;
  finally
    WizardSummary.EndUpdate
  end;
end;

procedure TFormSetup.ShowWizardPage(Page: Integer);
begin
  FWizardPage := Page;
  WizardConnectionLayout.Visible := FWizard and (Page = 0);
  WizardAccountLayout.Visible := FWizard and (Page = 0);
  WizardSummaryLayout.Visible := FWizard and (Page = 2);
  SetupSourceLayout.Visible := not FWizard or (Page = 1);
  PlatformPanel.Visible := SetupSourceLayout.Visible;
  BackButton.Visible := FWizard and (Page > 0);
  WizardSteps.Visible := FWizard;
  WizardSubtitle.Visible := FWizard;
  if FWizard then
  begin
    if not FEmbedded then
    begin
      ClientWidth := 1200;
      ClientHeight := 760;
    end;
    Caption := AppBrand + ' · ' + SK.Locale.L('Настройка библиотеки');
    WizardHeaderLayout.Height := 156;
    WizardHeaderLayout.Padding.Rect := RectF(40, 20, 36, 0);
    SetupBodyLayout.Margins.Left := 40;
    SetupBodyLayout.Margins.Right := 36;
    TitleLabel.Height := 44;
    TitleLabel.TextSettings.Font.Size := 32;
    TitleLabel.TextSettings.Font.Style := [TFontStyle.fsBold];
    TitleLabel.Text := SK.Locale.L('Настройка библиотеки');
    case Page of
      0:
        WizardSubtitle.Text := SK.Locale.L('Подключение к ScreenScraper и загрузка ресурсов');
      1:
        WizardSubtitle.Text := SK.Locale.L('Выберите игровую оболочку, папки и платформы');
      2:
        WizardSubtitle.Text := SK.Locale.L('Проверьте библиотеку перед сохранением');
    end;
    UpdateWizardSteps;
    if Page > 0 then
      MaskPasswords;
  end
  else
  begin
    if not FEmbedded then
    begin
      ClientWidth := 940;
      ClientHeight := 720;
    end;
    Caption := SK.Locale.L('Добавление систем');
    WizardHeaderLayout.Height := 88;
    WizardHeaderLayout.Padding.Rect := RectF(24, 18, 24, 0);
    SetupBodyLayout.Margins.Left := 24;
    SetupBodyLayout.Margins.Right := 24;
    TitleLabel.Height := 36;
    TitleLabel.TextSettings.Font.Size := 22;
    TitleLabel.TextSettings.Font.Style := [];
  end;
  FormResize(nil);
  WizardSummary.Clear;
  if FWizard then
    case Page of
      0:
        ApplyButton.Text := SK.Locale.L('Далее');
      1:
        ApplyButton.Text := SK.Locale.L('Найти платформы');
      2:
        begin
          ApplyButton.Text := SK.Locale.L('Сохранить');
          BuildWizardSummary;
        end;
    end
  else
  begin
    TitleLabel.Text := SK.Locale.L('Системы и игровая оболочка');
    ApplyButton.Text := SK.Locale.L('Добавить')
  end;
  UpdateSelection;
end;

procedure TFormSetup.BackButtonClick(Sender: TObject);
begin
  if not FScanning then
    ShowWizardPage(Max(0, FWizardPage - 1));
end;

procedure TFormSetup.StartWizardResources;
var
  Credentials, Settings: TJSONObject;
  Base: string;
  Count: Integer;
begin
  JSet(FConfig.Root, 'Anonymous', TJSONBool.Create(WizardAnonymous.IsChecked));
  JSet(FConfig.Credentials, 'devid', TJSONString.Create(WizardDeveloper.Text.Trim));
  JSet(FConfig.Credentials, 'devpassword', TJSONString.Create(WizardDeveloperPassword.Text));
  JSet(FConfig.Credentials, 'ssid', TJSONString.Create(WizardLogin.Text.Trim));
  JSet(FConfig.Credentials, 'sspassword', TJSONString.Create(WizardPassword.Text));
  if WizardOffline.IsChecked then
  begin
    Count := SelectablePlatformCount(FCatalog);
    ShowResourceStatus(wrOffline, Count, 0, 0);
    ShowWizardPage(1);
    Exit;
  end;
  if (not HasApplicationCredentials and
    ((WizardDeveloper.Text.Trim = '') or (WizardDeveloperPassword.Text = ''))) or
    (not WizardAnonymous.IsChecked and ((WizardLogin.Text.Trim = '') or (WizardPassword.Text = ''))) then
  begin
    FScanError := SK.Locale.L('Заполните данные подключения или выберите настройку без подключения.');
    FResourceFailureStage := Ord(wrConnecting);
    ShowResourceStatus(wrFailed, 0, 0, 0);
    Exit;
  end;
  Credentials := FConfig.Credentials.Clone as TJSONObject;
  JSet(Credentials, 'anonymous', TJSONBool.Create(WizardAnonymous.IsChecked));
  Settings := FConfig.SystemAt(-1).Clone as TJSONObject;
  JSet(Settings, 'CacheFolder', TJSONString.Create(JStr(FConfig.Root, 'CacheFolder')));
  JSet(Settings, 'CacheLimitGB', TJSONNumber.Create(JInt(FConfig.Root, 'CacheLimitGB', 10)));
  Base := FConfig.Base;
  FScanning := True;
  TInterlocked.Exchange(FScanCancelled, 0);
  FScanError := '';
  MaskPasswords;
  ShowResourceStatus(wrConnecting, 0, 0, 0);
  FScanTask := TTask.Run(
    procedure
    begin
      try
        try
          FPendingCatalog := LoadCatalogResources(Credentials, Settings, Base,
            function: Boolean
            begin
              Result := TInterlocked.CompareExchange(FScanCancelled, 0, 0) <> 0;
            end,
            procedure(Stage: TCatalogResourceStage; Platforms, Done, Total: Integer)
            begin
              case Stage of
                crConnecting:
                  PublishResourceStatus(wrConnecting, Platforms, Done, Total);
                crCatalog:
                  PublishResourceStatus(wrCatalog, Platforms, Done, Total);
                crArtwork:
                  PublishResourceStatus(wrArtwork, Platforms, Done, Total);
              end;
            end);
        except
          on E: EAbort do
            ;
          on E: Exception do
            FScanError := E.Message;
        end;
      finally
        Credentials.Free;
        Settings.Free;
      end;
      TThread.Queue(nil, FinishWizardResources);
    end);
end;

procedure TFormSetup.ShowResourceStatus(Stage: TWizardResourceStage; Platforms, Done, Total: Integer);
begin
  TInterlocked.Exchange(FResourceStage, Ord(Stage));
  TInterlocked.Exchange(FResourcePlatforms, Platforms);
  TInterlocked.Exchange(FResourceDone, Done);
  TInterlocked.Exchange(FResourceTotal, Total);
  UpdateWizardProgress;
end;

procedure TFormSetup.PublishResourceStatus(Stage: TWizardResourceStage; Platforms, Done, Total: Integer);
begin
  TInterlocked.Exchange(FResourceStage, Ord(Stage));
  TInterlocked.Exchange(FResourcePlatforms, Platforms);
  TInterlocked.Exchange(FResourceDone, Done);
  TInterlocked.Exchange(FResourceTotal, Total);
  TThread.Queue(nil, UpdateWizardProgress);
end;

procedure TFormSetup.UpdateWizardProgress;
var
  Stage: TWizardResourceStage;
  Done, Total, Count, Phase: Integer;

  procedure State(Circle: TCircle; Check: FMX.Objects.TPath; Complete, Active, Failed: Boolean);
  begin
    Circle.Fill.Kind := TBrushKind.Solid;
    Circle.Fill.Color := $FF333333;
    Circle.Stroke.Color := $FF777777;
    Check.Visible := Complete;
    if Complete then
    begin
      Circle.Fill.Color := $FF39D12A;
      Circle.Stroke.Color := $FF39D12A
    end
    else if Active then
      Circle.Stroke.Color := $FF4CC9F0
    else if Failed then
      Circle.Stroke.Color := $FFF0B455;
  end;

  function PlatformCountText: string;
  var
    Word: string;
  begin
    Result := SK.Locale.L('%d платформ.', [Count]);
    if CurrentLocale <> 'ru' then
      Exit;
    Word := 'платформ';
    if not (Count mod 100 in [11..14]) then
      case Count mod 10 of
        1:
          Word := 'платформа';
        2..4:
          Word := 'платформы'
      end;
    Result := Format('%d %s.', [Count, Word]);
  end;

begin
  if FWizard and (FWizardPage = 0) then
  begin
    Caption := AppBrand + ' · ' + SK.Locale.L('Настройка библиотеки');
    TitleLabel.Text := SK.Locale.L('Настройка библиотеки');
    WizardSubtitle.Text := SK.Locale.L('Подключение к ScreenScraper и загрузка ресурсов');
    ApplyButton.Text := SK.Locale.L('Далее');
  end;
  Stage := TWizardResourceStage(TInterlocked.CompareExchange(FResourceStage, 0, 0));
  Count := TInterlocked.CompareExchange(FResourcePlatforms, 0, 0);
  Done := TInterlocked.CompareExchange(FResourceDone, 0, 0);
  Total := TInterlocked.CompareExchange(FResourceTotal, 0, 0);
  Phase := Ord(Stage);
  if Stage = wrFailed then
    Phase := FResourceFailureStage;
  State(WizardConnectCircle, WizardConnectCheck, (Phase >= Ord(wrCatalog)) and (Stage <> wrOffline),
    Stage = wrConnecting, (Stage = wrFailed) and (Phase = Ord(wrConnecting)));
  State(WizardCatalogCircle, WizardCatalogCheck, (Count > 0) and (Phase >= Ord(wrArtwork)),
    Stage = wrCatalog, (Stage = wrFailed) and (Phase = Ord(wrCatalog)));
  State(WizardMediaCircle, WizardMediaCheck, Stage = wrReady, Stage = wrArtwork,
    (Stage = wrFailed) and (Phase = Ord(wrArtwork)));
  WizardConnectTitle.Text := SK.Locale.L('Подключение не проверено');
  WizardConnectDetail.Text := SK.Locale.L('Введите реквизиты ScreenScraper.');
  if Stage = wrConnecting then
  begin
    WizardConnectTitle.Text := SK.Locale.L('Проверка подключения…');
    WizardConnectDetail.Text := SK.Locale.L('Соединение с ScreenScraper.')
  end
  else if WizardConnectCheck.Visible then
  begin
    WizardConnectTitle.Text := SK.Locale.L('Подключение проверено');
    WizardConnectDetail.Text := SK.Locale.L('Успешное соединение с API ScreenScraper.')
  end;
  WizardCatalogTitle.Text := SK.Locale.L('Каталог платформ');
  WizardCatalogDetail.Text := SK.Locale.L('Каталог ещё не загружен.');
  if Stage = wrCatalog then
  begin
    WizardCatalogTitle.Text := SK.Locale.L('Загрузка каталога…');
    WizardCatalogDetail.Text := SK.Locale.L('Получение списка платформ.')
  end
  else if WizardCatalogCheck.Visible then
  begin
    WizardCatalogTitle.Text := SK.Locale.L('Каталог получен');
    WizardCatalogDetail.Text := PlatformCountText
  end;
  WizardMediaTitle.Text := SK.Locale.L('Загрузка изображений платформ');
  WizardMediaCount.Visible := (Stage in [wrArtwork, wrReady]) or
    ((Stage = wrFailed) and (Phase = Ord(wrArtwork)) and (Total > 0));
  WizardMediaProgress.Visible := WizardMediaCount.Visible;
  WizardMediaProgressTrack.Visible := WizardMediaProgress.Visible;
  WizardMediaProgress.Max := Max(1, Total);
  WizardMediaProgress.Value := Done;
  ProgressResize(nil);
  WizardMediaCount.Text := Format('%d / %d   (%d%%)', [Done, Total, Round(100.0 * Done / Max(1, Total))]);
  WizardMediaSpinner.Visible := Stage = wrArtwork;
  WizardMediaSpin.Enabled := Stage = wrArtwork;
  WizardAccountInfo.Text := SK.Locale.L('После загрузки можно выбрать папки и платформы.');
  WizardAccountInfo.TextSettings.FontColor := $FFB7BFC8;
  if Stage = wrReady then
    WizardMediaTitle.Text := SK.Locale.L('Изображения платформ загружены');
  if Stage = wrOffline then
  begin
    WizardConnectTitle.Text := SK.Locale.L('Настройка без подключения');
    WizardConnectDetail.Text := SK.Locale.L('Сеть не используется.');
    WizardCatalogTitle.Text := SK.Locale.L('Сохранённый каталог');
    WizardCatalogDetail.Text := PlatformCountText;
    WizardMediaTitle.Text := SK.Locale.L('Изображения из кэша');
  end;
  if Stage = wrFailed then
  begin
    WizardAccountInfo.Text := FScanError;
    WizardAccountInfo.TextSettings.FontColor := $FFF0B455;
    WizardMediaSpinner.Visible := False;
  end;
  UpdateSelection;
end;

procedure TFormSetup.FinishWizardResources;
begin
  FScanning := False;
  if TInterlocked.CompareExchange(FScanCancelled, 0, 0) <> 0 then
  begin
    Complete(mrCancel);
    Exit
  end;
  if FScanError <> '' then
  begin
    FResourceFailureStage := TInterlocked.CompareExchange(FResourceStage, 0, 0);
    ShowResourceStatus(wrFailed, FResourcePlatforms, FResourceDone, FResourceTotal);
    FreeAndNil(FPendingCatalog);
    Exit;
  end;
  FOwnedCatalog.Free;
  FOwnedCatalog := FPendingCatalog;
  FPendingCatalog := nil;
  LoadCatalog(FOwnedCatalog);
  ShowResourceStatus(wrReady, FResourcePlatforms, FResourceTotal, FResourceTotal);
  ShowWizardPage(1);
end;

procedure TFormSetup.AttachTo(Host: TControl);
begin
  FEmbedded := True;
  SetupRoot.Parent := Host;
  FormResize(nil);
end;

procedure TFormSetup.Complete(Result: TModalResult);
begin
  if FCompleted then
    Exit;
  FCompleted := True;
  ModalResult := Result;
  if Assigned(FOnCompleted) then
    FOnCompleted(Self);
end;

procedure TFormSetup.LoadCatalog(Catalog: TJSONObject);
begin
  // Rows borrow catalogue objects; detach them before changing the catalogue.
  FFiltering := True;
  try
    SaveCategories;
    ClearPlatformRows;
    FCatalog := Catalog;
    PlatformSearch.Text := '';
    FIconIndexes.Clear;
    PlatformIcons.Destination.Clear;
    PlatformIcons.Source.Clear;
    if FConfig <> nil then
      FArtworkBase := FConfig.Base
    else
      FArtworkBase := WritableBase;
  finally
    FFiltering := False;
  end;
  SearchChanged(nil);
end;

procedure TFormSetup.SearchChanged(Sender: TObject);
var
  A, V, Previous: TJSONValue;
  Query, Names, Key, Category: string;
  MatchCount: Integer;
  Expanded: Boolean;
  Matches: TList<TJSONValue>;
  Categories: TStringList;
  Header, SelectedRow, FirstRow: TTreeViewItem;

  procedure AddPlatform(Value: TJSONValue; ParentItem: TTreeViewItem = nil);
  var
    Row: TTreeViewItem;
  begin
    Row := TTreeViewItem.Create(SystemList);
    Row.TagObject := Value;
    if FCopyMode then
      Row.Text := JStr(Value, '_name')
    else
      Row.Text := PlatformName(FCatalog, nil, JInt(Value, 'id'));
    if ParentItem <> nil then
      Row.Parent := ParentItem
    else
      Row.Parent := SystemList;
    // Selecting a hidden child would make TreeView expand its parent.
    if (ParentItem = nil) or ParentItem.IsExpanded then
    begin
      if FirstRow = nil then
        FirstRow := Row;
      if Value = Previous then
        SelectedRow := Row;
    end;
    // Only the rows in the viewport need icons;
    // filtering reuses the existing image list.
  end;

begin
  if FFiltering then
    Exit;
  Previous := SelectedSystem;
  SaveCategories;
  Query := PlatformSearch.Text.Trim.ToLower;
  FFiltering := True;
  SystemList.BeginUpdate;
  PlatformIcons.BeginUpdate;
  Matches := TList<TJSONValue>.Create;
  Categories := TStringList.Create;
  try
    ClearPlatformRows;
    SelectedRow := nil;
    FirstRow := nil;
    if FCopyMode then
    begin
      for V in FMediaSources do
        if (Query = '') or JStr(V, '_name').ToLower.Contains(Query) then
          Matches.Add(V);
      A := nil;
    end
    else
      A := JValue(FCatalog, 'systemes');
    if A is TJSONArray then
      for V in TJSONArray(A) do
      begin
        if not SelectablePlatform(V) then
          Continue;
        Names := JStr(V, 'id');
        for Key in ['nom_us', 'nom_eu', 'nom_jp', 'nom_recalbox', 'nom_retropie', 'nom_launchbox', 'noms_commun'] do
          Names := Names + ' ' + JStr(V, 'noms.' + Key);
        if (Query <> '') and not Names.ToLower.Contains(Query) then
          Continue;
        Matches.Add(V);
      end;
    MatchCount := Matches.Count;
    if ShowCategories.IsChecked and not FCopyMode then
    begin
      Categories.Sorted := True;
      Categories.Duplicates := dupIgnore;
      for V in Matches do
        Categories.Add(JStr(V, 'type', 'Other'));
      for Category in Categories do
      begin
        Header := TTreeViewItem.Create(SystemList);
        Header.Text := SK.Locale.L(Category);
        Header.TagString := Category;
        Header.OnClick := ToggleCategory;
        Header.StyledSettings := Header.StyledSettings - [TStyledSetting.Style];
        Header.TextSettings.Font.Style := [TFontStyle.fsBold];
        Header.Parent := SystemList;
        Expanded := False;
        ExpandedPlatformCategories.TryGetValue(Category, Expanded);
        Header.IsExpanded := Expanded;
        for V in Matches do
          if JStr(V, 'type', 'Other') = Category then
            AddPlatform(V, Header);
      end;
    end
    else
      for V in Matches do
        AddPlatform(V);
    if SelectedRow = nil then
      SelectedRow := FirstRow;
    SystemList.Selected := SelectedRow;
  finally
    PlatformIcons.EndUpdate;
    SystemList.EndUpdate;
    FFiltering := False;
    Categories.Free;
    Matches.Free;
  end;
  PlatformCount.Text := SK.Locale.L('Найдено платформ: %d', [MatchCount]);
  EmptyLabel.Visible := MatchCount = 0;
  if Query = '' then
    EmptyLabel.Text := SK.Locale.L('Каталог пуст. Проверьте учётную запись ScreenScraper в настройках.')
  else
    EmptyLabel.Text := SK.Locale.L('Платформы не найдены. Измените поисковый запрос.');
  UpdateSelection;
  LoadVisibleIcons;
end;

procedure TFormSetup.ClearPlatformRows;
var
  Row: TTreeViewItem;
  Root: IRoot;

  procedure Disconnect(Obj: TFmxObject);
  var
    I: Integer;
    Control: TSetupControlAccess;
  begin
    Obj.TagObject := nil;
    if Obj is TControl then
    begin
      Control := TSetupControlAccess(Obj);
      Control.OnClick := nil;
      Control.OnDblClick := nil;
      Control.OnMouseDown := nil;
      Control.OnMouseUp := nil;
      Control.OnMouseMove := nil;
      Control.OnMouseEnter := nil;
      Control.OnMouseLeave := nil;
      Control.OnMouseWheel := nil;
    end;
    for I := 0 to Obj.ChildrenCount - 1 do
      Disconnect(Obj.Children[I]);
  end;

begin
  SystemList.BeginUpdate;
  try
    SystemList.Selected := nil;
    while SystemList.Count > 0 do
    begin
      Row := SystemList.Items[SystemList.Count - 1];
      Root := Row.Root;
      if (Root <> nil) and (Root.GetCaptured <> nil) and
        Row.IsChild(Root.GetCaptured.GetObject) then
        Root.SetCaptured(nil);
      Disconnect(Row);
      Row.Parent := nil;
      Row.Release;
    end;
    TSetupTreeAccess(SystemList).HoveredItem := nil;
    // All rows are detached: reset FMX viewport/selection indexes without
    // destroying any event targets synchronously.
    SystemList.Clear;
  finally
    SystemList.EndUpdate;
  end;
end;

procedure TFormSetup.PlatformViewportChanged(Sender: TObject; const OldViewportPosition, NewViewportPosition: TPointF; const ContentSizeChanged: Boolean);
begin
  LoadVisibleIcons;
end;

procedure TFormSetup.LoadVisibleIcons;
var
  I, ID, ImageIndex: Integer;
  Row: TTreeViewItem;
  Bounds: TRectF;
  ImageFile: string;
  Activity: IInterface;
begin
  if FFiltering or FLoadingIcons or FCopyMode or (FIconIndexes = nil) or
    (FArtworkBase = '') or (csDestroying in ComponentState) then
    Exit;
  FLoadingIcons := True;
  PlatformIcons.BeginUpdate;
  try
    Activity := CacheActivity(FArtworkBase);
    // GlobalCount includes only expanded rows, so collapsed categories do no I/O.
    for I := 0 to SystemList.GlobalCount - 1 do
    begin
      Row := SystemList.ItemByGlobalIndex(I);
      if Row.TagObject = nil then
        Continue;
      // ItemHeight is fixed in FMX. Positions are not assigned yet when the
      // embedded screen is first configured, so use the visible row index.
      if SystemList.ItemHeight > 0 then
        Bounds := RectF(0, I * SystemList.ItemHeight, 1, (I + 1) * SystemList.ItemHeight)
      else
        Bounds := TSetupTreeAccess(SystemList).GetItemRect(Row);
      if (Bounds.Bottom < SystemList.ViewportPosition.Y) or
        (Bounds.Top > SystemList.ViewportPosition.Y + SystemList.Height) then
        Continue;
      ID := JInt(TJSONValue(Row.TagObject), 'id');
      if not FIconIndexes.TryGetValue(ID, ImageIndex) then
      begin
        ImageIndex := -1;
        try
          if FConfig <> nil then
            ImageFile := PlatformArtwork(FArtworkBase, ID, 'icon', FCatalog, CacheBase(FConfig.Root))
          else
            ImageFile := PlatformArtwork(FArtworkBase, ID, 'icon', FCatalog);
          if ImageFile <> '' then
            ImageIndex := PlatformIcons.AddOrSet('platform_' + ID.ToString, [1.0], [ImageFile]);
        except
          // Missing or invalid artwork must not block selecting a platform.
        end;
        FIconIndexes.Add(ID, ImageIndex);
      end;
      Row.ImageIndex := ImageIndex;
    end;
  finally
    PlatformIcons.EndUpdate;
    FLoadingIcons := False;
  end;
end;

procedure TFormSetup.ToggleCategory(Sender: TObject);
var
  Header: TTreeViewItem;
begin
  Header := TTreeViewItem(Sender);
  Header.IsExpanded := not Header.IsExpanded;
  SaveCategories;
  LoadVisibleIcons;
end;

procedure TFormSetup.SaveCategories;
var
  I: Integer;
  Header: TTreeViewItem;
begin
  if SystemList = nil then
    Exit;
  for I := 0 to SystemList.Count - 1 do
  begin
    Header := SystemList.Items[I];
    if (Header.TagObject = nil) and (Header.TagString <> '') then
      ExpandedPlatformCategories.AddOrSetValue(Header.TagString, Header.IsExpanded);
  end;
end;

function TFormSetup.SelectedSystem: TJSONValue;
begin
  Result := nil;
  if SystemList.Selected <> nil then
    Result := TJSONValue(SystemList.Selected.TagObject);
end;

procedure TFormSetup.SelectionChanged(Sender: TObject);
begin
  if not FFiltering then
    UpdateSelection;
end;

procedure TFormSetup.UpdateSelection;
var
  A: TJSONValue;
  Busy: Boolean;
begin
  Busy := FScanning or (FResourceStage in [Ord(wrConnecting), Ord(wrCatalog), Ord(wrArtwork)]);
  if Busy then
    ApplyButton.Opacity := 0.7
  else
    ApplyButton.Opacity := 1;
  RootEdit.Enabled := not Busy;
  BackButton.Enabled := not Busy;
  WizardAccountLayout.Enabled := True;
  WizardDeveloper.Enabled := not Busy;
  WizardDeveloperPassword.Enabled := not Busy;
  WizardLogin.Enabled := not Busy and not WizardAnonymous.IsChecked;
  WizardPassword.Enabled := WizardLogin.Enabled;
  WizardPasswordReveal.Enabled := WizardPassword.Enabled;
  WizardDeveloperPasswordReveal.Enabled := not Busy;
  WizardAnonymous.Enabled := not Busy;
  WizardOffline.Enabled := not Busy;
  FrontEndCombo.Enabled := not Busy;
  BrowseButton.Enabled := not Busy;
  DetectCheck.Enabled := not Busy;
  FrontendHomeEdit.Enabled := not Busy;
  FrontendHomeBrowse.Enabled := not Busy;
  if Busy then
  begin
    ApplyButton.Enabled := False;
    PlatformSearch.Enabled := False;
    SystemList.Enabled := False;
    RecursiveCheck.Enabled := False;
    SearchAllCheck.Enabled := False;
    Exit;
  end;
  SearchAllCheck.Visible := FrontEndCombo.ItemIndex in [0, 1];
  SearchAllCheck.Enabled := DetectCheck.IsChecked;
  RecursiveCheck.Enabled := DetectCheck.IsChecked and
    (not SearchAllCheck.Visible or SearchAllCheck.IsChecked);
  FrontendHomePanel.Visible := not FCopyMode and (FrontEndCombo.ItemIndex = 2);
  if FCopyMode then
  begin
    ApplyButton.Enabled := SelectedSystem <> nil;
    Exit
  end;
  A := JValue(FCatalog, 'systemes');
  ApplyButton.Enabled := False;
  if A is TJSONArray then
    ApplyButton.Enabled := (TJSONArray(A).Count > 0) and
      (DetectCheck.IsChecked or (SelectedSystem <> nil));
  PlatformSearch.Enabled := not DetectCheck.IsChecked;
  SystemList.Enabled := not DetectCheck.IsChecked;
  if FWizard and (FWizardPage <> 1) then
    ApplyButton.Enabled := not FScanning;
end;

procedure TFormSetup.BrowseButtonClick(Sender: TObject);
var
  Folder: string;
begin
  Folder := FConfig.DialogFolder('GameAndRomFolder', RootEdit.Text);
  if SelectDirectory(SK.Locale.L('Папка ROM'), '', Folder) then
  begin
    RootEdit.Text := Folder;
    FConfig.RememberFolder('GameAndRomFolder', Folder);
  end;
end;

procedure TFormSetup.FrontendHomeBrowseClick(Sender: TObject);
var
  Folder: string;
begin
  Folder := FConfig.DialogFolder('FrontEndPath', FrontendHomeEdit.Text);
  if SelectDirectory(SK.Locale.L('Папка игровой оболочки'), '', Folder) then
  begin
    FrontendHomeEdit.Text := Folder;
    FConfig.RememberFolder('FrontEndPath', Folder);
  end;
end;

procedure TFormSetup.ConfigureMedia(Config: TRetroScraperConfig; Catalog: TJSONObject; TargetIndex: Integer);
var
  I: Integer;
  Source: TJSONObject;
begin
  Configure(Config, Catalog, False);
  FConfig := Config;
  FCatalog := Catalog;
  FCopyMode := True;
  FreeAndNil(FMediaSources);
  FMediaSources := TObjectList<TJSONObject>.Create(True);
  for I := -1 to Config.Root.GetValue<TJSONArray>('Systems').Count - 1 do
  begin
    if I = TargetIndex then
      Continue;
    Source := Config.EffectiveSystem(I);
    if not (JValue(Source, 'Medias') is TJSONArray) or
      (TJSONArray(JValue(Source, 'Medias')).Count = 0) then
    begin
      Source.Free;
      Continue
    end;
    if I < 0 then
      JSet(Source, '_name', TJSONString.Create(SK.Locale.L('Все системы')))
    else
      JSet(Source, '_name', TJSONString.Create(PlatformName(Catalog, Source, JInt(Source, 'SystemId')) +
          ' · ' + JStr(Source, 'GamesAndRoms.Path')));
    FMediaSources.Add(Source);
  end;
  SetupSourceLayout.Visible := False;
  PlatformPanel.Align := TAlignLayout.Client;
  PlatformPanel.Margins.Left := 0;
  TitleLabel.Text := SK.Locale.L('Копирование медиа из системы');
  SystemLabel.Text := SK.Locale.L('Система-источник');
  ApplyButton.Text := SK.Locale.L('Копировать');
  DetectCheck.IsChecked := False;
  PlatformSearch.Text := '';
  SearchChanged(nil);
end;

function TFormSetup.SelectedMedia: TJSONObject;
begin
  Result := nil;
  if FCopyMode and (ModalResult = mrOk) and (SelectedSystem <> nil) then
    Result := SelectedSystem.Clone as TJSONObject;
end;

procedure TFormSetup.AddSystem(const IDs: TArray<Integer>; const Folder: string);
begin
  FConfig.AddPlatform(FCatalog, FrontEndCombo.ItemIndex, IDs, Folder);
end;

procedure TFormSetup.CancelButtonClick(Sender: TObject);
begin
  if FScanning then
  begin
    TInterlocked.Exchange(FScanCancelled, 1);
    PlatformCount.Text := SK.Locale.L('Остановка…');
  end
  else
    Complete(mrCancel);
end;

procedure TFormSetup.FormCloseQuery(Sender: TObject; var CanClose: Boolean);
begin
  CanClose := not FScanning;
  if not CanClose then
    TInterlocked.Exchange(FScanCancelled, 1);
end;

procedure TFormSetup.CommitDetected(const Found: TArray<TDetectedPlatform>);
var
  Item: TDetectedPlatform;
begin
  if FWizard then
    JSet(FConfig.Root, 'Systems', TJSONArray.Create);
  if FWizard or (JInt(FConfig.Root, 'FrontEnd.Type') <> FrontEndCombo.ItemIndex) then
  begin
    JSet(FConfig.Root, 'FrontEnd.Type', TJSONNumber.Create(FrontEndCombo.ItemIndex));
    ApplyFrontendDefaults(FConfig.Root, True);
  end;
  if FrontEndCombo.ItemIndex = 2 then
  begin
    JSet(FConfig.Root, 'FrontEnd.HomePath', TJSONString.Create(FrontendHomeEdit.Text));
    FConfig.RememberFolder('FrontEndPath', FrontendHomeEdit.Text);
  end;
  for Item in Found do
    AddSystem(Item.IDs, Item.Folder);
  if DetectCheck.IsChecked then
    JSet(FConfig.Root, 'AllSystems.GamesAndRoms.Path', TJSONString.Create(RootEdit.Text));
  FConfig.RememberFolder('GameAndRomFolder', RootEdit.Text);
  if FWizard then
  begin
    JSet(FConfig.Root, 'IsConfigured', TJSONBool.Create(True));
    if FOwnedCatalog <> nil then
      WriteJSON(TPlatformPath.Combine(FConfig.Base, SystemsCatalogPath), FOwnedCatalog);
    FOriginalConfig.ReplaceWith(FConfig);
  end;
  Complete(mrOk);
end;

procedure TFormSetup.FinishDetection;
begin
  FScanning := False;
  UpdateSelection;
  if TInterlocked.CompareExchange(FScanCancelled, 0, 0) <> 0 then
  begin
    Complete(mrCancel);
    Exit
  end;
  if FScanError <> '' then
  begin
    ShowMessage(SK.Locale.L('Ошибка поиска платформ: %s', [FScanError]));
    Exit
  end;
  if Length(FScanFound) = 0 then
  begin
    PlatformCount.Text := SK.Locale.L('Найдено платформ: %d', [0]);
    ShowMessage(SK.Locale.L('Подходящие папки не найдены. Отключите автоопределение и выберите платформу.'));
    Exit;
  end;
  if FWizard then
  begin
    FWizardFound := FScanFound;
    ShowWizardPage(2)
  end
  else
    CommitDetected(FScanFound);
end;

procedure TFormSetup.StartDetection;
var
  Catalog: TJSONObject;
  Root: string;
  Frontend: Integer;
  Recursive, SearchAll: Boolean;
begin
  if FScanning then
    Exit;
  Catalog := FCatalog.Clone as TJSONObject;
  Root := RootEdit.Text;
  Frontend := FrontEndCombo.ItemIndex;
  Recursive := RecursiveCheck.IsChecked;
  SearchAll := SearchAllCheck.IsChecked;
  FScanning := True;
  TInterlocked.Exchange(FScanCancelled, 0);
  PlatformCount.Text := SK.Locale.L('Поиск платформ…');
  UpdateSelection;
  FScanTask := TTask.Run(
    procedure
    var
      Found: TArray<TDetectedPlatform>;
      ErrorText: string;
    begin
      ErrorText := '';
      try
        try
          Found := DetectPlatforms(Catalog, Root, Frontend, Recursive, SearchAll,
            function: Boolean
            begin
              Result := TInterlocked.CompareExchange(FScanCancelled, 0, 0) <> 0
            end);
        except
          on E: EAbort do
            ;
          on E: Exception do
            ErrorText := E.Message;
        end;
      finally
        Catalog.Free
      end;
      FScanFound := Found;
      FScanError := ErrorText;
      TThread.Queue(nil, FinishDetection);
    end);
end;

procedure TFormSetup.ApplyButtonClick(Sender: TObject);
var
  Found: TArray<TDetectedPlatform>;
  IDs, Matches: TArray<Integer>;
  Chosen, ID, Other: Integer;
  LIDs: TList<Integer>;
begin
  if FCopyMode then
  begin
    Complete(mrOk);
    Exit
  end;
  if FWizard then
    case FWizardPage of
      0:
        begin
          StartWizardResources;
          Exit
        end;
      2:
        begin
          CommitDetected(FWizardFound);
          Exit
        end;
    end;
  if not TDirectory.Exists(RootEdit.Text) then
  begin
    ShowMessage(SK.Locale.L('Выберите существующую папку ROM.'));
    Exit
  end;
  if (FrontEndCombo.ItemIndex = 2) and not TDirectory.Exists(FrontendHomeEdit.Text) then
  begin
    ShowMessage(SK.Locale.L('Выберите существующую папку LaunchBox.'));
    Exit
  end;
  if not (JValue(FCatalog, 'systemes') is TJSONArray) or
    (TJSONArray(JValue(FCatalog, 'systemes')).Count = 0) then
  begin
    ShowMessage(SK.Locale.L('Проверьте подключение, чтобы загрузить каталог платформ.'));
    Exit
  end;
  if DetectCheck.IsChecked then
  begin
    StartDetection;
    Exit
  end
  else
  begin
    if SelectedSystem = nil then
      Exit;
    Chosen := JInt(SelectedSystem, 'id');
    Matches := LookupPlatforms(FCatalog, System.IOUtils.TPath.GetFileName(RootEdit.Text), FrontEndCombo.ItemIndex, True, True);
    LIDs := TList<Integer>.Create;
    try
      LIDs.Add(Chosen);
      for ID in Matches do
        if ID = Chosen then
        begin
          for Other in Matches do
            if not LIDs.Contains(Other) then
              LIDs.Add(Other);
          Break
        end;
      IDs := LIDs.ToArray;
    finally
      LIDs.Free
    end;
    SetLength(Found, 1);
    Found[0].Folder := RootEdit.Text;
    Found[0].IDs := IDs;
  end;
  if FWizard then
  begin
    FWizardFound := Found;
    ShowWizardPage(2)
  end
  else
    CommitDetected(Found);
end;

initialization
  ExpandedPlatformCategories := TDictionary<string, Boolean>.Create;

finalization
  ExpandedPlatformCategories.Free;

end.

