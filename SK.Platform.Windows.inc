type
  TDataBlob = record
    cbData: DWORD;
    pbData: PByte;
  end;

function CryptProtectData(var InData: TDataBlob; Description: PWideChar; Entropy, Reserved, Prompt: Pointer; Flags: DWORD; var OutData: TDataBlob): BOOL; stdcall; external 'crypt32.dll';

function CryptUnprotectData(var InData: TDataBlob; Description: Pointer; Entropy, Reserved, Prompt: Pointer; Flags: DWORD; var OutData: TDataBlob): BOOL; stdcall; external 'crypt32.dll';

procedure AtomicReplace(const Temporary, Destination: string);
begin
  if not MoveFileEx(PChar(Temporary),PChar(Destination),MOVEFILE_REPLACE_EXISTING or MOVEFILE_WRITE_THROUGH) then RaiseLastOSError;
end;
procedure BeginWorkerPlatform;
begin OleCheck(CoInitializeEx(nil, COINIT_MULTITHREADED)) end;
procedure EndWorkerPlatform;
begin CoUninitialize end;
function LoadSecret(const Identity: string): string;
var B: TBytes; Input, Output: TDataBlob;
begin
  Result := '';
  if not TFile.Exists(Identity) then Exit;
  B := TFile.ReadAllBytes(Identity);
  if Length(B)=0 then Exit;
  Input.cbData := Length(B); Input.pbData := @B[0];
  if not CryptUnprotectData(Input,nil,nil,nil,nil,1,Output) then
    raise Exception.Create('Cannot unlock saved credentials for this Windows account');
  try
    SetLength(B,Output.cbData);
    if Length(B)>0 then Move(Output.pbData^,B[0],Length(B));
    Result := TEncoding.UTF8.GetString(B);
  finally LocalFree(HLOCAL(Output.pbData)) end;
end;
procedure SaveSecret(const Identity, Value: string);
var B: TBytes; Input, Output: TDataBlob; Temporary: string;
begin
  B := TEncoding.UTF8.GetBytes(Value);
  if Length(B)=0 then raise Exception.Create('Empty credentials');
  Input.cbData := Length(B); Input.pbData := @B[0];
  if not CryptProtectData(Input,PChar(AppBrand),nil,nil,nil,1,Output) then RaiseLastOSError;
  Temporary := Identity + '.' + TGUID.NewGuid.ToString + '.tmp';
  try
    SetLength(B,Output.cbData);
    if Length(B)>0 then Move(Output.pbData^,B[0],Length(B));
    TFile.WriteAllBytes(Temporary,B);
    AtomicReplace(Temporary,Identity);
  finally
    LocalFree(HLOCAL(Output.pbData));
    if TFile.Exists(Temporary) then TFile.Delete(Temporary);
  end;
end;
procedure OpenExternalURL(const URL: string);
begin
  if not URL.StartsWith('https://',True) then raise Exception.Create('Expected HTTPS URL');
  if NativeInt(ShellExecute(0,'open',PChar(URL),nil,nil,SW_SHOWNORMAL))<=32 then
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
    if Result = WAIT_FAILED then RaiseLastOSError;
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
  Command := '"' + Binary + '" -o BatchMode=yes -o StrictHostKeyChecking=yes -o ConnectTimeout=10 "' + Host + '" "pkill -TERM -x emulationstation"';
  UniqueString(Command);
  FillChar(SI, SizeOf(SI), 0);
  SI.cb := SizeOf(SI);
  SI.dwFlags := STARTF_USESHOWWINDOW;
  SI.wShowWindow := SW_HIDE;
  FillChar(PI, SizeOf(PI), 0);
  Win32Check(CreateProcess(PChar(Binary), PChar(Command), nil, nil, False, CREATE_NO_WINDOW, nil, nil, SI, PI));
  try
    if WaitFrontend(PI.hProcess, 15000, Cancel) = WAIT_TIMEOUT then
    begin
      TerminateProcess(PI.hProcess, 1);
      raise Exception.Create('SSH timeout. Check the host and key authentication.');
    end;
    Win32Check(GetExitCodeProcess(PI.hProcess, ExitStatus));
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
  Win32Check(Snap <> INVALID_HANDLE_VALUE);
  try
    Entry.dwSize := SizeOf(Entry);
    if Process32First(Snap, Entry) then
      repeat
        if SameText(Entry.szExeFile, Name) then
        begin
          if Assigned(Log) then Log('Closing ' + Name);
          ProcHandle := OpenProcess(SYNCHRONIZE or PROCESS_TERMINATE, False, Entry.th32ProcessID);
          Win32Check(ProcHandle <> 0);
          try
            EnumWindows(@CloseWindow, Entry.th32ProcessID);
            if WaitFrontend(ProcHandle, 5000, Cancel) = WAIT_TIMEOUT then
            begin
              Win32Check(TerminateProcess(ProcHandle, 0));
              WaitFrontend(ProcHandle, 5000, Cancel);
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

