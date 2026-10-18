unit SK.UI.Scraping;

interface

uses
  System.SysUtils, System.Classes, System.Types, System.UITypes,
  System.Generics.Collections, FMX.TabControl, FMX.Types, FMX.Controls,
  FMX.Layouts, FMX.Objects, FMX.StdCtrls, FMX.Memo, FMX.ListBox, SK.Scrape.Types;

type
  TScrapeControls = record
    OpenPlatformLibrary: TButton;
    AccountQuotaValue: TLabel;
    LabelQuotaValue: TLabel;
    ScrapeStateBadge: TRectangle;
    ScrapeStateText: TLabel;
    NavScrapingIcon: FMX.Objects.TPath;
    PageTabControl: TTabControl;
    PageSubtitle: TLabel;
    SelectAllSystems: TCheckBox;
    ConfigureSystem: TButton;
    ConfigureAll: TButton;
    StartScraping: TButton;
    ScrapePercent: TLabel;
    RecentMediaNote: TLabel;
    ScrapeSummary: TLabel;
    ProgressBarScrappingGames: TProgressBar;
    LabelScrapingGameCount: TLabel;
    ButtonScrap: TButton;
    PanelSettings: TLayout;
    FastColoredTextBoxLogging: TMemo;
    PictureBoxScrapSample3: TImage;
    PictureBoxScrapSample1: TImage;
    PictureBoxScrapSample2: TImage;
    LabelErrorsValue: TLabel;
    LabelEstimatedTimeValue: TLabel;
    LabelElapsedValue: TLabel;
    LabelSavedMediaValue: TLabel;
    PanelScrapingEngines: TVertScrollBox;
    LabelEngineState: TLabel;
    LabelEngineFile: TLabel;
    LabelEngineMedia: TLabel;
    ProgressEngine: TProgressBar;
    MediaCoverageDetail: TLabel;
    LabelMediaCoverage: TLabel;
    ProgressBarMediaFoundPercent: TProgressBar;
    LabelGameNotFoundValue: TLabel;
    LabelScrapedGamesValue: TLabel;
    PanelLeftPan: TLayout;
    ButtonAddSystem: TButton;
    ButtonRunWizard: TButton;
    ButtonRemoveSystem: TButton;
    ImportConfigButton: TButton;
    ExportConfigButton: TButton;
  end;

  TScrapePresenter = class
  private
    FView: TScrapeControls;
    FPreviewRevisions: array[0..2] of Int64;
    FEngineLabels: TObjectList<TLabel>;
    FEngineProgress: TObjectList<TProgressBar>;
    FEngineRows: TObjectList<TLayout>;
    FScrapeSubtitle: string;
  public
    OnLogChanged, OnFullLog, OnFinished: TProc;
    constructor Create(View: TComponent);
    destructor Destroy; override;
    procedure BeginScrape;
    procedure ApplyStatus(const S: TScrapeStatus);
    property Subtitle: string read FScrapeSubtitle;
  end;

function StageText(const Stage: string): string;

implementation

uses
  System.Math, System.DateUtils, System.IOUtils, FMX.Graphics, SK.Locale,
  SK.Consts, SK.Platform, SK.Storage, SK.UI.Controls;

constructor TScrapePresenter.Create(View: TComponent);
begin
  inherited Create;
  FView.OpenPlatformLibrary := RequireComponent(View, 'OpenPlatformLibrary') as TButton;
  FView.AccountQuotaValue := RequireComponent(View, 'AccountQuotaValue') as TLabel;
  FView.LabelQuotaValue := RequireComponent(View, 'LabelQuotaValue') as TLabel;
  FView.ScrapeStateBadge := RequireComponent(View, 'ScrapeStateBadge') as TRectangle;
  FView.ScrapeStateText := RequireComponent(View, 'ScrapeStateText') as TLabel;
  FView.NavScrapingIcon := RequireComponent(View, 'NavScrapingIcon') as FMX.Objects.TPath;
  FView.PageTabControl := RequireComponent(View, 'PageTabControl') as TTabControl;
  FView.PageSubtitle := RequireComponent(View, 'PageSubtitle') as TLabel;
  FView.SelectAllSystems := RequireComponent(View, 'SelectAllSystems') as TCheckBox;
  FView.ConfigureSystem := RequireComponent(View, 'ConfigureSystem') as TButton;
  FView.ConfigureAll := RequireComponent(View, 'ConfigureAll') as TButton;
  FView.StartScraping := RequireComponent(View, 'StartScraping') as TButton;
  FView.ScrapePercent := RequireComponent(View, 'ScrapePercent') as TLabel;
  FView.RecentMediaNote := RequireComponent(View, 'RecentMediaNote') as TLabel;
  FView.ScrapeSummary := RequireComponent(View, 'ScrapeSummary') as TLabel;
  FView.ProgressBarScrappingGames := RequireComponent(View, 'ProgressBarScrappingGames') as TProgressBar;
  FView.LabelScrapingGameCount := RequireComponent(View, 'LabelScrapingGameCount') as TLabel;
  FView.ButtonScrap := RequireComponent(View, 'ButtonScrap') as TButton;
  FView.PanelSettings := RequireComponent(View, 'PanelSettings') as TLayout;
  FView.FastColoredTextBoxLogging := RequireComponent(View, 'FastColoredTextBoxLogging') as TMemo;
  FView.PictureBoxScrapSample3 := RequireComponent(View, 'PictureBoxScrapSample3') as TImage;
  FView.PictureBoxScrapSample1 := RequireComponent(View, 'PictureBoxScrapSample1') as TImage;
  FView.PictureBoxScrapSample2 := RequireComponent(View, 'PictureBoxScrapSample2') as TImage;
  FView.LabelErrorsValue := RequireComponent(View, 'LabelErrorsValue') as TLabel;
  FView.LabelEstimatedTimeValue := RequireComponent(View, 'LabelEstimatedTimeValue') as TLabel;
  FView.LabelElapsedValue := RequireComponent(View, 'LabelElapsedValue') as TLabel;
  FView.LabelSavedMediaValue := RequireComponent(View, 'LabelSavedMediaValue') as TLabel;
  FView.PanelScrapingEngines := RequireComponent(View, 'PanelScrapingEngines') as TVertScrollBox;
  FView.LabelEngineState := RequireComponent(View, 'LabelEngineState') as TLabel;
  FView.LabelEngineFile := RequireComponent(View, 'LabelEngineFile') as TLabel;
  FView.LabelEngineMedia := RequireComponent(View, 'LabelEngineMedia') as TLabel;
  FView.ProgressEngine := RequireComponent(View, 'ProgressEngine') as TProgressBar;
  FView.MediaCoverageDetail := RequireComponent(View, 'MediaCoverageDetail') as TLabel;
  FView.LabelMediaCoverage := RequireComponent(View, 'LabelMediaCoverage') as TLabel;
  FView.ProgressBarMediaFoundPercent := RequireComponent(View, 'ProgressBarMediaFoundPercent') as TProgressBar;
  FView.LabelGameNotFoundValue := RequireComponent(View, 'LabelGameNotFoundValue') as TLabel;
  FView.LabelScrapedGamesValue := RequireComponent(View, 'LabelScrapedGamesValue') as TLabel;
  FView.PanelLeftPan := RequireComponent(View, 'PanelLeftPan') as TLayout;
  FView.ButtonAddSystem := RequireComponent(View, 'ButtonAddSystem') as TButton;
  FView.ButtonRunWizard := RequireComponent(View, 'ButtonRunWizard') as TButton;
  FView.ButtonRemoveSystem := RequireComponent(View, 'ButtonRemoveSystem') as TButton;
  FView.ImportConfigButton := RequireComponent(View, 'ImportConfigButton') as TButton;
  FView.ExportConfigButton := RequireComponent(View, 'ExportConfigButton') as TButton;
  FEngineRows := TObjectList<TLayout>.Create(True);
  FEngineLabels := TObjectList<TLabel>.Create(False);
  FEngineProgress := TObjectList<TProgressBar>.Create(False);
end;

destructor TScrapePresenter.Destroy;
begin
  FEngineLabels.Free;
  FEngineProgress.Free;
  FEngineRows.Free;
  inherited;
end;

procedure TScrapePresenter.BeginScrape;
var
  i: Integer;
  S: TScrapeStatus;
begin
  FView.PanelSettings.Enabled := False;
  FView.PanelLeftPan.Enabled := False;
  FView.ButtonAddSystem.Enabled := False;
  FView.ButtonRemoveSystem.Enabled := False;
  FView.ButtonRunWizard.Enabled := False;
  FView.ConfigureSystem.Enabled := False;
  FView.OpenPlatformLibrary.Enabled := False;
  FView.ConfigureAll.Enabled := False;
  FView.ImportConfigButton.Enabled := False;
  FView.ExportConfigButton.Enabled := False;
  FView.FastColoredTextBoxLogging.Lines.Clear;
  for i := 0 to 2 do
    FPreviewRevisions[i] := 0;
  FView.PictureBoxScrapSample1.Bitmap.Clear(0);
  FView.PictureBoxScrapSample2.Bitmap.Clear(0);
  FView.PictureBoxScrapSample3.Bitmap.Clear(0);
  FView.RecentMediaNote.Text := SK.Locale.L('Изображения появятся после загрузки');
  FView.ProgressBarMediaFoundPercent.Value := 0;
  FView.LabelMediaCoverage.Text := '0.0%';
  FView.MediaCoverageDetail.Text := SK.Locale.L('Найдено 0 из 0 запрошенных медиа');
  FView.ButtonScrap.Text := SK.Locale.L('Остановить');
  FView.StartScraping.Enabled := False;
  FView.SelectAllSystems.Enabled := False;
  FView.ButtonScrap.Enabled := True;
  S := Default(TScrapeStatus);
  S.Started := Now;
  S.Running := True;
  S.Stage := 'Starting';
  ApplyStatus(S);
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

procedure TScrapePresenter.ApplyStatus(const S: TScrapeStatus);
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
  if Assigned(OnLogChanged) then
    OnLogChanged;
  Images[0] := FView.PictureBoxScrapSample1;
  Images[1] := FView.PictureBoxScrapSample2;
  Images[2] := FView.PictureBoxScrapSample3;
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
            FView.FastColoredTextBoxLogging.Lines.Add('Preview: ' + E.Message);
        end;
        FPreviewRevisions[i] := S.PreviewRevision[i];
      finally
        Preview.Free;
        Stream.Free
      end;
    end;
  FView.LabelEngineState.Visible := Length(S.Engines) = 0;
  FView.LabelEngineFile.Visible := Length(S.Engines) = 0;
  FView.LabelEngineMedia.Visible := Length(S.Engines) = 0;
  FView.ProgressEngine.Visible := Length(S.Engines) = 0;
  if FEngineLabels.Count <> Length(S.Engines) then
  begin
    FEngineLabels.Clear;
    FEngineProgress.Clear;
    FEngineRows.Clear;
    for i := 0 to High(S.Engines) do
    begin
      EngineRow := TLayout.Create(nil);
      FEngineRows.Add(EngineRow);
      EngineRow.Parent := FView.PanelScrapingEngines;
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
      EngineIcon.Data.Assign(FView.NavScrapingIcon.Data);
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
  FView.LabelEngineState.Text := StageText(S.Stage);
  FView.LabelEngineFile.Text := S.CurrentFile;
  FView.LabelEngineMedia.Text := Format(SK.Locale.L('Медиа %d / %d'), [S.CurrentMedia, S.MediaTotal]);
  FView.ProgressEngine.Max := Max(1, S.MediaTotal);
  FView.ProgressEngine.Value := S.CurrentMedia;
  FView.ProgressBarMediaFoundPercent.Max := Max(1, S.MediaRequested);
  FView.ProgressBarMediaFoundPercent.Value := S.MediaFound;
  FView.MediaCoverageDetail.Text := Format(SK.Locale.L('Найдено %d из %d запрошенных медиа'), [S.MediaFound, S.MediaRequested]);
  FView.LabelMediaCoverage.Text := Format('%.1f%%', [100.0 * S.MediaFound / Max(1, S.MediaRequested)]);
  FView.LabelScrapedGamesValue.Text := S.Found.ToString;
  FView.LabelGameNotFoundValue.Text := S.Missing.ToString;
  FView.LabelErrorsValue.Text := S.Errors.ToString;
  if S.Errors > 0 then
    FView.LabelErrorsValue.TextSettings.FontColor := $FFF0B455
  else
    FView.LabelErrorsValue.TextSettings.FontColor := $FFF0B455;
  FView.ScrapeStateBadge.Fill.Color := $FF60CDFF;
  if S.Finished then
  begin
    if S.Cancelled then
      FView.ScrapeStateText.Text := SK.Locale.L('Остановлено')
    else if S.Errors > 0 then
    begin
      FView.ScrapeStateText.Text := SK.Locale.L('Есть ошибки');
      FView.ScrapeStateBadge.Fill.Color := $FFF0B455
    end
    else
      FView.ScrapeStateText.Text := SK.Locale.L('Завершено');
  end
  else if S.Running then
    FView.ScrapeStateText.Text := SK.Locale.L('Выполняется')
  else
    FView.ScrapeStateText.Text := SK.Locale.L('Ожидание');
  FView.LabelSavedMediaValue.Text := S.Saved.ToString;
  if S.QuotaText <> '' then
  begin
    FView.LabelQuotaValue.Text := S.QuotaText;
    FView.AccountQuotaValue.Text := S.QuotaText;
    FView.LabelQuotaValue.Hint := SK.Locale.L('Запросы сегодня / суточный лимит ScreenScraper. Обновлено: ') +
      FormatDateTime('dd.mm hh:nn:ss', S.QuotaUpdated);
  end;
  if S.Finished and (S.FinishedAt > 0) then
    EndTime := S.FinishedAt
  else
    EndTime := Now;
  if S.Started > 0 then
    Seconds := SecondsBetween(EndTime, S.Started)
  else
    Seconds := 0;
  FView.LabelElapsedValue.Text := Format(SK.Locale.L('Прошло %.2d:%.2d:%.2d'), [Seconds div 3600, (Seconds div 60) mod 60, Seconds mod 60]);
  FView.ProgressBarScrappingGames.Max := Max(1, S.Total);
  FView.ProgressBarScrappingGames.Value := S.Completed;
  FView.LabelEstimatedTimeValue.Text := '--:--:--';
  if S.Finished then
    FView.LabelEstimatedTimeValue.Text := '00:00:00'
  else if S.Completed > 0 then
  begin
    Remaining := Round(Seconds * (S.Total - S.Completed) / Max(1, S.Completed));
    FView.LabelEstimatedTimeValue.Text := Format('%.2d:%.2d:%.2d', [Remaining div 3600, (Remaining div 60) mod 60, Remaining mod 60]);
  end;
  FView.LabelEstimatedTimeValue.Text := SK.Locale.L('Осталось примерно ') + FView.LabelEstimatedTimeValue.Text;
  FView.LabelScrapingGameCount.Text := Format(SK.Locale.L('%d из %d игр'), [S.Completed, S.Total]);
  FScrapeSubtitle := Format(SK.Locale.L('%s · система %d из %d'), [S.CurrentSystem, Min(S.SystemsTotal, S.SystemsCompleted + Ord(not S.Finished)), S.SystemsTotal]);
  if FView.PageTabControl.TabIndex = 1 then
    FView.PageSubtitle.Text := FScrapeSubtitle;
  FView.ScrapePercent.Text := Format('%.0f%%', [100.0 * S.Completed / Max(1, S.Total)]);
  FView.ScrapeSummary.Text := Format(SK.Locale.L('ScreenScraper · %d потоков · %d запросов · %d из кэша · %d загружено'),
    [Length(S.Engines), S.Requests, S.Cached, S.Downloaded]);
  if not FView.PictureBoxScrapSample1.Bitmap.IsEmpty then
    FView.RecentMediaNote.Text := System.IOUtils.TPath.GetFileNameWithoutExtension(S.CurrentFile);
  if FView.PageTabControl.TabIndex = 3 then
    if Assigned(OnFullLog) then
      OnFullLog;
  if S.Finished then
  begin
    FView.PanelSettings.Enabled := True;
    FView.PanelLeftPan.Enabled := True;
    FView.ImportConfigButton.Enabled := True;
    FView.ExportConfigButton.Enabled := True;
    FView.SelectAllSystems.Enabled := True;
    FView.ButtonAddSystem.Enabled := True;
    FView.ButtonRunWizard.Enabled := True;
    FView.ConfigureAll.Enabled := True;
    FView.ButtonScrap.Enabled := True;
    if Assigned(OnFinished) then
      OnFinished;
    FView.ButtonScrap.Text := SK.Locale.L('В библиотеку');
    if S.Cancelled then
      FView.ScrapeSummary.Text := SK.Locale.L('Остановлено · ') + FView.ScrapeSummary.Text
    else if S.Errors > 0 then
      FView.ScrapeSummary.Text := SK.Locale.L('Завершено с ошибками · ') + FView.ScrapeSummary.Text
    else
      FView.ScrapeSummary.Text := SK.Locale.L('Завершено · ') + FView.ScrapeSummary.Text;
  end;
end;

end.

