unit SK.Data;

interface

uses
  SK.platform, System.SysUtils, System.Classes, System.JSON, System.IOUtils,
  System.Generics.Collections, Xml.XMLIntf, Xml.XMLDoc, SK.Core;

function JoinValues(Obj: TJSONValue; const Path, Default: string): string;

function PickText(Obj: TJSONValue; const Path, Key, Priority: string; AStrict: Boolean = False): string;

function OrderedRomRegions(Game, Config: TJSONObject; const FileName: string): string;

function RegionPriority(Game, Config: TJSONObject; const FileName: string): string;

function SelectMedia(Entries: TJSONValue; const MediaType, ParentType, ParentID, Priority, Classification: string; Support: Integer; AStrict: Boolean): TJSONValue;

function MediaNode(Configs: TJSONArray; Index: Integer): string;

function TipsContent(Game, Config: TJSONObject): string;

function DescribeGame(Game, Config: TJSONObject; const FileName: string): TJSONObject;

function CollectRoms(Config: TJSONObject): TArray<string>;

function ResolveOutput(const Pattern, Root, FileName: string): string;

type
  TGameListWriter = class
  private
    FDoc: IXMLDocument;
    FRoot: IXMLNode;
    FFile, FRomRoot, FPlatform: string;
    FKind, FBehavior, FSystemID: Integer;
    FOptimize, FPreserveMissingMedia, FPreserveHeader: Boolean;
    FFolderMode: Integer;
    FFolderSources: TObjectDictionary<string, TStringList>;
    FIndex: TDictionary<string, IXMLNode>;
    function NodeKey(Node: IXMLNode): string;
    function NormalizeKey(const Value: string): string;
  public
    constructor Create(Config: TJSONObject);
    destructor Destroy; override;
    procedure Add(Item: TJSONObject);
    procedure Save(Cancel: TFunc<Boolean> = nil);
    function PrepareFolders(Cancel: TFunc<Boolean> = nil): TArray<string>;
    property Document: IXMLDocument read FDoc;
  end;

implementation

uses
  SK.Consts, SK.Input, System.StrUtils, System.RegularExpressions,
  System.DateUtils, System.Zip, System.NetEncoding, System.Hash, System.Types,
  System.UITypes, System.Math, FMX.Graphics, FMX.Types;

function JoinValues(Obj: TJSONValue; const Path, Default: string): string;
var
  A, V: TJSONValue;
begin
  Result := '';
  A := JValue(Obj, Path);
  if A is TJSONArray then
    for V in TJSONArray(A) do
    begin
      if Result <> '' then
        Result := Result + ',';
      Result := Result + V.Value;
    end;
  if (Result = '') and not (A is TJSONArray) then
    Result := Default;
end;

function PickText(Obj: TJSONValue; const Path, Key, Priority: string; AStrict: Boolean): string;
var
  A, V: TJSONValue;
  P: string;
begin
  Result := '';
  A := JValue(Obj, Path);
  if A is TJSONArray then
  begin
    for P in Priority.Split([',']) do
      for V in TJSONArray(A) do
        if SameText(P.Trim, JStr(V, Key)) then
          Exit(TNetEncoding.HTML.Decode(JStr(V, 'text')));
    if not AStrict then
    begin
      for V in TJSONArray(A) do
        if SameText(JStr(V, Key), 'wor') then
          Exit(TNetEncoding.HTML.Decode(JStr(V, 'text')));
      if TJSONArray(A).Count > 0 then
        Result := TNetEncoding.HTML.Decode(JStr(TJSONArray(A).Items[0], 'text'));
    end;
  end
  else if A is TJSONObject then
    Result := JStr(A, 'text')
  else if A <> nil then
    Result := A.Value;
end;

function ResolveOutput(const Pattern, Root, FileName: string): string;
begin
  Result := Pattern.Replace('%ROMROOTFOLDER%', Root, [rfReplaceAll, rfIgnoreCase]);
  Result := Result.Replace('%ROMFOLDER%', ExtractFileDir(FileName), [rfReplaceAll, rfIgnoreCase]);
  if not TPath.IsPathRooted(Result) then
    Result := TPlatformPath.Combine(Root, Result);
  Result := TPath.GetFullPath(NativePath(Result));
end;

function CollectRoms(Config: TJSONObject): TArray<string>;
begin
  Result := ScanInputs(Config)
end;

function UseRomFileNameMetadata(Game, Config: TJSONObject): Boolean;
var
  Names, V: TJSONValue;
begin
  Result := False;
  if not JBool(Config, 'MetaData.ParseRomFileName', True) then
    Exit;
  if (Game = nil) or JBool(Game, 'notgame') then
    Exit(True);
  Names := JValue(Game, 'noms');
  if Names is TJSONArray then
    for V in TJSONArray(Names) do
      if JStr(V, 'text').Trim.StartsWith('ZZZ(notgame):', True) then
        Exit(True);
end;

function RegionCode(const Token: string): string;
var
  Pair: string;
begin
  Result := '';
  for Pair in RegionAliases.Split([';']) do
    if SameText(Pair.Split(['='])[0], Token.Replace(' ', '')) then
      Exit(Pair.Split(['='])[1]);
end;

function OrderedRomRegions(Game, Config: TJSONObject; const FileName: string): string;
var
  Values, Ordered: TStringList;
  Token, Code, Raw: string;
  M: TMatch;
begin
  Values := TStringList.Create;
  Ordered := TStringList.Create;
  try
    Values.CaseSensitive := False;
    Ordered.CaseSensitive := False;
    if JBool(Config, 'MetaData.ExtractRegionFromFileName') or UseRomFileNameMetadata(Game, Config) then
      for M in TRegEx.Matches(TPath.GetFileNameWithoutExtension(FileName), '[\(\[]([^\)\]]*)[\)\]]') do
        for Token in M.Groups[1].Value.Split([',', ';']) do
        begin
          Code := RegionCode(Token.Trim);
          if (Code <> '') and (Values.IndexOf(Code) < 0) then
            Values.Add(Code);
        end;
    if Values.Count = 0 then
    begin
      Raw := JStr(Game, 'rom.romregions');
      for Token in Raw.Split([',']) do
        if (Token.Trim <> '') and (Values.IndexOf(Token.Trim) < 0) then
          Values.Add(Token.Trim.ToLower);
    end;
    if Values.Count > 1 then
    begin
      if Values.IndexOf('wor') >= 0 then
        Values.Delete(Values.IndexOf('wor'));
    end;
    for Token in JoinValues(Config, 'Miscellaneous.Regions', 'us,wor,eu,jp').Split([',']) do
      if (Values.IndexOf(Token) >= 0) and (Ordered.IndexOf(Token) < 0) then
        Ordered.Add(Token);
    for Token in Values do
      if Ordered.IndexOf(Token) < 0 then
        Ordered.Add(Token);
    Result := string.Join(',', Ordered.ToStringArray);
  finally
    Ordered.Free;
    Values.Free
  end;
end;

function RegionPriority(Game, Config: TJSONObject; const FileName: string): string;
var
  RomRegions: string;
begin
  Result := JoinValues(Config, 'Miscellaneous.Regions', 'us,wor,eu,jp');
  if JBool(Config, 'Miscellaneous.RomRegionFirst') then
  begin
    RomRegions := OrderedRomRegions(Game, Config, FileName);
    if RomRegions <> '' then
      Result := RomRegions + ',' + Result;
  end;
end;

function SelectMedia(Entries: TJSONValue; const MediaType, ParentType, ParentID, Priority, Classification: string; Support: Integer; AStrict: Boolean): TJSONValue;
var
  Region, Regions: string;
  Pass: Integer;

  function Find(const R: string; FilterSupport: Boolean): TJSONValue;
  var
    K: string;
    M: TJSONValue;
    Types: TArray<string>;
    N, Ordinal: Integer;
  begin
    Result := nil;
    Ordinal := 0;
    if MediaType = 'wheel' then
      Types := TArray<string>.Create('wheel-hd', 'wheel')
    else
      Types := TArray<string>.Create(MediaType);
    for K in Types do
      for M in TJSONArray(Entries) do
      begin
        if not SameText(JStr(M, 'type'), K) or SameText(JStr(M, 'format'), 'svg') then
          Continue;
        if (ParentType <> 'system') and not SameText(JStr(M, 'parent', 'jeu'), ParentType) then
          Continue;
        if ParentType = 'genre' then
        begin
          Inc(Ordinal);
          if (ParentID <> '') and (Ordinal <> StrToIntDef(ParentID, 1)) then
            Continue;
        end
        else if (ParentID <> '') and (JStr(M, 'id') <> ParentID) then
          Continue;
        if (ParentType = 'classification') and not SameText(JStr(M, 'subparent'), Classification) then
          Continue;
        N := JInt(M, 'support');
        if N <= 1 then
          N := 1;
        if FilterSupport and (N <> Support) then
          Continue;
        if (R <> '*') and not SameText(JStr(M, 'region'), R) then
          Continue;
        Exit(M);
      end;
  end;

begin
  Result := nil;
  if not (Entries is TJSONArray) then
    Exit;
  Regions := Priority;
  if not AStrict then
    Regions := Regions + ',wor,*';
  // Direct logos and genre pictograms have no regional variant.
  if MatchText(ParentType, ['genre', 'editeur', 'developpeur']) then
    Regions := '*';
  for Pass := 0 to 1 do
  begin
    if (Pass = 0) and ((MediaType <> 'support-2D') or (Support <= 0)) then
      Continue;
    for Region in Regions.Split([',']) do
    begin
      Result := Find(Region, (Pass = 0));
      if Result <> nil then
        Exit;
    end;
  end;
end;

function MediaNode(Configs: TJSONArray; Index: Integer): string;
var
  I, K, N: Integer;
  Key: string;
  Used: TStringList;
begin
  Result := '';
  Used := TStringList.Create;
  try
    for I := 0 to Min(Index, Configs.Count - 1) do
    begin
      if not JBool(Configs.Items[I], 'LinkToNode', True) then
        Continue;
      K := JInt(Configs.Items[I], 'Type');
      Key := '';
      case K of
        0:
          begin
            N := JInt(Configs.Items[I], 'Image');
            if N = 14 then
              Key := 'marquee'
            else if N in [3, 6] then
              Key := 'box'
            else if N in [10, 11, 12, 13, 15] then
              Key := 'logo'
            else
              Key := 'image';
          end;
        1, 2:
          Key := 'image';
        3, 4:
          Key := 'video';
        5:
          Key := 'manual';
        6:
          Key := 'tips';
        7:
          Key := 'p2k';
        8:
          Key := 'maps';
      end;
      if (K = 0) and (Key <> 'image') and (Used.IndexOf(Key) >= 0) then
        Key := 'image';
      if (Key = 'image') and (Used.IndexOf(Key) >= 0) then
        Key := 'thumbnail';
      if (Key = '') or (Used.IndexOf(Key) >= 0) then
        Continue;
      Used.Add(Key);
      if I = Index then
        Result := Key;
    end;
  finally
    Used.Free
  end;
end;

function TipsContent(Game, Config: TJSONObject): string;
var
  A: TJSONValue;
  V: TJSONValue;
  Priorities, Lang: string;
  Used: TList<TJSONValue>;
  N: Integer;
begin
  Result := '';
  A := JValue(Game, 'tips');
  if not (A is TJSONArray) then
    Exit;
  Used := TList<TJSONValue>.Create;
  try
    Priorities := JoinValues(Config, 'Miscellaneous.Languages', 'en') + ',en,*';
    for Lang in Priorities.Split([',']) do
      for V in TJSONArray(A) do
        if ((Lang = '*') or SameText(JStr(V, 'langue'), Lang)) and not Used.Contains(V) then
        begin
          N := Used.Count;
          Used.Add(V);
          Result := Result + '[' + N.ToString + ']' + sLineBreak + 'language=' + JStr(V, 'langue') + sLineBreak +
            'title=' + JStr(V, 'titre') + sLineBreak + 'text=' + JStr(V, 'description') + sLineBreak;
        end;
  finally
    Used.Free
  end;
end;

function MoveNameArticle(const Name, Region: string): string;
var
  Articles, A, Prefix: string;
begin
  Articles := '';
  if MatchText(Region, ['fr', 'ca', 'ch', 'be']) then
    Articles := 'le|la|les|des|l''|un|une|';
  if MatchText(Region, ['it', 'ch']) then
    Articles := Articles + 'un|uno|un''|una|il|l''|lo|la|i|gli|le|';
  if MatchText(Region, ['de', 'ch']) then
    Articles := Articles + 'die|der|das|den|dem|des|ein|eine|einer|eines|einen|einem|';
  if MatchText(Region, ['sp', 'es', 'mx', 'cl', 'ar']) then
    Articles := 'el|la|los|las|un|una|unas|unos|';
  if MatchText(Region, ['pt', 'br']) then
    Articles := 'o|a|os|as|um|uma|uns|umas|';
  if MatchText(Region, ['nl', 'be']) then
    Articles := Articles + 'de|het|een|geen|';
  Articles := Articles + 'a|an|the';
  Result := Name;
  for A in Articles.Split(['|']) do
  begin
    Prefix := A;
    if not A.EndsWith(string(#39)) then
      Prefix := A + ' ';
    if Name.StartsWith(Prefix, True) and (Length(Name) > Length(Prefix)) then
      Exit(Name.Substring(Length(Prefix)) + ', ' + Name.Substring(0, Length(A)));
  end;
end;

function LookupGenre(ID: Integer; const Mappings: array of TGenreMapping): Integer;
var
  L, H, M: Integer;
begin
  L := Low(Mappings);
  H := High(Mappings);
  while L <= H do
  begin
    M := L + (H - L) div 2;
    if Mappings[M].SourceID = ID then
      Exit(Mappings[M].TargetID);
    if Mappings[M].SourceID < ID then
      L := M + 1
    else
      H := M - 1;
  end;
  Result := -1;
end;

function SubGenresMap(ID: Integer): Integer;
begin
  Result := LookupGenre(ID, SubGenreMappings);
end;

function GenresMap(ID: Integer): Integer;
begin
  Result := LookupGenre(ID, GenreMappings);
end;

function NormalizedGenre(Game: TJSONObject): string;
var
  A, V: TJSONValue;
  ID, N, Pass: Integer;
begin
  Result := '';
  A := JValue(Game, 'genres');
  if not (A is TJSONArray) then
    Exit;
  for V in TJSONArray(A) do
  begin
    N := SubGenresMap(JInt(V, 'id'));
    if N >= 0 then
      Exit(N.ToString)
  end;
  for Pass := 0 to 1 do
    for V in TJSONArray(A) do
    begin
      ID := JInt(V, 'id');
      if (ID = 413) or ((Pass = 0) and (ID = 10)) then
        Continue;
      N := GenresMap(ID);
      if N < 0 then
        N := GenresMap(JInt(V, 'parentid'));
      if N >= 0 then
        Exit(N.ToString);
    end;
end;

function GameFromRomFileName(Game, Config: TJSONObject; const FileName: string): TJSONObject;
var
  Base, Name, Tag, Token, Flag, Regions, Publisher: string;
  M, DateMatch, DiscMatch: TMatch;
  Year, Month, Day, Disc, Total: Integer;
  Date: TDateTime;
  Recognized, IsRegion, PublisherNext: Boolean;
begin
  if Game = nil then
    Result := TJSONObject.Create
  else
    Result := Game.Clone as TJSONObject;
  try
    Base := TPath.GetFileNameWithoutExtension(FileName);
    Name := Base;
    PublisherNext := False;
    Regions := OrderedRomRegions(Game, Config, FileName);
    if Regions <> '' then
      JSet(Result, 'rom.romregions', TJSONString.Create(Regions));
    for M in TRegEx.Matches(Base, '[\(\[]([^\)\]]*)[\)\]]') do
    begin
      Tag := M.Groups[1].Value.Trim;
      Recognized := False;
      IsRegion := False;
      for Token in Tag.Split([',', ';']) do
        IsRegion := IsRegion or (RegionCode(Token.Trim) <> '');
      DateMatch := TRegEx.Match(Tag, '^(19\d{2}|20\d{2})(?:-(\d{2})(?:-(\d{2}))?)?$');
      DiscMatch := TRegEx.Match(Tag, '^(?:disc|disk|cd|tape|side)\s*(\d+)(?:\s*(?:of|/)\s*(\d+))?$', [roIgnoreCase]);
      Flag := '';
      if TRegEx.IsMatch(Tag, '^beta(?:\s.*)?$', [roIgnoreCase]) then
        Flag := 'beta'
      else if TRegEx.IsMatch(Tag, '^demo(?:\s.*)?$', [roIgnoreCase]) then
        Flag := 'demo'
      else if TRegEx.IsMatch(Tag, '^(?:proto|prototype)(?:\s.*)?$', [roIgnoreCase]) then
        Flag := 'proto'
      else if TRegEx.IsMatch(Tag, '^(?:hack|h\d*)(?:\s.*)?$', [roIgnoreCase]) then
        Flag := 'hack'
      else if TRegEx.IsMatch(Tag, '^(?:alt|alternate|a\d*)\.?(?:\s.*)?$', [roIgnoreCase]) then
        Flag := 'alt'
      else if TRegEx.IsMatch(Tag, '^(?:unl|unlicensed)\.?$', [roIgnoreCase]) then
        Flag := 'unl'
      else if TRegEx.IsMatch(Tag, '^(?:trans|translation|translated)\.?(?:\s.*)?$|^t[+-].*$', [roIgnoreCase]) then
        Flag := 'trad'
      else if Tag = '!' then
        Flag := 'best';
      if IsRegion then
        Recognized := True
      else if DateMatch.Success then
      begin
        Year := StrToInt(DateMatch.Groups[1].Value);
        Month := 1;
        Day := 1;
        if DateMatch.Groups.Count > 2 then
          Month := StrToIntDef(DateMatch.Groups[2].Value, 1);
        if DateMatch.Groups.Count > 3 then
          Day := StrToIntDef(DateMatch.Groups[3].Value, 1);
        if TryEncodeDate(Year, Month, Day, Date) then
        begin
          if PickText(Result, 'dates', 'region', '*') = '' then
            JSet(Result, 'dates', TJSONArray.Create.Add(TJSONObject.Create.AddPair('region', 'wor').
                AddPair('text', FormatDateTime('yyyymmdd', Date))));
          Recognized := True;
        end;
      end
      else if DiscMatch.Success then
      begin
        Disc := StrToIntDef(DiscMatch.Groups[1].Value, 0);
        Total := Max(2, Disc);
        if DiscMatch.Groups.Count > 2 then
          Total := StrToIntDef(DiscMatch.Groups[2].Value, Total);
        if (Disc > 0) and (Total >= Disc) then
        begin
          if JInt(Result, 'rom.romnumsupport') = 0 then
            JSet(Result, 'rom.romnumsupport', TJSONNumber.Create(Disc));
          if JInt(Result, 'rom.romtotalsupport') = 0 then
            JSet(Result, 'rom.romtotalsupport', TJSONNumber.Create(Total));
          Recognized := True;
        end;
      end
      else if Flag <> '' then
      begin
        JSet(Result, 'rom.' + Flag, TJSONNumber.Create(1));
        Recognized := True;
      end
      else if TRegEx.IsMatch(Tag, '^(?:rev(?:ision)?|v(?:ersion)?)\.?\s*[\d].*$', [roIgnoreCase]) or
        TRegEx.IsMatch(Tag, '^(?:en|ja|fr|de|es|it|pt|ru|zh|ko|nl|sv|no|da|fi|pl)(?:,\s*(?:en|ja|fr|de|es|it|pt|ru|zh|ko|nl|sv|no|da|fi|pl))*$', [roIgnoreCase]) or
        TRegEx.IsMatch(Tag, '^[bofp]\d*$', [roIgnoreCase]) then
        Recognized := True
      else if PublisherNext and (M.Value[1] = '(') then
      begin
        // TOSEC places a publisher directly after the year: Title (1990)(Publisher).
        Publisher := Tag;
        if (Publisher <> '') and (Publisher <> '-') and (JStr(Result, 'editeur.text') = '') then
          JSet(Result, 'editeur.text', TJSONString.Create(Publisher));
        Recognized := True;
      end;
      PublisherNext := DateMatch.Success and Recognized;
      if Recognized then
        Name := Name.Replace(M.Value, '');
    end;
    Name := TRegEx.Replace(Name.Replace('_', ' '), '\s+', ' ').Trim;
    if Name = '' then
      Name := Base;
    JSet(Result, 'noms', TJSONArray.Create.Add(TJSONObject.Create.AddPair('region', 'wor').AddPair('text', Name)));
  except
    Result.Free;
    raise;
  end;
end;

function DescribeGameMetadata(Game, Config: TJSONObject; const FileName: string; Unscraped, FileNameMetadata: Boolean): TJSONObject;
const
  Decorations: array[0..10] of string = ('Beta', 'Demo', 'Alt.', 'Best', 'Clone', 'Hack', 'Trans.', 'Unl.', 'Proto.', 'Disc', 'Clone type');
var
  Name, Langs, Regions, Text, Base, Genre, RegionList, SelectedRegion, Suffix: string;
  Rom, A, V: TJSONValue;
  Mask, I, Decor: Integer;
  NameMatch: TMatch;
  Hidden, Excluded, Favorite, LStrict: Boolean;
  Rating: Double;

  procedure SetText(const Key, Value: string);
  begin
    JSet(Result, Key, TJSONString.Create(Value));
  end;

  function WordsMatch(const Path: string): Boolean;
  var
    Arr, W: TJSONValue;
  begin
    Result := False;
    Arr := JValue(Config, Path);
    if Arr is TJSONArray then
      for W in TJSONArray(Arr) do
        if (W.Value.Trim <> '') and MatchNameExpression(Name, W.Value.Trim) then
          Exit(True);
  end;

  function RegionMatch(const Path: string): Boolean;
  var
    Arr, W: TJSONValue;
  begin
    Result := False;
    Arr := JValue(Config, Path);
    if Arr is TJSONArray then
      for W in TJSONArray(Arr) do
        if (',' + RegionList.ToLower + ',').Contains(',' + W.Value.ToLower + ',') then
          Exit(True);
  end;

  function ApplyCase(const Value, Path: string): string;
  begin
    case JInt(Config, Path) of
      1:
        Result := Value.ToUpper;
      2:
        Result := Value.ToLower;
    else
      Result := Value;
    end;
  end;

begin
  Result := TJSONObject.Create;
  Langs := JoinValues(Config, 'Miscellaneous.Languages', 'en');
  LStrict := JBool(Config, 'Miscellaneous.StrictRegionList');
  Rom := JValue(Game, 'rom');
  RegionList := OrderedRomRegions(Game, Config, FileName);
  Regions := RegionPriority(Game, Config, FileName);
  if FileNameMetadata then
    Name := PickText(Game, 'noms', 'region', 'wor')
  else
    Name := PickText(Game, 'noms', 'region', Regions, LStrict);
  SelectedRegion := '';
  Text := Regions;
  if not LStrict then
    Text := Text + ',wor,*';
  if JValue(Game, 'noms') is TJSONArray then
    for Suffix in Text.Split([',']) do
    begin
      for V in TJSONArray(JValue(Game, 'noms')) do
        if (Suffix = '*') or SameText(JStr(V, 'region'), Suffix) then
        begin
          SelectedRegion := JStr(V, 'region');
          Break
        end;
      if SelectedRegion <> '' then
        Break;
    end;
  Base := TPath.GetFileNameWithoutExtension(FileName);
  if (Name = '') or JBool(Config, 'MetaData.KeepUndecoratedFileName') then
    Name := TRegEx.Replace(Base, '\s*[\(\[].*?[\)\]]', '').Trim;
  if JBool(Config, 'MetaData.MoveArticles') then
    Name := MoveNameArticle(Name, SelectedRegion);
  Name := ApplyCase(Name.Trim, 'MetaData.NameCase');
  Mask := 0;
  for I := 0 to 8 do
    if JInt(Rom, RomFlags[I]) <> 0 then
      Mask := Mask or RomFlagBits[I];
  // Auto-filter additional discs, while decorating every disc of a multi-disc set.
  if JInt(Rom, 'romnumsupport') > 1 then
    Mask := Mask or 1024;
  A := JValue(Rom, 'clonetypes.clonetypes_fr');
  if (A is TJSONArray) and (TJSONArray(A).Count > 0) then
    Mask := Mask or 2048;
  Decor := Mask;
  if (JInt(Rom, 'romnumsupport') > 0) and (JInt(Rom, 'romtotalsupport') > 1) then
    Decor := Decor or 1024
  else
    Decor := Decor and not 1024;
  if RegionList <> '' then
    Decor := Decor or 1;
  Decor := Decor and JInt(Config, 'MetaData.NameDecorations');
  Suffix := '';
  if JBool(Config, 'MetaData.KeepFileNameDecorations') then
  begin
    for NameMatch in TRegEx.Matches(Base, '[\(\[].*?[\)\]]') do
      Suffix := Suffix + NameMatch.Value + ' ';
    Suffix := Suffix.Trim;
  end
  else
  begin
    if (Decor and 2048 <> 0) and (A is TJSONArray) then
      Suffix := '(' + TJSONArray(A).Items[0].Value + ')';
    if Decor and 1 <> 0 then
      Suffix := Suffix + '[' + RegionList.ToUpper + ']';
    for I in TArray<Integer>.Create(4, 1, 0, 6, 2, 8, 5, 7, 3) do
      if Decor and RomFlagBits[I] <> 0 then
        Suffix := Suffix + '(' + Decorations[I] + ')';
    if Decor and 1024 <> 0 then
      Suffix := Suffix + '(#' + JStr(Rom, 'romnumsupport') + ')';
  end;
  if Suffix <> '' then
    Name := Name + ' ' + Suffix;
  Rating := StrToFloatDef(JStr(Game, 'note.text'), 0, TFormatSettings.Invariant) / 20;
  Hidden := Unscraped and JBool(Config, 'GameList.AutoHideUnscraped');
  Excluded := Unscraped and JBool(Config, 'GameList.AutoExcludeUnscraped');
  Hidden := Hidden or ((Mask and JInt(Config, 'GameList.AutoHideSelection')) <> 0);
  Excluded := Excluded or ((Mask and JInt(Config, 'GameList.AutoExcludeSelection')) <> 0);
  if (Rom <> nil) and (not Unscraped or (RegionList <> '')) and (JInt(Config, 'GameList.AutoHideSelection') and 1 <> 0) then
    Hidden := Hidden or not RegionMatch('GameList.AutoHideRegions');
  if (Rom <> nil) and (not Unscraped or (RegionList <> '')) and (JInt(Config, 'GameList.AutoExcludeSelection') and 1 <> 0) then
    Excluded := Excluded or not RegionMatch('GameList.AutoExcludeRegions');
  if JBool(Config, 'GameList.AutoHideWords') then
    Hidden := Hidden or WordsMatch('GameList.AutoHideWordList');
  if JBool(Config, 'GameList.AutoExcludeWords') then
    Excluded := Excluded or WordsMatch('GameList.AutoExcludeWordList');
  if JBool(Config, 'GameList.AutoHideExtension') then
    if JValue(Config, 'GameList.AutoHideExtensions') is TJSONArray then
      for V in TJSONArray(JValue(Config, 'GameList.AutoHideExtensions')) do
        Hidden := Hidden or FileName.EndsWith('.' + V.Value.TrimLeft(['.']), True);
  Favorite := JBool(Config, 'GameList.AutoFavoriteRating') and (Rating * 100 > JInt(Config, 'GameList.AutoFavoriteRatingPercent', 90));
  if JBool(Config, 'GameList.AutoFavoriteWords') then
    Favorite := Favorite or WordsMatch('GameList.AutoFavoriteWordList');
  if JBool(Config, 'GameList.AutoFavoriteTopStaff') then
    Favorite := Favorite or (JInt(Game, 'topstaff') > 0);
  if Excluded then
  begin
    Hidden := False;
    Favorite := False;
  end
  else if Hidden then
  begin
    Favorite := False;
    Name := Base;
  end;
  SetText('name', Name);
  if JBool(Config, 'MetaData.NoSynopsis') then
    SetText('desc', '')
  else
    SetText('desc', ApplyCase(PickText(Game, 'synopsis', 'langue', Langs, LStrict), 'MetaData.DescriptionCase'));
  SetText('developer', JStr(Game, 'developpeur.text'));
  SetText('publisher', JStr(Game, 'editeur.text'));
  SetText('players', JStr(Game, 'joueurs.text'));
  SetText('rating', FloatToStr(Rating, TFormatSettings.Invariant));
  Text := PickText(Game, 'dates', 'region', Regions, LStrict).Replace('-', '');
  if FileNameMetadata and (Text = '') then
    Text := PickText(Game, 'dates', 'region', 'wor').Replace('-', '');
  if Length(Text) = 6 then
    Text := Text + '01';
  if Length(Text) = 4 then
    Text := Text + '0101';
  if Length(Text) = 8 then
    Text := Text + 'T000000';
  SetText('releasedate', Text);
  Genre := '';
  A := JValue(Game, 'genres');
  if A is TJSONArray then
    for V in TJSONArray(A) do
    begin
      Text := PickText(V, 'noms', 'langue', Langs, LStrict);
      if Text <> '' then
      begin
        if Genre <> '' then
          Genre := Genre + ', ';
        Genre := Genre + Text;
      end;
    end;
  SetText('classification', PickText(Game, 'classifications', 'type', JStr(Config, 'Miscellaneous.Classification', 'PEGI'), True));
  SetText('genreid', NormalizedGenre(Game));
  SetText('genre', ApplyCase(Genre, 'MetaData.GenreCase'));
  SetText('region', RegionList);
  SetText('id', JStr(Game, 'id'));
  SetText('path', FileName);
  SetText('filename', TPath.GetFileName(FileName));
  JSet(Result, 'favorite', TJSONBool.Create(Favorite));
  JSet(Result, 'hidden', TJSONBool.Create(Hidden));
  JSet(Result, 'exclude', TJSONBool.Create(Excluded));
end;

function DescribeGame(Game, Config: TJSONObject; const FileName: string): TJSONObject;
var
  ParsedGame: TJSONObject;
begin
  if not UseRomFileNameMetadata(Game, Config) then
    Exit(DescribeGameMetadata(Game, Config, FileName, Game = nil, False));
  ParsedGame := GameFromRomFileName(Game, Config, FileName);
  try
    Result := DescribeGameMetadata(ParsedGame, Config, FileName, Game = nil, True);
  finally
    ParsedGame.Free;
  end;
end;

function ChildText(Node: IXMLNode; const Name: string): string;
var
  C: IXMLNode;
begin
  C := Node.ChildNodes.FindNode(Name);
  if C = nil then
    Result := ''
  else
    Result := C.Text;
end;

procedure Put(Node: IXMLNode; const Name, Value: string);
var
  C: IXMLNode;
begin
  C := Node.ChildNodes.FindNode(Name);
  if C = nil then
    C := Node.AddChild(Name);
  C.Text := Value;
end;

constructor TGameListWriter.Create(Config: TJSONObject);
var
  I: Integer;
  K: string;
  Bytes: TBytes;
  Zip: TZipFile;
begin
  inherited Create;
  FIndex := TDictionary<string, IXMLNode>.Create;
  FFolderSources := TObjectDictionary<string, TStringList>.Create([doOwnsValues]);
  FSystemID := JInt(Config, 'SystemId');
  FFolderMode := JInt(Config, 'GameList.Folders');
  FRomRoot := JStr(Config, 'GamesAndRoms.Path');
  FPlatform := JStr(Config, 'GamesAndRoms.Platform', TPath.GetFileName(FRomRoot));
  FKind := JInt(Config, 'GameList.Type', 1);
  FBehavior := JInt(Config, 'GameList.Behavior');
  FPreserveHeader := JBool(Config, 'GameList.PreserveHeader');
  FOptimize := JBool(Config, 'GameList.Optimize');
  FPreserveMissingMedia := JBool(Config, 'GameList.PreserveMissingMedia');
  FFile := ResolveOutput(JStr(Config, 'GameList.OutputFile', 'gamelist.xml'), FRomRoot, FRomRoot);
  FDoc := TXMLDocument.Create(nil);
  FDoc.Active := True;
  FDoc.Encoding := 'utf-8';
  if (FBehavior in [2, 3]) and TFile.Exists(FFile) then
    if FFile.EndsWith('.zip', True) then
    begin
      Zip := TZipFile.Create;
      try
        Zip.Open(FFile, zmRead);
        if Zip.FileCount > 0 then
        begin
          Zip.Read(0, Bytes);
          FDoc.LoadFromXML(TEncoding.UTF8.GetString(Bytes));
        end;
      finally
        Zip.Free;
      end;
    end
    else
      FDoc.LoadFromFile(FFile);
  FRoot := FDoc.DocumentElement;
  case FKind of
    2:
      K := 'LaunchBox';
    3:
      K := 'datafile';
  else
    K := 'gameList';
  end;
  if FRoot = nil then
    FRoot := FDoc.AddChild(K)
  else if FRoot.NodeName <> K then
    raise Exception.Create('Existing gamelist format does not match selected format.');
  for I := 0 to FRoot.ChildNodes.Count - 1 do
  begin
    K := NodeKey(FRoot.ChildNodes[I]);
    if K <> '' then
      FIndex.AddOrSetValue(NormalizeKey(K), FRoot.ChildNodes[I]);
  end;
end;

destructor TGameListWriter.Destroy;
begin
  FFolderSources.Free;
  FIndex.Free;
  inherited;
end;

function TGameListWriter.NormalizeKey(const Value: string): string;
begin
  Result := NativePath(Value);
  if Result = '' then
    Exit;
  if not TPath.IsPathRooted(Result) then
    Result := TPlatformPath.Combine(FRomRoot, Result);
  Result := PathKey(Result);
end;

function TGameListWriter.NodeKey(Node: IXMLNode): string;
var
  R: IXMLNode;
begin
  case FKind of
    2:
      if Node.NodeName = 'Game' then
        Result := ChildText(Node, 'ApplicationPath')
      else
        Result := '';
    3:
      begin
        R := Node.ChildNodes.FindNode('rom');
        if (R <> nil) and R.HasAttribute('name') then
          Result := R.Attributes['name']
        else
          Result := '';
      end;
  else
    Result := ChildText(Node, 'path');
  end;
end;

procedure TGameListWriter.Add(Item: TJSONObject);
var
  Node, R, MapNode, Additional: IXMLNode;
  Map: TJSONValue;
  Key, Field, Value: string;
  Pair: TJSONPair;
  Dir, Image: string;
  Images: TStringList;
  NodeIndex: Integer;
  OldFavorite, OldHidden, HasAdditional: Boolean;
begin
  if FKind = 0 then
    Exit;
  Key := JStr(Item, 'path');
  if FKind <> 2 then
    Key := './' + ExtractRelativePath(IncludeTrailingPathDelimiter(FRomRoot), Key).Replace('\', '/');
  if JBool(Item, 'exclude') then
    Exit;
  if (FKind = 1) and (FFolderMode > 0) then
  begin
    Dir := ExtractFileDir(JStr(Item, 'path'));
    Image := JStr(Item, 'image', JStr(Item, 'thumbnail', JStr(Item, 'box')));
    if (Image <> '') and not TPath.IsPathRooted(Image) then
      Image := TPath.GetFullPath(TPlatformPath.Combine(FRomRoot, NativePath(Image)));
    while not SamePath(Dir, FRomRoot) and IsPathWithin(Dir, FRomRoot) do
    begin
      if not FFolderSources.TryGetValue(Dir, Images) then
      begin
        Images := TStringList.Create;
        FFolderSources.Add(Dir, Images);
      end;
      if (Image <> '') and (Images.IndexOf(Image) < 0) then
        Images.Add(Image);
      Dir := ExtractFileDir(Dir);
    end;
  end;
  if not FIndex.TryGetValue(NormalizeKey(Key), Node) then
  begin
    if FKind = 2 then
      Node := FRoot.AddChild('Game')
    else
      Node := FRoot.AddChild('game');
    FIndex.Add(NormalizeKey(Key), Node);
  end;
  OldFavorite := SameText(ChildText(Node, 'favorite'), 'true') or SameText(ChildText(Node, 'Favorite'), 'true');
  OldHidden := SameText(ChildText(Node, 'hidden'), 'true') or SameText(ChildText(Node, 'Hide'), 'true');
  if FKind = 1 then
    for Field in ['image', 'thumbnail', 'box', 'logo', 'marquee', 'video', 'manual', 'maps', 'map', 'tips', 'p2k'] do
    begin
      R := Node.ChildNodes.FindNode(Field);
      if (R <> nil) and (not FPreserveMissingMedia or (JValue(Item, Field) <> nil)) then
        Node.ChildNodes.Remove(R);
    end;
  if FKind = 3 then
  begin
    Node.Attributes['name'] := JStr(Item, 'name');
    Put(Node, 'description', JStr(Item, 'desc'));
    Put(Node, 'manufacturer', JStr(Item, 'publisher'));
    Put(Node, 'year', Copy(JStr(Item, 'releasedate'), 1, 4));
    R := Node.ChildNodes.FindNode('rom');
    if R = nil then
      R := Node.AddChild('rom');
    R.Attributes['name'] := Key;
    R.Attributes['size'] := JStr(Item, 'size', '0');
    for Field in ['crc', 'md5', 'sha1'] do
      if JStr(Item, Field) <> '' then
        R.Attributes[Field] := JStr(Item, Field).ToLower;
    Exit;
  end;
  if FKind = 2 then
  begin
    Put(Node, 'ApplicationPath', Key);
    Put(Node, 'Title', JStr(Item, 'name'));
    Put(Node, 'Notes', JStr(Item, 'desc'));
    Put(Node, 'Developer', JStr(Item, 'developer'));
    Put(Node, 'Publisher', JStr(Item, 'publisher'));
    Put(Node, 'Genre', JStr(Item, 'genre'));
    Put(Node, 'Favorite', LowerCase(BoolToStr(OldFavorite or JBool(Item, 'favorite'), True)));
    Put(Node, 'Hide', LowerCase(BoolToStr(OldHidden or JBool(Item, 'hidden'), True)));
    Put(Node, 'Platform', FPlatform);
    Put(Node, 'Region', JStr(Item, 'region'));
    if not FPreserveMissingMedia or (JValue(Item, 'video') <> nil) then
      Put(Node, 'VideoPath', JStr(Item, 'video'));
    if not FPreserveMissingMedia or (JValue(Item, 'manual') <> nil) then
      Put(Node, 'ManualPath', JStr(Item, 'manual'));
    if ChildText(Node, 'ID') = '' then
      Put(Node, 'ID', TGUID.NewGuid.ToString.Trim(['{', '}']));
    if ChildText(Node, 'DateAdded') = '' then
      Put(Node, 'DateAdded', DateToISO8601(Now, False));
    Put(Node, 'DateModified', DateToISO8601(Now, False));
    Put(Node, 'Source', 'ScreenScraper.fr');
    Put(Node, 'UseDosBox', LowerCase(BoolToStr(FSystemID = SystemIDDOS, True)));
    Put(Node, 'UseScummVM', LowerCase(BoolToStr(FSystemID = SystemIDScummVM, True)));
    HasAdditional := False;
    for NodeIndex := 0 to FRoot.ChildNodes.Count - 1 do
    begin
      Additional := FRoot.ChildNodes[NodeIndex];
      if (Additional.NodeName = 'AdditionalApplication') and (ChildText(Additional, 'GameID') = ChildText(Node, 'ID')) and
        SamePath(ChildText(Additional, 'ApplicationPath'), Key) then
      begin
        HasAdditional := True;
        Break
      end;
    end;
    if not HasAdditional then
    begin
      Additional := FRoot.AddChild('AdditionalApplication');
      Put(Additional, 'ApplicationPath', Key);
      Put(Additional, 'GameID', ChildText(Node, 'ID'));
      Put(Additional, 'Id', TGUID.NewGuid.ToString.Trim(['{', '}']));
      Put(Additional, 'Name', JStr(Item, 'name'));
      Put(Additional, 'UseDosBox', LowerCase(BoolToStr(FSystemID = SystemIDDOS, True)));
      for Field in ['AutoRunAfter', 'AutoRunBefore', 'UseEmulator', 'WaitForExit', 'SideA', 'SideB'] do
        Put(Additional, Field, 'false');
      Put(Additional, 'PlayCount', '0');
      Put(Additional, 'Priority', '0');
    end;
    Put(Node, 'StarRatingFloat', FloatToStr(StrToFloatDef(JStr(Item, 'rating'), 0, TFormatSettings.Invariant) * 5, TFormatSettings.Invariant));
    Value := JStr(Item, 'releasedate');
    if Length(Value) >= 8 then
      Put(Node, 'ReleaseDate', Copy(Value, 1, 4) + '-' + Copy(Value, 5, 2) + '-' + Copy(Value, 7, 2) + 'T00:00:00');
    Exit;
  end;
  for Pair in Item do
  begin
    Field := Pair.JsonString.Value;
    if (Field = 'maps') and (Pair.JsonValue is TJSONArray) then
    begin
      R := Node.ChildNodes.FindNode('maps');
      if R = nil then
        R := Node.AddChild('maps');
      R.ChildNodes.Clear;
      for Map in TJSONArray(Pair.JsonValue) do
      begin
        MapNode := R.AddChild('map');
        Value := JStr(Map, 'path');
        if TPath.IsPathRooted(Value) then
          Value := './' + ExtractRelativePath(IncludeTrailingPathDelimiter(FRomRoot), Value).Replace('\', '/');
        MapNode.Attributes['path'] := Value;
        MapNode.Attributes['title'] := JStr(Map, 'title');
      end;
      Continue;
    end;
    Value := Pair.JsonValue.Value;
    if Field = 'favorite' then
      Value := LowerCase(BoolToStr(OldFavorite or JBool(Item, Field), True));
    if Field = 'hidden' then
      Value := LowerCase(BoolToStr(OldHidden or JBool(Item, Field), True));
    if MatchText(Field, ['exclude', 'filename', 'size', 'crc', 'md5', 'sha1', 'id']) then
      Continue;
    if Field = 'path' then
      Value := Key
    else if MatchText(Field, ['image', 'thumbnail', 'marquee', 'box', 'logo', 'video', 'manual', 'map', 'tips', 'p2k']) and TPath.IsPathRooted(Value) then
      Value := './' + ExtractRelativePath(IncludeTrailingPathDelimiter(FRomRoot), Value).Replace('\', '/');
    Put(Node, Field, Value);
  end;
  if JStr(Item, 'crc') <> '' then
    Put(Node, 'hash', JStr(Item, 'crc'));
  if JStr(Item, 'md5') <> '' then
    Put(Node, 'md5', JStr(Item, 'md5'));
  if JStr(Item, 'id') <> '' then
  begin
    Node.Attributes['id'] := JStr(Item, 'id');
    Node.Attributes['source'] := 'ScreenScraper.fr';
  end;
end;

function TGameListWriter.PrepareFolders(Cancel: TFunc<Boolean>): TArray<string>;
var
  Pair: TPair<string, TStringList>;
  Node: IXMLNode;
  Key, ImageFile: string;
  Output, Input: TBitmap;
  Pixels: TBitmapData;
  X, Y: Integer;
  Color: TAlphaColor;
  I, Count, Cols, Rows: Integer;
  R: TRectF;
  W, H, Scale: Single;
  Files: TList<string>;
begin
  Files := TList<string>.Create;
  try
    for Pair in FFolderSources do
    begin
      if Assigned(Cancel) and Cancel() then
        raise EAbort.Create('Cancelled');
      Key := './' + ExtractRelativePath(IncludeTrailingPathDelimiter(FRomRoot), Pair.Key).Replace('\', '/');
      if not FIndex.TryGetValue(NormalizeKey(Key), Node) then
      begin
        Node := FRoot.AddChild('folder');
        FIndex.Add(NormalizeKey(Key), Node);
      end;
      Put(Node, 'path', Key);
      Put(Node, 'name', ExtractFileName(Pair.Key));
      ImageFile := TPlatformPath.Combine(FRomRoot, NativePath('media\folders\') + THashSHA2.GetHashString(Key) + '.png');
      ForceDirectories(ExtractFilePath(ImageFile));
      Output := TBitmap.Create(512, 384);
      Input := TBitmap.Create;
      try
        Output.Clear(0);
        if FFolderMode = 1 then
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
        if (FFolderMode <> 1) and Output.Canvas.BeginScene then
        try
          Output.Canvas.Fill.Color := $FF888888;
          Output.Canvas.FillRect(RectF(24, 64, 200, 112), 12, 12, AllCorners, 1);
          Output.Canvas.FillRect(RectF(24, 94, 488, 354), 16, 16, AllCorners, 1);
          Count := 0;
          if FFolderMode = 2 then
            Count := Min(1, Pair.Value.Count)
          else if FFolderMode = 3 then
            Count := Pair.Value.Count;
          Cols := Max(1, Ceil(Sqrt(Count)));
          Rows := Max(1, Ceil(Count / Cols));
          for I := 0 to Count - 1 do
          begin
            if not TFile.Exists(Pair.Value[I]) then
              Continue;
            Input.LoadFromFile(Pair.Value[I]);
            if Input.IsEmpty then
              Continue;
            W := 440 / Cols;
            H := 224 / Rows;
            Scale := Min(W / Input.Width, H / Input.Height);
            R := RectF(36 + (I mod Cols) * W, 108 + (I div Cols) * H, 36 + (I mod Cols) * W + Input.Width * Scale, 108 + (I div Cols) * H + Input.Height * Scale);
            Output.Canvas.DrawBitmap(Input, Input.BoundsF, R, 1, False);
          end;
          if Count = 0 then
          begin
            Output.Canvas.Fill.Color := $FFFFFFFF;
            Output.Canvas.Font.Size := 28;
            Output.Canvas.FillText(RectF(44, 130, 468, 325), ExtractFileName(Pair.Key), True, 1, [], TTextAlign.Center, TTextAlign.Center);
          end;
        finally
          Output.Canvas.EndScene;
        end;
        if Assigned(Cancel) and Cancel() then
          raise EAbort.Create('Cancelled');
        Output.SaveToFile(ImageFile);
        Files.Add(ImageFile);
      finally
        Input.Free;
        Output.Free;
      end;
      Put(Node, 'image', './' + ExtractRelativePath(IncludeTrailingPathDelimiter(FRomRoot), ImageFile).Replace('\', '/'));
    end;
    Result := Files.ToArray;
  finally
    Files.Free;
  end;
end;

procedure TGameListWriter.Save(Cancel: TFunc<Boolean>);
var
  Zip: TZipFile;
  Bytes: TBytes;
  Header: IXMLNode;
begin
  if FKind = 0 then
    Exit;
  if (FKind = 3) and not FPreserveHeader then
  begin
    Header := FRoot.ChildNodes.FindNode('header');
    if Header = nil then
      Header := FRoot.AddChild('header', 0);
    Put(Header, 'name', FPlatform);
    Put(Header, 'description', 'Information from ScreenScraper.fr database');
    Put(Header, 'author', AppBrand);
    Put(Header, 'version', '1.0');
    Put(Header, 'date', DateToISO8601(Now, False));
    Put(Header, 'url', ScreenScraperWebsite);
  end;
  if Assigned(Cancel) and Cancel() then
    raise EAbort.Create('Cancelled');
  ForceDirectories(ExtractFilePath(FFile));
  if not FOptimize then
    FDoc.Options := FDoc.Options + [doNodeAutoIndent];
  if FFile.EndsWith('.zip', True) then
  begin
    Zip := TZipFile.Create;
    try
      Zip.Open(FFile + '.tmp', zmWrite);
      Bytes := TEncoding.UTF8.GetBytes(FDoc.XML.Text);
      Zip.Add(Bytes, 'gamelist.xml');
    finally
      Zip.Free;
    end;
  end
  else
    FDoc.SaveToFile(FFile + '.tmp');
  if Assigned(Cancel) and Cancel() then
  begin
    TFile.Delete(FFile + '.tmp');
    raise EAbort.Create('Cancelled');
  end;
  if (FBehavior in [0, 2]) and TFile.Exists(FFile) then
    TFile.Copy(FFile, FFile + '.' + FormatDateTime('yyyymmdd-hhnnss-zzz', Now) + '.bak', False);
  if Assigned(Cancel) and Cancel() then
  begin
    TFile.Delete(FFile + '.tmp');
    raise EAbort.Create('Cancelled');
  end;
  CommitFile(FFile + '.tmp', FFile);
end;

end.

