unit SK.Locale;

interface

uses
  System.SysUtils, System.Classes;

procedure SetLocale(const Culture: string);

function CurrentLocale: string;

function CommandLineCulture(const Default: string): string;

function UILocaleIndex(const Culture: string): Integer;

function UILocaleCode(Index: Integer): string;

function L(const Text: string): string; overload;

function L(const Text: string; const Args: array of const): string; overload;

procedure ApplyLocale(Form: TComponent);

implementation

uses
  System.JSON, System.Math, System.IOUtils, System.TypInfo,
  System.Generics.Collections, FMX.Controls, FMX.StdCtrls, FMX.Edit, FMX.ListBox,
  FMX.TabControl, SK.Platform, SK.Json;

type
  TLocaleBindings = class(TComponent)
  private
    Originals: TObjectDictionary<TComponent, TJSONObject>;
  protected
    procedure Notification(AComponent: TComponent; Operation: TOperation); override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure Apply;
  end;

const
  SupportedCultures: array[0..6] of string = ('ru', 'en', 'de', 'es', 'fr', 'it', 'pt');

var
  Values: TJSONObject;
  CultureCode: string;
  Guard: TObject;

function UILocaleIndex(const Culture: string): Integer;
var
  I: Integer;
  Code: string;
begin
  Code := Culture.ToLower.Split(['-', '_'])[0];
  for I := 0 to High(SupportedCultures) do
    if SupportedCultures[I] = Code then
      Exit(I);
  Result := 1;
end;

function UILocaleCode(Index: Integer): string;
begin
  if (Index < 0) or (Index > High(SupportedCultures)) then
    Index := 1;
  Result := SupportedCultures[Index];
end;

function CommandLineCulture(const Default: string): string;
var
  I: Integer;
begin
  Result := Default;
  for I := 1 to ParamCount do
    if ParamStr(I).ToLower.StartsWith('-culture=') then
      Exit(ParamStr(I).Substring(9));
end;

procedure SetLocale(const Culture: string);
var
  Code: string;
  NewValues: TJSONObject;
begin
  Code := Culture.Trim.ToLower;
  if Code.Contains('-') then
    Code := Code.Substring(0, Code.IndexOf('-'));
  if Code.Contains('_') then
    Code := Code.Substring(0, Code.IndexOf('_'));
  Code := UILocaleCode(UILocaleIndex(Code));
  NewValues := ReadJSON(TPlatformPath.Combine(ResourceBase, 'Resources/Locales/' + Code + '.json'));
  if NewValues = nil then
    raise Exception.Create('Language resources are missing: ' + Code);
  TMonitor.Enter(Guard);
  try
    Values.Free;
    Values := NewValues;
    CultureCode := Code;
  finally
    TMonitor.Exit(Guard)
  end;
end;

function CurrentLocale: string;
begin
  TMonitor.Enter(Guard);
  try
    Result := CultureCode
  finally
    TMonitor.Exit(Guard)
  end;
end;

function L(const Text: string): string;
var
  V: TJSONValue;
begin
  TMonitor.Enter(Guard);
  try
    V := nil;
    if Values <> nil then
      V := Values.GetValue(Text);
    if V is TJSONString then
      Result := V.Value
    else
      Result := Text;
  finally
    TMonitor.Exit(Guard)
  end;
end;

function L(const Text: string; const Args: array of const): string;
begin
  Result := Format(L(Text), Args)
end;

constructor TLocaleBindings.Create(AOwner: TComponent);
begin
  inherited;
  Originals := TObjectDictionary<TComponent, TJSONObject>.Create([doOwnsValues]);
end;

destructor TLocaleBindings.Destroy;
begin
  FreeAndNil(Originals);
  inherited
end;

procedure TLocaleBindings.Notification(AComponent: TComponent; Operation: TOperation);
begin
  inherited;
  if (Operation = opRemove) and (Originals <> nil) then
    Originals.Remove(AComponent);
end;

procedure TLocaleBindings.Apply;
var
  I, J, Selection: Integer;
  C: TComponent;
  Obj: TJSONObject;
  V: TJSONValue;
  A: TJSONArray;
  Combo: TComboBox;
begin
  for I := 0 to Owner.ComponentCount - 1 do
  begin
    C := Owner.Components[I];
    if C.Name = '' then
      Continue;
    if not ((C is TLabel) or (C is TButton) or (C is TCheckBox) or (C is TRadioButton) or
      (C is TTabItem) or (C is TEdit) or (C is TComboBox)) then
      Continue;
    if not Originals.TryGetValue(C, Obj) then
    begin
      Obj := TJSONObject.Create;
      if (C is TLabel) or (C is TButton) or (C is TCheckBox) or (C is TRadioButton) or (C is TTabItem) then
        Obj.AddPair('Text', GetStrProp(C, 'Text'));
      if C is TEdit then
        Obj.AddPair('TextPrompt', TEdit(C).TextPrompt);
      if (C is TComboBox) and (C.Name <> 'RollingButtonSystemSelect') and
        (C.Name <> 'SettingsScope') and (C.Name <> 'UILanguage') then
      begin
        A := TJSONArray.Create;
        for J := 0 to TComboBox(C).Items.Count - 1 do
          A.Add(TComboBox(C).Items[J]);
        Obj.AddPair('Items', A);
      end;
      Originals.Add(C, Obj);
      C.FreeNotification(Self);
    end;
    V := Obj.GetValue('Text');
    if V <> nil then
      SetStrProp(C, 'Text', L(V.Value));
    V := Obj.GetValue('TextPrompt');
    if V <> nil then
      TEdit(C).TextPrompt := L(V.Value);
    V := Obj.GetValue('Items');
    if V is TJSONArray then
    begin
      Combo := TComboBox(C);
      Selection := Combo.ItemIndex;
      for J := 0 to Min(TJSONArray(V).Count, Combo.Items.Count) - 1 do
        Combo.Items[J] := L(TJSONArray(V).Items[J].Value);
      Combo.ItemIndex := Selection;
    end;
  end;
end;

procedure ApplyLocale(Form: TComponent);
var
  Bindings: TLocaleBindings;
begin
  Bindings := Form.FindComponent('LocaleBindings') as TLocaleBindings;
  if Bindings = nil then
  begin
    Bindings := TLocaleBindings.Create(Form);
    Bindings.Name := 'LocaleBindings'
  end;
  Bindings.Apply;
end;

initialization
  Guard := TObject.Create;
  CultureCode := 'ru';

finalization
  Values.Free;
  Guard.Free;

end.

