unit SK.Data;

interface

// Compatibility facade. Application modules import the specific owners directly.

uses
  System.JSON, SK.GameList;

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
  // Compatibility alias; new consumers use SK.GameList directly.
  TGameListWriter = SK.GameList.TGameListWriter;

implementation

uses
  SK.Metadata, SK.Input, SK.Output;

function JoinValues(Obj: TJSONValue; const Path, Default: string): string;
begin
  Result := SK.Metadata.JoinValues(Obj, Path, Default);
end;

function PickText(Obj: TJSONValue; const Path, Key, Priority: string; AStrict: Boolean): string;
begin
  Result := SK.Metadata.PickText(Obj, Path, Key, Priority, AStrict);
end;

function OrderedRomRegions(Game, Config: TJSONObject; const FileName: string): string;
begin
  Result := SK.Metadata.OrderedRomRegions(Game, Config, FileName);
end;

function RegionPriority(Game, Config: TJSONObject; const FileName: string): string;
begin
  Result := SK.Metadata.RegionPriority(Game, Config, FileName);
end;

function SelectMedia(Entries: TJSONValue; const MediaType, ParentType, ParentID, Priority, Classification: string; Support: Integer; AStrict: Boolean): TJSONValue;
begin
  Result := SK.Metadata.SelectMedia(Entries, MediaType, ParentType, ParentID, Priority, Classification, Support, AStrict);
end;

function MediaNode(Configs: TJSONArray; Index: Integer): string;
begin
  Result := SK.Metadata.MediaNode(Configs, Index);
end;

function TipsContent(Game, Config: TJSONObject): string;
begin
  Result := SK.Metadata.TipsContent(Game, Config);
end;

function DescribeGame(Game, Config: TJSONObject; const FileName: string): TJSONObject;
begin
  Result := SK.Metadata.DescribeGame(Game, Config, FileName);
end;

function CollectRoms(Config: TJSONObject): TArray<string>;
begin
  Result := SK.Input.ScanInputs(Config);
end;

function ResolveOutput(const Pattern, Root, FileName: string): string;
begin
  Result := SK.Output.ResolveOutput(Pattern, Root, FileName);
end;

end.
