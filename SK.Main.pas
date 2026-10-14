unit SK.Main;

interface

uses
  System.SysUtils, System.Types, System.UITypes, System.Classes, System.Variants,
  System.JSON, System.IOUtils, System.Hash, System.Math, System.DateUtils,
  System.Threading, FMX.Types, FMX.Controls, FMX.Forms, FMX.Graphics,
  FMX.Dialogs, FMX.StdCtrls, FMX.Controls.Presentation, FMX.Layouts, FMX.Objects,
  FMX.Edit, FMX.ListBox, FMX.TabControl, FMX.Memo, FMX.ScrollBox,
  FMX.DialogService, FMX.DialogService.Sync, FMX.Styles, FMX.Filter.Effects,
  SK.Platform, System.Generics.Collections, SK.Core, SK.Engine, SK.Setup, SK.Mix,
  SK.Frontend, SK.Data, SK.Catalog, SK.Cache, SK.Preview, SK.Locale, FMX.Memo.Types;

type
  TFolderItemCount = record
    Files, Folders: Int64;
    Error: string;
  end;

  TFormMain = class(TForm)
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
    LibraryInspectorSpacer: TLayout;
    OpenPlatformLibrary: TButton;
    LibrarySearchLayout: TLayout;
    LibraryActionLayout: TLayout;
    LibraryCommandsLayout: TLayout;
    LibraryBodyLayout: TLayout;
    LibraryHeaderSelectCell: TLayout;
    LibraryHeaderSystemCell: TLayout;
    LibraryHeaderPathCell: TLayout;
    LibraryHeaderSettingsCell: TLayout;
    LibraryHeaderGrid: TGridPanelLayout;
    SettingsScopeLayout: TLayout;
    ScrapeProgressLayout: TLayout;
    ScrapeMediaColumns: TGridPanelLayout;
    ScrapeLogLayout: TLayout;
    ScrapeLogHeaderLayout: TLayout;
    MediaBodyLayout: TLayout;
    MediaEditorLayout: TLayout;
    AppTitleFrame: TLayout;
    AppTitleRow: TLayout;
    AppSubtitleFrame: TLayout;
    AppSubtitleRow: TLayout;
    NavLibraryFrame: TLayout;
    NavLibraryRow: TLayout;
    NavLibraryIconFrame: TLayout;
    NavLibraryIconRow: TLayout;
    NavScrapingFrame: TLayout;
    NavScrapingRow: TLayout;
    NavScrapingIconFrame: TLayout;
    NavScrapingIconRow: TLayout;
    NavSettingsFrame: TLayout;
    NavSettingsRow: TLayout;
    NavSettingsIconFrame: TLayout;
    NavSettingsIconRow: TLayout;
    NavLogFrame: TLayout;
    NavLogRow: TLayout;
    NavLogIconFrame: TLayout;
    NavLogIconRow: TLayout;
    ServiceTitleFrame: TLayout;
    ServiceTitleRow: TLayout;
    ServiceStateFrame: TLayout;
    ServiceStateRow: TLayout;
    NavAccountFrame: TLayout;
    NavAccountRow: TLayout;
    NavigationEdgeFrame: TLayout;
    ServiceDividerFrame: TLayout;
    ServiceDividerRow: TLayout;
    ScrapeStateBadgeFrame: TLayout;
    ScrapeStateBadgeRow: TLayout;
    ScrapeStateTextFrame: TLayout;
    PageTitleFrame: TLayout;
    PageSubtitleFrame: TLayout;
    IconAddSystemFrame: TLayout;
    IconAddSystemRow: TLayout;
    LibraryHeaderSurfaceFrame: TLayout;
    PictureBoxScreenscraperFrame: TLayout;
    PictureBoxScreenscraperRow: TLayout;
    LabelCourtesyOfFrame: TLayout;
    LabelCourtesyOfRow: TLayout;
    InspectorTitleFrame: TLayout;
    InspectorTitleRow: TLayout;
    InspectorIDFrame: TLayout;
    InspectorIDRow: TLayout;
    InspectorFolderLabelFrame: TLayout;
    InspectorFolderLabelRow: TLayout;
    InspectorFolderFrame: TLayout;
    InspectorFolderRow: TLayout;
    InspectorExtensionsLabelFrame: TLayout;
    InspectorExtensionsLabelRow: TLayout;
    InspectorExtensionsFrame: TLayout;
    InspectorExtensionsRow: TLayout;
    InspectorOverrideFrame: TLayout;
    InspectorOverrideRow: TLayout;
    ConfigureSystemFrame: TLayout;
    ConfigureSystemRow: TLayout;
    ConfigureSystemAccentIconFrame: TLayout;
    ConfigureSystemAccentIconRow: TLayout;
    ButtonRemoveSystemFrame: TLayout;
    ButtonRemoveSystemRow: TLayout;
    InspectorProviderFrame: TLayout;
    InspectorProviderRow: TLayout;
    InspectorSettingsDividerFrame: TLayout;
    InspectorSettingsDividerRow: TLayout;
    InspectorProviderDividerFrame: TLayout;
    InspectorProviderDividerRow: TLayout;
    InspectorBrowseFrame: TLayout;
    InspectorUseGlobalFrame: TLayout;
    InspectorProviderValueFrame: TLayout;
    InspectorItemCountFrame: TLayout;
    ConfigureAllAccentIconFrame: TLayout;
    ConfigureAllAccentIconRow: TLayout;
    LabelRequestsValueFrame: TLayout;
    LabelRequestsValueRow: TLayout;
    LabelDownloadedMediaFrame: TLayout;
    LabelDownloadedMediaRow: TLayout;
    PictureBoxGearsFrame: TLayout;
    PictureBoxGearsRow: TLayout;
    LabelCachedFrame: TLayout;
    LabelCachedRow: TLayout;
    LabelFavoriteGamesValueFrame: TLayout;
    LabelFavoriteGamesValueRow: TLayout;
    LabelCachedValueFrame: TLayout;
    LabelCachedValueRow: TLayout;
    LabelDownloadedMediaValueFrame: TLayout;
    LabelDownloadedMediaValueRow: TLayout;
    LabelHiddenGamesFrame: TLayout;
    LabelHiddenGamesRow: TLayout;
    LabelRequestsFrame: TLayout;
    LabelRequestsRow: TLayout;
    LabelFavoriteGamesFrame: TLayout;
    LabelFavoriteGamesRow: TLayout;
    LabelHiddenGamesValueFrame: TLayout;
    LabelHiddenGamesValueRow: TLayout;
    ProgressBarScrapingSystemsFrame: TLayout;
    PictureBoxPhotoFrame: TLayout;
    PictureBoxPhotoRow: TLayout;
    LabelSystemNameFrame: TLayout;
    LabelScrapingSystemCountFrame: TLayout;
    LabelScrapingSystemCountRow: TLayout;
    LabelScrapingGameCountFrame: TLayout;
    LabelScrapingGameCountRow: TLayout;
    ScrapePercentFrame: TLayout;
    ScrapePercentRow: TLayout;
    ProgressBarScrappingGamesFrame: TLayout;
    LabelElapsedFrame: TLayout;
    LabelElapsedRow: TLayout;
    LabelElapsedValueFrame: TLayout;
    LabelElapsedValueRow: TLayout;
    LabelEstimatedTimeFrame: TLayout;
    LabelEstimatedTimeRow: TLayout;
    LabelEstimatedTimeValueFrame: TLayout;
    LabelEstimatedTimeValueRow: TLayout;
    LabelScrapedGamesFrame: TLayout;
    LabelScrapedGamesValueFrame: TLayout;
    MetricGameNotFoundDividerFrame: TLayout;
    LabelGameNotFoundFrame: TLayout;
    LabelGameNotFoundValueFrame: TLayout;
    MetricErrorsDividerFrame: TLayout;
    LabelErrorsFrame: TLayout;
    LabelErrorsValueFrame: TLayout;
    MetricSavedMediaDividerFrame: TLayout;
    LabelSavedMediaFrame: TLayout;
    LabelSavedMediaValueFrame: TLayout;
    MetricQuotaDividerFrame: TLayout;
    LabelQuotaFrame: TLayout;
    LabelQuotaValueFrame: TLayout;
    WorkerSurfaceFrame: TLayout;
    PictureBoxWorkEnginesFrame: TLayout;
    PictureBoxWorkEnginesRow: TLayout;
    LabelWorkEnginesFrame: TLayout;
    LabelWorkEnginesRow: TLayout;
    PanelScrapingEnginesFrame: TLayout;
    WorkerHeaderDividerFrame: TLayout;
    RecentMediaTitleFrame: TLayout;
    RecentMediaTitleRow: TLayout;
    PreviewGridFrame: TLayout;
    RecentMediaNoteFrame: TLayout;
    OpenFullLogAccentIconFrame: TLayout;
    OpenFullLogAccentIconRow: TLayout;
    FastColoredTextBoxLoggingFrame: TLayout;
    LabelMediaPercentFrame: TLayout;
    LabelMediaCoverageFrame: TLayout;
    LabelMediaCoverageRow: TLayout;
    ProgressBarMediaFoundPercentFrame: TLayout;
    MediaCoverageDetailFrame: TLayout;
    ScrapeFooterSurfaceFrame: TLayout;
    ScrapeSummaryFrame: TLayout;
    ButtonScrapFrame: TLayout;
    ButtonScrapRow: TLayout;
    IconScrapFrame: TLayout;
    IconScrapRow: TLayout;
    IconStopFrame: TLayout;
    IconStopRow: TLayout;
    ScrapeFooterTopBorderFrame: TLayout;
    SettingsTabBaselineFrame: TLayout;
    PanelFrontEndCardFrame: TLayout;
    DividerFrontEndFrame: TLayout;
    DividerFrontEndRow: TLayout;
    PictureBoxFrontEndFrame: TLayout;
    PictureBoxFrontEndRow: TLayout;
    PanelFrontEndV3TitleFrame: TLayout;
    LabelFrontEndFrame: TLayout;
    RollingButtonFrontEndFrame: TLayout;
    RollingButtonFrontEndRow: TLayout;
    LabelFrontEndHostFrame: TLayout;
    EditFrontEndHostFrame: TLayout;
    EditFrontEndHostRow: TLayout;
    LabelFrontEndPathFrame: TLayout;
    EditFrontEndPathFrame: TLayout;
    CheckBoxKillFrontEndFrame: TLayout;
    ButtonFrontEndPathFrame: TLayout;
    ButtonFrontEndPathRow: TLayout;
    LabelGameRomsSpecificConfigWarningFrame: TLayout;
    LabelGameRomsSpecificConfigWarningRow: TLayout;
    CheckBoxGameRomsSpecificConfigFrame: TLayout;
    CheckBoxGameRomsSpecificConfigRow: TLayout;
    PanelSourceFolderCardFrame: TLayout;
    PanelSourceFolderV3TitleFrame: TLayout;
    LabelSystemSelectFrame: TLayout;
    RollingButtonSystemSelectFrame: TLayout;
    LabelSourceFolderFrame: TLayout;
    EditSourceFolderFrame: TLayout;
    LabelGamesAndRomAllSystemsFrame: TLayout;
    ButtonSourceFolderFrame: TLayout;
    ButtonSourceFolderRow: TLayout;
    PanelGameFileExtensionsCardFrame: TLayout;
    PanelGameFileExtensionsV3TitleFrame: TLayout;
    LabelSourceExtensionsFrame: TLayout;
    EditGamesAndRomsExtensionsFrame: TLayout;
    ExtensionsHelpFrame: TLayout;
    PanelLaunchBoxPlatformCardFrame: TLayout;
    LabelLaunchBoxPlaformFrame: TLayout;
    EditLaunchBoxPlatformFrame: TLayout;
    LaunchBoxHelpFrame: TLayout;
    CheckBoxGameListSpecificConfigFrame: TLayout;
    CheckBoxGameListSpecificConfigRow: TLayout;
    LabelGameListSpecificConfigWarningFrame: TLayout;
    LabelGameListSpecificConfigWarningRow: TLayout;
    PanelGameListTypeCardFrame: TLayout;
    PanelGameListTypeV3TitleFrame: TLayout;
    materialLabel1Frame: TLayout;
    RollingButtonGamelistFrame: TLayout;
    RollingButtonGamelistRow: TLayout;
    ExistingListLabelFrame: TLayout;
    RollingButtonGamelistBehaviorFrame: TLayout;
    RollingButtonGamelistBehaviorRow: TLayout;
    CheckBoxOptimizeGameFileFrame: TLayout;
    CheckBoxOptimizeGameFileRow: TLayout;
    PanelDestinationFolderFrame: TLayout;
    PanelDestinationFolderCardFrame: TLayout;
    LabelDestinationFolderFrame: TLayout;
    EditDestinationFolderFrame: TLayout;
    LabelFolderEntriesFrame: TLayout;
    RollingButtonProcessFoldersFrame: TLayout;
    ButtonDestinationFolderFrame: TLayout;
    ButtonDestinationFolderRow: TLayout;
    PanelAutoFavoriteCardFrame: TLayout;
    LabelAutoFavoriteFrame: TLayout;
    CheckBoxFavoriteRatingFrame: TLayout;
    RollingButtonAutoFavoriteRatingFrame: TLayout;
    CheckBoxFavoriteContainingWordsFrame: TLayout;
    EditFavoriteContainingWordsFrame: TLayout;
    CheckBoxAutoFavoriteTopStaffFrame: TLayout;
    FavoriteHelpFrame: TLayout;
    PanelAutoHideCardFrame: TLayout;
    LabelAutoHideFrame: TLayout;
    CheckBoxHideNonScrapedFrame: TLayout;
    CheckBoxHideContainingWordsFrame: TLayout;
    EditHideContainingWordsFrame: TLayout;
    CheckBoxAutoHiddenExtentionFrame: TLayout;
    EditAutoHiddenExtentionsFrame: TLayout;
    PanelAutoExcludeCardFrame: TLayout;
    LabelAutoExcludeFrame: TLayout;
    CheckBoxExcludeNonScrapedFrame: TLayout;
    CheckBoxExcludeContainingWordsFrame: TLayout;
    EditExcludeContainingWordsFrame: TLayout;
    GameFiltersChevronFrame: TLayout;
    GameFiltersChevronRow: TLayout;
    PanelAutoHide2CardFrame: TLayout;
    PanelAutoHide2V3TitleFrame: TLayout;
    CheckBoxAutoHideAlternateFrame: TLayout;
    CheckBoxAutoHideAlternateRow: TLayout;
    CheckBoxAutoHideUnlicensedFrame: TLayout;
    CheckBoxAutoHideUnlicensedRow: TLayout;
    CheckBoxAutoHidePrototypeFrame: TLayout;
    CheckBoxAutoHidePrototypeRow: TLayout;
    CheckBoxAutoHideBetaFrame: TLayout;
    CheckBoxAutoHideBetaRow: TLayout;
    CheckBoxAutoHideHackFrame: TLayout;
    CheckBoxAutoHideHackRow: TLayout;
    CheckBoxAutoHideSupportFrame: TLayout;
    CheckBoxAutoHideSupportRow: TLayout;
    CheckBoxAutoHideCloneFrame: TLayout;
    CheckBoxAutoHideCloneRow: TLayout;
    CheckBoxAutoHideBestFrame: TLayout;
    CheckBoxAutoHideBestRow: TLayout;
    CheckBoxAutoHideTranslationFrame: TLayout;
    CheckBoxAutoHideTranslationRow: TLayout;
    CheckBoxAutoHideDemoFrame: TLayout;
    CheckBoxAutoHideDemoRow: TLayout;
    CheckBoxAutoHideRegionsFrame: TLayout;
    EditAutoHideRegionsFrame: TLayout;
    PanelAutoExclude2CardFrame: TLayout;
    PanelAutoExclude2V3TitleFrame: TLayout;
    CheckBoxAutoExcludeHackFrame: TLayout;
    CheckBoxAutoExcludeHackRow: TLayout;
    CheckBoxAutoExcludePrototypeFrame: TLayout;
    CheckBoxAutoExcludePrototypeRow: TLayout;
    CheckBoxAutoExcludeCloneFrame: TLayout;
    CheckBoxAutoExcludeCloneRow: TLayout;
    CheckBoxAutoExcludeBestFrame: TLayout;
    CheckBoxAutoExcludeBestRow: TLayout;
    CheckBoxAutoExcludeTranslationFrame: TLayout;
    CheckBoxAutoExcludeTranslationRow: TLayout;
    CheckBoxAutoExcludeAlternateFrame: TLayout;
    CheckBoxAutoExcludeAlternateRow: TLayout;
    CheckBoxAutoExcludeDemoFrame: TLayout;
    CheckBoxAutoExcludeDemoRow: TLayout;
    CheckBoxAutoExcludeBetaFrame: TLayout;
    CheckBoxAutoExcludeBetaRow: TLayout;
    CheckBoxAutoExcludeUnlicensedFrame: TLayout;
    CheckBoxAutoExcludeUnlicensedRow: TLayout;
    CheckBoxAutoExcludeSupportFrame: TLayout;
    CheckBoxAutoExcludeSupportRow: TLayout;
    CheckBoxAutoExcludeRegionsFrame: TLayout;
    EditAutoExcludeRegionsFrame: TLayout;
    MetadataCaseCardFrame: TLayout;
    PanelTextCaseTitleFrame: TLayout;
    PanelTextCaseTitleCardFrame: TLayout;
    LabelTextCaseFrame: TLayout;
    LabelTextCaseRow: TLayout;
    PictureBoxMetaDataFrame: TLayout;
    PictureBoxMetaDataRow: TLayout;
    LabelMetadataSpecificConfigWarningFrame: TLayout;
    LabelMetadataSpecificConfigWarningRow: TLayout;
    CheckBoxMetadataSpecificConfigFrame: TLayout;
    CheckBoxMetadataSpecificConfigRow: TLayout;
    TextCaseGroupTitleFrame: TLayout;
    TextCaseHelpFrame: TLayout;
    PanelNameCaseCardFrame: TLayout;
    PanelDescriptionCaseCardFrame: TLayout;
    PanelGenreCaseCardFrame: TLayout;
    NameDescriptionGroupTitleFrame: TLayout;
    CheckBoxMoveArticlesFrame: TLayout;
    CheckBoxMoveArticlesRow: TLayout;
    CheckBoxUseFilenameRegionsFrame: TLayout;
    CheckBoxUseFilenameRegionsRow: TLayout;
    CheckBoxNameDecorationKeepUndecoratedFilenameFrame: TLayout;
    CheckBoxNameDecorationKeepUndecoratedFilenameRow: TLayout;
    CheckBoxNameDecorationKeepFilenameDecorationFrame: TLayout;
    CheckBoxNameDecorationKeepFilenameDecorationRow: TLayout;
    CheckBoxDoNotIncludeSynopsisFrame: TLayout;
    CheckBoxDoNotIncludeSynopsisRow: TLayout;
    CheckBoxMoveArticlesHelpFrame: TLayout;
    CheckBoxUseFilenameRegionsHelpFrame: TLayout;
    CheckBoxNameDecorationKeepUndecoratedFilenameHelpFrame: TLayout;
    CheckBoxNameDecorationKeepFilenameDecorationHelpFrame: TLayout;
    CheckBoxDoNotIncludeSynopsisHelpFrame: TLayout;
    PanelNameDecorationsCardFrame: TLayout;
    LabelNameDecorationsFrame: TLayout;
    LabelNameDecorationsRow: TLayout;
    PanelNameDecorationsV3TitleFrame: TLayout;
    DecorationGridFrame: TLayout;
    MediaStorageSurfaceFrame: TLayout;
    MediaStorageTitleFrame: TLayout;
    LabelMediaOutputFolderFrame: TLayout;
    EditMediaOutputFolderFrame: TLayout;
    ButtonMediaOutputFolderFrame: TLayout;
    ButtonMediaOutputFolderRow: TLayout;
    PanelLinkSelectionFrame: TLayout;
    LabelLinkSelectionFrame: TLayout;
    LabelLinkSelectionRow: TLayout;
    MediaXMLFieldFrame: TLayout;
    MediaXMLFieldRow: TLayout;
    RadioButtonNodeLinkFrame: TLayout;
    RadioButtonNodeLinkRow: TLayout;
    RadioButtonNoLinkFrame: TLayout;
    RadioButtonNoLinkRow: TLayout;
    CheckBoxOptimizeMediaStorageFrame: TLayout;
    CheckBoxOptimizeMediaStorageRow: TLayout;
    CheckBoxOptimizeMediaStorageCaptionFrame: TLayout;
    CheckBoxMediaEmptyOutputFolderFrame: TLayout;
    CheckBoxMediaEmptyOutputFolderRow: TLayout;
    CheckBoxMediaEmptyOutputFolderCaptionFrame: TLayout;
    MediaSourceSurfaceFrame: TLayout;
    MediaSourceTitleFrame: TLayout;
    LabelMediaTypeFrame: TLayout;
    RollingButtonMediaTypeSelectorFrame: TLayout;
    MediaVariantLabelFrame: TLayout;
    RollingButtonInternalMixSelectorFrame: TLayout;
    RollingButtonImageSelectorFrame: TLayout;
    EditUserProvidedMixFrame: TLayout;
    ButtonUserProvidedMixFrame: TLayout;
    ButtonUserProvidedMixRow: TLayout;
    PictureBoxMediaSubTypeFrame: TLayout;
    PictureBoxMediaSubTypeRow: TLayout;
    ButtonMediaTypeLeftFrame: TLayout;
    ButtonMediaTypeLeftRow: TLayout;
    ButtonMediaTypeRightFrame: TLayout;
    ButtonMediaTypeRightRow: TLayout;
    LabelMediaSpecificConfigWarningFrame: TLayout;
    LabelMediaSpecificConfigWarningRow: TLayout;
    CheckBoxMediaSpecificConfigFrame: TLayout;
    CheckBoxMediaSpecificConfigRow: TLayout;
    MediaListSurfaceFrame: TLayout;
    ButtonMediaLeftFrame: TLayout;
    ButtonMediaLeftRow: TLayout;
    ButtonCycleMediaSamplesFrame: TLayout;
    ButtonCycleMediaSamplesRow: TLayout;
    ButtonMediaMoveToLeftFrame: TLayout;
    ButtonMediaMoveToLeftRow: TLayout;
    ButtonMediaMoveToRightFrame: TLayout;
    ButtonMediaMoveToRightRow: TLayout;
    ButtonMediaRightFrame: TLayout;
    ButtonMediaRightRow: TLayout;
    LabelScrapedMediaListFrame: TLayout;
    LabelScrapedMediaListRow: TLayout;
    ButtonAddMediaFrame: TLayout;
    ButtonAddMediaRow: TLayout;
    IconAddMediaFrame: TLayout;
    IconAddMediaRow: TLayout;
    PanelMediaOuterFrame: TLayout;
    ButtonMediaMoveLeftFrame: TLayout;
    ButtonMediaMoveLeftRow: TLayout;
    ButtonMediaMoveLeftWinIconFrame: TLayout;
    ButtonMediaMoveLeftWinIconRow: TLayout;
    ButtonMediaMoveRightFrame: TLayout;
    ButtonMediaMoveRightRow: TLayout;
    ButtonMediaMoveRightWinIconFrame: TLayout;
    ButtonMediaMoveRightWinIconRow: TLayout;
    ButtonDeleteMediaFrame: TLayout;
    ButtonDeleteMediaRow: TLayout;
    ButtonDeleteMediaWinIconFrame: TLayout;
    ButtonDeleteMediaWinIconRow: TLayout;
    ButtonCopyFromMainFrame: TLayout;
    ButtonCopyFromMainRow: TLayout;
    ButtonCopyFromMainWinIconFrame: TLayout;
    ButtonCopyFromMainWinIconRow: TLayout;
    ButtonRefreshUserMixFrame: TLayout;
    ButtonRefreshUserMixRow: TLayout;
    ButtonRefreshUserMixWinIconFrame: TLayout;
    ButtonRefreshUserMixWinIconRow: TLayout;
    ButtonDeleteAllFrame: TLayout;
    ButtonDeleteAllRow: TLayout;
    MediaCommandsHintFrame: TLayout;
    MediaCommandsHintRow: TLayout;
    MediaListHeaderDividerFrame: TLayout;
    MediaResizeSurfaceFrame: TLayout;
    ResizeTitleFrame: TLayout;
    ResizeTitleRow: TLayout;
    CheckBoxResizeWidthFrame: TLayout;
    CheckBoxResizeWidthRow: TLayout;
    EditResizeWidthFrame: TLayout;
    EditResizeWidthRow: TLayout;
    CheckBoxResizeHeightFrame: TLayout;
    CheckBoxResizeHeightRow: TLayout;
    EditResizeHeightFrame: TLayout;
    EditResizeHeightRow: TLayout;
    CheckBoxKeepImageRatioFrame: TLayout;
    CheckBoxKeepImageRatioRow: TLayout;
    ResizeWidthUnitFrame: TLayout;
    ResizeHeightUnitFrame: TLayout;
    PanelResetConfigFrame: TLayout;
    LabelConfigurationManagementFrame: TLayout;
    LabelConfigurationManagementRow: TLayout;
    RaisedButtonResetConfigFrame: TLayout;
    RaisedButtonResetConfigRow: TLayout;
    LabelMiscellaneousSpecificConfigWarningFrame: TLayout;
    LabelMiscellaneousSpecificConfigWarningRow: TLayout;
    CheckBoxMiscellaneousSpecificConfigFrame: TLayout;
    CheckBoxMiscellaneousSpecificConfigRow: TLayout;
    SearchLocaleGroupTitleFrame: TLayout;
    PanelMethodFrame: TLayout;
    PanelMethodCardFrame: TLayout;
    ButtonMethodLeftFrame: TLayout;
    ButtonMethodLeftRow: TLayout;
    ButtonMethodRightFrame: TLayout;
    ButtonMethodRightRow: TLayout;
    LabelMethodFrame: TLayout;
    RollingButtonMethodFrame: TLayout;
    RollingButtonMethodRow: TLayout;
    PanelCountryPreferencesFrame: TLayout;
    PanelCountryPreferencesCardFrame: TLayout;
    ButtonClassificationLeftFrame: TLayout;
    ButtonClassificationLeftRow: TLayout;
    ButtonClassificationRightFrame: TLayout;
    ButtonClassificationRightRow: TLayout;
    LabelLanguageFrame: TLayout;
    EditLanguagesFrame: TLayout;
    EditLanguagesRow: TLayout;
    LabelRegionFrame: TLayout;
    EditRegionsFrame: TLayout;
    EditRegionsRow: TLayout;
    LabelClassificationFrame: TLayout;
    RollingButtonClassificationFrame: TLayout;
    RollingButtonClassificationRow: TLayout;
    CheckBoxRomRegionFirstFrame: TLayout;
    CheckBoxRegionStrictModeFrame: TLayout;
    LanguagesHelpFrame: TLayout;
    LanguagesHelpRow: TLayout;
    RegionsHelpFrame: TLayout;
    RegionsHelpRow: TLayout;
    PanelLogsCardFrame: TLayout;
    LogOptionsTitleFrame: TLayout;
    CheckBoxSaveLogsFrame: TLayout;
    CheckBoxSaveLogsRow: TLayout;
    CheckBoxSaveLogsCaptionFrame: TLayout;
    CheckBoxVerboseLoggingFrame: TLayout;
    CheckBoxVerboseLoggingRow: TLayout;
    CheckBoxVerboseLoggingCaptionFrame: TLayout;
    CheckBoxSaveMissingFrame: TLayout;
    CheckBoxSaveMissingRow: TLayout;
    CheckBoxSaveMissingCaptionFrame: TLayout;
    PanelNetworkCardFrame: TLayout;
    ButtonHTTPTriesLeftFrame: TLayout;
    ButtonHTTPTriesLeftRow: TLayout;
    ButtonHTTPTriesRightFrame: TLayout;
    ButtonHTTPTriesRightRow: TLayout;
    ButtonCacheTTLRightFrame: TLayout;
    ButtonCacheTTLRightRow: TLayout;
    ButtonCacheTTLLeftFrame: TLayout;
    ButtonCacheTTLLeftRow: TLayout;
    NetworkTitleFrame: TLayout;
    LabelHTTPTriesFrame: TLayout;
    RollingButtonHTTPTriesFrame: TLayout;
    LabelCacheTTLFrame: TLayout;
    RollingButtonCacheTTLFrame: TLayout;
    ReuseExistingMediaCaptionFrame: TLayout;
    ReuseExistingMediaSwitchFrame: TLayout;
    ReuseExistingMediaSwitchRow: TLayout;
    PanelCacheManagementCardFrame: TLayout;
    LabelCacheManagementFrame: TLayout;
    LabelCacheManagementRow: TLayout;
    PanelCacheManagementV3TitleFrame: TLayout;
    CacheSafetyNoteFrame: TLayout;
    CacheActionGridFrame: TLayout;
    AccountServiceCardFrame: TLayout;
    AccountCredentialsCardFrame: TLayout;
    PictureBoxScreenScraperShotFrame: TLayout;
    PictureBoxScreenScraperShotRow: TLayout;
    LabelJoinUsFrame: TLayout;
    LabelJoinUsRow: TLayout;
    ButtonDiscordFrame: TLayout;
    ButtonDiscordRow: TLayout;
    PictureBoxLoginIconFrame: TLayout;
    PictureBoxLoginIconRow: TLayout;
    PictureBoxPasswordIconFrame: TLayout;
    PictureBoxPasswordIconRow: TLayout;
    AccountTitleFrame: TLayout;
    AccountDescriptionFrame: TLayout;
    AccountLoginLabelFrame: TLayout;
    EditLoginFrame: TLayout;
    AccountPasswordLabelFrame: TLayout;
    EditPasswordFrame: TLayout;
    ButtonTestAccountFrame: TLayout;
    AccountCredentialNoteFrame: TLayout;
    AccountStatusTitleFrame: TLayout;
    AccountConnectionStateFrame: TLayout;
    AccountStatusDotFrame: TLayout;
    AccountStatusDotRow: TLayout;
    LabelThreadAvailableFrame: TLayout;
    AccountThreadsLabelFrame: TLayout;
    AccountThreadsValueFrame: TLayout;
    AccountQuotaLabelFrame: TLayout;
    AccountQuotaValueFrame: TLayout;
    LabelSSAdvertisementFrame: TLayout;
    LabelSSAdvertisementRow: TLayout;
    ServiceAboutTitleFrame: TLayout;
    ServiceAboutNoteFrame: TLayout;
    ButtonWebFrame: TLayout;
    ButtonWebRow: TLayout;
    SettingsFooterSurfaceFrame: TLayout;
    ResetSettingsFrame: TLayout;
    ResetSettingsRow: TLayout;
    CancelSettingsFrame: TLayout;
    CancelSettingsRow: TLayout;
    SaveSettingsFrame: TLayout;
    SaveSettingsRow: TLayout;
    SettingsFooterTopBorderFrame: TLayout;
    FullLogFrame: TLayout;
    ExportLogFrame: TLayout;
    ExportLogRow: TLayout;
    ImportConfigButtonFrame: TLayout;
    ImportConfigButtonRow: TLayout;
    ImportConfigButtonIconFrame: TLayout;
    ImportConfigButtonIconRow: TLayout;
    ExportConfigButtonFrame: TLayout;
    ExportConfigButtonRow: TLayout;
    ExportConfigButtonIconFrame: TLayout;
    ExportConfigButtonIconRow: TLayout;
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

    MetadataCaseCard: TRectangle;
    SettingsTabBaseline: TRectangle;
    InspectorBrowse: TButton;
    InspectorBrowseIcon: TPath;
    InspectorUseGlobal: TSwitch;
    InspectorProviderValue: TEdit;
    PanelFrontEndCard: TRectangle;
    PanelSourceFolderCard: TRectangle;
    PanelGameFileExtensionsCard: TRectangle;
    PanelLaunchBoxPlatformCard: TRectangle;
    PanelGameListTypeCard: TRectangle;
    PanelDestinationFolderCard: TRectangle;
    PanelAutoFavoriteCard: TRectangle;
    PanelAutoHideCard: TRectangle;
    PanelAutoHide2Card: TRectangle;
    PanelAutoExcludeCard: TRectangle;
    PanelAutoExclude2Card: TRectangle;
    PanelTextCaseTitleCard: TRectangle;
    PanelNameCaseCard: TRectangle;
    PanelDescriptionCaseCard: TRectangle;
    PanelGenreCaseCard: TRectangle;
    PanelNameDecorationsCard: TRectangle;
    PanelMethodCard: TRectangle;
    PanelCountryPreferencesCard: TRectangle;
    PanelLogsCard: TRectangle;
    PanelNetworkCard: TRectangle;
    PanelCacheManagementCard: TRectangle;
    AccountCredentialsCard: TRectangle;
    AccountServiceCard: TRectangle;
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
    LibraryHeaderSurface: TRectangle;
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
    ResizeHeightUnit: TLabel;
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
    IconRemoveSystem: FMX.Objects.TPath;
    IconDeleteMedia: FMX.Objects.TPath;
    IconDeleteAll: FMX.Objects.TPath;
    IconCopyFromMain: FMX.Objects.TPath;
    IconMediaTypeLeft: FMX.Objects.TPath;
    IconMediaTypeRight: FMX.Objects.TPath;
    IconMediaLeft: FMX.Objects.TPath;
    IconMediaMoveLeft: FMX.Objects.TPath;
    IconMediaMoveToLeft: FMX.Objects.TPath;
    IconMediaMoveToRight: FMX.Objects.TPath;
    IconMediaMoveRight: FMX.Objects.TPath;
    IconMediaRight: FMX.Objects.TPath;
    IconMethodLeft: FMX.Objects.TPath;
    IconMethodRight: FMX.Objects.TPath;
    IconHTTPTriesLeft: FMX.Objects.TPath;
    IconHTTPTriesRight: FMX.Objects.TPath;
    IconCacheTTLRight: FMX.Objects.TPath;
    IconCacheTTLLeft: FMX.Objects.TPath;
    IconClassificationLeft: FMX.Objects.TPath;
    IconClassificationRight: FMX.Objects.TPath;
    IconScrap: FMX.Objects.TPath;
    IconStop: FMX.Objects.TPath;
    PanelMain: TLayout;
    ProgressBarScrappingGames: TProgressBar;
    LabelScrapingSystemCount: TLabel;
    LabelScrapingGameCount: TLabel;
    LabelSystemName: TLabel;
    ProgressBarScrapingSystems: TProgressBar;
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
    DividerFrontEnd: TRectangle;
    LabelFrontEnd: TLabel;
    RollingButtonFrontEnd: TComboBox;
    EditFrontEndHost: TEdit;
    LabelFrontEndHost: TLabel;
    LabelFrontEndPath: TLabel;
    CheckBoxKillFrontEnd: TCheckBox;
    EditFrontEndPath: TEdit;
    PictureBoxFrontEnd: TImage;
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
    PictureBoxMediaSubType: FMX.Objects.TPath;
    RollingButtonImageSelector: TComboBox;
    ButtonMediaTypeLeft: TButton;
    CheckBoxMediaEmptyOutputFolder: TSwitch;
    PanelImageResizeConfig: TLayout;
    CheckBoxResizeHeight: TCheckBox;
    CheckBoxKeepImageRatio: TCheckBox;
    EditResizeWidth: TEdit;
    CheckBoxResizeWidth: TCheckBox;
    EditResizeHeight: TEdit;
    EditUserProvidedMix: TEdit;
    RollingButtonMediaTypeSelector: TComboBox;
    ButtonMediaTypeRight: TButton;
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
    ButtonMediaLeft: TButton;
    ButtonMediaMoveLeft: TButton;
    LabelScrapedMediaList: TLabel;
    ButtonCycleMediaSamples: TButton;
    ButtonMediaMoveToLeft: TButton;
    ButtonMediaMoveToRight: TButton;
    PanelMediaOuter: TVertScrollBox;
    PanelMediaInner: TLayout;
    ButtonRefreshUserMix: TButton;
    ButtonAddMedia: TButton;
    ButtonMediaMoveRight: TButton;
    ButtonCopyFromMain: TButton;
    ButtonMediaRight: TButton;
    TabMetadata: TTabItem;
    PanelScrollMetadataOuter: TVertScrollBox;
    PanelScrollMetadataInner: TLayout;
    PanelGenreCase: TLayout;
    RadioBoxGenreCaseLower: TRadioButton;
    RadioBoxGenreCaseAsIs: TRadioButton;
    LabelGenreCase: TLabel;
    RadioBoxGenreCaseUpper: TRadioButton;
    PanelTextCaseTitle: TLayout;
    LabelTextCase: TLabel;
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
    LabelNameDecorations: TLabel;
    CheckBoxNameDecorationBeta: TCheckBox;
    CheckBoxParseRomFileNameFrame: TLayout;
    CheckBoxParseRomFileNameRow: TLayout;
    CheckBoxParseRomFileName: TCheckBox;
    CheckBoxParseRomFileNameHelp: TLabel;
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
    PictureBoxMetaData: FMX.Objects.TPath;
    PanelDescriptionCase: TLayout;
    RadioBoxDescriptionCaseUpper: TRadioButton;
    RadioBoxDescriptionCaseAsIs: TRadioButton;
    RadioBoxDescriptionCaseLower: TRadioButton;
    LabelDescriptionCase: TLabel;
    TabAccount: TTabItem;
    PictureBoxScreenScraperShot: TImage;
    PictureBoxLoginIcon: FMX.Objects.TPath;
    EditLogin: TEdit;
    PictureBoxPasswordIcon: FMX.Objects.TPath;
    PanelScreenScraperDescription: TLayout;
    LabelSSAdvertisement: TLabel;
    LabelThreadAvailable: TLabel;
    LabelJoinUs: TLabel;
    ButtonDiscord: TButton;
    ButtonWeb: TButton;
    EditPassword: TEdit;
    ButtonTestAccount: TButton;
    TabMiscellaneous: TTabItem;
    PanelScrollMiscOuter: TVertScrollBox;
    PanelScrollMiscInner: TLayout;
    PanelMethod: TLayout;
    RollingButtonMethod: TComboBox;
    ButtonMethodLeft: TButton;
    LabelMethod: TLabel;
    ButtonMethodRight: TButton;
    PanelNetwork: TLayout;
    ButtonHTTPTriesLeft: TButton;
    RollingButtonCacheTTL: TComboBox;
    LabelHTTPTries: TLabel;
    ButtonHTTPTriesRight: TButton;
    ButtonCacheTTLRight: TButton;
    ButtonCacheTTLLeft: TButton;
    LabelCacheTTL: TLabel;
    RollingButtonHTTPTries: TComboBox;
    PanelCountryPreferences: TLayout;
    LabelRegion: TLabel;
    LabelClassification: TLabel;
    CheckBoxRegionStrictMode: TCheckBox;
    EditRegions: TEdit;
    ButtonClassificationLeft: TButton;
    LabelLanguage: TLabel;
    CheckBoxRomRegionFirst: TCheckBox;
    RollingButtonClassification: TComboBox;
    ButtonClassificationRight: TButton;
    EditLanguages: TEdit;
    PanelAdvancedScpecifyConfig: TLayout;
    LabelMiscellaneousSpecificConfigWarning: TLabel;
    CheckBoxMiscellaneousSpecificConfig: TCheckBox;
    PanelLogs: TLayout;
    CheckBoxSaveLogs: TSwitch;
    CheckBoxSaveMissing: TSwitch;
    CheckBoxVerboseLogging: TSwitch;
    PanelResetConfig: TLayout;
    LabelConfigurationManagement: TLabel;
    RaisedButtonResetConfig: TButton;
    PanelCacheManagement: TLayout;
    RaisedButtonClearGameInformationCache: TButton;
    RaisedButtonClearAllCaches: TButton;
    LabelCacheManagement: TLabel;
    RaisedButtonClearMediaCache: TButton;
    PanelScrapingInProgress: TLayout;
    FastColoredTextBoxLogging: TMemo;
    PanelScraping: TLayout;
    LabelRequestsValue: TLabel;
    PanelScrapStatusContainer: TLayout;
    PictureBoxScrapSample3: TImage;
    PictureBoxScrapSample1: TImage;
    PictureBoxScrapSample2: TImage;
    LabelElapsed: TLabel;
    LabelDownloadedMedia: TLabel;
    PictureBoxGears: FMX.Objects.TPath;
    LabelSavedMedia: TLabel;
    LabelErrors: TLabel;
    LabelErrorsValue: TLabel;
    LabelEstimatedTimeValue: TLabel;
    LabelScrapedGames: TLabel;
    LabelCached: TLabel;
    LabelFavoriteGamesValue: TLabel;
    LabelCachedValue: TLabel;
    LabelDownloadedMediaValue: TLabel;
    LabelHiddenGames: TLabel;
    LabelMediaPercent: TLabel;
    LabelGameNotFound: TLabel;
    LabelElapsedValue: TLabel;
    LabelRequests: TLabel;
    LabelSavedMediaValue: TLabel;
    PanelWorkEngines: TLayout;
    LabelWorkEngines: TLabel;
    PictureBoxWorkEngines: FMX.Objects.TPath;
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
    LabelFavoriteGames: TLabel;
    LabelHiddenGamesValue: TLabel;
    LabelGameNotFoundValue: TLabel;
    LabelEstimatedTime: TLabel;
    LabelScrapedGamesValue: TLabel;
    PanelLeftPan: TLayout;
    PanelSystemListOuter: TVertScrollBox;
    PanelSystemListInner: TLayout;
    ButtonAddSystem: TButton;
    PictureBoxScreenscraper: TImage;
    ButtonRunWizard: TButton;
    LabelCourtesyOf: TLabel;
    ButtonRemoveSystem: TButton;
    ImportConfigButton: TButton;
    ExportConfigButton: TButton;
    OpenDialog: TOpenDialog;
    SaveDialog: TSaveDialog;
    StatusTimer: TTimer;
    StyleBookWinUI3: TStyleBook;
    LayoutHead: TLayout;
    procedure OpenPlatformLibraryClick(Sender: TObject);
    procedure PageTabChanged(Sender: TObject);
    procedure ShellAction(Sender: TObject);
    procedure ScopeChanged(Sender: TObject);
    procedure SearchChanged(Sender: TObject);
    procedure SystemCheckChanged(Sender: TObject);
    procedure ToggleGameFilters(Sender: TObject);
    procedure InspectorChanged(Sender: TObject);
    procedure InspectorBrowseClick(Sender: TObject);
    procedure InspectorGlobalChanged(Sender: TObject);
    procedure ScrapeLogChanged(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure FormShow(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure FormCloseQuery(Sender: TObject; var CanClose: Boolean);
    procedure ActionClick(Sender: TObject);
    procedure SettingChanged(Sender: TObject);
    procedure StatusTimerTimer(Sender: TObject);
  private
    FCheckedSystems: TDictionary<string, Boolean>;
    FSettingsSnapshot, FCredentialSnapshot: TJSONObject;
    FConfig: TSkraperConfig;
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
    FPreviewRevisions: array[0..2] of Int64;
    FDisplayedSystemID: string;
    FEngineLabels: TObjectList<TLabel>;
    FLogInfoData, FLogSuccessData, FLogErrorData: TPathData;
    FDisplayedLogCount: Integer;
    FDisplayedLogTail: string;
    FFullLogCount: Integer;
    FFullLogTail: string;
    FFullLogReset: Boolean;
    FScrapeSubtitle: string;
    FEngineProgress: TObjectList<TProgressBar>;
    FEngineRows: TObjectList<TLayout>;
    procedure ShowPage(Page: Integer);
    procedure SyncFullLog;
    procedure UpdateInspector;
    procedure PollFolderCount;
    procedure UpdateSelectionCount;
    procedure UpdateRowSelection;
    function SystemTitle(Index: Integer): string;
    function SystemKey(Index: Integer): string;
    procedure RefreshSettings;
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
  SK.Consts, FMX.BehaviorManager, SK.GameLibrary.Form, SK.Artwork;

{$R *.fmx}

function CountFolderItems(const Folder: string): TFolderItemCount;
var
  Entry: string;
begin
  Result := Default(TFolderItemCount);
  if Folder.Trim = '' then
  begin
    Result.Error := SK.Locale.L('Папка не указана');
    Exit
  end;
  if not TDirectory.Exists(Folder) then
  begin
    Result.Error := SK.Locale.L('Папка не найдена');
    Exit
  end;
  try
    for Entry in TDirectory.GetFileSystemEntries(Folder) do
      if TDirectory.Exists(Entry) then
        Inc(Result.Folders)
      else
        Inc(Result.Files);
  except
    on E: Exception do
      Result.Error := SK.Locale.L('Не удалось прочитать папку');
  end;
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

function LoadLogPath(const RelativePath: string): TPathData;
var
  Source: TStringStream;
  Binary: TMemoryStream;
  Path: FMX.Objects.TPath;
begin
  Source := TStringStream.Create(TFile.ReadAllText(TPlatformPath.Combine(AppBase, RelativePath), TEncoding.UTF8), TEncoding.UTF8);
  try
    Binary := TMemoryStream.Create;
    try
      ObjectTextToBinary(Source, Binary);
      Binary.Position := 0;
      Path := FMX.Objects.TPath.Create(nil);
      try
        Binary.ReadComponent(Path);
        Result := TPathData.Create;
        try
          Result.Assign(Path.Data);
        except
          Result.Free;
          raise;
        end;
      finally
        Path.Free;
      end;
    finally
      Binary.Free;
    end;
  finally
    Source.Free;
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
  FFullLogReset := True;
  FLogInfoData := LoadLogPath(LogInfoIconPath);
  FLogSuccessData := LoadLogPath(LogSuccessIconPath);
  FLogErrorData := LoadLogPath(LogErrorIconPath);
  FCheckedSystems := TDictionary<string, Boolean>.Create;
  FEngineRows := TObjectList<TLayout>.Create(True);
  FEngineLabels := TObjectList<TLabel>.Create(False);
  FEngineProgress := TObjectList<TProgressBar>.Create(False);
  FSelected := -1;
  FMedia := 0;
  FConfig := TSkraperConfig.Create(WritableBase);
  SetLocale(CommandLineCulture(JStr(FConfig.Root, 'Culture', 'ru')));
  JSet(FConfig.Root, 'Culture', TJSONString.Create(CurrentLocale));
  FRefreshing := True;
  try ApplyLocale(Self) finally FRefreshing := False end;
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
  EditUserProvidedMix.OnChange := SettingChanged;
  RadioButtonNodeLink.Hint := 'Media.LinkToNode|radio-bool|true';
  RadioButtonNodeLink.OnChange := SettingChanged;
  RadioButtonNoLink.Hint := 'Media.LinkToNode|radio-bool|false';
  RadioButtonNoLink.OnChange := SettingChanged;
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
  FLogInfoData.Free;
  FLogSuccessData.Free;
  FLogErrorData.Free;
  FCheckedSystems.Free;
  FSettingsSnapshot.Free;
  FCredentialSnapshot.Free;
  FEngineRows.Free;
  FEngineLabels.Free;
  FEngineProgress.Free;
  FWorker.Free;
  FEffective.Free;
  FCatalog.Free;
  FreeAndNil(FConfig);
end;

procedure TFormMain.FormShow(Sender: TObject);
begin
  if FStartupWizardShown then Exit;
  FStartupWizardShown := True;
  if not JBool(FConfig.Root, 'IsConfigured') and not FindCmdLineSwitch('selftest') and
    not FindCmdLineSwitch('directorytest') and not FindCmdLineSwitch('librarytest') and
    not FindCmdLineSwitch('paritytest') and not FindCmdLineSwitch('editvisibilitytest') and
    not FindCmdLineSwitch('wizardconcepttest') then RunWizard;
end;

procedure TFormMain.RunWizard;
var Setup: TFormSetup;
begin
  Setup := TFormSetup.Create(nil);
  try
    Setup.StyleBook := StyleBookWinUI3;
    if Setup.Execute(FConfig, FCatalog, True) then
    begin
      FSelected := -1; FMedia := 0;
      FCatalog.Free;
      FCatalog := ReadJSON(TPlatformPath.Combine(WritableBase, SystemsCatalogPath));
      if FCatalog = nil then FCatalog := ReadJSON(TPlatformPath.Combine(AppBase, SystemsCatalogPath));
      FCheckedSystems.Clear;
      FillCatalog; BuildSystems; BuildMedia; RefreshSettings; SaveConfig;
    end;
  finally Setup.Free end;
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
      IconScrap.Visible := False;
      IconStop.Visible := False;
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
        if not SelectablePlatform(V) then Continue;
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
  Result := JStr(FConfig.SystemAt(Index), 'SystemId') + '|' +
    JStr(FConfig.SystemAt(Index), 'GamesAndRoms.Path').ToLower;
end;

procedure SetRowAccent(Button: TButton; Selected: Boolean);
var
  Child: TFmxObject;
begin
  for Child in Button.Children do
    if (Child is TRectangle) and (Child.StyleName = 'rowaccent') then
      TRectangle(Child).Visible := Selected;
end;

procedure AddRowAccent(Button: TButton; Selected, Divider: Boolean);
var
  Surface: TRectangle;
begin
  Surface := TRectangle.Create(Button);
  Surface.Parent := Button;
  Surface.StyleName := 'rowaccent';
  Surface.Align := TAlignLayout.Contents;
  Surface.Fill.Color := $FF304B5B;
  Surface.Stroke.Kind := TBrushKind.None;
  Surface.XRadius := 4;
  Surface.YRadius := 4;
  Surface.HitTest := False;
  Surface.Visible := Selected;
  if Divider then
  begin
    Surface := TRectangle.Create(Button);
    Surface.Parent := Button;
    Surface.Align := TAlignLayout.Bottom;
    Surface.Height := 1;
    Surface.Fill.Color := $FF414141;
    Surface.Stroke.Kind := TBrushKind.None;
    Surface.HitTest := False;
  end;
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
        ArtworkImage.Parent := Prefix; ArtworkImage.Align := TAlignLayout.Right;
        ArtworkImage.Width := 28; ArtworkImage.Margins.Rect := RectF(0, 8, 8, 8);
        ArtworkImage.HitTest := False; ArtworkImage.WrapMode := TImageWrapMode.Fit;
        try ArtworkImage.Bitmap.LoadFromFile(ImageFile); P.Visible := False
        except ArtworkImage.Free end;
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
              if TLabel(Child).StyleName = 'systempath' then TLabel(Child).Text := JStr(FConfig.SystemAt(B.Tag), 'GamesAndRoms.Path');
              if TLabel(Child).StyleName = 'systemsettings' then
                if JInt(FConfig.SystemAt(B.Tag), 'Overriden') = 0 then TLabel(Child).Text := SK.Locale.L('Общие')
                else TLabel(Child).Text := SK.Locale.L('Индивидуальные');
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
var
  i: Integer;
  A: TJSONArray;
begin
  if FRefreshing or (FConfig = nil) then
    Exit;
  if (FWorker <> nil) and not FWorker.Finished then
    Exit;
  if Sender = SelectAllSystems then
  begin
    A := FConfig.Root.GetValue<TJSONArray>('Systems');
    for i := 0 to A.Count - 1 do
      FCheckedSystems.AddOrSetValue(SystemKey(i), SelectAllSystems.IsChecked);
    UpdateRowSelection;
  end
  else
  begin
    FCheckedSystems.AddOrSetValue(SystemKey(TControl(Sender).Tag), TCheckBox(Sender).IsChecked);
    UpdateSelectionCount;
  end;
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
  PictureBoxPhotoFrame.Visible := ImageFile <> '';
    if ImageFile <> '' then
      try PictureBoxPhoto.Bitmap.LoadFromFile(ImageFile)
    except PictureBoxPhoto.Visible := False; PictureBoxPhotoFrame.Visible := False end;
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
var Window: TFormGameLibrary; Config, RunConfig: TJSONObject; Rom: string;
begin
  if (FWorker <> nil) and not FWorker.Finished then Exit;
  if FSelected < 0 then Exit;
  Window := nil;
  Config := FConfig.EffectiveSystem(FSelected);
  Rom := '';
  try
    try
      ResolveFrontendPaths(Config, JValue(FConfig.Root, 'FrontEnd') as TJSONObject, FCatalog);
      Window := TFormGameLibrary.Create(Self);
      Window.StyleBook := StyleBookWinUI3;
      Window.LoadPlatform(Config, SystemTitle(FSelected));
      Window.ShowModal;
      Rom := Window.RequestedRom;
    except
      on E: Exception do TDialogServiceSync.ShowMessage(E.Message);
    end;
  finally Window.Free; Config.Free end;
  if Rom = '' then Exit;
  SaveConfig;
  FreeAndNil(FWorker);
  // The selected platform index refers to the complete config, independent of checkboxes.
  RunConfig := FConfig.Root.Clone as TJSONObject;
  try
    FWorker := TScrapeWorker.Create(RunConfig, FConfig.Credentials, WritableBase,
      FSelected, False, 1, Rom);
  finally RunConfig.Free end;
  BeginScrapeDisplay;
  FWorker.Start;
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
var
  A: TJSONArray;
  Group: string;
  Bit: Integer;
begin
  if WriteAccess and not Path.StartsWith('@') and not Path.StartsWith('!') then
  begin
    Group := Path.Split(['.'])[0];
    Bit := 0;
    if Group = 'GameList' then
      Bit := 1
    else if Group = 'GamesAndRoms' then
      Bit := 2
    else if Group = 'MetaData' then
      Bit := 4
    else if Group = 'Media' then
    begin
      Group := 'Medias';
      Bit := 8;
    end
    else if Group = 'Miscellaneous' then
      Bit := 16;
    if Bit <> 0 then
      EnsureGroup(Group, Bit);
  end;
  Result := FConfig.SystemAt(FSelected);
  if Path.StartsWith('@') then
  begin
    Delete(Path, 1, 1);
    Exit(FConfig.Root);
  end;
  if Path.StartsWith('!') then
  begin
    Delete(Path, 1, 1);
    Exit(FConfig.Credentials);
  end;
  if Path.StartsWith('Media.') then
  begin
    Delete(Path, 1, 6);
    if not WriteAccess and (FSelected >= 0) and (JInt(Result, 'Overriden') and 8 = 0) then
      Result := FConfig.SystemAt(-1);
    A := Result.GetValue<TJSONArray>('Medias');
    if (FMedia < 0) or (FMedia >= A.Count) then
      Exit(nil);
    Result := A.Items[FMedia] as TJSONObject;
  end;
end;

procedure TFormMain.RefreshSettings;
var
  i, j, N: Integer;
  C: TComponent;
  Path, Text: string;
  Spec: TArray<string>;
  Obj, Effective: TJSONObject;
  V, Item: TJSONValue;
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
      V := JValue(Obj, Path);
      Text := JStr(Obj, Path);
      N := JInt(Obj, Path);
      if (Length(Spec) > 2) and (Spec[1] = 'array') and (Spec[2] = '') then
        Spec[2] := '|';
      if (Length(Spec) > 1) and (Spec[1] = 'array') then
      begin
        Text := '';
        if V is TJSONArray then
          for Item in TJSONArray(V) do
          begin
            if Text <> '' then
              Text := Text + Spec[2];
            Text := Text + Item.Value;
          end;
      end;
      if C is TEdit then
        TEdit(C).Text := Text
      else if C is TSwitch then
        TSwitch(C).IsChecked := JBool(Obj, Path)
      else if C is TCheckBox then
      begin
        if (Length(Spec) > 1) and (Spec[1] = 'bit') then
          TCheckBox(C).IsChecked := (N and StrToInt(Spec[2])) <> 0
        else
          TCheckBox(C).IsChecked := JBool(Obj, Path);
      end
      else if C is TRadioButton then
      begin
        if Length(Spec) > 2 then
          if Spec[1] = 'radio-bool' then
            TRadioButton(C).IsChecked := SameText(Text, Spec[2])
          else
            TRadioButton(C).IsChecked := N = StrToInt(Spec[2]);
      end
      else if C is TComboBox then
      begin
        if (Length(Spec) > 1) and (Spec[1] = 'rating') then
          N := (N - 40) div 5;
        if (Length(Spec) > 1) and (Spec[1] = 'text') then
          N := TComboBox(C).Items.IndexOf(Text);
        if C = RollingButtonCacheTTL then
        begin
          while RollingButtonCacheTTL.Items.Count > 17 do
            RollingButtonCacheTTL.Items.Delete(17);
          if N >= UnlimitedCacheDays then
            N := 16
          else if N >= 16 then
          begin
            RollingButtonCacheTTL.Tag := N;
            RollingButtonCacheTTL.Items.Add(N.ToString + ' days');
            N := 17;
          end;
        end;
        TComboBox(C).ItemIndex := N;
      end;
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
      Text := SK.Data.MediaNode(TJSONArray(JValue(Effective, 'Medias')), FMedia);
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
  if (FWorker = nil) or FWorker.Finished then PreviewMedia;
end;

procedure TFormMain.SettingChanged(Sender: TObject);
var
  C: TControl;
  Path, Text: string;
  Spec: TArray<string>;
  Obj: TJSONObject;
  Value: TJSONValue;
  A: TJSONArray;
  S: string;
  N, Bit: Integer;
begin
  if FRefreshing or (FConfig = nil) then
    Exit;
  C := TControl(Sender);
  if C = UILanguage then
  begin
    SetLocale(UILocaleCode(UILanguage.ItemIndex));
    JSet(FConfig.Root, 'Culture', TJSONString.Create(CurrentLocale));
    FRefreshing := True;
    try ApplyLocale(Self) finally FRefreshing := False end;
    FPreviewKey := '';
    BuildSystems; BuildMedia; RefreshSettings; PageTabChanged(nil);
    Exit;
  end;
  if (C = EditLogin) or (C = EditPassword) then
  begin
    AccountConnectionState.Text := SK.Locale.L('Не проверено');
    ServiceState.Text := SK.Locale.L('Не проверено');
    AccountStatusDot.Fill.Color := $FF888888;
    AccountThreadsValue.Text := '—';
    AccountQuotaValue.Text := '—';
    LabelQuotaValue.Text := '—';
    LabelQuotaValue.Hint := '';
    LabelThreadAvailable.Text := SK.Locale.L('Нажмите «Проверить подключение»');
  end;
  if C = RollingButtonSystemSelect then
  begin
    if (FSelected >= 0) and (RollingButtonSystemSelect.ItemIndex >= 0) then
    begin
      ConfigurePlatform(FConfig.SystemAt(FSelected), FConfig.SystemAt(-1), FCatalog,
        JInt(FConfig.Root, 'FrontEnd.Type'),
        TArray<Integer>.Create(NativeInt(RollingButtonSystemSelect.Items.Objects[RollingButtonSystemSelect.ItemIndex])),
        JStr(FConfig.SystemAt(FSelected), 'GamesAndRoms.Path'));
      BuildSystems; BuildMedia; RefreshSettings;
    end;
    Exit;
  end;
  Spec := C.Hint.Split(['|']);
  if (Length(Spec) = 0) or (Spec[0] = '') then
    Exit;
  if (Length(Spec) > 2) and (Spec[1] = 'array') and (Spec[2] = '') then
    Spec[2] := '|';
  Path := Spec[0];
  Obj := BindingObject(Path, True);
  if Obj = nil then
    Exit;
  Value := nil;
  if C is TEdit then
  begin
    Text := TEdit(C).Text;
    if (Length(Spec) > 1) and (Spec[1] = 'array') then
    begin
      A := TJSONArray.Create;
      for S in Text.Split([Spec[2][1]]) do
        if S.Trim <> '' then
          A.Add(S.Trim);
      if C = EditSecondarySystems then
      begin
        Value := TJSONArray.Create;
        for S in Text.Split([',']) do
          if S.Trim <> '' then
          begin
            if not TryStrToInt(S.Trim, N) or (N <= 0) or (CatalogSystem(FCatalog, N) = nil) then
            begin Value.Free; A.Free; ShowMessage(SK.Locale.L('Введите действительные ID систем через запятую.')); Exit end;
            if N <> JInt(FConfig.SystemAt(FSelected), 'SystemId') then TJSONArray(Value).Add(N);
          end;
        A.Free;
      end
      else Value := A;
    end
    else if JValue(Obj, Path) is TJSONNumber then
    begin
      if not TryStrToInt(Text, N) or (N < 0) then
        Exit;
      Value := TJSONNumber.Create(N);
    end
    else
      Value := TJSONString.Create(Text);
  end
  else if C is TSwitch then
    Value := TJSONBool.Create(TSwitch(C).IsChecked)
  else if C is TCheckBox then
  begin
    if (Length(Spec) > 1) and (Spec[1] = 'bit') then
    begin
      N := JInt(Obj, Path);
      Bit := StrToInt(Spec[2]);
      if TCheckBox(C).IsChecked then
        N := N or Bit
      else
        N := N and not Bit;
      Value := TJSONNumber.Create(N);
    end
    else
      Value := TJSONBool.Create(TCheckBox(C).IsChecked);
  end
  else if C is TRadioButton then
  begin
    if TRadioButton(C).IsChecked and (Length(Spec) > 2) then
      if Spec[1] = 'radio-bool' then
        Value := TJSONBool.Create(Spec[2] = 'true')
      else
        Value := TJSONNumber.Create(StrToInt(Spec[2]));
  end
  else if C is TComboBox then
  begin
    N := TComboBox(C).ItemIndex;
    if N < 0 then
      Exit;
    if (Length(Spec) > 1) and (Spec[1] = 'text') then
      Value := TJSONString.Create(TComboBox(C).Items[N])
    else
    begin
      if (Length(Spec) > 1) and (Spec[1] = 'rating') then
        N := N * 5 + 40;
      if C = RollingButtonCacheTTL then
      begin
        if N = 16 then
          N := UnlimitedCacheDays
        else if N = 17 then
          N := RollingButtonCacheTTL.Tag;
      end;
      Value := TJSONNumber.Create(N);
    end;
  end;
  if Value <> nil then
    JSet(Obj, Path, Value);
  if (FSelected >= 0) and (Path <> 'Overriden') and not C.Hint.StartsWith('@') and not C.Hint.StartsWith('!') then
  begin
    N := JInt(FConfig.SystemAt(FSelected), 'Overriden');
    Bit := 0;
    if C.Hint.StartsWith('GameList.') then
      Bit := 1;
    if C.Hint.StartsWith('GamesAndRoms.') then
      Bit := 2;
    if C.Hint.StartsWith('MetaData.') then
      Bit := 4;
    if C.Hint.StartsWith('Media.') then
      Bit := 8;
    if C.Hint.StartsWith('Miscellaneous.') then
      Bit := 16;
    JSet(FConfig.SystemAt(FSelected), 'Overriden', TJSONNumber.Create(N or Bit));
  end;
  if (C = RollingButtonMediaTypeSelector) or (C = RollingButtonImageSelector) then
  begin
    A := TJSONArray.Create;
    try
      for N := 0 to TJSONArray(JValue(FConfig.SystemAt(FSelected), 'Medias')).Count - 1 do
        if N <> FMedia then A.AddElement(TJSONArray(JValue(FConfig.SystemAt(FSelected), 'Medias')).Items[N].Clone as TJSONValue);
      JSet(Obj, 'OutputFolder', TJSONString.Create(DefaultMediaFolder(JInt(FConfig.Root, 'FrontEnd.Type'),
        JInt(Obj, 'Type'), JInt(Obj, 'Image'), A)));
    finally A.Free end;
  end;
  if C = RollingButtonFrontEnd then
  begin
    ApplyFrontendDefaults(FConfig.Root, True);
    BuildMedia;
    RefreshSettings;
    Exit;
  end;
  if (C = RollingButtonMediaTypeSelector) or (C = RollingButtonImageSelector) or
    (C = RollingButtonInternalMixSelector) or (C = RadioButtonNodeLink) or (C = RadioButtonNoLink) or
    (C = EditMediaOutputFolder) or (C = CheckBoxAnonymous) or (C = EditUserProvidedMix) or
    (C = EditResizeWidth) or (C = EditResizeHeight) or (C = CheckBoxKeepImageRatio) or (C = CheckBoxResizeWidth) or (C = CheckBoxResizeHeight) or (Path = 'Overriden') then
  begin
    BuildMedia;
    RefreshSettings;
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
    if Kind = 1 then Title := MixTitle(TPlatformPath.Combine(AppBase, 'Mixes/' +
      BuiltInMixFiles[EnsureRange(JInt(A.Items[i], 'InternalMix'), 0, 6)]))
    else if Kind = 2 then Title := MixTitle(JStr(A.Items[i], 'LocalMixFile'));
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
  Credentials, ArtworkCredentials, ArtworkSettings: TJSONObject;
  Base: string;
begin
  if FAccountBusy then
    Exit;
  SaveConfig;
  FAccountBusy := True;
  CheckBoxAnonymous.Enabled := False; EditLogin.Enabled := False; EditPassword.Enabled := False;
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
  ArtworkCredentials := Credentials.Clone as TJSONObject;
  ArtworkSettings := FConfig.SystemAt(-1).Clone as TJSONObject;
  Base := WritableBase;
  FAccountTask := TTask.Run(
    procedure
    var
      API: TScreenScraper;
      User, Catalog: TJSONObject;
      MessageText, ThreadsText, QuotaText: string;
      Verified, Anonymous: Boolean;
      ArtworkCount: Integer;
    begin
      Anonymous := JBool(Credentials, 'anonymous');
      API := TScreenScraper.Create(Credentials, Base + NativePath('Cache\api'));
      Credentials.Free;
      Catalog := nil;
      Verified := False;
      ThreadsText := '—';
      QuotaText := '—';
      try
        try
          if not Anonymous then
          begin
            User := API.Authenticate;
            try
              if JValue(User, 'response.ssuser') = nil then raise EScreenScraper.Create('No user information returned');
              Verified := True;
              ThreadsText := JStr(User, 'response.ssuser.maxthreads', '—');
              QuotaText := JStr(User, 'response.ssuser.requeststoday', '—') + ' / ' + JStr(User, 'response.ssuser.maxrequestsperday', '—');
              MessageText := SK.Locale.L('Авторизация выполнена');
            finally User.Free end;
          end;
          try
            Catalog := API.Systems;
            if JValue(Catalog, 'response') is TJSONObject then
            begin
              if Anonymous then
              begin Verified := True; ThreadsText := '1'; QuotaText := SK.Locale.L('Без аккаунта'); MessageText := SK.Locale.L('Анонимное подключение выполнено') end;
              WriteJSON(Base + NativePath('Resources\systems.json'), JValue(Catalog, 'response'));
              try
                ArtworkCount := RefreshPlatformArtwork(JValue(Catalog, 'response') as TJSONObject,
                  ArtworkSettings, ArtworkCredentials, Base, False, nil,
                  procedure(Done, Total: Integer)
                  begin
                    if (Done mod 8 = 0) or (Done = Total) then
                      TThread.Queue(nil, TThreadProcedure(procedure
                      begin ServiceState.Text := SK.Locale.L('Изображения платформ: %d / %d', [Done, Total]) end));
                  end);
                MessageText := MessageText + SK.Locale.L(' — изображений платформ: %d', [ArtworkCount]);
              except on E: Exception do
                MessageText := MessageText + SK.Locale.L(' — изображения платформ недоступны');
              end;
            end;
          except
            on E: Exception do
              MessageText := MessageText + SK.Locale.L(' — каталог систем недоступен');
          end;
        except
          on E: Exception do
            MessageText := E.Message;
        end;
      finally
        API.Free;
        Catalog.Free;
        ArtworkCredentials.Free; ArtworkSettings.Free;
      end;
      System.Classes.TThread.Queue(nil, TThreadProcedure(
        procedure
        begin
          LabelThreadAvailable.Text := MessageText;
          AccountThreadsValue.Text := ThreadsText;
          AccountQuotaValue.Text := QuotaText;
          LabelQuotaValue.Text := QuotaText;
          LabelQuotaValue.Hint := SK.Locale.L('Запросы сегодня / суточный лимит ScreenScraper');
          if Verified then
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
          if FCatalog = nil then FCatalog := ReadJSON(TPlatformPath.Combine(AppBase, SystemsCatalogPath));
          FillCatalog;
          BuildSystems;
          RefreshSettings;
        end));
    end);
end;

procedure TFormMain.Browse(Edit: TEdit; IsFile: Boolean);
var Folder, Key: string;
begin
  Key := 'GameAndRomFolder';
  if Edit = EditFrontEndPath then Key := 'FrontEndPath'
  else if Edit = EditMediaOutputFolder then Key := 'MediaOutputFolder'
  else if IsFile then Key := 'MixFolder';
  Folder := FConfig.DialogFolder(Key, Edit.Text);
  if IsFile then
  begin
    OpenDialog.Filter := SK.Locale.L('XML-файлы|*.xml|Все файлы|*.*');
    OpenDialog.InitialDir := Folder;
    if TFile.Exists(Edit.Text) then OpenDialog.FileName := Edit.Text else OpenDialog.FileName := '';
    if OpenDialog.Execute then
    begin Edit.Text := OpenDialog.FileName; FConfig.RememberFolder(Key, ExtractFilePath(OpenDialog.FileName)) end;
  end
  else if SelectDirectory(SK.Locale.L('Выберите папку'), '', Folder) then
  begin Edit.Text := Folder; FConfig.RememberFolder(Key, Folder) end;
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
var
  Sys: TJSONObject;
  Path: string;
begin
  if FSelected < 0 then
    Exit;
  Sys := FConfig.SystemAt(FSelected);
  if JInt(Sys, 'Overriden') and Bit = 0 then
  begin
    Path := JStr(Sys, 'GamesAndRoms.Path');
    JSet(Sys, Group, JValue(FConfig.SystemAt(-1), Group).Clone as TJSONValue);
    if Group = 'GamesAndRoms' then
      JSet(Sys, 'GamesAndRoms.Path', TJSONString.Create(Path));
    JSet(Sys, 'Overriden', TJSONNumber.Create(JInt(Sys, 'Overriden') or Bit));
  end;
end;

procedure TFormMain.PreviewMedia;
var Settings: TJSONObject; Medias: TJSONValue; Media: TJSONObject; FileName, Key, Title: string;
begin
  if FConfig = nil then Exit;
  Settings := FConfig.EffectiveSystem(FSelected);
  try
    Medias := JValue(Settings, 'Medias');
    if not (Medias is TJSONArray) or (FMedia < 0) or (FMedia >= TJSONArray(Medias).Count) then
    begin MediaPreviewImage.Bitmap.Clear(0); MediaPreviewCaption.Text := SK.Locale.L('Добавьте медиа для предпросмотра'); Exit end;
    Media := TJSONArray(Medias).Items[FMedia] as TJSONObject;
    Key := Settings.ToJSON + '|' + FMedia.ToString + '|' + FSample.ToString + '|' + CurrentLocale;
    if Key = FPreviewKey then Exit;
    FPreviewKey := Key; MediaPreviewImage.Bitmap.SetSize(0, 0);
    try
      FileName := MediaPreview(Media, Settings, FCatalog, FSample, TPlatformPath.Combine(WritableBase, 'Cache/preview'));
      if FileName <> '' then MediaPreviewImage.Bitmap.LoadFromFile(FileName);
      Title := MediaSelectionTitle.Text;
      if JInt(Media, 'Type') = 1 then Title := MixTitle(TPlatformPath.Combine(AppBase, 'Mixes/' +
        BuiltInMixFiles[EnsureRange(JInt(Media, 'InternalMix'), 0, 6)]))
      else if JInt(Media, 'Type') = 2 then Title := MixTitle(JStr(Media, 'LocalMixFile'));
      MediaSelectionTitle.Text := Title;
      MediaPreviewCaption.Text := Title + sLineBreak + SK.Locale.L('Образец: %s', [MixSamplePrefixes[FSample mod 6]]);
      if FileName = '' then MediaPreviewCaption.Text := MediaPreviewCaption.Text + sLineBreak + SK.Locale.L('Изображение образца отсутствует');
    except
      on E: Exception do MediaPreviewCaption.Text := SK.Locale.L('Не удалось построить предпросмотр: %s', [E.Message]);
    end;
  finally Settings.Free end;
end;

function TFormMain.PrepareRequiredMedia: Integer;
var V: TJSONValue;
begin
  Result := 0;
  if JInt(FConfig.Root, 'FrontEnd.Type') <> 0 then Exit;
  Inc(Result, EnsureRecalboxMedia(FConfig.SystemAt(-1)));
  for V in FConfig.Root.GetValue<TJSONArray>('Systems') do
    if JInt(V, 'Overriden') and 8 <> 0 then Inc(Result, EnsureRecalboxMedia(V as TJSONObject));
  if Result > 0 then begin BuildMedia; RefreshSettings end;
end;

procedure TFormMain.CleanCache(Information, Media: Boolean);
var Config: TJSONObject; Base: string; SystemID: Integer;
begin
  if FCacheBusy then Exit;
  FCacheBusy := True; PanelSettings.Enabled := False; PanelLeftPan.Enabled := False;
  ButtonScrap.Enabled := False; CacheStatusLabel.Text := SK.Locale.L('Очистка кэша…');
  Config := FConfig.Root.Clone as TJSONObject;
  Base := WritableBase; SystemID := JInt(FConfig.SystemAt(FSelected), 'SystemId');
  FCacheTask := TTask.Run(
    procedure
    var ErrorText: string;
    begin
      ErrorText := '';
      try
        try
          ClearSystemCache(Base, Config, SystemID, Information, Media,
            procedure(Done, Total: Integer)
            var MessageText: string;
            begin
              if (Done mod 25 <> 0) and (Done <> Total) then Exit;
              MessageText := SK.Locale.L('Очистка кэша: %d / %d', [Done, Total]);
              TThread.Queue(nil, TThreadProcedure(procedure begin CacheStatusLabel.Text := MessageText end));
            end);
        except on E: Exception do ErrorText := E.Message end;
      finally Config.Free end;
      TThread.Queue(nil, TThreadProcedure(
        procedure
        begin
          FCacheBusy := False; PanelSettings.Enabled := True; PanelLeftPan.Enabled := True;
          UpdateSelectionCount;
          if ErrorText = '' then
          begin
            if SystemID = 0 then CacheStatusLabel.Text := SK.Locale.L('Кэш всех систем очищен')
            else CacheStatusLabel.Text := SK.Locale.L('Кэш выбранной системы очищен');
          end
          else CacheStatusLabel.Text := SK.Locale.L('Ошибка очистки кэша: %s', [ErrorText]);
        end));
    end);
end;

procedure TFormMain.ActionClick(Sender: TObject);
var
  Name: string;
  A, B: TJSONArray;
  O: TJSONObject;
  i, j, Target, Required: Integer;
  Combo: TComboBox;
  Setup: TFormSetup;
begin
  Name := TComponent(Sender).Name;
  if FCacheBusy or FAccountBusy then Exit;
  if (FWorker <> nil) and not FWorker.Finished and (Sender <> ButtonScrap) then
    Exit;
  if Sender = ImportConfigButton then
  begin
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
      try ApplyLocale(Self) finally FRefreshing := False end;
      FSample := EnsureRange(JInt(FConfig.Root, 'SampleSet'), 0, 5);
      FSelected := -1;
      FMedia := 0;
      FillCatalog;
      BuildSystems;
      BuildMedia;
      RefreshSettings;
    end;
    Exit;
  end;
  if Sender = ExportConfigButton then
  begin
    SaveDialog.Filter := SK.Locale.L('Сохранить конфигурацию|*.json');
    SaveDialog.InitialDir := FConfig.DialogFolder('ConfigFolder', '');
    SaveDialog.FileName := 'skraper.config.json';
    SaveDialog.DefaultExt := 'json';
    if SaveDialog.Execute then
    begin
      FConfig.RememberFolder('ConfigFolder', ExtractFilePath(SaveDialog.FileName));
      WriteJSON(SaveDialog.FileName, FConfig.Root);
    end;
    Exit;
  end;
  if Sender = ButtonRunWizard then
  begin
    RunWizard;
    Exit;
  end;
  if Sender = ButtonTestAccount then
  begin
    ValidateAccount;
    Exit;
  end;
  if Sender = ButtonScrap then
  begin
    if FWorker <> nil then
    begin
      if not FWorker.Finished then
      begin
        FWorker.Terminate;
        IconScrap.Visible := False;
        IconStop.Visible := False;
        ButtonScrap.Text := SK.Locale.L('Остановка…');
        Exit;
      end;
      FreeAndNil(FWorker);
      PanelLeftPan.Enabled := True;
      ImportConfigButton.Enabled := True;
      ExportConfigButton.Enabled := True;
      RefreshSettings;
      ProgressBarScrappingGames.Value := 0;
      ProgressBarScrapingSystems.Value := 0;
      LabelScrapingGameCount.Text := 'Games';
      LabelScrapingSystemCount.Text := 'System';
      ButtonScrap.Text := SK.Locale.L('Остановить');
      IconScrap.Visible := False;
      IconStop.Visible := False;
      ShowPage(0);
      UpdateSelectionCount;
      Exit;
    end;
    Required := PrepareRequiredMedia;
    SaveConfig;
    FreeAndNil(FSettingsSnapshot);
    FreeAndNil(FCredentialSnapshot);
    O := CreateRunConfig;
    try
      if O.GetValue<TJSONArray>('Systems').Count = 0 then
        Exit;
      FWorker := TScrapeWorker.Create(O, FConfig.Credentials, WritableBase, -1);
    finally
      O.Free
    end;
    BeginScrapeDisplay;
    if Required > 0 then FastColoredTextBoxLogging.Lines.Add(SK.Locale.L('Добавлено обязательных медиа Recalbox: %d', [Required]));
    ButtonScrap.Text := SK.Locale.L('Остановить');
    IconScrap.Visible := False;
    IconStop.Visible := False;
    FWorker.Start;
    Exit;
  end;
  if (Sender = ButtonAddSystem) then
  begin
    AddSystem;
    Exit;
  end;
  if Sender = ButtonRemoveSystem then
  begin
    if FSelected < 0 then
      Exit;
    FConfig.Root.GetValue<TJSONArray>('Systems').Remove(FSelected).Free;
    FSelected := -1;
    BuildSystems;
    BuildMedia;
    RefreshSettings;
    Exit;
  end;
  if Sender = ButtonSourceFolder then
  begin
    Browse(EditSourceFolder);
    BuildSystems;
    Exit;
  end;
  if Sender = ButtonDestinationFolder then
  begin
    SaveDialog.Filter := SK.Locale.L('Файл списка игр|*.xml;*.dat;*.zip');
    SaveDialog.InitialDir := FConfig.DialogFolder('GamelistFolder', EditDestinationFolder.Text);
    if not EditDestinationFolder.Text.Contains('%') then SaveDialog.FileName := EditDestinationFolder.Text
    else SaveDialog.FileName := 'gamelist.xml';
    if SaveDialog.Execute then
    begin
      EditDestinationFolder.Text := SaveDialog.FileName;
      FConfig.RememberFolder('GamelistFolder', ExtractFilePath(SaveDialog.FileName));
    end;
    Exit;
  end;
  if Sender = ButtonMediaOutputFolder then
  begin
    Browse(EditMediaOutputFolder);
    Exit;
  end;
  if Sender = ButtonFrontEndPath then
  begin
    Browse(EditFrontEndPath);
    Exit;
  end;
  if Sender = ButtonUserProvidedMix then
  begin
    Browse(EditUserProvidedMix, True);
    Exit;
  end;
  if Sender = ButtonWeb then
  begin
    OpenExternalURL(ScreenScraperWebsite);
    Exit;
  end;
  if Sender = ButtonDiscord then
  begin
    OpenExternalURL(ScreenScraperDiscordURL);
    Exit;
  end;
  if (Sender = ButtonCycleMediaSamples) or (Sender = ButtonRefreshUserMix) then
  begin
    if Sender = ButtonCycleMediaSamples then
    begin
      FSample := (FSample + 1) mod 6;
      JSet(FConfig.Root, 'SampleSet', TJSONNumber.Create(FSample));
    end;
    FPreviewKey := '';
    BuildMedia;
    RefreshSettings;
    try
      PreviewMedia;
    except
      on E: Exception do
        ShowMessage(E.Message);
    end;
    Exit;
  end;
  if (Sender = ButtonMediaMoveLeft) or (Sender = ButtonMediaMoveRight) or
    (Sender = ButtonMediaMoveToLeft) or (Sender = ButtonMediaMoveToRight) or
    (Sender = ButtonAddMedia) or (Sender = ButtonDeleteMedia) or (Sender = ButtonDeleteAll) then
    EnsureGroup('Medias', 8);
  A := FConfig.SystemAt(FSelected).GetValue<TJSONArray>('Medias');
  if (Sender = ButtonMediaMoveLeft) or (Sender = ButtonMediaMoveRight) or (Sender = ButtonMediaMoveToLeft) or (Sender = ButtonMediaMoveToRight) then
  begin
    if (FMedia < 0) or (FMedia >= A.Count) then
      Exit;
    Target := FMedia;
    if Sender = ButtonMediaMoveLeft then
      Dec(Target);
    if Sender = ButtonMediaMoveRight then
      Inc(Target);
    if Sender = ButtonMediaMoveToLeft then
      Target := 0;
    if Sender = ButtonMediaMoveToRight then
      Target := A.Count - 1;
    Target := EnsureRange(Target, 0, A.Count - 1);
    B := TJSONArray.Create;
    for i := 0 to A.Count - 1 do
    begin
      j := i;
      if i = Target then
        j := FMedia
      else if (Target < FMedia) and (i > Target) and (i <= FMedia) then
        j := i - 1
      else if (Target > FMedia) and (i >= FMedia) and (i < Target) then
        j := i + 1;
      B.AddElement(A.Items[j].Clone as TJSONValue);
    end;
    JSet(FConfig.SystemAt(FSelected), 'Medias', B);
    FMedia := Target;
    BuildMedia;
    RefreshSettings;
    Exit;
  end;
  if (Sender = ButtonMediaLeft) or (Sender = ButtonMediaRight) then
  begin
    if FEffective <> nil then A := FEffective.GetValue<TJSONArray>('Medias');
    if Sender = ButtonMediaLeft then
      i := -1
    else
      i := 1;
    FMedia := EnsureRange(FMedia + i, 0, Max(0, A.Count - 1));
    BuildMedia;
    RefreshSettings;
    PanelMediaOuter.ViewportPosition := PointF(0, FMedia * 76);
    Exit;
  end;
  if Sender = ButtonAddMedia then
  begin
    A.AddElement(DefaultMedia(JInt(FConfig.Root, 'FrontEnd.Type'), A));
    FMedia := A.Count - 1; BuildMedia; RefreshSettings; Exit;
  end;
  if Sender = ButtonDeleteMedia then
  begin
    if (FMedia >= 0) and (FMedia < A.Count) then
      A.Remove(FMedia).Free;
    FMedia := Max(0, A.Count - 1);
    BuildMedia;
    RefreshSettings;
    Exit;
  end;
  if Sender = ButtonDeleteAll then
  begin
    while A.Count > 0 do
      A.Remove(0).Free;
    FMedia := 0;
    BuildMedia;
    RefreshSettings;
    Exit;
  end;
  if Sender = ButtonCopyFromMain then
  begin
    Setup := TFormSetup.Create(nil);
    try
      Setup.StyleBook := StyleBookWinUI3;
      O := Setup.ExecuteMedia(FConfig, FCatalog, FSelected);
      if O <> nil then
      try
        EnsureGroup('Medias', 8); AppendSystemMedia(FConfig.SystemAt(FSelected), O);
        BuildMedia; RefreshSettings;
      finally O.Free end;
    finally Setup.Free end;
    Exit;
  end;
  if Name.Contains('Clear') and Name.Contains('Cache') then
  begin
    CleanCache(not Name.Contains('Media'), not Name.Contains('GameInformation'));
    Exit;
  end;
  if Sender = RaisedButtonResetConfig then
  begin
    if TDialogServiceSync.MessageDialog(SK.Locale.L('Сбросить настройки выбранной системы? Для области «Все системы» будут восстановлены настройки платформ из каталога.'), TMsgDlgType.mtConfirmation, [TMsgDlgBtn.mbYes, TMsgDlgBtn.mbNo], TMsgDlgBtn.mbNo, 0) <> mrYes then
      Exit;
    FConfig.ResetSystemSettings(FSelected, FCatalog);
    BuildSystems;
    BuildMedia;
    RefreshSettings;
    Exit;
  end;
  Combo := nil;
  if Name.Contains('Method') then
    Combo := RollingButtonMethod;
  if Name.Contains('HTTPTries') then
    Combo := RollingButtonHTTPTries;
  if Name.Contains('CacheTTL') then
    Combo := RollingButtonCacheTTL;
  if Name.Contains('Classification') then
    Combo := RollingButtonClassification;
  if Name.Contains('MediaType') then
    Combo := RollingButtonMediaTypeSelector;
  if Combo <> nil then
  begin
    i := 1;
    if Name.EndsWith('Left') then
      i := -1;
    Combo.ItemIndex := (Combo.ItemIndex + i + Combo.Items.Count) mod Combo.Items.Count;
    Exit;
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
var
  i: Integer;
  S: TScrapeStatus;
begin
  ShowPage(1);
  PanelSettings.Enabled := False;
  PanelLeftPan.Enabled := False;
  ButtonAddSystem.Enabled := False;
  ButtonRemoveSystem.Enabled := False;
  ButtonRunWizard.Enabled := False;
  ConfigureSystem.Enabled := False;
  OpenPlatformLibrary.Enabled := False;
  ConfigureAll.Enabled := False;
  ImportConfigButton.Enabled := False;
  ExportConfigButton.Enabled := False;
  FFullLogReset := True;
  FastColoredTextBoxLogging.Lines.Clear;
  for i := 0 to 2 do
    FPreviewRevisions[i] := 0;
  PictureBoxScrapSample1.Bitmap.Clear(0);
  PictureBoxScrapSample2.Bitmap.Clear(0);
  PictureBoxScrapSample3.Bitmap.Clear(0);
  FDisplayedSystemID := '';
  RecentMediaNote.Text := SK.Locale.L('Изображения появятся после загрузки');
  ProgressBarMediaFoundPercent.Value := 0;
  LabelMediaCoverage.Text := '0.0%';
  MediaCoverageDetail.Text := SK.Locale.L('Найдено 0 из 0 запрошенных медиа');
  IconScrap.Visible := False;
  IconStop.Visible := False;
  ButtonScrap.Text := SK.Locale.L('Остановить');
  StartScraping.Enabled := False;
  SelectAllSystems.Enabled := False;
  ButtonScrap.Enabled := True;
  S := Default(TScrapeStatus);
  S.Started := Now;
  S.Running := True;
  S.Stage := 'Starting';
  ApplyScrapeStatus(S);
end;

function StageText(const Stage: string): string;
begin
  Result := Stage;
  if Stage = 'Starting' then
    Result := SK.Locale.L('Запуск')
  else if Stage = 'Downloading media' then
    Result := SK.Locale.L('Загрузка медиа')
  else if Stage = 'Preparing media' then
    Result := SK.Locale.L('Подготовка медиа')
  else if Stage = 'Hashing ROM' then
    Result := SK.Locale.L('Расчёт хеша ROM')
  else if Stage = 'Composing mix' then
    Result := SK.Locale.L('Создание Mix')
  else if Stage = 'Requesting metadata' then
    Result := SK.Locale.L('Получение метаданных')
  else if Stage = 'Saving game list' then
    Result := SK.Locale.L('Запись списка игр')
  else if Stage = 'Authenticating' then
    Result := SK.Locale.L('Авторизация')
  else if Stage = 'Scanning ROMs' then
    Result := SK.Locale.L('Поиск файлов ROM')
  else if Stage = 'Cancelled' then
    Result := SK.Locale.L('Отменено')
  else if Stage = 'Stopped' then
    Result := SK.Locale.L('Остановлено')
  else if Stage = 'Completed' then
    Result := SK.Locale.L('Завершено')
  else if Stage = 'Completed with errors' then
    Result := SK.Locale.L('Завершено с ошибками');
end;

procedure TFormMain.ApplyScrapeStatus(const S: TScrapeStatus);
var
  Seconds, Remaining, i, j: Integer;
  EndTime: TDateTime;
  Images: array[0..2] of TImage;
  Stream: TBytesStream;
  Preview: FMX.Graphics.TBitmap;
  EngineLabel: TLabel;
  EngineIcon: FMX.Objects.TPath;
  EngineDetail: TLabel;
  Obj: TFmxObject;
  EngineRow, TextColumn, MediaRow, StatsColumn: TLayout;
begin
  ScrapeLogChanged(nil);
  Images[0] := PictureBoxScrapSample1;
  Images[1] := PictureBoxScrapSample2;
  Images[2] := PictureBoxScrapSample3;
  for i := 0 to 2 do
    if (S.PreviewRevision[i] > FPreviewRevisions[i]) and (Length(S.PreviewData[i]) > 0) then
    begin
      Stream := TBytesStream.Create(S.PreviewData[i]);
      Preview := FMX.Graphics.TBitmap.Create;
      try
        try
          Preview.LoadFromStream(Stream);
          Images[i].Bitmap.Assign(Preview);
          Images[i].Hint := S.PreviewSource[i];
        except
          on E: Exception do
            FastColoredTextBoxLogging.Lines.Add('Preview: ' + E.Message);
        end;
        FPreviewRevisions[i] := S.PreviewRevision[i];
      finally
        Preview.Free;
        Stream.Free
      end;
    end;
  LabelEngineState.Visible := Length(S.Engines) = 0;
  LabelEngineFile.Visible := Length(S.Engines) = 0;
  LabelEngineMedia.Visible := Length(S.Engines) = 0;
  ProgressEngine.Visible := Length(S.Engines) = 0;
  if FEngineLabels.Count <> Length(S.Engines) then
  begin
    FEngineLabels.Clear;
    FEngineProgress.Clear;
    FEngineRows.Clear;
    for i := 0 to High(S.Engines) do
    begin
      EngineRow := TLayout.Create(nil);
      FEngineRows.Add(EngineRow);
      EngineRow.Parent := PanelScrapingEngines;
      EngineRow.Height := 80;
      EngineRow.Position.Y := i * 80;
      EngineRow.Align := TAlignLayout.Top;
      EngineRow.Padding.Right := 8;
      EngineRow.HitTest := False;
      TextColumn := TLayout.Create(EngineRow);
      TextColumn.Parent := EngineRow;
      TextColumn.Align := TAlignLayout.Client;
      TextColumn.Padding.Bottom := 8;
      TextColumn.HitTest := False;
      EngineLabel := TLabel.Create(EngineRow);
      FEngineLabels.Add(EngineLabel);
      EngineLabel.Parent := TextColumn;
      EngineLabel.Align := TAlignLayout.Top;
      EngineLabel.Height := 24;
      EngineLabel.StyledSettings := [];
      EngineLabel.TextSettings.FontColor := $FFF3F3F3;
      EngineLabel.TextSettings.Font.Size := 14;
      EngineLabel.TextSettings.Font.Style := [TFontStyle.fsBold];
      EngineLabel.TextSettings.WordWrap := True;
      EngineIcon := FMX.Objects.TPath.Create(EngineLabel);
      EngineIcon.Parent := EngineRow;
      EngineIcon.Align := TAlignLayout.Left;
      EngineIcon.Width := 28;
      EngineIcon.Margins.Rect := RectF(0, 16, 12, 36);
      EngineIcon.Data.Assign(NavScrapingIcon.Data);
      EngineIcon.Fill.Color := $FF60CDFF;
      EngineIcon.Stroke.Kind := TBrushKind.None;
      EngineIcon.WrapMode := TPathWrapMode.Fit;
      EngineIcon.HitTest := False;
      EngineDetail := TLabel.Create(EngineLabel);
      EngineDetail.Parent := TextColumn;
      EngineDetail.StyleName := 'enginephase';
      EngineDetail.Tag := i;
      EngineDetail.Align := TAlignLayout.Bottom;
      EngineDetail.Height := 24;
      EngineDetail.Opacity := 0.65;
      EngineDetail.TextSettings.Trimming := TTextTrimming.Character;
      MediaRow := TLayout.Create(EngineRow);
      MediaRow.Parent := TextColumn;
      MediaRow.Align := TAlignLayout.Client;
      MediaRow.HitTest := False;
      StatsColumn := TLayout.Create(EngineRow);
      StatsColumn.Parent := MediaRow;
      StatsColumn.Align := TAlignLayout.Right;
      StatsColumn.Width := 164;
      StatsColumn.Margins.Left := 8;
      StatsColumn.HitTest := False;
      EngineDetail := TLabel.Create(EngineLabel);
      EngineDetail.Parent := StatsColumn;
      EngineDetail.StyleName := 'enginepercent';
      EngineDetail.Tag := i;
      EngineDetail.Align := TAlignLayout.Right;
      EngineDetail.Width := 40;
      EngineDetail.Margins.Left := 8;
      EngineDetail.TextSettings.HorzAlign := TTextAlign.Trailing;
      FEngineProgress.Add(TProgressBar.Create(EngineLabel));
      FEngineProgress[i].Parent := StatsColumn;
      FEngineProgress[i].Align := TAlignLayout.Client;
      FEngineProgress[i].Width := 116;
      FEngineProgress[i].Margins.Rect := RectF(0, 9, 0, 9);
      EngineDetail := TLabel.Create(EngineLabel);
      EngineDetail.Parent := MediaRow;
      EngineDetail.StyleName := 'enginefile';
      EngineDetail.Tag := i;
      EngineDetail.Align := TAlignLayout.Client;
      EngineDetail.Opacity := 0.8;
      EngineDetail.TextSettings.Trimming := TTextTrimming.Character;
    end;
  end;
  for i := 0 to High(S.Engines) do
  begin
    FEngineProgress[i].Max := Max(1, S.Engines[i].MediaTotal);
    FEngineProgress[i].Value := S.Engines[i].CurrentMedia;
    FEngineLabels[i].Text := Format(SK.Locale.L('Поток %d'), [i + 1]);
    for j := 0 to FEngineLabels[i].ComponentCount - 1 do
    begin
      Obj := FEngineLabels[i].Components[j] as TFmxObject;
      if (Obj is TLabel) and (TLabel(Obj).Tag = i) then
      begin
        if Obj.StyleName = 'enginefile' then
          TLabel(Obj).Text := S.Engines[i].FileName
        else if Obj.StyleName = 'enginephase' then
          TLabel(Obj).Text := Format(SK.Locale.L('%s · %d из %d'), [StageText(S.Engines[i].Stage), S.Engines[i].CurrentMedia, S.Engines[i].MediaTotal])
        else if Obj.StyleName = 'enginepercent' then
          TLabel(Obj).Text := Format('%.0f%%', [100.0 * S.Engines[i].CurrentMedia / Max(1, S.Engines[i].MediaTotal)]);
      end;
    end;
  end;
  LabelEngineState.Text := StageText(S.Stage);
  LabelEngineFile.Text := S.CurrentFile;
  LabelEngineMedia.Text := Format(SK.Locale.L('Медиа %d / %d'), [S.CurrentMedia, S.MediaTotal]);
  ProgressEngine.Max := Max(1, S.MediaTotal);
  ProgressEngine.Value := S.CurrentMedia;
  ProgressBarMediaFoundPercent.Max := Max(1, S.MediaRequested);
  ProgressBarMediaFoundPercent.Value := S.MediaFound;
  MediaCoverageDetail.Text := Format(SK.Locale.L('Найдено %d из %d запрошенных медиа'), [S.MediaFound, S.MediaRequested]);
  LabelMediaCoverage.Text := Format('%.1f%%', [100.0 * S.MediaFound / Max(1, S.MediaRequested)]);
  LabelScrapedGamesValue.Text := S.Found.ToString;
  LabelGameNotFoundValue.Text := S.Missing.ToString;
  LabelErrorsValue.Text := S.Errors.ToString;
  if S.Errors > 0 then
    LabelErrorsValue.TextSettings.FontColor := $FFF0B455
  else
    LabelErrorsValue.TextSettings.FontColor := $FFF0B455;
  ScrapeStateBadge.Fill.Color := $FF60CDFF;
  if S.Finished then
  begin
    if S.Cancelled then
      ScrapeStateText.Text := SK.Locale.L('Остановлено')
    else if S.Errors > 0 then
    begin
      ScrapeStateText.Text := SK.Locale.L('Есть ошибки');
      ScrapeStateBadge.Fill.Color := $FFF0B455
    end
    else
      ScrapeStateText.Text := SK.Locale.L('Завершено');
  end
  else if S.Running then
    ScrapeStateText.Text := SK.Locale.L('Выполняется')
  else
    ScrapeStateText.Text := SK.Locale.L('Ожидание');
  LabelDownloadedMediaValue.Text := S.Downloaded.ToString;
  LabelSavedMediaValue.Text := S.Saved.ToString;
  if S.QuotaText <> '' then
  begin
    LabelQuotaValue.Text := S.QuotaText;
    AccountQuotaValue.Text := S.QuotaText;
    LabelQuotaValue.Hint := SK.Locale.L('Запросы сегодня / суточный лимит ScreenScraper. Обновлено: ') +
      FormatDateTime('dd.mm hh:nn:ss', S.QuotaUpdated);
  end;
  LabelCachedValue.Text := S.Cached.ToString;
  LabelRequestsValue.Text := S.Requests.ToString;
  LabelFavoriteGamesValue.Text := S.Favorites.ToString;
  LabelHiddenGamesValue.Text := S.Hidden.ToString;
  if S.Finished and (S.FinishedAt > 0) then
    EndTime := S.FinishedAt
  else
    EndTime := Now;
  if S.Started > 0 then
    Seconds := SecondsBetween(EndTime, S.Started)
  else
    Seconds := 0;
  LabelElapsedValue.Text := Format(SK.Locale.L('Прошло %.2d:%.2d:%.2d'), [Seconds div 3600, (Seconds div 60) mod 60, Seconds mod 60]);
  ProgressBarScrappingGames.Max := Max(1, S.Total);
  ProgressBarScrappingGames.Value := S.Completed;
  ProgressBarScrapingSystems.Max := Max(1, S.SystemsTotal);
  ProgressBarScrapingSystems.Value := S.SystemsCompleted;
  LabelScrapingSystemCount.Text := S.SystemsCompleted.ToString + ' / ' + S.SystemsTotal.ToString;
  LabelEstimatedTimeValue.Text := '--:--:--';
  if S.Finished then
    LabelEstimatedTimeValue.Text := '00:00:00'
  else if S.Completed > 0 then
  begin
    Remaining := Round(Seconds * (S.Total - S.Completed) / Max(1, S.Completed));
    LabelEstimatedTimeValue.Text := Format('%.2d:%.2d:%.2d', [Remaining div 3600, (Remaining div 60) mod 60, Remaining mod 60]);
  end;
  LabelEstimatedTimeValue.Text := SK.Locale.L('Осталось примерно ') + LabelEstimatedTimeValue.Text;
  LabelScrapingGameCount.Text := Format(SK.Locale.L('%d из %d игр'), [S.Completed, S.Total]);
  FScrapeSubtitle := Format(SK.Locale.L('%s · система %d из %d'), [S.CurrentSystem, Min(S.SystemsTotal, S.SystemsCompleted + Ord(not S.Finished)), S.SystemsTotal]);
  if PageTabControl.TabIndex = 1 then
    PageSubtitle.Text := FScrapeSubtitle;
  LabelSystemName.Text := S.CurrentSystem;
  ScrapePercent.Text := Format('%.0f%%', [100.0 * S.Completed / Max(1, S.Total)]);
  ScrapeSummary.Text := Format(SK.Locale.L('ScreenScraper · %d потоков · %d запросов · %d из кэша · %d загружено'),
    [Length(S.Engines), S.Requests, S.Cached, S.Downloaded]);
  if not PictureBoxScrapSample1.Bitmap.IsEmpty then
    RecentMediaNote.Text := System.IOUtils.TPath.GetFileNameWithoutExtension(S.CurrentFile);
  if PageTabControl.TabIndex = 3 then
    SyncFullLog;
  if S.Finished then
  begin
    IconScrap.Visible := False;
    IconStop.Visible := False;
    PanelSettings.Enabled := True;
    PanelLeftPan.Enabled := True;
    ImportConfigButton.Enabled := True;
    ExportConfigButton.Enabled := True;
    SelectAllSystems.Enabled := True;
    UpdateSelectionCount;
    ButtonAddSystem.Enabled := True;
    ButtonRunWizard.Enabled := True;
    ConfigureAll.Enabled := True;
    UpdateInspector;
    ButtonScrap.Enabled := True;
    ButtonScrap.Text := SK.Locale.L('В библиотеку');
    if S.Cancelled then
      ScrapeSummary.Text := SK.Locale.L('Остановлено · ') + ScrapeSummary.Text
    else if S.Errors > 0 then
      ScrapeSummary.Text := SK.Locale.L('Завершено с ошибками · ') + ScrapeSummary.Text
    else
      ScrapeSummary.Text := SK.Locale.L('Завершено · ') + ScrapeSummary.Text;
  end;
end;

procedure ReplaceObject(Target, Source: TJSONObject);
var
  Pair: TJSONPair;
begin
  while Target.Count > 0 do
    Target.RemovePair(Target.Pairs[0].JsonString.Value).Free;
  for Pair in Source do
    Target.AddPair(Pair.JsonString.Value, Pair.JsonValue.Clone as TJSONValue);
end;

procedure TFormMain.ShowPage(Page: Integer);
begin
  if (Page < 0) or (Page >= PageTabControl.TabCount) then
    raise EArgumentOutOfRangeException.Create('Page');
  if PageTabControl.TabIndex = Page then PageTabChanged(nil)
  else PageTabControl.TabIndex := Page;
end;

procedure TFormMain.SyncFullLog;
var
  Source: TStrings;
  Count, First, I, SelectionStart, SelectionLength: Integer;
  OldViewport: TPointF;
  Reset, FollowTail: Boolean;
begin
  Source := FastColoredTextBoxLogging.Lines;
  Count := Source.Count;
  Reset := FFullLogReset or (Count < FFullLogCount);
  if not Reset and (FFullLogCount > 0) then
    Reset := Source[FFullLogCount - 1] <> FFullLogTail;
  // Never touch the memo for a status tick that contains no new lines.
  // This also leaves its active wheel animation and selection undisturbed.
  if not Reset and (Count = FFullLogCount) then Exit;
  OldViewport := FullLog.ViewportPosition;
  FollowTail := Reset or (OldViewport.Y + FullLog.ViewportSize.Height >= FullLog.ContentSize.Height - 2);
  SelectionStart := FullLog.SelStart;
  SelectionLength := FullLog.SelLength;
  First := FFullLogCount;
  if Reset then
  begin
    First := 0;
    SelectionStart := 0;
    SelectionLength := 0;
  end;
  FullLog.BeginUpdate;
  try
    FullLog.Lines.BeginUpdate;
    try
      if Reset then FullLog.Lines.Clear;
      for I := First to Count - 1 do FullLog.Lines.Add(Source[I]);
    finally
      FullLog.Lines.EndUpdate;
    end;
  finally
    FullLog.EndUpdate;
  end;
  FullLog.SelStart := SelectionStart;
  FullLog.SelLength := SelectionLength;
  // Memo layout may reveal its caret while processing LinesChanged. Restore the
  // reader's viewport after layout, and follow new output only from the bottom.
  if FollowTail then
    FullLog.ViewportPosition := PointF(OldViewport.X,
      Max(0, FullLog.ContentSize.Height - FullLog.ViewportSize.Height))
  else FullLog.ViewportPosition := OldViewport;
  FFullLogCount := Count;
  FFullLogTail := '';
  if Count > 0 then FFullLogTail := Source[Count - 1];
  FFullLogReset := False;
end;

procedure TFormMain.PageTabChanged(Sender: TObject);
var
  Page: Integer;
  ActiveButton: TButton;
  Icons: array[0..3] of FMX.Objects.TPath;
  i: Integer;
begin
  if (csLoading in ComponentState) or (csDestroying in ComponentState) or (FConfig = nil) then Exit;
  Page := PageTabControl.TabIndex;
  if Page < 0 then Exit;
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
    0: ActiveButton := NavLibrary;
    1: ActiveButton := NavScraping;
    2: ActiveButton := NavSettings;
  else ActiveButton := NavLog;
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
        PageSubtitle.Text := FScrapeSubtitle
      end;
    2:
      begin
        PageTitle.Text := SK.Locale.L('Настройки');
        PageSubtitle.Text := SK.Locale.L('Параметры скраппинга и сохранения файлов');
        if FSettingsSnapshot = nil then
        begin
          FSettingsSnapshot := FConfig.Root.Clone as TJSONObject;
          FCredentialSnapshot := FConfig.Credentials.Clone as TJSONObject;
        end;
      end;
    3:
      begin
        PageTitle.Text := SK.Locale.L('Журнал');
        PageSubtitle.Text := SK.Locale.L('События текущего сеанса скраппинга');
        SyncFullLog;
      end;
  end;
end;

procedure TFormMain.ShellAction(Sender: TObject);
var
  Page: Integer;
begin
  Page := TControl(Sender).Tag;
  if FCacheBusy then Exit;
  if (Page in [2, 4, 5, 6, 8, 9, 10]) and (FWorker <> nil) and not FWorker.Finished then
  begin
    ShowPage(1);
    Exit
  end;
  case Page of
    0..3:
      ShowPage(Page);
    4:
      begin
        ShowPage(2);
        SettingsTabControl.ActiveTab := TabAccount
      end;
    5:
      begin
        ShowPage(2);
        SettingsTabControl.ActiveTab := TabSource
      end;
    6:
      begin
        FSelected := -1;
        FMedia := 0;
        BuildSystems;
        BuildMedia;
        RefreshSettings;
        ShowPage(2);
      end;
    7:
      begin
        if (FWorker <> nil) and FWorker.Finished then
          FreeAndNil(FWorker);
        if FWorker <> nil then
        begin
          ShowPage(1);
          Exit
        end;
        ActionClick(ButtonScrap);
      end;
    8:
      ActionClick(RaisedButtonResetConfig);
    9:
      begin
        if FSettingsSnapshot <> nil then
        begin
          ReplaceObject(FConfig.Root, FSettingsSnapshot);
          ReplaceObject(FConfig.Credentials, FCredentialSnapshot);
          SetLocale(JStr(FConfig.Root, 'Culture', 'ru'));
          FRefreshing := True;
          try ApplyLocale(Self) finally FRefreshing := False end;
          FSample := EnsureRange(JInt(FConfig.Root, 'SampleSet'), 0, 5);
        end;
        FreeAndNil(FSettingsSnapshot);
        FreeAndNil(FCredentialSnapshot);
        FSelected := -1;
        FMedia := 0;
        BuildSystems;
        BuildMedia;
        RefreshSettings;
        ShowPage(0);
      end;
    10:
      begin
        SaveConfig;
        FreeAndNil(FSettingsSnapshot);
        FreeAndNil(FCredentialSnapshot);
        BuildSystems;
        UpdateInspector;
        ShowPage(0);
      end;
    11:
      begin
        SaveDialog.Filter := SK.Locale.L('Текстовый журнал|*.txt');
        SaveDialog.DefaultExt := 'txt';
        SaveDialog.FileName := 'skraper-log.txt';
        SaveDialog.InitialDir := FConfig.DialogFolder('LogFolder', '');
        if SaveDialog.Execute then
        begin
          FConfig.RememberFolder('LogFolder', ExtractFilePath(SaveDialog.FileName));
          FastColoredTextBoxLogging.Lines.SaveToFile(SaveDialog.FileName, TEncoding.UTF8);
        end;
      end;
  end;
end;

function TFormMain.CreateRunConfig: TJSONObject;
var
  i: Integer;
  Selected: TJSONArray;
  Source: TJSONArray;
begin
  Result := FConfig.Root.Clone as TJSONObject;
  Selected := TJSONArray.Create;
  Source := FConfig.Root.GetValue<TJSONArray>('Systems');
  for i := 0 to Source.Count - 1 do
    if FCheckedSystems.ContainsKey(SystemKey(i)) and FCheckedSystems[SystemKey(i)] then
      Selected.AddElement(Source.Items[i].Clone as TJSONValue);
  JSet(Result, 'Systems', Selected);
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
var
  i: Integer;
  Item: TListBoxItem;
  Caption: TLabel;
  Icon: FMX.Objects.TPath;
  Rule: TRectangle;
  MessageText, Stamp, Lower: string;
  Template: TPathData;
  Color: TAlphaColor;
begin
  if (csDestroying in ComponentState) or (ScrapeEventList = nil) then
    Exit;
  MessageText := '';
  if FastColoredTextBoxLogging.Lines.Count > 0 then
    MessageText := FastColoredTextBoxLogging.Lines[FastColoredTextBoxLogging.Lines.Count - 1];
  if (FDisplayedLogCount = FastColoredTextBoxLogging.Lines.Count) and (FDisplayedLogTail = MessageText) then
    Exit;
  FDisplayedLogCount := FastColoredTextBoxLogging.Lines.Count;
  FDisplayedLogTail := MessageText;
  ScrapeEventList.BeginUpdate;
  try
    ScrapeEventList.Clear;
    for i := Max(0, FastColoredTextBoxLogging.Lines.Count - MaxVisibleLogEntries) to FastColoredTextBoxLogging.Lines.Count - 1 do
    begin
      MessageText := FastColoredTextBoxLogging.Lines[i];
      Stamp := '';
      if (Length(MessageText) >= 10) and (MessageText[3] = ':') and (MessageText[6] = ':') then
      begin
        Stamp := Copy(MessageText, 1, 8);
        Delete(MessageText, 1, 10)
      end;
      Lower := MessageText.ToLower;
      Template := FLogInfoData;
      Color := $FF60CDFF;
      if Lower.Contains('error') or Lower.Contains('ошиб') or Lower.Contains('not found') then
      begin
        Template := FLogErrorData;
        Color := $FFF0B455
      end
      else if Lower.Contains('completed') or Lower.Contains('saved') or Lower.Contains('получены') or Lower.Contains('сохран') then
      begin
        Template := FLogSuccessData;
        Color := $FF6CCB5F
      end;
      Item := TListBoxItem.Create(ScrapeEventList);
      Item.Parent := ScrapeEventList;
      Item.Height := 36;
      Item.Text := '';
      Icon := FMX.Objects.TPath.Create(Item);
      Icon.Parent := Item;
      Icon.Align := TAlignLayout.Left;
      Icon.Width := 20;
      Icon.Margins.Rect := RectF(0, 8, 16, 8);
      Icon.Data.Assign(Template);
      Icon.Fill.Color := Color;
      Icon.Stroke.Kind := TBrushKind.None;
      Icon.WrapMode := TPathWrapMode.Fit;
      Icon.HitTest := False;
      Caption := TLabel.Create(Item);
      Caption.Parent := Item;
      Caption.Align := TAlignLayout.Left;
      Caption.Width := 80;
      Caption.Text := Stamp;
      Caption.Opacity := 0.72;
      Caption.HitTest := False;
      Caption := TLabel.Create(Item);
      Caption.Parent := Item;
      Caption.Align := TAlignLayout.Client;
      Caption.Margins.Rect := RectF(12, 0, 16, 0);
      Caption.Text := MessageText;
      Caption.TextSettings.WordWrap := False;
      Caption.TextSettings.Trimming := TTextTrimming.Character;
      Caption.HitTest := False;
      Item.Hint := MessageText;
      Item.ShowHint := True;
      Rule := TRectangle.Create(Item);
      Rule.Parent := Item;
      Rule.Align := TAlignLayout.Bottom;
      Rule.Height := 1;
      Rule.Fill.Color := $FF414141;
      Rule.Stroke.Kind := TBrushKind.None;
      Rule.HitTest := False;
    end;
  finally
    ScrapeEventList.EndUpdate
  end;
  if ScrapeEventList.Count > 0 then
    ScrapeEventList.ScrollToItem(ScrapeEventList.ListItems[ScrapeEventList.Count - 1]);
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
