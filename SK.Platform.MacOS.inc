const SecurityFramework = '/System/Library/Frameworks/Security.framework/Security';
function FindPassword(Keychain: Pointer; ServiceLength: Cardinal; Service: MarshaledAString;
  AccountLength: Cardinal; Account: MarshaledAString; var PasswordLength: Cardinal;
  var Password, Item: Pointer): Integer; cdecl; external SecurityFramework name 'SecKeychainFindGenericPassword';
function AddPassword(Keychain: Pointer; ServiceLength: Cardinal; Service: MarshaledAString;
  AccountLength: Cardinal; Account: MarshaledAString; PasswordLength: Cardinal; Password: Pointer;
  Item: Pointer): Integer; cdecl; external SecurityFramework name 'SecKeychainAddGenericPassword';
function ModifyPassword(Item, Attributes: Pointer; Length: Cardinal; Data: Pointer): Integer; cdecl;
  external SecurityFramework name 'SecKeychainItemModifyAttributesAndData';
function FreePassword(Attributes, Data: Pointer): Integer; cdecl; external SecurityFramework name 'SecKeychainItemFreeContent';
procedure ReleaseCF(Value: Pointer); cdecl; external '/System/Library/Frameworks/CoreFoundation.framework/CoreFoundation' name 'CFRelease';
function MacSecret(const Identity, Value: string; WriteAccess: Boolean): string;
var Key, Service, Secret: UTF8String; Data, Item: Pointer; Size: Cardinal; Code: Integer;
begin
  Result:=''; Key:=UTF8String(THashSHA2.GetHashString(Identity)); Service:='org.skraperfmx.Credentials';
  Data:=nil; Item:=nil; Size:=0;
  Code:=FindPassword(nil,Length(Service),MarshaledAString(Service),Length(Key),MarshaledAString(Key),Size,Data,Item);
  try
    if (Code<>0) and (Code<>errSecItemNotFound) then raise Exception.CreateFmt('Keychain access failed (%d)',[Code]);
    if WriteAccess then
    begin
      Secret:=UTF8String(Value);
      if Code=errSecItemNotFound then
        Code:=AddPassword(nil,Length(Service),MarshaledAString(Service),Length(Key),MarshaledAString(Key),Length(Secret),Pointer(Secret),nil)
      else Code:=ModifyPassword(Item,nil,Length(Secret),Pointer(Secret));
      if Code<>0 then raise Exception.CreateFmt('Cannot save Keychain credentials (%d)',[Code]);
    end
    else if Code=0 then begin SetString(Secret,MarshaledAString(Data),Size); Result:=string(Secret) end;
  finally
    if Data<>nil then FreePassword(nil,Data);
    if Item<>nil then ReleaseCF(Item);
  end;
end;
function NativeLoadSecret(const Identity: string): string;
begin Result:=MacSecret(Identity,'',False) end;
procedure NativeSaveSecret(const Identity, Value: string);
begin MacSecret(Identity,Value,True) end;
