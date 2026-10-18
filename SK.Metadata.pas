unit SK.Metadata;

interface

uses
  System.SysUtils, System.JSON;

function JoinValues(Obj: TJSONValue; const Path, Default: string): string;

function PickText(Obj: TJSONValue; const Path, Key, Priority: string; AStrict: Boolean = False): string;

function OrderedRomRegions(Game, Config: TJSONObject; const FileName: string): string;

function RegionPriority(Game, Config: TJSONObject; const FileName: string): string;

function SelectMedia(Entries: TJSONValue; const MediaType, ParentType, ParentID, Priority, Classification: string; Support: Integer; AStrict: Boolean): TJSONValue;

function MediaNode(Configs: TJSONArray; Index: Integer): string;

function TipsContent(Game, Config: TJSONObject): string;

function DescribeGame(Game, Config: TJSONObject; const FileName: string): TJSONObject;

implementation

uses
  System.IOUtils, System.Classes, System.Generics.Collections, System.StrUtils,
  System.RegularExpressions, System.NetEncoding, System.Math,
  SK.Json, SK.Consts, SK.Input;

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
    if JBool(Config, 'MetaData.ExtractRegionFromFileName') then
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

function DescribeGame(Game, Config: TJSONObject; const FileName: string): TJSONObject;
const
  Decorations: array[0..10] of string = ('Beta', 'Demo', 'Alt.', 'Best', 'Clone', 'Hack', 'Trans.', 'Unl.', 'Proto.', 'Disc', 'Clone type');
var
  Name, Langs, Regions, Text, Base, Genre, RegionList, SelectedRegion, Suffix: string;
  Rom, A, V: TJSONValue;
  Mask, I, Decor: Integer;
  NameMatch: TMatch;
  Hidden, Excluded, Favorite, LStrict, Unscraped: Boolean;
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
  Unscraped := Game = nil;
  Langs := JoinValues(Config, 'Miscellaneous.Languages', 'en');
  LStrict := JBool(Config, 'Miscellaneous.StrictRegionList');
  Rom := JValue(Game, 'rom');
  RegionList := OrderedRomRegions(Game, Config, FileName);
  Regions := RegionPriority(Game, Config, FileName);
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

end.
