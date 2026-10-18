unit SK.Tests;

interface

procedure RunSelfTests;

implementation

uses
  SK.Platform.Tests, System.SysUtils, System.Math, System.Classes, System.JSON,
  System.IOUtils, System.Hash, System.Generics.Collections, System.Zip,
  Xml.XMLDoc, Xml.XMLIntf, FMX.Forms, System.Types, FMX.Types, FMX.Graphics,
  FMX.Controls, FMX.ListBox, FMX.Layouts, FMX.StdCtrls, FMX.TabControl, SK.Json,
  SK.Configuration, SK.ScreenScraper, SK.Storage, SK.GameList, SK.Metadata,
  SK.Engine, SK.Mix, SK.Main, SK.Setup, SK.Frontend, SK.Input, SK.Features.Tests,
  SK.Catalog, SK.Platform, SK.Consts, System.SyncObjs;

type
  TComboWheelAccess = class(TComboBox);

  TScrollWheelAccess = class(TVertScrollBox);

  TButtonInputAccess = class(TButton);

  TRowLifetimeProbe = class(TComponent)
  public
    Removed: Integer;
    procedure Notification(AComponent: TComponent; Operation: TOperation); override;
  end;

procedure TRowLifetimeProbe.Notification(AComponent: TComponent; Operation: TOperation);
begin
  inherited;
  if Operation = opRemove then
    Inc(Removed);
end;

procedure RunQuotaStopRegressions(Report: TStrings);
var
  Code: Integer;
  Context, FileName, Reason: string;
  Rejected: Boolean;
  Queue: TInputQueue;

  procedure Check(Condition: Boolean; const Description: string);
  begin
    if not Condition then
      raise Exception.Create('FAIL: ' + Description);
    Report.Add('PASS: ' + Description);
  end;

begin
  for Context in TArray<string>.Create('ScreenScraper', 'Media') do
    for Code in TArray<Integer>.Create(401, 403, 423, 426, 429, 430, 431) do
    begin
      Rejected := False;
      try
        CheckScreenScraperHTTPStatus(Code, Context);
      except
        on E: EScreenScraperFatal do
          Rejected := (E.StatusCode = Code) and E.Message.Contains(Code.ToString) and E.Message.StartsWith(Context);
      end;
      Check(Rejected, Context + ' HTTP ' + Code.ToString + ' stops scraping with its HTTP code preserved');
    end;
  for Code in TArray<Integer>.Create(200, 404, 500, 503) do
    CheckScreenScraperHTTPStatus(Code, 'ScreenScraper');
  Report.Add('PASS: Successful, missing and transient responses do not stop the entire queue');
  Queue := TInputQueue.Create(TArray<string>.Create('first.rom', 'second.rom', 'third.rom'));
  try
    Check(Queue.Pop(FileName) and (FileName = 'first.rom'), 'Input queue yields games before quota stop');
    Reason := 'ScreenScraper daily scrape quota reached (HTTP 430).';
    Queue.Stop(Reason);
    Check(Queue.Stopped and not Queue.Pop(FileName), 'Quota stop blocks remaining games in the shared queue');
    Queue.Stop('Secondary error');
    Check(Queue.StopReason = Reason, 'Parallel failures preserve the original quota stop reason');
  finally
    Queue.Free;
  end;
end;

procedure RunNetworkQueueRegressions(Report: TStrings);
var
  Gate: TScreenScraperNetworkQueue;
  First, Second, Waiting: TThread;
  Cancelled, Aborted, OrderCount: Integer;
  Order: array[0..1] of Integer;
  Held: Boolean;
  API: TScreenScraper;
  Credentials, Response: TJSONObject;
  Folder: string;
  Started: UInt64;

  procedure Check(Condition: Boolean; const Description: string);
  begin
    if not Condition then
      raise Exception.Create('FAIL: ' + Description);
    Report.Add('PASS: ' + Description);
  end;

  procedure AwaitPending(Count: Integer);
  var
    Start: UInt64;
  begin
    Start := TThread.GetTickCount64;
    while (Gate.PendingCount <> Count) and (TThread.GetTickCount64 - Start < 3000) do
      TThread.Sleep(5);
    Check(Gate.PendingCount = Count, 'Network requests wait when the account slot is occupied');
  end;

  function NewOrderedThread(Number: Integer): TThread;
  begin
    Result := TThread.CreateAnonymousThread(
      procedure
      var
        Index: Integer;
      begin
        Gate.Acquire(
          function: Boolean
          begin
            Result := TInterlocked.CompareExchange(Cancelled, 0, 0) <> 0
          end);
        try
          Index := TInterlocked.Increment(OrderCount) - 1;
          Order[Index] := Number;
          TThread.Sleep(20);
        finally
          Gate.Release;
        end;
      end);
    Result.FreeOnTerminate := False;
    Result.Start;
  end;

  function NewAbortableThread: TThread;
  begin
    Result := TThread.CreateAnonymousThread(
      procedure
      begin
        try
          Gate.Acquire(
            function: Boolean
            begin
              Result := TInterlocked.CompareExchange(Cancelled, 0, 0) <> 0
            end);
          Gate.Release;
        except
          on E: EAbort do
            TInterlocked.Exchange(Aborted, 1);
        end;
      end);
    Result.FreeOnTerminate := False;
    Result.Start;
  end;

  procedure AwaitFinished(Thread: TThread);
  var
    Start: UInt64;
  begin
    Start := TThread.GetTickCount64;
    while not Thread.Finished and (TThread.GetTickCount64 - Start < 3000) do
      TThread.Sleep(5);
    Check(Thread.Finished and (Thread.FatalException = nil), 'Queued network request finishes without an unhandled exception');
    Thread.WaitFor;
  end;

begin
  Gate := TScreenScraperNetworkQueue.Create(1);
  First := nil;
  Second := nil;
  Waiting := nil;
  Cancelled := 0;
  Aborted := 0;
  OrderCount := 0;
  Held := False;
  try
    Gate.Acquire(nil);
    Held := True;
    First := NewOrderedThread(1);
    AwaitPending(1);
    Second := NewOrderedThread(2);
    AwaitPending(2);
    Folder := AppBase + 'tests\output\network-queue-' + TGUID.NewGuid.ToString.Trim(['{', '}']) + '\';
    ForceDirectories(Folder);
    Credentials := TJSONObject.Create;
    API := TScreenScraper.Create(Credentials, Folder);
    Credentials.Free;
    API.NetworkQueue := Gate;
    try
      Response := TJSONObject.ParseJSONValue('{"response":{"jeu":{"id":42}}}') as TJSONObject;
      try
        WriteJSON(Folder + THashSHA2.GetHashString('probe.php?') + '.json', Response)
      finally
        Response.Free
      end;
      Started := TThread.GetTickCount64;
      Response := API.Request('probe.php', '');
      try
        Check((JInt(Response, 'response.jeu.id') = 42) and (API.Requests = 0) and
          (API.CacheHits = 1) and (TThread.GetTickCount64 - Started < 1000),
          'Cached metadata completes while the only network slot and its waiting queue are occupied');
      finally
        Response.Free
      end;
      TFile.WriteAllText(Folder + 'existing.png', 'existing');
      API.Download('https://fixture.invalid/image.png', Folder + 'existing.png');
      Check(Gate.PendingCount = 2, 'Existing media bypasses the network admission queue');
    finally
      API.Free
    end;
    Gate.Release;
    Held := False;
    AwaitFinished(First);
    AwaitFinished(Second);
    Check((OrderCount = 2) and (Order[0] = 1) and (Order[1] = 2), 'Network admission follows FIFO order');
    Gate.Acquire(nil);
    Held := True;
    Waiting := NewAbortableThread;
    AwaitPending(1);
    TInterlocked.Exchange(Cancelled, 1);
    AwaitFinished(Waiting);
    Check((Aborted = 1) and (Gate.PendingCount = 0), 'Cancelling a waiting request removes it without consuming a network slot');
    Waiting.Free;
    Waiting := nil;
    TInterlocked.Exchange(Cancelled, 0);
    TInterlocked.Exchange(Aborted, 0);
    Waiting := NewAbortableThread;
    AwaitPending(1);
    Gate.Stop('HTTP 430');
    Gate.Stop('Secondary error');
    AwaitFinished(Waiting);
    Check((Aborted = 1) and Gate.Stopped and (Gate.StopReason = 'HTTP 430') and (Gate.PendingCount = 0),
      'Quota stop wakes queued requests before the occupied network slot is released');
  finally
    TInterlocked.Exchange(Cancelled, 1);
    if Held then
      Gate.Release;
    if First <> nil then
    begin
      First.WaitFor;
      First.Free
    end;
    if Second <> nil then
    begin
      Second.WaitFor;
      Second.Free
    end;
    if Waiting <> nil then
    begin
      Waiting.WaitFor;
      Waiting.Free
    end;
    Gate.Free;
  end;
  Gate := TScreenScraperNetworkQueue.Create(2);
  Waiting := nil;
  Held := False;
  Cancelled := 0;
  Aborted := 0;
  try
    Gate.Acquire(nil);
    Held := True;
    Gate.Acquire(nil);
    try
      Waiting := NewAbortableThread;
      AwaitPending(1);
    finally
      Gate.Release
    end;
    AwaitFinished(Waiting);
    Check(Aborted = 0, 'Two account slots admit two requests and queue a third until a slot is released');
  finally
    TInterlocked.Exchange(Cancelled, 1);
    if Held then
      Gate.Release;
    if Waiting <> nil then
    begin
      Waiting.WaitFor;
      Waiting.Free
    end;
    Gate.Free;
  end;
end;

procedure RunOriginalFileNameRegressions(Report: TStrings);
var
  Config, Game, Item, Root, Sys: TJSONObject;
  Account: TRetroScraperConfig;
  Folder, Original: string;

  procedure Check(Condition: Boolean; const Description: string);
  begin
    if not Condition then
      raise Exception.Create('FAIL: ' + Description);
    Report.Add('PASS: ' + Description);
  end;

begin
  Config := TJSONObject.Create;
  Game := TJSONObject.ParseJSONValue('{"id":"540620","notgame":"true","noms":[{"region":"ss","text":"ZZZ(notgame):#NONGAME"}]}') as TJSONObject;
  Folder := AppBase + 'tests\output\original-filename-' + TGUID.NewGuid.ToString.Trim(['{', '}']) + '\';
  ForceDirectories(Folder);
  try
    Original := Game.ToJSON;
    Item := DescribeGame(Game, Config, 'LinkWord (1990)(Sega)(USA)(Beta)(Disc 2 of 3).sg');
    try
      Check(JStr(Item, 'name') = 'ZZZ(notgame):#NONGAME', 'Notgame keeps the original service title');
      Check((JStr(Item, 'releasedate') = '') and (JStr(Item, 'publisher') = '') and (JStr(Item, 'region') = ''),
        'Filename does not supply year, publisher or implicit region');
      Check((JStr(Item, 'id') = '540620') and (Game.ToJSON = Original), 'Metadata keeps the service ID and response unchanged');
    finally
      Item.Free;
    end;
    JSet(Config, 'MetaData.KeepUndecoratedFileName', TJSONBool.Create(True));
    Item := DescribeGame(Game, Config, 'LinkWord (1990)(Sega)(USA).sg');
    try
      Check(JStr(Item, 'name') = 'LinkWord', 'Original undecorated filename setting still replaces the service title');
    finally
      Item.Free;
    end;
    JSet(Config, 'MetaData.KeepFileNameDecorations', TJSONBool.Create(True));
    Item := DescribeGame(Game, Config, 'LinkWord (1990)(Sega)(USA).sg');
    try
      Check(JStr(Item, 'name') = 'LinkWord (1990) (Sega) (USA)', 'Original filename decorations remain literal text');
      Check((JStr(Item, 'releasedate') = '') and (JStr(Item, 'publisher') = ''), 'Literal decorations are not converted to metadata');
    finally
      Item.Free;
    end;
    JSet(Config, 'MetaData.KeepFileNameDecorations', TJSONBool.Create(False));
    JSet(Config, 'MetaData.ExtractRegionFromFileName', TJSONBool.Create(True));
    Item := DescribeGame(Game, Config, 'LinkWord (USA).sg');
    try
      Check(JStr(Item, 'region') = 'us', 'Original explicit filename region setting still works');
    finally
      Item.Free;
    end;
    JSet(Config, 'MetaData.ExtractRegionFromFileName', TJSONBool.Create(False));
    JSet(Config, 'MetaData.NameDecorations', TJSONNumber.Create(1027));
    JSet(Config, 'GameList.AutoHideSelection', TJSONNumber.Create(1026));
    Item := DescribeGame(nil, Config, 'Unknown (USA)(Beta)(Disc 2 of 3)(1990)(Sega).rom');
    try
      Check(JStr(Item, 'name') = 'Unknown', 'Missing games use the existing undecorated filename fallback');
      Check((JStr(Item, 'region') = '') and (JStr(Item, 'releasedate') = '') and (JStr(Item, 'publisher') = ''),
        'Missing games receive no synthesized filename metadata');
      Check(not JBool(Item, 'hidden'), 'Filename beta and disc tags do not become automatic filter flags');
    finally
      Item.Free;
    end;
    JSet(Config, 'GameList.AutoHideUnscraped', TJSONBool.Create(True));
    Item := DescribeGame(nil, Config, 'Unknown.rom');
    try
      Check(JBool(Item, 'hidden'), 'Original unscraped-game filter still works');
    finally
      Item.Free;
    end;
    JSet(Config, 'MetaData.KeepUndecoratedFileName', TJSONBool.Create(False));
    JSet(Game, 'noms', TJSONObject.ParseJSONValue('[{"region":"wor","text":"Known game"}]'));
    JSet(Game, 'editeur.text', TJSONString.Create('Known publisher'));
    JSet(Game, 'dates', TJSONObject.ParseJSONValue('[{"region":"wor","text":"1989"}]'));
    Item := DescribeGame(Game, Config, 'Different (1990)(Sega)(Beta).sg');
    try
      Check((JStr(Item, 'name') = 'Known game') and (JStr(Item, 'publisher') = 'Known publisher') and
        (JStr(Item, 'releasedate') = '19890101T000000'), 'Titles, publisher and dates come from the service');
    finally
      Item.Free;
    end;
    Root := ReadJSON(AppBase + 'Resources\default.config.json');
    try
      Check(JValue(Root, 'AllSystems.MetaData.ParseRomFileName') = nil, 'Default configuration contains only original metadata settings');
      JSet(Root, 'ConfigVersion', TJSONNumber.Create(ConfigSchemaVersion));
      JSet(Root, 'AllSystems.MetaData.ParseRomFileName', TJSONBool.Create(True));
      JSet(Root, 'AllSystems.MetaData.KeepUndecoratedFileName', TJSONBool.Create(True));
      Sys := TJSONObject.Create;
      JSet(Sys, 'MetaData.ParseRomFileName', TJSONBool.Create(False));
      JSet(Sys, 'MetaData.ExtractRegionFromFileName', TJSONBool.Create(True));
      JSet(Root, 'Systems', TJSONArray.Create.Add(Sys));
      WriteJSON(Folder + ConfigFileName, Root);
    finally
      Root.Free;
    end;
    Account := TRetroScraperConfig.Create(Folder);
    try
      Check((JValue(Account.Root, 'AllSystems.MetaData.ParseRomFileName') = nil) and
        (JValue(Account.SystemAt(0), 'MetaData.ParseRomFileName') = nil), 'Loading removes the obsolete option from global and system settings');
      Check(JBool(Account.SystemAt(-1), 'MetaData.KeepUndecoratedFileName') and
        JBool(Account.SystemAt(0), 'MetaData.ExtractRegionFromFileName'), 'Removing the obsolete option preserves original settings');
      Account.Save;
    finally
      Account.Free;
    end;
    Account := TRetroScraperConfig.Create(Folder);
    try
      Check((JValue(Account.SystemAt(-1), 'MetaData.ParseRomFileName') = nil) and
        (JValue(Account.SystemAt(0), 'MetaData.ParseRomFileName') = nil), 'Saving and reloading does not restore the obsolete option');
    finally
      Account.Free;
    end;
  finally
    Game.Free;
    Config.Free;
  end;
end;

procedure RunAlgorithmRegressions(Report: TStrings);
var
  Config, Game, Item, Root, Credentials, Response, Sys: TJSONObject;
  Entries, Slots, Arr: TJSONArray;
  Writer: TGameListWriter;
  Doc: IXMLDocument;
  Folder, Text, Before, FileName, Params, URL, ImageFile, CacheFile: string;
  I, J, CancelCalls: Integer;
  Rejected: Boolean;
  API: TScreenScraper;
  Hashes: TRomHashes;
  Worker: TScrapeWorker;
  Status: TScrapeStatus;
  Lines: TStringList;
  Started: UInt64;
  Bitmap: TBitmap;
  MediaStream: TFileStream;
  Pixels: TBitmapData;
  Sources: TDictionary<string, string>;
  Paths: array[0..2] of string;

  procedure Check(OK: Boolean; const Name: string);
  begin
    if not OK then
      raise Exception.Create('FAIL: ' + Name);
    Report.Add('PASS: ' + Name);
  end;

  procedure VerifyItem(const Key, Expected, Name: string);
  begin
    Item := DescribeGame(Game, Config, Folder + 'sample.rom');
    try
      Check(JStr(Item, Key) = Expected, Name + ' [' + JStr(Item, Key) + ']');
    finally
      Item.Free
    end;
  end;

  procedure RunWorker(OnlineWithSingleNetworkSlot: Boolean = False);
  var
    Gate: TScreenScraperNetworkQueue;
    OnlineConfig: TJSONObject;
    CompletedWithoutUI: Boolean;
  begin
    Gate := nil;
    OnlineConfig := nil;
    if OnlineWithSingleNetworkSlot then
    begin
      Gate := TScreenScraperNetworkQueue.Create(1);
      Gate.Acquire(nil);
      OnlineConfig := Root.Clone as TJSONObject;
      JSet(OnlineConfig, 'Anonymous', TJSONBool.Create(True));
      Worker := TScrapeWorker.Create(OnlineConfig, Credentials, Folder + 'pipeline', 0, False, 1, '', Gate);
    end
    else
      Worker := TScrapeWorker.Create(Root, Credentials, Folder + 'pipeline', 0, True, 2);
    Lines := TStringList.Create;
    try
      Worker.Start;
      Started := TThread.GetTickCount64;
      while not Worker.Finished and (TThread.GetTickCount64 - Started < 30000) do
        TThread.Sleep(20);
      CompletedWithoutUI := Worker.Finished;
      if not Worker.Finished then
        Worker.Terminate;
      Worker.WaitFor;
      Worker.Snapshot(Status, Lines);
      Lines.SaveToFile(Folder + 'pipeline.log', TEncoding.UTF8);
      Check(CompletedWithoutUI, 'Media pipeline completes without main-thread synchronization');
      Check(Status.Errors = 0, 'Offline regression pipeline: ' + Status.LastError);
      Check(Status.Requests = 0, 'Regression pipeline makes no network requests');
    finally
      Lines.Free;
      Worker.Free;
      if Gate <> nil then
      begin
        Gate.Release;
        Gate.Free;
      end;
      OnlineConfig.Free;
    end;
  end;

begin
  Folder := AppBase + 'tests\output\algorithms-' + TGUID.NewGuid.ToString.Trim(['{', '}']) + '\';
  ForceDirectories(Folder);
  Config := TJSONObject.Create;
  Game := TJSONObject.ParseJSONValue('{"romid":12345,"id":42,"rom":{"romregions":"jp,us"},' +
    '"noms":[{"region":"jp","text":"Japanese"},{"region":"us","text":"USA"},{"region":"wor","text":"World"}],' +
    '"synopsis":[{"langue":"en","text":"English"}],"dates":[{"region":"us","text":"1990-07"}],' +
    '"genres":[{"id":7,"parentid":0,"noms":[{"langue":"en","text":"Platform"}]}]}') as TJSONObject;
  try
    JSet(Config, 'Miscellaneous.Regions', TJSONArray.Create.Add('us').Add('jp'));
    JSet(Config, 'Miscellaneous.Languages', TJSONArray.Create.Add('en'));
    JSet(Config, 'Miscellaneous.RomRegionFirst', TJSONBool.Create(True));
    VerifyItem('name', 'USA', 'User region order overrides API order');
    VerifyItem('genreid', '257', 'Normalized platform genre');
    VerifyItem('releasedate', '19900701T000000', 'Year-month release date');
    JSet(Config, 'Miscellaneous.RomRegionFirst', TJSONBool.Create(False));
    JSet(Config, 'Miscellaneous.Regions', TJSONArray.Create.Add('fr'));
    JSet(Config, 'Miscellaneous.Languages', TJSONArray.Create.Add('ru'));
    JSet(Config, 'Miscellaneous.StrictRegionList', TJSONBool.Create(True));
    VerifyItem('name', 'sample', 'Strict name falls back to filename, not foreign title');
    VerifyItem('desc', '', 'Strict description has no foreign-language fallback');
    VerifyItem('genre', '', 'Strict genre has no foreign-language fallback');
    VerifyItem('releasedate', '', 'Strict date has no foreign-region fallback');
    JSet(Config, 'Miscellaneous.StrictRegionList', TJSONBool.Create(False));
    VerifyItem('name', 'World', 'Non-strict metadata prefers world fallback');
    JSet(Config, 'MetaData.ExtractRegionFromFileName', TJSONBool.Create(True));
    JSet(Config, 'Miscellaneous.Regions', TJSONArray.Create);
    JSet(Config, 'Miscellaneous.StrictRegionList', TJSONBool.Create(True));
    VerifyItem('name', 'sample', 'Empty strict region list does not acquire default regions');
    JSet(Config, 'Miscellaneous.Regions', TJSONArray.Create.Add('fr'));
    JSet(Config, 'Miscellaneous.StrictRegionList', TJSONBool.Create(False));
    Check(OrderedRomRegions(Game, Config, 'C:\USA\Game (Japan, France, Europe).rom') = 'fr,jp,eu', 'Multiple filename regions and country names');
    Check(OrderedRomRegions(Game, Config, 'C:\Game (France)\plain.rom') = 'jp,us', 'Filename regions ignore parent-directory decorations');
    JSet(Config, 'Miscellaneous.RomRegionFirst', TJSONBool.Create(True));
    Check(RegionPriority(Game, Config, 'Game (France).rom').StartsWith('fr,'), 'Media and metadata share extracted region');
    JSet(Config, 'GameList.AutoHideSelection', TJSONNumber.Create(1));
    JSet(Config, 'GameList.AutoExcludeSelection', TJSONNumber.Create(1));
    JSet(Config, 'GameList.AutoHideRegions', TJSONArray.Create.Add('us'));
    JSet(Config, 'GameList.AutoExcludeRegions', TJSONArray.Create.Add('us'));
    Item := DescribeGame(nil, Config, Folder + 'unknown.rom');
    try
      Check(not JBool(Item, 'hidden') and not JBool(Item, 'exclude'), 'Unknown game is not rejected by ROM region masks');
    finally
      Item.Free
    end;
    JSet(Config, 'GameList.AutoHideSelection', TJSONNumber.Create(0));
    JSet(Config, 'GameList.AutoExcludeSelection', TJSONNumber.Create(0));
    JSet(Config, 'Miscellaneous.Regions', TJSONArray.Create.Add('us'));
    JSet(Config, 'Miscellaneous.Languages', TJSONArray.Create.Add('en'));
    JSet(Config, 'MetaData.NameDecorations', TJSONNumber.Create(3073));
    JSet(Game, 'rom.romregions', TJSONString.Create('us'));
    JSet(Game, 'rom.romnumsupport', TJSONNumber.Create(1));
    JSet(Game, 'rom.romtotalsupport', TJSONNumber.Create(2));
    JSet(Game, 'rom.clonetypes.clonetypes_fr', TJSONArray.Create.Add('Variant'));
    VerifyItem('name', 'USA (Variant)[US](#1)', 'First disc and structured clone-type decorations');
    JSet(Config, 'MetaData.NameCase', TJSONNumber.Create(2));
    VerifyItem('name', 'usa (Variant)[US](#1)', 'Case applied before decorations');
    JSet(Game, 'tips', TJSONObject.ParseJSONValue('[{"langue":"jp","titre":"J","description":"J"},{"langue":"en","titre":"E","description":"Line1\nLine2"}]'));
    Text := TipsContent(Game, Config);
    Check((Text.IndexOf('language=en') < Text.IndexOf('language=jp')) and Text.Contains('Line1' + #10 + 'Line2'), 'Tips retains all languages and literal line breaks');
    Entries := TJSONObject.ParseJSONValue('[{"type":"wheel","region":"us","url":"sd"},{"type":"wheel-hd","region":"us","url":"hd"},' +
      '{"type":"ss","region":"jp","url":"jp"},{"type":"ss","region":"wor","url":"world"},' +
      '{"type":"support-2D","region":"us","support":1,"url":"disc1"},{"type":"support-2D","region":"us","support":2,"url":"disc2"},' +
      '{"type":"pictoliste","parent":"classification","subparent":"ESRB","region":"us","url":"esrb"},' +
      '{"type":"pictoliste","parent":"classification","subparent":"PEGI","region":"us","url":"pegi"}]') as TJSONArray;
    try
      Check(JStr(SelectMedia(Entries, 'wheel', 'jeu', '', 'us', '', 0, False), 'url') = 'hd', 'HD wheel outranks SD in same region');
      Check(JStr(SelectMedia(Entries, 'ss', 'jeu', '', 'fr', '', 0, False), 'url') = 'world', 'Media prefers world fallback');
      Check(SelectMedia(Entries, 'ss', 'jeu', '', 'fr', '', 0, True) = nil, 'Strict media does not fall back');
      Check(JStr(SelectMedia(Entries, 'support-2D', 'jeu', '', 'us', '', 2, False), 'url') = 'disc2', 'Artwork follows disc number');
      Check(JStr(SelectMedia(Entries, 'support-2D', 'jeu', '', 'us', '', 3, False), 'url') = 'disc1', 'Missing disc art falls back');
      Check(JStr(SelectMedia(Entries, 'pictoliste', 'classification', '', 'us', 'PEGI', 0, False), 'url') = 'pegi', 'Classification icon follows PEGI setting');
    finally
      Entries.Free
    end;
    Entries := TJSONObject.ParseJSONValue('[{"type":"pictoliste","parent":"genre","url":"first"},{"type":"pictoliste","parent":"genre","url":"second"}]') as TJSONArray;
    try
      Check(JStr(SelectMedia(Entries, 'pictoliste', 'genre', '2', 'us', '', 0, True), 'url') = 'second', 'Genre icons use ordinal API media, not nonexistent ID field');
    finally
      Entries.Free
    end;
    Slots := TJSONObject.ParseJSONValue('[{"Type":0,"Image":2},{"Type":0,"Image":0},{"Type":0,"Image":10},{"Type":0,"Image":14}]') as TJSONArray;
    try
      Check((MediaNode(Slots, 0) = 'image') and (MediaNode(Slots, 1) = 'thumbnail'), 'XML slots assigned independently of downloads');
      Check((MediaNode(Slots, 2) = 'logo') and (MediaNode(Slots, 3) = 'marquee'), 'Wheel and screen marquee have distinct XML nodes');
    finally
      Slots.Free
    end;
    JSet(Config, 'GamesAndRoms.Path', TJSONString.Create(Folder));
    JSet(Config, 'GameList.Type', TJSONNumber.Create(1));
    JSet(Config, 'GameList.Behavior', TJSONNumber.Create(3));
    JSet(Config, 'GameList.OutputFile', TJSONString.Create(Folder + 'update.xml'));
    Before := '<gameList><game><path>./sample.rom</path><favorite>true</favorite><hidden>true</hidden><image>./stale.png</image><logo>./stale-logo.png</logo></game></gameList>';
    TFile.WriteAllText(Folder + 'update.xml', Before, TEncoding.UTF8);
    Item := TJSONObject.ParseJSONValue('{"name":"New","favorite":false,"hidden":false}') as TJSONObject;
    JSet(Item, 'path', TJSONString.Create(Folder + 'sample.rom'));
    Writer := TGameListWriter.Create(Config);
    try
      Writer.Add(Item);
      Writer.Save;
      Doc := Writer.Document;
      Check((Doc.DocumentElement.ChildNodes[0].ChildNodes['favorite'].Text = 'true') and (Doc.DocumentElement.ChildNodes[0].ChildNodes['hidden'].Text = 'true'), 'ES update preserves user favorite and hidden');
      Check((Doc.DocumentElement.ChildNodes[0].ChildNodes.FindNode('image') = nil) and (Doc.DocumentElement.ChildNodes[0].ChildNodes.FindNode('logo') = nil), 'ES update clears unavailable old media');
      JSet(Item, 'exclude', TJSONBool.Create(True));
      Writer.Add(Item);
      Check(Doc.DocumentElement.ChildNodes.Count = 1, 'Update does not delete excluded existing game');
      Before := TFile.ReadAllText(Folder + 'update.xml');
      CancelCalls := 0;
      Rejected := False;
      try
        Writer.Save(
          function: Boolean
          begin
            Inc(CancelCalls);
            Result := CancelCalls > 1
          end);
      except
        on E: EAbort do
          Rejected := True
      end;
      Check(Rejected and (TFile.ReadAllText(Folder + 'update.xml') = Before) and not TFile.Exists(Folder + 'update.xml.tmp'), 'Cancel immediately before XML commit preserves old file');
    finally
      Writer.Free;
      Item.Free
    end;
    Rejected := False;
    try
      ScanInputs(Config,
        function: Boolean
        begin
          Result := True
        end);
    except
      on E: EAbort do
        Rejected := True
    end;
    Check(Rejected, 'Directory scan honours cancellation');
    JSet(Config, 'GameList.Type', TJSONNumber.Create(2));
    JSet(Config, 'SystemId', TJSONNumber.Create(135));
    JSet(Config, 'GameList.OutputFile', TJSONString.Create(Folder + 'launchbox.xml'));
    Item := TJSONObject.ParseJSONValue('{"name":"DOS","favorite":true,"hidden":true}') as TJSONObject;
    JSet(Item, 'path', TJSONString.Create(Folder + 'dos.rom'));
    Writer := TGameListWriter.Create(Config);
    try
      Writer.Add(Item);
      Writer.Save;
    finally
      Writer.Free
    end;
    JSet(Item, 'favorite', TJSONBool.Create(False));
    JSet(Item, 'hidden', TJSONBool.Create(False));
    Writer := TGameListWriter.Create(Config);
    try
      Writer.Add(Item);
      Writer.Save;
      Doc := Writer.Document;
      Check((Doc.DocumentElement.ChildNodes.Count = 2) and (Doc.DocumentElement.ChildNodes[0].ChildNodes['UseDosBox'].Text = 'true'), 'LaunchBox DOS and unique AdditionalApplication');
      Check((Doc.DocumentElement.ChildNodes[0].ChildNodes['Favorite'].Text = 'true') and (Doc.DocumentElement.ChildNodes[0].ChildNodes['Hide'].Text = 'true'), 'LaunchBox fixes original loss of user flags');
    finally
      Writer.Free;
      Item.Free
    end;
  finally
    Game.Free;
    Config.Free
  end;

  Credentials := TJSONObject.Create;
  API := TScreenScraper.Create(Credentials, Folder + 'cache');
  try
    API.Offline := True;
    API.CacheDays := 30;
    Response := TJSONObject.Create;
    try
      WriteJSON(Folder + 'cache\' + THashSHA2.GetHashString('probe.php?') + '.json', Response);
    finally
      Response.Free
    end;
    CacheFile := Folder + 'cache\' + THashSHA2.GetHashString('probe.php?') + '.json';
    TFile.SetLastWriteTime(CacheFile, Now - 20);
    Response := API.Request('probe.php', '');
    Response.Free;
    Check(API.CacheHits = 1, 'Imported 30-day TTL keeps 20-day entry');
    TFile.SetLastWriteTime(CacheFile, Now - 31);
    Rejected := False;
    try
      Response := API.Request('probe.php', '');
      Response.Free;
    except
      on E: EScreenScraper do
        Rejected := True
    end;
    Check(Rejected, 'Imported 30-day TTL expires instead of becoming infinite');
    API.CacheDays := 44739242;
    Response := API.Request('probe.php', '');
    Response.Free;
    Check(API.CacheHits = 2, 'Explicit infinite cache sentinel remains supported');
  finally
    API.Free;
    Credentials.Free
  end;

  Sources := TDictionary<string, string>.Create;
  Bitmap := TBitmap.Create(10, 10);
  try
    Bitmap.Clear($FFFF0000);
    Bitmap.SaveToFile(Folder + 'red.png');
  finally
    Bitmap.Free
  end;
  try
    FileName := Folder + 'mix.xml';
    Text := '<Mix><Viewport Width="100" Height="100"/><Drawings><Item Type="LocalFile" LocalFilePath="red.png" TestOnly="true"><Display Width="20" Height="20"/>' +
      '<Children Reference="Parent"><Item Type="LocalFile" LocalFilePath="red.png"><Display X="50%" Y="50%" Width="10" Height="10"/></Item></Children></Item></Drawings></Mix>';
    TFile.WriteAllText(FileName, Text, TEncoding.UTF8);
    RenderMix(FileName, Sources, Folder + 'mix.png', 0, 0);
    Bitmap := TBitmap.Create;
    try
      Bitmap.LoadFromFile(Folder + 'mix.png');
      Bitmap.Map(TMapAccess.Read, Pixels);
      try
        Check((Pixels.GetPixel(55, 55) = $FFFF0000) and (Pixels.GetPixel(15, 15) = 0), 'Mix TestOnly preserves parent reference rectangle');
      finally
        Bitmap.Unmap(Pixels)
      end;
    finally
      Bitmap.Free
    end;
    Text := '<Mix><Viewport Width="100" Height="100"/><Drawings><Item Type="LocalFile" LocalFilePath="red.png"><Display Width="20" Height="20"/>' +
      '<Children Reference="Parent"><Item Type="FanArt"><Children Reference="Viewport" DrawIfNoParent="true"><Item Type="LocalFile" LocalFilePath="red.png">' +
      '<Display X="50%" Y="50%" Width="10" Height="10"/></Item></Children></Item></Children></Item></Drawings></Mix>';
    TFile.WriteAllText(FileName, Text, TEncoding.UTF8);
    RenderMix(FileName, Sources, Folder + 'mix.png', 0, 0);
    Bitmap := TBitmap.Create;
    try
      Bitmap.LoadFromFile(Folder + 'mix.png');
      Bitmap.Map(TMapAccess.Read, Pixels);
      try
        Check(Pixels.GetPixel(55, 55) = $FFFF0000, 'Mix missing parent respects Viewport child reference');
      finally
        Bitmap.Unmap(Pixels)
      end;
    finally
      Bitmap.Free
    end;
    Text := '<Mix><Viewport Width="100" Height="100"/><Drawings><Item Type="LocalFile" LocalFilePath="red.png"><Display Mode="Distord" Anchor="Center" X="20" Y="20" X2="80" Y2="20" X3="80" Y3="80" X4="20" Y4="80"/></Item></Drawings></Mix>';
    TFile.WriteAllText(FileName, Text, TEncoding.UTF8);
    RenderMix(FileName, Sources, Folder + 'mix.png', 0, 0);
    Bitmap := TBitmap.Create;
    try
      Bitmap.LoadFromFile(Folder + 'mix.png');
      Bitmap.Map(TMapAccess.Read, Pixels);
      try
        Check((Pixels.GetPixel(10, 10) = 0) and (Pixels.GetPixel(40, 40) = $FFFF0000), 'Mix Distord does not offset first corner by anchor');
      finally
        Bitmap.Unmap(Pixels)
      end;
    finally
      Bitmap.Free
    end;
  finally
    Sources.Free
  end;

  Root := ReadJSON(AppBase + 'Resources\default.config.json');
  Credentials := TJSONObject.Create;
  try
    JSet(Root, 'FrontEnd.Type', TJSONNumber.Create(4));
    JSet(Root, 'FrontEnd.Kill', TJSONBool.Create(False));
    Sys := TJSONObject.Create;
    JSet(Sys, 'SystemId', TJSONNumber.Create(1));
    JSet(Sys, 'Overriden', TJSONNumber.Create(63));
    JSet(Sys, 'GamesAndRoms.Path', TJSONString.Create(Folder + 'pipeline\roms'));
    JSet(Sys, 'GamesAndRoms.FileExtensions', TJSONArray.Create.Add('rom'));
    JSet(Sys, 'GameList.Type', TJSONNumber.Create(1));
    JSet(Sys, 'GameList.Behavior', TJSONNumber.Create(3));
    JSet(Sys, 'GameList.Folders', TJSONNumber.Create(1));
    JSet(Sys, 'GameList.OutputFile', TJSONString.Create('%ROMROOTFOLDER%\gamelist.xml'));
    JSet(Sys, 'Miscellaneous.RomRegionFirst', TJSONBool.Create(True));
    JSet(Sys, 'Miscellaneous.Regions', TJSONArray.Create.Add('us').Add('jp'));
    JSet(Sys, 'Miscellaneous.Method', TJSONNumber.Create(0));
    Slots := TJSONObject.ParseJSONValue('[{"Type":0,"Image":2,"LinkToNode":true,"Optimize":true,"OutputFolder":"%ROMROOTFOLDER%/media","EmptyOutputFolder":true},{"Type":0,"Image":0,"LinkToNode":true,"Optimize":true,"OutputFolder":"%ROMROOTFOLDER%/media","EmptyOutputFolder":true}]') as TJSONArray;
    JSet(Slots.Items[1] as TJSONObject, 'ResizeWidth', TJSONBool.Create(True));
    JSet(Slots.Items[1] as TJSONObject, 'ResizeWidthValue', TJSONNumber.Create(8));
    JSet(Slots.Items[1] as TJSONObject, 'KeepRatio', TJSONBool.Create(True));
    JSet(Sys, 'Medias', Slots);
    Arr := TJSONArray.Create;
    Arr.AddElement(Sys);
    JSet(Root, 'Systems', Arr);
    ForceDirectories(Folder + 'pipeline\Cache\media');
    for I := 0 to 2 do
    begin
      FileName := Folder + 'pipeline\roms\sub' + I.ToString + '\game.rom';
      ForceDirectories(ExtractFilePath(FileName));
      TFile.WriteAllText(FileName, 'rom' + I.ToString, TEncoding.ASCII);
      Hashes := ComputeInputHashes(Sys, FileName, Folder + 'pipeline\Cache\hashes');
      Params := 'systemeid=1&romtype=rom&romnom=' + CleanRomName(Hashes.Name) + '&romtaille=' + Hashes.Size.ToString + '&crc=' + Hashes.CRC + '&md5=' + Hashes.MD5 + '&sha1=' + Hashes.SHA1;
      Response := TJSONObject.ParseJSONValue('{"response":{"jeu":{"id":42,"romid":12345,"rom":{"romregions":"us"},"noms":[{"region":"us","text":"Game"}],"medias":[]}}}') as TJSONObject;
      try
        if I = 1 then
          JSet(Response, 'response.jeu.rom.romregions', TJSONString.Create('jp'));
        if I = 2 then
          JSet(Response, 'response.jeu.id', TJSONNumber.Create(99));
        Entries := TJSONArray.Create;
        for J := 0 to 1 do
        begin
          if J = 0 then
            Text := 'us'
          else
            Text := 'jp';
          URL := 'https://fixture.invalid/' + Text + '.png';
          ImageFile := Folder + 'pipeline\Cache\media\' + THashSHA2.GetHashString(URL) + '.png';
          Bitmap := TBitmap.Create(16, 16);
          try
            if J = 0 then
              Bitmap.Clear($FFFF0000)
            else
              Bitmap.Clear($FF0000FF);
            Bitmap.SaveToFile(ImageFile);
          finally
            Bitmap.Free
          end;
          Item := TJSONObject.Create;
          Item.AddPair('type', 'ss');
          Item.AddPair('region', Text);
          Item.AddPair('url', URL);
          Item.AddPair('format', 'png');
          MediaStream := TFileStream.Create(ImageFile, fmOpenRead or fmShareDenyNone);
          try
            Item.AddPair('md5', THashMD5.GetHashString(MediaStream));
          finally
            MediaStream.Free
          end;
          Entries.AddElement(Item);
        end;
        JSet(Response, 'response.jeu.medias', Entries);
        WriteJSON(Folder + 'pipeline\Cache\api\' + THashSHA2.GetHashString('jeuInfos.php?' + Params) + '.json', Response);
      finally
        Response.Free
      end;
    end;
    JSet(Sys, 'Miscellaneous.SaveLogs', TJSONBool.Create(True));
    TFile.WriteAllText(Folder + 'pipeline\Logs', 'block log directory', TEncoding.UTF8);
    RunWorker;
    Check(TFile.ReadAllText(Folder + 'pipeline.log').Contains('Warning: file logging'),
      'Unavailable log file warns without aborting the media pipeline');
    TFile.Delete(Folder + 'pipeline\Logs');
    JSet(Sys, 'Miscellaneous.SaveLogs', TJSONBool.Create(False));
    Check((Status.Cached = 3) and (Status.Found = 3), 'Real romid prevents redundant name fallback');
    Check((Status.Completed = 6) and (Status.Total = 6), 'Pipeline counts three games and three actual folders');
    Doc := LoadXMLDocument(Folder + 'pipeline\roms\gamelist.xml');
    J := 0;
    for I := 0 to Doc.DocumentElement.ChildNodes.Count - 1 do
      if Doc.DocumentElement.ChildNodes[I].NodeName = 'game' then
      begin
        Check(Doc.DocumentElement.ChildNodes[I].ChildNodes.FindNode('image') = nil, 'Missing first media leaves primary slot empty');
        Paths[J] := Doc.DocumentElement.ChildNodes[I].ChildNodes['thumbnail'].Text;
        Inc(J);
      end;
    Check((Paths[0] <> Paths[1]) and (Paths[0] = Paths[2]), 'Content dedup preserves different region art and shares identical art across game IDs');
    Bitmap := TBitmap.Create;
    try
      Bitmap.LoadFromFile(Folder + 'pipeline\roms\' + Paths[0].Substring(2).Replace('/', '\'));
      Check((Bitmap.Width = 8) and (Bitmap.Height = 8), 'Image resize completes without main-thread synchronization');
    finally
      Bitmap.Free;
    end;
    Check(Length(TDirectory.GetFiles(Folder + 'pipeline\roms\media', 'stage-*')) = 0, 'Published media leave no staging files');
    JSet(Slots.Items[1] as TJSONObject, 'ResizeWidth', TJSONBool.Create(False));
    for I := 0 to 1 do
      JSet(Slots.Items[I] as TJSONObject, 'Optimize', TJSONBool.Create(False));
    RunWorker;
    Check(TFile.Exists(Folder + 'pipeline\roms\media\sub0\game-media2.png'), 'Nonoptimized output preserves relative ROM directory');
    Check(not TFile.Exists(Folder + 'pipeline\roms\' + Paths[0].Substring(2).Replace('/', '\')), 'Update cleans previously managed orphan media');
    // Reuse published files with the binary media cache completely removed.
    JSet(Sys, 'Miscellaneous.ReuseExistingMedia', TJSONBool.Create(True));
    for FileName in TDirectory.GetFiles(Folder + 'pipeline\Cache\media') do
      TFile.Delete(FileName);
    for FileName in TDirectory.GetFiles(Folder + 'pipeline\State\MediaSources') do
      TFile.Delete(FileName);
    RunWorker;
    Check((Status.Downloaded = 0) and (Status.MediaFound = 3), 'Existing output bootstraps media sources without binary cache or index');
    RunWorker(True);
    Check((Length(Status.Engines) = 3) and (Status.Found = 3) and (Status.Downloaded = 0) and
      (Status.MediaFound = 3) and not Status.Cancelled,
      'Online processing uses multiple workers and existing media while the single network slot stays occupied');
    FileName := Folder + 'reuse-mix.xml';
    TFile.WriteAllText(FileName, '<ImageComposition><Viewport Width="64" Height="32"/><Drawings><Item Type="Screenshot"><Display Width="100%" Height="100%"/></Item></Drawings></ImageComposition>', TEncoding.UTF8);
    Item := TJSONObject.Create;
    Item.AddPair('Type', TJSONNumber.Create(2));
    Item.AddPair('LocalMixFile', FileName);
    Item.AddPair('OutputFolder', '%ROMROOTFOLDER%/mix');
    Item.AddPair('ResizeWidth', TJSONBool.Create(True));
    Item.AddPair('ResizeWidthValue', TJSONNumber.Create(48));
    Item.AddPair('KeepRatio', TJSONBool.Create(True));
    Slots.AddElement(Item);
    RunWorker;
    ImageFile := Folder + 'pipeline\roms\mix\sub0\game.png';
    Bitmap := TBitmap.Create;
    try
      Bitmap.LoadFromFile(ImageFile);
      Check((Bitmap.Width = 48) and (Bitmap.Height = 24), 'MIX renders and resizes without main-thread synchronization');
    finally
      Bitmap.Free
    end;
    JSet(Item, 'ResizeWidth', TJSONBool.Create(False));
    TFile.WriteAllText(FileName, '<ImageComposition><Viewport Width="96" Height="48"/><Drawings><Item Type="Screenshot"><Display Width="100%" Height="100%"/></Item></Drawings></ImageComposition>', TEncoding.UTF8);
    TFile.Delete(Folder + 'pipeline\roms\media\sub0\game-media2.png');
    RunWorker;
    Check(TFile.Exists(Folder + 'pipeline\roms\media\sub0\game-media2.png'), 'Missing published media is restored from persistent source');
    Bitmap := TBitmap.Create;
    try
      Bitmap.LoadFromFile(ImageFile);
      Check((Bitmap.Width = 96) and (Bitmap.Height = 48), 'Changed MIX is regenerated using persistent local sources');
    finally
      Bitmap.Free
    end;
    // The next template introduces a source which was not in the original MIX.
    URL := 'https://fixture.invalid/title.png';
    ImageFile := Folder + 'pipeline\Cache\media\' + THashSHA2.GetHashString(URL) + '.png';
    Bitmap := TBitmap.Create(16, 16);
    try
      Bitmap.Clear($FF00FF00);
      Bitmap.SaveToFile(ImageFile);
    finally
      Bitmap.Free
    end;
    for CacheFile in TDirectory.GetFiles(Folder + 'pipeline\Cache\api', '*.json') do
    begin
      Response := ReadJSON(CacheFile);
      try
        Entries := JValue(Response, 'response.jeu.medias') as TJSONArray;
        if Entries <> nil then
        begin
          Item := TJSONObject.Create;
          Item.AddPair('type', 'sstitle');
          Item.AddPair('region', 'us');
          Item.AddPair('url', URL);
          Item.AddPair('format', 'png');
          Entries.AddElement(Item);
          WriteJSON(CacheFile, Response);
        end;
      finally
        Response.Free
      end;
    end;
    TFile.WriteAllText(FileName, '<ImageComposition><Viewport Width="96" Height="48"/><Drawings><Item Type="ScreenshotTitle"><Display Width="100%" Height="100%"/></Item></Drawings></ImageComposition>', TEncoding.UTF8);
    RunWorker;
    Check(TFile.Exists(Folder + 'pipeline\Sources\media\' + THashSHA2.GetHashString(URL) + '.png'), 'New MIX dependency is acquired and persisted outside cache');
    TFile.Delete(ImageFile);
    RunWorker;
    Bitmap := TBitmap.Create;
    try
      Bitmap.LoadFromFile(Folder + 'pipeline\roms\mix\sub0\game.png');
      Bitmap.Map(TMapAccess.Read, Pixels);
      try
        Check(Pixels.GetPixel(40, 20) = $FF00FF00, 'New MIX source survives removal of binary cache');
      finally
        Bitmap.Unmap(Pixels)
      end;
    finally
      Bitmap.Free
    end;
    Slots.Remove(Slots.Count - 1).Free;
    JSet(Sys, 'GameList.Folders', TJSONNumber.Create(3));
    RunWorker;
    Doc := LoadXMLDocument(Folder + 'pipeline\roms\gamelist.xml');
    for I := 0 to Doc.DocumentElement.ChildNodes.Count - 1 do
      if (Doc.DocumentElement.ChildNodes[I].NodeName = 'folder') and (Doc.DocumentElement.ChildNodes[I].ChildNodes['path'].Text = './sub0') then
      begin
        ImageFile := Folder + 'pipeline\roms\' + Doc.DocumentElement.ChildNodes[I].ChildNodes['image'].Text.Substring(2).Replace('/', '\');
        Bitmap := TBitmap.Create;
        try
          Bitmap.LoadFromFile(ImageFile);
          Bitmap.Map(TMapAccess.Read, Pixels);
          try
            Check(Pixels.GetPixel(100, 160) = $FFFF0000, 'Folder mosaic resolves relative thumbnail from real pipeline');
          finally
            Bitmap.Unmap(Pixels)
          end;
        finally
          Bitmap.Free
        end;
      end;
    // All three matching methods are tested using cached responses and real ROM hashes.
    JSet(Sys, 'Miscellaneous.SaveFCRCMissing', TJSONBool.Create(True));
    for I := 0 to 2 do
    begin
      FileName := Folder + 'pipeline\roms\sub' + I.ToString + '\game.rom';
      Hashes := ComputeInputHashes(Sys, FileName, Folder + 'pipeline\Cache\hashes');
      Params := 'systemeid=1&romtype=rom&romnom=' + CleanRomName(Hashes.Name) + '&romtaille=' + Hashes.Size.ToString + '&crc=' + Hashes.CRC + '&md5=' + Hashes.MD5 + '&sha1=' + Hashes.SHA1;
      CacheFile := Folder + 'pipeline\Cache\api\' + THashSHA2.GetHashString('jeuInfos.php?' + Params) + '.json';
      Response := ReadJSON(CacheFile);
      try
        JSet(Response, 'response.jeu.romid', TJSONNumber.Create(0));
        WriteJSON(CacheFile, Response);
        JSet(Response, 'response.jeu.noms', TJSONArray.Create.Add('unused'));
        JSet(Response, 'response.jeu.noms', TJSONObject.ParseJSONValue('[{"region":"us","text":"Name fallback"}]'));
        WriteJSON(Folder + 'pipeline\Cache\api\' + THashSHA2.GetHashString('jeuInfos.php?systemeid=1&romtype=jeu&romnom=Game') + '.json', Response);
      finally
        Response.Free
      end;
    end;
    JSet(Sys, 'Miscellaneous.Method', TJSONNumber.Create(0));
    RunWorker;
    Check((Status.Cached = 6) and (Status.Found = 3), 'Hash-then-name mode performs fallback for unknown ROMs');
    Check(Length(TFile.ReadAllLines(Folder + 'pipeline\roms\gamelist.Missing.FCRC.txt')) = 3, 'FCRC records unknown ROM hashes even when game name is found');
    JSet(Sys, 'Miscellaneous.Method', TJSONNumber.Create(1));
    RunWorker;
    Check((Status.Cached = 3) and (Status.Found = 3), 'Hash-only mode never performs name query');
    JSet(Sys, 'Miscellaneous.Method', TJSONNumber.Create(2));
    RunWorker;
    Check((Status.Cached = 3) and (Status.Found = 3), 'Name-only mode uses only name responses');
    JSet(Sys, 'GameList.AutoExcludeWords', TJSONBool.Create(True));
    JSet(Sys, 'GameList.AutoExcludeWordList', TJSONArray.Create.Add('Name fallback'));
    RunWorker;
    Check((Status.Total = 3) and (Status.Completed = 3) and (Status.Saved = 0), 'Excluded games do not inflate completed folder count');
    JSet(Sys, 'GameList.AutoExcludeWords', TJSONBool.Create(False));
    JSet(Sys, 'Medias', TJSONObject.ParseJSONValue('[{"Type":8,"LinkToNode":true,"OutputFolder":"%ROMROOTFOLDER%/maps"}]'));
    CacheFile := Folder + 'pipeline\Cache\api\' + THashSHA2.GetHashString('jeuInfos.php?systemeid=1&romtype=jeu&romnom=Game') + '.json';
    Response := ReadJSON(CacheFile);
    try
      Entries := JValue(Response, 'response.jeu.medias') as TJSONArray;
      Item := Entries.Items[0].Clone as TJSONObject;
      JSet(Item, 'type', TJSONString.Create('maps'));
      Arr := TJSONArray.Create;
      Arr.AddElement(Item);
      JSet(Response, 'response.jeu.medias', Arr);
      WriteJSON(CacheFile, Response);
    finally
      Response.Free
    end;
    RunWorker;
    Check((Status.MediaRequested = 3) and (Status.MediaFound = 3),
      'Map downloads contribute to session media coverage');
  finally
    Credentials.Free;
    Root.Free
  end;
end;

procedure RunLayoutFlowRegressions(Main: TFormMain; Report: TStrings);
var
  OriginalHeight, OriginalTop: Single;
  PhotoVisible: Boolean;

  procedure Check(OK: Boolean; const Description: string);
  begin
    if not OK then
      raise Exception.Create('FAIL: ' + Description);
    Report.Add('PASS: ' + Description);
  end;

begin
  Check((Main.AppTitle.Parent = Main.AppSubtitle.Parent) and
    (Main.NavLibrary.Parent = Main.NavScraping.Parent) and
    (Main.NavLibraryIcon.Parent = Main.NavLibrary),
    'Navigation uses shared stacks and directly owned icons');
  OriginalHeight := Main.AppTitle.Height;
  OriginalTop := Main.AppSubtitle.Position.Y;
  try
    Main.AppTitle.Height := OriginalHeight + 16;
    Check(SameValue(Main.AppSubtitle.Position.Y, OriginalTop + 16, 0.1),
      'Increasing a navigation heading moves the following controls');
    Main.AppTitle.Visible := False;
    Check(SameValue(Main.AppSubtitle.Position.Y, OriginalTop - OriginalHeight - Main.AppTitle.Margins.Top, 0.1),
      'Hiding a navigation heading closes its space in the shared stack');
  finally
    Main.AppTitle.Height := OriginalHeight;
    Main.AppTitle.Visible := True;
  end;
  Check(Main.AppTitle.Position.Y < Main.AppSubtitle.Position.Y,
    'Restoring a hidden heading preserves vertical docking order');
  PhotoVisible := Main.PictureBoxPhoto.Visible;
  try
    Main.PictureBoxPhoto.Visible := False;
    OriginalTop := Main.InspectorTitle.Position.Y;
    Main.PictureBoxPhoto.Visible := True;
    Check(SameValue(Main.InspectorTitle.Position.Y, OriginalTop + Main.PictureBoxPhoto.Height, 0.1),
      'Showing the system photo moves inspector fields without coordinate updates');
  finally
    Main.PictureBoxPhoto.Visible := PhotoVisible;
  end;
  Check((Main.InspectorID.Parent = Main.InspectorTitle.Parent) and
    (Main.InspectorExtensionsLabel.Parent = Main.InspectorExtensions.Parent),
    'Inspector labels and fields share their vertical container');
  Check(Main.ButtonRemoveSystem.Position.Y < Main.InspectorProvider.Position.Y,
    'Inspector actions precede the provider information');
  Check((Main.RollingButtonSystemSelect.Parent = Main.LabelGamesAndRomAllSystems.Parent) and
    (Main.RollingButtonSystemSelect.Width > 100),
    'Alternative system selectors share one usable field slot');
  OriginalHeight := Main.AccountTitle.Height;
  OriginalTop := Main.AccountDescription.Position.Y;
  try
    Main.AccountTitle.Height := OriginalHeight + 12;
    Check(SameValue(Main.AccountDescription.Position.Y, OriginalTop + 12, 0.1),
      'Account fields follow changes to the preceding label height');
  finally
    Main.AccountTitle.Height := OriginalHeight;
  end;
end;

procedure RunSelfTests;
var
  Report: TStringList;
  Folder, CRC, MD5, SHA1, FileName: string;
  Stream: TStringStream;
  Config, Game, Item, Response: TJSONObject;
  Writer: TGameListWriter;
  I: Integer;
  Doc: IXMLDocument;
  Sources: TDictionary<string, string>;
  Bitmap: TBitmap;
  Rejected: Boolean;
  Zip: TZipFile;
  Bytes: TBytes;
  Setup: TFormSetup;
  API: TScreenScraper;
  Account: TRetroScraperConfig;
  Worker: TScrapeWorker;
  Status: TScrapeStatus;
  Systems, Media: TJSONArray;
  Lines: TStringList;
  RunRoot, Params: string;
  Started: UInt64;
  Payload: TStream;
  Header: TZipHeader;
  FolderFiles: TArray<string>;
  Dependencies: TArray<string>;
  FrozenTime: string;
  Handled: Boolean;
  ComboIndex: Integer;
  Hashes: TRomHashes;
  Pixels: FMX.Graphics.TBitmapData;
  RowButton, MediaButton: TButton;
  RowGrid: TGridPanelLayout;
  EventRow: TListBoxItem;
  RowProbe: TRowLifetimeProbe;
  ScrollBefore: TPointF;
  OriginalOptimize, OriginalLog: Boolean;
  FolderCounts: TFolderItemCount;

  procedure Check(Condition: Boolean; const Name: string);
  begin
    if not Condition then
      raise Exception.Create('FAIL: ' + Name);
    Report.Add('PASS: ' + Name);
  end;

begin
  Folder := AppBase + 'tests\output\';
  ForceDirectories(Folder);
  Report := TStringList.Create;
  try
    FileName := Folder + 'folder-count-' + TGUID.NewGuid.ToString;
    ForceDirectories(FileName + '\sub');
    ForceDirectories(FileName + '\empty');
    TFile.WriteAllText(FileName + '\one.rom', 'one');
    TFile.WriteAllText(FileName + '\two.txt', 'two');
    TFile.WriteAllText(FileName + '\sub\nested.rom', 'nested');
    try
      FolderCounts := CountFolderItems(FileName);
      Check((FolderCounts.Error = '') and (FolderCounts.Files = 2) and (FolderCounts.Folders = 2), 'Folder count includes immediate files and folders without recursion');
      FolderCounts := CountFolderItems(FileName + '\empty');
      Check((FolderCounts.Error = '') and (FolderCounts.Files = 0) and (FolderCounts.Folders = 0), 'Empty folder has a valid zero count');
      FolderCounts := CountFolderItems(FileName + '\missing');
      Check(FolderCounts.Error <> '', 'Unavailable folder is not reported as empty');
    finally
      TFile.Delete(FileName + '\one.rom');
      TFile.Delete(FileName + '\two.txt');
      TFile.Delete(FileName + '\sub\nested.rom');
      TDirectory.Delete(FileName + '\sub');
      TDirectory.Delete(FileName + '\empty');
      TDirectory.Delete(FileName);
    end;

    try
      RunOriginalFileNameRegressions(Report);
      Stream := TStringStream.Create('123456789', TEncoding.ASCII);
      try
        HashStream(Stream, CRC, MD5, SHA1);
      finally
        Stream.Free;
      end;
      Check(CRC = 'CBF43926', 'CRC32 standard vector');
      Check(MD5 = '25F9E794323B453885F5181F1B624D0B', 'MD5 standard vector');
      Check(SHA1 = 'F7C3BC1D808E04732ADF679965CCC34CA7AE3441', 'SHA1 standard vector');
      Zip := TZipFile.Create;
      try
        Zip.Open(Folder + 'payload.zip', zmWrite);
        Zip.Add(TEncoding.ASCII.GetBytes('123456789'), 'folder/game.rom');
        Zip.Close;
        Zip.Open(Folder + 'payload.zip', zmRead);
        Zip.Read(0, Payload, Header);
        try
          Check(Header.UncompressedSize = 9, 'ZIP payload size');
          HashStream(Payload, CRC, MD5, SHA1);
          Check(CRC = 'CBF43926', 'ZIP hashes decompressed content');
        finally
          Payload.Free;
        end;
      finally
        Zip.Free;
      end;
      Stream := TStringStream.Create('123456789', TEncoding.ASCII);
      Rejected := False;
      try
        try
          HashStream(Stream, CRC, MD5, SHA1,
            function: Boolean
            begin
              Result := True;
            end);
        except
          on E: EAbort do
            Rejected := True;
        end;
      finally
        Stream.Free;
      end;
      Check(Rejected, 'Hashing responds to cancellation');
      Response := TJSONObject.ParseJSONValue('{"header":{"url":"secret"},"response":{"medias":[{"url":"https://example.test/api?devid=x&devpassword=y&ssid=z&sspassword=w&id=1"}]}}') as TJSONObject;
      try
        SanitizeResponse(Response);
        Check(not Response.ToJSON.Contains('password'), 'Remove echoed API secrets');
      finally
        Response.Free;
      end;
      Response := ReadJSON(AppBase + 'Resources\default.config.json');
      try
        Config := Response.GetValue<TJSONObject>('AllSystems').Clone as TJSONObject;
      finally
        Response.Free;
      end;
      Game := TJSONObject.ParseJSONValue('{"id":"42","noms":[{"region":"us","text":"The Game"}],"synopsis":[{"langue":"en","text":"A & B < C"}],"note":{"text":"19"},"rom":{"beta":1,"romregions":"us"},"genres":[{"noms":[{"langue":"en","text":"Action"}]}]}') as TJSONObject;
      try
        JSet(Config, 'GamesAndRoms.Path', TJSONString.Create(Folder));
        JSet(Config, 'MetaData.MoveArticles', TJSONBool.Create(True));
        JSet(Config, 'GameList.AutoFavoriteRating', TJSONBool.Create(True));
        JSet(Config, 'GameList.AutoHideSelection', TJSONNumber.Create(0));
        Item := DescribeGame(Game, Config, Folder + 'game.rom');
        try
          Check(JStr(Item, 'name') = 'Game, The', 'Move name article');
          Check(JBool(Item, 'favorite'), 'Rating-based favorite');
          JSet(Config, 'GameList.AutoHideSelection', TJSONNumber.Create(2));
          Response := DescribeGame(Game, Config, Folder + 'game.rom');
          try
            Check(JBool(Response, 'hidden') and not JBool(Response, 'favorite'), 'Hidden games are not favorites');
          finally
            Response.Free;
          end;
          JSet(Config, 'GameList.AutoHideSelection', TJSONNumber.Create(1));
          JSet(Config, 'GameList.AutoHideRegions', TJSONArray.Create.Add('us'));
          Response := DescribeGame(Game, Config, Folder + 'game.rom');
          try
            Check(not JBool(Response, 'hidden'), 'Allowed region is retained');
          finally
            Response.Free;
          end;
          JSet(Config, 'GameList.AutoHideRegions', TJSONArray.Create.Add('jp'));
          Response := DescribeGame(Game, Config, Folder + 'game.rom');
          try
            Check(JBool(Response, 'hidden'), 'Regions outside the list are hidden');
          finally
            Response.Free;
          end;
          JSet(Config, 'GameList.AutoHideSelection', TJSONNumber.Create(0));
          Check(JStr(Item, 'desc') = 'A & B < C', 'Localized synopsis');
          Check(JStr(Item, 'genre') = 'Action', 'Localized genre');
          for I := 1 to 3 do
          begin
            FileName := Folder + 'format-' + I.ToString + '.xml';
            JSet(Config, 'GameList.Type', TJSONNumber.Create(I));
            JSet(Config, 'GameList.Behavior', TJSONNumber.Create(1));
            JSet(Config, 'GameList.OutputFile', TJSONString.Create(FileName));
            Writer := TGameListWriter.Create(Config);
            try
              Writer.Add(Item);
              Writer.Save;
            finally
              Writer.Free;
            end;
            Doc := LoadXMLDocument(FileName);
            Check(Doc.DocumentElement <> nil, 'Parse export format ' + I.ToString);
            Check(TFile.ReadAllText(FileName).Contains('A &amp; B &lt; C'), 'XML escaping format ' + I.ToString);
            // EmulationStation/LaunchBox/DAT may store equivalent paths differently.
            case I of
              1:
                Doc.DocumentElement.ChildNodes[0].ChildNodes['path'].Text := '.\game.rom';
              2:
                Doc.DocumentElement.ChildNodes[0].ChildNodes['ApplicationPath'].Text := (Folder + 'game.rom').Replace('\', '/');
              3:
                Doc.DocumentElement.ChildNodes[0].ChildNodes['rom'].Attributes['name'] := 'game.rom';
            end;
            Doc.SaveToFile(FileName);
            JSet(Config, 'GameList.Behavior', TJSONNumber.Create(3));
            Writer := TGameListWriter.Create(Config);
            try
              Writer.Add(Item);
              Writer.Save;
            finally
              Writer.Free;
            end;
            Doc := LoadXMLDocument(FileName);
            if I = 2 then
              Check(Doc.DocumentElement.ChildNodes.Count = 2, 'LaunchBox game and additional application without duplicates')
            else if I = 3 then
              Check(Doc.DocumentElement.ChildNodes.Count = 2, 'DAT update without duplicate')
            else
              Check(Doc.DocumentElement.ChildNodes.Count = 1, 'XML update without duplicate ' + I.ToString);
          end;
          JSet(Config, 'GameList.Type', TJSONNumber.Create(1));
          JSet(Config, 'GameList.Behavior', TJSONNumber.Create(1));
          JSet(Item, 'path', TJSONString.Create(Folder + 'nested\game.rom'));
          JSet(Item, 'image', TJSONString.Create(AppBase + 'Resources\SkraperUI.Properties.Samples\snesss.png'));
          for I := 1 to 3 do
          begin
            JSet(Config, 'GameList.Folders', TJSONNumber.Create(I));
            JSet(Config, 'GameList.OutputFile', TJSONString.Create(Folder + 'folders-' + I.ToString + '.xml'));
            Writer := TGameListWriter.Create(Config);
            try
              Writer.Add(Item);
              FolderFiles := Writer.PrepareFolders;
              Writer.Save;
              Check((Length(FolderFiles) = 1) and TFile.Exists(FolderFiles[0]), 'Folder image mode ' + I.ToString);
              Check(Writer.Document.DocumentElement.ChildNodes.FindNode('folder') <> nil, 'Folder XML mode ' + I.ToString);
            finally
              Writer.Free;
            end;
          end;
          JSet(Item, 'path', TJSONString.Create(Folder + 'game.rom'));
          JSet(Config, 'GameList.Folders', TJSONNumber.Create(0));
          Media := TJSONArray.Create;
          Response := TJSONObject.Create;
          Response.AddPair('path', Folder + 'map.png');
          Response.AddPair('title', 'Map & cave');
          Media.AddElement(Response);
          JSet(Item, 'maps', Media);
          JSet(Config, 'GameList.OutputFile', TJSONString.Create(Folder + 'maps.xml'));
          Writer := TGameListWriter.Create(Config);
          try
            Writer.Add(Item);
            Writer.Save;
            Doc := LoadXMLDocument(Folder + 'maps.xml');
            Check(Doc.DocumentElement.ChildNodes[0].ChildNodes['maps'].ChildNodes[0].Attributes['path'] = './map.png', 'Map relative path');
            Check(Doc.DocumentElement.ChildNodes[0].ChildNodes['maps'].ChildNodes[0].Attributes['title'] = 'Map & cave', 'Map title XML escaping');
          finally
            Writer.Free;
          end;
          JSet(Config, 'GameList.Type', TJSONNumber.Create(1));
          JSet(Config, 'GameList.Behavior', TJSONNumber.Create(1));
          JSet(Config, 'GameList.OutputFile', TJSONString.Create(Folder + 'gamelist.zip'));
          Writer := TGameListWriter.Create(Config);
          try
            Writer.Add(Item);
            Writer.Save;
          finally
            Writer.Free;
          end;
          Zip := TZipFile.Create;
          try
            Zip.Open(Folder + 'gamelist.zip', zmRead);
            Zip.Read('gamelist.xml', Bytes);
            Check(Length(Bytes) > 0, 'Zipped gamelist');
          finally
            Zip.Free;
          end;
        finally
          Item.Free;
        end;
      finally
        Game.Free;
        Config.Free;
      end;
      Response := ReadJSON(AppBase + 'Resources\default.config.json');
      try
        JSet(Response, 'FrontEnd.Type', TJSONNumber.Create(2));
        JSet(Response, 'FrontEnd.HomePath', TJSONString.Create(Folder + 'LaunchBox'));
        ApplyFrontendDefaults(Response);
        Config := JValue(Response, 'AllSystems').Clone as TJSONObject;
        try
          JSet(Config, 'GamesAndRoms.Platform', TJSONString.Create('Nintendo NES'));
          ResolveFrontendPaths(Config, JValue(Response, 'FrontEnd') as TJSONObject);
          Check(JStr(Config, 'GameList.OutputFile') = Folder + 'LaunchBox\Data\Platforms\Nintendo NES.xml', 'LaunchBox platform output path');
          Check(not Config.ToJSON.Contains('%FRONTENDROOTFOLDER%'), 'Frontend media macros expanded');
        finally
          Config.Free;
        end;
      finally
        Response.Free;
      end;
      // UI regressions use a dedicated library instead of developer paths in defaults.
      Account := TRetroScraperConfig.Create(WritableBase);
      Response := ReadJSON(AppBase + 'Resources\systems.json');
      try
        JSet(Account.Root, 'Systems', TJSONArray.Create);
        for I := 1 to 13 do
        begin
          FileName := Folder + 'ui-roms\' + I.ToString;
          ForceDirectories(FileName);
          Config := Account.SystemAt(-1).Clone as TJSONObject;
          ConfigurePlatform(Config, Account.SystemAt(-1), Response, 0, TArray<Integer>.Create(I), FileName);
          JSet(Config, 'UniqueId', TJSONString.Create(TGUID.NewGuid.ToString));
          TJSONArray(JValue(Account.Root, 'Systems')).AddElement(Config);
        end;
        Account.Save;
      finally
        Response.Free;
        Account.Free
      end;
      FormMain := TFormMain.Create(nil);
      for I := 0 to FormMain.ComponentCount - 1 do
        if FormMain.Components[I] is TComboBox then
        begin
          Check(TComboBox(FormMain.Components[I]).ItemHeight = TComboBox(FormMain.Components[I]).Height,
            'Combo item height: ' + FormMain.Components[I].Name);
          ComboIndex := TComboBox(FormMain.Components[I]).ItemIndex;
          Handled := False;
          TComboWheelAccess(FormMain.Components[I]).MouseWheel([], -120, Handled);
          Check((TComboBox(FormMain.Components[I]).ItemIndex = ComboIndex) and not Handled,
            'Wheel passes through: ' + FormMain.Components[I].Name);
        end;
      Check(FormMain.ComponentCount > 300, 'FMX form streaming and style load');
      Check((FormMain.NavLibraryIcon.Data.Count > 0) and (FormMain.NavScrapingIcon.Data.Count > 0) and
        (FormMain.NavSettingsIcon.Data.Count > 0), 'Visible Fluent TPath icons stream from FMX');
      Check(FormMain.RollingButtonSystemSelect.Items.Count = 243, 'Eligible system catalog excludes flipper and non-game databases');
      Check(FormMain.RadioBoxNameCaseAsIs.IsChecked or FormMain.RadioBoxNameCaseLower.IsChecked or FormMain.RadioBoxNameCaseUpper.IsChecked, 'Name case radio binding');
      Check(FormMain.RadioButtonNodeLink.IsChecked or FormMain.RadioButtonNoLink.IsChecked, 'Media link radio binding');
      Setup := TFormSetup.Create(nil);
      try
        Check(Setup.SystemList <> nil, 'Setup form streaming');
        Setup.StyleBook := FormMain.StyleBookWinUI3;
        Response := TJSONObject.ParseJSONValue('{"systemes":[{"id":1,"noms":{"nom_us":"Genesis","nom_recalbox":"megadrive"}},{"id":2,"noms":{"nom_us":"Game Boy"}}]}') as TJSONObject;
        try
          Setup.LoadCatalog(Response);
          Check(Setup.SystemList.Count = 2, 'Platform list loads catalog');
          Setup.PlatformSearch.Text := 'MEGADRIVE';
          Check((Setup.SystemList.Count = 1) and
            (JInt(TJSONValue(Setup.SystemList.Items[0].TagObject), 'id') = 1), 'Platform search matches aliases without case');
          Setup.PlatformSearch.Text := '2';
          Check(Setup.SystemList.Items[0].Text = 'Game Boy', 'Platform search matches ID and maps selection');
          Setup.PlatformSearch.Text := 'missing';
          Check(Setup.EmptyLabel.Visible and not Setup.ApplyButton.Enabled, 'Empty platform search blocks manual add');
          Setup.DetectCheck.IsChecked := True;
          Check(Setup.ApplyButton.Enabled, 'Auto detection ignores platform search filter');
          Setup.DetectCheck.IsChecked := False;
          Setup.PlatformSearch.Text := '';
          Check((Setup.SystemList.Count = 2) and Setup.ApplyButton.Enabled, 'Clearing search restores platform list');
          Setup.FrontEndCombo.ItemIndex := 0;
          Setup.RootEdit.Text := 'H:\ROMS';
          Bitmap := TBitmap.Create(940, 580);
          try
            if Bitmap.Canvas.BeginScene then
            try
              Setup.PaintTo(Bitmap.Canvas);
            finally
              Bitmap.Canvas.EndScene
            end;
            Bitmap.SaveToFile(Folder + 'setup-platform-list.png');
          finally
            Bitmap.Free
          end;
        finally
          Setup.LoadCatalog(nil);
          Response.Free;
        end;
        Bitmap := TBitmap.Create(940, 580);
        try
          if Bitmap.Canvas.BeginScene then
          try
            Setup.PaintTo(Bitmap.Canvas);
          finally
            Bitmap.Canvas.EndScene
          end;
          Bitmap.SaveToFile(Folder + 'setup-form.png');
        finally
          Bitmap.Free
        end;
        Check(Setup.CancelButton.AbsoluteRect.Right < Setup.ApplyButton.AbsoluteRect.Left,
          'Setup command containers keep Cancel before Add');
        Check(Setup.FrontEndCombo.DisableMouseWheel and
          (Setup.FrontEndCombo.ItemHeight = Setup.FrontEndCombo.Height), 'Setup combos use consistent height and pass wheel');
      finally
        Setup.Free;
      end;
      FormMain.Show;
      Sleep(250);
      Application.ProcessMessages;
      RunLayoutFlowRegressions(FormMain, Report);
      Check((FormMain.PageTabControl.ActiveTab = FormMain.TabLibraryPage) and
        (FormMain.PageTabControl.TabPosition = TTabPosition.None) and
        (FormMain.LibraryPage.Parent.Parent = FormMain.TabLibraryPage), 'Library is the initial hidden-tab page');
      FormMain.SelectAllSystems.IsChecked := False;
      Response := FormMain.CreateRunConfig;
      try
        Check(Response.GetValue<TJSONArray>('Systems').Count = 0, 'Unchecked systems are excluded from run');
      finally
        Response.Free
      end;
      FormMain.SelectAllSystems.IsChecked := True;
      Response := FormMain.CreateRunConfig;
      try
        Check(Response.GetValue<TJSONArray>('Systems').Count = FormMain.SettingsScope.Items.Count - 1,
          'Select all supplies every system to worker');
      finally
        Response.Free
      end;
      RowProbe := TRowLifetimeProbe.Create(nil);
      try
        if FormMain.PanelSystemListInner.ChildrenCount > 0 then
        begin
          RowButton := FormMain.PanelSystemListInner.Children[FormMain.PanelSystemListInner.ChildrenCount - 1] as TButton;
          RowButton.FreeNotification(RowProbe);
          RowGrid := nil;
          for I := 0 to RowButton.ComponentCount - 1 do
            if RowButton.Components[I] is TGridPanelLayout then
              RowGrid := TGridPanelLayout(RowButton.Components[I]);
          Check(RowGrid <> nil, 'Library row uses a shared column grid');
          Check(SameValue(RowGrid.ControlCollection.Controls[2, 0].AbsoluteRect.Left, FormMain.PathColumn.AbsoluteRect.Left, 1),
            'Library header and row ROM columns align');
          Check(SameValue(RowGrid.ControlCollection.Controls[3, 0].AbsoluteRect.Left, FormMain.OverrideColumn.AbsoluteRect.Left, 1),
            'Library header and row settings columns align');

          FormMain.PanelSystemListOuter.ViewportPosition := PointF(0, 200);
          ScrollBefore := FormMain.PanelSystemListOuter.ViewportPosition;
          for I := 1 to 10 do
          begin
            RowButton.OnClick(RowButton);
            Check(RowProbe.Removed = 0, 'System row survives click dispatch ' + I.ToString);
            TButtonInputAccess(RowButton).Click;
            TButtonInputAccess(RowButton).DblClick;
            TButtonInputAccess(RowButton).Click;
          end;
          Check(FormMain.SettingsScope.ItemIndex = RowButton.Tag + 1, 'Repeated clicks update selected system');
          Check(FormMain.PanelSystemListOuter.ViewportPosition = ScrollBefore, 'Selecting a system preserves scroll position');
          FormMain.ClientWidth := 1400;
          Application.ProcessMessages;
          Check(RowProbe.Removed = 0, 'Resizing preserves system input target');
          Check(SameValue(RowGrid.ControlCollection.Controls[2, 0].AbsoluteRect.Left, FormMain.PathColumn.AbsoluteRect.Left, 1) and
            SameValue(RowGrid.ControlCollection.Controls[3, 0].AbsoluteRect.Left, FormMain.OverrideColumn.AbsoluteRect.Left, 1),
            'Library columns remain aligned after resizing');

          FormMain.ClientWidth := 1280;
          FormMain.SelectAllSystems.IsChecked := False;
          FormMain.SelectAllSystems.IsChecked := True;
          Check(RowProbe.Removed = 0, 'Select all updates existing rows');
          RowButton.RemoveFreeNotification(RowProbe);
        end;
        if FormMain.PanelMediaInner.ChildrenCount > 0 then
        begin
          MediaButton := FormMain.PanelMediaInner.Children[FormMain.PanelMediaInner.ChildrenCount - 1] as TButton;
          MediaButton.FreeNotification(RowProbe);
          for I := 1 to 10 do
          begin
            MediaButton.OnClick(MediaButton);
            Check(RowProbe.Removed = 0, 'Media row survives click dispatch ' + I.ToString);
            TButtonInputAccess(MediaButton).Click;
            TButtonInputAccess(MediaButton).DblClick;
            TButtonInputAccess(MediaButton).Click;
          end;
          FormMain.ClientWidth := 1400;
          Application.ProcessMessages;
          Check(RowProbe.Removed = 0, 'Resizing preserves media input target');
          FormMain.ClientWidth := 1280;
          MediaButton.RemoveFreeNotification(RowProbe);
        end;
      finally
        RowProbe.Free
      end;
      FormMain.SettingsScope.ItemIndex := 1;
      FormMain.PanelSystemListOuter.ViewportPosition := PointF(0, 0);
      FormMain.SystemSearch.Text := 'no-system-matches-this-filter';
      Check(FormMain.PanelSystemListInner.ChildrenCount = 0, 'System search filters rows');
      FormMain.SystemSearch.Text := '';
      FormMain.NavSettingsClick(FormMain.NavSettings);
      OriginalOptimize := FormMain.CheckBoxOptimizeMediaStorage.IsChecked;
      OriginalLog := FormMain.CheckBoxSaveLogs.IsChecked;
      FormMain.CheckBoxSaveLogs.IsChecked := not OriginalLog;
      FormMain.CheckBoxOptimizeMediaStorage.IsChecked := not OriginalOptimize;
      if FormMain.PanelMediaInner.ChildrenCount > 1 then
      begin
        TButton(FormMain.PanelMediaInner.Children[1]).OnClick(FormMain.PanelMediaInner.Children[1]);
        TButton(FormMain.PanelMediaInner.Children[0]).OnClick(FormMain.PanelMediaInner.Children[0]);
      end;
      Check(FormMain.CheckBoxSaveLogs.IsChecked <> OriginalLog, 'Log switch binding survives settings refresh');
      Check(FormMain.CheckBoxOptimizeMediaStorage.IsChecked <> OriginalOptimize,
        'Media optimization switch persists through selection changes');
      FrozenTime := FormMain.EditSourceFolder.Text;
      FormMain.EditSourceFolder.Text := 'Z:\temporary-settings-test';
      FormMain.CancelSettingsClick(FormMain.CancelSettings);
      FormMain.SettingsScope.ItemIndex := 1;
      Check(FormMain.EditSourceFolder.Text = FrozenTime, 'Cancel restores settings transaction');
      Check(FormMain.CheckBoxOptimizeMediaStorage.IsChecked = OriginalOptimize, 'Cancel restores media switch value');
      Check(FormMain.CheckBoxSaveLogs.IsChecked = OriginalLog, 'Cancel restores logging switch value');
      FormMain.NavSettingsClick(FormMain.NavSettings);
      FormMain.SettingsScope.ItemIndex := 1;
      FormMain.SelectAllSystems.IsChecked := True;
      FormMain.CheckBoxResizeWidth.IsChecked := True;
      FormMain.CheckBoxResizeHeight.IsChecked := True;
      // Model.Text reproduces typing without Enter or losing focus. Assigning
      // the control's Text property would commit and conceal the original bug.
      FormMain.EditResizeWidth.Model.Text := '1237';
      FormMain.EditResizeHeight.Model.Text := '659';
      if FormMain.PanelMediaInner.ChildrenCount > 1 then
      begin
        TButton(FormMain.PanelMediaInner.Children[1]).OnClick(FormMain.PanelMediaInner.Children[1]);
        TButton(FormMain.PanelMediaInner.Children[0]).OnClick(FormMain.PanelMediaInner.Children[0]);
      end;
      Check((Round(FormMain.EditResizeWidth.Value) = 1237) and
        (Round(FormMain.EditResizeHeight.Value) = 659), 'Uncommitted numeric input survives media selection');
      FormMain.EditResizeWidth.Model.Text := '1241';
      FormMain.EditMediaOutputFolder.Model.Text := '%ROMROOTFOLDER%/pending-edit';
      FormMain.SaveSettingsClick(FormMain.SaveSettings);
      Account := TRetroScraperConfig.Create(WritableBase);
      try
        Media := Account.SystemAt(0).GetValue<TJSONArray>('Medias');
        Check((JInt(Media.Items[0], 'ResizeWidthValue') = 1241) and
          (JInt(Media.Items[0], 'ResizeHeightValue') = 659) and
          (JValue(Media.Items[0], 'ResizeWidthValue') is TJSONNumber) and
          (JValue(Media.Items[0], 'ResizeHeightValue') is TJSONNumber),
          'Save persists typed dimensions as JSON numbers before focus is lost');
        Check(JStr(Media.Items[0], 'OutputFolder') = '%ROMROOTFOLDER%/pending-edit',
          'Save also captures uncommitted text settings');
        Check(JInt(Account.SystemAt(0), 'Overriden') and 8 <> 0,
          'Editing inherited dimensions enables the media override');
        Check(JInt(Account.SystemAt(-1).GetValue<TJSONArray>('Medias').Items[0], 'ResizeWidthValue') <> 1241,
          'Platform dimensions leave global media settings unchanged');
      finally
        Account.Free;
      end;
      FormMain.NavSettingsClick(FormMain.NavSettings);
      FormMain.SettingsScope.ItemIndex := 1;
      FormMain.EditResizeWidth.Model.Text := '777';
      FormMain.CancelSettingsClick(FormMain.CancelSettings);
      FormMain.SettingsScope.ItemIndex := 1;
      Check(Round(FormMain.EditResizeWidth.Value) = 1241,
        'Cancel restores numeric settings after an uncommitted edit');
      FormMain.NavLibraryClick(FormMain.NavLibrary);
      Sleep(250);
      Application.ProcessMessages;
      Bitmap := TBitmap.Create(1280, 855);
      try
        Bitmap.Clear($FF333333);
        if Bitmap.Canvas.BeginScene then
        try
          FormMain.PaintTo(Bitmap.Canvas);
        finally
          Bitmap.Canvas.EndScene;
        end;
        Bitmap.SaveToFile(Folder + 'main-form.png');
        FormMain.NavSettingsClick(FormMain.NavSettings);
        for I := 0 to FormMain.SettingsTabControl.TabCount - 1 do
        begin
          FormMain.SettingsTabControl.TabIndex := I;
          Sleep(200);
          Application.ProcessMessages;
          Bitmap.Clear($FF333333);
          if Bitmap.Canvas.BeginScene then
          try
            FormMain.PaintTo(Bitmap.Canvas);
          finally
            Bitmap.Canvas.EndScene;
          end;
          Bitmap.SaveToFile(Folder + 'tab-' + I.ToString + '.png');
          Check(FormMain.SaveSettings.IsVisible and
            (FormMain.SaveSettings.AbsoluteRect.Bottom <= FormMain.ClientHeight),
            'Settings commands accessible on tab ' + I.ToString);
        end;
      finally
        Bitmap.Free;
      end;
      FormMain.NavSettingsClick(FormMain.NavSettings);
      FormMain.SettingsTabControl.ActiveTab := FormMain.TabMedia;
      FormMain.ClientWidth := 1600;
      FormMain.ClientHeight := 1000;
      Sleep(250);
      Application.ProcessMessages;
      Bitmap := TBitmap.Create(1600, 1000);
      try
        if Bitmap.Canvas.BeginScene then
        try
          FormMain.PaintTo(Bitmap.Canvas);
        finally
          Bitmap.Canvas.EndScene
        end;
        Bitmap.SaveToFile(Folder + 'media-concept-size.png');
      finally
        Bitmap.Free
      end;
      Bitmap := TBitmap.Create(1600, 1000);
      try
        for I := 0 to FormMain.SettingsTabControl.TabCount - 1 do
        begin
          FormMain.SettingsTabControl.TabIndex := I;
          Application.ProcessMessages;
          Bitmap.Clear($FF272727);
          if Bitmap.Canvas.BeginScene then
          try
            FormMain.PaintTo(Bitmap.Canvas);
          finally
            Bitmap.Canvas.EndScene
          end;
          Bitmap.SaveToFile(Folder + 'settings-concept-' + I.ToString + '.png');
          if I = 1 then
            Check(FormMain.RollingButtonGamelistBehavior.AbsoluteRect.Right < FormMain.CheckBoxOptimizeGameFile.AbsoluteRect.Left, 'List behavior field does not overlap compact XML option');
          if I = 4 then
            Check(FormMain.RaisedButtonClearAllCaches.AbsoluteRect.Right < FormMain.RaisedButtonClearGameInformationCache.AbsoluteRect.Left, 'Cache actions remain separate at concept width');
        end;
      finally
        Bitmap.Free
      end;
      FormMain.SettingsTabControl.ActiveTab := FormMain.TabGameList;
      FormMain.ToggleGameFilters(nil);
      Check(FormMain.PanelAutoHide2.IsVisible and FormMain.PanelAutoExclude2.IsVisible, 'Expanded filters expose both independent rule groups');
      FormMain.PanelScrollGamelistOuter.ViewportPosition := PointF(0, 0);
      Application.ProcessMessages;
      Handled := False;
      TScrollWheelAccess(FormMain.PanelScrollGamelistOuter).MouseWheel([], -120, Handled);
      Check(Handled and (Abs(FormMain.PanelScrollGamelistOuter.ViewportPosition.Y) < 1),
        'Mouse wheel starts animation without an immediate viewport jump');
      Started := TThread.GetTickCount64;
      while (FormMain.PanelScrollGamelistOuter.ViewportPosition.Y < 1) and
        (TThread.GetTickCount64 - Started < 1000) do
      begin
        Sleep(10);
        Application.ProcessMessages;
      end;
      Check(FormMain.PanelScrollGamelistOuter.ViewportPosition.Y > 0,
        'Animated wheel scrolling advances the viewport over time');

      FormMain.PanelScrollGamelistOuter.ViewportPosition := PointF(0, 500);
      Application.ProcessMessages;
      Bitmap := TBitmap.Create(1600, 1000);
      try
        if Bitmap.Canvas.BeginScene then
        try
          FormMain.PaintTo(Bitmap.Canvas);
        finally
          Bitmap.Canvas.EndScene
        end;
        Bitmap.SaveToFile(Folder + 'settings-filters-expanded.png');
      finally
        Bitmap.Free
      end;
      FormMain.PanelScrollGamelistOuter.ViewportPosition := PointF(0, 0);
      FormMain.ToggleGameFilters(nil);
      Check(not FormMain.PanelAutoHide2.Visible and not FormMain.PanelAutoExclude2.Visible, 'Extra filters collapse without replacing controls');
      Check(Abs(FormMain.AccountStatusDot.Width - FormMain.AccountStatusDot.Height) < 1, 'Account status indicator keeps its aspect ratio');
      FormMain.ClientWidth := 1280;
      FormMain.ClientHeight := 855;
      FormMain.BeginScrapeDisplay;
      Status := Default(TScrapeStatus);
      Status.Running := True;
      Status.Started := Now - 125 / 86400;
      Status.Stage := 'Downloading media';
      Status.CurrentFile := 'Super Mario World (USA).sfc';
      Status.CurrentSystem := 'Super Nintendo';
      Status.CurrentSystemID := '4';
      Status.CurrentTotal := 10;
      Status.CurrentCompleted := 4;
      Status.Total := 30;
      Status.Completed := 24;
      Status.SystemsTotal := 3;
      Status.SystemsCompleted := 2;
      Status.CurrentMedia := 2;
      Status.MediaTotal := 3;
      Status.MediaRequested := 12;
      Status.MediaFound := 9;
      Status.QuotaText := '1234 / 50000';
      Status.QuotaUpdated := Now;
      Status.Saved := 9;
      Status.Found := 4;
      Status.Requests := 16;
      Status.Errors := 2;
      SetLength(Status.Engines, 2);
      for I := 0 to 1 do
      begin
        Status.Engines[I].Running := True;
        Status.Engines[I].Stage := 'Downloading media';
        Status.Engines[I].FileName := 'Super Mario World (USA).sfc';
        Status.Engines[I].CurrentMedia := I + 1;
        Status.Engines[I].MediaTotal := 3;
      end;
      for I := 0 to 2 do
      begin
        case I of
          0:
            FileName := AppBase + 'Resources\SkraperUI.Properties.Samples\snesss.png';
          1:
            FileName := AppBase + 'Resources\SkraperUI.Properties.Samples\sneswheel.png';
          2:
            FileName := AppBase + 'Resources\SkraperUI.Properties.Samples\snesbox3D.png';
        end;
        Status.PreviewData[I] := TFile.ReadAllBytes(FileName);
        Status.PreviewRevision[I] := I + 1;
      end;
      FormMain.ApplyScrapeStatus(Status);
      EventRow := FormMain.ScrapeEventList.ListItems[0];
      FormMain.FastColoredTextBoxLogging.Lines.Add('14:32:08  Completed: Метаданные получены');
      FormMain.FastColoredTextBoxLogging.Lines.Add('14:32:09  Media saved: Обложка сохранена');
      FormMain.FastColoredTextBoxLogging.Lines.Add('14:32:10  Media error: Не удалось загрузить изображение');
      FormMain.NavLogClick(FormMain.NavLog);
      Check(FormMain.ScrapeEventList.ListItems[0] = EventRow, 'New log lines preserve existing event controls');
      Check((FormMain.PageTabControl.ActiveTab = FormMain.TabLogPage) and FormMain.FullLog.Lines.Text.Contains('Метаданные получены'), 'Full journal reflects the run log');
      Lines := TStringList.Create;
      try
        Lines.Assign(FormMain.FastColoredTextBoxLogging.Lines);
        for I := 1 to 250 do
          FormMain.FastColoredTextBoxLogging.Lines.Add('14:32:11  Journal fixture line ' + I.ToString);
        FormMain.ApplyScrapeStatus(Status);
        Application.ProcessMessages;
        Check(FormMain.FullLog.ViewportPosition.Y > 0, 'Journal follows new lines from the bottom');
        FormMain.FullLog.SelStart := 15;
        FormMain.FullLog.SelLength := 8;
        FormMain.FullLog.ViewportPosition := PointF(0, 200);
        ScrollBefore := FormMain.FullLog.ViewportPosition;
        for I := 1 to 5 do
          FormMain.ApplyScrapeStatus(Status);
        Application.ProcessMessages;
        Check((FormMain.FullLog.ViewportPosition = ScrollBefore) and (FormMain.FullLog.SelLength = 8),
          'Unchanged status ticks preserve journal viewport and text selection');
        FormMain.FastColoredTextBoxLogging.Lines.Add('14:32:12  Appended while reading older lines');
        FormMain.ApplyScrapeStatus(Status);
        Application.ProcessMessages;
        Check((FormMain.FullLog.ViewportPosition = ScrollBefore) and (FormMain.FullLog.SelStart = 15) and
          (FormMain.FullLog.SelLength = 8) and FormMain.FullLog.Lines.Text.Contains('Appended while reading'),
          'Appending journal lines preserves manual scroll and selection');
        Status.Running := False;
        Status.Finished := True;
        for I := 1 to 5 do
          FormMain.ApplyScrapeStatus(Status);
        Check(FormMain.FullLog.ViewportPosition = ScrollBefore,
          'Completed scraping does not reset journal viewport');
        FormMain.NavLibraryClick(FormMain.NavLibrary);
        FormMain.NavLogClick(FormMain.NavLog);
        Application.ProcessMessages;
        Check(FormMain.FullLog.ViewportPosition = ScrollBefore,
          'Returning to the journal preserves its reading position');
        FormMain.FullLog.ViewportPosition := PointF(0,
          Max(0, FormMain.FullLog.ContentSize.Height - FormMain.FullLog.ViewportSize.Height));
        ScrollBefore := FormMain.FullLog.ViewportPosition;
        FormMain.FastColoredTextBoxLogging.Lines.Add('14:32:13  Following the last line');
        FormMain.ApplyScrapeStatus(Status);
        Check(FormMain.FullLog.ViewportPosition.Y > ScrollBefore.Y,
          'Journal resumes following when reader scrolls to the bottom');
        FormMain.FastColoredTextBoxLogging.Lines.Clear;
        FormMain.ApplyScrapeStatus(Status);
        Check(FormMain.FullLog.Lines.Count = 0, 'Resetting source clears the full journal once');
        FormMain.BeginScrapeDisplay;
        FormMain.FastColoredTextBoxLogging.Lines.AddStrings(Lines);
        Status.Running := True;
        Status.Finished := False;
        FormMain.ApplyScrapeStatus(Status);
      finally
        Lines.Free
      end;

      FormMain.NavScrapingClick(FormMain.NavScraping);
      Check(FormMain.PageTabControl.ActiveTab = FormMain.TabScrapingPage, 'Navigation returns to the scraping tab');
      Check(FormMain.ScrapeStateText.Text = 'Выполняется', 'Scraping state badge reflects running status');
      Check(FormMain.ScrapeEventList.Count = 3, 'Run log renders events as list items');
      Check(not FormMain.FastColoredTextBoxLogging.Visible, 'Plain memo is hidden from scraping page');
      Check(FormMain.LabelErrorsValue.TextSettings.FontColor = $FFF0B455, 'Nonzero errors have warning accent');
      Check(not FormMain.PictureBoxScrapSample1.Bitmap.IsEmpty and
        not FormMain.PictureBoxScrapSample2.Bitmap.IsEmpty and
        not FormMain.PictureBoxScrapSample3.Bitmap.IsEmpty, 'All three scraping previews display snapshots');
      Check(not FormMain.LabelEngineState.Visible, 'Pool status replaces single-engine placeholder');
      Check(FormMain.LabelScrapingGameCount.Text = '24 из 30 игр', 'Game progress covers entire run');
      Check(FormMain.LabelMediaCoverage.Text.Contains('75'), 'Media coverage uses found/requested sources');
      Check(FormMain.ProgressBarMediaFoundPercent.Visible and
        (FormMain.ProgressBarMediaFoundPercent.Value = 9) and
        (FormMain.ProgressBarMediaFoundPercent.Max = 12), 'Session media coverage bar is visible and accurate');
      Check((FormMain.LabelQuotaValue.Text = '1234 / 50000') and
        (FormMain.ScrapeMetricsGrid.ColumnCollection.Count = 5), 'Quota is the fifth scraping metric');
      Check(not FormMain.PanelLeftPan.Enabled, 'System selection disabled while scraping');
      for I := 0 to 2 do
      begin
        if I = 1 then
          FormMain.ClientWidth := 1600;
        if I = 2 then
          FormMain.ClientHeight := 640;
        Application.ProcessMessages;
        Check(FormMain.ScrapeFooter.Position.Y + FormMain.ScrapeFooter.Height <= FormMain.PanelScrapingInProgress.Height + 1, 'Scraping commands remain inside page');
        Check(FormMain.ScrapeEventList.Height >= 120, 'Log remains visible at height ' + FormMain.ClientHeight.ToString);
        Bitmap := TBitmap.Create(Round(FormMain.ClientWidth), Round(FormMain.ClientHeight));
        try
          Bitmap.Clear($FF202020);
          if Bitmap.Canvas.BeginScene then
          try
            FormMain.PaintTo(Bitmap.Canvas);
          finally
            Bitmap.Canvas.EndScene
          end;
          Bitmap.SaveToFile(Folder + 'scraping-' + I.ToString + '.png');
          if I = 2 then
          begin
            FormMain.ScrapingScroll.ViewportPosition := PointF(0, FormMain.PanelScraping.Height - FormMain.ScrapingScroll.Height);
            Application.ProcessMessages;
            Check(FormMain.ScrapingScroll.ViewportPosition.Y > 0, 'Compact window can scroll to the run log');
            if Bitmap.Canvas.BeginScene then
            try
              FormMain.PaintTo(Bitmap.Canvas);
            finally
              Bitmap.Canvas.EndScene
            end;
            Bitmap.SaveToFile(Folder + 'scraping-compact-log.png');
          end;
        finally
          Bitmap.Free
        end;
      end;
      FormMain.ScrapingScroll.ViewportPosition := PointF(0, 0);
      FormMain.ClientWidth := 1280;
      FormMain.ClientHeight := 855;
      Status.Running := False;
      Status.Finished := True;
      Status.FinishedAt := Status.Started + 120 / 86400;
      FormMain.ApplyScrapeStatus(Status);
      FrozenTime := FormMain.LabelElapsedValue.Text;
      Status.FinishedAt := Status.Started + 120 / 86400;
      FormMain.ApplyScrapeStatus(Status);
      Check((FrozenTime = 'Прошло 00:02:00') and (FormMain.LabelElapsedValue.Text = FrozenTime), 'Elapsed time freezes at completion');
      FormMain.BeginScrapeDisplay;
      Check(FormMain.LabelSavedMediaValue.Text = '0', 'New run resets counters');
      Check(FormMain.PictureBoxScrapSample1.Bitmap.Width > 0, 'Preview surfaces survive reset');
      Response := TJSONObject.Create;
      try
        Worker := TScrapeWorker.Create(Response, Response, AppBase, -1);
      finally
        Response.Free
      end;
      Lines := TStringList.Create;
      try
        Worker.Terminate;
        Worker.Start;
        Worker.WaitFor;
        Worker.Snapshot(Status, Lines);
        Check(Status.Cancelled and Status.Finished and (Status.Errors = 0) and (Status.Completed = 0),
          'Cancel before start performs no request and reports no false error or completion');
        FormMain.ApplyScrapeStatus(Status);
        Check(FormMain.ScrapeSummary.Text.StartsWith('Остановлено'), 'Cancellation appears on scraping page');
      finally
        Lines.Free;
        Worker.Free
      end;
      Dependencies := RequiredMixMedia(AppBase + 'Mixes\4 Images Mix [HD][4-3].xml', '3');
      Check(Length(Dependencies) >= 4, 'Mix dependencies include composited image sources');
      Check(MatchNameExpression('Super Mario Bros', 'super*mario?'), 'Wildcard name filters');
      Check(MatchNameExpression('Mario 2', '<^mario [0-9]+$>'), 'Regex name filters');
      Check(not MatchNameExpression('Sonic', '<^mario>'), 'Regex rejects nonmatching game');
      Check(CleanRomName('[!] superMario_world.rom') = 'Super Mario World.rom', 'ROM filename cleanup: ' + CleanRomName('[!] superMario_world.rom'));
      RunRoot := Folder + 'input-' + TGUID.NewGuid.ToString + '\';
      ForceDirectories(RunRoot + 'game.scummvm');
      ForceDirectories(RunRoot + '.hidden');
      Config := TJSONObject.Create;
      try
        JSet(Config, 'GamesAndRoms.Path', TJSONString.Create(RunRoot));
        JSet(Config, 'GamesAndRoms.FileExtensions', TJSONArray.Create.Add('rom').Add('bin').Add('cue').Add('scummvm(dat|exe)'));
        TFile.WriteAllText(RunRoot + 'game.scummvm\a.dat', '12', TEncoding.ASCII);
        TFile.WriteAllText(RunRoot + 'game.scummvm\b.exe', '3456789', TEncoding.ASCII);
        TFile.WriteAllText(RunRoot + 'game.scummvm\ignored.rom', 'ignored', TEncoding.ASCII);
        TFile.WriteAllText(RunRoot + '.hidden\hidden.rom', 'ignored', TEncoding.ASCII);
        TFile.WriteAllText(RunRoot + 'disc.bin', 'payload', TEncoding.ASCII);
        TFile.WriteAllText(RunRoot + 'disc.cue', 'FILE "disc.bin" BINARY', TEncoding.UTF8);
        Dependencies := ScanInputs(Config);
        Check(Length(Dependencies) = 2, 'Scan excludes hidden paths, composite members and CUE tracks');
        JSet(Config, 'GameList.Type', TJSONNumber.Create(1));
        JSet(Config, 'GameList.Folders', TJSONNumber.Create(1));
        Check(InputFolderCount(Config, TArray<string>.Create(RunRoot + 'a\b\game.rom', RunRoot + 'a\game2.rom')) = 2, 'Global progress counts unique parent folders');
        Hashes := ComputeInputHashes(Config, RunRoot + 'game.scummvm', RunRoot + 'hashes');
        Check((Hashes.CRC = 'CBF43926') and (Hashes.Size = 9), 'Composite hashes concatenate sorted component bytes');
        Check(Hashes.Name = 'game.[dat,exe].scummvm', 'Composite query name contains component extensions');
        Zip := TZipFile.Create;
        try
          Zip.Open(RunRoot + 'joined.zip', zmWrite);
          Zip.Add(TEncoding.ASCII.GetBytes('3456789'), 'b.rom');
          Zip.Add(TEncoding.ASCII.GetBytes('12'), 'a.rom');
          Zip.Close;
        finally
          Zip.Free
        end;
        Hashes := ComputeInputHashes(Config, RunRoot + 'joined.zip', RunRoot + 'hashes');
        Check((Hashes.CRC = 'CBF43926') and (Hashes.Size = 9), 'Multi-entry ZIP uses ordered decompressed bytes');
        Payload := TFileStream.Create(RunRoot + 'large.rom', fmCreate);
        try
          Payload.Size := 20971520;
        finally
          Payload.Free
        end;
        Hashes := ComputeInputHashes(Config, RunRoot + 'large.rom', RunRoot + 'hashes');
        Check(not Hashes.FromCache, 'First large ROM hash is computed');
        Hashes := ComputeInputHashes(Config, RunRoot + 'large.rom', RunRoot + 'hashes');
        Check(Hashes.FromCache, 'Large ROM hashes reused from cache');
        Payload := TFileStream.Create(RunRoot + 'large.rom', fmOpenWrite);
        try
          Payload.Size := 20971521;
        finally
          Payload.Free
        end;
        Hashes := ComputeInputHashes(Config, RunRoot + 'large.rom', RunRoot + 'hashes');
        Check(not Hashes.FromCache and (Hashes.Size = 20971521), 'Changed ROM invalidates hash cache');
      finally
        Config.Free;
        TDirectory.Delete(RunRoot, True)
      end;
      Sources := TDictionary<string, string>.Create;
      try
        Sources.Add('ss', AppBase + 'Resources\SkraperUI.Properties.Samples\snesss.png');
        Sources.Add('wheel', AppBase + 'Resources\SkraperUI.Properties.Samples\sneswheel.png');
        Sources.Add('box-3D', AppBase + 'Resources\SkraperUI.Properties.Samples\snesbox3D.png');
        Sources.Add('support-2D', AppBase + 'Resources\SkraperUI.Properties.Samples\snessupport2D.png');
        RenderMix(AppBase + 'Mixes\4 Images Mix [HD][4-3].xml', Sources, Folder + 'mix.png', 800, 600);
        Bitmap := TBitmap.Create;
        try
          Bitmap.LoadFromFile(Folder + 'mix.png');
          Check((Bitmap.Width = 800) and (Bitmap.Height = 600), 'Original 4-image composition');
        finally
          Bitmap.Free;
        end;
        Sources.AddOrSetValue('@systemid', '21');
        Sources.AddOrSetValue('@name', 'Test title');
        RenderMix(AppBase + 'Mixes\Sega GameGear\SegaGamegear.xml', Sources, Folder + 'gamegear.png', 640, 480);
        Check(TFile.Exists(Folder + 'gamegear.png'), 'Original GameGear projection with includes and system condition');
        RenderMix(AppBase + 'Mixes\ZX-81\Old Fashioned ZX-81.xml', Sources, Folder + 'zx81.png', 640, 480);
        Check(TFile.Exists(Folder + 'zx81.png'), 'Original ZX81 barrel composition');
        Bitmap := TBitmap.Create(8, 8);
        try
          Bitmap.Clear($FFFF0000);
          Bitmap.SaveToFile(Folder + 'red.png');
        finally
          Bitmap.Free
        end;
        Sources.AddOrSetValue('@parent:999', '21');
        Sources['@systemid'] := '999';
        TFile.WriteAllText(Folder + 'layout.xml', '<Mix><Viewport Width="100" Height="80"/><Drawings>' +
          '<Item Type="FanArt"><Fallback Type="LocalFile" LocalFilePath="red.png"><Display X="10" Y="10" Width="50!" Height="20" KeepRatio="false"/></Fallback></Item>' +
          '<Item IfSystem="IsInTheListOrAncestors:21"><Children><Item Type="LocalFile" LocalFilePath="red.png"><Display X="80" Y="60" Width="10" Height="10"/></Item></Children></Item>' +
          '<Item Type="FanArt"><Children><Item Type="LocalFile" LocalFilePath="red.png"><Display X="60" Y="40" Width="10" Height="10"/></Item></Children></Item>' +
          '</Drawings></Mix>', TEncoding.UTF8);
        RenderMix(Folder + 'layout.xml', Sources, Folder + 'layout.png', 0, 0);
        Bitmap := TBitmap.Create;
        try
          Bitmap.LoadFromFile(Folder + 'layout.png');
          Check(Bitmap.Map(TMapAccess.Read, Pixels), 'Read mix pixels');
          try
            Check((Pixels.GetPixel(12, 12) = $FFFF0000) and (Pixels.GetPixel(48, 12) = $FFFF0000) and
              (Pixels.GetPixel(52, 12) = 0), 'Fallback display and perpendicular percentages');
            Check(Pixels.GetPixel(84, 64) = $FFFF0000, 'System condition walks parent chain');
            Check(Pixels.GetPixel(64, 44) = 0, 'Missing parent suppresses children by default');
          finally
            Bitmap.Unmap(Pixels)
          end;
        finally
          Bitmap.Free
        end;
        TFile.WriteAllText(Folder + 'text.xml', '<Mix><Viewport Width="240" Height="100" ImageFormat="Jpg"/>' +
          '<Drawings><Item Type="Text" Text="%name%%%%publisher%" TextColor="#FFFFFFFF" TextOutlineColor="#FF000000" FontFile="' + AppBase + 'Mixes\ZX-81\ka1.ttf" FontStyle="Regular" TextAlign="VCenterHCenter">' +
          '<Display Width="100%" Height="100%"/></Item></Drawings></Mix>', TEncoding.UTF8);
        Sources.AddOrSetValue('@publisher', 'Publisher');
        RenderMix(Folder + 'text.xml', Sources, Folder + 'text.png', 0, 0);
        Check(MixExtension(Folder + 'text.xml') = '.jpg', 'Mix output format follows viewport');
        Check(TFile.GetSize(Folder + 'text.png') > 500, 'Mix text renders metadata with fitted font');
        TFile.WriteAllText(Folder + 'cycle-a.xml', '<Mix><Viewport Width="32" Height="32"/><Drawings><Item Type="Include" LocalFilePath="cycle-b.xml"/></Drawings></Mix>', TEncoding.UTF8);
        TFile.WriteAllText(Folder + 'cycle-b.xml', '<Mix><Viewport Width="32" Height="32"/><Drawings><Item Type="Include" LocalFilePath="cycle-a.xml"/></Drawings></Mix>', TEncoding.UTF8);
        Rejected := False;
        try
          RenderMix(Folder + 'cycle-a.xml', Sources, Folder + 'cycle.png', 32, 32);
        except
          on E: Exception do
            Rejected := E.Message.Contains('cyclic includes');
        end;
        Check(Rejected, 'Reject indirect cyclic mix includes');
        Rejected := False;
        try
          RenderMix(Folder + 'not-existing.xml', Sources, Folder + 'missing.png', 32, 32);
        except
          on E: Exception do
            Rejected := E.Message.Contains('not found');
        end;
        Check(Rejected, 'Report missing template without substituting screenshot');
      finally
        Sources.Free;
      end;
      if FindCmdLineSwitch('online') then
      begin
        Account := TRetroScraperConfig.Create(AppBase);
        try
          API := TScreenScraper.Create(Account.Credentials, Folder + 'api');
          try
            Response := API.Authenticate;
            try
              Check(JValue(Response, 'response.ssuser') <> nil, 'Live account validation');
            finally
              Response.Free;
            end;
            Response := API.Request('jeuInfos.php', 'gameid=3', False);
            try
              Check(JValue(Response, 'response.jeu') <> nil, 'Live game metadata');
              SanitizeResponse(Response);
              WriteJSON(Folder + 'game-fixture.json', Response);
            finally
              Response.Free;
            end;
          finally
            API.Free;
          end;
          RunRoot := Folder + 'pipeline\';
          ForceDirectories(RunRoot + 'roms');
          TFile.WriteAllText(RunRoot + 'roms\fixture.rom', '123456789', TEncoding.ASCII);
          TFile.Copy(Folder + 'payload.zip', RunRoot + 'roms\archived.zip', True);
          Config := Account.Root.Clone as TJSONObject;
          try
            JSet(Config, 'FrontEnd.Type', TJSONNumber.Create(4));
            JSet(Config, 'FrontEnd.Kill', TJSONBool.Create(False));
            Item := Account.SystemAt(-1).Clone as TJSONObject;
            JSet(Item, 'SystemId', TJSONNumber.Create(1));
            JSet(Item, 'Overriden', TJSONNumber.Create(31));
            JSet(Item, 'GamesAndRoms.Path', TJSONString.Create(RunRoot + 'roms'));
            JSet(Item, 'GamesAndRoms.FileExtensions', TJSONArray.Create.Add('rom').Add('zip'));
            JSet(Item, 'GameList.OutputFile', TJSONString.Create('%ROMROOTFOLDER%\gamelist.xml'));
            JSet(Item, 'GameList.Type', TJSONNumber.Create(1));
            JSet(Item, 'GameList.Behavior', TJSONNumber.Create(1));
            JSet(Item, 'Miscellaneous.CacheTTLInDays', TJSONNumber.Create(3));
            JSet(Item, 'Miscellaneous.Method', TJSONNumber.Create(0));
            Media := TJSONArray.Create;
            Media.AddElement(TJSONObject.ParseJSONValue('{"Type":0,"Image":0,"OutputFolder":"%ROMROOTFOLDER%/media","ResizeWidth":true,"ResizeHeight":true,"ResizeWidthValue":64,"ResizeHeightValue":64,"KeepRatio":true,"LinkToNode":true}'));
            JSet(Media.Items[0] as TJSONObject, 'EmptyOutputFolder', TJSONBool.Create(True));
            Media.AddElement(Media.Items[0].Clone as TJSONValue);
            Media.AddElement(Media.Items[0].Clone as TJSONValue);
            JSet(Media.Items[2] as TJSONObject, 'Image', TJSONNumber.Create(3));
            JSet(Item, 'Medias', Media);
            Systems := TJSONArray.Create;
            Systems.AddElement(Item);
            JSet(Config, 'Systems', Systems);
            Hashes := ComputeInputHashes(Item, RunRoot + 'roms\fixture.rom', RunRoot + 'Cache\hashes');
            CRC := Hashes.CRC;
            MD5 := Hashes.MD5;
            SHA1 := Hashes.SHA1;
            Params := 'systemeid=1&romtype=rom&romnom=Fixture.rom&romtaille=9&crc=' + CRC + '&md5=' + MD5 + '&sha1=' + SHA1;
            Response := ReadJSON(Folder + 'game-fixture.json');
            try
              JSet(Response, 'response.jeu.romid', TJSONNumber.Create(1));
              WriteJSON(RunRoot + 'Cache\api\' + THashSHA2.GetHashString('jeuInfos.php?' + Params) + '.json', Response);
              Params := Params.Replace('Fixture.rom', 'Archived.zip');
              WriteJSON(RunRoot + 'Cache\api\' + THashSHA2.GetHashString('jeuInfos.php?' + Params) + '.json', Response);
            finally
              Response.Free;
            end;
            ForceDirectories(RunRoot + 'roms\media');
            TFile.WriteAllText(RunRoot + 'roms\media\managed-orphan.png', 'old');
            TFile.WriteAllText(RunRoot + 'roms\media\personal.png', 'user');
            Response := TJSONObject.Create;
            try
              Response.AddPair('files', TJSONArray.Create.Add(RunRoot + 'roms\media\managed-orphan.png'));
              WriteJSON(RunRoot + 'State\MediaIndex\' + THashSHA2.GetHashString((RunRoot + 'roms').ToLower) + '.json', Response);
            finally
              Response.Free;
            end;
            Worker := TScrapeWorker.Create(Config, Account.Credentials, RunRoot, 0);
            Lines := TStringList.Create;
            try
              Worker.Start;
              Started := TThread.GetTickCount64;
              while not Worker.Finished and (TThread.GetTickCount64 - Started < 90000) do
                CheckSynchronize(50);
              if not Worker.Finished then
                Worker.Terminate;
              Worker.WaitFor;
              Worker.Snapshot(Status, Lines);
              Lines.SaveToFile(Folder + 'pipeline.log', TEncoding.UTF8);
              Check(Status.Errors = 0, 'Pipeline has no errors');
              Check(not TFile.Exists(RunRoot + 'roms\media\managed-orphan.png'), 'Cleanup removes previously managed orphan media');
              Check(TFile.Exists(RunRoot + 'roms\media\personal.png'), 'Cleanup preserves unrelated files');
              Check(TFile.Exists(RunRoot + 'roms\fixture.rom'), 'Cleanup preserves ROMs');
              Check(Status.Completed = 2, 'Pipeline completes raw and ZIP ROMs');
              Check(Length(Status.Engines) = 2, 'Processing pool uses both games independently of the account network limit');
              Check(Status.Saved = 6, 'Pipeline downloads and resizes six media');
              Check(Status.PreviewRevision[0] > 0, 'Worker publishes sampled image snapshots');
              FormMain.ApplyScrapeStatus(Status);
              Check(not FormMain.PictureBoxScrapSample1.Bitmap.IsEmpty, 'Actual worker image reaches FMX preview');
              Check((Status.MediaFound = Status.MediaRequested) and (Status.MediaRequested > 0), 'Worker reports media coverage');
              Check(TFile.Exists(RunRoot + 'roms\gamelist.xml'), 'Pipeline writes gamelist');
              Doc := LoadXMLDocument(RunRoot + 'roms\gamelist.xml');
              Check(Doc.DocumentElement.ChildNodes[0].ChildNodes['image'].Text <>
                Doc.DocumentElement.ChildNodes[0].ChildNodes['thumbnail'].Text, 'Distinct image and thumbnail files');
              Check(Doc.DocumentElement.ChildNodes[0].ChildNodes['box'].Text.StartsWith('./'), 'Box node uses relative path');
            finally
              Lines.Free;
              Worker.Free;
            end;
            Item := TJSONArray(JValue(Config, 'Systems')).Items[0] as TJSONObject;
            JSet(Item, 'GamesAndRoms.FileExtensions', TJSONArray.Create.Add('rom'));
            Response := ReadJSON(Folder + 'game-fixture.json');
            try
              JSet(Response, 'response.jeu.romid', TJSONNumber.Create(0));
              Params := 'systemeid=1&romtype=rom&romnom=Fixture.rom&romtaille=9&crc=' + CRC + '&md5=' + MD5 + '&sha1=' + SHA1;
              WriteJSON(RunRoot + 'Cache\api\' + THashSHA2.GetHashString('jeuInfos.php?' + Params) + '.json', Response);
              Params := 'systemeid=1&romtype=jeu&romnom=Fixture';
              WriteJSON(RunRoot + 'Cache\api\' + THashSHA2.GetHashString('jeuInfos.php?' + Params) + '.json', Response);
            finally
              Response.Free
            end;
            Worker := TScrapeWorker.Create(Config, Account.Credentials, RunRoot, 0);
            Lines := TStringList.Create;
            try
              Worker.Start;
              Started := TThread.GetTickCount64;
              while not Worker.Finished and (TThread.GetTickCount64 - Started < 90000) do
                CheckSynchronize(50);
              if not Worker.Finished then
                Worker.Terminate;
              Worker.WaitFor;
              Worker.Snapshot(Status, Lines);
              Check((Status.Errors = 0) and (Status.Completed = 1) and (Status.Found = 1) and (Status.Cached = 2),
                'Unknown ROM falls back to game-name request');
            finally
              Lines.Free;
              Worker.Free
            end;
            JSet(Item, 'GamesAndRoms.FileExtensions', TJSONArray.Create.Add('rom').Add('zip'));
            Worker := TScrapeWorker.Create(Config, Account.Credentials, RunRoot, 0, True, 2);
            Lines := TStringList.Create;
            try
              Worker.Start;
              Started := TThread.GetTickCount64;
              while not Worker.Finished and (TThread.GetTickCount64 - Started < 30000) do
                CheckSynchronize(50);
              if not Worker.Finished then
                Worker.Terminate;
              Worker.WaitFor;
              Worker.Snapshot(Status, Lines);
              Check((Status.Errors = 0) and (Status.Completed = 2) and (Length(Status.Engines) = 2) and (Status.Requests = 0),
                'Two parallel engines finish from offline cache without exceeding account quota');
            finally
              Lines.Free;
              Worker.Free
            end;
          finally
            Config.Free;
          end;
        finally
          Account.Free;
        end;
      end;
      RunFeatureTests(Report);
      RunQuotaStopRegressions(Report);
      RunNetworkQueueRegressions(Report);
      RunAlgorithmRegressions(Report);
      RunPlatformTests(Report);
      Report.Add('ALL TESTS PASSED');
    except
      on E: Exception do
      begin
        Report.Add(E.ClassName + ': ' + E.Message);
        ExitCode := 1;
      end;
    end;
  finally
    Report.SaveToFile(Folder + 'results.txt', TEncoding.UTF8);
    Report.Free;
  end;
end;

end.

