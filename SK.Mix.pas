unit SK.Mix;

interface

uses
  System.SysUtils, System.Types, System.UITypes, System.Classes,
  System.Generics.Collections, FMX.Graphics, FMX.Types;

procedure ResizeImage(const Source, Destination: string; Width, Height: Integer; KeepRatio: Boolean);

procedure RenderMix(const Template: string; Sources: TDictionary<string, string>; const Destination: string; Width, Height: Integer);

function RequiredMixMedia(const Template, SystemID: string): TArray<string>;

function MixExtension(const Template: string): string;

implementation

uses
  SK.Consts, System.IOUtils, System.Math, System.Math.Vectors,
  System.RegularExpressions, Xml.XMLDoc, Xml.XMLIntf, System.Variants,
  SK.Platform.Graphics, SK.Platform;

type
  TMixFiltering = (mfNone, mfMedium, mfHigh);
  TFilterTap = record
    Index: Integer;
    Weight: Single;
  end;
  TPixelSum = record
    R, G, B, A: Single;
  end;
  TFilterAxis = TArray<TArray<TFilterTap>>;

function MixFiltering(const Name: string): TMixFiltering;
begin
  if SameText(Name, 'None') then Exit(mfNone);
  if SameText(Name, 'Medium') then Exit(mfMedium);
  if SameText(Name, 'High') then Exit(mfHigh);
  raise Exception.Create('Unsupported MIX antialiasing: ' + Name);
end;

function CubicWeight(X: Single): Single;
begin
  X := Abs(X);
  if X < 1 then
    Result := (1.5 * X - 2.5) * X * X + 1
  else if X < 2 then
    Result := ((-0.5 * X + 2.5) * X - 4) * X + 2
  else
    Result := 0;
end;

function FilterAxis(SourceSize, TargetSize: Integer; Filtering: TMixFiltering): TFilterAxis;
var
  X, I, First, Last, K: Integer;
  Center, Scale, Radius, Weight, Total: Single;
begin
  SetLength(Result, TargetSize);
  Scale := 1;
  Radius := 1;
  if Filtering = mfHigh then
  begin
    Scale := Max(1, SourceSize / TargetSize);
    Radius := 2 * Scale;
  end;
  for X := 0 to TargetSize - 1 do
  begin
    Center := (X + 0.5) * SourceSize / TargetSize - 0.5;
    First := Ceil(Center - Radius);
    Last := Floor(Center + Radius);
    SetLength(Result[X], Last - First + 1);
    Total := 0;
    K := 0;
    for I := First to Last do
    begin
      if Filtering = mfHigh then
        Weight := CubicWeight((Center - I) / Scale)
      else
        Weight := Max(0, 1 - Abs(Center - I));
      Result[X][K].Index := EnsureRange(I, 0, SourceSize - 1);
      Result[X][K].Weight := Weight;
      Total := Total + Weight;
      Inc(K);
    end;
    if Abs(Total) > 0.000001 then
      for K := 0 to High(Result[X]) do
        Result[X][K].Weight := Result[X][K].Weight / Total;
  end;
end;

function ResampleBitmap(Input: TBitmap; Width, Height: Integer; Filtering: TMixFiltering): TBitmap;
var
  Src, Dst: TBitmapData;
  Horizontal: TArray<TArray<TPixelSum>>;
  AxisX, AxisY: TFilterAxis;
  X, Y, I, SX, SY, AlphaByte: Integer;
  Color: TAlphaColor;
  Sum, Pixel: TPixelSum;
  Weight: Single;
begin
  Result := TBitmap.Create;
  try
    if (Width = Input.Width) and (Height = Input.Height) then
    begin
      Result.Assign(Input);
      Exit;
    end;
    Result.SetSize(Width, Height);
    if not Input.Map(TMapAccess.Read, Src) then
      raise Exception.Create('Cannot read MIX bitmap');
    try
      if not Result.Map(TMapAccess.Write, Dst) then
        raise Exception.Create('Cannot write MIX bitmap');
      try
        if Filtering = mfNone then
        begin
          for Y := 0 to Height - 1 do
          begin
            SY := Min(Input.Height - 1, Floor((Y + 0.5) * Input.Height / Height));
            for X := 0 to Width - 1 do
            begin
              SX := Min(Input.Width - 1, Floor((X + 0.5) * Input.Width / Width));
              Dst.SetPixel(X, Y, Src.GetPixel(SX, SY));
            end;
          end;
          Exit;
        end;
        AxisX := FilterAxis(Input.Width, Width, Filtering);
        AxisY := FilterAxis(Input.Height, Height, Filtering);
        SetLength(Horizontal, Input.Height);
        for Y := 0 to Input.Height - 1 do
        begin
          SetLength(Horizontal[Y], Width);
          for X := 0 to Width - 1 do
          begin
            Sum := Default(TPixelSum);
            for I := 0 to High(AxisX[X]) do
            begin
              Color := Src.GetPixel(AxisX[X][I].Index, Y);
              Weight := AxisX[X][I].Weight;
              // FMX mapped pixels already contain premultiplied colour channels.
              Sum.A := Sum.A + (Color shr 24) * Weight;
              Sum.R := Sum.R + ((Color shr 16) and $FF) * Weight;
              Sum.G := Sum.G + ((Color shr 8) and $FF) * Weight;
              Sum.B := Sum.B + (Color and $FF) * Weight;
            end;
            Horizontal[Y][X] := Sum;
          end;
        end;
        for Y := 0 to Height - 1 do
          for X := 0 to Width - 1 do
          begin
            Sum := Default(TPixelSum);
            for I := 0 to High(AxisY[Y]) do
            begin
              Pixel := Horizontal[AxisY[Y][I].Index][X];
              Weight := AxisY[Y][I].Weight;
              Sum.A := Sum.A + Pixel.A * Weight;
              Sum.R := Sum.R + Pixel.R * Weight;
              Sum.G := Sum.G + Pixel.G * Weight;
              Sum.B := Sum.B + Pixel.B * Weight;
            end;
            AlphaByte := EnsureRange(Round(Sum.A), 0, 255);
            Color := Cardinal(AlphaByte) shl 24 or
              Cardinal(EnsureRange(Round(Sum.R), 0, AlphaByte)) shl 16 or
              Cardinal(EnsureRange(Round(Sum.G), 0, AlphaByte)) shl 8 or
              Cardinal(EnsureRange(Round(Sum.B), 0, AlphaByte));
            Dst.SetPixel(X, Y, Color);
          end;
      finally
        Result.Unmap(Dst);
      end;
    finally
      Input.Unmap(Src);
    end;
  except
    Result.Free;
    raise;
  end;
end;

procedure ResizeImage(const Source, Destination: string; Width, Height: Integer; KeepRatio: Boolean);
var
  Input, Output: TBitmap;
  Scale: Single;
begin
  Input := TBitmap.Create;
  Output := TBitmap.Create;
  try
    Input.LoadFromFile(Source);
    if (Input.Width = 0) or (Input.Height = 0) then
      raise Exception.Create('Empty image');
    if (Width <= 0) and (Height <= 0) then
    begin
      Width := Input.Width;
      Height := Input.Height;
    end;
    if Width <= 0 then
      Width := Round(Input.Width * Height / Input.Height);
    if Height <= 0 then
      Height := Round(Input.Height * Width / Input.Width);
    if KeepRatio then
    begin
      Scale := Min(Width / Input.Width, Height / Input.Height);
      Width := Max(1, Round(Input.Width * Scale));
      Height := Max(1, Round(Input.Height * Scale));
    end;
    Output.Free;
    Output := nil;
    Output := ResampleBitmap(Input, Width, Height, mfHigh);
    Output.SaveToFile(Destination);
  finally
    Output.Free;
    Input.Free;
  end;
end;

function Attr(N: IXMLNode; const Name, Default: string): string;
begin
  if (N = nil) or not N.HasAttribute(Name) then
    Result := Default
  else
    Result := VarToStr(N.Attributes[Name]);
end;

function MixExtension(const Template: string): string;
var
  Doc: IXMLDocument;
  Text: string;
begin
  Text := TFile.ReadAllText(Template, TEncoding.UTF8);
  Text := TRegEx.Replace(Text, '(<Fallback\b[^>]*?)(?<!/)>(\s*</Item>)', '$1 />$2', [roIgnoreCase]);
  Doc := LoadXMLData(Text);
  if SameText(Attr(Doc.DocumentElement.ChildNodes.FindNode('Viewport'), 'ImageFormat', 'Png'), 'Jpg') then
    Result := '.jpg'
  else
    Result := '.png';
end;

function Dimension(const S: string; Max: Single; Perpendicular: Single = 0): Single;
begin
  if S.EndsWith('%') then
    Result := StrToFloatDef(S.TrimRight(['%']), 0, TFormatSettings.Invariant) * Max / 100
  else if S.EndsWith('!') then
    Result := StrToFloatDef(S.TrimRight(['!']), 0, TFormatSettings.Invariant) * Perpendicular / 100
  else
    Result := StrToFloatDef(S, 0, TFormatSettings.Invariant);
end;

function ExpandMixText(const Text: string; Sources: TDictionary<string, string>): string;
var
  Pair: TPair<string, string>;
begin
  Result := Text;
  for Pair in Sources do
    if Pair.Key.StartsWith('@') then
      Result := Result.Replace('%' + Pair.Key.Substring(1) + '%', Pair.Value, [rfReplaceAll, rfIgnoreCase]);
end;

function MediaKey(const S: string): string;
begin
  if SameText(S, 'Screenshot') then
    Exit('ss');
  if SameText(S, 'ScreenshotTitle') then
    Exit('sstitle');
  if SameText(S, 'Box3D') then
    Exit('box-3D');
  if SameText(S, 'Box2DFront') then
    Exit('box-2D');
  if SameText(S, 'Support') then
    Exit('support-2D');
  if SameText(S, 'FanArt') then
    Exit('fanart');
  if SameText(S, 'RecalBoxMixV1') then
    Exit('mixrbv1');
  if SameText(S, 'RecalBoxMixV2') then
    Exit('mixrbv2');
  if SameText(S, 'Box2DSide') then
    Exit('box-2D-side');
  if SameText(S, 'Box2DBack') then
    Exit('box-2D-back');
  if SameText(S, 'BoxTexture') then
    Exit('box-texture');
  if SameText(S, 'SupportTexture') then
    Exit('support-texture');
  if SameText(S, 'WheelCarbon') then
    Exit('wheel-carbon');
  if SameText(S, 'WheelSteel') then
    Exit('wheel-steel');
  if SameText(S, 'SystemBezel43') then
    Exit('system:bezel-4-3');
  if SameText(S, 'SystemBezel169') then
    Exit('system:bezel-16-9');
  if SameText(S, 'SystemWheel') then
    Exit('system:wheel');
  if SameText(S, 'SystemCarbonWheel') then
    Exit('system:wheel-carbon');
  if SameText(S, 'SystemSteelWheel') then
    Exit('system:wheel-steel');
  if SameText(S, 'SystemMonochromeLogo') then
    Exit('system:logo-monochrome');
  if SameText(S, 'SystemIcon') then
    Exit('system:icon');
  if SameText(S, 'SystemIconMini') then
    Exit('system:minicon');
  if SameText(S, 'SystemPhoto') then
    Exit('system:photo');
  if SameText(S, 'SystemPicture') then
    Exit('system:illustration');
  if SameText(S, 'SystemControllerPhoto') then
    Exit('system:controller');
  if SameText(S, 'SystemScreenMarquee') then
    Exit('system:screenmarquee');
  if SameText(S, 'SystemWallPaper') then
    Exit('system:background');
  if SameText(S, 'PublisherLogo') then
    Exit('editeur:pictocouleur');
  if SameText(S, 'PublisherMonochromeLogo') then
    Exit('editeur:pictomonochrome');
  if SameText(S, 'DeveloperLogo') then
    Exit('developpeur:pictocouleur');
  if SameText(S, 'DeveloperMonochromeLogo') then
    Exit('developpeur:pictomonochrome');
  if SameText(S, 'PlayersIcon') then
    Exit('joueurs:pictoliste');
  if SameText(S, 'NoteIcon') then
    Exit('note:pictoliste');
  if SameText(S, 'ClassificationIcon') then
    Exit('classification:pictoliste');
  if SameText(S, 'PictoPlayers') then
    Exit('joueurs:pictoliste');
  if SameText(S, 'PictoNote') then
    Exit('note:pictoliste');
  if SameText(S, 'Classification') then
    Exit('classification:pictoliste');
  if S.StartsWith('Genre', True) and (S.Length > 6) then
    if S.EndsWith('Picto', True) then
      Exit('genre:pictoliste#' + S.Substring(5, 1))
    else
      Exit('genre:pictomonochrome#' + S.Substring(5, 1));

  Result := S.ToLower;
end;

function RequiredMixMedia(const Template, SystemID: string): TArray<string>;
var
  Keys, Visited: TDictionary<string, Boolean>;

  procedure ReadTemplate(const FileName: string; Depth: Integer); forward;

  procedure Visit(Node: IXMLNode; const FileName: string; Depth: Integer);
  var
    i: Integer;
    Kind, IncludeFile: string;
  begin
    if Node = nil then
      Exit;
    Kind := Attr(Node, 'Type', '');
    if SameText(Kind, 'Include') then
    begin
      IncludeFile := Attr(Node, 'LocalFilePath', '').Replace('%SYSTEM%', SystemID, [rfReplaceAll, rfIgnoreCase]);
      if not TFile.Exists(TPlatformPath.Combine(ExtractFilePath(FileName), IncludeFile)) then
        IncludeFile := Attr(Node, 'LocalFilePath', '').Replace('%SYSTEM%', '0', [rfReplaceAll, rfIgnoreCase]);
      ReadTemplate(TPlatformPath.Combine(ExtractFilePath(FileName), IncludeFile), Depth + 1);
    end
    else if (Kind <> '') and not SameText(Kind, 'NoResource') and not SameText(Kind, 'LocalFile') and not SameText(Kind, 'Text') then
      Keys.AddOrSetValue(MediaKey(Kind), True);
    for i := 0 to Node.ChildNodes.Count - 1 do
      Visit(Node.ChildNodes[i], FileName, Depth);
  end;

  procedure ReadTemplate(const FileName: string; Depth: Integer);
  var
    Doc: IXMLDocument;
    XML, Full: string;
  begin
    if Depth > MixIncludeDepthLimit then
      raise Exception.Create('Mix include nesting exceeds 16');
    Full := TPath.GetFullPath(FileName);
    if Visited.ContainsKey(Full.ToLower) then
      Exit;
    Visited.Add(Full.ToLower, True);
    XML := TFile.ReadAllText(Full, TEncoding.UTF8);
    XML := TRegEx.Replace(XML, '(<Fallback\b[^>]*?)(?<!/)>(\s*</Item>)', '$1 />$2', [roIgnoreCase]);
    Doc := LoadXMLData(XML);
    Visit(Doc.DocumentElement, Full, Depth);
  end;

begin
  Keys := TDictionary<string, Boolean>.Create;
  Visited := TDictionary<string, Boolean>.Create;
  try
    ReadTemplate(Template, 0);
    Result := Keys.Keys.ToArray;
  finally
    Visited.Free;
    Keys.Free;
  end;
end;

function ProjectImage(Input: TBitmap; const Points: array of TPointF; Width, Height, Samples: Integer): TBitmap;
var
  A: array[0..7, 0..8] of Double;
  i, J, K, P, X, Y, SX, SY, AX, AY, Alpha, Red, Green, Blue, N, Left, Top, Right, Bottom: Integer;
  Color: Cardinal;
  FX, FY: Double;
  U, V, Q, F, Temp: Double;
  Src, Dst: FMX.Graphics.TBitmapData;
begin
  // Solve the inverse projective transform: destination quadrilateral -> unit square.
  FillChar(A, SizeOf(A), 0);
  for i := 0 to 3 do
  begin
    if i in [1, 2] then
      U := 1
    else
      U := 0;
    if i in [2, 3] then
      V := 1
    else
      V := 0;
    J := i * 2;
    A[J, 0] := Points[i].X;
    A[J, 1] := Points[i].Y;
    A[J, 2] := 1;
    A[J, 6] := -U * Points[i].X;
    A[J, 7] := -U * Points[i].Y;
    A[J, 8] := U;
    A[J + 1, 3] := Points[i].X;
    A[J + 1, 4] := Points[i].Y;
    A[J + 1, 5] := 1;
    A[J + 1, 6] := -V * Points[i].X;
    A[J + 1, 7] := -V * Points[i].Y;
    A[J + 1, 8] := V;
  end;
  for i := 0 to 7 do
  begin
    P := i;
    for J := i + 1 to 7 do
      if Abs(A[J, i]) > Abs(A[P, i]) then
        P := J;
    if Abs(A[P, i]) < 1E-10 then
      raise Exception.Create('Degenerate mix projection');
    for K := 0 to 8 do
    begin
      Temp := A[i, K];
      A[i, K] := A[P, K];
      A[P, K] := Temp;
    end;
    F := A[i, i];
    for K := i to 8 do
      A[i, K] := A[i, K] / F;
    for J := 0 to 7 do
      if J <> i then
      begin
        F := A[J, i];
        for K := i to 8 do
          A[J, K] := A[J, K] - F * A[i, K];
      end;
  end;
  Result := TBitmap.Create(Width, Height);
  try
    Result.Clear(0);
    if not Input.Map(TMapAccess.Read, Src) then
      raise Exception.Create('Cannot read mix bitmap');
    try
      if not Result.Map(TMapAccess.Write, Dst) then
        raise Exception.Create('Cannot write mix projection');
      try
        Left := Width;
        Top := Height;
        Right := 0;
        Bottom := 0;
        for i := 0 to 3 do
        begin
          Left := Min(Left, Floor(Points[i].X));
          Right := Max(Right, Ceil(Points[i].X));
          Top := Min(Top, Floor(Points[i].Y));
          Bottom := Max(Bottom, Ceil(Points[i].Y));
        end;
        Samples := EnsureRange(Samples, 1, 4);
        N := Samples * Samples;
        for Y := Max(0, Top) to Min(Height - 1, Bottom) do
          for X := Max(0, Left) to Min(Width - 1, Right) do
          begin
            Alpha := 0;
            Red := 0;
            Green := 0;
            Blue := 0;
            for AY := 0 to Samples - 1 do
              for AX := 0 to Samples - 1 do
              begin
                FX := X + (AX + 0.5) / Samples;
                FY := Y + (AY + 0.5) / Samples;
                Q := A[6, 8] * FX + A[7, 8] * FY + 1;
                if Abs(Q) < 1E-10 then
                  Continue;
                U := (A[0, 8] * FX + A[1, 8] * FY + A[2, 8]) / Q;
                V := (A[3, 8] * FX + A[4, 8] * FY + A[5, 8]) / Q;
                if (U < 0) or (U >= 1) or (V < 0) or (V >= 1) then
                  Continue;
                SX := Min(Input.Width - 1, Trunc(U * Input.Width));
                SY := Min(Input.Height - 1, Trunc(V * Input.Height));
                Color := Src.GetPixel(SX, SY);
                Inc(Alpha, Color shr 24);
                Inc(Red, (Color shr 16) and $FF);
                Inc(Green, (Color shr 8) and $FF);
                Inc(Blue, Color and $FF);
              end;
            Dst.SetPixel(X, Y, Cardinal(Alpha div N) shl 24 or Cardinal(Red div N) shl 16 or Cardinal(Green div N) shl 8 or Cardinal(Blue div N));
          end;
      finally
        Result.Unmap(Dst);
      end;
    finally
      Input.Unmap(Src);
    end;
  except
    Result.Free;
    raise;
  end;
end;

function BarrelImage(Input: TBitmap; Level: Double; Samples: Integer): TBitmap;
var
  Src, Dst: FMX.Graphics.TBitmapData;
  X, Y, SX, SY: Integer;
  CX, CY, Radius, DX, DY, R, Q, A, B, D: Double;
begin
  Level := EnsureRange(Level, 0.5, 16.0);
  Samples := EnsureRange(Samples, 1, 4);
  A := -0.0038575 * Level;
  B := -0.0133655 * Level;
  D := 1 - A - B;
  CX := (Input.Width * Samples - 1) / 2;
  CY := (Input.Height * Samples - 1) / 2;
  Radius := Max(1, Min(Input.Width, Input.Height) * Samples / 2);
  Result := TBitmap.Create(Input.Width * Samples, Input.Height * Samples);
  try
    Result.Clear(0);
    if not Input.Map(TMapAccess.Read, Src) then
      raise Exception.Create('Cannot read mix bitmap');
    try
      if not Result.Map(TMapAccess.Write, Dst) then
        raise Exception.Create('Cannot write barrel bitmap');
      try
        for Y := 0 to Result.Height - 1 do
          for X := 0 to Result.Width - 1 do
          begin
            DX := (X - CX) / Radius;
            DY := (Y - CY) / Radius;
            R := Sqrt(DX * DX + DY * DY);
            Q := A * R * R * R + B * R * R + D;
            if Abs(Q) < 1E-10 then
              Continue;
            SX := Trunc((CX + DX * Radius / Abs(Q)) / Samples);
            SY := Trunc((CY + DY * Radius / Abs(Q)) / Samples);
            if (SX >= 0) and (SY >= 0) and (SX < Input.Width) and (SY < Input.Height) then
              Dst.SetPixel(X, Y, Src.GetPixel(SX, SY));
          end;
      finally
        Result.Unmap(Dst);
      end;
    finally
      Input.Unmap(Src);
    end;
  except
    Result.Free;
    raise;
  end;
end;

procedure ApplyImageEffect(Bitmap: TBitmap; const Effect: string);
var
  Data: FMX.Graphics.TBitmapData;
  X, Y, R, G, B, NR, NG, NB: Integer;
  C: TAlphaColor;
begin
  if SameText(Effect, 'None') or (Effect = '') then
    Exit;
  if not Bitmap.Map(TMapAccess.ReadWrite, Data) then
    raise Exception.Create('Cannot apply mix color effect');
  try
    for Y := 0 to Bitmap.Height - 1 do
      for X := 0 to Bitmap.Width - 1 do
      begin
        C := Data.GetPixel(X, Y);
        R := (C shr 16) and $FF;
        G := (C shr 8) and $FF;
        B := C and $FF;
        if SameText(Effect, 'BlackAndWhite') then
        begin
          NR := Round(R * 0.299 + G * 0.587 + B * 0.114);
          NG := NR;
          NB := NR;
        end
        else if SameText(Effect, 'Sepia') or SameText(Effect, 'GreenGameboy') then
        begin
          NR := Min(255, Round(R * 0.393 + G * 0.769 + B * 0.189));
          NG := Min(255, Round(R * 0.349 + G * 0.686 + B * 0.168));
          NB := Min(255, Round(R * 0.272 + G * 0.534 + B * 0.131));
          if SameText(Effect, 'GreenGameboy') then
          begin
            R := NR;
            NR := NG;
            NG := R;
          end;
        end
        else
          raise Exception.Create('Unsupported mix effect: ' + Effect);
        Data.SetPixel(X, Y, (C and $FF000000) or Cardinal(NR shl 16) or Cardinal(NG shl 8) or Cardinal(NB));
      end;
  finally
    Bitmap.Unmap(Data);
  end;
end;

procedure RenderMixInternal(const Template: string; Sources: TDictionary<string, string>; const Destination: string; Width, Height, IncludeDepth: Integer);
var
  Doc: IXMLDocument;
  View: IXMLNode;
  Bitmap: TBitmap;
  BaseWidth, BaseHeight: Single;
  XML: string;
  Drawn: Integer;

  function DrawItems(Parent: IXMLNode; Depth: Integer; const Reference: TRectF; SingleItem: Boolean = False): Boolean;
  var
    i, Count, ParentDepth, Samples: Integer;
    Item, Display, Children, Rotation, Resolved: IXMLNode;
    Source, Kind, Anchor, Orientation, IncludeFile, Condition, ID, Caption, ParentID: string;
    Input, Warped: TBitmap;
    Points: array[0..3] of TPointF;
    X, Y, W, H, Scale, Opacity, PX, PY: Single;
    Rect, ChildReference, ProjectionBounds: TRectF;
    Matrix: TMatrix;
    Matches, ItemAvailable: Boolean;
    Filtering: TMixFiltering;

    procedure Resolve(Node: IXMLNode);
    begin
      if Node = nil then
        Exit;
      Kind := Attr(Node, 'Type', 'NoResource');
      Source := '';
      Resolved := Node;
      Sources.TryGetValue(MediaKey(Kind), Source);
      if SameText(Kind, 'LocalFile') or SameText(Kind, 'Include') then
      begin
        Source := ExpandMixText(Attr(Node, 'LocalFilePath', ''), Sources);
        if Sources.TryGetValue('@systemid', ID) then
          Source := StringReplace(Source, '%SYSTEM%', ID, [rfReplaceAll, rfIgnoreCase]);
        Source := TPlatformPath.Combine(ExtractFilePath(Template), Source);
        if not TFile.Exists(Source) then
          Source := TPlatformPath.Combine(ExtractFilePath(Template),
            ExpandMixText(Attr(Node, 'LocalFilePath', '').Replace('%SYSTEM%', '0', [rfReplaceAll, rfIgnoreCase]), Sources));
      end;
    end;

  begin
    Result := False;
    if (Parent = nil) or (Depth > MixDrawingDepthLimit) then
      Exit;
    if SingleItem then
      Count := 1
    else
      Count := Parent.ChildNodes.Count;
    for i := 0 to Count - 1 do
    begin
      if SingleItem then
        Item := Parent
      else
        Item := Parent.ChildNodes[i];
      if not SingleItem and not SameText(Item.NodeName, 'Item') then
        Continue;
      Condition := Attr(Item, 'IfSystem', '');
      if Condition.Contains(':') and Sources.TryGetValue('@systemid', ID) then
      begin
        Matches := (',' + Condition.Substring(Condition.IndexOf(':') + 1).Replace(' ', '') + ',').Contains(',' + ID + ',');
        if not Matches and Condition.Contains('OrAncestors') then
          for ParentDepth := 0 to MixParentDepthLimit - 1 do
          begin
            if not Sources.TryGetValue('@parent:' + ID, ParentID) or (ParentID = '0') or (ParentID = ID) then
              Break;
            ID := ParentID;
            Matches := (',' + Condition.Substring(Condition.IndexOf(':') + 1).Replace(' ', '') + ',').Contains(',' + ID + ',');
            if Matches then
              Break;
          end;
        if Condition.StartsWith('IsNot') then
          Matches := not Matches;
        if not Matches then
        begin
          Result := DrawItems(Item.ChildNodes.FindNode('Else'), Depth + 1, Reference, True) or Result;
          Continue;
        end;
      end;
      Rect := Reference;
      Kind := Attr(Item, 'Type', 'NoResource');
      Source := '';
      Resolve(Item);
      if SameText(Kind, 'Image') or SameText(Kind, 'File') then
      begin
        Source := Attr(Item, 'Filename', Attr(Item, 'File', ''));
        if Source <> '' then
          Source := TPlatformPath.Combine(ExtractFilePath(Template), Source);
      end;
      if SameText(Attr(Item, 'IfOrientation', ''), 'IsPortrait') and not SameText(Kind, 'Text') and
        ((Source = '') or not TFile.Exists(Source)) then
      begin
        Result := DrawItems(Item.ChildNodes.FindNode('Else'), Depth + 1, Reference, True) or Result;
        Continue;
      end;
      if ((Source = '') or not TFile.Exists(Source)) and not SameText(Kind, 'Text') and not SameText(Kind, 'NoResource') then
      begin
        ItemAvailable := DrawItems(Item.ChildNodes.FindNode('Fallback'), Depth + 1, Reference, True);
        Result := ItemAvailable or Result;
        Children := Item.ChildNodes.FindNode('Children');
        ChildReference := Reference;
        if SameText(Attr(Children, 'Reference', ''), 'Viewport') then
          ChildReference := Bitmap.BoundsF;
        if ItemAvailable or SameText(Attr(Children, 'DrawIfNoParent', 'false'), 'true') then
          DrawItems(Children, Depth + 1, ChildReference);
        Continue;
      end;
      if ((Source <> '') and TFile.Exists(Source)) or SameText(Kind, 'Text') then
      begin
        Input := TBitmap.Create;
        try
          IncludeFile := '';
          if SameText(Kind, 'Include') then
          begin
            if SameText(TPath.GetFullPath(Source), TPath.GetFullPath(Template)) then
              raise Exception.Create('Recursive mix include');
            IncludeFile := TPlatformPath.Combine(ExtractFilePath(Destination), 'include-' + TGUID.NewGuid.ToString + '.png');
            RenderMixInternal(Source, Sources, IncludeFile, 0, 0, IncludeDepth + 1);
            Source := IncludeFile;
          end;
          if SameText(Kind, 'Text') then
          begin
            Display := Item.ChildNodes.FindNode('Display');
            Input.SetSize(Max(1, Round(Dimension(Attr(Display, 'Width', '100%'), Reference.Width, Reference.Height))),
              Max(1, Round(Dimension(Attr(Display, 'Height', '100%'), Reference.Height, Reference.Width))));
            Caption := ExpandMixText(Attr(Item, 'Text', ''), Sources).Replace('%%', sLineBreak);
            PaintMixText(Input, Item, Caption, ExtractFilePath(Template), Reference.Height);
          end
          else
            Input.LoadFromFile(Source);
          Display := Item.ChildNodes.FindNode('Display');
          ApplyImageEffect(Input, Attr(Display, 'Effect', 'None'));
          Orientation := Attr(Item, 'IfOrientation', '');
          if ((Orientation = 'IsPortrait') and (Input.Width >= Input.Height)) or
            ((Orientation = 'IsLandscape') and (Input.Height > Input.Width)) then
          begin
            Result := DrawItems(Item.ChildNodes.FindNode('Else'), Depth + 1, Reference, True) or Result;
            Continue;
          end;
          X := Reference.Left + Dimension(Attr(Display, 'X', '0'), Reference.Width, Reference.Height);
          Y := Reference.Top + Dimension(Attr(Display, 'Y', '0'), Reference.Height, Reference.Width);
          W := Dimension(Attr(Display, 'Width', '100%'), Reference.Width, Reference.Height);
          H := Dimension(Attr(Display, 'Height', '100%'), Reference.Height, Reference.Width);
          if (Input.Width = 0) or (Input.Height = 0) then
            Continue;
          if SameText(Attr(Display, 'KeepRatio', 'true'), 'true') then
          begin
            Scale := Min(W / Input.Width, H / Input.Height);
            W := Input.Width * Scale;
            H := Input.Height * Scale;
          end;
          Anchor := Attr(Display, 'Anchor', 'TopLeft');
          if Anchor.Contains('Right') then
            X := X - W
          else if Anchor.Contains('HCenter') or (Anchor = 'Center') then
            X := X - W / 2;
          if Anchor.Contains('Bottom') then
            Y := Y - H
          else if Anchor.Contains('VCenter') or (Anchor = 'Center') then
            Y := Y - H / 2;
          Rect := RectF(X, Y, X + W, Y + H);
          Opacity := EnsureRange(1 - StrToFloatDef(Attr(Display, 'Transparency', '0'), 0, TFormatSettings.Invariant) / 100, 0, 1);
          Filtering := MixFiltering(Attr(Display, 'Antialiasing', 'High'));
          Samples := 1;
          case Filtering of
            mfMedium: Samples := 2;
            mfHigh: Samples := 4;
          end;
          // Loading, includes and pixel effects must not hold the shared FMX canvas lock.
          if SameText(Attr(Display, 'Mode', ''), 'Distord') then
          begin
            Points[0] := PointF(Reference.Left + Dimension(Attr(Display, 'X', '0'), Reference.Width, Reference.Height), Reference.Top + Dimension(Attr(Display, 'Y', '0'), Reference.Height, Reference.Width));
            Points[1] := PointF(Reference.Left + Dimension(Attr(Display, 'X2', '100%'), Reference.Width, Reference.Height), Reference.Top + Dimension(Attr(Display, 'Y2', '0'), Reference.Height, Reference.Width));
            Points[2] := PointF(Reference.Left + Dimension(Attr(Display, 'X3', '100%'), Reference.Width, Reference.Height), Reference.Top + Dimension(Attr(Display, 'Y3', '100%'), Reference.Height, Reference.Width));
            Points[3] := PointF(Reference.Left + Dimension(Attr(Display, 'X4', '0'), Reference.Width, Reference.Height), Reference.Top + Dimension(Attr(Display, 'Y4', '100%'), Reference.Height, Reference.Width));
            ProjectionBounds := RectF(Min(Min(Points[0].X, Points[1].X), Min(Points[2].X, Points[3].X)),
              Min(Min(Points[0].Y, Points[1].Y), Min(Points[2].Y, Points[3].Y)),
              Max(Max(Points[0].X, Points[1].X), Max(Points[2].X, Points[3].X)),
              Max(Max(Points[0].Y, Points[1].Y), Max(Points[2].Y, Points[3].Y)));
            Warped := ProjectImage(Input, Points, Bitmap.Width, Bitmap.Height, Samples);
            Input.Free;
            Input := Warped;
            Rect := Bitmap.BoundsF;
          end
          else if SameText(Attr(Display, 'Mode', ''), 'Barrel') then
          begin
            Warped := BarrelImage(Input, StrToFloatDef(Attr(Display, 'BarrelLevel', '1'), 1, TFormatSettings.Invariant), Samples);
            Input.Free;
            Input := Warped;
          end;
          if not SameText(Attr(Display, 'Mode', ''), 'Distord') then
          begin
            Warped := ResampleBitmap(Input, Max(1, Round(W)), Max(1, Round(H)), Filtering);
            Input.Free;
            Input := Warped;
          end;
          if (Display <> nil) and not SameText(Attr(Item, 'TestOnly', 'false'), 'true') then
          begin
            if not Bitmap.Canvas.BeginScene then
              raise Exception.Create('Cannot begin MIX rendering');
            try
              Matrix := Bitmap.Canvas.Matrix;
              try
                Rotation := Item.ChildNodes.FindNode('Rotation');
                if Rotation <> nil then
                begin
                  PX := X + Dimension(Attr(Rotation, 'XOffset', '50%'), W, H);
                  PY := Y + Dimension(Attr(Rotation, 'YOffset', '50%'), H, W);
                  Bitmap.Canvas.SetMatrix(TMatrix.CreateTranslation(-PX, -PY) * TMatrix.CreateRotation(DegToRad(StrToFloatDef(Attr(Rotation, 'Angle', '0'), 0, TFormatSettings.Invariant))) * TMatrix.CreateTranslation(PX, PY) * Matrix);
                end;
                Bitmap.Canvas.DrawBitmap(Input, Input.BoundsF, Rect, Opacity, SameText(Attr(Display, 'Antialiasing', 'High'), 'None'));
              finally
                Bitmap.Canvas.SetMatrix(Matrix);
              end;
            finally
              Bitmap.Canvas.EndScene;
            end;
            Inc(Drawn);
          end;
          if SameText(Attr(Display, 'Mode', ''), 'Distord') then
            Rect := ProjectionBounds;
          if (Display = nil) or SameText(Attr(Item, 'TestOnly', 'false'), 'true') then
            Rect := Reference;
        finally
          Input.Free;
          if (IncludeFile <> '') and TFile.Exists(IncludeFile) then
            TFile.Delete(IncludeFile);
        end;
      end;
      Result := True;
      Children := Item.ChildNodes.FindNode('Children');
      ChildReference := Reference;
      if SameText(Attr(Children, 'Reference', ''), 'Parent') then
        ChildReference := Rect;
      if SameText(Attr(Children, 'Reference', ''), 'Viewport') then
        ChildReference := Bitmap.BoundsF;
      DrawItems(Children, Depth + 1, ChildReference);
    end;
  end;

begin
  if IncludeDepth > MixIncludeDepthLimit then
    raise Exception.Create('Mix include nesting exceeds 16; check for cyclic includes');
  if not TFile.Exists(Template) then
  begin
    raise Exception.Create('Mix template not found: ' + TPath.GetFileName(Template));
  end;
  XML := TFile.ReadAllText(Template, TEncoding.UTF8);
  // A few shipped 1.4.2 templates contain a non-closed empty Fallback element.
  XML := TRegEx.Replace(XML, '(<Fallback\b[^>]*?)(?<!/)>(\s*</Item>)', '$1 />$2', [roIgnoreCase]);
  Doc := LoadXMLData(XML);
  View := Doc.DocumentElement.ChildNodes.FindNode('Viewport');
  BaseWidth := StrToFloatDef(Attr(View, 'Width', IntToStr(MixDefaultWidth)), MixDefaultWidth);
  BaseHeight := StrToFloatDef(Attr(View, 'Height', IntToStr(MixDefaultHeight)), MixDefaultHeight);
  if (BaseWidth <= 0) or (BaseHeight <= 0) then
    raise Exception.Create('Mix viewport dimensions must be positive');
  if Width <= 0 then
    Width := Round(BaseWidth);
  if Height <= 0 then
    Height := Round(BaseHeight);
  Bitmap := TBitmap.Create(Round(BaseWidth), Round(BaseHeight));
  Drawn := 0;
  try
    Bitmap.Clear(TAlphaColor(StrToInt64Def('$' + Attr(View, 'Color', '#00000000').TrimLeft(['#']), 0)));
    DrawItems(Doc.DocumentElement.ChildNodes.FindNode('Drawings'), 0, Bitmap.BoundsF);
    if Drawn = 0 then
      raise Exception.Create('No matching images in mix template');
    Bitmap.SaveToFile(Destination);
    if (Width <> Bitmap.Width) or (Height <> Bitmap.Height) then
      ResizeImage(Destination, Destination, Width, Height, False);
  finally
    Bitmap.Free;
  end;
end;

procedure RenderMix(const Template: string; Sources: TDictionary<string, string>; const Destination: string; Width, Height: Integer);
begin
  RenderMixInternal(Template, Sources, Destination, Width, Height, 0);
end;

end.

