unit SK.UI.FieldEditor;

interface

uses
  System.SysUtils, System.Classes, FMX.Types, FMX.Layouts, FMX.Objects, FMX.StdCtrls, FMX.Edit,
  FMX.Memo, SK.GameLibrary;

type
  TGameFieldEditor = class(TLayout)
  private
    function GetText: string;
    procedure SetText(const Value: string);
  public
    Field: TLibraryField;
    HeaderLayout, ValueColumn, InputFrame, EditorArea, InputControlFrame: TLayout;
    ErrorFrame: TRectangle;
    CaptionLabel, ErrorLabel, MediaNote: TLabel;
    HelpText, ErrorText: string;
    InfoButton: TButton;
    InfoIcon: FMX.Objects.TPath;
    HelpLabel: TLabel;
    ValueEdit: TEdit;
    ValueMemo: TMemo;
    MediaImage: TImage;
    PreviewLoading: Boolean;
    MediaCommands: TLayout;
    ReplaceMediaButton, ClearMediaButton: TButton;
    constructor CreateFromTemplate(AOwner: TComponent; Template: TLayout);
    procedure BindControls;
    property Text: string read GetText write SetText;
  end;

function FieldCaption(const Name: string): string;

function FieldOrder(Field: TLibraryField): Integer;

implementation

uses
  System.StrUtils, FMX.BehaviorManager, SK.Locale, SK.UI.Controls;

function FieldCaption(const Name: string): string;
begin
  Result := Name;
  if MatchText(Name, ['name', 'Title', '@name']) then
    Result := L('Название')
  else if MatchText(Name, ['desc', 'Notes', 'description']) then
    Result := L('Описание')
  else if SameText(Name, 'developer') then
    Result := L('Разработчик')
  else if SameText(Name, 'publisher') then
    Result := L('Издатель')
  else if SameText(Name, 'players') then
    Result := L('Число игроков')
  else if MatchText(Name, ['rating', 'StarRatingFloat']) then
    Result := L('Рейтинг')
  else if MatchText(Name, ['releasedate', 'ReleaseDate']) then
    Result := L('Дата выпуска')
  else if SameText(Name, 'genre') then
    Result := L('Жанр')
  else if SameText(Name, 'region') then
    Result := L('Регион')
  else if SameText(Name, 'favorite') then
    Result := L('Избранное')
  else if MatchText(Name, ['hidden', 'Hide']) then
    Result := L('Скрытая игра')
  else if SameText(Name, 'image') then
    Result := L('Изображение')
  else if SameText(Name, 'thumbnail') then
    Result := L('Миниатюра')
  else if SameText(Name, 'box') then
    Result := L('Обложка')
  else if MatchText(Name, ['logo', 'marquee']) then
    Result := L('Логотип')
  else if MatchText(Name, ['video', 'VideoPath']) then
    Result := L('Видео')
  else if MatchText(Name, ['manual', 'ManualPath']) then
    Result := L('Руководство')
  else if MatchText(Name, ['path', 'ApplicationPath', 'rom/@name']) then
    Result := L('Путь ROM');
end;

function FieldOrder(Field: TLibraryField): Integer;
begin
  Result := 100;
  if MatchText(Field.Caption, ['name', 'Title', '@name']) then
    Exit(0);
  if MatchText(Field.Caption, ['desc', 'Notes', 'description']) then
    Exit(1);
  if MatchText(Field.Caption, ['rating', 'StarRatingFloat']) then
    Exit(2);
  if MatchText(Field.Caption, ['releasedate', 'ReleaseDate']) then
    Exit(3);
  if SameText(Field.Caption, 'players') then
    Exit(4);
  if SameText(Field.Caption, 'box') then
    Exit(5);
  if MatchText(Field.Caption, ['image', 'ImagePath', 'BoxFrontImagePath']) then
    Exit(6);
  if Field.IsMedia then
    Exit(10);
  if SameText(Field.Caption, 'developer') then
    Exit(20);
  if SameText(Field.Caption, 'publisher') then
    Exit(21);
  if SameText(Field.Caption, 'genre') then
    Exit(22);
  if SameText(Field.Caption, 'region') then
    Exit(23);
  if SameText(Field.Caption, 'classification') then
    Exit(24);
  if SameText(Field.Caption, 'favorite') then
    Exit(25);
  if MatchText(Field.Caption, ['hidden', 'Hide']) then
    Exit(26);
  if Field.Rule(1) = lrRomPath then
    Exit(30);
  if MatchText(Field.Caption, ['hash', 'crc', 'md5', 'sha1']) then
    Exit(40);
  if Field.Caption.StartsWith('@') then
    Exit(90);
end;

constructor TGameFieldEditor.CreateFromTemplate(AOwner: TComponent; Template: TLayout);
var
  I: Integer;
  Child: TFmxObject;
begin
  inherited Create(AOwner);
  if Template = nil then
    raise EArgumentNilException.Create('Template');
  BeginUpdate;
  try
    Width := Template.Width;
    Height := Template.Height;
    Margins.Assign(Template.Margins);
    Padding.Assign(Template.Padding);
    // The designer stores only standard controls. Own each cloned subtree here
    // so its lifetime follows this runtime editor, including pending previews.
    for I := 0 to Template.ChildrenCount - 1 do
    begin
      Child := Template.Children[I].Clone(Self);
      Child.Parent := Self;
    end;
    BindControls;
  finally
    EndUpdate;
  end;
end;

function TGameFieldEditor.GetText: string;
begin
  if ValueMemo.Visible then
    Result := ValueMemo.Text
  else
    Result := ValueEdit.Text;
end;

procedure TGameFieldEditor.SetText(const Value: string);
begin
  if ValueMemo.Visible then
    ValueMemo.Text := Value
  else
    ValueEdit.Text := Value;
end;

procedure TGameFieldEditor.BindControls;
begin
  HeaderLayout := TLayout(FindStyledPart(Self, 'fieldheader'));
  ValueColumn := TLayout(FindStyledPart(Self, 'fieldvaluecolumn'));
  InputFrame := TLayout(FindStyledPart(Self, 'fieldinputframe'));
  EditorArea := TLayout(FindStyledPart(Self, 'fieldeditorarea'));
  InputControlFrame := TLayout(FindStyledPart(Self, 'fieldinputcontrols'));
  ErrorFrame := TRectangle(FindStyledPart(Self, 'fielderrorframe'));
  CaptionLabel := TLabel(FindStyledPart(Self, 'fieldcaption'));
  ErrorLabel := TLabel(FindStyledPart(Self, 'fielderror'));
  InfoButton := TButton(FindStyledPart(Self, 'fieldinfo'));
  InfoIcon := FMX.Objects.TPath(FindStyledPart(Self, 'fieldinfoicon'));
  HelpLabel := TLabel(FindStyledPart(Self, 'fieldhelp'));
  ValueEdit := TEdit(FindStyledPart(Self, 'fieldedit'));
  ValueMemo := TMemo(FindStyledPart(Self, 'fieldmemo'));
  MediaImage := TImage(FindStyledPart(Self, 'fieldmediaimage'));
  MediaCommands := TLayout(FindStyledPart(Self, 'fieldmediacommands'));
  ReplaceMediaButton := TButton(FindStyledPart(Self, 'fieldreplace'));
  ClearMediaButton := TButton(FindStyledPart(Self, 'fieldclear'));
  MediaNote := TLabel(FindStyledPart(Self, 'fieldmedianote'));
  if (HeaderLayout = nil) or (ValueColumn = nil) or (InputFrame = nil) or
    (EditorArea = nil) or (InputControlFrame = nil) or (ErrorFrame = nil) or
    (CaptionLabel = nil) or (ErrorLabel = nil) or
    (InfoButton = nil) or (InfoIcon = nil) or (HelpLabel = nil) or
    (ValueEdit = nil) or (ValueMemo = nil) or (MediaImage = nil) or
    (MediaCommands = nil) or (ReplaceMediaButton = nil) or
    (ClearMediaButton = nil) or (MediaNote = nil) then
    raise Exception.Create('The game field FMX template is incomplete');
  // Public-only memo properties are not preserved by FMX template cloning.
  ValueMemo.ScrollAnimation := TBehaviorBoolean.True;
end;

end.

