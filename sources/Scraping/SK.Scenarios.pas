unit SK.Scenarios;

interface

uses
  System.SysUtils, System.JSON;

type
  TScenarioMode = (scmForce, scmMissing);

  TScenarioDefinition = record
    ID, Title, Description: string;
  end;

  TScenarioRequest = record
    ID, Field: string;
    Mode: TScenarioMode;
    function Active: Boolean;
    class function FromConfig(Config: TJSONObject): TScenarioRequest; static;
    procedure Apply(Config: TJSONObject);
    procedure PrepareSystem(Config: TJSONObject);
  end;

const
  UpdateFieldScenarioID = 'update-field';
  ScenarioFields: array[0..24] of string = (
    'name', 'desc', 'developer', 'publisher', 'genre', 'genreid', 'players',
    'rating', 'releasedate', 'classification', 'region', 'favorite', 'hidden',
    'hash', 'md5', 'image', 'thumbnail', 'box', 'logo', 'marquee', 'video',
    'manual', 'tips', 'p2k', 'maps');

function ScenarioDefinitions: TArray<TScenarioDefinition>;
function ScenarioMediaField(const Field: string): Boolean;
function ScenarioXmlField(const Field: string; Kind: Integer): string;

implementation

uses
  System.StrUtils, SK.Json, SK.Metadata, SK.Locale;

function ScenarioDefinitions: TArray<TScenarioDefinition>;
begin
  SetLength(Result, 1);
  Result[0].ID := UpdateFieldScenarioID;
  Result[0].Title := L('Обновить конкретное поле выбранных платформ');
  Result[0].Description := L('Выберите XML-поле и платформы. Для медиа используются источники, папки и формат из настроек платформы.');
end;

function ScenarioMediaField(const Field: string): Boolean;
begin
  Result := MatchText(Field, ['image', 'thumbnail', 'box', 'logo', 'marquee',
    'video', 'manual', 'tips', 'p2k', 'maps']);
end;

function ScenarioXmlField(const Field: string; Kind: Integer): string;
begin
  Result := '';
  if not MatchText(Field, ScenarioFields) then
    Exit;
  case Kind of
    1: Result := Field;
    2:
      if Field = 'name' then Result := 'Title'
      else if Field = 'desc' then Result := 'Notes'
      else if Field = 'developer' then Result := 'Developer'
      else if Field = 'publisher' then Result := 'Publisher'
      else if Field = 'genre' then Result := 'Genre'
      else if Field = 'rating' then Result := 'StarRatingFloat'
      else if Field = 'releasedate' then Result := 'ReleaseDate'
      else if Field = 'region' then Result := 'Region'
      else if Field = 'favorite' then Result := 'Favorite'
      else if Field = 'hidden' then Result := 'Hide'
      else if Field = 'video' then Result := 'VideoPath'
      else if Field = 'manual' then Result := 'ManualPath';
    3:
      if Field = 'name' then Result := '@name'
      else if Field = 'desc' then Result := 'description'
      else if Field = 'publisher' then Result := 'manufacturer'
      else if Field = 'releasedate' then Result := 'year';
  end;
end;

function TScenarioRequest.Active: Boolean;
begin
  Result := ID <> '';
end;

class function TScenarioRequest.FromConfig(Config: TJSONObject): TScenarioRequest;
var
  ModeName: string;
begin
  Result := Default(TScenarioRequest);
  Result.ID := JStr(Config, 'Scenario.ID');
  if not Result.Active then
    Exit;
  if Result.ID <> UpdateFieldScenarioID then
    raise EArgumentException.Create('Unknown scraping scenario: ' + Result.ID);
  Result.Field := JStr(Config, 'Scenario.Field');
  if not MatchText(Result.Field, ScenarioFields) then
    raise EArgumentException.Create('Unknown scraping field: ' + Result.Field);
  ModeName := JStr(Config, 'Scenario.Mode');
  if ModeName = 'force' then
    Result.Mode := scmForce
  else if ModeName = 'missing' then
    Result.Mode := scmMissing
  else
    raise EArgumentException.Create('Unknown scenario mode: ' + ModeName);
end;

procedure TScenarioRequest.Apply(Config: TJSONObject);
begin
  JSet(Config, 'Scenario.ID', TJSONString.Create(ID));
  JSet(Config, 'Scenario.Field', TJSONString.Create(Field));
  if Mode = scmForce then
    JSet(Config, 'Scenario.Mode', TJSONString.Create('force'))
  else
    JSet(Config, 'Scenario.Mode', TJSONString.Create('missing'));
  JSet(Config, 'OnlyNew', TJSONBool.Create(False));
end;

procedure TScenarioRequest.PrepareSystem(Config: TJSONObject);
var
  Media: TJSONArray;
  I: Integer;
  HasMedia: Boolean;
begin
  if not Active then
    Exit;
  if ScenarioXmlField(Field, JInt(Config, 'GameList.Type', 1)) = '' then
    raise EArgumentException.Create(L('Поле %s не поддерживается выбранным форматом XML.', [Field]));
  Apply(Config);
  if Field = 'desc' then
    JSet(Config, 'MetaData.NoSynopsis', TJSONBool.Create(False));
  if MatchText(Field, ['hash', 'md5']) and (JInt(Config, 'Miscellaneous.Method') = 2) then
    JSet(Config, 'Miscellaneous.Method', TJSONNumber.Create(0));
  JSet(Config, 'GameList.OnlyNew', TJSONBool.Create(False));
  JSet(Config, 'GameList.Behavior', TJSONNumber.Create(2));
  JSet(Config, 'GameList.Folders', TJSONNumber.Create(0));
  JSet(Config, 'GameList.PreserveHeader', TJSONBool.Create(True));
  JSet(Config, 'GameList.PreserveMissingMedia', TJSONBool.Create(True));
  JSet(Config, 'Miscellaneous.SaveFCRCMissing', TJSONBool.Create(False));
  if Mode = scmForce then
  begin
    JSet(Config, 'Miscellaneous.CacheTTLInDays', TJSONNumber.Create(0));
    JSet(Config, 'Miscellaneous.ReuseExistingMedia', TJSONBool.Create(False));
  end;
  if ScenarioMediaField(Field) then
  begin
    HasMedia := False;
    if JValue(Config, 'Medias') is TJSONArray then
    begin
      Media := TJSONArray(JValue(Config, 'Medias'));
      // Keep every slot in place: MediaNode and output names depend on its index.
      for I := 0 to Media.Count - 1 do
        HasMedia := HasMedia or (MediaNode(Media, I) = Field);
    end;
    if not HasMedia then
      raise EArgumentException.Create(L('Для поля %s не настроен источник медиа. Добавьте его в настройках платформы.', [Field]));
  end;
end;

end.
