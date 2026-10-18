unit SK.Xml;

interface

uses
  Xml.XMLIntf;

function XmlChildText(Node: IXMLNode; const Name: string): string;

procedure SetXmlChildText(Node: IXMLNode; const Name, Value: string; SkipEmpty: Boolean = False);

implementation

function XmlChildText(Node: IXMLNode; const Name: string): string;
var
  Child: IXMLNode;
begin
  Result := '';
  Child := Node.ChildNodes.FindNode(Name);
  if Child <> nil then
    Result := Child.Text;
end;

procedure SetXmlChildText(Node: IXMLNode; const Name, Value: string; SkipEmpty: Boolean);
var
  Child: IXMLNode;
begin
  if SkipEmpty and (Value = '') then
    Exit;
  Child := Node.ChildNodes.FindNode(Name);
  if Child = nil then
    Child := Node.AddChild(Name);
  Child.Text := Value;
end;

end.
