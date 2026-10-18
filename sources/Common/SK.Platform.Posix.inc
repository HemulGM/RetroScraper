function NativeSpawn(var PID: Integer; Path: MarshaledAString; Actions, Attributes: Pointer;
  Args, Environment: PMarshaledAString): Integer; cdecl; external libc name _PU + 'posix_spawn';
procedure AtomicReplace(const Temporary, Destination: string);
begin
  if Posix.Stdio.__rename(MarshaledAString(UTF8String(Temporary)),MarshaledAString(UTF8String(Destination)))<>0 then RaiseLastOSError;
end;
procedure BeginWorkerPlatform;
begin end;
procedure EndWorkerPlatform;
begin end;
function RunNative(const Binary: string; const Arguments: array of string; Timeout: UInt64; Cancel: TFunc<Boolean>): Integer;
const Names: array[0..10] of string = ('HOME','PATH','LANG','DISPLAY','WAYLAND_DISPLAY','XDG_RUNTIME_DIR',
  'DBUS_SESSION_BUS_ADDRESS','SSH_AUTH_SOCK','USER','LOGNAME','XAUTHORITY');
var Values, EnvValues: TArray<UTF8String>; Args, Env: TArray<MarshaledAString>;
  I, PID, Status, Code: Integer; Started: UInt64; Reaped: Boolean; Value: string;
begin
  if Assigned(Cancel) and Cancel() then raise EAbort.Create('Cancelled');
  SetLength(Values,Length(Arguments)+1); SetLength(Args,Length(Values)+1);
  Values[0] := UTF8String(Binary);
  for I:=0 to High(Arguments) do Values[I+1]:=UTF8String(Arguments[I]);
  for I:=0 to High(Values) do Args[I]:=MarshaledAString(Values[I]);
  SetLength(EnvValues,Length(Names)); SetLength(Env,Length(Names)+1);
  for I:=0 to High(Names) do begin
    Value:=GetEnvironmentVariable(Names[I]);
    EnvValues[I]:=UTF8String(Names[I]+'='+Value); Env[I]:=MarshaledAString(EnvValues[I]);
  end;
  Code:=NativeSpawn(PID,Args[0],nil,nil,@Args[0],@Env[0]);
  if Code<>0 then raise EOSError.CreateFmt('Cannot start %s (error %d)',[Binary,Code]);
  Reaped:=False; Started:=TThread.GetTickCount64;
  try
    repeat
      Code:=waitpid(PID,@Status,WNOHANG);
      if Code=PID then begin Reaped:=True; Break end;
      if (Code<0) and (errno<>EINTR) then
      begin
        // Another reaper may have consumed it; never signal a recycled PID.
        if errno=ECHILD then Reaped:=True;
        RaiseLastOSError;
      end;
      if Assigned(Cancel) and Cancel() then raise EAbort.Create('Cancelled');
      if TThread.GetTickCount64-Started>=Timeout then raise Exception.Create('Process timed out: '+Binary);
      TThread.Sleep(25);
    until False;
    if not WIFEXITED(Status) then raise Exception.Create('Process terminated by signal: '+Binary);
    Result:=WEXITSTATUS(Status);
  finally
    if not Reaped then begin
      kill(PID,SIGKILL);
      while (waitpid(PID,@Status,0)<0) and (errno=EINTR) do ;
    end;
  end;
end;
procedure StopRemoteProcess(const Host: string; Cancel: TFunc<Boolean>);
var Code: Integer;
begin
  Code:=RunNative('/usr/bin/ssh',['-o','BatchMode=yes','-o','StrictHostKeyChecking=yes',
    '-o','ConnectTimeout=10',Host,'pkill -TERM -x emulationstation'],15000,Cancel);
  if not (Code in [0,1]) then raise Exception.Create('SSH could not stop EmulationStation');
end;
procedure StopNamedProcess(const Name: string; const Log: TProc<string>; Cancel: TFunc<Boolean>);
var Code: Integer; UserID, Pattern: string; Ch: Char; Started: UInt64;
begin
  if (Name='') or Name.StartsWith('-') then raise EArgumentException.Create('Invalid process name');
  // pkill/pgrep always parse their operand as an extended regular expression.
  Pattern:='';
  for Ch in Name do
  begin
    if CharInSet(Ch,['\','.','[',']','(',')','{','}','*','+','?','^','$','|']) then
      Pattern:=Pattern+'\';
    Pattern:=Pattern+Ch;
  end;
  UserID:=UIntToStr(geteuid);
  Code:=RunNative('/usr/bin/pkill',['-TERM','-u',UserID,'-x',Pattern],5000,Cancel);
  if Code=1 then Exit;
  if Code<>0 then raise Exception.Create('Cannot request frontend shutdown');
  if Assigned(Log) then Log('Closing '+Name);
  Started:=TThread.GetTickCount64;
  repeat
    Code:=RunNative('/usr/bin/pgrep',['-u',UserID,'-x',Pattern],5000,Cancel);
    if Code=1 then Exit;
    if Code<>0 then raise Exception.Create('Cannot check frontend process');
    TThread.Sleep(50);
  until TThread.GetTickCount64-Started>=5000;
  Code:=RunNative('/usr/bin/pkill',['-KILL','-u',UserID,'-x',Pattern],5000,Cancel);
  if not (Code in [0,1]) then raise Exception.Create('Cannot stop frontend process');
end;
procedure OpenExternalURL(const URL: string);
var Code: Integer;
begin
  if not URL.StartsWith('https://',True) then raise Exception.Create('Expected HTTPS URL');
{$IFDEF MACOS}
  Code:=RunNative('/usr/bin/open',[URL],10000,nil);
{$ELSE}
  Code:=RunNative('/usr/bin/xdg-open',[URL],10000,nil);
{$ENDIF}
  if Code<>0 then raise Exception.Create('Could not open browser');
end;
