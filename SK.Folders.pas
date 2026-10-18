unit SK.Folders;

interface

uses
  System.SysUtils;

type
  TFolderItemCount = record
    Files, Folders: Int64;
    Error: string;
  end;

function CountFolderItems(const Folder: string): TFolderItemCount;

implementation

uses
  System.IOUtils, SK.Locale;

function CountFolderItems(const Folder: string): TFolderItemCount;
var
  Entry: string;
begin
  Result := Default(TFolderItemCount);
  if Folder.Trim = '' then
  begin
    Result.Error := SK.Locale.L('Папка не указана');
    Exit
  end;
  if not TDirectory.Exists(Folder) then
  begin
    Result.Error := SK.Locale.L('Папка не найдена');
    Exit
  end;
  try
    for Entry in TDirectory.GetFileSystemEntries(Folder) do
      if TDirectory.Exists(Entry) then
        Inc(Result.Folders)
      else
        Inc(Result.Files);
  except
    on E: Exception do
      Result.Error := SK.Locale.L('Не удалось прочитать папку');
  end;
end;

end.
