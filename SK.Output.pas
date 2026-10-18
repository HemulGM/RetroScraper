unit SK.Output;

interface

uses
  System.SysUtils;

function ResolveOutput(const Pattern, Root, FileName: string): string;

implementation

uses
  System.IOUtils, SK.Platform;

function ResolveOutput(const Pattern, Root, FileName: string): string;
begin
  Result := Pattern.Replace('%ROMROOTFOLDER%', Root, [rfReplaceAll, rfIgnoreCase]);
  Result := Result.Replace('%ROMFOLDER%', ExtractFileDir(FileName), [rfReplaceAll, rfIgnoreCase]);
  if not TPath.IsPathRooted(Result) then
    Result := TPlatformPath.Combine(Root, Result);
  Result := TPath.GetFullPath(NativePath(Result));
end;

end.
