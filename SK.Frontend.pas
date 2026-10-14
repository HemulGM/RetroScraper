unit SK.Frontend;

interface

uses
  System.SysUtils, System.JSON;

procedure ResolveFrontendPaths(SystemConfig, Frontend: TJSONObject; Catalog: TJSONObject = nil);

procedure ApplyFrontendDefaults(Config: TJSONObject; ReplaceMedia: Boolean = False);

function DefaultMedia(Frontend: Integer; Existing: TJSONArray = nil): TJSONObject;

function DefaultMediaFolder(Frontend, Kind, Image: Integer; Existing: TJSONArray = nil): string;

function FrontendMedia(Frontend: Integer): TJSONArray;

function EnsureRecalboxMedia(SystemConfig: TJSONObject): Integer;

procedure AppendSystemMedia(Target, Source: TJSONObject);

procedure StopLocalFrontend(Frontend: TJSONObject; const Log: TProc<string>; Cancel: TFunc<Boolean> = nil);

implementation

uses
  System.Classes, System.IOUtils, System.StrUtils, System.Math, SK.Platform,
  SK.Core, SK.Consts, SK.Catalog;

function SafePlatformName(const Name: string): string;
var
  C: Char;
begin
  Result := Name;
  for C in ['<', '>', ':', '"', '/', '\', '|', '?', '*'] do
    Result := Result.Replace(C, '-');
  for C in Result do
    if Ord(C) < 32 then
      Result := Result.Replace(C, ' ');
  Result := Result.Trim.TrimRight(['.', ' ']);
  if Result = '' then
    Result := 'Platform';
end;

function DefaultMediaFolder(Frontend, Kind, Image: Integer; Existing: TJSONArray): string;
const
  Names: array[0..16] of string = ('screenshot', 'screenshottitle', 'fanart', 'box2dfront',
    'box2dside', 'box2dback', 'box3d', 'boxtexture', 'support', 'supporttexture', 'wheel',
    'wheelcarbon', 'wheelsteel', 'steamgrid', 'screenmarquee', 'screenmarqueesmall', 'marquee');
var
  Folder: string;
  V: TJSONValue;
  MainUsed: Boolean;
begin
  Folder := 'images';
  MainUsed := False;
  if Existing <> nil then
    for V in Existing do
      if SameText(NativePath(JStr(V, 'OutputFolder')), NativePath('%ROMROOTFOLDER%\media\images')) then
        MainUsed := True;
  if Frontend = 2 then
  begin
    case Kind of
      0:
        case Image of
          0:
            Folder := 'Screenshot - Gameplay';
          1:
            Folder := 'Screenshot - Game Title';
          2:
            Folder := 'Fanart - Background';
          3:
            Folder := 'Box - Front';
          4:
            Folder := 'Box - Spine';
          5:
            Folder := 'Box - Back';
          6:
            Folder := 'Box - 3D';
          7:
            Folder := 'Box - Full';
          8:
            Folder := 'Cart - Front';
          9:
            Folder := 'Cart - 3D';
          10..12:
            Folder := 'Clear Logo';
          13:
            Folder := 'Steam Banner';
          14..16:
            Folder := 'Arcade - Marquee';
        else
          Folder := 'Skraper'
        end;
      1, 2:
        Folder := 'Screenshot - Game Select';
      3, 4:
        Exit(NativePath('%FRONTENDROOTFOLDER%\Videos\%LAUNCHBOXPLATFORM%'));
      5, 6, 7:
        Exit(NativePath('%FRONTENDROOTFOLDER%\Manuals\%LAUNCHBOXPLATFORM%'));
      8:
        Exit(NativePath('%FRONTENDROOTFOLDER%\Maps\%LAUNCHBOXPLATFORM%'));
    end;
    Exit(NativePath('%FRONTENDROOTFOLDER%\Images\%LAUNCHBOXPLATFORM%\' + Folder));
  end;
  case Kind of
    0:
      if not ((Frontend in [0, 1]) and not MainUsed) then
      begin
        Folder := Names[EnsureRange(Image, 0, 16)];
        if (Frontend = 0) and (Image in [3..7]) then
          Folder := 'boxes';
        if (Frontend = 0) and (Image in [10..12]) then
          Folder := 'wheels';
        if (Frontend = 1) and (Image in [14..16]) then
          Folder := 'marquee';
      end;
    1, 2:
      if (Frontend in [0, 1]) and MainUsed then
        Folder := 'mix';
    3, 4:
      Folder := 'videos';
    5:
      if Frontend in [0, 1] then
        Folder := 'manuals'
      else
        Folder := 'manual';
    6:
      if Frontend = 0 then
        Folder := 'tipsandtricks'
      else if Frontend = 1 then
        Folder := 'manuals'
      else
        Folder := 'manual';
    7:
      if Frontend = 0 then
        Exit('%ROMROOTFOLDER%')
      else if Frontend = 1 then
        Folder := 'manuals'
      else
        Folder := 'manual';
    8:
      Folder := 'maps';
  end;
  Result := NativePath('%ROMROOTFOLDER%\media\' + Folder);
end;

function NewMedia(Frontend, Kind, Image: Integer; Existing: TJSONArray): TJSONObject;
begin
  Result := TJSONObject.Create;
  Result.AddPair('Type', TJSONNumber.Create(Kind));
  Result.AddPair('Image', TJSONNumber.Create(Image));
  Result.AddPair('InternalMix', TJSONNumber.Create(3));
  Result.AddPair('LocalMixFile', '');
  Result.AddPair('OutputFolder', DefaultMediaFolder(Frontend, Kind, Image, Existing));
  Result.AddPair('LinkToNode', TJSONBool.Create(True));
  Result.AddPair('Optimize', TJSONBool.Create(Frontend in [0, 1]));
  Result.AddPair('EmptyOutputFolder', TJSONBool.Create((Frontend in [0, 1]) and (Kind <> 7)));
  Result.AddPair('ResizeWidth', TJSONBool.Create(Kind in [0, 1, 2]));
  Result.AddPair('ResizeHeight', TJSONBool.Create(Kind in [0, 1, 2]));
  Result.AddPair('KeepRatio', TJSONBool.Create(True));
  Result.AddPair('ResizeWidthValue', TJSONNumber.Create(DefaultMediaWidth));
  Result.AddPair('ResizeHeightValue', TJSONNumber.Create(DefaultMediaHeight));
end;

function DefaultMedia(Frontend: Integer; Existing: TJSONArray): TJSONObject;
var
  K, I, N: Integer;

  function Has(Kind, Image: Integer): Boolean;
  var
    V: TJSONValue;
  begin
    Result := False;
    if Existing <> nil then
      for V in Existing do
        if (JInt(V, 'Type') = Kind) and ((Kind <> 0) or (JInt(V, 'Image') = Image)) then
          Exit(True);
  end;

  function Slot(Kind, Image: Integer): TJSONObject;
  begin
    Result := NewMedia(Frontend, Kind, Image, Existing)
  end;

begin
  if not Has(1, 0) and not Has(2, 0) then
    Exit(Slot(1, 0));
  if Frontend = 0 then
  begin
    for I in [10, 6] do
      if not Has(0, I) then
        Exit(Slot(0, I));
    for K in [3, 5, 8, 6, 7] do
      if not Has(K, 0) then
        Exit(Slot(K, 0));
  end
  else if Frontend = 1 then
  begin
    if not Has(3, 0) and not Has(4, 0) then
      Exit(Slot(3, 0));
    if not Has(0, 14) and not Has(0, 15) and not Has(0, 16) then
      Exit(Slot(0, 14));
  end
  else if Frontend = 2 then
  begin
    for I in [0, 1, 2] do
      if not Has(0, I) then
        Exit(Slot(0, I));
    if not Has(3, 0) then
      Exit(Slot(3, 0));
    for I in [14, 10, 13, 3, 5, 6, 8] do
      if not Has(0, I) then
        Exit(Slot(0, I));
    if not Has(5, 0) then
      Exit(Slot(5, 0));
  end
  else
  begin
    if not Has(5, 0) then
      Exit(Slot(5, 0));
    if not Has(3, 0) then
      Exit(Slot(3, 0));
  end;
  for N := 0 to High(ScreenScraperImageTypes) do
    if not Has(0, N) then
      Exit(Slot(0, N));
  Result := Slot(0, 0);
end;

function FrontendMedia(Frontend: Integer): TJSONArray;
var
  I, Count: Integer;
begin
  case Frontend of
    0:
      Count := 8;
    1, 3:
      Count := 3;
    2:
      Count := 12;
  else
    Count := 2
  end;
  Result := TJSONArray.Create;
  try
    for I := 1 to Count do
      Result.AddElement(DefaultMedia(Frontend, Result));
  except
    Result.Free;
    raise
  end;
end;

procedure ApplyFrontendDefaults(Config: TJSONObject; ReplaceMedia: Boolean);
var
  Master: TJSONObject;
  FE, ListType, FolderMode: Integer;
  Path: string;
  V: TJSONValue;
  Earlier: TJSONArray;
begin
  FE := JInt(Config, 'FrontEnd.Type');
  Master := JValue(Config, 'AllSystems') as TJSONObject;
  ListType := 1;
  FolderMode := 1;
  Path := NativePath('%ROMROOTFOLDER%\gamelist.xml');
  if FE = 2 then
  begin
    ListType := 2;
    FolderMode := 0;
    Path := NativePath('%FRONTENDROOTFOLDER%\Data\Platforms\%LAUNCHBOXPLATFORM%.xml')
  end
  else if FE = 4 then
  begin
    ListType := 3;
    FolderMode := 0;
    Path := NativePath('%ROMROOTFOLDER%\%SCREENSCRAPERPLATFORM%.dat')
  end;
  JSet(Master, 'GameList.Type', TJSONNumber.Create(ListType));
  JSet(Master, 'GameList.Folders', TJSONNumber.Create(FolderMode));
  JSet(Master, 'GameList.OutputFile', TJSONString.Create(Path));
  if ReplaceMedia or not (JValue(Master, 'Medias') is TJSONArray) or
    (TJSONArray(JValue(Master, 'Medias')).Count = 0) then
    JSet(Master, 'Medias', FrontendMedia(FE))
  else
  begin
    Earlier := TJSONArray.Create;
    try
      for V in TJSONArray(JValue(Master, 'Medias')) do
      begin
        JSet(V as TJSONObject, 'OutputFolder', TJSONString.Create(DefaultMediaFolder(FE, JInt(V, 'Type'), JInt(V, 'Image'), Earlier)));
        Earlier.AddElement(V.Clone as TJSONValue);
      end;
    finally
      Earlier.Free
    end;
  end;
  if FE = 0 then
    JSet(Config, 'FrontEnd.NetworkHost', TJSONString.Create('RECALBOX'))
  else if FE = 1 then
    JSet(Config, 'FrontEnd.NetworkHost', TJSONString.Create('RETROPIE'));
end;

procedure ResolveFrontendPaths(SystemConfig, Frontend: TJSONObject; Catalog: TJSONObject);
var
  V: TJSONValue;
  S, Home, platform, Root, SSName, General: string;
  Loaded: TJSONObject;

  function Expand(const Value: string): string;
  begin
    Result := NativePath(Value.Replace('%FRONTENDROOTFOLDER%', Home, [rfReplaceAll, rfIgnoreCase])
      .Replace('%LAUNCHBOXPLATFORM%', platform, [rfReplaceAll, rfIgnoreCase])
      .Replace('%SCREENSCRAPERPLATFORM%', SSName, [rfReplaceAll, rfIgnoreCase])
      .Replace('%PLATFORM%', General, [rfReplaceAll, rfIgnoreCase])
      .Replace('%ROMROOTFOLDER%', Root, [rfReplaceAll, rfIgnoreCase]));
  end;

begin
  Loaded := nil;
  try
    if Catalog = nil then
    begin
      Loaded := ReadJSON(TPlatformPath.Combine(WritableBase, SystemsCatalogPath));
      if Loaded = nil then
        Loaded := ReadJSON(TPlatformPath.Combine(AppBase, SystemsCatalogPath));
      Catalog := Loaded;
    end;
    Home := JStr(Frontend, 'HomePath');
    Root := JStr(SystemConfig, 'GamesAndRoms.Path');
    if (JInt(Frontend, 'Type') = 2) and (Home = '') then
      raise Exception.Create('Set the LaunchBox front-end path before scraping.');
    if CatalogSystem(Catalog, JInt(SystemConfig, 'SystemId')) <> nil then
      SSName := PlatformName(Catalog, SystemConfig, JInt(SystemConfig, 'SystemId'))
    else
      SSName := TPath.GetFileName(ExcludeTrailingPathDelimiter(Root));
    SSName := SafePlatformName(SSName);
    platform := JStr(SystemConfig, 'GamesAndRoms.Platform');
    if platform = '' then
      platform := SSName;
    platform := SafePlatformName(platform);
    if JInt(Frontend, 'Type') in [2, 4] then
      General := platform
    else
      General := SSName;
    S := JStr(SystemConfig, 'GameList.OutputFile');
    if S = '' then
      case JInt(SystemConfig, 'GameList.Type', 1) of
        2:
          S := NativePath('%FRONTENDROOTFOLDER%\Data\Platforms\%LAUNCHBOXPLATFORM%.xml');
        3:
          S := NativePath('%ROMROOTFOLDER%\%SCREENSCRAPERPLATFORM%.dat');
      else
        S := NativePath('%ROMROOTFOLDER%\gamelist.xml')
      end;
    JSet(SystemConfig, 'GameList.OutputFile', TJSONString.Create(Expand(S)));
    JSet(SystemConfig, 'GamesAndRoms.Platform', TJSONString.Create(General));
    if JValue(SystemConfig, 'Medias') is TJSONArray then
      for V in TJSONArray(JValue(SystemConfig, 'Medias')) do
        JSet(V as TJSONObject, 'OutputFolder', TJSONString.Create(Expand(JStr(V, 'OutputFolder'))));
  finally
    Loaded.Free
  end;
end;

function EnsureRecalboxMedia(SystemConfig: TJSONObject): Integer;
var
  A: TJSONArray;
  V: TJSONValue;
  Screenshot, Box, Logo: Boolean;
begin
  if not (JValue(SystemConfig, 'Medias') is TJSONArray) then
    JSet(SystemConfig, 'Medias', TJSONArray.Create);
  A := TJSONArray(JValue(SystemConfig, 'Medias'));
  Screenshot := False;
  Box := False;
  Logo := False;
  for V in A do
    if JBool(V, 'LinkToNode', True) then
    begin
      Screenshot := Screenshot or (JInt(V, 'Type') in [1, 2]) or ((JInt(V, 'Type') = 0) and (JInt(V, 'Image') in [0, 1]));
      Box := Box or ((JInt(V, 'Type') = 0) and (JInt(V, 'Image') in [3, 6]));
      Logo := Logo or ((JInt(V, 'Type') = 0) and (JInt(V, 'Image') in [10, 11, 12, 13, 15]));
    end;
  Result := 0;
  if not Screenshot then
  begin
    A.AddElement(NewMedia(0, 1, 0, A));
    Inc(Result)
  end;
  if not Box then
  begin
    A.AddElement(NewMedia(0, 0, 6, A));
    Inc(Result)
  end;
  if not Logo then
  begin
    A.AddElement(NewMedia(0, 0, 10, A));
    Inc(Result)
  end;
end;

procedure AppendSystemMedia(Target, Source: TJSONObject);
var
  A: TJSONArray;
  V: TJSONValue;
begin
  if not (JValue(Source, 'Medias') is TJSONArray) then
    Exit;
  if not (JValue(Target, 'Medias') is TJSONArray) then
    JSet(Target, 'Medias', TJSONArray.Create);
  A := TJSONArray(JValue(Target, 'Medias'));
  for V in TJSONArray(JValue(Source, 'Medias')) do
    A.AddElement(V.Clone as TJSONValue);
end;

procedure StopLocalFrontend(Frontend: TJSONObject; const Log: TProc<string>; Cancel: TFunc<Boolean>);
var
  Host, Name: string;
  C: Char;
begin
  if Assigned(Cancel) and Cancel() then
    raise EAbort.Create('Cancelled');
  if not JBool(Frontend, 'Kill') then
    Exit;
  case JInt(Frontend, 'Type') of
    0, 1:
      begin
        Host := JStr(Frontend, 'NetworkHost').Trim;
        if (Host = '') or Host.StartsWith('-') then
          raise Exception.Create('Enter an SSH host');
        for C in Host do
          if not CharInSet(C, ['a'..'z', 'A'..'Z', '0'..'9', '-', '_', '.', ':', '@', '[', ']']) then
            raise Exception.Create('Invalid SSH host');
        if not Host.Contains('@') then
          if JInt(Frontend, 'Type') = 0 then
            Host := 'root@' + Host
          else
            Host := 'pi@' + Host;
        StopRemoteProcess(Host, Cancel);
        if Assigned(Log) then
          Log('EmulationStation stopped on ' + Host);
        Exit;
      end;
    2:
      Name := 'LaunchBox.exe';
    3:
      Name := 'retrobat.exe';
  else
    raise Exception.Create('Automatic shutdown is unavailable for a generic frontend');
  end;
  StopNamedProcess(Name, Log, Cancel);
end;

end.

