unit FMX.Edit.VisibilityFix;

interface

implementation

uses
  System.Classes, System.Types, FMX.Controls, FMX.Edit, FMX.Edit.Style.New,
  FMX.Graphics, FMX.Text.LinesLayout, FMX.Presentation.Style,
  FMX.Presentation.Factory, FMX.Controls.Presentation;

type
  TLinesLayoutAccess = class(TLinesLayout);

  TVisibleStyledEdit = class(TStyledEdit)
  protected
    procedure ContentPaint(Sender: TObject; ACanvas: TCanvas; const ARect: TRectF); override;
  end;

var
  PreviousPresentation: TPresentationProxyClass;

procedure TVisibleStyledEdit.ContentPaint(Sender: TObject; ACanvas: TCanvas; const ARect: TRectF);
begin
  // RAD Studio 13's new editor can release a line layout while its viewport is
  // empty or narrow. A later width change with leading alignment does not
  // necessarily recreate it, and TLineObject.Render silently skips nil layouts.
  // Restore only visible missing layouts, preserving the framework's masking,
  // selection, caret, IME and resource reuse. Focus and the text model stay intact.
  if not Editor.LinesLayout.IsUpdating then
  begin
    Editor.LinesLayout.RealignIfNeeded;
    TLinesLayoutAccess(Editor.LinesLayout).CreateLayoutsForVisibleLinesIfNotCreated;
  end;
  inherited;
end;

initialization
  PreviousPresentation := TPresentationProxyFactory.Current.FindPresentationProxyClass(
    TPresentationProxyFactory.GeneratePresentationName(TEdit, TControlType.Styled));
  TPresentationProxyFactory.Current.Replace(TEdit, TControlType.Styled,
    TStyledPresentationProxy<TVisibleStyledEdit>);

finalization
  if (PreviousPresentation <> nil) and
    (TPresentationProxyFactory.Current.FindPresentationProxyClass(
    TPresentationProxyFactory.GeneratePresentationName(TEdit, TControlType.Styled)) =
    TStyledPresentationProxy<TVisibleStyledEdit>) then
    TPresentationProxyFactory.Current.Replace(TEdit, TControlType.Styled, PreviousPresentation);

end.

