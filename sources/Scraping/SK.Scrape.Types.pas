unit SK.Scrape.Types;

interface

uses
  System.SysUtils, System.SyncObjs;

type
  TEngineStatus = record
    Stage, FileName, SystemName: string;
    CurrentMedia, MediaTotal: Integer;
    Running: Boolean;
  end;

  TInputQueue = class
  private
    FNext: Integer;
    FStopped: Integer;
    FStopReason: string;
    function GetStopped: Boolean;
    function GetStopReason: string;
  public
    Files: TArray<string>;
    constructor Create(const InputFiles: TArray<string>);
    function Pop(out FileName: string): Boolean;
    procedure Stop(const Reason: string);
    property Stopped: Boolean read GetStopped;
    property StopReason: string read GetStopReason;
  end;

  TScrapeStatus = record
    Running, Finished, Cancelled, CanResume: Boolean;
    Total, Completed, Found, Missing, Errors, Downloaded, Saved, Requests, Cached, Favorites, Hidden: Integer;
    SystemsTotal, SystemsCompleted: Integer;
    CurrentSystem, CurrentSystemID, CurrentFile, LastError, Stage: string;
    CurrentTotal, CurrentCompleted, CurrentMedia, MediaTotal, MediaFound, MediaRequested: Integer;
    PreviewData: array[0..2] of TBytes;
    PreviewRevision: array[0..2] of Int64;
    PreviewSource: array[0..2] of string;
    QuotaText, KOQuotaText: string;
    QuotaUpdated: TDateTime;
    Started, FinishedAt: TDateTime;
    Engines: TArray<TEngineStatus>;
  end;

implementation

constructor TInputQueue.Create(const InputFiles: TArray<string>);
begin
  inherited Create;
  Files := InputFiles;
  FNext := -1
end;

function TInputQueue.Pop(out FileName: string): Boolean;
var
  i: Integer;
begin
  i := TInterlocked.Increment(FNext);
  Result := not Stopped and (i < Length(Files));
  if Result then
    FileName := Files[i]
end;

function TInputQueue.GetStopped: Boolean;
begin
  Result := TInterlocked.CompareExchange(FStopped, 0, 0) <> 0;
end;

function TInputQueue.GetStopReason: string;
begin
  TMonitor.Enter(Self);
  try
    Result := FStopReason;
  finally
    TMonitor.Exit(Self);
  end;
end;

procedure TInputQueue.Stop(const Reason: string);
begin
  TMonitor.Enter(Self);
  try
    if not Stopped then
    begin
      FStopReason := Reason;
      TInterlocked.Exchange(FStopped, 1);
    end;
  finally
    TMonitor.Exit(Self);
  end;
end;

end.
