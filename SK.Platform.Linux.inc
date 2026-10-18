type
  THashNew = function(Hash, Equal: Pointer): Pointer; cdecl;
  THashInsert = function(Table, Key, Value: Pointer): Integer; cdecl;
  TNativeFree = procedure(Value: Pointer); cdecl;
  TPasswordLookup = function(Schema, Attributes, Cancel: Pointer; var Error: Pointer): MarshaledAString; cdecl;
  TPasswordStore = function(Schema, Attributes: Pointer; Collection, LabelText, Password: MarshaledAString;
    Cancel: Pointer; var Error: Pointer): Integer; cdecl;
function LinuxSecret(const Identity, Value: string; WriteAccess: Boolean): string;
var Lib: NativeUInt; Attributes, Error: Pointer;
  NewHash: THashNew; Insert: THashInsert; FreeHash, FreePassword, FreeError: TNativeFree;
  Lookup: TPasswordLookup; StorePassword: TPasswordStore;
  Key, Secret: UTF8String; Password: MarshaledAString;
begin
  Result:=''; Lib:=dlopen('libsecret-1.so.0',RTLD_LAZY);
  if Lib=0 then begin
    if WriteAccess then raise Exception.Create('Install libsecret and unlock a Secret Service keyring to save credentials');
    Exit;
  end;
  try
    NewHash:=THashNew(dlsym(Lib,'g_hash_table_new')); Insert:=THashInsert(dlsym(Lib,'g_hash_table_insert'));
    FreeHash:=TNativeFree(dlsym(Lib,'g_hash_table_unref')); FreePassword:=TNativeFree(dlsym(Lib,'secret_password_free'));
    FreeError:=TNativeFree(dlsym(Lib,'g_error_free')); Lookup:=TPasswordLookup(dlsym(Lib,'secret_password_lookupv_sync'));
    StorePassword:=TPasswordStore(dlsym(Lib,'secret_password_storev_sync'));
    if not Assigned(NewHash) or not Assigned(Insert) or not Assigned(FreeHash) or not Assigned(FreePassword) or
      not Assigned(FreeError) or not Assigned(Lookup) or not Assigned(StorePassword) then
      raise Exception.Create('Incompatible libsecret installation');
    Attributes:=NewHash(dlsym(Lib,'g_str_hash'),dlsym(Lib,'g_str_equal'));
    if Attributes=nil then raise Exception.Create('Cannot allocate secret attributes');
    Error:=nil;
    try
      Key:=UTF8String(THashSHA2.GetHashString(Identity)); Secret:=UTF8String(Value);
      Insert(Attributes,MarshaledAString('application'),MarshaledAString(CredentialServiceID));
      Insert(Attributes,MarshaledAString('account'),MarshaledAString(Key));
      // Use non-variadic APIs: their ABI is identical across Delphi/C compilers.
      if WriteAccess then begin
        if StorePassword(nil,Attributes,nil,AppBrand + ' ScreenScraper',MarshaledAString(Secret),nil,Error)=0 then
          raise Exception.Create('Cannot save credentials: unlock the desktop keyring');
      end else begin
        Password:=Lookup(nil,Attributes,nil,Error);
        try
          if Error<>nil then raise Exception.Create('Cannot read credentials: unlock the desktop keyring');
          if Password<>nil then Result:=string(UTF8String(Password));
        finally if Password<>nil then FreePassword(Password) end;
      end;
    finally
      if Error<>nil then FreeError(Error);
      FreeHash(Attributes);
    end;
  finally dlclose(Lib) end;
end;
function NativeLoadSecret(const Identity: string): string;
begin Result:=LinuxSecret(Identity,'',False) end;
procedure NativeSaveSecret(const Identity, Value: string);
begin LinuxSecret(Identity,Value,True) end;
