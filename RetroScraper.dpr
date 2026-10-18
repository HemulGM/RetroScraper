program RetroScraper;

uses
  System.StartUpCopy,
  System.SysUtils,
  Xml.xmldom,
  Xml.omnixmldom,
  FMX.Forms,
  SK.Consts in 'SK.Consts.pas',
  SK.Platform in 'SK.Platform.pas',
  SK.Platform.Graphics in 'SK.Platform.Graphics.pas',
  FMX.Edit.VisibilityFix in 'FMX.Edit.VisibilityFix.pas',
  SK.Storage in 'SK.Storage.pas',
  SK.Json in 'SK.Json.pas',
  SK.Xml in 'SK.Xml.pas',
  SK.Configuration in 'SK.Configuration.pas',
  SK.ScreenScraper in 'SK.ScreenScraper.pas',
  SK.Core in 'SK.Core.pas',
  SK.Input in 'SK.Input.pas',
  SK.Output in 'SK.Output.pas',
  SK.Metadata in 'SK.Metadata.pas',
  SK.GameList in 'SK.GameList.pas',
  SK.Data in 'SK.Data.pas',
  SK.GameLibrary in 'SK.GameLibrary.pas',
  SK.Catalog in 'SK.Catalog.pas',
  SK.Frontend in 'SK.Frontend.pas',
  SK.Cache in 'SK.Cache.pas',
  SK.Artwork in 'SK.Artwork.pas',
  SK.Artwork.Folders in 'SK.Artwork.Folders.pas',
  SK.Mix in 'SK.Mix.pas',
  SK.Preview in 'SK.Preview.pas',
  SK.Folders in 'SK.Folders.pas',
  SK.Locale in 'SK.Locale.pas',
  SK.Scrape.Types in 'SK.Scrape.Types.pas',
  SK.Settings.Session in 'SK.Settings.Session.pas',
  SK.Services.Catalog in 'SK.Services.Catalog.pas',
  SK.Engine in 'SK.Engine.pas',
  HGM.FMX.Image in 'HGM.FMX.Image.pas',
  SK.UI.Controls in 'SK.UI.Controls.pas',
  SK.UI.Settings in 'SK.UI.Settings.pas',
  SK.UI.FieldEditor in 'SK.UI.FieldEditor.pas',
  SK.UI.Log in 'SK.UI.Log.pas',
  SK.UI.Scraping in 'SK.UI.Scraping.pas',
  SK.Setup in 'SK.Setup.pas' {FormSetup},
  SK.GameLibrary.Form in 'SK.GameLibrary.Form.pas' {FormGameLibrary},
  SK.Main in 'SK.Main.pas' {FormMain},
  SK.Settings.Tests in 'SK.Settings.Tests.pas',
  SK.Features.Tests in 'SK.Features.Tests.pas',
  SK.GameLibrary.Tests in 'SK.GameLibrary.Tests.pas',
  SK.Parity.Tests in 'SK.Parity.Tests.pas',
  {$IFDEF MSWINDOWS}
  SK.Tests in 'SK.Tests.pas',
  {$ENDIF }
  SK.Platform.Tests in 'SK.Platform.Tests.pas',
  Z7.Archive.Filters in 'Delphi7z\Z7.Archive.Filters.pas',
  Z7.Archive.Lzma in 'Delphi7z\Z7.Archive.Lzma.pas',
  Z7.Archive in 'Delphi7z\Z7.Archive.pas';

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
  if FindCmdLineSwitch('selftest') then
  begin
    {$IFDEF MSWINDOWS}RunSelfTests;{$ELSE}RunPortableSelfTests;{$ENDIF}
    Halt(ExitCode);
  end;
  Application.CreateForm(TFormMain, FormMain);
  Application.Run;
end.
