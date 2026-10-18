unit SK.platform.Graphics;

interface

uses
  System.SysUtils, System.Types, System.UITypes, FMX.Graphics, Xml.XMLIntf;

procedure PaintMixText(Bitmap: TBitmap; Node: IXMLNode; const Caption, BasePath: string; ReferenceHeight: Single);

implementation

uses
  System.Generics.Collections, System.Math, System.Variants, FMX.Types,
  FMX.FontManager, FMX.TextLayout, SK.Consts, SK.Platform;

var
  RegisteredFonts: TDictionary<string, string>;

function Attr(N: IXMLNode; const Name, Default: string): string;
begin
  if (N = nil) or not N.HasAttribute(Name) then
    Result := Default
  else
    Result := VarToStr(N.Attributes[Name]);
end;

function TextColor(const Value: string; Default: TAlphaColor): TAlphaColor;
var
  Hex: string;
  Color: Int64;
begin
  Hex := Value.Trim.TrimLeft(['#']);
  if Length(Hex) = 6 then
    Hex := 'FF' + Hex;
  if (Length(Hex) = 8) and TryStrToInt64('$' + Hex, Color) then
    Result := TAlphaColor(Color)
  else
    Result := Default;
end;

function FontFamily(Node: IXMLNode; const BasePath: string): string;
var
  FileName, Key, Family, Preferred: string;
  Before: TDictionary<string, Boolean>;
  I: Integer;
begin
  Preferred := Attr(Node, 'FontFamily', Attr(Node, 'FontFamilly', 'Arial'));
  FileName := Attr(Node, 'FontFile', '');
  if FileName = '' then
    Exit(Preferred);
  FileName := TPlatformPath.Combine(BasePath, FileName);
  Key := PathKey(FileName);
  // MIX rendering also runs on workers; serialize registration of custom fonts.
  TMonitor.Enter(RegisteredFonts);
  try
    if RegisteredFonts.TryGetValue(Key, Result) then
      Exit;
    Before := TDictionary<string, Boolean>.Create;
    try
      for I := 0 to TFontManager.CustomFontInfoCount - 1 do
        Before.AddOrSetValue(string(TFontManager.CustomFontInfo[I].FamilyName).ToLower, True);
      if not TFontManager.AddCustomFontFromFile(FileName) then
        raise Exception.Create('Cannot load MIX font: ' + FileName);
      Result := '';
      // Collections may reorder families after registration. Find the added family.
      for I := 0 to TFontManager.CustomFontInfoCount - 1 do
      begin
        Family := TFontManager.CustomFontInfo[I].FamilyName;
        if not Before.ContainsKey(Family.ToLower) then
        begin
          Result := Family;
          Break;
        end;
      end;
      if Result = '' then
        for I := 0 to TFontManager.CustomFontInfoCount - 1 do
        begin
          Family := TFontManager.CustomFontInfo[I].FamilyName;
          if SameText(Family, Preferred) or (TFontManager.CustomFontInfoCount = 1) then
          begin
            Result := Family;
            Break;
          end;
        end;
      if Result = '' then
        raise Exception.Create('Cannot resolve MIX font family: ' + FileName);
      RegisteredFonts.Add(Key, Result);
    finally
      Before.Free;
    end;
  finally
    TMonitor.Exit(RegisteredFonts);
  end;
end;

procedure PaintMixText(Bitmap: TBitmap; Node: IXMLNode; const Caption, BasePath: string; ReferenceHeight: Single);
var
  Layout: TTextLayout;
  Bounds: TRectF;
  Style, Align, Family: string;
  Low, High, Mid, Outline, DX, DY: Integer;
  Color, OutlineColor: TAlphaColor;
begin
  if Bitmap = nil then
    raise EArgumentNilException.Create('Bitmap');
  Bitmap.Clear(TAlphaColorRec.Null);
  if (Caption = '') or (Bitmap.Width = 0) or (Bitmap.Height = 0) then
    Exit;
  Family := FontFamily(Node, BasePath);
  Outline := StrToIntDef(Attr(Node, 'TextOutlineWidth', '-1'), -1);
  if Outline < 0 then
    Outline := Max(0, Ceil(ReferenceHeight / TextOutlineScale))
  else
    Outline := EnsureRange(Outline, 0, 3);
  Outline := Min(Outline, Max(0, (Min(Bitmap.Width, Bitmap.Height) - 1) div 2));
  Bounds := RectF(Outline, Outline, Bitmap.Width - Outline, Bitmap.Height - Outline);
  Color := TextColor(Attr(Node, 'TextColor', '#FFFFFFFF'), TAlphaColorRec.White);
  OutlineColor := TextColor(Attr(Node, 'TextOutlineColor', '#00000000'), TAlphaColorRec.Null);
  if not Bitmap.Canvas.BeginScene then
    raise Exception.Create('Cannot begin MIX text rendering');
  try
    Layout := TTextLayoutManager.DefaultTextLayout.Create(Bitmap.Canvas);
    try
      Layout.BeginUpdate;
      try
        Layout.Font.Family := Family;
        Style := Attr(Node, 'FontStyle', 'Regular').ToLower;
        Layout.Font.Style := [];
        if Style.Contains('bold') then
          Layout.Font.Style := Layout.Font.Style + [TFontStyle.fsBold];
        if Style.Contains('italic') then
          Layout.Font.Style := Layout.Font.Style + [TFontStyle.fsItalic];
        if Style.Contains('underline') then
          Layout.Font.Style := Layout.Font.Style + [TFontStyle.fsUnderline];
        if Style.Contains('strikeout') then
          Layout.Font.Style := Layout.Font.Style + [TFontStyle.fsStrikeOut];
        Layout.Text := Caption;
        Layout.WordWrap := True;
        Layout.Trimming := TTextTrimming.None;
        Layout.HorizontalAlign := TTextAlign.Leading;
        Layout.VerticalAlign := TTextAlign.Leading;
        Layout.MaxSize := PointF(Bounds.Width, TextMeasureHeight);
        Layout.Opacity := 1;
      finally
        Layout.EndUpdate;
      end;
      Low := 1;
      High := TextFontSizeUpperBound;
      while Low + 1 < High do
      begin
        Mid := (Low + High) div 2;
        Layout.Font.Size := Mid;
        if (Layout.TextWidth > Bounds.Width) or (Layout.TextHeight > Bounds.Height) then
          High := Mid
        else
          Low := Mid;
      end;
      Layout.BeginUpdate;
      try
        Layout.Font.Size := Low;
        Layout.MaxSize := PointF(Bounds.Width, Bounds.Height);
        Align := Attr(Node, 'TextAlign', 'TopLeft').ToLower;
        if Align.Contains('hcenter') then
          Layout.HorizontalAlign := TTextAlign.Center
        else if Align.Contains('right') then
          Layout.HorizontalAlign := TTextAlign.Trailing;
        if Align.Contains('vcenter') then
          Layout.VerticalAlign := TTextAlign.Center
        else if Align.Contains('bottom') then
          Layout.VerticalAlign := TTextAlign.Trailing;
        Layout.Color := OutlineColor;
      finally
        Layout.EndUpdate;
      end;
      if (Outline > 0) and (OutlineColor shr 24 <> 0) then
        for DY := -Outline to Outline do
          for DX := -Outline to Outline do
            if (DX * DX + DY * DY <= Sqr(Outline + 0.5)) and ((DX <> 0) or (DY <> 0)) then
            begin
              Layout.TopLeft := PointF(Bounds.Left + DX, Bounds.Top + DY);
              Layout.RenderLayout(Bitmap.Canvas);
            end;
      Layout.Color := Color;
      Layout.TopLeft := Bounds.TopLeft;
      Layout.RenderLayout(Bitmap.Canvas);
    finally
      Layout.Free;
    end;
  finally
    Bitmap.Canvas.EndScene;
  end;
end;

initialization
  RegisteredFonts := TDictionary<string, string>.Create;

finalization
  RegisteredFonts.Free;

end.

