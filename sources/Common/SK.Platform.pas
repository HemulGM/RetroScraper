unit SK.platform;

interface

uses
  System.SysUtils, System.Classes, System.IOUtils;

type
  TPlatformPath = record
    class function Combine(const Left, Right: string): string; static;
  end;

function NativePath(const Value: string): string;

function PathKey(const Value: string): string;

function SamePath(const A, B: string): Boolean;

function IsPathWithin(const Path, Root: string): Boolean;

procedure AtomicReplace(const Temporary, Destination: string);

procedure BeginWorkerPlatform;

procedure EndWorkerPlatform;

function LoadSecret(const Identity: string): string;

procedure SaveSecret(const Identity, Value: string);

procedure OpenExternalURL(const URL: string);

procedure StopNamedProcess(const Name: string; const Log: TProc<string>; Cancel: TFunc<Boolean>);

procedure StopRemoteProcess(const Host: string; Cancel: TFunc<Boolean>);

function HiddenEntry(const Path: string): Boolean;

function DirectoryLink(const Path: string): Boolean;

function DirectoryIdentity(const Path: string): string;

function ResourceBase: string;

function WritableBase: string;

function UserDataBase: string;

function LegacyWritableBase: string;

function SessionTemporaryBase: string;

procedure CheckWritablePath(const Path: string);

function CompatibleSettingsBase(const Preferred: string): string;

function SystemCulture: string;

implementation

uses
  SK.Consts, {$IFDEF MSWINDOWS}
  Winapi.Windows, Winapi.ActiveX, System.Win.ComObj, Winapi.ShellAPI,
  Winapi.Messages, Winapi.TlHelp32, Winapi.ShFolder,
  {$ELSE}
  Posix.Base, Posix.SysTypes, Posix.Unistd, Posix.SysWait, Posix.Signal,
  Posix.Stdio, Posix.Errno, Posix.Dlfcn, Posix.SysStat,
  {$IFDEF MACOS}
  Macapi.Security, Macapi.CoreFoundation,
  {$ENDIF}
  {$ENDIF}
  System.Hash;

function SystemCulture: string;
{$IFDEF MSWINDOWS}
var
  Buffer: array[0..LOCALE_NAME_MAX_LENGTH - 1] of Char;
{$ELSEIF Defined(MACOS)}
var
  Locale: CFLocaleRef;
  Identifier: CFStringRef;
  Buffer: array[0..255] of UTF8Char;
{$ENDIF}
begin
  Result := '';
  {$IFDEF MSWINDOWS}
  if GetUserDefaultLocaleName(Buffer, Length(Buffer)) > 0 then
    Result := PChar(@Buffer[0]);
  {$ELSEIF Defined(MACOS)}
  Locale := CFLocaleCopyCurrent;
  if Locale <> nil then
  try
    Identifier := CFLocaleGetIdentifier(Locale);
    if (Identifier <> nil) and CFStringGetCString(Identifier, @Buffer[0],
      SizeOf(Buffer), kCFStringEncodingUTF8) then
      Result := UTF8ToString(PUTF8Char(@Buffer[0]));
  finally
    CFRelease(Locale);
  end;
  {$ELSE}
  Result := GetEnvironmentVariable('LC_ALL');
  if Result = '' then
    Result := GetEnvironmentVariable('LC_MESSAGES');
  if Result = '' then
    Result := GetEnvironmentVariable('LANG');
  {$ENDIF}
  if (Result = '') or SameText(Result.Split(['.', '@'])[0], 'C') or
    SameText(Result, 'POSIX') then
    Result := 'en-US';
end;

function NativePath(const Value: string): string;
begin
  {$IFDEF MSWINDOWS}
  Result := Value.Replace('/', PathDelim);
  {$ELSE}
  Result := Value.Replace('\', PathDelim);
  {$ENDIF}
end;

class function TPlatformPath.Combine(const Left, Right: string): string;
begin
  Result := TPath.Combine(NativePath(Left), NativePath(Right))
end;

function PathKey(const Value: string): string;
begin
  Result := TPath.GetFullPath(NativePath(Value));
  {$IFDEF MSWINDOWS}
  Result := Result.ToLower;
  {$ENDIF}
end;

function SamePath(const A, B: string): Boolean;
begin
  if (A = '') or (B = '') then
    Exit(A = B);

  Result := PathKey(A) = PathKey(B)
end;

function IsPathWithin(const Path, Root: string): Boolean;
begin
  Result := PathKey(Path).StartsWith(IncludeTrailingPathDelimiter(PathKey(Root)))
end;

{$IFDEF MSWINDOWS}
function NativeFileAttributes(const Path: string): DWORD;
begin
  Result := GetFileAttributes(PChar(Path));
  if Result = INVALID_FILE_ATTRIBUTES then
    RaiseLastOSError;
end;
{$ENDIF}

function HiddenEntry(const Path: string): Boolean;
begin
  Result := TPath.GetFileName(ExcludeTrailingPathDelimiter(Path)).StartsWith('.');
  {$IFDEF MSWINDOWS}
  Result := Result or ((NativeFileAttributes(Path) and
    (FILE_ATTRIBUTE_HIDDEN or FILE_ATTRIBUTE_SYSTEM)) <> 0);
  {$ENDIF}
end;

function DirectoryLink(const Path: string): Boolean;
{$IFNDEF MSWINDOWS}
var
  Info: _stat;
  EncodedPath: UTF8String;
{$ENDIF}
begin
  {$IFDEF MSWINDOWS}
  Result := (NativeFileAttributes(Path) and FILE_ATTRIBUTE_REPARSE_POINT) <> 0;
  {$ELSE}
  // Inspect the link itself; following it would hide directory symlinks.
  EncodedPath := UTF8String(ExcludeTrailingPathDelimiter(Path));
  if lstat(MarshaledAString(EncodedPath), Info) <> 0 then
    RaiseLastOSError;
  Result := S_ISLNK(Info.st_mode);
  {$ENDIF}
end;

function DirectoryIdentity(const Path: string): string;
{$IFDEF MSWINDOWS}
var
  Handle: THandle;
  Info: TByHandleFileInformation;
{$ELSE}
var
  Info: _stat;
  EncodedPath: UTF8String;
{$ENDIF}
begin
  {$IFDEF MSWINDOWS}
  Handle := CreateFile(PChar(Path), 0, FILE_SHARE_READ or FILE_SHARE_WRITE or
    FILE_SHARE_DELETE, nil, OPEN_EXISTING, FILE_FLAG_BACKUP_SEMANTICS, 0);
  if Handle = INVALID_HANDLE_VALUE then
    RaiseLastOSError;
  try
    if not GetFileInformationByHandle(Handle, Info) then
      RaiseLastOSError;
    Result := UInt64(Info.dwVolumeSerialNumber).ToString + ':' +
      UInt64(Info.nFileIndexHigh).ToString + ':' + UInt64(Info.nFileIndexLow).ToString;
  finally
    CloseHandle(Handle)
  end;
  {$ELSE}
  EncodedPath := UTF8String(ExcludeTrailingPathDelimiter(Path));
  if stat(MarshaledAString(EncodedPath), Info) <> 0 then
    RaiseLastOSError;
  Result := UInt64(Info.st_dev).ToString + ':' + UInt64(Info.st_ino).ToString;
  {$ENDIF}
end;

function SourceProjectBase: string;
var
  Candidate, Parent: string;
begin
  Candidate := ExcludeTrailingPathDelimiter(ExtractFilePath(ParamStr(0)));
  while Candidate <> '' do
  begin
    if TFile.Exists(TPlatformPath.Combine(Candidate, 'RetroScraper.dproj')) and
      TDirectory.Exists(TPlatformPath.Combine(Candidate, 'sources')) then
      Exit(IncludeTrailingPathDelimiter(Candidate));
    Parent := TDirectory.GetParent(Candidate);
    if Parent = Candidate then
      Break;
    Candidate := Parent;
  end;
  Result := '';
end;

function ResourceBase: string;
var
  Candidate, Parent: string;
begin
  Candidate := ExcludeTrailingPathDelimiter(ExtractFilePath(ParamStr(0)));
  while Candidate <> '' do
  begin
    if TFile.Exists(TPlatformPath.Combine(Candidate, ResourceManifestPath)) then
      Exit(IncludeTrailingPathDelimiter(Candidate));

    // Development builds use the same resource tree that packaging copies beside the executable.
    if TFile.Exists(TPlatformPath.Combine(Candidate, 'sources/Assets/Runtime/' + ResourceManifestPath)) then
      Exit(IncludeTrailingPathDelimiter(TPlatformPath.Combine(Candidate, 'sources/Assets/Runtime')));

    // macOS application bundles keep resources in Contents/Resources.
    if TFile.Exists(TPlatformPath.Combine(Candidate, 'Resources/Resources/manifest.json')) then
      Exit(IncludeTrailingPathDelimiter(TPlatformPath.Combine(Candidate, 'Resources')));

    Parent := TDirectory.GetParent(Candidate);
    if Parent = Candidate then
      Break;
    Candidate := Parent;
  end;
  Result := IncludeTrailingPathDelimiter(ExtractFilePath(ParamStr(0)));
end;

function CompatibleSettingsBase(const Preferred: string): string;
var
  Parent, Candidate, Name: string;

  function HasSettings(const Folder: string): Boolean;
  begin
    Result := TFile.Exists(TPlatformPath.Combine(Folder, ConfigFileName)) or
      TFile.Exists(TPlatformPath.Combine(Folder, LegacyConfigFileName)) or
      TFile.Exists(TPlatformPath.Combine(Folder, 'RetroScraper.legacy.config.json'));
  end;

begin
  Result := Preferred;
  if HasSettings(Preferred) then
    Exit;
  Parent := TDirectory.GetParent(ExcludeTrailingPathDelimiter(Preferred));
  for Name in TArray<string>.Create('SkraperFMX', 'RetroScraperFMX') do
  begin
    Candidate := TPlatformPath.Combine(Parent, Name);
    if HasSettings(Candidate) then
      Exit(Candidate);
  end;
end;

function UserDataBase: string;
var
{$IFDEF MSWINDOWS}
  Folder: array[0..MAX_PATH] of Char;
{$ELSE}
  Home: string;
{$ENDIF}
begin
  {$IFDEF MSWINDOWS}
  // Resolve the current user's known folder, never the executable directory.
  OleCheck(SHGetFolderPath(0, CSIDL_LOCAL_APPDATA or CSIDL_FLAG_CREATE, 0, 0, Folder));
  Result := TPlatformPath.Combine(string(Folder), AppDataDirectoryName);
  {$ELSE}
  Home := GetEnvironmentVariable('HOME');
  if Home = '' then
    raise Exception.Create('HOME is not configured');
  {$IFDEF MACOS}
  Result := TPlatformPath.Combine(Home, 'Library/Application Support/' + AppDataDirectoryName);
  {$ELSE}
  Result := GetEnvironmentVariable('XDG_DATA_HOME');
  if (Result = '') or not TPath.IsPathRooted(Result) then
    Result := TPlatformPath.Combine(Home, '.local/share');
  Result := TPlatformPath.Combine(Result, AppDataDirectoryName);
  {$ENDIF}
  {$ENDIF}
  Result := IncludeTrailingPathDelimiter(Result);
end;

function LegacyWritableBase: string;
var
  Project: string;
begin
  {$IFDEF MSWINDOWS}
  Project := SourceProjectBase;
  if Project <> '' then
    Result := TPlatformPath.Combine(Project, 'dist/Data')
  else
    Result := TPlatformPath.Combine(ExtractFilePath(ParamStr(0)), 'Data');
  {$ELSE}
  Result := CompatibleSettingsBase(UserDataBase);
  {$ENDIF}
  Result := IncludeTrailingPathDelimiter(Result);
end;

procedure CheckWritablePath(const Path: string);
var
  Folder, Assets, Candidate, Parent: string;
begin
  if Path.Trim = '' then
    raise EArgumentException.Create('A writable path is required');
  Folder := ExcludeTrailingPathDelimiter(ExtractFilePath(ParamStr(0)));
  Assets := ExcludeTrailingPathDelimiter(ResourceBase);
  Candidate := TPath.GetFullPath(NativePath(Path));
  repeat
    if SamePath(Candidate, Folder) or IsPathWithin(Candidate, Folder) or
      SamePath(Candidate, Assets) or IsPathWithin(Candidate, Assets) then
      raise EArgumentException.Create('Writing inside the application or resource directory is not allowed: ' + Path);
    // Reject aliases through junctions/symlinks rather than bypassing protection.
    if (TDirectory.Exists(Candidate) or TFile.Exists(Candidate)) and DirectoryLink(Candidate) then
      raise EArgumentException.Create('Writable paths must not pass through directory links: ' + Path);
    Parent := TDirectory.GetParent(Candidate);
    if (Parent = '') or SamePath(Parent, Candidate) then
      Break;
    Candidate := Parent;
  until False;
end;

function WritableBase: string;
var
  TestBase: string;
begin
  Result := UserDataBase;
  if FindCmdLineSwitch('selftest') or FindCmdLineSwitch('paritytest') or FindCmdLineSwitch('editvisibilitytest') or
    FindCmdLineSwitch('wizardconcepttest') or FindCmdLineSwitch('directorytest') or FindCmdLineSwitch('librarytest') then
  begin
    TestBase := GetEnvironmentVariable('RETROSCRAPER_TEST_DATA');
    if TestBase = '' then
      TestBase := GetEnvironmentVariable('SKRAPERFMX_TEST_DATA');
    if TestBase = '' then
      TestBase := TPlatformPath.Combine(Result, 'Tests/AppData');
    Result := TPath.GetFullPath(TestBase);
  end;
  CheckWritablePath(Result);
  ForceDirectories(Result);
  Result := IncludeTrailingPathDelimiter(Result);
end;

var
  TemporaryGuard: TObject;
  TemporarySession: string;

function SessionTemporaryBase: string;
begin
  TMonitor.Enter(TemporaryGuard);
  try
    if TemporarySession = '' then
    begin
      TemporarySession := TPlatformPath.Combine(WritableBase, 'Temp/' + TGUID.NewGuid.ToString);
      CheckWritablePath(TemporarySession);
      ForceDirectories(TemporarySession);
    end;
    Result := TemporarySession;
  finally
    TMonitor.Exit(TemporaryGuard);
  end;
end;

{$IFDEF MSWINDOWS}
type
  TDataBlob = record
    cbData: DWORD;
    pbData: PByte;
  end;

function CryptProtectData(var InData: TDataBlob; Description: PWideChar; Entropy, Reserved, Prompt: Pointer; Flags: DWORD; var OutData: TDataBlob): BOOL; stdcall; external 'crypt32.dll';

function CryptUnprotectData(var InData: TDataBlob; Description: Pointer; Entropy, Reserved, Prompt: Pointer; Flags: DWORD; var OutData: TDataBlob): BOOL; stdcall; external 'crypt32.dll';

procedure AtomicReplace(const Temporary, Destination: string);
begin
  CheckWritablePath(Destination);
  CheckWritablePath(Temporary);
  if not MoveFileEx(PChar(Temporary), PChar(Destination), MOVEFILE_REPLACE_EXISTING or MOVEFILE_WRITE_THROUGH) then
    RaiseLastOSError;
end;

procedure BeginWorkerPlatform;
begin
  OleCheck(CoInitializeEx(nil, COINIT_MULTITHREADED))
end;

procedure EndWorkerPlatform;
begin
  CoUninitialize
end;

function LoadSecret(const Identity: string): string;
var
  B: TBytes;
  Input, Output: TDataBlob;
begin
  Result := '';
  if not TFile.Exists(Identity) then
    Exit;
  B := TFile.ReadAllBytes(Identity);
  if Length(B) = 0 then
    Exit;
  Input.cbData := Length(B);
  Input.pbData := @B[0];
  if not CryptUnprotectData(Input, nil, nil, nil, nil, 1, Output) then
    raise Exception.Create('Cannot unlock saved credentials for this Windows account');
  try
    SetLength(B, Output.cbData);
    if Length(B) > 0 then
      Move(Output.pbData^, B[0], Length(B));
    Result := TEncoding.UTF8.GetString(B);
  finally
    LocalFree(HLOCAL(Output.pbData))
  end;
end;

procedure SaveSecret(const Identity, Value: string);
var
  B: TBytes;
  Input, Output: TDataBlob;
  Temporary: string;
begin
  CheckWritablePath(Identity);
  B := TEncoding.UTF8.GetBytes(Value);
  if Length(B) = 0 then
    raise Exception.Create('Empty credentials');
  Input.cbData := Length(B);
  Input.pbData := @B[0];
  if not CryptProtectData(Input, PChar(AppBrand), nil, nil, nil, 1, Output) then
    RaiseLastOSError;
  Temporary := Identity + '.' + TGUID.NewGuid.ToString + '.tmp';
  try
    SetLength(B, Output.cbData);
    if Length(B) > 0 then
      Move(Output.pbData^, B[0], Length(B));
    TFile.WriteAllBytes(Temporary, B);
    AtomicReplace(Temporary, Identity);
  finally
    LocalFree(HLOCAL(Output.pbData));
    if TFile.Exists(Temporary) then
      TFile.Delete(Temporary);
  end;
end;

procedure OpenExternalURL(const URL: string);
begin
  if not URL.StartsWith('https://', True) then
    raise Exception.Create('Expected HTTPS URL');
  if NativeInt(ShellExecute(0, 'open', PChar(URL), nil, nil, SW_SHOWNORMAL)) <= 32 then
    raise Exception.Create('Could not open browser');
end;

function CloseWindow(Wnd: HWND; Param: LPARAM): BOOL; stdcall;
var
  PID: DWORD;
begin
  GetWindowThreadProcessId(Wnd, PID);
  if PID = DWORD(Param) then
    PostMessage(Wnd, WM_CLOSE, 0, 0);
  Result := True;
end;

function WaitFrontend(Handle: THandle; Timeout: Cardinal; Cancel: TFunc<Boolean>): DWORD;
var
  Started: UInt64;
begin
  Started := TThread.GetTickCount64;
  repeat
    if Assigned(Cancel) and Cancel() then
      raise EAbort.Create('Cancelled');
    Result := WaitForSingleObject(Handle, 50);
    if Result = WAIT_FAILED then
      RaiseLastOSError;
    if Result <> WAIT_TIMEOUT then
      Exit;
  until TThread.GetTickCount64 - Started >= Timeout;
end;

procedure StopRemoteProcess(const Host: string; Cancel: TFunc<Boolean>);
var
  Binary, Command, WindowsFolder: string;
  SI: TStartupInfo;
  PI: TProcessInformation;
  ExitStatus: DWORD;
  Buffer: array[0..MAX_PATH] of Char;
begin
  GetWindowsDirectory(Buffer, Length(Buffer));
  WindowsFolder := Buffer;
  Binary := TPath.Combine(WindowsFolder, 'Sysnative\OpenSSH\ssh.exe');
  if not TFile.Exists(Binary) then
    Binary := TPath.Combine(WindowsFolder, 'System32\OpenSSH\ssh.exe');
  if not TFile.Exists(Binary) then
    raise Exception.Create('Windows OpenSSH client is not installed.');
  // Use the user's existing SSH keys and known_hosts; never prompt for a password in a hidden process.
  Command := '"' + Binary + '" -o BatchMode=yes -o StrictHostKeyChecking=yes -o ConnectTimeout=' + IntToStr(SSHConnectTimeoutSeconds) + ' "' + Host + '" "pkill -TERM -x emulationstation"';
  UniqueString(Command);
  FillChar(SI, SizeOf(SI), 0);
  SI.cb := SizeOf(SI);
  SI.dwFlags := STARTF_USESHOWWINDOW;
  SI.wShowWindow := SW_HIDE;
  FillChar(PI, SizeOf(PI), 0);
  if not CreateProcess(PChar(Binary), PChar(Command), nil, nil, False, CREATE_NO_WINDOW, nil, nil, SI, PI) then
    RaiseLastOSError;
  try
    if WaitFrontend(PI.hProcess, SSHTimeoutMs, Cancel) = WAIT_TIMEOUT then
    begin
      TerminateProcess(PI.hProcess, 1);
      raise Exception.Create('SSH timeout. Check the host and key authentication.');
    end;
    if not GetExitCodeProcess(PI.hProcess, ExitStatus) then
      RaiseLastOSError;
    if not (ExitStatus in [0, 1]) then
      raise Exception.Create('SSH could not stop EmulationStation. Check key authentication and known_hosts.');
  finally
    if WaitForSingleObject(PI.hProcess, 0) = WAIT_TIMEOUT then
      TerminateProcess(PI.hProcess, 1);
    CloseHandle(PI.hThread);
    CloseHandle(PI.hProcess);
  end;
end;

procedure StopNamedProcess(const Name: string; const Log: TProc<string>; Cancel: TFunc<Boolean>);
var
  Snap, ProcHandle: THandle;
  Entry: TProcessEntry32;
begin
  if Assigned(Cancel) and Cancel() then
    raise EAbort.Create('Cancelled');
  Snap := CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0);
  if Snap = INVALID_HANDLE_VALUE then
    RaiseLastOSError;
  try
    Entry.dwSize := SizeOf(Entry);
    if Process32First(Snap, Entry) then
      repeat
        if SameText(Entry.szExeFile, Name) then
        begin
          if Assigned(Log) then
            Log('Closing ' + Name);
          ProcHandle := OpenProcess(SYNCHRONIZE or PROCESS_TERMINATE, False, Entry.th32ProcessID);
          if ProcHandle = 0 then
            RaiseLastOSError;
          try
            EnumWindows(@CloseWindow, Entry.th32ProcessID);
            if WaitFrontend(ProcHandle, FrontendStopTimeoutMs, Cancel) = WAIT_TIMEOUT then
            begin
              if not TerminateProcess(ProcHandle, 0) then
                RaiseLastOSError;
              WaitFrontend(ProcHandle, FrontendStopTimeoutMs, Cancel);
            end;
          finally
            CloseHandle(ProcHandle);
          end;
        end;
      until not Process32Next(Snap, Entry);
  finally
    CloseHandle(Snap);
  end;
end;

{$ELSE}
function NativeSpawn(var PID: Integer; Path: MarshaledAString; Actions, Attributes: Pointer; Args, Environment: PMarshaledAString): Integer; cdecl; external libc name _PU + 'posix_spawn';

procedure AtomicReplace(const Temporary, Destination: string);
begin
  CheckWritablePath(Destination);
  CheckWritablePath(Temporary);
  if Posix.Stdio.__rename(MarshaledAString(UTF8String(Temporary)), MarshaledAString(UTF8String(Destination))) <> 0 then
    RaiseLastOSError;
end;

procedure BeginWorkerPlatform;
begin
end;

procedure EndWorkerPlatform;
begin
end;

function RunNative(const Binary: string; const Arguments: array of string; Timeout: UInt64; Cancel: TFunc<Boolean>): Integer;
var
  Values, EnvValues: TArray<UTF8String>;
  Args, Env: TArray<MarshaledAString>;
  I, PID, Status, Code: Integer;
  Started: UInt64;
  Reaped: Boolean;
  Value: string;
begin
  if Assigned(Cancel) and Cancel() then
    raise EAbort.Create('Cancelled');
  SetLength(Values, Length(Arguments) + 1);
  SetLength(Args, Length(Values) + 1);
  Values[0] := UTF8String(Binary);
  for I := 0 to High(Arguments) do
    Values[I + 1] := UTF8String(Arguments[I]);
  for I := 0 to High(Values) do
    Args[I] := MarshaledAString(Values[I]);
  SetLength(EnvValues, Length(ProcessEnvironmentNames));
  SetLength(Env, Length(ProcessEnvironmentNames) + 1);
  for I := 0 to High(ProcessEnvironmentNames) do
  begin
    Value := GetEnvironmentVariable(ProcessEnvironmentNames[I]);
    EnvValues[I] := UTF8String(ProcessEnvironmentNames[I] + '=' + Value);
    Env[I] := MarshaledAString(EnvValues[I]);
  end;
  Code := NativeSpawn(PID, Args[0], nil, nil, @Args[0], @Env[0]);
  if Code <> 0 then
    raise EOSError.CreateFmt('Cannot start %s (error %d)', [Binary, Code]);
  Reaped := False;
  Started := TThread.GetTickCount64;
  try
    repeat
      Code := waitpid(PID, @Status, WNOHANG);
      if Code = PID then
      begin
        Reaped := True;
        Break
      end;
      if (Code < 0) and (errno <> EINTR) then
      begin
        // Another reaper may have consumed it; never signal a recycled PID.
        if errno = ECHILD then
          Reaped := True;
        RaiseLastOSError;
      end;
      if Assigned(Cancel) and Cancel() then
        raise EAbort.Create('Cancelled');
      if TThread.GetTickCount64 - Started >= Timeout then
        raise Exception.Create('Process timed out: ' + Binary);
      TThread.Sleep(ProcessPollMs);
    until False;
    if not WIFEXITED(Status) then
      raise Exception.Create('Process terminated by signal: ' + Binary);
    Result := WEXITSTATUS(Status);
  finally
    if not Reaped then
    begin
      kill(PID, SIGKILL);
      while (waitpid(PID, @Status, 0) < 0) and (errno = EINTR) do
        ;
    end;
  end;
end;

procedure StopRemoteProcess(const Host: string; Cancel: TFunc<Boolean>);
var
  Code: Integer;
begin
  Code := RunNative(PosixSSHPath, ['-o', 'BatchMode=yes', '-o', 'StrictHostKeyChecking=yes',
      '-o', 'ConnectTimeout=' + IntToStr(SSHConnectTimeoutSeconds), Host, 'pkill -TERM -x emulationstation'], SSHTimeoutMs, Cancel);
  if not (Code in [0, 1]) then
    raise Exception.Create('SSH could not stop EmulationStation');
end;

procedure StopNamedProcess(const Name: string; const Log: TProc<string>; Cancel: TFunc<Boolean>);
var
  Code: Integer;
  UserID, Pattern: string;
  Ch: Char;
  Started: UInt64;
begin
  if (Name = '') or Name.StartsWith('-') then
    raise EArgumentException.Create('Invalid process name');
  // pkill/pgrep always parse their operand as an extended regular expression.
  Pattern := '';
  for Ch in Name do
  begin
    if CharInSet(Ch, ['\', '.', '[', ']', '(', ')', '{', '}', '*', '+', '?', '^', '$', '|']) then
      Pattern := Pattern + '\';
    Pattern := Pattern + Ch;
  end;
  UserID := UIntToStr(geteuid);
  Code := RunNative(PosixProcessKillPath, ['-TERM', '-u', UserID, '-x', Pattern], FrontendStopTimeoutMs, Cancel);
  if Code = 1 then
    Exit;
  if Code <> 0 then
    raise Exception.Create('Cannot request frontend shutdown');
  if Assigned(Log) then
    Log('Closing ' + Name);
  Started := TThread.GetTickCount64;
  repeat
    Code := RunNative(PosixProcessQueryPath, ['-u', UserID, '-x', Pattern], FrontendStopTimeoutMs, Cancel);
    if Code = 1 then
      Exit;
    if Code <> 0 then
      raise Exception.Create('Cannot check frontend process');
    TThread.Sleep(FrontendPollMs);
  until TThread.GetTickCount64 - Started >= FrontendStopTimeoutMs;
  Code := RunNative(PosixProcessKillPath, ['-KILL', '-u', UserID, '-x', Pattern], FrontendStopTimeoutMs, Cancel);
  if not (Code in [0, 1]) then
    raise Exception.Create('Cannot stop frontend process');
end;

procedure OpenExternalURL(const URL: string);
var
  Code: Integer;
begin
  if not URL.StartsWith('https://', True) then
    raise Exception.Create('Expected HTTPS URL');
  {$IFDEF MACOS}
  Code := RunNative(MacOSOpenPath, [URL], BrowserTimeoutMs, nil);
  {$ELSE}
  Code := RunNative(LinuxOpenPath, [URL], BrowserTimeoutMs, nil);
  {$ENDIF}
  if Code <> 0 then
    raise Exception.Create('Could not open browser');
end;

{$IFDEF MACOS}

function FindPassword(Keychain: Pointer; ServiceLength: Cardinal; Service: MarshaledAString; AccountLength: Cardinal; Account: MarshaledAString; var PasswordLength: Cardinal; var Password, Item: Pointer): Integer; cdecl; external SecurityFramework name 'SecKeychainFindGenericPassword';

function AddPassword(Keychain: Pointer; ServiceLength: Cardinal; Service: MarshaledAString; AccountLength: Cardinal; Account: MarshaledAString; PasswordLength: Cardinal; Password: Pointer; Item: Pointer): Integer; cdecl; external SecurityFramework name 'SecKeychainAddGenericPassword';

function ModifyPassword(Item, Attributes: Pointer; Length: Cardinal; Data: Pointer): Integer; cdecl; external SecurityFramework name 'SecKeychainItemModifyAttributesAndData';

function FreePassword(Attributes, Data: Pointer): Integer; cdecl; external SecurityFramework name 'SecKeychainItemFreeContent';

procedure ReleaseCF(Value: Pointer); cdecl; external '/System/Library/Frameworks/CoreFoundation.framework/CoreFoundation' name 'CFRelease';

function MacSecret(const Identity, Value: string; WriteAccess: Boolean): string;
var
  Key, Service, Secret: UTF8String;
  Data, Item: Pointer;
  Size: Cardinal;
  Code: Integer;
begin
  Result := '';
  Key := UTF8String(THashSHA2.GetHashString(Identity));
  Service := CredentialServiceID;
  Data := nil;
  Item := nil;
  Size := 0;
  Code := FindPassword(nil, Length(Service), MarshaledAString(Service), Length(Key), MarshaledAString(Key), Size, Data, Item);
  try
    if (Code <> 0) and (Code <> errSecItemNotFound) then
      raise Exception.CreateFmt('Keychain access failed (%d)', [Code]);

    if WriteAccess then
    begin
      Secret := UTF8String(Value);
      if Code = errSecItemNotFound then
        Code := AddPassword(nil, Length(Service), MarshaledAString(Service), Length(Key), MarshaledAString(Key), Length(Secret), Pointer(Secret), nil)
      else
        Code := ModifyPassword(Item, nil, Length(Secret), Pointer(Secret));
      if Code <> 0 then
        raise Exception.CreateFmt('Cannot save Keychain credentials (%d)', [Code]);
    end
    else if Code = 0 then
    begin
      SetString(Secret, MarshaledAString(Data), Size);
      Result := string(Secret)
    end;
  finally
    if Data <> nil then
      FreePassword(nil, Data);
    if Item <> nil then
      ReleaseCF(Item);
  end;
end;

function NativeLoadSecret(const Identity: string): string;
begin
  Result := MacSecret(Identity, '', False)
end;

procedure NativeSaveSecret(const Identity, Value: string);
begin
  MacSecret(Identity, Value, True)
end;
{$ELSE}

type
  THashNew = function(Hash, Equal: Pointer): Pointer; cdecl;

  THashInsert = function(Table, Key, Value: Pointer): Integer; cdecl;

  TNativeFree = procedure(Value: Pointer); cdecl;

  TPasswordLookup = function(Schema, Attributes, Cancel: Pointer; var Error: Pointer): MarshaledAString; cdecl;

  TPasswordStore = function(Schema, Attributes: Pointer; Collection, LabelText, Password: MarshaledAString; Cancel: Pointer; var Error: Pointer): Integer; cdecl;

function LinuxSecret(const Identity, Value: string; WriteAccess: Boolean): string;
var
  Lib: NativeUInt;
  Attributes, Error: Pointer;
  NewHash: THashNew;
  Insert: THashInsert;
  FreeHash, FreePassword, FreeError: TNativeFree;
  Lookup: TPasswordLookup;
  StorePassword: TPasswordStore;
  Key, Secret: UTF8String;
  Password: MarshaledAString;
begin
  Result := '';
  Lib := dlopen(LinuxSecretLibrary, RTLD_LAZY);
  if Lib = 0 then
  begin
    if WriteAccess then
      raise Exception.Create('Install libsecret and unlock a Secret Service keyring to save credentials');

    Exit;
  end;
  try
    NewHash := THashNew(dlsym(Lib, 'g_hash_table_new'));
    Insert := THashInsert(dlsym(Lib, 'g_hash_table_insert'));
    FreeHash := TNativeFree(dlsym(Lib, 'g_hash_table_unref'));
    FreePassword := TNativeFree(dlsym(Lib, 'secret_password_free'));
    FreeError := TNativeFree(dlsym(Lib, 'g_error_free'));
    Lookup := TPasswordLookup(dlsym(Lib, 'secret_password_lookupv_sync'));
    StorePassword := TPasswordStore(dlsym(Lib, 'secret_password_storev_sync'));
    if not Assigned(NewHash) or not Assigned(Insert) or not Assigned(FreeHash) or not Assigned(FreePassword) or
      not Assigned(FreeError) or not Assigned(Lookup) or not Assigned(StorePassword) then
      raise Exception.Create('Incompatible libsecret installation');

    Attributes := NewHash(dlsym(Lib, 'g_str_hash'), dlsym(Lib, 'g_str_equal'));
    if Attributes = nil then
      raise Exception.Create('Cannot allocate secret attributes');

    Error := nil;
    try
      Key := UTF8String(THashSHA2.GetHashString(Identity));
      Secret := UTF8String(Value);
      Insert(Attributes, MarshaledAString('application'), MarshaledAString(CredentialServiceID));
      Insert(Attributes, MarshaledAString('account'), MarshaledAString(Key));
      // Use non-variadic APIs: their ABI is identical across Delphi/C compilers.
      if WriteAccess then
      begin
        if StorePassword(nil, Attributes, nil, AppBrand + ' ScreenScraper', MarshaledAString(Secret), nil, Error) = 0 then
          raise Exception.Create('Cannot save credentials: unlock the desktop keyring');
      end
      else
      begin
        Password := Lookup(nil, Attributes, nil, Error);
        try
          if Error <> nil then
            raise Exception.Create('Cannot read credentials: unlock the desktop keyring');
          if Password <> nil then
            Result := string(UTF8String(Password));
        finally
          if Password <> nil then
            FreePassword(Password)
        end;
      end;
    finally
      if Error <> nil then
        FreeError(Error);
      FreeHash(Attributes);
    end;
  finally
    dlclose(Lib)
  end;
end;

function NativeLoadSecret(const Identity: string): string;
begin
  Result := LinuxSecret(Identity, '', False)
end;

procedure NativeSaveSecret(const Identity, Value: string);
begin
  LinuxSecret(Identity, Value, True)
end;
{$ENDIF}

function LoadSecret(const Identity: string): string;
begin
  Result := '';
  // A fresh installation must not contact or unlock a keyring before an account is saved.
  if TFile.Exists(Identity) then
    Result := NativeLoadSecret(Identity);
end;

procedure SaveSecret(const Identity, Value: string);
var
  Temporary: string;
begin
  CheckWritablePath(Identity);
  NativeSaveSecret(Identity, Value);
  Temporary := Identity + '.' + TGUID.NewGuid.ToString + '.tmp';
  try
    TFile.WriteAllText(Temporary, CredentialMarker, TEncoding.UTF8);
    AtomicReplace(Temporary, Identity);
  finally
    if TFile.Exists(Temporary) then
      TFile.Delete(Temporary);
  end;
end;
{$ENDIF}

initialization
  TemporaryGuard := TObject.Create;

finalization
  if (TemporarySession <> '') and TDirectory.Exists(TemporarySession) then
  try
    TDirectory.Delete(TemporarySession, True);
  except
    // The next launch uses a distinct session; never touch another process's files.
  end;
  TemporaryGuard.Free;

end.
