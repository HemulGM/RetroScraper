unit SK.Main;

interface

uses
  System.SysUtils, System.Types, System.UITypes, System.Classes, System.JSON,
  System.Threading, FMX.Types, FMX.Controls, FMX.Forms, FMX.Graphics,
  FMX.Dialogs, FMX.StdCtrls, FMX.Controls.Presentation, FMX.Layouts, FMX.Objects,
  FMX.Edit, FMX.ListBox, FMX.TabControl, FMX.Memo, FMX.ScrollBox, FMX.Styles,
  FMX.Filter.Effects, SK.UI.Log, SK.UI.Scraping, SK.Folders, SK.Settings.Session,
  System.Generics.Collections, SK.Configuration, SK.Engine, FMX.Memo.Types,
  FMX.NumberBox, FMX.EditBox;

type
  TFolderItemCount = SK.Folders.TFolderItemCount;

  TFormMain = class(TForm)
    NavigationService: TLayout;
    InspectorFolderLine: TLayout;
    InspectorOverrideLine: TLayout;
    ScrapeGameLine: TLayout;
    ScrapeTimeLine: TLayout;
    LabelMediaPercentLine: TLayout;
    LabelFrontEndLine: TLayout;
    LabelFrontEndHostLine: TLayout;
    LabelFrontEndPathLine: TLayout;
    LabelSystemSelectLine: TLayout;
    SystemSelectionChoices: TLayout;
    LabelSourceFolderLine: TLayout;
    LabelLaunchBoxPlaformLine: TLayout;
    LabelSourceExtensionsLine: TLayout;
    materialLabel1Line: TLayout;
    ExistingListLabelLine: TLayout;
    LabelDestinationFolderLine: TLayout;
    LabelFolderEntriesLine: TLayout;
    CheckBoxFavoriteRatingLine: TLayout;
    CheckBoxFavoriteContainingWordsLine: TLayout;
    CheckBoxHideContainingWordsLine: TLayout;
    CheckBoxAutoHiddenExtentionLine: TLayout;
    CheckBoxExcludeContainingWordsLine: TLayout;
    CheckBoxAutoHideAlternateLine: TLayout;
    CheckBoxAutoHideHackLine: TLayout;
    CheckBoxAutoHideTranslationLine: TLayout;
    CheckBoxAutoHideRegionsLine: TLayout;
    CheckBoxAutoExcludeHackLine: TLayout;
    CheckBoxAutoExcludeTranslationLine: TLayout;
    CheckBoxAutoExcludeUnlicensedLine: TLayout;
    CheckBoxAutoExcludeRegionsLine: TLayout;
    TextCaseGroupTitleLine: TLayout;
    CheckBoxMoveArticlesLine: TLayout;
    CheckBoxUseFilenameRegionsLine: TLayout;
    CheckBoxNameDecorationKeepUndecoratedFilenameLine: TLayout;
    CheckBoxNameDecorationKeepFilenameDecorationLine: TLayout;
    CheckBoxDoNotIncludeSynopsisLine: TLayout;
    MediaListHeading: TLayout;
    MediaListActions: TLayout;
    MediaTypeLine: TLayout;
    MediaVariantLine: TLayout;
    MediaVariantEditors: TLayout;
    LabelMediaOutputFolderLine: TLayout;
    LabelLinkSelectionLine: TLayout;
    RadioButtonNodeLinkLine: TLayout;
    CheckBoxOptimizeMediaStorageLine: TLayout;
    CheckBoxMediaEmptyOutputFolderLine: TLayout;
    CheckBoxResizeWidthLine: TLayout;
    LabelMethodLine: TLayout;
    LabelLanguageLine: TLayout;
    LabelRegionLine: TLayout;
    LabelClassificationLine: TLayout;
    CheckBoxSaveLogsLine: TLayout;
    CheckBoxVerboseLoggingLine: TLayout;
    CheckBoxSaveMissingLine: TLayout;
    LabelHTTPTriesLine: TLayout;
    LabelCacheTTLLine: TLayout;
    ReuseExistingMediaCaptionLine: TLayout;
    AccountStatusDotLine: TLayout;
    AccountThreadsLabelLine: TLayout;
    AccountQuotaLabelLine: TLayout;
    PageHeadingLine: TLayout;
    SecondarySystemsRow: TLayout;
    SecondarySystemsLabel: TLabel;
    EditSecondarySystems: TEdit;
    MediaPreviewLayout: TLayout;
    MediaPreviewImage: TImage;
    MediaPreviewCaption: TLabel;
    AccountPreferences: TLayout;
    LanguageRow: TLayout;
    LanguageLabel: TLabel;
    UILanguage: TComboBox;
    CheckBoxAnonymous: TCheckBox;
    CacheStatusLabel: TLabel;
    OpenPlatformLibrary: TButton;
    LibrarySearchLayout: TLayout;
    LibraryActionLayout: TLayout;
    LibraryCommandsLayout: TLayout;
    LibraryBodyLayout: TLayout;
    LibraryHeaderSelectCell: TLayout;
    LibraryHeaderSystemCell: TLayout;
    LibraryHeaderPathCell: TLayout;
    LibraryHeaderGrid: TGridPanelLayout;
    SettingsScopeLayout: TLayout;
    ScrapeProgressLayout: TLayout;
    ScrapeMediaColumns: TGridPanelLayout;
    ScrapeLogLayout: TLayout;
    ScrapeLogHeaderLayout: TLayout;
    MediaBodyLayout: TLayout;
    MediaEditorLayout: TLayout;
    InspectorItemCount: TLabel;
    GameFiltersChevron: FMX.Objects.TPath;
    CheckBoxMoveArticlesHelp: TLabel;
    CheckBoxUseFilenameRegionsHelp: TLabel;
    CheckBoxNameDecorationKeepUndecoratedFilenameHelp: TLabel;
    CheckBoxNameDecorationKeepFilenameDecorationHelp: TLabel;
    CheckBoxDoNotIncludeSynopsisHelp: TLabel;

    CacheActionGrid: TGridPanelLayout;
    CaseFieldHeader: TLabel;
    CaseHeadingGrid: TGridPanelLayout;
    PanelNameCaseColumns: TGridPanelLayout;
    PanelDescriptionCaseColumns: TGridPanelLayout;
    PanelGenreCaseColumns: TGridPanelLayout;
    DecorationGrid: TGridPanelLayout;

    PanelFrontEndV3Surface: TRectangle;
    PanelFrontEndV3Title: TLabel;
    PanelSourceFolderV3Surface: TRectangle;
    PanelSourceFolderV3Title: TLabel;
    PanelGameFileExtensionsV3Surface: TRectangle;
    PanelGameFileExtensionsV3Title: TLabel;
    ExtensionsHelp: TLabel;
    LaunchBoxHelp: TLabel;
    PanelGameListTypeV3Surface: TRectangle;
    PanelGameListTypeV3Title: TLabel;
    BasicFilterPanel: TLayout;
    GameRulesGrid: TGridPanelLayout;
    PanelAutoFavoriteV3Surface: TRectangle;
    BasicFilterPanelV3Surface: TRectangle;
    FavoriteHelp: TLabel;
    GameFiltersToggle: TButton;
    PanelAutoHide2V3Surface: TRectangle;
    PanelAutoHide2V3Title: TLabel;
    PanelAutoExclude2V3Surface: TRectangle;
    PanelAutoExclude2V3Title: TLabel;
    TextCaseGroup: TLayout;
    TextCaseGroupV3Surface: TRectangle;
    TextCaseGroupTitle: TLabel;
    TextCaseHelp: TLabel;
    CaseHeader320: TLabel;
    CaseHeader556: TLabel;
    CaseHeader792: TLabel;
    NameDescriptionGroup: TLayout;
    NameDescriptionGroupV3Surface: TRectangle;
    NameDescriptionGroupTitle: TLabel;
    PanelNameDecorationsV3Surface: TRectangle;
    PanelNameDecorationsV3Title: TLabel;
    SearchLocaleGroup: TLayout;
    SearchLocaleGroupV3Surface: TRectangle;
    SearchLocaleGroupTitle: TLabel;
    LanguagesHelp: TLabel;
    RegionsHelp: TLabel;
    NetworkLogsGrid: TGridPanelLayout;
    PanelLogsV3Surface: TRectangle;
    PanelNetworkV3Surface: TRectangle;
    LogOptionsTitle: TLabel;
    NetworkTitle: TLabel;
    CheckBoxSaveLogsCaption: TLabel;
    CheckBoxVerboseLoggingCaption: TLabel;
    CheckBoxSaveMissingCaption: TLabel;
    PanelCacheManagementV3Surface: TRectangle;
    PanelCacheManagementV3Title: TLabel;
    CacheSafetyNote: TLabel;
    AccountScroll: TVertScrollBox;
    AccountContent: TLayout;
    AccountCredentialsPanel: TLayout;
    AccountStatusPanel: TLayout;
    AccountGrid: TGridPanelLayout;
    AccountCredentialsPanelV3Surface: TRectangle;
    AccountStatusPanelV3Surface: TRectangle;
    AccountLoginLabel: TLabel;
    AccountPasswordLabel: TLabel;
    AccountCredentialNote: TLabel;
    AccountStatusTitle: TLabel;
    AccountConnectionState: TLabel;
    AccountStatusDot: TEllipse;
    AccountThreadsLabel: TLabel;
    AccountThreadsValue: TLabel;
    ReuseExistingMediaCaption: TLabel;
    ReuseExistingMediaSwitch: TSwitch;
    AccountQuotaLabel: TLabel;
    AccountQuotaValue: TLabel;
    PanelScreenScraperDescriptionV3Surface: TRectangle;
    ServiceAboutTitle: TLabel;
    ServiceAboutNote: TLabel;

    InspectorBrowse: TButton;
    InspectorBrowseIcon: TPath;
    InspectorUseGlobal: TSwitch;
    InspectorProviderValue: TEdit;
    ScrapeEventList: TListBox;

    CheckBoxOptimizeMediaStorageCaption: TLabel;
    CheckBoxMediaEmptyOutputFolderCaption: TLabel;
    LibraryFooterTopBorder: TRectangle;
    SettingsFooterSurface: TRectangle;
    SettingsFooterTopBorder: TRectangle;
    ScrapeFooterSurface: TRectangle;
    ScrapeFooterTopBorder: TRectangle;
    NavigationEdge: TRectangle;
    ServiceDivider: TRectangle;
    ConfigureSystemAccentIcon: FMX.Objects.TPath;
    ConfigureAllAccentIcon: FMX.Objects.TPath;
    OpenFullLogAccentIcon: FMX.Objects.TPath;
    InspectorSettingsDivider: TRectangle;
    InspectorProviderDivider: TRectangle;
    LibraryHeaderDivider: TRectangle;
    LibraryCheckColumnDivider: TRectangle;
    LibraryPathColumnDivider: TRectangle;
    LibrarySettingsColumnDivider: TRectangle;
    MediaListSurface: TRectangle;
    MediaListHeaderDivider: TRectangle;
    MediaEditorSurface: TRectangle;
    MediaSelectionTitle: TLabel;
    MediaSourceSurface: TRectangle;
    MediaStorageSurface: TRectangle;
    MediaResizeSurface: TRectangle;
    ResizeWidthUnit: TLabel;
    ScrapeProgressSurface: TRectangle;
    ScrapeMetricsRule: TRectangle;
    ScrapeMetricsGrid: TGridPanelLayout;
    MetricScrapedGames: TLayout;
    MetricGameNotFound: TLayout;
    MetricGameNotFoundDivider: TRectangle;
    MetricErrors: TLayout;
    MetricErrorsDivider: TRectangle;
    MetricQuota: TLayout;
    MetricQuotaDivider: TRectangle;
    LabelQuota: TLabel;
    LabelQuotaValue: TLabel;
    MetricSavedMedia: TLayout;
    MetricSavedMediaDivider: TRectangle;
    WorkerSurface: TRectangle;
    WorkerHeaderDivider: TRectangle;
    RunLogSurface: TRectangle;
    RunLogHeaderDivider: TRectangle;
    ScrapeStateBadge: TRectangle;
    ScrapeStateText: TLabel;
    WindowSurface: TRectangle;
    NavigationPanel: TRectangle;
    AppTitle: TLabel;
    AppSubtitle: TLabel;
    NavLibrary: TButton;
    NavLibraryIcon: FMX.Objects.TPath;
    NavScraping: TButton;
    NavScrapingIcon: FMX.Objects.TPath;
    NavSettings: TButton;
    NavSettingsIcon: FMX.Objects.TPath;
    NavLog: TButton;
    NavLogIcon: FMX.Objects.TPath;
    NavMarker: TRectangle;
    ServiceTitle: TLabel;
    ServiceState: TLabel;
    NavAccount: TButton;
    PageHost: TLayout;
    PageTabControl: TTabControl;
    TabLibraryPage: TTabItem;
    TabScrapingPage: TTabItem;
    TabSettingsPage: TTabItem;
    TabLogPage: TTabItem;
    PageTitle: TLabel;
    PageSubtitle: TLabel;
    LibraryPage: TLayout;
    ImportConfigButtonIcon: FMX.Objects.TPath;
    ExportConfigButtonIcon: FMX.Objects.TPath;
    SystemSearch: TEdit;
    LibraryTable: TRectangle;
    SelectAllSystems: TCheckBox;
    SystemColumn: TLabel;
    PathColumn: TLabel;
    OverrideColumn: TLabel;
    SystemInspector: TRectangle;
    InspectorScroll: TVertScrollBox;
    InspectorContent: TLayout;
    InspectorTitle: TLabel;
    InspectorID: TLabel;
    InspectorFolderLabel: TLabel;
    InspectorFolder: TEdit;
    InspectorExtensionsLabel: TLabel;
    InspectorExtensions: TEdit;
    InspectorOverride: TLabel;
    ConfigureSystem: TButton;
    InspectorProvider: TLabel;
    LibraryFooter: TLayout;
    SelectedSystemCount: TLabel;
    ConfigureAll: TButton;
    StartScraping: TButton;
    StartScrapingIcon: FMX.Objects.TPath;
    ScopeLabel: TLabel;
    SettingsScope: TComboBox;
    ScopeNote: TLabel;
    SettingsFooter: TLayout;
    ResetSettings: TButton;
    CancelSettings: TButton;
    SaveSettings: TButton;
    ButtonMediaMoveLeftWinIcon: FMX.Objects.TPath;
    ButtonMediaMoveRightWinIcon: FMX.Objects.TPath;
    ButtonDeleteMediaWinIcon: FMX.Objects.TPath;
    ButtonCopyFromMainWinIcon: FMX.Objects.TPath;
    ButtonRefreshUserMixWinIcon: FMX.Objects.TPath;
    MediaCommandsHint: TLabel;
    MediaSourceTitle: TLabel;
    MediaVariantLabel: TLabel;
    MediaStorageTitle: TLabel;
    MediaXMLField: TLabel;
    ResizeTitle: TLabel;
    AccountTitle: TLabel;
    AccountDescription: TLabel;
    ScrapePercent: TLabel;
    RecentMediaPanel: TRectangle;
    RecentMediaTitle: TLabel;
    PreviewGrid: TGridPanelLayout;
    RecentMediaNote: TLabel;
    RunLogTitle: TLabel;
    OpenFullLog: TButton;
    ScrapeFooter: TLayout;
    ScrapeSummary: TLabel;
    LogPage: TLayout;
    FullLog: TMemo;
    ExportLog: TButton;
    ExistingListLabel: TLabel;
    IconSourceFolder: FMX.Objects.TPath;
    IconFrontEndPath: FMX.Objects.TPath;
    IconDestinationFolder: FMX.Objects.TPath;
    IconMediaOutputFolder: FMX.Objects.TPath;
    IconUserProvidedMix: FMX.Objects.TPath;
    IconAddSystem: FMX.Objects.TPath;
    IconAddMedia: FMX.Objects.TPath;
    PanelMain: TLayout;
    ProgressBarScrappingGames: TProgressBar;
    LabelScrapingGameCount: TLabel;
    PictureBoxPhoto: TImage;
    ButtonScrap: TButton;
    PanelSettings: TLayout;
    SettingsTabControl: TTabControl;
    TabGameList: TTabItem;
    PanelScrollGamelistOuter: TVertScrollBox;
    PanelScrollGamelistInner: TLayout;
    PanelGameListType: TLayout;
    RollingButtonGamelist: TComboBox;
    materialLabel1: TLabel;
    RollingButtonGamelistBehavior: TComboBox;
    CheckBoxOptimizeGameFile: TCheckBox;
    PanelAutoHide2: TLayout;
    CheckBoxAutoHideAlternate: TCheckBox;
    CheckBoxAutoHideUnlicensed: TCheckBox;
    EditAutoHideRegions: TEdit;
    CheckBoxAutoHidePrototype: TCheckBox;
    CheckBoxAutoHideBeta: TCheckBox;
    CheckBoxAutoHideRegions: TCheckBox;
    CheckBoxAutoHideHack: TCheckBox;
    CheckBoxAutoHideSupport: TCheckBox;
    CheckBoxAutoHideClone: TCheckBox;
    CheckBoxAutoHideBest: TCheckBox;
    CheckBoxAutoHideTranslation: TCheckBox;
    CheckBoxAutoHideDemo: TCheckBox;
    PanelAutoExclude: TLayout;
    CheckBoxExcludeNonScraped: TCheckBox;
    EditExcludeContainingWords: TEdit;
    CheckBoxExcludeContainingWords: TCheckBox;
    LabelAutoExclude: TLabel;
    PanelGameListSpecifyConfig: TLayout;
    CheckBoxGameListSpecificConfig: TCheckBox;
    LabelGameListSpecificConfigWarning: TLabel;
    PanelAutoExclude2: TLayout;
    CheckBoxAutoExcludeHack: TCheckBox;
    CheckBoxAutoExcludePrototype: TCheckBox;
    CheckBoxAutoExcludeClone: TCheckBox;
    CheckBoxAutoExcludeBest: TCheckBox;
    CheckBoxAutoExcludeTranslation: TCheckBox;
    CheckBoxAutoExcludeAlternate: TCheckBox;
    CheckBoxAutoExcludeRegions: TCheckBox;
    CheckBoxAutoExcludeDemo: TCheckBox;
    CheckBoxAutoExcludeBeta: TCheckBox;
    EditAutoExcludeRegions: TEdit;
    CheckBoxAutoExcludeUnlicensed: TCheckBox;
    CheckBoxAutoExcludeSupport: TCheckBox;
    PanelAutoHide: TLayout;
    EditHideContainingWords: TEdit;
    CheckBoxHideContainingWords: TCheckBox;
    LabelAutoHide: TLabel;
    CheckBoxHideNonScraped: TCheckBox;
    CheckBoxAutoHiddenExtention: TCheckBox;
    EditAutoHiddenExtentions: TEdit;
    PanelAutoFavorite: TLayout;
    EditFavoriteContainingWords: TEdit;
    LabelAutoFavorite: TLabel;
    RollingButtonAutoFavoriteRating: TComboBox;
    CheckBoxFavoriteContainingWords: TCheckBox;
    CheckBoxAutoFavoriteTopStaff: TCheckBox;
    CheckBoxFavoriteRating: TCheckBox;
    PanelDestinationFolder: TLayout;
    RollingButtonProcessFolders: TComboBox;
    EditDestinationFolder: TEdit;
    ButtonDestinationFolder: TButton;
    LabelFolderEntries: TLabel;
    LabelDestinationFolder: TLabel;
    TabSource: TTabItem;
    PanelScrollSourceOuter: TVertScrollBox;
    PanelScrollSourceInner: TLayout;
    PanelGamesAndRomsSpecifyConfig: TLayout;
    LabelGameRomsSpecificConfigWarning: TLabel;
    CheckBoxGameRomsSpecificConfig: TCheckBox;
    PanelSourceFolder: TLayout;
    RollingButtonSystemSelect: TComboBox;
    LabelGamesAndRomAllSystems: TLabel;
    LabelSourceFolder: TLabel;
    ButtonSourceFolder: TButton;
    LabelSystemSelect: TLabel;
    EditSourceFolder: TEdit;
    PanelGameFileExtensions: TLayout;
    EditGamesAndRomsExtensions: TEdit;
    LabelSourceExtensions: TLabel;
    PanelLaunchBoxPlatform: TLayout;
    EditLaunchBoxPlatform: TEdit;
    LabelLaunchBoxPlaform: TLabel;
    PanelFrontEnd: TLayout;
    LabelFrontEnd: TLabel;
    RollingButtonFrontEnd: TComboBox;
    EditFrontEndHost: TEdit;
    LabelFrontEndHost: TLabel;
    LabelFrontEndPath: TLabel;
    CheckBoxKillFrontEnd: TCheckBox;
    EditFrontEndPath: TEdit;
    ButtonFrontEndPath: TButton;
    TabMedia: TTabItem;
    PanelScrollMediaOuter: TVertScrollBox;
    PanelScrollMediaInner: TLayout;
    PanelMediaDetails: TLayout;
    ButtonMediaOutputFolder: TButton;
    ButtonUserProvidedMix: TButton;
    LabelMediaOutputFolder: TLabel;
    LabelMediaType: TLabel;
    RollingButtonInternalMixSelector: TComboBox;
    RollingButtonImageSelector: TComboBox;
    CheckBoxMediaEmptyOutputFolder: TSwitch;
    PanelImageResizeConfig: TLayout;
    CheckBoxKeepImageRatio: TCheckBox;
    EditResizeWidth: TNumberBox;
    CheckBoxResizeWidth: TCheckBox;
    EditUserProvidedMix: TEdit;
    RollingButtonMediaTypeSelector: TComboBox;
    EditMediaOutputFolder: TEdit;
    PanelLinkSelection: TLayout;
    LabelLinkSelection: TLabel;
    RadioButtonNoLink: TRadioButton;
    RadioButtonNodeLink: TRadioButton;
    CheckBoxOptimizeMediaStorage: TSwitch;
    PanelScrapedMediaScpecifyConfig: TLayout;
    LabelMediaSpecificConfigWarning: TLabel;
    CheckBoxMediaSpecificConfig: TCheckBox;
    PanelScrapedMediaSelector: TLayout;
    ButtonDeleteMedia: TButton;
    ButtonDeleteAll: TButton;
    ButtonMediaMoveLeft: TButton;
    LabelScrapedMediaList: TLabel;
    PanelMediaOuter: TVertScrollBox;
    PanelMediaInner: TLayout;
    ButtonRefreshUserMix: TButton;
    ButtonAddMedia: TButton;
    ButtonMediaMoveRight: TButton;
    ButtonCopyFromMain: TButton;
    TabMetadata: TTabItem;
    PanelScrollMetadataOuter: TVertScrollBox;
    PanelScrollMetadataInner: TLayout;
    PanelGenreCase: TLayout;
    RadioBoxGenreCaseLower: TRadioButton;
    RadioBoxGenreCaseAsIs: TRadioButton;
    LabelGenreCase: TLabel;
    RadioBoxGenreCaseUpper: TRadioButton;
    PanelNameDecorations: TLayout;
    CheckBoxNameDecorationHack: TCheckBox;
    CheckBoxNameDecorationTranslation: TCheckBox;
    CheckBoxNameDecorationAlternate: TCheckBox;
    CheckBoxMoveArticles: TCheckBox;
    CheckBoxDoNotIncludeSynopsis: TCheckBox;
    CheckBoxNameDecorationKeepUndecoratedFilename: TCheckBox;
    CheckBoxNameDecorationCloneType: TCheckBox;
    CheckBoxNameDecorationSupport: TCheckBox;
    CheckBoxNameDecorationPrototype: TCheckBox;
    CheckBoxNameDecorationRegion: TCheckBox;
    CheckBoxNameDecorationBeta: TCheckBox;
    CheckBoxUseFilenameRegions: TCheckBox;
    CheckBoxNameDecorationClone: TCheckBox;
    CheckBoxNameDecorationBest: TCheckBox;
    CheckBoxNameDecorationUnlicensed: TCheckBox;
    CheckBoxNameDecorationKeepFilenameDecoration: TCheckBox;
    CheckBoxNameDecorationDemo: TCheckBox;
    PanelMetadataSpecifyConfig: TLayout;
    LabelMetadataSpecificConfigWarning: TLabel;
    CheckBoxMetadataSpecificConfig: TCheckBox;
    PanelNameCase: TLayout;
    RadioBoxNameCaseLower: TRadioButton;
    RadioBoxNameCaseAsIs: TRadioButton;
    RadioBoxNameCaseUpper: TRadioButton;
    LabelNameCase: TLabel;
    PanelDescriptionCase: TLayout;
    RadioBoxDescriptionCaseUpper: TRadioButton;
    RadioBoxDescriptionCaseAsIs: TRadioButton;
    RadioBoxDescriptionCaseLower: TRadioButton;
    LabelDescriptionCase: TLabel;
    TabAccount: TTabItem;
    EditLogin: TEdit;
    PanelScreenScraperDescription: TLayout;
    LabelThreadAvailable: TLabel;
    EditPassword: TEdit;
    ButtonTestAccount: TButton;
    TabMiscellaneous: TTabItem;
    PanelScrollMiscOuter: TVertScrollBox;
    PanelScrollMiscInner: TLayout;
    PanelMethod: TLayout;
    RollingButtonMethod: TComboBox;
    LabelMethod: TLabel;
    PanelNetwork: TLayout;
    RollingButtonCacheTTL: TComboBox;
    LabelHTTPTries: TLabel;
    LabelCacheTTL: TLabel;
    RollingButtonHTTPTries: TComboBox;
    PanelCountryPreferences: TLayout;
    LabelRegion: TLabel;
    LabelClassification: TLabel;
    CheckBoxRegionStrictMode: TCheckBox;
    EditRegions: TEdit;
    LabelLanguage: TLabel;
    CheckBoxRomRegionFirst: TCheckBox;
    RollingButtonClassification: TComboBox;
    EditLanguages: TEdit;
    PanelAdvancedScpecifyConfig: TLayout;
    LabelMiscellaneousSpecificConfigWarning: TLabel;
    CheckBoxMiscellaneousSpecificConfig: TCheckBox;
    PanelLogs: TLayout;
    CheckBoxSaveLogs: TSwitch;
    CheckBoxSaveMissing: TSwitch;
    CheckBoxVerboseLogging: TSwitch;
    PanelCacheManagement: TLayout;
    RaisedButtonClearGameInformationCache: TButton;
    RaisedButtonClearAllCaches: TButton;
    RaisedButtonClearMediaCache: TButton;
    PanelScrapingInProgress: TLayout;
    FastColoredTextBoxLogging: TMemo;
    PanelScraping: TLayout;
    PictureBoxScrapSample3: TImage;
    PictureBoxScrapSample1: TImage;
    PictureBoxScrapSample2: TImage;
    LabelSavedMedia: TLabel;
    LabelErrors: TLabel;
    LabelErrorsValue: TLabel;
    LabelEstimatedTimeValue: TLabel;
    LabelScrapedGames: TLabel;
    LabelMediaPercent: TLabel;
    LabelGameNotFound: TLabel;
    LabelElapsedValue: TLabel;
    LabelSavedMediaValue: TLabel;
    PanelWorkEngines: TLayout;
    LabelWorkEngines: TLabel;
    PanelScrapingEngines: TVertScrollBox;
    LabelEngineState: TLabel;
    LabelEngineFile: TLabel;
    LabelEngineMedia: TLabel;
    ProgressEngine: TProgressBar;
    MediaCoveragePanel: TRectangle;
    MediaCoverageDetail: TLabel;
    LabelMediaCoverage: TLabel;
    ScrapingScroll: TVertScrollBox;
    ProgressBarMediaFoundPercent: TProgressBar;
    LabelGameNotFoundValue: TLabel;
    LabelScrapedGamesValue: TLabel;
    PanelLeftPan: TLayout;
    PanelSystemListOuter: TVertScrollBox;
    PanelSystemListInner: TLayout;
    ButtonAddSystem: TButton;
    ButtonRunWizard: TButton;
    ButtonRemoveSystem: TButton;
    ImportConfigButton: TButton;
    ExportConfigButton: TButton;
    OpenDialog: TOpenDialog;
    SaveDialog: TSaveDialog;
    StatusTimer: TTimer;
    StyleBookWinUI3: TStyleBook;
    LayoutHead: TLayout;
    Layout1: TLayout;
    CheckBoxResizeHeight: TCheckBox;
    EditResizeHeight: TNumberBox;
    ResizeHeightUnit: TLabel;
    Layout2: TLayout;
    ButtonWeb: TButton;
    procedure OpenPlatformLibraryClick(Sender: TObject);
    procedure PageTabChanged(Sender: TObject);
    procedure NavLibraryClick(Sender: TObject);
    procedure NavScrapingClick(Sender: TObject);
    procedure NavSettingsClick(Sender: TObject);
    procedure NavLogClick(Sender: TObject);
    procedure NavAccountClick(Sender: TObject);
    procedure ConfigureSystemClick(Sender: TObject);
    procedure ConfigureAllClick(Sender: TObject);
    procedure StartScrapingClick(Sender: TObject);
    procedure ResetSettingsClick(Sender: TObject);
    procedure CancelSettingsClick(Sender: TObject);
    procedure SaveSettingsClick(Sender: TObject);
    procedure ExportLogClick(Sender: TObject);
    procedure ScopeChanged(Sender: TObject);
    procedure SearchChanged(Sender: TObject);
    procedure SystemCheckChanged(Sender: TObject);
    procedure SelectAllSystemsChanged(Sender: TObject);
    procedure ToggleGameFilters(Sender: TObject);
    procedure InspectorChanged(Sender: TObject);
    procedure InspectorBrowseClick(Sender: TObject);
    procedure InspectorGlobalChanged(Sender: TObject);
    procedure ScrapeLogChanged(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure FormShow(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure FormCloseQuery(Sender: TObject; var CanClose: Boolean);
    procedure ImportConfigButtonClick(Sender: TObject);
    procedure ExportConfigButtonClick(Sender: TObject);
    procedure ButtonRunWizardClick(Sender: TObject);
    procedure ButtonTestAccountClick(Sender: TObject);
    procedure ButtonScrapClick(Sender: TObject);
    procedure ButtonAddSystemClick(Sender: TObject);
    procedure ButtonRemoveSystemClick(Sender: TObject);
    procedure ButtonSourceFolderClick(Sender: TObject);
    procedure ButtonDestinationFolderClick(Sender: TObject);
    procedure ButtonMediaOutputFolderClick(Sender: TObject);
    procedure ButtonFrontEndPathClick(Sender: TObject);
    procedure ButtonUserProvidedMixClick(Sender: TObject);
    procedure ButtonWebClick(Sender: TObject);
    procedure ButtonRefreshUserMixClick(Sender: TObject);
    procedure ButtonMediaMoveLeftClick(Sender: TObject);
    procedure ButtonMediaMoveRightClick(Sender: TObject);
    procedure ButtonAddMediaClick(Sender: TObject);
    procedure ButtonDeleteMediaClick(Sender: TObject);
    procedure ButtonDeleteAllClick(Sender: TObject);
    procedure ButtonCopyFromMainClick(Sender: TObject);
    procedure RaisedButtonClearAllCachesClick(Sender: TObject);
    procedure RaisedButtonClearGameInformationCacheClick(Sender: TObject);
    procedure RaisedButtonClearMediaCacheClick(Sender: TObject);
    procedure RaisedButtonResetConfigClick(Sender: TObject);
    procedure SettingChanged(Sender: TObject);
    procedure UILanguageChanged(Sender: TObject);
    procedure CredentialsChanged(Sender: TObject);
    procedure PlatformSelectionChanged(Sender: TObject);
    procedure MediaSettingsChanged(Sender: TObject);
    procedure MediaKindChanged(Sender: TObject);
    procedure FrontendChanged(Sender: TObject);
    procedure SettingValueChanging(Sender: TObject);
    procedure StatusTimerTimer(Sender: TObject);
  private
    FCheckedSystems: TDictionary<string, Boolean>;
    FSettings: TSettingsSession;
    FScrapePresenter: TScrapePresenter;
    FLogPresenter: TLogPresenter;
    FConfig: TRetroScraperConfig;
    FSelected, FMedia, FSample: Integer;
    FEffective: TJSONObject;
    FRefreshing, FAccountBusy, FCacheBusy: Boolean;
    FWorker: TScrapeWorker;
    FCatalog: TJSONObject;
    FAccountTask, FCacheTask: ITask;
    FStartupWizardShown: Boolean;
    FPreviewKey: string;
    FFolderCountFuture: IFuture<TFolderItemCount>;
    FFolderCountRequestedPath, FFolderCountActivePath: string;
    FFolderCountPending: Boolean;
    function CanOpenSettings: Boolean;
    function CanExecuteAction(AllowRunningWorker: Boolean = False): Boolean;
    procedure RefreshMediaPreview;
    procedure MoveMedia(Direction: Integer; ToEdge: Boolean);
    procedure ShowPage(Page: Integer);
    procedure SyncFullLog;
    procedure UpdateInspector;
    procedure PollFolderCount;
    procedure UpdateSelectionCount;
    procedure UpdateRowSelection;
    function SystemTitle(Index: Integer): string;
    function SystemKey(Index: Integer): string;
    procedure RefreshSettings;
    function StoreSettingValue(Control: TControl; Validate: Boolean): Boolean;
    procedure BuildSystems;
    procedure BuildMedia;
    procedure SelectSystem(Sender: TObject);
    procedure SelectMedia(Sender: TObject);
    function BindingObject(var Path: string; WriteAccess: Boolean): TJSONObject;
    procedure ValidateAccount;
    procedure AddSystem;
    procedure RunWizard;
    procedure Browse(Edit: TEdit; IsFile: Boolean = False);
    procedure SaveConfig;
    procedure FillCatalog;
    procedure EnsureGroup(const Group: string; Bit: Integer);
    procedure PreviewMedia;
    procedure CleanCache(Information, Media: Boolean);
    function PrepareRequiredMedia: Integer;
  public
    function CreateRunConfig: TJSONObject;
    procedure BeginScrapeDisplay;
    procedure ApplyScrapeStatus(const S: TScrapeStatus);
  end;

function CountFolderItems(const Folder: string): TFolderItemCount;

var
  FormMain: TFormMain;

implementation

uses
  SK.Locale, SK.Preview, SK.Cache, SK.Catalog, SK.Metadata, SK.Frontend, SK.Mix,
  SK.Setup, SK.Storage, SK.Json, SK.Platform, FMX.DialogService.Sync,
  FMX.DialogService, System.DateUtils, System.Math, System.Hash, System.IOUtils,
  System.Variants, SK.UI.Settings, SK.Services.Catalog, SK.UI.Controls,
  SK.Consts, FMX.BehaviorManager, SK.GameLibrary.Form, SK.Artwork;

{$R *.fmx}

function CountFolderItems(const Folder: string): TFolderItemCount;
begin
  Result := SK.Folders.CountFolderItems(Folder);
end;

procedure TFormMain.PollFolderCount;
var
  Counts: TFolderItemCount;
  Folder: string;
begin
  if csDestroying in ComponentState then
    Exit;
  if FFolderCountFuture <> nil then
  begin
    if not (FFolderCountFuture.Status in [TTaskStatus.Completed, TTaskStatus.Exception, TTaskStatus.Canceled]) then
      Exit;
    try
      try
        Counts := FFolderCountFuture.Value;
      except
        Counts := Default(TFolderItemCount);
        Counts.Error := SK.Locale.L('Не удалось прочитать папку')
      end;
      if FFolderCountActivePath = FFolderCountRequestedPath then
      begin
        if Counts.Error <> '' then
          InspectorItemCount.Text := Counts.Error
        else
          InspectorItemCount.Text := Format(SK.Locale.L('Элементов: %d') + sLineBreak + SK.Locale.L('Файлов: %d · папок: %d'),
            [Counts.Files + Counts.Folders, Counts.Files, Counts.Folders]);
      end;
    finally
      FFolderCountFuture := nil
    end;
  end;
  if FFolderCountPending then
  begin
    FFolderCountPending := False;
    Folder := FFolderCountRequestedPath;
    if Folder = '' then
      Exit;
    FFolderCountActivePath := Folder;
    // The worker captures only the path: no form access and no queued UI callback.
    FFolderCountFuture := TTask.Future<TFolderItemCount>(TFunc<TFolderItemCount>(
      function: TFolderItemCount
      begin
        Result := CountFolderItems(Folder)
      end));
  end;
end;

procedure TFormMain.FormCreate(Sender: TObject);
var
  I: Integer;
begin
  // Memo keeps ScrollAnimation public; dropdown lists are created by FMX at runtime.
  for I := 0 to ComponentCount - 1 do
    if Components[I] is TMemo then
      TMemo(Components[I]).ScrollAnimation := TBehaviorBoolean.True
    else if Components[I] is TComboBox then
      TComboBox(Components[I]).ListBox.ScrollAnimation := TBehaviorBoolean.True;
  Caption := AppBrand;
  AppTitle.Text := AppBrand;
  FCheckedSystems := TDictionary<string, Boolean>.Create;
  FLogPresenter := TLogPresenter.Create(Self);
  FScrapePresenter := TScrapePresenter.Create(Self);
  FScrapePresenter.OnLogChanged :=
    procedure
    begin
      ScrapeLogChanged(nil);
    end;
  FScrapePresenter.OnFullLog :=
    procedure
    begin
      SyncFullLog;
    end;
  FScrapePresenter.OnFinished :=
    procedure
    begin
      UpdateSelectionCount;
      UpdateInspector;
    end;
  FSelected := -1;
  FMedia := 0;
  FConfig := TRetroScraperConfig.Create(WritableBase);
  FSettings := TSettingsSession.Create(FConfig);
  SetLocale(CommandLineCulture(JStr(FConfig.Root, 'Culture', 'ru')));
  JSet(FConfig.Root, 'Culture', TJSONString.Create(CurrentLocale));
  FRefreshing := True;
  try
    ApplyLocale(Self)
  finally
    FRefreshing := False
  end;
  FSample := EnsureRange(JInt(FConfig.Root, 'SampleSet'), 0, 5);
  FCatalog := ReadJSON(TPlatformPath.Combine(WritableBase, SystemsCatalogPath));
  if FCatalog = nil then
    FCatalog := ReadJSON(TPlatformPath.Combine(AppBase, SystemsCatalogPath));
  FillCatalog;
  EditLanguages.Hint := 'Miscellaneous.Languages|array|,';
  EditRegions.Hint := 'Miscellaneous.Regions|array|,';
  EditUserProvidedMix.Hint := 'Media.LocalMixFile';
  EditLanguages.OnChange := SettingChanged;
  EditRegions.OnChange := SettingChanged;
  EditUserProvidedMix.OnChange := MediaSettingsChanged;
  RadioButtonNodeLink.Hint := 'Media.LinkToNode|radio-bool|true';
  RadioButtonNodeLink.OnChange := MediaSettingsChanged;
  RadioButtonNoLink.Hint := 'Media.LinkToNode|radio-bool|false';
  RadioButtonNoLink.OnChange := MediaSettingsChanged;
  RollingButtonFrontEnd.Items.Text := 'Recalbox' + sLineBreak + 'RetroPie' + sLineBreak + 'LaunchBox' + sLineBreak + 'RetroBat' + sLineBreak + 'Generic';
  BuildSystems;
  BuildMedia;
  RefreshSettings;
  SettingsTabControl.ActiveTab := TabSource;
  if FConfig.Root.GetValue<TJSONArray>('Systems').Count > 0 then
  begin
    FSelected := 0;
    BuildSystems;
    BuildMedia;
    RefreshSettings
  end;
  ShowPage(0);
end;

procedure TFormMain.FormDestroy(Sender: TObject);
begin
  FLogPresenter.Free;
  FScrapePresenter.Free;
  FCheckedSystems.Free;
  FSettings.Free;
  FWorker.Free;
  FEffective.Free;
  FCatalog.Free;
  FreeAndNil(FConfig);
end;

procedure TFormMain.FormShow(Sender: TObject);
begin
  if FStartupWizardShown then
    Exit;
  FStartupWizardShown := True;
  if not JBool(FConfig.Root, 'IsConfigured') and not FindCmdLineSwitch('selftest') and
    not FindCmdLineSwitch('directorytest') and not FindCmdLineSwitch('librarytest') and
    not FindCmdLineSwitch('paritytest') and not FindCmdLineSwitch('editvisibilitytest') and
    not FindCmdLineSwitch('wizardconcepttest') then
    RunWizard;
end;

procedure TFormMain.RunWizard;
var
  Setup: TFormSetup;
begin
  Setup := TFormSetup.Create(nil);
  try
    Setup.StyleBook := StyleBookWinUI3;
    if Setup.Execute(FConfig, FCatalog, True) then
    begin
      FSelected := -1;
      FMedia := 0;
      FCatalog.Free;
      FCatalog := ReadJSON(TPlatformPath.Combine(WritableBase, SystemsCatalogPath));
      if FCatalog = nil then
        FCatalog := ReadJSON(TPlatformPath.Combine(AppBase, SystemsCatalogPath));
      FCheckedSystems.Clear;
      FillCatalog;
      BuildSystems;
      BuildMedia;
      RefreshSettings;
      SaveConfig;
    end;
  finally
    Setup.Free
  end;
end;

procedure TFormMain.FormCloseQuery(Sender: TObject; var CanClose: Boolean);
var
  S: TScrapeStatus;
  Lines: TStringList;
begin
  CanClose := not FAccountBusy and not FCacheBusy;
  if FWorker <> nil then
  begin
    Lines := TStringList.Create;
    try
      FWorker.Snapshot(S, Lines);
      if Lines.Count > 0 then
        FastColoredTextBoxLogging.Lines.AddStrings(Lines);
    finally
      Lines.Free;
    end;
    if S.Running then
    begin
      FWorker.Terminate;
      CanClose := False;
      ButtonScrap.Text := SK.Locale.L('Остановка…');
    end;
  end;
  if CanClose then
    SaveConfig;
end;

procedure TFormMain.SaveConfig;
begin
  FConfig.Save;
  FConfig.SaveCredentials;
end;

procedure TFormMain.FillCatalog;
var
  A, V: TJSONValue;
  Name: string;
  i: Integer;
  Systems: TJSONArray;
begin
  FRefreshing := True;
  try
    RollingButtonSystemSelect.Items.Clear;
    A := JValue(FCatalog, 'systemes');
    if A is TJSONArray then
      for V in TJSONArray(A) do
      begin
        if not SelectablePlatform(V) then
          Continue;
        Name := JStr(V, 'noms.nom_us', JStr(V, 'noms.nom_eu', JStr(V, 'noms.nom_jp', JStr(V, 'id'))));
        RollingButtonSystemSelect.Items.AddObject(Name, TObject(NativeInt(JInt(V, 'id'))));
      end;
    if RollingButtonSystemSelect.Items.Count = 0 then
    begin
      Systems := FConfig.Root.GetValue<TJSONArray>('Systems');
      for i := 0 to Systems.Count - 1 do
        RollingButtonSystemSelect.Items.AddObject(System.IOUtils.TPath.GetFileName(JStr(Systems.Items[i], 'GamesAndRoms.Path')), TObject(NativeInt(JInt(Systems.Items[i], 'SystemId'))));
    end;
  finally
    FRefreshing := False;
  end;
end;

function TFormMain.SystemTitle(Index: Integer): string;
var
  i, ID: Integer;
begin
  if Index < 0 then
    Exit(SK.Locale.L('Все системы'));
  ID := JInt(FConfig.SystemAt(Index), 'SystemId');
  for i := 0 to RollingButtonSystemSelect.Items.Count - 1 do
    if NativeInt(RollingButtonSystemSelect.Items.Objects[i]) = ID then
      Exit(RollingButtonSystemSelect.Items[i]);
  Result := System.IOUtils.TPath.GetFileName(JStr(FConfig.SystemAt(Index), 'GamesAndRoms.Path'));
end;

function TFormMain.SystemKey(Index: Integer): string;
begin
  Result := FSettings.SystemKey(Index);
end;

procedure TFormMain.BuildSystems;
var
  i, Row: Integer;
  B: TButton;
  Grid: TGridPanelLayout;
  Prefix: TLayout;
  C: TCheckBox;
  L: TLabel;
  P: FMX.Objects.TPath;
  ArtworkImage: TImage;
  Systems: TJSONArray;
  Name, Folder, Filter, ImageFile: string;
  WasRefreshing: Boolean;
begin
  WasRefreshing := FRefreshing;
  FRefreshing := True;
  try
    PanelSystemListInner.DeleteChildren;
    Systems := FConfig.Root.GetValue<TJSONArray>('Systems');
    FSelected := EnsureRange(FSelected, -1, Systems.Count - 1);
    SettingsScope.Items.Clear;
    SettingsScope.Items.Add(SK.Locale.L('Все системы'));
    Filter := SystemSearch.Text.Trim.ToLower;
    Row := 0;
    for i := 0 to Systems.Count - 1 do
    begin
      Name := SystemTitle(i);
      Folder := JStr(Systems.Items[i], 'GamesAndRoms.Path');
      SettingsScope.Items.Add(Name);
      if not FCheckedSystems.ContainsKey(SystemKey(i)) then
        FCheckedSystems.Add(SystemKey(i), True);
      if (Filter <> '') and not (Name.ToLower.Contains(Filter) or Folder.ToLower.Contains(Filter)) then
        Continue;
      B := TButton.Create(Self);
      B.Parent := PanelSystemListInner;
      B.Height := 44;
      B.Position.Y := Row * B.Height; // Initial docking order only.
      B.Align := TAlignLayout.Top;
      B.Tag := i;
      B.OnClick := SelectSystem;
      B.Text := '';
      B.StyleLookup := 'buttonstyle_subtle';
      B.StaysPressed := True;
      B.ApplyStyleLookup;
      B.IsPressed := i = FSelected;
      AddRowAccent(B, i = FSelected, True);
      Grid := TGridPanelLayout.Create(B);
      Grid.Parent := B;
      Grid.Align := TAlignLayout.Contents;
      Grid.HitTest := False;
      Grid.ColumnCollection.Assign(LibraryHeaderGrid.ColumnCollection);
      Grid.RowCollection.Assign(LibraryHeaderGrid.RowCollection);
      Prefix := TLayout.Create(B);
      Prefix.Parent := Grid;
      Prefix.Align := TAlignLayout.Client;
      Prefix.HitTest := False;
      C := TCheckBox.Create(B);
      C.Parent := Prefix;
      C.Align := TAlignLayout.Left;
      C.Width := 24;
      C.Margins.Rect := RectF(16, 6, 0, 6);
      C.Tag := i;
      C.ApplyStyleLookup;
      C.IsChecked := FCheckedSystems[SystemKey(i)];
      C.OnChange := SystemCheckChanged;
      P := FMX.Objects.TPath.Create(B);
      P.Parent := Prefix;
      P.Align := TAlignLayout.Right;
      P.Width := 20;
      P.Margins.Rect := RectF(0, 12, 12, 12);
      P.Data.Assign(NavLibraryIcon.Data);
      P.Fill.Color := $FFE6E6E6;
      P.Stroke.Kind := TBrushKind.None;
      P.WrapMode := TPathWrapMode.Fit;
      P.HitTest := False;
      ImageFile := PlatformArtwork(WritableBase, JInt(Systems.Items[i], 'SystemId'), 'icon');
      if ImageFile <> '' then
      begin
        ArtworkImage := TImage.Create(B);
        ArtworkImage.Parent := Prefix;
        ArtworkImage.Align := TAlignLayout.Right;
        ArtworkImage.Width := 28;
        ArtworkImage.Margins.Rect := RectF(0, 8, 8, 8);
        ArtworkImage.HitTest := False;
        ArtworkImage.WrapMode := TImageWrapMode.Fit;
        try
          ArtworkImage.Bitmap.LoadFromFile(ImageFile);
          P.Visible := False
        except
          ArtworkImage.Free
        end;
      end;
      L := TLabel.Create(B);
      L.Parent := Grid;
      L.Align := TAlignLayout.Client;
      L.Margins.Rect := RectF(0, 4, 4, 4);
      L.Text := Name;
      L.HitTest := False;
      L.StyleName := 'systemname';
      L.TextSettings.WordWrap := False;
      L.TextSettings.Trimming := TTextTrimming.Character;
      L := TLabel.Create(B);
      L.Parent := Grid;
      L.Align := TAlignLayout.Client;
      L.Margins.Rect := RectF(12, 4, 12, 4);
      L.Text := Folder;
      L.StyleName := 'systempath';
      L.TextSettings.WordWrap := False;
      L.HitTest := False;
      L.TextSettings.Trimming := TTextTrimming.Character;
      L.ShowHint := True;
      L.Hint := '';
      L.Opacity := 0.72;
      L := TLabel.Create(B);
      L.Parent := Grid;
      L.Align := TAlignLayout.Client;
      L.Margins.Rect := RectF(12, 4, 12, 4);
      if JInt(Systems.Items[i], 'Overriden') = 0 then
        L.Text := SK.Locale.L('Общие')
      else
        L.Text := SK.Locale.L('Индивидуальные');
      L.StyleName := 'systemsettings';
      L.HitTest := False;
      L.TextSettings.WordWrap := False;
      L.TextSettings.Trimming := TTextTrimming.Character;
      L.Opacity := 0.8;
      Inc(Row);
    end;
    PanelSystemListInner.Height := Max(44, Row * 44);
    SettingsScope.ItemIndex := FSelected + 1;
  finally
    FRefreshing := WasRefreshing
  end;
  UpdateSelectionCount;
end;

procedure TFormMain.UpdateSelectionCount;
var
  i, Count: Integer;
  A: TJSONArray;
  WasRefreshing: Boolean;
begin
  A := FConfig.Root.GetValue<TJSONArray>('Systems');
  Count := 0;
  for i := 0 to A.Count - 1 do
    if FCheckedSystems.ContainsKey(SystemKey(i)) and FCheckedSystems[SystemKey(i)] then
      Inc(Count);
  SelectedSystemCount.Text := Format(SK.Locale.L('%d систем · выбрано %d'), [A.Count, Count]);
  StartScraping.Enabled := (Count > 0) and ((FWorker = nil) or FWorker.Finished);
  WasRefreshing := FRefreshing;
  FRefreshing := True;
  try
    SelectAllSystems.IsChecked := (A.Count > 0) and (Count = A.Count);
  finally
    FRefreshing := WasRefreshing
  end;
end;

procedure TFormMain.UpdateRowSelection;
var
  Row: TFmxObject;
  Child: TComponent;
  J: Integer;
  B: TButton;
  WasRefreshing: Boolean;
begin
  // Keep input targets alive until FMX has completed click/double-click dispatch.
  WasRefreshing := FRefreshing;
  FRefreshing := True;
  try
    if PanelSystemListInner.Children <> nil then
      for Row in PanelSystemListInner.Children do
        if Row is TButton then
        begin
          B := TButton(Row);
          B.IsPressed := B.Tag = FSelected;
          SetRowAccent(B, B.Tag = FSelected);
          for J := 0 to B.ComponentCount - 1 do
          begin
            Child := B.Components[J];
            if Child is TCheckBox then
              TCheckBox(Child).IsChecked := FCheckedSystems[SystemKey(B.Tag)]
            else if Child is TLabel then
            begin
              if TLabel(Child).StyleName = 'systempath' then
                TLabel(Child).Text := JStr(FConfig.SystemAt(B.Tag), 'GamesAndRoms.Path');
              if TLabel(Child).StyleName = 'systemsettings' then
                if JInt(FConfig.SystemAt(B.Tag), 'Overriden') = 0 then
                  TLabel(Child).Text := SK.Locale.L('Общие')
                else
                  TLabel(Child).Text := SK.Locale.L('Индивидуальные');
            end;
          end;
        end;
    SettingsScope.ItemIndex := FSelected + 1;
    if PanelMediaInner.Children <> nil then
      for Row in PanelMediaInner.Children do
        if Row is TButton then
        begin
          TButton(Row).IsPressed := TButton(Row).Tag = FMedia;
          SetRowAccent(TButton(Row), TButton(Row).Tag = FMedia);
        end;
    ButtonMediaMoveLeft.Enabled := FMedia > 0;
    ButtonMediaMoveRight.Enabled := (FEffective <> nil) and
      (FMedia < FEffective.GetValue<TJSONArray>('Medias').Count - 1);
  finally
    FRefreshing := WasRefreshing
  end;
  UpdateSelectionCount;
end;

procedure TFormMain.SystemCheckChanged(Sender: TObject);
begin
  if FRefreshing or (FConfig = nil) then
    Exit;
  if (FWorker <> nil) and not FWorker.Finished then
    Exit;
  FCheckedSystems.AddOrSetValue(SystemKey(TControl(Sender).Tag), TCheckBox(Sender).IsChecked);
  UpdateSelectionCount;
end;

procedure TFormMain.SelectAllSystemsChanged(Sender: TObject);
var
  I: Integer;
  A: TJSONArray;
begin
  if FRefreshing or (FConfig = nil) then
    Exit;
  if (FWorker <> nil) and not FWorker.Finished then
    Exit;
  A := FConfig.Root.GetValue<TJSONArray>('Systems');
  for I := 0 to A.Count - 1 do
    FCheckedSystems.AddOrSetValue(SystemKey(I), SelectAllSystems.IsChecked);
  UpdateRowSelection;
end;

procedure TFormMain.SearchChanged(Sender: TObject);
begin
  if not FRefreshing and (FConfig <> nil) then
    BuildSystems;
end;

procedure TFormMain.ScopeChanged(Sender: TObject);
begin
  if FRefreshing or (FConfig = nil) then
    Exit;
  FSelected := SettingsScope.ItemIndex - 1;
  FMedia := 0;
  BuildMedia;
  UpdateRowSelection;
  RefreshSettings;
end;

procedure TFormMain.UpdateInspector;
var
  E: TJSONObject;
  V: TJSONValue;
  Ext, ImageFile: string;
begin
  OpenPlatformLibrary.Enabled := (FSelected >= 0) and ((FWorker = nil) or FWorker.Finished);
  InspectorTitle.Text := SystemTitle(FSelected);
  ImageFile := PlatformArtwork(WritableBase, JInt(FConfig.SystemAt(FSelected), 'SystemId'), 'photo');
  PictureBoxPhoto.Visible := ImageFile <> '';
  if ImageFile <> '' then
  try
    PictureBoxPhoto.Bitmap.LoadFromFile(ImageFile)
  except
    PictureBoxPhoto.Visible := False
  end;
  InspectorID.Text := 'ScreenScraper ID: ' + JStr(FConfig.SystemAt(FSelected), 'SystemId', '—');
  E := FConfig.EffectiveSystem(FSelected);
  try
    InspectorFolder.Text := JStr(E, 'GamesAndRoms.Path');
    Ext := '';
    if JValue(E, 'GamesAndRoms.FileExtensions') is TJSONArray then
      for V in TJSONArray(JValue(E, 'GamesAndRoms.FileExtensions')) do
      begin
        if Ext <> '' then
          Ext := Ext + ', ';
        Ext := Ext + V.Value;
      end;
    InspectorExtensions.Text := Ext;
  finally
    E.Free
  end;
  FRefreshing := True;
  try
    InspectorUseGlobal.IsChecked := JInt(FConfig.SystemAt(FSelected), 'Overriden') = 0;
  finally
    FRefreshing := False
  end;
  InspectorUseGlobal.Enabled := (FSelected >= 0) and ((FWorker = nil) or FWorker.Finished);
  InspectorFolder.Enabled := InspectorUseGlobal.Enabled;
  InspectorExtensions.Enabled := InspectorUseGlobal.Enabled;
  InspectorBrowse.Enabled := InspectorUseGlobal.Enabled;
  if (FSelected < 0) or (InspectorFolder.Text.Trim = '') then
  begin
    FFolderCountRequestedPath := '';
    FFolderCountPending := False;
    InspectorItemCount.Text := SK.Locale.L('Элементов: —');
  end
  else if FFolderCountRequestedPath <> InspectorFolder.Text.Trim then
  begin
    FFolderCountRequestedPath := InspectorFolder.Text.Trim;
    FFolderCountPending := True;
    InspectorItemCount.Text := SK.Locale.L('Подсчёт элементов…');
  end;
  PollFolderCount;
  ConfigureSystem.Enabled := FSelected >= 0;
  ButtonRemoveSystem.Enabled := FSelected >= 0;
end;

procedure TFormMain.OpenPlatformLibraryClick(Sender: TObject);
var
  Window: TFormGameLibrary;
  Config: TJSONObject;
begin
  if (FWorker <> nil) and not FWorker.Finished then
    Exit;
  if FSelected < 0 then
    Exit;
  Window := nil;
  Config := FConfig.EffectiveSystem(FSelected);
  try
    try
      ResolveFrontendPaths(Config, JValue(FConfig.Root, 'FrontEnd') as TJSONObject, FCatalog);
      Window := TFormGameLibrary.Create(Self);
      Window.StyleBook := StyleBookWinUI3;
      Window.OnCreateScrapeWorker :=
        function(Rom: string): TScrapeWorker
        begin
          SaveConfig;
          // The index refers to the complete config, independent of checkboxes.
          Result := TScrapeWorker.Create(FConfig.Root, FConfig.Credentials,
            WritableBase, FSelected, False, 1, Rom);
        end;
      Window.LoadPlatform(Config, SystemTitle(FSelected));
      Window.ShowModal;
    except
      on E: Exception do
        TDialogServiceSync.ShowMessage(E.Message);
    end;
  finally
    Window.Free;
    Config.Free
  end;
end;

procedure TFormMain.SelectSystem(Sender: TObject);
begin
  if (FWorker <> nil) and not FWorker.Finished then
    Exit;
  if FSelected <> TControl(Sender).Tag then
  begin
    FSelected := TControl(Sender).Tag;
    FMedia := 0;
    BuildMedia;
  end;
  UpdateRowSelection;
  RefreshSettings;
end;

function TFormMain.BindingObject(var Path: string; WriteAccess: Boolean): TJSONObject;
begin
  Result := FSettings.BindingObject(FSelected, FMedia, Path, WriteAccess);
end;

procedure TFormMain.RefreshSettings;
var
  i, j: Integer;
  C: TComponent;
  Path, Text: string;
  Spec: TArray<string>;
  Obj, Effective: TJSONObject;
begin
  FRefreshing := True;
  Effective := FConfig.EffectiveSystem(FSelected);
  try
    for i := 0 to ComponentCount - 1 do
    begin
      C := Components[i];
      if not (C is TControl) then
        Continue;
      Spec := TControl(C).Hint.Split(['|']);
      if (Length(Spec) = 0) or (Spec[0] = '') then
        Continue;
      Path := Spec[0];
      Obj := BindingObject(Path, False);
      if Obj = nil then
        Continue;
      if (Obj = FConfig.SystemAt(FSelected)) and not Path.StartsWith('Overriden') then
        Obj := Effective;
      ApplySettingValue(TControl(C), Obj, Path, Spec, RollingButtonCacheTTL);
    end;
    for j := 0 to RollingButtonSystemSelect.Items.Count - 1 do
      if NativeInt(RollingButtonSystemSelect.Items.Objects[j]) = JInt(FConfig.SystemAt(FSelected), 'SystemId') then
        RollingButtonSystemSelect.ItemIndex := j;
    RollingButtonSystemSelect.Visible := FSelected >= 0;
    LabelGamesAndRomAllSystems.Visible := FSelected < 0;
    CheckBoxGameRomsSpecificConfig.Visible := FSelected >= 0;
    CheckBoxGameListSpecificConfig.Visible := FSelected >= 0;
    CheckBoxMetadataSpecificConfig.Visible := FSelected >= 0;
    CheckBoxMediaSpecificConfig.Visible := FSelected >= 0;
    CheckBoxMiscellaneousSpecificConfig.Visible := FSelected >= 0;
    LabelGameRomsSpecificConfigWarning.Visible := FSelected < 0;
    LabelGameListSpecificConfigWarning.Visible := FSelected < 0;
    LabelMetadataSpecificConfigWarning.Visible := FSelected < 0;
    LabelMediaSpecificConfigWarning.Visible := FSelected < 0;
    LabelMiscellaneousSpecificConfigWarning.Visible := FSelected < 0;
    RollingButtonInternalMixSelector.Visible := RollingButtonMediaTypeSelector.ItemIndex = 1;
    RollingButtonImageSelector.Visible := RollingButtonMediaTypeSelector.ItemIndex = 0;
    EditUserProvidedMix.Visible := RollingButtonMediaTypeSelector.ItemIndex = 2;
    ButtonUserProvidedMix.Visible := EditUserProvidedMix.Visible;
    PanelLaunchBoxPlatform.Visible := RollingButtonFrontEnd.ItemIndex = 2;
    if PanelLaunchBoxPlatform.Visible then
    begin
      PanelGameFileExtensions.Height := 168;
      PanelScrollSourceInner.Height := 644;
    end
    else
    begin
      PanelGameFileExtensions.Height := 108;
      PanelScrollSourceInner.Height := 584;
    end;
    EditFrontEndHost.Enabled := RollingButtonFrontEnd.ItemIndex in [0, 1];
    SecondarySystemsRow.Visible := FSelected >= 0;
    UILanguage.ItemIndex := UILocaleIndex(CurrentLocale);
    CheckBoxAnonymous.Enabled := not FAccountBusy;
    EditLogin.Enabled := not FAccountBusy and not CheckBoxAnonymous.IsChecked;
    EditPassword.Enabled := not FAccountBusy and not CheckBoxAnonymous.IsChecked;
    PanelMediaDetails.Enabled := JValue(Effective, 'Medias') is TJSONArray;
    if PanelMediaDetails.Enabled then
      PanelMediaDetails.Enabled := TJSONArray(JValue(Effective, 'Medias')).Count > 0;
    PanelLinkSelection.Enabled := PanelMediaDetails.Enabled;
    ButtonDeleteMedia.Enabled := PanelMediaDetails.Enabled;
    ButtonCopyFromMain.Enabled := True;
    ButtonRefreshUserMix.Enabled := PanelMediaDetails.Enabled;
    PanelImageResizeConfig.Enabled := RollingButtonMediaTypeSelector.ItemIndex in [0, 1, 2, 8];
    EditResizeWidth.Enabled := CheckBoxResizeWidth.IsChecked;
    EditResizeHeight.Enabled := CheckBoxResizeHeight.IsChecked;
    PanelImageResizeConfig.Enabled := PanelMediaDetails.Enabled and PanelImageResizeConfig.Enabled;
    MediaXMLField.Text := SK.Locale.L('Поле XML: —');
    if JValue(Effective, 'Medias') is TJSONArray then
    begin
      Text := SK.Metadata.MediaNode(TJSONArray(JValue(Effective, 'Medias')), FMedia);
      if Text <> '' then
        MediaXMLField.Text := SK.Locale.L('Поле XML: ') + Text;
    end;
  finally
    Effective.Free;
    FRefreshing := False;
  end;
  UpdateInspector;
  MediaSelectionTitle.Text := SK.Locale.L('Медиа');
  if PanelMediaDetails.Enabled then
    case RollingButtonMediaTypeSelector.ItemIndex of
      0:
        MediaSelectionTitle.Text := RollingButtonImageSelector.Text;
      1:
        MediaSelectionTitle.Text := RollingButtonInternalMixSelector.Text;
    else
      MediaSelectionTitle.Text := RollingButtonMediaTypeSelector.Text;
    end;
  if (FWorker = nil) or FWorker.Finished then
    PreviewMedia;
end;

procedure TFormMain.SettingChanged(Sender: TObject);
begin
  if not FRefreshing and (FConfig <> nil) then
    StoreSettingValue(TControl(Sender), True);
end;

procedure TFormMain.UILanguageChanged(Sender: TObject);
begin
  if FRefreshing or (FConfig = nil) then
    Exit;
  SetLocale(UILocaleCode(UILanguage.ItemIndex));
  JSet(FConfig.Root, 'Culture', TJSONString.Create(CurrentLocale));
  FRefreshing := True;
  try
    ApplyLocale(Self)
  finally
    FRefreshing := False
  end;
  FPreviewKey := '';
  BuildSystems;
  BuildMedia;
  RefreshSettings;
  PageTabChanged(nil);
end;

procedure TFormMain.CredentialsChanged(Sender: TObject);
begin
  if FRefreshing or (FConfig = nil) then
    Exit;
  if not StoreSettingValue(TControl(Sender), True) then
    Exit;
  AccountConnectionState.Text := SK.Locale.L('Не проверено');
  ServiceState.Text := SK.Locale.L('Не проверено');
  AccountStatusDot.Fill.Color := $FF888888;
  AccountThreadsValue.Text := '—';
  AccountQuotaValue.Text := '—';
  LabelQuotaValue.Text := '—';
  LabelQuotaValue.Hint := '';
  LabelThreadAvailable.Text := SK.Locale.L('Нажмите «Проверить подключение»');
end;

procedure TFormMain.PlatformSelectionChanged(Sender: TObject);
begin
  if FRefreshing or (FConfig = nil) or (FSelected < 0) or
    (RollingButtonSystemSelect.ItemIndex < 0) then
    Exit;
  ConfigurePlatform(FConfig.SystemAt(FSelected), FConfig.SystemAt(-1), FCatalog,
    JInt(FConfig.Root, 'FrontEnd.Type'),
    TArray<Integer>.Create(NativeInt(RollingButtonSystemSelect.Items.Objects[RollingButtonSystemSelect.ItemIndex])),
    JStr(FConfig.SystemAt(FSelected), 'GamesAndRoms.Path'));
  BuildSystems;
  BuildMedia;
  RefreshSettings;
end;

procedure TFormMain.MediaSettingsChanged(Sender: TObject);
begin
  if FRefreshing or (FConfig = nil) then
    Exit;
  if not StoreSettingValue(TControl(Sender), True) then
    Exit;
  BuildMedia;
  RefreshSettings;
end;

procedure TFormMain.MediaKindChanged(Sender: TObject);
begin
  if FRefreshing or (FConfig = nil) then
    Exit;
  if not StoreSettingValue(TControl(Sender), True) then
    Exit;
  FSettings.UpdateMediaOutput(FSelected, FMedia);
  BuildMedia;
  RefreshSettings;
end;

procedure TFormMain.FrontendChanged(Sender: TObject);
begin
  if FRefreshing or (FConfig = nil) then
    Exit;
  if not StoreSettingValue(TControl(Sender), True) then
    Exit;
  ApplyFrontendDefaults(FConfig.Root, True);
  BuildMedia;
  RefreshSettings;
end;

procedure TFormMain.SettingValueChanging(Sender: TObject);
begin
  if FRefreshing or (FConfig = nil) then
    Exit;
  // Keep the edited value before selection changes or Save can refresh the UI.
  // Dependent controls and previews are updated only when the edit is committed.
  StoreSettingValue(TControl(Sender), False);
end;

function TFormMain.StoreSettingValue(Control: TControl; Validate: Boolean): Boolean;
var
  Path: string;
  Spec: TArray<string>;
  Obj: TJSONObject;
  Value: TJSONValue;
  A: TJSONArray;
begin
  Result := False;
  Spec := Control.Hint.Split(['|']);
  if (Length(Spec) = 0) or (Spec[0] = '') then
    Exit;
  if (Length(Spec) > 2) and (Spec[1] = 'array') and (Spec[2] = '') then
    Spec[2] := '|';
  Path := Spec[0];
  Obj := BindingObject(Path, False);
  if Obj = nil then
    Exit;
  if (Length(Spec) > 1) and (Spec[1] = 'systems') then
  begin
    if not FSettings.ParseSecondarySystems(FSelected, FCatalog, TEdit(Control).Text, A) then
    begin
      if Validate then
        ShowMessage(SK.Locale.L('Введите действительные ID систем через запятую.'));
      Exit;
    end;
    Value := A;
  end
  else
    Value := ReadSettingValue(Control, Obj, Path, Spec, RollingButtonCacheTTL);
  if Value = nil then
    Exit;
  try
    Path := Spec[0];
    Obj := BindingObject(Path, True);
    if Obj = nil then
      Exit;
    JSet(Obj, Path, Value);
    Value := nil;
    FSettings.MarkOverride(FSelected, Spec[0]);
    Result := True;
  finally
    Value.Free;
  end;
end;

procedure TFormMain.BuildMedia;
var
  i, Kind: Integer;
  B: TButton;
  TextColumn: TLayout;
  L: TLabel;
  P: FMX.Objects.TPath;
  A: TJSONArray;
  Title: string;
begin
  PanelMediaInner.DeleteChildren;
  FreeAndNil(FEffective);
  FEffective := FConfig.EffectiveSystem(FSelected);
  A := FEffective.GetValue<TJSONArray>('Medias');
  FMedia := EnsureRange(FMedia, 0, Max(0, A.Count - 1));
  MediaCommandsHint.Visible := A.Count = 0;
  ButtonDeleteAll.Enabled := A.Count > 0;
  ButtonMediaMoveLeft.Enabled := (A.Count > 1) and (FMedia > 0);
  ButtonMediaMoveRight.Enabled := (A.Count > 1) and (FMedia < A.Count - 1);
  for i := 0 to A.Count - 1 do
  begin
    B := TButton.Create(Self);
    B.Parent := PanelMediaInner;
    B.Height := 70;
    B.Position.Y := i * 76; // Initial docking order only.
    B.Margins.Rect := RectF(4, 0, 8, 6);
    B.Align := TAlignLayout.Top;
    B.Tag := i;
    B.OnClick := SelectMedia;
    B.Text := '';
    B.StyleLookup := 'buttonstyle_subtle';
    B.StaysPressed := True;
    B.ApplyStyleLookup;
    B.IsPressed := i = FMedia;
    AddRowAccent(B, i = FMedia, False);
    Kind := JInt(A.Items[i], 'Type');
    Title := JStr(A.Items[i], 'Title');
    if (Title = '') and (Kind >= 0) and (Kind < RollingButtonMediaTypeSelector.Items.Count) then
      Title := RollingButtonMediaTypeSelector.Items[Kind];
    if (Kind = 0) and (JInt(A.Items[i], 'Image') < RollingButtonImageSelector.Items.Count) then
      Title := RollingButtonImageSelector.Items[Max(0, JInt(A.Items[i], 'Image'))];
    if Kind = 1 then
      Title := MixTitle(TPlatformPath.Combine(AppBase, 'Mixes/' +
          BuiltInMixFiles[EnsureRange(JInt(A.Items[i], 'InternalMix'), 0, 6)]))
    else if Kind = 2 then
      Title := MixTitle(JStr(A.Items[i], 'LocalMixFile'));
    P := FMX.Objects.TPath.Create(B);
    P.Parent := B;
    P.Align := TAlignLayout.Left;
    P.Width := 24;
    P.Margins.Rect := RectF(12, 14, 12, 32);
    P.Data.Assign(ButtonRefreshUserMixWinIcon.Data);
    P.Fill.Color := $FFE6E6E6;
    P.Stroke.Kind := TBrushKind.None;
    P.WrapMode := TPathWrapMode.Fit;
    P.HitTest := False;
    TextColumn := TLayout.Create(B);
    TextColumn.Parent := B;
    TextColumn.Align := TAlignLayout.Client;
    TextColumn.Padding.Rect := RectF(0, 6, 12, 8);
    TextColumn.HitTest := False;
    L := TLabel.Create(B);
    L.Parent := TextColumn;
    L.Align := TAlignLayout.Top;
    L.Height := 28;
    L.Text := Title;
    L.HitTest := False;
    L.TextSettings.Trimming := TTextTrimming.Character;
    L := TLabel.Create(B);
    L.Parent := TextColumn;
    L.Align := TAlignLayout.Client;
    L.Margins.Top := 2;
    L.Text := JStr(A.Items[i], 'OutputFolder');
    L.HitTest := False;
    L.Opacity := 0.65;
    L.TextSettings.Trimming := TTextTrimming.Character;
  end;
  PanelMediaInner.Height := Max(76, A.Count * 76);
end;

procedure TFormMain.SelectMedia(Sender: TObject);
begin
  if (FWorker <> nil) and not FWorker.Finished then
    Exit;
  FMedia := TControl(Sender).Tag;
  UpdateRowSelection;
  RefreshSettings;
end;

procedure TFormMain.ValidateAccount;
var
  Credentials, ArtworkSettings: TJSONObject;
  Base: string;
begin
  if FAccountBusy then
    Exit;
  SaveConfig;
  FAccountBusy := True;
  CheckBoxAnonymous.Enabled := False;
  EditLogin.Enabled := False;
  EditPassword.Enabled := False;
  ButtonTestAccount.Enabled := False;
  LabelThreadAvailable.Text := SK.Locale.L('Проверка подключения…');
  ServiceState.Text := SK.Locale.L('Проверка подключения…');
  AccountConnectionState.Text := SK.Locale.L('Проверка…');
  AccountStatusDot.Fill.Color := $FF60CDFF;
  AccountThreadsValue.Text := '—';
  AccountQuotaValue.Text := '—';
  LabelQuotaValue.Text := '—';
  LabelQuotaValue.Hint := '';
  Credentials := FConfig.Credentials.Clone as TJSONObject;
  JSet(Credentials, 'anonymous', TJSONBool.Create(JBool(FConfig.Root, 'Anonymous')));
  ArtworkSettings := FConfig.SystemAt(-1).Clone as TJSONObject;
  Base := WritableBase;
  FAccountTask := TTask.Run(
    procedure
    var
      Connection: TAccountConnection;
    begin
      try
        Connection := CheckAccountConnection(Credentials, ArtworkSettings, Base,
          procedure(Done, Total: Integer)
          begin
            if (Done mod 8 = 0) or (Done = Total) then
              TThread.Queue(nil, TThreadProcedure(
                procedure
                begin
                  ServiceState.Text := SK.Locale.L('Изображения платформ: %d / %d', [Done, Total]);
                end));
          end);
      finally
        Credentials.Free;
        ArtworkSettings.Free;
      end;
      System.Classes.TThread.Queue(nil, TThreadProcedure(
        procedure
        begin
          LabelThreadAvailable.Text := Connection.MessageText;
          AccountThreadsValue.Text := Connection.ThreadsText;
          AccountQuotaValue.Text := Connection.QuotaText;
          LabelQuotaValue.Text := Connection.QuotaText;
          LabelQuotaValue.Hint := SK.Locale.L('Запросы сегодня / суточный лимит ScreenScraper');
          if Connection.Verified then
          begin
            AccountConnectionState.Text := SK.Locale.L('Подключено');
            ServiceState.Text := SK.Locale.L('Подключено');
            AccountStatusDot.Fill.Color := $FF6CCB5F;
          end
          else
          begin
            AccountConnectionState.Text := SK.Locale.L('Ошибка подключения');
            ServiceState.Text := SK.Locale.L('Ошибка подключения');
            AccountStatusDot.Fill.Color := $FFF0B455;
          end;
          ButtonTestAccount.Enabled := True;
          FAccountBusy := False;
          FCatalog.Free;
          FCatalog := ReadJSON(Base + NativePath('Resources\systems.json'));
          if FCatalog = nil then
            FCatalog := ReadJSON(TPlatformPath.Combine(AppBase, SystemsCatalogPath));
          FillCatalog;
          BuildSystems;
          RefreshSettings;
        end));
    end);
end;

procedure TFormMain.Browse(Edit: TEdit; IsFile: Boolean);
var
  Folder, Key: string;
begin
  Key := 'GameAndRomFolder';
  if Edit = EditFrontEndPath then
    Key := 'FrontEndPath'
  else if Edit = EditMediaOutputFolder then
    Key := 'MediaOutputFolder'
  else if IsFile then
    Key := 'MixFolder';
  Folder := FConfig.DialogFolder(Key, Edit.Text);
  if IsFile then
  begin
    OpenDialog.Filter := SK.Locale.L('XML-файлы|*.xml|Все файлы|*.*');
    OpenDialog.InitialDir := Folder;
    if TFile.Exists(Edit.Text) then
      OpenDialog.FileName := Edit.Text
    else
      OpenDialog.FileName := '';
    if OpenDialog.Execute then
    begin
      Edit.Text := OpenDialog.FileName;
      FConfig.RememberFolder(Key, ExtractFilePath(OpenDialog.FileName))
    end;
  end
  else if SelectDirectory(SK.Locale.L('Выберите папку'), '', Folder) then
  begin
    Edit.Text := Folder;
    FConfig.RememberFolder(Key, Folder)
  end;
end;

procedure TFormMain.AddSystem;
var
  Setup: TFormSetup;
begin
  Setup := TFormSetup.Create(nil);
  try
    Setup.StyleBook := StyleBookWinUI3;
    if Setup.Execute(FConfig, FCatalog, False) then
    begin
      FSelected := FConfig.Root.GetValue<TJSONArray>('Systems').Count - 1;
      FillCatalog;
      BuildSystems;
      BuildMedia;
      RefreshSettings;
      SaveConfig;
    end;
  finally
    Setup.Free;
  end;
end;

procedure TFormMain.EnsureGroup(const Group: string; Bit: Integer);
begin
  FSettings.EnsureGroup(FSelected, Group, Bit);
end;

procedure TFormMain.PreviewMedia;
var
  Settings: TJSONObject;
  Medias: TJSONValue;
  Media: TJSONObject;
  FileName, Key, Title: string;
begin
  if FConfig = nil then
    Exit;
  Settings := FConfig.EffectiveSystem(FSelected);
  try
    Medias := JValue(Settings, 'Medias');
    if not (Medias is TJSONArray) or (FMedia < 0) or (FMedia >= TJSONArray(Medias).Count) then
    begin
      MediaPreviewImage.Bitmap.Clear(0);
      MediaPreviewCaption.Text := SK.Locale.L('Добавьте медиа для предпросмотра');
      Exit
    end;
    Media := TJSONArray(Medias).Items[FMedia] as TJSONObject;
    Key := Settings.ToJSON + '|' + FMedia.ToString + '|' + FSample.ToString + '|' + CurrentLocale;
    if Key = FPreviewKey then
      Exit;
    FPreviewKey := Key;
    MediaPreviewImage.Bitmap.SetSize(0, 0);
    try
      FileName := MediaPreview(Media, Settings, FCatalog, FSample, TPlatformPath.Combine(WritableBase, 'Cache/preview'));
      if FileName <> '' then
        MediaPreviewImage.Bitmap.LoadFromFile(FileName);
      Title := MediaSelectionTitle.Text;
      if JInt(Media, 'Type') = 1 then
        Title := MixTitle(TPlatformPath.Combine(AppBase, 'Mixes/' +
            BuiltInMixFiles[EnsureRange(JInt(Media, 'InternalMix'), 0, 6)]))
      else if JInt(Media, 'Type') = 2 then
        Title := MixTitle(JStr(Media, 'LocalMixFile'));
      MediaSelectionTitle.Text := Title;
      MediaPreviewCaption.Text := Title + sLineBreak + SK.Locale.L('Образец: %s', [MixSamplePrefixes[FSample mod 6]]);
      if FileName = '' then
        MediaPreviewCaption.Text := MediaPreviewCaption.Text + sLineBreak + SK.Locale.L('Изображение образца отсутствует');
    except
      on E: Exception do
        MediaPreviewCaption.Text := SK.Locale.L('Не удалось построить предпросмотр: %s', [E.Message]);
    end;
  finally
    Settings.Free
  end;
end;

function TFormMain.PrepareRequiredMedia: Integer;
begin
  Result := FSettings.PrepareRequiredMedia;
  if Result > 0 then
  begin
    BuildMedia;
    RefreshSettings;
  end;
end;

procedure TFormMain.CleanCache(Information, Media: Boolean);
var
  Config: TJSONObject;
  Base: string;
  SystemID: Integer;
begin
  if FCacheBusy then
    Exit;
  FCacheBusy := True;
  PanelSettings.Enabled := False;
  PanelLeftPan.Enabled := False;
  ButtonScrap.Enabled := False;
  CacheStatusLabel.Text := SK.Locale.L('Очистка кэша…');
  Config := FConfig.Root.Clone as TJSONObject;
  Base := WritableBase;
  SystemID := JInt(FConfig.SystemAt(FSelected), 'SystemId');
  FCacheTask := TTask.Run(
    procedure
    var
      ErrorText: string;
    begin
      ErrorText := '';
      try
        try
          ClearSystemCache(Base, Config, SystemID, Information, Media,
            procedure(Done, Total: Integer)
            var
              MessageText: string;
            begin
              if (Done mod 25 <> 0) and (Done <> Total) then
                Exit;
              MessageText := SK.Locale.L('Очистка кэша: %d / %d', [Done, Total]);
              TThread.Queue(nil, TThreadProcedure(
                procedure
                begin
                  CacheStatusLabel.Text := MessageText
                end));
            end);
        except
          on E: Exception do
            ErrorText := E.Message
        end;
      finally
        Config.Free
      end;
      TThread.Queue(nil, TThreadProcedure(
        procedure
        begin
          FCacheBusy := False;
          PanelSettings.Enabled := True;
          PanelLeftPan.Enabled := True;
          UpdateSelectionCount;
          if ErrorText = '' then
          begin
            if SystemID = 0 then
              CacheStatusLabel.Text := SK.Locale.L('Кэш всех систем очищен')
            else
              CacheStatusLabel.Text := SK.Locale.L('Кэш выбранной системы очищен');
          end
          else
            CacheStatusLabel.Text := SK.Locale.L('Ошибка очистки кэша: %s', [ErrorText]);
        end));
    end);
end;

procedure TFormMain.ImportConfigButtonClick(Sender: TObject);
begin
  if not CanExecuteAction then
    Exit;
  OpenDialog.Filter := SK.Locale.L('Открыть конфигурацию|*.json');
  OpenDialog.InitialDir := FConfig.DialogFolder('ConfigFolder', '');
  OpenDialog.FileName := '';
  if OpenDialog.Execute then
  begin
    FConfig.Load(OpenDialog.FileName);
    FConfig.RememberFolder('ConfigFolder', ExtractFilePath(OpenDialog.FileName));
    SetLocale(JStr(FConfig.Root, 'Culture', CurrentLocale));
    JSet(FConfig.Root, 'Culture', TJSONString.Create(CurrentLocale));
    FRefreshing := True;
    try
      ApplyLocale(Self)
    finally
      FRefreshing := False
    end;
    FSample := EnsureRange(JInt(FConfig.Root, 'SampleSet'), 0, 5);
    FSelected := -1;
    FMedia := 0;
    FillCatalog;
    BuildSystems;
    BuildMedia;
    RefreshSettings;
  end;
end;

procedure TFormMain.ExportConfigButtonClick(Sender: TObject);
begin
  if not CanExecuteAction then
    Exit;
  SaveDialog.Filter := SK.Locale.L('Сохранить конфигурацию|*.json');
  SaveDialog.InitialDir := FConfig.DialogFolder('ConfigFolder', '');
  SaveDialog.FileName := ConfigFileName;
  SaveDialog.DefaultExt := 'json';
  if SaveDialog.Execute then
  begin
    FConfig.RememberFolder('ConfigFolder', ExtractFilePath(SaveDialog.FileName));
    WriteJSON(SaveDialog.FileName, FConfig.Root);
  end;
end;

procedure TFormMain.ButtonRunWizardClick(Sender: TObject);
begin
  if not CanExecuteAction then
    Exit;
  RunWizard;
end;

procedure TFormMain.ButtonTestAccountClick(Sender: TObject);
begin
  if not CanExecuteAction then
    Exit;
  ValidateAccount;
end;

procedure TFormMain.ButtonScrapClick(Sender: TObject);
var
  O: TJSONObject;
  Required: Integer;
begin
  if not CanExecuteAction(True) then
    Exit;
  if FWorker <> nil then
  begin
    if not FWorker.Finished then
    begin
      FWorker.Terminate;
      ButtonScrap.Text := SK.Locale.L('Остановка…');
      Exit;
    end;
    FreeAndNil(FWorker);
    PanelLeftPan.Enabled := True;
    ImportConfigButton.Enabled := True;
    ExportConfigButton.Enabled := True;
    RefreshSettings;
    ProgressBarScrappingGames.Value := 0;
    LabelScrapingGameCount.Text := 'Games';
    ButtonScrap.Text := SK.Locale.L('Остановить');
    ShowPage(0);
    UpdateSelectionCount;
    Exit;
  end;
  Required := PrepareRequiredMedia;
  SaveConfig;
  FSettings.DiscardSnapshot;
  O := CreateRunConfig;
  try
    if O.GetValue<TJSONArray>('Systems').Count = 0 then
      Exit;
    FWorker := TScrapeWorker.Create(O, FConfig.Credentials, WritableBase, -1);
  finally
    O.Free
  end;
  BeginScrapeDisplay;
  if Required > 0 then
    FastColoredTextBoxLogging.Lines.Add(SK.Locale.L('Добавлено обязательных медиа Recalbox: %d', [Required]));
  ButtonScrap.Text := SK.Locale.L('Остановить');
  FWorker.Start;
end;

procedure TFormMain.ButtonAddSystemClick(Sender: TObject);
begin
  if not CanExecuteAction then
    Exit;
  AddSystem;
end;

procedure TFormMain.ButtonRemoveSystemClick(Sender: TObject);
begin
  if not CanExecuteAction then
    Exit;
  if FSelected < 0 then
    Exit;
  FConfig.Root.GetValue<TJSONArray>('Systems').Remove(FSelected).Free;
  FSelected := -1;
  BuildSystems;
  BuildMedia;
  RefreshSettings;
end;

procedure TFormMain.ButtonSourceFolderClick(Sender: TObject);
begin
  if not CanExecuteAction then
    Exit;
  Browse(EditSourceFolder);
  BuildSystems;
end;

procedure TFormMain.ButtonDestinationFolderClick(Sender: TObject);
begin
  if not CanExecuteAction then
    Exit;
  SaveDialog.Filter := SK.Locale.L('Файл списка игр|*.xml;*.dat;*.zip');
  SaveDialog.InitialDir := FConfig.DialogFolder('GamelistFolder', EditDestinationFolder.Text);
  if not EditDestinationFolder.Text.Contains('%') then
    SaveDialog.FileName := EditDestinationFolder.Text
  else
    SaveDialog.FileName := 'gamelist.xml';
  if SaveDialog.Execute then
  begin
    EditDestinationFolder.Text := SaveDialog.FileName;
    FConfig.RememberFolder('GamelistFolder', ExtractFilePath(SaveDialog.FileName));
  end;
end;

procedure TFormMain.ButtonMediaOutputFolderClick(Sender: TObject);
begin
  if not CanExecuteAction then
    Exit;
  Browse(EditMediaOutputFolder);
end;

procedure TFormMain.ButtonFrontEndPathClick(Sender: TObject);
begin
  if not CanExecuteAction then
    Exit;
  Browse(EditFrontEndPath);
end;

procedure TFormMain.ButtonUserProvidedMixClick(Sender: TObject);
begin
  if not CanExecuteAction then
    Exit;
  Browse(EditUserProvidedMix, True);
end;

procedure TFormMain.ButtonWebClick(Sender: TObject);
begin
  if not CanExecuteAction then
    Exit;
  OpenExternalURL(ScreenScraperWebsite);
end;

procedure TFormMain.ButtonRefreshUserMixClick(Sender: TObject);
begin
  if not CanExecuteAction then
    Exit;
  RefreshMediaPreview;
end;

procedure TFormMain.ButtonMediaMoveLeftClick(Sender: TObject);
begin
  MoveMedia(-1, False);
end;

procedure TFormMain.ButtonMediaMoveRightClick(Sender: TObject);
begin
  MoveMedia(1, False);
end;

procedure TFormMain.ButtonAddMediaClick(Sender: TObject);
var
  A: TJSONArray;
begin
  if not CanExecuteAction then
    Exit;
  EnsureGroup('Medias', 8);
  A := FConfig.SystemAt(FSelected).GetValue<TJSONArray>('Medias');
  A.AddElement(DefaultMedia(JInt(FConfig.Root, 'FrontEnd.Type'), A));
  FMedia := A.Count - 1;
  BuildMedia;
  RefreshSettings;
end;

procedure TFormMain.ButtonDeleteMediaClick(Sender: TObject);
var
  A: TJSONArray;
begin
  if not CanExecuteAction then
    Exit;
  EnsureGroup('Medias', 8);
  A := FConfig.SystemAt(FSelected).GetValue<TJSONArray>('Medias');
  if (FMedia >= 0) and (FMedia < A.Count) then
    A.Remove(FMedia).Free;
  FMedia := Max(0, A.Count - 1);
  BuildMedia;
  RefreshSettings;
end;

procedure TFormMain.ButtonDeleteAllClick(Sender: TObject);
var
  A: TJSONArray;
begin
  if not CanExecuteAction then
    Exit;
  EnsureGroup('Medias', 8);
  A := FConfig.SystemAt(FSelected).GetValue<TJSONArray>('Medias');
  while A.Count > 0 do
    A.Remove(0).Free;
  FMedia := 0;
  BuildMedia;
  RefreshSettings;
end;

procedure TFormMain.ButtonCopyFromMainClick(Sender: TObject);
var
  O: TJSONObject;
  Setup: TFormSetup;
begin
  if not CanExecuteAction then
    Exit;
  Setup := TFormSetup.Create(nil);
  try
    Setup.StyleBook := StyleBookWinUI3;
    O := Setup.ExecuteMedia(FConfig, FCatalog, FSelected);
    if O <> nil then
    try
      EnsureGroup('Medias', 8);
      AppendSystemMedia(FConfig.SystemAt(FSelected), O);
      BuildMedia;
      RefreshSettings;
    finally
      O.Free
    end;
  finally
    Setup.Free
  end;
end;

procedure TFormMain.RaisedButtonClearAllCachesClick(Sender: TObject);
begin
  if not CanExecuteAction then
    Exit;
  CleanCache(True, True);
end;

procedure TFormMain.RaisedButtonClearGameInformationCacheClick(Sender: TObject);
begin
  if not CanExecuteAction then
    Exit;
  CleanCache(True, False);
end;

procedure TFormMain.RaisedButtonClearMediaCacheClick(Sender: TObject);
begin
  if not CanExecuteAction then
    Exit;
  CleanCache(False, True);
end;

procedure TFormMain.RaisedButtonResetConfigClick(Sender: TObject);
begin
  if not CanExecuteAction then
    Exit;
  if TDialogServiceSync.MessageDialog(SK.Locale.L('Сбросить настройки выбранной системы? Для области «Все системы» будут восстановлены настройки платформ из каталога.'), TMsgDlgType.mtConfirmation, [TMsgDlgBtn.mbYes, TMsgDlgBtn.mbNo], TMsgDlgBtn.mbNo, 0) <> mrYes then
    Exit;
  FConfig.ResetSystemSettings(FSelected, FCatalog);
  BuildSystems;
  BuildMedia;
  RefreshSettings;
end;

function TFormMain.CanExecuteAction(AllowRunningWorker: Boolean): Boolean;
begin
  Result := not (FCacheBusy or FAccountBusy) and
    (AllowRunningWorker or (FWorker = nil) or FWorker.Finished);
end;

procedure TFormMain.RefreshMediaPreview;
begin
  FPreviewKey := '';
  BuildMedia;
  RefreshSettings;
  try
    PreviewMedia;
  except
    on E: Exception do
      ShowMessage(E.Message);
  end;
end;

procedure TFormMain.MoveMedia(Direction: Integer; ToEdge: Boolean);
begin
  if not CanExecuteAction then
    Exit;
  if FSettings.MoveMedia(FSelected, FMedia, Direction, ToEdge) then
  begin
    BuildMedia;
    RefreshSettings;
  end;
end;

procedure TFormMain.StatusTimerTimer(Sender: TObject);
var
  S: TScrapeStatus;
  Lines: TStringList;
begin
  PollFolderCount;
  if FWorker = nil then
    Exit;
  Lines := TStringList.Create;
  try
    FWorker.Snapshot(S, Lines);
    if Lines.Count > 0 then
      FastColoredTextBoxLogging.Lines.AddStrings(Lines);
  finally
    Lines.Free;
  end;
  ApplyScrapeStatus(S);
end;

procedure TFormMain.BeginScrapeDisplay;
begin
  ShowPage(1);
  FLogPresenter.Reset;
  FScrapePresenter.BeginScrape;
end;

procedure TFormMain.ApplyScrapeStatus(const S: TScrapeStatus);
begin
  FScrapePresenter.ApplyStatus(S);
end;

procedure TFormMain.ShowPage(Page: Integer);
begin
  if (Page < 0) or (Page >= PageTabControl.TabCount) then
    raise EArgumentOutOfRangeException.Create('Page');
  if PageTabControl.TabIndex = Page then
    PageTabChanged(nil)
  else
    PageTabControl.TabIndex := Page;
end;

procedure TFormMain.SyncFullLog;
begin
  FLogPresenter.SyncFullLog;
end;

procedure TFormMain.PageTabChanged(Sender: TObject);
var
  Page: Integer;
  ActiveButton: TButton;
  Icons: array[0..3] of FMX.Objects.TPath;
  i: Integer;
begin
  if (csLoading in ComponentState) or (csDestroying in ComponentState) or (FConfig = nil) then
    Exit;
  Page := PageTabControl.TabIndex;
  if Page < 0 then
    Exit;
  if Page = 1 then
    ScrapeLogChanged(nil);
  ScrapeStateBadge.Visible := Page = 1;
  Icons[0] := NavLibraryIcon;
  Icons[1] := NavScrapingIcon;
  Icons[2] := NavSettingsIcon;
  Icons[3] := NavLogIcon;
  for i := 0 to 3 do
    if i = Page then
      Icons[i].Fill.Color := $FF60CDFF
    else
      Icons[i].Fill.Color := $FFE6E6E6;
  ImportConfigButton.Visible := Page = 0;
  ExportConfigButton.Visible := Page = 0;
  NavLibrary.IsPressed := Page = 0;
  NavScraping.IsPressed := Page = 1;
  NavSettings.IsPressed := Page = 2;
  NavLog.IsPressed := Page = 3;
  case Page of
    0:
      ActiveButton := NavLibrary;
    1:
      ActiveButton := NavScraping;
    2:
      ActiveButton := NavSettings;
  else
    ActiveButton := NavLog;
  end;
  NavMarker.Parent := ActiveButton;
  NavMarker.BringToFront;
  if Page = 1 then
    ButtonScrap.Enabled := FWorker <> nil;
  case Page of
    0:
      begin
        PageTitle.Text := SK.Locale.L('Библиотека');
        PageSubtitle.Text := SK.Locale.L('Системы и папки с играми')
      end;
    1:
      begin
        PageTitle.Text := SK.Locale.L('Скраппинг');
        PageSubtitle.Text := FScrapePresenter.Subtitle
      end;
    2:
      begin
        PageTitle.Text := SK.Locale.L('Настройки');
        PageSubtitle.Text := SK.Locale.L('Параметры скраппинга и сохранения файлов');
        FSettings.BeginEdit;
      end;
    3:
      begin
        PageTitle.Text := SK.Locale.L('Журнал');
        PageSubtitle.Text := SK.Locale.L('События текущего сеанса скраппинга');
        SyncFullLog;
      end;
  end;
end;

function TFormMain.CanOpenSettings: Boolean;
begin
  Result := not FCacheBusy;
  if Result and (FWorker <> nil) and not FWorker.Finished then
  begin
    ShowPage(1);
    Result := False;
  end;
end;

procedure TFormMain.NavLibraryClick(Sender: TObject);
begin
  if not FCacheBusy then
    ShowPage(0);
end;

procedure TFormMain.NavScrapingClick(Sender: TObject);
begin
  if not FCacheBusy then
    ShowPage(1);
end;

procedure TFormMain.NavSettingsClick(Sender: TObject);
begin
  if CanOpenSettings then
    ShowPage(2);
end;

procedure TFormMain.NavLogClick(Sender: TObject);
begin
  if not FCacheBusy then
    ShowPage(3);
end;

procedure TFormMain.NavAccountClick(Sender: TObject);
begin
  if not CanOpenSettings then
    Exit;
  ShowPage(2);
  SettingsTabControl.ActiveTab := TabAccount;
end;

procedure TFormMain.ConfigureSystemClick(Sender: TObject);
begin
  if not CanOpenSettings then
    Exit;
  ShowPage(2);
  SettingsTabControl.ActiveTab := TabSource;
end;

procedure TFormMain.ConfigureAllClick(Sender: TObject);
begin
  if not CanOpenSettings then
    Exit;
  FSelected := -1;
  FMedia := 0;
  BuildSystems;
  BuildMedia;
  RefreshSettings;
  ShowPage(2);
end;

procedure TFormMain.StartScrapingClick(Sender: TObject);
begin
  if FCacheBusy then
    Exit;
  if (FWorker <> nil) and FWorker.Finished then
    FreeAndNil(FWorker);
  if FWorker <> nil then
  begin
    ShowPage(1);
    Exit;
  end;
  ButtonScrapClick(ButtonScrap);
end;

procedure TFormMain.ResetSettingsClick(Sender: TObject);
begin
  if CanOpenSettings then
    RaisedButtonResetConfigClick(Sender);
end;

procedure TFormMain.CancelSettingsClick(Sender: TObject);
begin
  if not CanOpenSettings then
    Exit;
  if FSettings.Rollback then
  begin
    SetLocale(JStr(FConfig.Root, 'Culture', 'ru'));
    FRefreshing := True;
    try
      ApplyLocale(Self)
    finally
      FRefreshing := False
    end;
    FSample := EnsureRange(JInt(FConfig.Root, 'SampleSet'), 0, 5);
  end;
  FSettings.DiscardSnapshot;
  FSelected := -1;
  FMedia := 0;
  BuildSystems;
  BuildMedia;
  RefreshSettings;
  ShowPage(0);
end;

procedure TFormMain.SaveSettingsClick(Sender: TObject);
begin
  if not CanOpenSettings then
    Exit;
  SaveConfig;
  FSettings.DiscardSnapshot;
  BuildSystems;
  UpdateInspector;
  ShowPage(0);
end;

procedure TFormMain.ExportLogClick(Sender: TObject);
begin
  if FCacheBusy then
    Exit;
  SaveDialog.Filter := SK.Locale.L('Текстовый журнал|*.txt');
  SaveDialog.DefaultExt := 'txt';
  SaveDialog.FileName := ExportLogFileName;
  SaveDialog.InitialDir := FConfig.DialogFolder('LogFolder', '');
  if SaveDialog.Execute then
  begin
    FConfig.RememberFolder('LogFolder', ExtractFilePath(SaveDialog.FileName));
    FastColoredTextBoxLogging.Lines.SaveToFile(SaveDialog.FileName, TEncoding.UTF8);
  end;
end;

function TFormMain.CreateRunConfig: TJSONObject;
begin
  Result := FSettings.CreateRunConfig(FCheckedSystems);
end;

procedure TFormMain.InspectorChanged(Sender: TObject);
var
  A: TJSONArray;
  Part: string;
begin
  if (csDestroying in ComponentState) or FRefreshing or (FConfig = nil) or (FSelected < 0) then
    Exit;
  if (FWorker <> nil) and not FWorker.Finished then
    Exit;
  if (InspectorFolder.Text.Trim = EditSourceFolder.Text.Trim) and
    (InspectorExtensions.Text.Replace(' ', '') = EditGamesAndRomsExtensions.Text.Replace(' ', '')) then
    Exit;
  EnsureGroup('GamesAndRoms', 2);
  JSet(FConfig.SystemAt(FSelected), 'GamesAndRoms.Path', TJSONString.Create(InspectorFolder.Text.Trim));
  A := TJSONArray.Create;
  for Part in InspectorExtensions.Text.Split([',', ';']) do
    if Part.Trim <> '' then
      A.Add(Part.Trim);
  JSet(FConfig.SystemAt(FSelected), 'GamesAndRoms.FileExtensions', A);
  SaveConfig;
  RefreshSettings;
  // Keep the clicked row alive; update its text without rebuilding controls.
end;

procedure TFormMain.InspectorBrowseClick(Sender: TObject);
begin
  Browse(InspectorFolder, False);
  InspectorChanged(InspectorFolder);
end;

procedure TFormMain.InspectorGlobalChanged(Sender: TObject);
begin
  if (csDestroying in ComponentState) or FRefreshing or (FConfig = nil) or (FSelected < 0) then
    Exit;
  if (FWorker <> nil) and not FWorker.Finished then
    Exit;
  if InspectorUseGlobal.IsChecked then
    JSet(FConfig.SystemAt(FSelected), 'Overriden', TJSONNumber.Create(0))
  else
  begin
    EnsureGroup('GameList', 1);
    EnsureGroup('GamesAndRoms', 2);
    EnsureGroup('MetaData', 4);
    EnsureGroup('Medias', 8);
    EnsureGroup('Miscellaneous', 16);
  end;
  SaveConfig;
  BuildMedia;
  RefreshSettings;
end;

procedure TFormMain.ScrapeLogChanged(Sender: TObject);
begin
  if (csDestroying in ComponentState) or (FLogPresenter = nil) then
    Exit;
  FLogPresenter.RefreshEvents;
end;

procedure TFormMain.ToggleGameFilters(Sender: TObject);
begin
  PanelAutoHide2.Visible := not PanelAutoHide2.Visible;
  PanelAutoExclude2.Visible := PanelAutoHide2.Visible;
  if PanelAutoHide2.Visible then
  begin
    PanelScrollGamelistInner.Height := 1056;
    GameFiltersChevron.RotationAngle := 270;
  end
  else
  begin
    PanelScrollGamelistInner.Height := 632;
    GameFiltersChevron.RotationAngle := 90;
  end;
end;

end.

