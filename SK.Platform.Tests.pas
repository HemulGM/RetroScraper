unit SK.platform.Tests;

interface

uses
  System.Classes;

procedure RunPlatformTests(Report: TStrings);

procedure RunPortableSelfTests;

implementation

uses
  {$IFDEF MSWINDOWS}
  Winapi.Windows, {$ELSE}Posix.Unistd, {$ENDIF}
  System.SysUtils, System.IOUtils, System.JSON, System.Threading, System.Hash,
  System.Types, System.UITypes, System.Math, Xml.XMLDoc, Xml.XMLIntf,
  SK.Platform.Graphics, FMX.FontManager, System.Generics.Collections,
  FMX.Graphics, FMX.Types, SK.Mix, SK.Platform, SK.Json, SK.ScreenScraper,
  SK.Storage, SK.Input, SK.Main, SK.Engine, SK.Features.Tests;

type
  TFailingWorker = class(TScrapeWorker)
    procedure Execute; override;
  end;

procedure TFailingWorker.Execute;
begin
  raise Exception.Create('Injected worker failure');
end;

procedure RunTextRegressions(Report: TStrings; const Root: string);
var
  Bitmap: TBitmap;
  Doc: IXMLDocument;
  Node: IXMLNode;
  Data: TBitmapData;
  Bounds: TRect;
  Count, RedPixels, GreenPixels, MaxAlpha, RegisteredCount: Integer;
  First, Second: TBytes;
  FileName: string;

  procedure Check(Condition: Boolean; const Name: string);
  begin
    if not Condition then
      raise Exception.Create('FAIL: ' + Name);
    Report.Add('PASS: ' + Name);
  end;

  procedure Draw(const Text, Attributes: string);
  var
    X, Y: Integer;
    Pixel: TAlphaColor;
  begin
    Doc := LoadXMLData('<Item ' + Attributes + '/>');
    Node := Doc.DocumentElement;
    PaintMixText(Bitmap, Node, Text, AppBase + 'Mixes/ZX-81', 120);
    Check(Bitmap.Map(TMapAccess.Read, Data), 'FMX text pixels can be read');
    try
      Bounds := Rect(Bitmap.Width, Bitmap.Height, 0, 0);
      Count := 0;
      RedPixels := 0;
      GreenPixels := 0;
      MaxAlpha := 0;
      for Y := 0 to Bitmap.Height - 1 do
        for X := 0 to Bitmap.Width - 1 do
        begin
          Pixel := Data.GetPixel(X, Y);
          MaxAlpha := Max(MaxAlpha, Integer(Pixel shr 24));
          if Pixel shr 24 > 16 then
          begin
            Inc(Count);
            Bounds.Left := Min(Bounds.Left, X);
            Bounds.Top := Min(Bounds.Top, Y);
            Bounds.Right := Max(Bounds.Right, X + 1);
            Bounds.Bottom := Max(Bounds.Bottom, Y + 1);
            if Integer((Pixel shr 16) and $FF) > Integer((Pixel shr 8) and $FF) + 30 then
              Inc(RedPixels);
            if Integer((Pixel shr 8) and $FF) > Integer((Pixel shr 16) and $FF) + 30 then
              Inc(GreenPixels);
          end;
        end;
    finally
      Bitmap.Unmap(Data)
    end;
  end;

begin
  Bitmap := TBitmap.Create(240, 30);
  try
    Draw('I', 'TextAlign="TopLeft"');
    Check((Count > 0) and (Bounds.Left < 20), 'FMX text aligns left');
    Draw('I', 'TextAlign="VCenterHCenter"');
    Check((Count > 0) and (Abs((Bounds.Left + Bounds.Right) / 2 - 120) < 15), 'FMX text aligns horizontally centered');
    Draw('I', 'TextAlign="BottomRight"');
    Check((Count > 0) and (Bounds.Right > 220), 'FMX text aligns right');
    Draw('Outlined', 'TextColor="#FFFF0000" TextOutlineColor="#FF00FF00" TextOutlineWidth="3"');
    Check((RedPixels > 0) and (GreenPixels > 0), 'FMX outline and text keep distinct colors');
    Bitmap.SetSize(160, 80);
    Draw('First line' + sLineBreak + 'Вторая строка', 'FontStyle="bold italic underline"');
    Check((Count > 20) and (Bounds.Top > 0) and (Bounds.Bottom < 80), 'FMX multiline Unicode text fits with outline padding');
    Bitmap.SaveToFile(TPlatformPath.Combine(Root, 'fmx-text-multiline.png'));
    Draw('WWWWWWWWWWWWWWWWWWWW', 'TextOutlineWidth="2"');
    Check((Count > 0) and (Bounds.Left >= 2) and (Bounds.Right <= 158), 'FMX fitting handles an unbroken long word');
    Draw('Alpha', 'TextColor="#800000FF" TextOutlineWidth="0"');
    Check((Count > 0) and (MaxAlpha <= 128), 'FMX text preserves alpha channel');
    Draw('RGB', 'TextColor="#0000FF" TextOutlineWidth="0"');
    Check(Count > 0, 'FMX text accepts RGB colors as opaque');
    Draw('', '');
    Check(Count = 0, 'Empty text clears the destination');
    Bitmap.SetSize(1, 1);
    Draw('Tiny', 'TextOutlineWidth="3"');
    Check((Bitmap.Width = 1) and (Bitmap.Height = 1), 'FMX text handles a one-pixel destination');
    Bitmap.SetSize(160, 80);
    Draw('CUSTOM', 'FontFile="ka1.ttf"');
    Check(Count > 20, 'FMX custom TTF font renders glyphs');
    FileName := TPlatformPath.Combine(Root, 'fmx-text-custom.png');
    Bitmap.SaveToFile(FileName);
    First := TFile.ReadAllBytes(FileName);
    RegisteredCount := TFontManager.CustomFontInfoCount;
    Draw('CUSTOM', 'FontFile="ka1.ttf"');
    Bitmap.SaveToFile(FileName);
    Second := TFile.ReadAllBytes(FileName);
    Check((RegisteredCount = TFontManager.CustomFontInfoCount) and
      (Length(First) = Length(Second)) and CompareMem(@First[0], @Second[0], Length(First)),
      'FMX reuses the registered font with identical output');
  finally
    Bitmap.Free;
  end;
end;

procedure RunPlatformTests(Report: TStrings);
var
  Root, FileName, Temporary: string;
  JSON: TJSONObject;
  Jobs: array[0..3] of ITask;
  Worker: TScrapeWorker;
  Status: TScrapeStatus;
  Lines: TStringList;
  Rejected: Boolean;
  API: TScreenScraper;
  I, X, Y, NonTransparent: Integer;
  Bitmap: TBitmap;
  Pixels: TBitmapData;
  Sources: TDictionary<string, string>;

  procedure Check(Condition: Boolean; const Name: string);
  begin
    if not Condition then
      raise Exception.Create('FAIL: ' + Name);
    Report.Add('PASS: ' + Name);
  end;

begin
  Root := TPlatformPath.Combine(WritableBase, 'tests/platform-' + TGUID.NewGuid.ToString);
  ForceDirectories(Root);
  Rejected := False;
  try
    TScrapeWorker.Create(nil, nil, Root, -1, True).Free;
  except
    on E: EArgumentNilException do
      Rejected := True
  end;
  Check(Rejected, 'Invalid worker arguments unwind without secondary AV');
  JSON := TJSONObject.Create;
  Lines := TStringList.Create;
  try
    Worker := TFailingWorker.Create(JSON, JSON, Root, -1, True);
    try
      Worker.Start;
      Worker.WaitFor;
      Worker.Snapshot(Status, Lines);
      Check(Status.Finished and not Status.Running and (Status.Errors = 1) and
        (Status.LastError = 'Injected worker failure') and (Status.Stage = 'Failed'),
        'Unhandled worker failure is visible in final status');
    finally
      Worker.Free
    end;
    API := TScreenScraper.Create(JSON, Root);
    try
      WriteJSON(TPlatformPath.Combine(Root, THashSHA2.GetHashString('fixture?') + '.json'), JSON);
      API.Offline := True;
      API.IsCancelled :=
        function: Boolean
        begin
          Result := True
        end;
      Rejected := False;
      try
        API.Request('fixture', '').Free;
      except
        on E: EAbort do
          Rejected := True
      end;
      Check(Rejected and (API.Requests = 0) and (API.CacheHits = 0),
        'Cancellation takes priority over an available cached response');
    finally
      API.Free
    end;
  finally
    Lines.Free;
    JSON.Free
  end;
  Check(not DirectoryLink(Root), 'Ordinary directory is not a link');
  Temporary := TPlatformPath.Combine(Root, '.hidden');
  TFile.WriteAllText(Temporary, 'test', TEncoding.UTF8);
  Check(HiddenEntry(Temporary), 'Dot-prefixed file is hidden');
  {$IFDEF MSWINDOWS}
  Temporary := TPlatformPath.Combine(Root, 'hidden-attribute');
  TFile.WriteAllText(Temporary, 'test', TEncoding.UTF8);
  if not SetFileAttributes(PChar(Temporary), FILE_ATTRIBUTE_HIDDEN) then
    RaiseLastOSError;
  Check(HiddenEntry(Temporary), 'Windows hidden attribute is recognized');
  {$ELSE}
  Temporary := TPlatformPath.Combine(Root, 'directory-link');
  if symlink(MarshaledAString(UTF8String(Root)), MarshaledAString(UTF8String(Temporary))) <> 0 then
    RaiseLastOSError;
  Check(DirectoryLink(Temporary), 'POSIX directory symlink is detected without following it');
  Check(DirectoryLink(IncludeTrailingPathDelimiter(Temporary)), 'Directory symlink with trailing slash is detected');
  {$ENDIF}
  FileName := TPlatformPath.Combine(Root, 'данные.json');
  Check(not SamePath(FileName, ''), 'Empty optional path does not raise');
  Check(IsPathWithin(FileName, Root), 'Path containment uses directory boundary');
  Check(not IsPathWithin(Root + '-other/file', Root), 'Sibling directory is not a child');
  Check(NativePath('folder\child') = TPlatformPath.Combine('folder', 'child'), 'Portable legacy path separators');
  {$IFDEF MSWINDOWS}
  Check(SamePath(Root + '\Game.rom', Root + '\game.rom'), 'Windows path identity ignores case');
  {$ELSE}
  Check(not SamePath(Root + '/Game.rom', Root + '/game.rom'), 'POSIX path identity preserves case');
  {$ENDIF}
  JSON := TJSONObject.Create;
  try
    JSON.AddPair('value', 'first');
    WriteJSON(FileName, JSON);
    JSet(JSON, 'value', TJSONString.Create('second'));
    WriteJSON(FileName, JSON);
  finally
    JSON.Free
  end;
  JSON := ReadJSON(FileName);
  try
    Check(JStr(JSON, 'value') = 'second', 'Atomic JSON replacement preserves UTF-8 filenames');
  finally
    JSON.Free
  end;
  JSON := ReadJSON(FileName + '.bak');
  try
    Check(JStr(JSON, 'value') = 'first', 'Atomic JSON replacement retains previous backup');
  finally
    JSON.Free
  end;
  for I := 0 to High(Jobs) do
    Jobs[I] := TTask.Run(
      procedure
      var
        Value: TJSONObject;
      begin
        Value := TJSONObject.Create;
        try
          Value.AddPair('value', 'parallel');
          WriteJSON(FileName, Value);
        finally
          Value.Free
        end;
      end);
  for I := 0 to High(Jobs) do
    Jobs[I].Wait;
  JSON := ReadJSON(FileName);
  try
    Check(JStr(JSON, 'value') = 'parallel', 'Concurrent JSON publication leaves valid complete document');
  finally
    JSON.Free
  end;
  Check(Length(TDirectory.GetFiles(Root, '*.tmp')) = 0, 'Atomic writes leave no staging files');
  Temporary := TPlatformPath.Combine(Root, 'no-such-file');
  try
    AtomicReplace(Temporary, FileName);
  except
    on E: EOSError do
      ;
  end;
  Check(TFile.Exists(FileName), 'Failed replacement preserves destination');
  Sources := TDictionary<string, string>.Create;
  Bitmap := TBitmap.Create;
  try
    Temporary := TPlatformPath.Combine(Root, 'text-mix.xml');
    TFile.WriteAllText(Temporary, '<ImageComposition><Viewport Width="160" Height="80"/><Drawings><Item Type="Text" Text="TEST" TextColor="#FFFFFFFF" TextAlign="VCenterHCenter"><Display Width="100%" Height="100%"/></Item></Drawings></ImageComposition>', TEncoding.UTF8);
    RenderMix(Temporary, Sources, TPlatformPath.Combine(Root, 'text.png'), 0, 0);
    Bitmap.LoadFromFile(TPlatformPath.Combine(Root, 'text.png'));
    Check((Bitmap.Width = 160) and (Bitmap.Height = 80), 'Native MIX renderer preserves output dimensions');
    NonTransparent := 0;
    Check(Bitmap.Map(TMapAccess.Read, Pixels), 'Native MIX result maps into pixels');
    try
      for Y := 0 to Bitmap.Height - 1 do
        for X := 0 to Bitmap.Width - 1 do
          if Pixels.GetPixel(X, Y) shr 24 <> 0 then
            Inc(NonTransparent);
    finally
      Bitmap.Unmap(Pixels)
    end;
    Check(NonTransparent > 20, 'Native text renderer produces visible glyphs');
  finally
    Bitmap.Free;
    Sources.Free
  end;
  RunTextRegressions(Report, Root);
  {$IFDEF MSWINDOWS}
  Temporary := TPlatformPath.Combine(Root, 'test-secret.dat');
  SaveSecret(Temporary, 'synthetic-test-value');
  Check(LoadSecret(Temporary) = 'synthetic-test-value', 'Windows protected secret round trip');
  Check(not TFile.ReadAllText(Temporary, TEncoding.ASCII).Contains('synthetic-test-value'), 'Protected secret is not stored as plaintext');
  TFile.Delete(Temporary);
  {$ENDIF}
end;

procedure RunPortableSelfTests;
var
  Report: TStringList;
  Bitmap: TBitmap;
begin
  Report := TStringList.Create;
  try
    try
      RunPlatformTests(Report);
      RunFeatureTests(Report);
      FormMain := TFormMain.Create(nil);
      try
        Bitmap := TBitmap.Create(1280, 855);
        try
          FormMain.ClientWidth := 1280;
          FormMain.ClientHeight := 855;
          if Bitmap.Canvas.BeginScene then
          try
            FormMain.PaintTo(Bitmap.Canvas);
          finally
            Bitmap.Canvas.EndScene
          end;
          Bitmap.SaveToFile(TPlatformPath.Combine(WritableBase, 'tests/main-form.png'));
        finally
          Bitmap.Free
        end;
      finally
        FreeAndNil(FormMain)
      end;
      Report.Add('PASS: Main FMX form and dark style load and render');
      Report.Add('ALL PORTABLE TESTS PASSED');
    except
      on E: Exception do
      begin
        Report.Add(E.ClassName + ': ' + E.Message);
        ExitCode := 1
      end
    end;
    ForceDirectories(TPlatformPath.Combine(WritableBase, 'tests'));
    Report.SaveToFile(TPlatformPath.Combine(WritableBase, 'tests/portable-results.txt'), TEncoding.UTF8);
  finally
    Report.Free
  end;
end;

end.

