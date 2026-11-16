program RetroScraper;

uses
  System.StartUpCopy,
  System.SysUtils,
  Xml.xmldom,
  Xml.omnixmldom,
  FMX.Forms,
  SK.Consts in 'sources\Common\SK.Consts.pas',
  SK.Platform in 'sources\Common\SK.Platform.pas',
  SK.Platform.Graphics in 'sources\Common\SK.Platform.Graphics.pas',
  FMX.Edit.VisibilityFix in 'sources\UI\FMX.Edit.VisibilityFix.pas',
  SK.Storage in 'sources\Common\SK.Storage.pas',
  SK.Json in 'sources\Common\SK.Json.pas',
  SK.Xml in 'sources\Common\SK.Xml.pas',
  SK.Configuration in 'sources\Settings\SK.Configuration.pas',
  SK.ScreenScraper in 'sources\Services\SK.ScreenScraper.pas',
  SK.Core in 'sources\Common\SK.Core.pas',
  SK.Input in 'sources\Scraping\SK.Input.pas',
  SK.Output in 'sources\Scraping\SK.Output.pas',
  SK.Scenarios in 'sources\Scraping\SK.Scenarios.pas',
  SK.Metadata in 'sources\Library\SK.Metadata.pas',
  SK.GameList in 'sources\Library\SK.GameList.pas',
  SK.Data in 'sources\Library\SK.Data.pas',
  SK.GameLibrary in 'sources\Library\SK.GameLibrary.pas',
  SK.Catalog in 'sources\Catalog\SK.Catalog.pas',
  SK.Frontend in 'sources\Library\SK.Frontend.pas',
  SK.Cache in 'sources\Media\SK.Cache.pas',
  SK.Artwork in 'sources\Media\SK.Artwork.pas',
  SK.Artwork.Folders in 'sources\Media\SK.Artwork.Folders.pas',
  SK.Mix in 'sources\Media\SK.Mix.pas',
  SK.Preview in 'sources\Media\SK.Preview.pas',
  SK.Folders in 'sources\Common\SK.Folders.pas',
  SK.Locale in 'sources\Common\SK.Locale.pas',
  SK.Scrape.Types in 'sources\Scraping\SK.Scrape.Types.pas',
  SK.Settings.Session in 'sources\Settings\SK.Settings.Session.pas',
  SK.Services.Catalog in 'sources\Catalog\SK.Services.Catalog.pas',
  SK.Engine in 'sources\Scraping\SK.Engine.pas',
  HGM.FMX.Image in 'dependencies\HGM\HGM.FMX.Image.pas',
  SK.UI.Controls in 'sources\UI\SK.UI.Controls.pas',
  SK.UI.Settings in 'sources\UI\SK.UI.Settings.pas',
  SK.UI.FieldEditor in 'sources\UI\SK.UI.FieldEditor.pas',
  SK.UI.Log in 'sources\UI\SK.UI.Log.pas',
  SK.UI.Scraping in 'sources\UI\SK.UI.Scraping.pas',
  SK.Setup in 'sources\UI\SK.Setup.pas' {FormSetup},
  SK.GameLibrary.Form in 'sources\UI\SK.GameLibrary.Form.pas' {FormGameLibrary},
  SK.Main in 'sources\UI\SK.Main.pas' {FormMain},
  SK.Settings.Tests in 'sources\Tests\SK.Settings.Tests.pas',
  SK.Features.Tests in 'sources\Tests\SK.Features.Tests.pas',
  SK.GameLibrary.Tests in 'sources\Tests\SK.GameLibrary.Tests.pas',
  SK.Parity.Tests in 'sources\Tests\SK.Parity.Tests.pas',
  {$IFDEF MSWINDOWS}
  SK.Tests in 'sources\Tests\SK.Tests.pas',
  SK.Lookup.Tests in 'sources\Tests\SK.Lookup.Tests.pas',
  {$ENDIF }
  SK.Platform.Tests in 'sources\Tests\SK.Platform.Tests.pas',
  Z7.Archive.Filters in 'dependencies\Delphi7z\Z7.Archive.Filters.pas',
  Z7.Archive.Lzma in 'dependencies\Delphi7z\Z7.Archive.Lzma.pas',
  Z7.Archive in 'dependencies\Delphi7z\Z7.Archive.pas';

{$R *.res}

begin
  DefaultDOMVendor := sOmniXmlVendor;
  Application.Initialize;
  Application.Title := AppBrand;
  if FindCmdLineSwitch('wizardconcepttest') then
  begin
    RunWizardConceptSelfTests;
    Halt(ExitCode);
  end;
  if FindCmdLineSwitch('editvisibilitytest') then
  begin
    RunEditVisibilitySelfTests;
    Halt(ExitCode);
  end;
  if FindCmdLineSwitch('paritytest') then
  begin
    RunSelectedParitySelfTests;
    Halt(ExitCode);
  end;
  if FindCmdLineSwitch('directorytest') then
  begin
    RunDirectoryDetectionSelfTests;
    Halt(ExitCode);
  end;
  if FindCmdLineSwitch('librarytest') then
  begin
    RunGameLibrarySelfTests;
    Halt(ExitCode);
  end;
  {$IFDEF MSWINDOWS}
  if FindCmdLineSwitch('lookuptest') then
  begin
    RunLookupSelfTests;
    Halt(ExitCode);
  end;
  {$ENDIF}
  if FindCmdLineSwitch('selftest') then
  begin
    {$IFDEF MSWINDOWS}RunSelfTests;{$ELSE}RunPortableSelfTests;{$ENDIF}
    Halt(ExitCode);
  end;
  Application.CreateForm(TFormMain, FormMain);
  Application.Run;
end.
