unit SK.Catalog;

interface

uses
  System.SysUtils, System.JSON;

type
  TDetectedPlatform = record
    Folder: string;
    IDs: TArray<Integer>;
  end;

function CatalogSystem(Catalog: TJSONObject; ID: Integer): TJSONObject;

function SelectablePlatform(SystemInfo: TJSONValue): Boolean;

function PlatformName(Catalog, Settings: TJSONObject; ID: Integer): string;

function LookupPlatforms(Catalog: TJSONObject; const Folder: string; Frontend: Integer; Approximate, SearchAll: Boolean): TArray<Integer>;

function DetectPlatforms(Catalog: TJSONObject; const Root: string; Frontend: Integer; Recursive, SearchAll: Boolean; Cancel: TFunc<Boolean> = nil): TArray<TDetectedPlatform>;

procedure ConfigurePlatform(Target, Master, Catalog: TJSONObject; Frontend: Integer; const IDs: TArray<Integer>; const Folder: string);

function PlatformIDs(Settings: TJSONObject): TArray<Integer>;

implementation

uses
  System.Classes, System.IOUtils, System.StrUtils, System.Math,
  System.RegularExpressions, System.Generics.Collections,
  System.Generics.Defaults, System.NetEncoding, SK.Json, SK.Platform;

function SelectablePlatform(SystemInfo: TJSONValue): Boolean;
begin
  Result := (SystemInfo <> nil) and (JInt(SystemInfo, 'id') > 0) and
    (JInt(SystemInfo, 'id') <> 168) and not SameText(JStr(SystemInfo, 'type'), 'flipper');
end;

function CatalogSystem(Catalog: TJSONObject; ID: Integer): TJSONObject;
var
  V: TJSONValue;
begin
  Result := nil;
  if JValue(Catalog, 'systemes') is TJSONArray then
    for V in TJSONArray(JValue(Catalog, 'systemes')) do
      if JInt(V, 'id') = ID then
        Exit(V as TJSONObject);
end;

function PlatformName(Catalog, Settings: TJSONObject; ID: Integer): string;
var
  S: TJSONObject;
  V: TJSONValue;
  Code: string;
begin
  S := CatalogSystem(Catalog, ID);
  if JValue(Settings, 'Miscellaneous.Regions') is TJSONArray then
    for V in TJSONArray(JValue(Settings, 'Miscellaneous.Regions')) do
    begin
      Result := JStr(S, 'noms.nom_' + V.Value.ToLower);
      if Result <> '' then
        Exit(TNetEncoding.HTML.Decode(Result));
    end;
  if JValue(Settings, 'Miscellaneous.Languages') is TJSONArray then
    for V in TJSONArray(JValue(Settings, 'Miscellaneous.Languages')) do
    begin
      Result := JStr(S, 'noms.nom_' + V.Value.ToLower);
      if Result <> '' then
        Exit(TNetEncoding.HTML.Decode(Result));
    end;
  for Code in ['us', 'eu', 'jp'] do
  begin
    Result := JStr(S, 'noms.nom_' + Code);
    if Result <> '' then
      Exit(TNetEncoding.HTML.Decode(Result));
  end;
  Result := ID.ToString;
end;

function Normalized(const Value: string): string;
begin
  Result := TRegEx.Replace(Value.ToLower, '[^a-z0-9]', '');
end;

function JaroWinkler(const A, B: string): Double;
var
  MA, MB: TArray<Boolean>;
  I, J, Window, Matches, Transpositions, Prefix, K: Integer;
begin
  if A = B then
    Exit(1);
  if (A = '') or (B = '') then
    Exit(0);
  SetLength(MA, A.Length);
  SetLength(MB, B.Length);
  Window := Max(0, Max(A.Length, B.Length) div 2 - 1);
  Matches := 0;
  for I := 0 to A.Length - 1 do
    for J := Max(0, I - Window) to Min(B.Length - 1, I + Window) do
      if not MB[J] and (A[I + 1] = B[J + 1]) then
      begin
        MA[I] := True;
        MB[J] := True;
        Inc(Matches);
        Break;
      end;
  if Matches = 0 then
    Exit(0);
  Transpositions := 0;
  K := 0;
  for I := 0 to A.Length - 1 do
    if MA[I] then
    begin
      while not MB[K] do
        Inc(K);
      if A[I + 1] <> B[K + 1] then
        Inc(Transpositions);
      Inc(K);
    end;
  Result := (Matches / A.Length + Matches / B.Length +
    (Matches - Transpositions div 2) / Matches) / 3;
  Prefix := 0;
  while (Prefix < Min(4, Min(A.Length, B.Length))) and
    (A[Prefix + 1] = B[Prefix + 1]) do
    Inc(Prefix);
  if Result > 0.7 then
    Result := Result + Prefix * 0.1 * (1 - Result);
end;

function HasAncestor(Catalog: TJSONObject; Child, Parent: Integer): Boolean;
var
  Seen: TList<Integer>;
begin
  Result := False;
  Seen := TList<Integer>.Create;
  try
    while (Child > 0) and not Seen.Contains(Child) do
    begin
      if Child = Parent then
        Exit(True);
      Seen.Add(Child);
      Child := JInt(CatalogSystem(Catalog, Child), 'parentid');
    end;
  finally
    Seen.Free
  end;
end;

type
  TPlatformAliasIndex = class
  private
    FAliases: TObjectDictionary<string, TList<Integer>>;
    FOrder, FNormalized: TList<string>;
  public
    constructor Create(Catalog: TJSONObject; const Field: string);
    destructor Destroy; override;
    function Lookup(const Folder: string; Approximate: Boolean): TArray<Integer>;
  end;

constructor TPlatformAliasIndex.Create(Catalog: TJSONObject; const Field: string);
var
  S: TJSONValue;
  Name, Alias: string;
  IDs: TList<Integer>;
  I, J, ID, Parent: Integer;
begin
  inherited Create;
  FAliases := TObjectDictionary<string, TList<Integer>>.Create([doOwnsValues]);
  FOrder := TList<string>.Create;
  FNormalized := TList<string>.Create;
  if not (JValue(Catalog, 'systemes') is TJSONArray) then
    Exit;
  for S in TJSONArray(JValue(Catalog, 'systemes')) do
  begin
    if not SelectablePlatform(S) then
      Continue;
    // Match SystemObject.Convert: replace slashes before decoding HTML entities.
    for Name in TNetEncoding.HTML.Decode(JStr(S, 'noms.' + Field).Replace('/', '-')).Split([',']) do
    begin
      Alias := Name.Trim;
      if Alias = '' then
        Continue;
      if not FAliases.TryGetValue(Alias, IDs) then
      begin
        IDs := TList<Integer>.Create;
        FAliases.Add(Alias, IDs);
        FOrder.Add(Alias);
        FNormalized.Add(Normalized(Alias));
      end;
      if not IDs.Contains(JInt(S, 'id')) then
        IDs.Add(JInt(S, 'id'));
    end;
  end;
  for Alias in FOrder do
  begin
    IDs := FAliases[Alias];
    // Parents are primary; equal parent IDs retain catalogue order.
    for I := 1 to IDs.Count - 1 do
    begin
      ID := IDs[I];
      Parent := JInt(CatalogSystem(Catalog, ID), 'parentid');
      J := I - 1;
      while (J >= 0) and (JInt(CatalogSystem(Catalog, IDs[J]), 'parentid') > Parent) do
      begin
        IDs[J + 1] := IDs[J];
        Dec(J)
      end;
      IDs[J + 1] := ID;
    end;
    for I := IDs.Count - 1 downto 0 do
      for J := 0 to IDs.Count - 1 do
        if (I <> J) and HasAncestor(Catalog, IDs[I], IDs[J]) then
        begin
          IDs.Delete(I);
          Break
        end;
  end;
end;

destructor TPlatformAliasIndex.Destroy;
begin
  FNormalized.Free;
  FOrder.Free;
  FAliases.Free;
  inherited;
end;

function TPlatformAliasIndex.Lookup(const Folder: string; Approximate: Boolean): TArray<Integer>;
var
  IDs: TList<Integer>;
  Query: string;
  I, Best: Integer;
  Score, BestScore, Threshold: Double;
begin
  Result := nil;
  if not Approximate then
  begin
    if FAliases.TryGetValue(Folder, IDs) then
      Result := IDs.ToArray;
    Exit;
  end;
  // Generic detection always uses normalized common names, even for exact spellings.
  Query := Normalized(Folder);
  BestScore := 0;
  Best := -1;
  for I := 0 to FOrder.Count - 1 do
  begin
    Score := JaroWinkler(Query, FNormalized[I]);
    if Score > BestScore then
    begin
      BestScore := Score;
      Best := I
    end;
  end;
  Threshold := 1;
  if Query.Length >= 5 then
    Threshold := Max(0.92, 0.96 - 0.005 * (Query.Length - 5));
  if (Best >= 0) and (BestScore >= Threshold) then
    Result := FAliases[FOrder[Best]].ToArray;
end;

function LookupPlatforms(Catalog: TJSONObject; const Folder: string; Frontend: Integer; Approximate, SearchAll: Boolean): TArray<Integer>;
var
  Index: TPlatformAliasIndex;
  Field: string;
begin
  case Frontend of
    0:
      Field := 'nom_recalbox';
    1:
      Field := 'nom_retropie';
    2:
      Field := 'nom_launchbox';
  else
    Field := 'noms_commun';
  end;
  Index := TPlatformAliasIndex.Create(Catalog, Field);
  try
    Result := Index.Lookup(Folder, Approximate and (Frontend in [3, 4]))
  finally
    Index.Free
  end;
  if (Length(Result) = 0) and SearchAll and Approximate and not (Frontend in [3, 4]) then
  begin
    Index := TPlatformAliasIndex.Create(Catalog, 'noms_commun');
    try
      Result := Index.Lookup(Folder, True)
    finally
      Index.Free
    end;
  end;
end;

function DetectPlatforms(Catalog: TJSONObject; const Root: string; Frontend: Integer; Recursive, SearchAll: Boolean; Cancel: TFunc<Boolean>): TArray<TDetectedPlatform>;
type
  TScanDirectory = record
    Folder: string;
    Ancestors: TArray<string>;
  end;
var
  Pending: TQueue<TScanDirectory>;
  Found: TList<TDetectedPlatform>;
  Standard, Common: TPlatformAliasIndex;
  Seen: TDictionary<string, Boolean>;
  RootPath, Folder, Identity, Ancestor: string;
  Item: TDetectedPlatform;
  Parent, Next: TScanDirectory;
  Cycle: Boolean;

  procedure CheckCancelled;
  begin
    if Assigned(Cancel) and Cancel() then
      raise EAbort.Create('Cancelled');
  end;

  procedure AddFolder(const Path: string; Index: TPlatformAliasIndex; Approximate: Boolean);
  begin
    CheckCancelled;
    if Seen.ContainsKey(PathKey(Path)) then
      Exit;
    Item.IDs := Index.Lookup(TPath.GetFileName(Path), Approximate);
    if Length(Item.IDs) = 0 then
      Exit;
    Item.Folder := Path;
    Found.Add(Item);
    Seen.Add(PathKey(Path), True);
  end;

begin
  Pending := TQueue<TScanDirectory>.Create;
  Found := TList<TDetectedPlatform>.Create;
  Seen := TDictionary<string, Boolean>.Create;
  Standard := nil;
  Common := nil;
  try
    CheckCancelled;
    RootPath := TPath.GetFullPath(Root);
    if Frontend in [0, 1] then
    begin
      // The original uses Recalbox's exact dictionary for both Recalbox and RetroPie.
      Standard := TPlatformAliasIndex.Create(Catalog, 'nom_recalbox');
      for Folder in TDirectory.GetDirectories(RootPath) do
        AddFolder(Folder, Standard, False);
      if not SearchAll then
        Exit(Found.ToArray);
    end;
    Common := TPlatformAliasIndex.Create(Catalog, 'noms_commun');
    Next.Folder := RootPath;
    if Recursive then
      Next.Ancestors := TArray<string>.Create(DirectoryIdentity(RootPath));
    Pending.Enqueue(Next);
    while Pending.Count > 0 do
    begin
      CheckCancelled;
      Parent := Pending.Dequeue;
      for Folder in TDirectory.GetDirectories(Parent.Folder) do
      begin
        AddFolder(Folder, Common, True);
        if not Recursive then
          Continue;
        Identity := DirectoryIdentity(Folder);
        Cycle := False;
        for Ancestor in Parent.Ancestors do
          if Ancestor = Identity then
          begin
            Cycle := True;
            Break
          end;
        if Cycle then
          Continue;
        Next.Folder := Folder;
        Next.Ancestors := Copy(Parent.Ancestors);
        SetLength(Next.Ancestors, Length(Next.Ancestors) + 1);
        Next.Ancestors[High(Next.Ancestors)] := Identity;
        Pending.Enqueue(Next);
      end;
    end;
    Result := Found.ToArray;
  finally
    Common.Free;
    Standard.Free;
    Seen.Free;
    Found.Free;
    Pending.Free
  end;
end;

function PlatformIDs(Settings: TJSONObject): TArray<Integer>;
var
  IDs: TList<Integer>;
  V: TJSONValue;
  ID: Integer;
begin
  IDs := TList<Integer>.Create;
  try
    IDs.Add(JInt(Settings, 'SystemId'));
    if JValue(Settings, 'SecondarySystemIds') is TJSONArray then
      for V in TJSONArray(JValue(Settings, 'SecondarySystemIds')) do
      begin
        ID := StrToIntDef(V.Value, 0);
        if (ID > 0) and not IDs.Contains(ID) then
          IDs.Add(ID);
      end;
    Result := IDs.ToArray;
  finally
    IDs.Free
  end;
end;

procedure ConfigurePlatform(Target, Master, Catalog: TJSONObject; Frontend: Integer; const IDs: TArray<Integer>; const Folder: string);
var
  A, Extensions: TJSONArray;
  S: TJSONObject;
  Ext, Group, Name: string;
  Unique: TStringList;
  I, Mask: Integer;
  Arcade, CD: Boolean;
begin
  if Length(IDs) = 0 then
    raise EArgumentException.Create('A platform is required');
  for Group in ['GamesAndRoms', 'GameList', 'MetaData', 'Medias', 'Miscellaneous', 'Overlays'] do
    if JValue(Master, Group) <> nil then
      JSet(Target, Group, JValue(Master, Group).Clone as TJSONValue);
  JSet(Target, 'SystemId', TJSONNumber.Create(IDs[0]));
  A := TJSONArray.Create;
  for I := 1 to High(IDs) do
    if IDs[I] <> IDs[0] then
      A.Add(IDs[I]);
  JSet(Target, 'SecondarySystemIds', A);
  JSet(Target, 'GamesAndRoms.Path', TJSONString.Create(Folder));
  S := CatalogSystem(Catalog, IDs[0]);
  Name := JStr(S, 'noms.nom_launchbox');
  if Name.Contains(',') then
    Name := Name.Substring(0, Name.IndexOf(','));
  Name := Name.Trim;
  if Name = '' then
    Name := PlatformName(Catalog, Master, IDs[0]);
  JSet(Target, 'GamesAndRoms.Platform', TJSONString.Create(Name));
  Unique := TStringList.Create;
  try
    Unique.CaseSensitive := False;
    Unique.Sorted := True;
    Unique.Duplicates := dupIgnore;
    Unique.Add('zip');
    if Frontend in [2, 3, 4] then
      for Ext in ['7z', 'rar', 'gz', 'xz', 'tar'] do
        Unique.Add(Ext);
    for I in IDs do
    begin
      for Ext in JStr(CatalogSystem(Catalog, I), 'extensions').Split([',']) do
        if Ext.Trim <> '' then
          Unique.Add(Ext.Trim.ToLower.TrimLeft(['.']));
      // SG-1000 also covers SC-3000 and SF-7000 software.
      if I = 109 then
        for Ext in ['sc', 'sf7'] do
          Unique.Add(Ext);
    end;
    if (S = nil) and (JValue(Master, 'GamesAndRoms.FileExtensions') is TJSONArray) then
      for I := 0 to TJSONArray(JValue(Master, 'GamesAndRoms.FileExtensions')).Count - 1 do
        Unique.Add(TJSONArray(JValue(Master, 'GamesAndRoms.FileExtensions')).Items[I].Value);
    Extensions := TJSONArray.Create;
    for Ext in Unique do
      Extensions.Add(Ext);
    JSet(Target, 'GamesAndRoms.FileExtensions', Extensions);
  finally
    Unique.Free
  end;
  Arcade := JStr(S, 'type').ToLower.Contains('arcade');
  CD := JStr(S, 'romtype').ToLower.Contains('iso');
  Mask := 2;
  if Arcade or CD then
    Mask := Mask or 20;
  JSet(Target, 'Overriden', TJSONNumber.Create(Mask));
  if Arcade or CD then
    JSet(Target, 'Miscellaneous.Method', TJSONNumber.Create(2));
  if Arcade then
    JSet(Target, 'MetaData.NameDecorations', TJSONNumber.Create(2048))
  else
    JSet(Target, 'MetaData.NameDecorations', TJSONNumber.Create(0));
end;

end.

