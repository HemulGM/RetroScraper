unit SK.Storage;

interface

uses
  System.SysUtils, System.Generics.Collections;

function SharedResourceLock(const Key: string): TObject;

function AppBase: string;

procedure CommitFile(const Temporary, Destination: string);

procedure EnsureDirectory(const DirectoryName: string);

implementation

uses
  System.IOUtils, SK.platform;

var
  ResourceGuard: TObject;
  ResourceLocks: TObjectDictionary<string, TObject>;

function SharedResourceLock(const Key: string): TObject;
begin
  TMonitor.Enter(ResourceGuard);
  try
    if not ResourceLocks.TryGetValue(Key, Result) then
    begin
      Result := TObject.Create;
      ResourceLocks.Add(Key, Result)
    end;
  finally
    TMonitor.Exit(ResourceGuard)
  end;
end;

procedure CommitFile(const Temporary, Destination: string);
begin
  AtomicReplace(Temporary, Destination)
end;

procedure EnsureDirectory(const DirectoryName: string);
var
  DirectoryPath, Parent: string;
  ErrorCode: Integer;
begin
  if DirectoryName = '' then
    Exit;
  DirectoryPath := TPath.GetFullPath(DirectoryName);
  if DirectoryExists(DirectoryPath) then
    Exit;
  DirectoryPath := ExcludeTrailingPathDelimiter(DirectoryPath);
  Parent := ExtractFileDir(DirectoryPath);
  if (Parent <> '') and (Parent <> DirectoryPath) then
    EnsureDirectory(Parent);
  // Another worker may create a parent or this directory between the checks.
  if not CreateDir(DirectoryPath) then
  begin
    ErrorCode := System.GetLastError;
    if not DirectoryExists(DirectoryPath) then
      RaiseLastOSError(ErrorCode);
  end;
end;

function AppBase: string;
begin
  Result := ResourceBase
end;

initialization
  ResourceGuard := TObject.Create;
  ResourceLocks := TObjectDictionary<string, TObject>.Create([doOwnsValues]);

finalization
  ResourceLocks.Free;
  ResourceGuard.Free;

end.

