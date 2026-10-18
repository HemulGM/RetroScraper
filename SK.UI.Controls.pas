unit SK.UI.Controls;

interface

uses
  System.SysUtils, System.Classes, FMX.Types, FMX.StdCtrls;

function RequireComponent(Owner: TComponent; const Name: string): TComponent;

function FindStyledPart(Root: TFmxObject; const PartName: string): TFmxObject;

procedure SetRowAccent(Button: TButton; Selected: Boolean);

procedure AddRowAccent(Button: TButton; Selected, Divider: Boolean);

implementation

uses
  System.Types, FMX.Objects, FMX.Graphics;

function RequireComponent(Owner: TComponent; const Name: string): TComponent;
begin
  Result := Owner.FindComponent(Name);
  if Result = nil then
    raise EComponentError.Create('Missing FMX component: ' + Name);
end;

function FindStyledPart(Root: TFmxObject; const PartName: string): TFmxObject;
var
  Child, Found: TFmxObject;
begin
  if Root.StyleName = PartName then
    Exit(Root);
  if Root.Children <> nil then
    for Child in Root.Children do
    begin
      Found := FindStyledPart(Child, PartName);
      if Found <> nil then
        Exit(Found);
    end;
  Result := nil;
end;

procedure SetRowAccent(Button: TButton; Selected: Boolean);
var
  Child: TFmxObject;
begin
  for Child in Button.Children do
    if (Child is TRectangle) and (Child.StyleName = 'rowaccent') then
      TRectangle(Child).Visible := Selected;
end;

procedure AddRowAccent(Button: TButton; Selected, Divider: Boolean);
var
  Surface: TRectangle;
begin
  Surface := TRectangle.Create(Button);
  Surface.Parent := Button;
  Surface.StyleName := 'rowaccent';
  Surface.Align := TAlignLayout.Contents;
  Surface.Fill.Color := $FF304B5B;
  Surface.Stroke.Kind := TBrushKind.None;
  Surface.XRadius := 4;
  Surface.YRadius := 4;
  Surface.HitTest := False;
  Surface.Visible := Selected;
  if Divider then
  begin
    Surface := TRectangle.Create(Button);
    Surface.Parent := Button;
    Surface.Align := TAlignLayout.Bottom;
    Surface.Height := 1;
    Surface.Fill.Color := $FF414141;
    Surface.Stroke.Kind := TBrushKind.None;
    Surface.HitTest := False;
  end;
end;

end.
