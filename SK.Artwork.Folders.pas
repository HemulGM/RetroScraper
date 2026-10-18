unit SK.Artwork.Folders;

interface

uses
  System.SysUtils, System.Classes;

procedure RenderFolderArtwork(const Destination, Title: string; Sources: TStrings; Mode: Integer; Cancel: TFunc<Boolean> = nil);

implementation

uses
  System.IOUtils, System.Types, System.UITypes, System.Math, FMX.Graphics,
  FMX.Types, SK.Platform, SK.Storage;

procedure RenderFolderArtwork(const Destination, Title: string; Sources: TStrings; Mode: Integer; Cancel: TFunc<Boolean>);
var
  Output, Input: TBitmap;
  Pixels: TBitmapData;
  X, Y: Integer;
  Color: TAlphaColor;
  I, Count, Cols, Rows: Integer;
  R: TRectF;
  W, H, Scale: Single;
begin
  EnsureDirectory(ExtractFilePath(Destination));
  Output := TBitmap.Create(512, 384);
  Input := TBitmap.Create;
  try
    Output.Clear(0);
    if Mode = 1 then
    begin
      Output.LoadFromFile(AppBase + NativePath('Resources\SkraperLibrary2.Properties.Resource\foldermask.png'));
      if Output.Map(TMapAccess.ReadWrite, Pixels) then
      try
        for Y := 0 to Output.Height - 1 do
          for X := 0 to Output.Width - 1 do
          begin
            Color := Pixels.GetPixel(X, Y);
            Pixels.SetPixel(X, Y, (Color and $FF000000) or $00F7CD23);
          end;
      finally
        Output.Unmap(Pixels)
      end;
    end;
    if Mode <> 1 then
    begin
      if not Output.Canvas.BeginScene then
        raise Exception.Create('Cannot begin folder rendering');
      try
        Output.Canvas.Fill.Color := $FF888888;
        Output.Canvas.FillRect(RectF(24, 64, 200, 112), 12, 12, AllCorners, 1);
        Output.Canvas.FillRect(RectF(24, 94, 488, 354), 16, 16, AllCorners, 1);
      finally
        Output.Canvas.EndScene;
      end;
      Count := 0;
      if Mode = 2 then
        Count := Min(1, Sources.Count)
      else if Mode = 3 then
        Count := Sources.Count;
      Cols := Max(1, Ceil(Sqrt(Count)));
      Rows := Max(1, Ceil(Count / Cols));
      for I := 0 to Count - 1 do
      begin
        if Assigned(Cancel) and Cancel() then
          raise EAbort.Create('Cancelled');
        if not TFile.Exists(Sources[I]) then
          Continue;
        Input.LoadFromFile(Sources[I]);
        if Input.IsEmpty then
          Continue;
        W := 440 / Cols;
        H := 224 / Rows;
        Scale := Min(W / Input.Width, H / Input.Height);
        R := RectF(36 + (I mod Cols) * W, 108 + (I div Cols) * H, 36 + (I mod Cols) * W + Input.Width * Scale, 108 + (I div Cols) * H + Input.Height * Scale);
        if not Output.Canvas.BeginScene then
          raise Exception.Create('Cannot begin folder rendering');
        try
          Output.Canvas.DrawBitmap(Input, Input.BoundsF, R, 1, False);
        finally
          Output.Canvas.EndScene;
        end;
      end;
      if Count = 0 then
      begin
        if not Output.Canvas.BeginScene then
          raise Exception.Create('Cannot begin folder rendering');
        try
          Output.Canvas.Fill.Color := $FFFFFFFF;
          Output.Canvas.Font.Size := 28;
          Output.Canvas.FillText(RectF(44, 130, 468, 325), Title, True, 1, [], TTextAlign.Center, TTextAlign.Center);
        finally
          Output.Canvas.EndScene;
        end;
      end;
    end;
    if Assigned(Cancel) and Cancel() then
      raise EAbort.Create('Cancelled');
    Output.SaveToFile(Destination);
  finally
    Input.Free;
    Output.Free;
  end;
end;

end.

