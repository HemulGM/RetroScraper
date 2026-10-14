unit SK.Preview;

interface

uses System.SysUtils, System.JSON, System.Generics.Collections;

function PreviewSources(Catalog, Settings: TJSONObject; Sample: Integer): TDictionary<string, string>;
function MediaPreview(Media, Settings, Catalog: TJSONObject; Sample: Integer; const Cache: string): string;
function MixTitle(const Template: string): string;

implementation

uses System.Classes, System.IOUtils, System.Hash, System.Math, System.StrUtils, FMX.Graphics,
  Xml.XMLDoc, Xml.XMLIntf, System.Variants, SK.Core, SK.Mix, SK.Consts, SK.Platform, SK.Locale;

function MixTitle(const Template: string): string;
var Doc: IXMLDocument; Info: IXMLNode;
begin
  Result := TPath.GetFileNameWithoutExtension(Template);
  if not TFile.Exists(Template) then Exit;
  try
    Doc := LoadXMLDocument(Template); Info := Doc.DocumentElement.ChildNodes.FindNode('Info');
    if (Info <> nil) and Info.HasAttribute('LongName') then Result := VarToStr(Info.Attributes['LongName']);
  except
    // An invalid template is reported by preview; a list title should still be usable.
  end;
end;

function PreviewSources(Catalog, Settings: TJSONObject; Sample: Integer): TDictionary<string, string>;
const
  Files: array[0..29] of string = ('ss','sstitle','fanart','box2Dfront','box2Dside',
    'box2Dback','box3D','boxtexture','support2D','supporttexture','wheel','wheelcarbon',
    'wheelsteel','steamgrid','screenmarquee','screenmarqueesmall','marquee','mixrbv1',
    'mixrbv2','systembezel43','systembezel169','systemwheel','systemwheelcarbon',
    'systemwheelsteel','systemlogomonochrome','systemicon','systemminicon',
    'systemphoto','systempicture','systemcontroller');
  Keys: array[0..29] of string = ('ss','sstitle','fanart','box-2D','box-2D-side',
    'box-2D-back','box-3D','box-texture','support-2D','support-texture','wheel',
    'wheel-carbon','wheel-steel','steamgrid','screenmarquee','screenmarqueesmall',
    'marquee','mixrbv1','mixrbv2','system:bezel-4-3','system:bezel-16-9','system:wheel',
    'system:wheel-carbon','system:wheel-steel','system:logo-monochrome','system:icon',
    'system:minicon','system:photo','system:illustration','system:controller');
var Folder, Prefix, Path: string; I: Integer; V: TJSONValue;
  procedure Add(const Key, Name: string);
  var FileName: string;
  begin
    FileName := Folder + Name + '.png';
    if TFile.Exists(FileName) then Result.AddOrSetValue(Key, FileName);
  end;
begin
  Result := TDictionary<string, string>.Create;
  try
    Folder := TPlatformPath.Combine(AppBase, 'Resources/SkraperUI.Properties.Samples/');
    Prefix := MixSamplePrefixes[EnsureRange(Sample mod 6, 0, 5)];
    for I := 0 to High(Keys) do Add(Keys[I], Prefix + Files[I]);
    // Some samples use an explicit controllerphoto suffix; arcade systems use mame.
    Add('system:controller', Prefix + 'systemcontrollerphoto');
    if Prefix.StartsWith('arcade') then
      for I := 19 to High(Keys) do Add(Keys[I], 'mame' + Files[I]);
    Add('system:screenmarquee', Prefix + 'systemscreenmarquee');
    Add('system:background', Prefix + 'systemwallpaper');
    if Prefix.StartsWith('arcade') then
    begin Add('system:screenmarquee', 'mamesystemscreenmarquee'); Add('system:background', 'mamesystemwallpaper') end;
    if not Result.ContainsKey('marquee') and Result.TryGetValue('screenmarquee', Path) then Result.Add('marquee', Path);
    Add('classification:pictoliste', '_classification');
    Add('developpeur:pictocouleur', 'acmedevcolor'); Add('developpeur:pictomonochrome', 'acmedevmono');
    Add('editeur:pictocouleur', 'acmepubcolor'); Add('editeur:pictomonochrome', 'acmepubmono');
    for I := 1 to 3 do
    begin
      Add('genre:pictoliste#' + I.ToString, 'pictoliste' + I.ToString);
      Add('genre:pictomonochrome#' + I.ToString, 'pictomonochromelogo' + I.ToString);
    end;
    Add('region1', '_flageu'); Add('region2', '_flagus');
    // The original sample set reuses genre pictograms for player/rating placeholders.
    Add('joueurs:pictoliste', 'pictoliste2'); Add('note:pictoliste', 'pictoliste1');
    Result.Add('@systemid', JStr(Settings, 'SystemId', '0'));
    if JValue(Catalog, 'systemes') is TJSONArray then
      for V in TJSONArray(JValue(Catalog, 'systemes')) do
        Result.AddOrSetValue('@parent:' + JStr(V, 'id'), JStr(V, 'parentid', '0'));
    Result.Add('@name', SK.Locale.L('НАЗВАНИЕ ИГРЫ'));
    Result.Add('@publisher', 'Publisher Ltd.'); Result.Add('@developer', 'Developer Studio');
    Result.Add('@description', SK.Locale.L('Пример описания игры. Играйте и получайте удовольствие!'));
    Result.Add('@genre', SK.Locale.L('Экшен')); Result.Add('@genre0', SK.Locale.L('Экшен'));
    Result.Add('@genre1', SK.Locale.L('Приключения')); Result.Add('@genre2', SK.Locale.L('Платформер'));
    Result.Add('@players', '1-2'); Result.Add('@minplayers', '1'); Result.Add('@maxplayers', '2');
    Result.Add('@region', 'EU, US'); Result.Add('@region0', 'EU'); Result.Add('@region1', 'US');
    Result.Add('@releasedate', '1987-05-13'); Result.Add('@rating', '0.9'); Result.Add('@classification', '7');
  except Result.Free; raise end;
end;

function MediaPreview(Media, Settings, Catalog: TJSONObject; Sample: Integer; const Cache: string): string;
var Sources: TDictionary<string, string>; Kind, Image, W, H: Integer;
  Template, Key, PreviewFile: string; Scale: Double;
  procedure FitPreview(const FileName: string);
  begin
    if JBool(Media, 'ResizeWidth') and JBool(Media, 'ResizeHeight') and not JBool(Media, 'KeepRatio', True) then
    begin
      W := Max(1, JInt(Media, 'ResizeWidthValue', DefaultMediaWidth));
      H := Max(1, JInt(Media, 'ResizeHeightValue', DefaultMediaHeight));
      Scale := Min(MixPreviewWidth / W, MixPreviewHeight / H);
      ResizeImage(FileName, FileName, Max(1, Round(W * Scale)), Max(1, Round(H * Scale)), False);
    end
    else ResizeImage(FileName, FileName, MixPreviewWidth, MixPreviewHeight, True);
  end;
begin
  Result := ''; Sources := PreviewSources(Catalog, Settings, Sample);
  try
    Kind := JInt(Media, 'Type'); Image := JInt(Media, 'Image');
    if Kind in [1, 2] then
    begin
      if Kind = 1 then Template := TPlatformPath.Combine(AppBase, 'Mixes/' + BuiltInMixFiles[EnsureRange(JInt(Media, 'InternalMix'), 0, 6)])
      else Template := JStr(Media, 'LocalMixFile');
      if Template = '' then Exit;
      ForceDirectories(Cache);
      Result := TPlatformPath.Combine(Cache, THashSHA2.GetHashString(Template + '|' +
        JStr(Settings, 'SystemId') + '|' + Sample.ToString) + MixExtension(Template));
      RenderMix(Template, Sources, Result, 0, 0);
      FitPreview(Result);
    end
    else if Kind = 0 then
    begin
      if (Image >= 0) and (Image <= High(ScreenScraperImageTypes)) then
        Sources.TryGetValue(ScreenScraperImageTypes[Image], Result)
      else if (Image >= Low(ScreenScraperExtendedImageTypes)) and
        (Image <= High(ScreenScraperExtendedImageTypes)) then
        Sources.TryGetValue(ScreenScraperExtendedImageTypes[Image], Result);
      if (Result <> '') and JBool(Media, 'ResizeWidth') and JBool(Media, 'ResizeHeight') and
        not JBool(Media, 'KeepRatio', True) then
      begin
        ForceDirectories(Cache);
        PreviewFile := TPlatformPath.Combine(Cache, THashSHA2.GetHashString(Result + Media.ToJSON) + '.png');
        TFile.Copy(Result, PreviewFile, True); FitPreview(PreviewFile); Result := PreviewFile;
      end;
    end
    else
    begin
      case Kind of
        3: Key := '_video'; 4: Key := '_normalizedvideo'; 5: Key := '_docpdf';
        6: Key := '_tips'; 7: Key := '_pad2key'; 8: Key := '_map';
      else Key := '' end;
      if Key <> '' then Result := TPlatformPath.Combine(AppBase, 'Resources/SkraperUI.Properties.Samples/' + Key + '.png');
      if not TFile.Exists(Result) then Result := '';
    end;
  finally Sources.Free end;
end;

end.
