unit SK.UI.Settings;

interface

uses
  System.SysUtils, System.JSON, FMX.Controls, FMX.Edit, FMX.StdCtrls,
  FMX.ListBox, FMX.NumberBox;

procedure ApplySettingValue(Control: TControl; Obj: TJSONObject; const Path: string; Spec: TArray<string>; CacheTTL: TComboBox = nil);

// Returns an owned value, or nil if a control has no applicable/valid value.
function ReadSettingValue(Control: TControl; Obj: TJSONObject; const Path: string; Spec: TArray<string>; CacheTTL: TComboBox = nil): TJSONValue;

implementation

uses
  SK.Json, SK.Consts, SK.Locale;

procedure ApplySettingValue(Control: TControl; Obj: TJSONObject; const Path: string; Spec: TArray<string>; CacheTTL: TComboBox);
var
  C: TControl;
  V, Item: TJSONValue;
  Text: string;
  N: Integer;
begin
  C := Control;
  V := JValue(Obj, Path);
  Text := JStr(Obj, Path);
  N := JInt(Obj, Path);
  if (Length(Spec) > 2) and (Spec[1] = 'integer') then
    N := JInt(Obj, Path, StrToIntDef(Spec[2], 0));
  if (Length(Spec) > 2) and ((Spec[1] = 'array') or (Spec[1] = 'systems')) and (Spec[2] = '') then
    Spec[2] := '|';
  if (Length(Spec) > 1) and ((Spec[1] = 'array') or (Spec[1] = 'systems')) then
  begin
    Text := '';
    if V is TJSONArray then
      for Item in TJSONArray(V) do
      begin
        if Text <> '' then
          Text := Text + Spec[2];
        Text := Text + Item.Value;
      end;
  end;
  if C is TNumberBox then
    TNumberBox(C).Value := N
  else if C is TEdit then
    TEdit(C).Text := Text
  else if C is TSwitch then
    TSwitch(C).IsChecked := JBool(Obj, Path)
  else if C is TCheckBox then
  begin
    if (Length(Spec) > 1) and (Spec[1] = 'bit') then
      TCheckBox(C).IsChecked := (N and StrToInt(Spec[2])) <> 0
    else
      TCheckBox(C).IsChecked := JBool(Obj, Path);
  end
  else if C is TRadioButton then
  begin
    if Length(Spec) > 2 then
      if Spec[1] = 'radio-bool' then
        TRadioButton(C).IsChecked := SameText(Text, Spec[2])
      else
        TRadioButton(C).IsChecked := N = StrToInt(Spec[2]);
  end
  else if C is TComboBox then
  begin
    if (Length(Spec) > 1) and (Spec[1] = 'rating') then
      N := (N - 40) div 5;
    if (Length(Spec) > 1) and (Spec[1] = 'text') then
      N := TComboBox(C).Items.IndexOf(Text);
    if C = CacheTTL then
    begin
      while CacheTTL.Items.Count > 17 do
        CacheTTL.Items.Delete(17);
      if N >= UnlimitedCacheDays then
        N := 16
      else if N >= 16 then
      begin
        CacheTTL.Tag := N;
        CacheTTL.Items.Add(L('%d дн.', [N]));
        N := 17;
      end;
    end;
    TComboBox(C).ItemIndex := N;
  end;
end;

function ReadSettingValue(Control: TControl; Obj: TJSONObject; const Path: string; Spec: TArray<string>; CacheTTL: TComboBox): TJSONValue;
var
  C: TControl;
  Value: TJSONValue;
  A: TJSONArray;
  Text, S: string;
  N, Bit: Integer;
begin
  Result := nil;
  C := Control;
  Value := nil;
  if C is TNumberBox then
  begin
    // Value is validated on commit; Text already contains the current keystrokes.
    if not TryStrToInt(TNumberBox(C).Text.Trim, N) or
      (N < TNumberBox(C).Min) or (N > TNumberBox(C).Max) then
      Exit;
    Value := TJSONNumber.Create(N);
  end
  else if C is TEdit then
  begin
    Text := TEdit(C).Text;
    if (Length(Spec) > 1) and ((Spec[1] = 'array') or (Spec[1] = 'systems')) then
    begin
      A := TJSONArray.Create;
      for S in Text.Split([Spec[2][1]]) do
        if S.Trim <> '' then
          A.Add(S.Trim);
      Value := A;
    end
    else if JValue(Obj, Path) is TJSONNumber then
    begin
      if not TryStrToInt(Text, N) or (N < 0) then
        Exit;
      Value := TJSONNumber.Create(N);
    end
    else
      Value := TJSONString.Create(Text);
  end
  else if C is TSwitch then
    Value := TJSONBool.Create(TSwitch(C).IsChecked)
  else if C is TCheckBox then
  begin
    if (Length(Spec) > 1) and (Spec[1] = 'bit') then
    begin
      N := JInt(Obj, Path);
      Bit := StrToInt(Spec[2]);
      if TCheckBox(C).IsChecked then
        N := N or Bit
      else
        N := N and not Bit;
      Value := TJSONNumber.Create(N);
    end
    else
      Value := TJSONBool.Create(TCheckBox(C).IsChecked);
  end
  else if C is TRadioButton then
  begin
    if TRadioButton(C).IsChecked and (Length(Spec) > 2) then
      if Spec[1] = 'radio-bool' then
        Value := TJSONBool.Create(Spec[2] = 'true')
      else
        Value := TJSONNumber.Create(StrToInt(Spec[2]));
  end
  else if C is TComboBox then
  begin
    N := TComboBox(C).ItemIndex;
    if N < 0 then
      Exit;
    if (Length(Spec) > 1) and (Spec[1] = 'text') then
      Value := TJSONString.Create(TComboBox(C).Items[N])
    else
    begin
      if (Length(Spec) > 1) and (Spec[1] = 'rating') then
        N := N * 5 + 40;
      if C = CacheTTL then
      begin
        if N = 16 then
          N := UnlimitedCacheDays
        else if N = 17 then
          N := CacheTTL.Tag;
      end;
      Value := TJSONNumber.Create(N);
    end;
  end;
  Result := Value;
end;

end.

