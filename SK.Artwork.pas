unit SK.Artwork;

interface

uses
  System.SysUtils, System.JSON;

function PlatformArtwork(const Base: string; SystemID: Integer; const Kind: string): string;

function RefreshPlatformArtwork(Catalog, Settings, Credentials: TJSONObject; const Base: string; Offline: Boolean = False; Cancel: TFunc<Boolean> = nil; Progress: TProc<Integer, Integer> = nil): Integer;

implementation

uses
  System.Classes, System.IOUtils, System.Hash, System.StrUtils, SK.Json,
  SK.ScreenScraper, SK.Storage, SK.Metadata, SK.Catalog, SK.Platform, SK.Cache;

function IndexFile(const Base: string; SystemID: Integer): string;
begin
  Result := TPlatformPath.Combine(Base, 'State/PlatformArtwork/' + SystemID.ToString + '.json')
end;

function PlatformArtwork(const Base: string; SystemID: Integer; const Kind: string): string;
var
  Obj: TJSONObject;
begin
  Obj := ReadJSON(IndexFile(Base, SystemID));
  try
    Result := JStr(Obj, Kind)
  finally
    Obj.Free
  end;
  if (Result = '') or not IsPathWithin(Result, TPlatformPath.Combine(Base, 'Cache/media')) or
    not TFile.Exists(Result) then
    Result := '';
end;

function RefreshPlatformArtwork(Catalog, Settings, Credentials: TJSONObject; const Base: string; Offline: Boolean; Cancel: TFunc<Boolean>; Progress: TProc<Integer, Integer>): Integer;
const
  Kinds: array[0..3] of string = ('wheel', 'logo', 'photo', 'icon');
  Types: array[0..3] of string = ('wheel', 'logo-monochrome', 'photo', 'icon');
var
  API: TScreenScraper;
  Systems, S, Media: TJSONValue;
  Index: TJSONObject;
  Priority, URL, Ext, FileName: string;
  I, Done, Total, Attempt: Integer;
  CacheLock: TObject;

  function ValidImage: Boolean;
  var
    Stream: TFileStream;
    Digest: string;
    ExpectedSize: Int64;
  begin
    Result := False;
    if not TFile.Exists(FileName) then
      Exit;
    ExpectedSize := StrToInt64Def(JStr(Media, 'size'), 0);
    if (TFile.GetSize(FileName) = 0) or
      ((ExpectedSize > 0) and (TFile.GetSize(FileName) <> ExpectedSize)) then
      Exit;
    Digest := JStr(Media, 'md5');
    if Digest <> '' then
    begin
      Stream := TFileStream.Create(FileName, fmOpenRead or fmShareDenyWrite);
      try
        if not SameText(THashMD5.GetHashString(Stream), Digest) then
          Exit
      finally
        Stream.Free
      end;
    end;
    Result := True;
  end;

begin
  Result := 0;
  Done := 0;
  Total := 0;
  Systems := JValue(Catalog, 'systemes');
  if not (Systems is TJSONArray) then
    Exit;
  for S in TJSONArray(Systems) do
    if SelectablePlatform(S) then
      Inc(Total, Length(Kinds));
  Priority := JoinValues(Settings, 'Miscellaneous.Regions', 'us,eu,jp,wor');
  API := TScreenScraper.Create(Credentials, TPlatformPath.Combine(Base, 'Cache/api'));
  try
    API.Offline := Offline;
    API.IsCancelled := Cancel;
    for S in TJSONArray(Systems) do
    begin
      if not SelectablePlatform(S) then
        Continue;
      Index := ReadJSON(IndexFile(Base, JInt(S, 'id')));
      if Index = nil then
        Index := TJSONObject.Create;
      try
        API.ScopeSystemID := JInt(S, 'id');
        for I := 0 to High(Kinds) do
        begin
          if Assigned(Cancel) and Cancel() then
            raise EAbort.Create('Cancelled');
          Media := SelectMedia(JValue(S, 'medias'), Types[I], 'system', '', Priority, '', 0, False);
          if Media <> nil then
          begin
            URL := JStr(Media, 'url');
            Ext := JStr(Media, 'format', 'png').ToLower;
            if (URL <> '') and MatchText(Ext, ['png', 'jpg', 'jpeg', 'bmp']) then
            begin
              FileName := TPlatformPath.Combine(Base, 'Cache/media/' + THashSHA2.GetHashString(URL) + '.' + Ext);
              CacheLock := SharedResourceLock('download|' + PathKey(FileName));
              while not TMonitor.Enter(CacheLock, 100) do
                if Assigned(Cancel) and Cancel() then
                  raise EAbort.Create('Cancelled');
              try
                for Attempt := 0 to 1 do
                begin
                  if ValidImage then
                    Break;
                  if TFile.Exists(FileName) then
                    TFile.Delete(FileName);
                  API.Download(URL, FileName);
                end;
                if not ValidImage then
                  raise EScreenScraper.Create('Platform image checksum or size mismatch');
              finally
                TMonitor.Exit(CacheLock)
              end;
              JSet(Index, Kinds[I], TJSONString.Create(FileName));
              RegisterCacheFile(Base, JInt(S, 'id'), 'media', FileName);
              Inc(Result);
            end;
          end;
          Inc(Done);
          if Assigned(Progress) then
            Progress(Done, Total);
        end;
        WriteJSON(IndexFile(Base, JInt(S, 'id')), Index);
      finally
        Index.Free
      end;
    end;
  finally
    API.Free
  end;
end;

end.

