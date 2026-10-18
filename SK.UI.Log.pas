unit SK.UI.Log;

interface

uses
  System.SysUtils, System.Classes, System.Types, System.UITypes,
  System.Generics.Collections, FMX.Graphics, FMX.Types, FMX.Controls,
  FMX.Layouts, FMX.Objects, FMX.StdCtrls, FMX.Memo, FMX.ListBox, FMX.Menus, SK.Scrape.Types;

type
  TLogControls = record
    ScrapeEventList: TListBox;
    FullLog: TListBox;
    FastColoredTextBoxLogging: TMemo;
  end;

  TLogPresenter = class
  private
    FView: TLogControls;
    FLogInfoData, FLogSuccessData, FLogErrorData: TPathData;
    FDisplayedLogCount, FFullLogCount: Integer;
    FDisplayedLogTail, FFullLogTail: string;
    FFullLogReset, FEventsReset: Boolean;
    FEventMenu: TPopupMenu;
    FCopyEvent: TMenuItem;
    FMenuList: TListBox;
    function CopySelectedEvent(List: TListBox): Boolean;
    procedure EventKeyDown(Sender: TObject; var Key: Word; var KeyChar: WideChar; Shift: TShiftState);
    procedure EventMouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Single);
    procedure EventMenuPopup(Sender: TObject);
    procedure CopyEventClick(Sender: TObject);
    procedure SyncEvents(List: TListBox; var DisplayedCount: Integer;
      var DisplayedTail: string; var NeedsReset: Boolean; Limit: Integer);
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
  SK.Platform, SK.Storage, SK.UI.Controls, FMX.Platform;

function LoadLogPath(const RelativePath: string): TPathData; forward;

constructor TLogPresenter.Create(View: TComponent);
begin
  inherited Create;
  FView.ScrapeEventList := RequireComponent(View, 'ScrapeEventList') as TListBox;
  FView.FullLog := RequireComponent(View, 'FullLog') as TListBox;
  FView.FastColoredTextBoxLogging := RequireComponent(View, 'FastColoredTextBoxLogging') as TMemo;
  FEventMenu := RequireComponent(View, 'LogEventMenu') as TPopupMenu;
  FCopyEvent := RequireComponent(View, 'CopyLogEvent') as TMenuItem;
  FEventMenu.OnPopup := EventMenuPopup;
  FCopyEvent.OnClick := CopyEventClick;
  FView.ScrapeEventList.OnKeyDown := EventKeyDown;
  FView.FullLog.OnKeyDown := EventKeyDown;
  FView.ScrapeEventList.OnMouseDown := EventMouseDown;
  FView.FullLog.OnMouseDown := EventMouseDown;
  FFullLogReset := True;
  FEventsReset := True;
  FLogInfoData := LoadLogPath(LogInfoIconPath);
  FLogSuccessData := LoadLogPath(LogSuccessIconPath);
  FLogErrorData := LoadLogPath(LogErrorIconPath);
end;

destructor TLogPresenter.Destroy;
begin
  FEventMenu.OnPopup := nil;
  FCopyEvent.OnClick := nil;
  FView.ScrapeEventList.OnKeyDown := nil;
  FView.FullLog.OnKeyDown := nil;
  FView.ScrapeEventList.OnMouseDown := nil;
  FView.FullLog.OnMouseDown := nil;
  FLogInfoData.Free;
  FLogSuccessData.Free;
  FLogErrorData.Free;
  inherited;
end;

function TLogPresenter.CopySelectedEvent(List: TListBox): Boolean;
var
  Clipboard: IFMXClipboardService;
begin
  Result := (List <> nil) and (List.Selected <> nil) and
    TPlatformServices.Current.SupportsPlatformService(IFMXClipboardService, Clipboard);
  if Result then
    Clipboard.SetClipboard(List.Selected.Hint);
end;

procedure TLogPresenter.EventKeyDown(Sender: TObject; var Key: Word; var KeyChar: WideChar; Shift: TShiftState);
begin
  if (Shift = [ssCtrl]) and ((Key = vkC) or (KeyChar = 'c') or (KeyChar = 'C')) and
    CopySelectedEvent(Sender as TListBox) then
  begin
    Key := 0;
    KeyChar := #0;
  end;
end;

procedure TLogPresenter.EventMouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Single);
var
  List: TListBox;
  Item: TListBoxItem;
begin
  if Button <> TMouseButton.mbRight then
    Exit;
  List := Sender as TListBox;
  Item := List.ItemByPoint(X, Y);
  if Item <> nil then
    List.ItemIndex := Item.Index;
  List.SetFocus;
end;

procedure TLogPresenter.EventMenuPopup(Sender: TObject);
var
  Target: TFmxObject;
  Clipboard: IFMXClipboardService;
begin
  FMenuList := nil;
  if FEventMenu.PopupComponent is TFmxObject then
  begin
    Target := TFmxObject(FEventMenu.PopupComponent);
    while (Target <> nil) and not (Target is TListBox) do
      Target := Target.Parent;
    if (Target = FView.FullLog) or (Target = FView.ScrapeEventList) then
      FMenuList := TListBox(Target);
  end;
  FCopyEvent.Text := SK.Locale.L('Копировать');
  FCopyEvent.Enabled := (FMenuList <> nil) and (FMenuList.Selected <> nil) and
    TPlatformServices.Current.SupportsPlatformService(IFMXClipboardService, Clipboard);
end;

procedure TLogPresenter.CopyEventClick(Sender: TObject);
begin
  CopySelectedEvent(FMenuList);
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
begin
  SyncEvents(FView.FullLog, FFullLogCount, FFullLogTail, FFullLogReset, 0);
end;

procedure TLogPresenter.RefreshEvents;
begin
  SyncEvents(FView.ScrapeEventList, FDisplayedLogCount, FDisplayedLogTail,
    FEventsReset, MaxVisibleLogEntries);
end;

procedure TLogPresenter.SyncEvents(List: TListBox; var DisplayedCount: Integer;
  var DisplayedTail: string; var NeedsReset: Boolean; Limit: Integer);
var
  i, Count, First: Integer;
  Source: TStrings;
  Reset, FollowTail: Boolean;
  OldViewport: TPointF;
  Item: TListBoxItem;
  Caption: TLabel;
  Icon: FMX.Objects.TPath;
  Rule: TRectangle;
  MessageText, Stamp, Lower: string;
  Template: TPathData;
  Color: TAlphaColor;
begin
  if (csDestroying in List.ComponentState) then
    Exit;
  Source := FView.FastColoredTextBoxLogging.Lines;
  Count := Source.Count;
  Reset := NeedsReset or (Count < DisplayedCount);
  if not Reset and (DisplayedCount > 0) then
    Reset := Source[DisplayedCount - 1] <> DisplayedTail;
  if not Reset and (DisplayedCount = Count) then
    Exit;
  First := DisplayedCount;
  if Reset then
    First := 0;
  if Limit > 0 then
    First := Max(First, Count - Limit);
  List.ApplyStyleLookup;
  OldViewport := List.ViewportPosition;
  FollowTail := (Limit > 0) or Reset or
    (OldViewport.Y + List.Height >= List.ContentBounds.Height - 2);
  List.BeginUpdate;
  try
    if Reset then
      List.Clear;
    // Keep existing controls on append; discard only entries outside the visible tail.
    while (Limit > 0) and (List.Count > Max(0, Limit - (Count - First))) do
      List.ListItems[0].Free;
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

      Item := TListBoxItem.Create(List);
      Item.Parent := List;
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
      Item.Hint := Source[i];
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
    List.EndUpdate
  end;
  List.RealignContent;
  DisplayedCount := Count;
  DisplayedTail := '';
  if Count > 0 then
    DisplayedTail := Source[Count - 1];
  NeedsReset := False;
  if FollowTail then
    List.ViewportPosition := PointF(OldViewport.X, Max(0, List.ContentBounds.Height - List.Height))
  else
    List.ViewportPosition := OldViewport;
end;

procedure TLogPresenter.Reset;
begin
  FFullLogReset := True;
  FEventsReset := True;
end;

end.

