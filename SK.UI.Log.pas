unit SK.UI.Log;

interface

uses
  System.SysUtils, System.Classes, System.Types, System.UITypes,
  System.Generics.Collections, FMX.Graphics, FMX.Types, FMX.Controls,
  FMX.Layouts, FMX.Objects, FMX.StdCtrls, FMX.Memo, FMX.ListBox, SK.Scrape.Types;

type
  TLogControls = record
    ScrapeEventList: TListBox;
    FullLog: TMemo;
    FastColoredTextBoxLogging: TMemo;
  end;

  TLogPresenter = class
  private
    FView: TLogControls;
    FLogInfoData, FLogSuccessData, FLogErrorData: TPathData;
    FDisplayedLogCount, FFullLogCount: Integer;
    FDisplayedLogTail, FFullLogTail: string;
    FFullLogReset, FEventsReset: Boolean;
  public
    constructor Create(View: TComponent);
    destructor Destroy; override;
    procedure Reset;
    procedure SyncFullLog;
    procedure RefreshEvents;
  end;

implementation

uses
  System.Math, System.DateUtils, System.IOUtils, SK.Locale, SK.Consts,
  SK.Platform, SK.Storage, SK.UI.Controls;

function LoadLogPath(const RelativePath: string): TPathData; forward;

constructor TLogPresenter.Create(View: TComponent);
begin
  inherited Create;
  FView.ScrapeEventList := RequireComponent(View, 'ScrapeEventList') as TListBox;
  FView.FullLog := RequireComponent(View, 'FullLog') as TMemo;
  FView.FastColoredTextBoxLogging := RequireComponent(View, 'FastColoredTextBoxLogging') as TMemo;
  FFullLogReset := True;
  FEventsReset := True;
  FLogInfoData := LoadLogPath(LogInfoIconPath);
  FLogSuccessData := LoadLogPath(LogSuccessIconPath);
  FLogErrorData := LoadLogPath(LogErrorIconPath);
end;

destructor TLogPresenter.Destroy;
begin
  FLogInfoData.Free;
  FLogSuccessData.Free;
  FLogErrorData.Free;
  inherited;
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

procedure TLogPresenter.SyncFullLog;
var
  Source: TStrings;
  Count, First, I, SelectionStart, SelectionLength: Integer;
  OldViewport: TPointF;
  Reset, FollowTail: Boolean;
begin
  Source := FView.FastColoredTextBoxLogging.Lines;
  Count := Source.Count;
  Reset := FFullLogReset or (Count < FFullLogCount);
  if not Reset and (FFullLogCount > 0) then
    Reset := Source[FFullLogCount - 1] <> FFullLogTail;
  // Never touch the memo for a status tick that contains no new lines.
  // This also leaves its active wheel animation and selection undisturbed.
  if not Reset and (Count = FFullLogCount) then
    Exit;
  OldViewport := FView.FullLog.ViewportPosition;
  FollowTail := Reset or (OldViewport.Y + FView.FullLog.ViewportSize.Height >= FView.FullLog.ContentSize.Height - 2);
  SelectionStart := FView.FullLog.SelStart;
  SelectionLength := FView.FullLog.SelLength;
  First := FFullLogCount;
  if Reset then
  begin
    First := 0;
    SelectionStart := 0;
    SelectionLength := 0;
  end;
  FView.FullLog.BeginUpdate;
  try
    FView.FullLog.Lines.BeginUpdate;
    try
      if Reset then
        FView.FullLog.Lines.Clear;
      for I := First to Count - 1 do
        FView.FullLog.Lines.Add(Source[I]);
    finally
      FView.FullLog.Lines.EndUpdate;
    end;
  finally
    FView.FullLog.EndUpdate;
  end;
  FView.FullLog.SelStart := SelectionStart;
  FView.FullLog.SelLength := SelectionLength;
  // Memo layout may reveal its caret while processing LinesChanged. Restore the
  // reader's viewport after layout, and follow new output only from the bottom.
  if FollowTail then
    FView.FullLog.ViewportPosition := PointF(OldViewport.X,
      Max(0, FView.FullLog.ContentSize.Height - FView.FullLog.ViewportSize.Height))
  else
    FView.FullLog.ViewportPosition := OldViewport;
  FFullLogCount := Count;
  FFullLogTail := '';
  if Count > 0 then
    FFullLogTail := Source[Count - 1];
  FFullLogReset := False;
end;

procedure TLogPresenter.RefreshEvents;
var
  i, Count, First: Integer;
  Source: TStrings;
  Reset: Boolean;
  Item: TListBoxItem;
  Caption: TLabel;
  Icon: FMX.Objects.TPath;
  Rule: TRectangle;
  MessageText, Stamp, Lower: string;
  Template: TPathData;
  Color: TAlphaColor;
begin
  if (csDestroying in FView.ScrapeEventList.ComponentState) then
    Exit;
  Source := FView.FastColoredTextBoxLogging.Lines;
  Count := Source.Count;
  Reset := FEventsReset or (Count < FDisplayedLogCount);
  if not Reset and (FDisplayedLogCount > 0) then
    Reset := Source[FDisplayedLogCount - 1] <> FDisplayedLogTail;
  if not Reset and (FDisplayedLogCount = Count) then
    Exit;
  First := FDisplayedLogCount;
  if Reset then
    First := 0;
  First := Max(First, Count - MaxVisibleLogEntries);
  FView.ScrapeEventList.BeginUpdate;
  try
    if Reset then
      FView.ScrapeEventList.Clear;
    // Keep existing controls on append; discard only entries outside the visible tail.
    while FView.ScrapeEventList.Count > Max(0, MaxVisibleLogEntries - (Count - First)) do
      FView.ScrapeEventList.ListItems[0].Free;
    for i := First to Count - 1 do
    begin
      MessageText := Source[i];
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

      Item := TListBoxItem.Create(FView.ScrapeEventList);
      Item.Parent := FView.ScrapeEventList;
      Item.Height := 36;
      Item.Text := '';

      Icon := FMX.Objects.TPath.Create(Item);
      Icon.Parent := Item;
      Icon.Align := TAlignLayout.Left;
      Icon.Width := 20;
      Icon.Margins.Rect := RectF(16, 8, 16, 8);
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
    FView.ScrapeEventList.EndUpdate
  end;
  FDisplayedLogCount := Count;
  FDisplayedLogTail := '';
  if Count > 0 then
    FDisplayedLogTail := Source[Count - 1];
  FEventsReset := False;
  if FView.ScrapeEventList.Count > 0 then
    FView.ScrapeEventList.ScrollToItem(FView.ScrapeEventList.ListItems[FView.ScrapeEventList.Count - 1]);
end;

procedure TLogPresenter.Reset;
begin
  FFullLogReset := True;
  FEventsReset := True;
end;

end.

