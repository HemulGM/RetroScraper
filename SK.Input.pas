unit SK.Input;

interface

uses
  SK.platform, System.SysUtils, System.Classes, System.JSON,
  System.Generics.Collections;

type
  TRomHashes = record
    Name, CRC, MD5, SHA1: string;
    Size: Int64;
    FromCache: Boolean;
  end;

function ScanInputs(Config: TJSONObject; Cancel: TFunc<Boolean> = nil): TArray<string>;

function InputFolderCount(Config: TJSONObject; const Inputs: TArray<string>): Integer;

function CompositeParts(Config: TJSONObject; const Folder: string; Cancel: TFunc<Boolean> = nil): TArray<string>;

function ComputeInputHashes(Config: TJSONObject; const FileName, CacheRoot: string; Cancel: TFunc<Boolean> = nil): TRomHashes;

procedure HashInputStream(Stream: TStream; out CRC, MD5, SHA1: string; Cancel: TFunc<Boolean> = nil);

function CleanRomName(const Name: string): string;

function MatchNameExpression(const Name, Expression: string): Boolean;

implementation

uses
  SK.Consts, System.IOUtils, System.Hash, System.Types, System.StrUtils,
  System.RegularExpressions, System.Character, System.Generics.Defaults,
  System.Zip, SK.Json, Z7.Archive;

type
  TJoinedInput = class(TStream)
  private
    FFiles: TArray<string>;
    FIndex: Integer;
    FStream: TStream;
    FZip: TZipFile;
    FPosition: Int64;
  public
    constructor Create(const Files: TArray<string>);
    constructor CreateZip(const FileName: string);
    function ContentSize: Int64;
    destructor Destroy; override;
    function Read(var Buffer; Count: Longint): Longint; override;
    function Write(const Buffer; Count: Longint): Longint; override;
    function Seek(const Offset: Int64; Origin: TSeekOrigin): Int64; override;
  end;

constructor TJoinedInput.Create(const Files: TArray<string>);
begin
  inherited Create;
  FFiles := Files
end;

constructor TJoinedInput.CreateZip(const FileName: string);
var
  L: TList<string>;
  i: Integer;
begin
  inherited Create;
  FZip := TZipFile.Create;
  FZip.Open(FileName, zmRead);
  L := TList<string>.Create;
  try
    for i := 0 to FZip.FileCount - 1 do
      if not FZip.FileNames[i].EndsWith('/') then
        L.Add(FZip.FileNames[i]);
    L.Sort(TComparer<string>.Construct(
      function(const A, B: string): Integer
      begin
        Result := CompareStr(A, B)
      end));
    FFiles := L.ToArray;
  finally
    L.Free
  end;
end;

function TJoinedInput.ContentSize: Int64;
var
  i: Integer;
begin
  Result := 0;
  for i := 0 to FZip.FileCount - 1 do
    Inc(Result, FZip.FileInfo[i].UncompressedSize64);
end;

destructor TJoinedInput.Destroy;
begin
  FStream.Free;
  FZip.Free;
  inherited
end;

function TJoinedInput.Read(var Buffer; Count: Longint): Longint;
var
  Header: TZipHeader;
begin
  Result := 0;
  while FIndex < Length(FFiles) do
  begin
    if FStream = nil then
      if FZip <> nil then
        FZip.Read(FFiles[FIndex], FStream, Header, True)
      else
        FStream := TFileStream.Create(FFiles[FIndex], fmOpenRead or fmShareDenyWrite);
    Result := FStream.Read(Buffer, Count);
    if Result > 0 then
    begin
      Inc(FPosition, Result);
      Exit
    end;
    FreeAndNil(FStream);
    Inc(FIndex);
  end;
end;

function TJoinedInput.Write(const Buffer; Count: Longint): Longint;
begin
  raise EStreamError.Create('Read-only ROM stream')
end;

function TJoinedInput.Seek(const Offset: Int64; Origin: TSeekOrigin): Int64;
begin
  if (Origin = soBeginning) and (Offset = 0) then
  begin
    FreeAndNil(FStream);
    FIndex := 0;
    FPosition := 0
  end
  else if not ((Origin = soCurrent) and (Offset = 0)) then
    raise EStreamError.Create('Sequential ROM stream');
  Result := FPosition;
end;

function Extensions(Config: TJSONObject): TArray<string>;
var
  V: TJSONValue;
  L: TList<string>;
begin
  L := TList<string>.Create;
  try
    if JValue(Config, 'GamesAndRoms.FileExtensions') is TJSONArray then
      for V in TJSONArray(JValue(Config, 'GamesAndRoms.FileExtensions')) do
        L.Add(V.Value.Trim.ToLower.TrimLeft(['.']));
    Result := L.ToArray;
  finally
    L.Free
  end;
end;

function IsHiddenPath(const Path, Root: string): Boolean;
var
  P: string;
begin
  P := Path;
  Result := False;
  while Length(P) >= Length(Root) do
  begin
    if HiddenEntry(P) then
      Exit(True);
    if SamePath(P, Root) then
      Break;
    P := TPath.GetDirectoryName(P);
  end;
end;

function SafeEntries(const Root: string; Directories: Boolean; Cancel: TFunc<Boolean>): TArray<string>;
var
  Pending: TStack<string>;
  Entries: TList<string>;
  Folder, Path: string;
begin
  Pending := TStack<string>.Create;
  Entries := TList<string>.Create;
  try
    Pending.Push(Root);
    while Pending.Count > 0 do
    begin
      if Assigned(Cancel) and Cancel() then
        raise EAbort.Create('Cancelled');
      Folder := Pending.Pop;
      for Path in TDirectory.GetDirectories(Folder) do
      begin
        if Assigned(Cancel) and Cancel() then
          raise EAbort.Create('Cancelled');
        if DirectoryLink(Path) or IsHiddenPath(Path, Root) then
          Continue;
        if Directories then
          Entries.Add(Path);
        Pending.Push(Path);
      end;
      if not Directories then
        for Path in TDirectory.GetFiles(Folder) do
        begin
          if Assigned(Cancel) and Cancel() then
            raise EAbort.Create('Cancelled');
          if not IsHiddenPath(Path, Root) then
            Entries.Add(Path);
        end;
    end;
    Result := Entries.ToArray;
  finally
    Entries.Free;
    Pending.Free
  end;
end;

function CompositeParts(Config: TJSONObject; const Folder: string; Cancel: TFunc<Boolean>): TArray<string>;
var
  Spec, FileName, Ext: string;
  P: Integer;
  Subs: TArray<string>;
  L: TList<string>;
begin
  Result := nil;
  L := TList<string>.Create;
  try
    for Spec in Extensions(Config) do
    begin
      P := Spec.IndexOf('(');
      if (P < 1) or not Spec.EndsWith(')') or not Folder.EndsWith('.' + Spec.Substring(0, P), True) then
        Continue;
      Subs := Spec.Substring(P + 1, Spec.Length - P - 2).Split(['|']);
      for FileName in SafeEntries(Folder, False, Cancel) do
        if not IsHiddenPath(FileName, Folder) then
          for Ext in Subs do
            if SameText(TPath.GetExtension(FileName), '.' + Ext.Trim.TrimLeft(['.'])) then
            begin
              if not L.Contains(FileName) then
                L.Add(FileName);
              Break
            end;
    end;
    L.Sort(TComparer<string>.Construct(
      function(const A, B: string): Integer
      begin
        Result := CompareStr(A, B)
      end));
    Result := L.ToArray;
  finally
    L.Free
  end;
end;

function ScanInputs(Config: TJSONObject; Cancel: TFunc<Boolean>): TArray<string>;
var
  Root, Path, Ext, Folder, Output: string;
  L, Composites, Excluded: TList<string>;
  Specs: TArray<string>;
  V: TJSONValue;
  Skip: Boolean;
  Blacklist: TDictionary<string, Boolean>;
  Line, Part: string;
  M: TMatch;
  i: Integer;

  procedure AddExcluded(const FileName: string);
  begin
    if TFile.Exists(FileName) then
      Blacklist.AddOrSetValue(PathKey(FileName), True);
  end;

begin
  Root := TPath.GetFullPath(JStr(Config, 'GamesAndRoms.Path'));
  if not TDirectory.Exists(Root) then
    raise Exception.Create('ROM folder does not exist: ' + Root);
  L := TList<string>.Create;
  Composites := TList<string>.Create;
  Excluded := TList<string>.Create;
  try
    Specs := Extensions(Config);
    Excluded.Add(IncludeTrailingPathDelimiter(TPlatformPath.Combine(Root, NativePath('media\folders'))));
    if JValue(Config, 'Medias') is TJSONArray then
      for V in TJSONArray(JValue(Config, 'Medias')) do
      begin
        Folder := JStr(V, 'OutputFolder').Replace('%ROMROOTFOLDER%', Root, [rfReplaceAll, rfIgnoreCase]);
        if Folder.Contains('%') or (Folder = '') then
          Continue;
        if not TPath.IsPathRooted(Folder) then
          Folder := TPlatformPath.Combine(Root, Folder);
        Folder := TPath.GetFullPath(NativePath(Folder));
        if not SamePath(Folder, Root) then
          Excluded.Add(IncludeTrailingPathDelimiter(Folder));
      end;
    for Path in SafeEntries(Root, True, Cancel) do
      if not IsHiddenPath(Path, Root) then
      begin
        Skip := False;
        for Folder in Excluded do
          if SamePath(Path, ExcludeTrailingPathDelimiter(Folder)) or IsPathWithin(Path, Folder) then
            Skip := True;
        if not Skip and (Length(CompositeParts(Config, Path, Cancel)) > 0) then
        begin
          Composites.Add(Path);
          L.Add(Path)
        end;
      end;
    Output := JStr(Config, 'GameList.OutputFile').Replace('%ROMROOTFOLDER%', Root, [rfReplaceAll, rfIgnoreCase]);
    if (Output <> '') and not TPath.IsPathRooted(Output) then
      Output := TPlatformPath.Combine(Root, Output);
    for Path in SafeEntries(Root, False, Cancel) do
    begin
      if IsHiddenPath(Path, Root) or SamePath(Path, Output) or SameText(TPath.GetFileName(Path), 'gamelist.xml') or Path.EndsWith('.part', True) then
        Continue;
      Skip := False;
      for Folder in Excluded do
        if IsPathWithin(Path, Folder) then
          Skip := True;
      for Folder in Composites do
        if IsPathWithin(Path, Folder) then
          Skip := True;
      if Skip then
        Continue;
      for Ext in Specs do
        if not Ext.Contains('(') and SameText(TPath.GetExtension(Path), '.' + Ext) then
        begin
          L.Add(Path);
          Break
        end;
    end;
    Blacklist := TDictionary<string, Boolean>.Create;
    try
      for Path in L do
      begin
        if Assigned(Cancel) and Cancel() then
          raise EAbort.Create('Cancelled');
        Ext := TPath.GetExtension(Path).ToLower;
        if Ext = '.ccd' then
          for Part in ['.cue', '.bin', '.sub', '.img'] do
            AddExcluded(ChangeFileExt(Path, Part));
        if Ext = '.mds' then
          AddExcluded(ChangeFileExt(Path, '.mdf'));
        if not MatchText(Ext, ['.cue', '.gdi', '.m3u']) or not TFile.Exists(Path) then
          Continue;
        if (Ext = '.gdi') and (TFile.GetSize(Path) > MaxGdiDescriptorSize) then
          Continue;
        for Line in TFile.ReadAllLines(Path) do
        begin
          Part := Line.Trim;
          if (Part = '') or Part.StartsWith('#') then
            Continue;
          if Ext <> '.m3u' then
          begin
            if (Ext = '.cue') and not (Part.Contains('FILE') and Part.Contains('BINARY')) then
              Continue;
            M := TRegEx.Match(Part, '"([^"]+\.[^"]+)"|([^\s"]+\.[^\s"]+)');
            if not M.Success then
              Continue;
            if M.Groups[1].Success then
              Part := M.Groups[1].Value
            else
              Part := M.Groups[2].Value;
          end;
          AddExcluded(TPlatformPath.Combine(ExtractFilePath(Path), Part));
        end;
      end;
      for i := L.Count - 1 downto 0 do
        if Blacklist.ContainsKey(PathKey(L[i])) then
          L.Delete(i);
    finally
      Blacklist.Free
    end;
    L.Sort;
    Result := L.ToArray;
  finally
    L.Free;
    Composites.Free;
    Excluded.Free
  end;
end;

function InputFolderCount(Config: TJSONObject; const Inputs: TArray<string>): Integer;
var
  Folders: TDictionary<string, Boolean>;
  Path, Root, FileName: string;
begin
  Result := 0;
  if (JInt(Config, 'GameList.Folders') = 0) or (JInt(Config, 'GameList.Type') <> 1) then
    Exit;
  Root := ExcludeTrailingPathDelimiter(TPath.GetFullPath(JStr(Config, 'GamesAndRoms.Path')));
  Folders := TDictionary<string, Boolean>.Create;
  try
    for FileName in Inputs do
    begin
      Path := ExtractFileDir(FileName);
      while IsPathWithin(Path, Root) do
      begin
        Folders.AddOrSetValue(PathKey(Path), True);
        Path := ExtractFileDir(Path);
      end;
    end;
    Result := Folders.Count;
  finally
    Folders.Free
  end;
end;

function CleanRomName(const Name: string): string;
var
  Base, Ext: string;
  i: Integer;
begin
  Ext := TPath.GetExtension(Name);
  Base := TPath.GetFileNameWithoutExtension(Name);
  Base := TRegEx.Replace(Base, '^(\s*[\(\[\{][^\)\]\}]*[\)\]\}]\s*)+', '');
  Base := Base.Replace('_', ' ').Replace('.', ' ').Replace(',', ' ');
  for i := Length(Base) downto 2 do
    if Base[i].IsUpper and (Base[i - 1].IsLower or Base[i - 1].IsDigit) then
      Insert(' ', Base, i);
  Base := TRegEx.Replace(Base, '\s+', ' ').Trim;
  for i := 1 to Length(Base) do
    if (i = 1) or (Base[i - 1] = ' ') then
      Base[i] := Base[i].ToUpper;
  Result := Base + Ext;
end;

function MatchNameExpression(const Name, Expression: string): Boolean;
var
  Pattern: string;
  C: Char;
begin
  if Expression = '' then
    Exit(False);
  if Expression.StartsWith('<') and Expression.EndsWith('>') then
    Pattern := Expression.Substring(1, Expression.Length - 2)
  else
  begin
    Pattern := '';
    for C in Expression.ToLower do
      case C of
        '*':
          Pattern := Pattern + '.*';
        '?':
          Pattern := Pattern + '.?'; // Original wildcard semantics: optional single character.
      else
        Pattern := Pattern + TRegEx.Escape(C)
      end;
  end;
  Result := TRegEx.IsMatch(Name.ToLower, Pattern, []);
end;

procedure HashInputStream(Stream: TStream; out CRC, MD5, SHA1: string; Cancel: TFunc<Boolean>);
var
  Buffer: TBytes;
  N, i, J: Integer;
  C, V: Cardinal;
  Table: array[0..255] of Cardinal;
  M: THashMD5;
  S: THashSHA1;
begin
  M := THashMD5.Create;
  S := THashSHA1.Create;
  C := CRC32InitialValue;
  for i := 0 to 255 do
  begin
    V := i;
    for J := 0 to 7 do
      if V and 1 <> 0 then
        V := (V shr 1) xor CRC32Polynomial
      else
        V := V shr 1;
    Table[i] := V;
  end;
  SetLength(Buffer, HashBufferSize);
  Stream.Position := 0;
  repeat
    if Assigned(Cancel) and Cancel() then
      raise EAbort.Create('Cancelled');
    N := Stream.Read(Buffer[0], Length(Buffer));
    if N = 0 then
      Break;
    M.Update(Buffer[0], N);
    S.Update(Buffer[0], N);
    for i := 0 to N - 1 do
      C := Table[(C xor Buffer[i]) and $FF] xor (C shr 8);
  until False;
  CRC := IntToHex(not C, 8);
  MD5 := M.HashAsString.ToUpper;
  SHA1 := S.HashAsString.ToUpper;
end;

function ComputeInputHashes(Config: TJSONObject; const FileName, CacheRoot: string; Cancel: TFunc<Boolean>): TRomHashes;
var
  Files: TArray<string>;
  FilePart, Signature, CacheFile, NameExt: string;
  Meta: TJSONObject;
  Stream: TStream;
  Order: TList<string>;
  Size: Int64;
begin
  Result := Default(TRomHashes);
  Result.Name := TPath.GetFileName(FileName);
  if Assigned(Cancel) and Cancel() then
    raise EAbort.Create('Cancelled');
  if TDirectory.Exists(FileName) then
    Files := CompositeParts(Config, FileName, Cancel)
  else
    Files := TArray<string>.Create(FileName);
  Signature := '';
  Size := 0;
  Order := TList<string>.Create;
  try
    for FilePart in Files do
    begin
      Size := Size + TFile.GetSize(FilePart);
      Signature := Signature + FilePart + '|' + TFile.GetSize(FilePart).ToString + '|' + FloatToStr(TFile.GetLastWriteTimeUtc(FilePart), TFormatSettings.Invariant) + #10;
      NameExt := TPath.GetExtension(FilePart).TrimLeft(['.']).ToLower;
      if not Order.Contains(NameExt) then
        Order.Add(NameExt);
    end;
    if TDirectory.Exists(FileName) then
    begin
      Order.Sort;
      NameExt := string.Join(',', Order.ToArray);
      Result.Name := TPath.GetFileNameWithoutExtension(FileName) + '.[' + NameExt + ']' + TPath.GetExtension(FileName);
    end;
  finally
    Order.Free
  end;
  CacheFile := TPlatformPath.Combine(CacheRoot, THashSHA2.GetHashString(PathKey(FileName)) + '.json');
  if Size >= LargeRomHashThreshold then
  begin
    Meta := ReadJSON(CacheFile);
    try
      if (Meta <> nil) and (JStr(Meta, 'signature') = Signature) then
      begin
        Result.CRC := JStr(Meta, 'crc');
        Result.MD5 := JStr(Meta, 'md5');
        Result.SHA1 := JStr(Meta, 'sha1');
        Result.Size := StrToInt64Def(JStr(Meta, 'size'), 0);
        Result.FromCache := True;
        Exit;
      end;
    finally
      Meta.Free
    end;
  end;
  if FileName.EndsWith('.zip', True) then
  begin
    Stream := TJoinedInput.CreateZip(FileName);
    try
      Result.Size := TJoinedInput(Stream).ContentSize;
      HashInputStream(Stream, Result.CRC, Result.MD5, Result.SHA1, Cancel);
    finally
      Stream.Free
    end;
  end
  else if FileName.EndsWith('.7z', True) then
  begin
    Stream := OpenSevenZipInput(FileName, Result.Size, Cancel);
    try
      HashInputStream(Stream, Result.CRC, Result.MD5, Result.SHA1, Cancel);
    finally
      Stream.Free;
    end;
  end
  else
  begin
    if MatchText(TPath.GetExtension(FileName), ['.rar', '.xz', '.gz', '.tar']) then
      raise Exception.Create('Deferred archive format: ' + TPath.GetExtension(FileName));
    Stream := TJoinedInput.Create(Files);
    try
      Result.Size := Size;
      HashInputStream(Stream, Result.CRC, Result.MD5, Result.SHA1, Cancel);
    finally
      Stream.Free
    end;
  end;
  if Size >= LargeRomHashThreshold then
  begin
    Meta := TJSONObject.Create;
    try
      Meta.AddPair('signature', Signature);
      Meta.AddPair('crc', Result.CRC);
      Meta.AddPair('md5', Result.MD5);
      Meta.AddPair('sha1', Result.SHA1);
      Meta.AddPair('size', TJSONNumber.Create(Result.Size));
      WriteJSON(CacheFile, Meta);
    finally
      Meta.Free
    end;
  end;
end;

end.

