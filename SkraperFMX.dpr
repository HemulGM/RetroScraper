program SkraperFMX;

uses
  System.StartUpCopy,
  Xml.xmldom, Xml.omnixmldom,
  SK.Consts in 'SK.Consts.pas',
  SK.Platform in 'SK.Platform.pas',
  SK.Platform.Graphics in 'SK.Platform.Graphics.pas',
  System.SysUtils,
  FMX.Forms,
  FMX.Edit.VisibilityFix in 'FMX.Edit.VisibilityFix.pas',
  SK.Main in 'SK.Main.pas' {FormMain},
  SK.Core in 'SK.Core.pas',
  SK.Catalog in 'SK.Catalog.pas',
  SK.Artwork in 'SK.Artwork.pas',
  SK.Cache in 'SK.Cache.pas',
  SK.Locale in 'SK.Locale.pas',
  SK.Preview in 'SK.Preview.pas',
  SK.Features.Tests in 'SK.Features.Tests.pas',
  SK.Parity.Tests in 'SK.Parity.Tests.pas',
  SK.Input in 'SK.Input.pas',
  SK.Engine in 'SK.Engine.pas',
  SK.Mix in 'SK.Mix.pas',
  SK.Data in 'SK.Data.pas',
  HGM.FMX.Image in 'HGM.FMX.Image.pas',
  SK.GameLibrary in 'SK.GameLibrary.pas',
  SK.GameLibrary.Tests in 'SK.GameLibrary.Tests.pas',
  SK.GameLibrary.Form in 'SK.GameLibrary.Form.pas' {FormGameLibrary},
  {$IFDEF MSWINDOWS}SK.Tests in 'SK.Tests.pas',{$ENDIF}
  SK.Platform.Tests in 'SK.Platform.Tests.pas',
  SK.Frontend in 'SK.Frontend.pas',
  SK.Setup in 'SK.Setup.pas';

{$R *.res}

begin
  DefaultDOMVendor := sOmniXmlVendor;
  Application.Initialize;
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
