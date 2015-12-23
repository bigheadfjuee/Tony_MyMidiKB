unit Unit1;

interface

uses
  System.SysUtils, System.Types, System.UITypes, System.Classes,
  System.Variants,
  FMX.Types, FMX.Controls, FMX.Forms, FMX.Graphics, FMX.Dialogs, FMX.ScrollBox,
  FMX.Memo, FMX.Controls.Presentation, FMX.StdCtrls, FMX.ListBox, FMX.Edit;

type
  TForm1 = class(TForm)
    cbKey: TComboBox;
    cbSharpNote: TCheckBox;
    Memo1: TMemo;
    edtKey: TEdit;
    cbOctave: TComboBox;
    cbInstrument: TComboBox;
    btnPlay: TButton;
    procedure FormCreate(Sender: TObject);
    procedure cbInstrumentChange(Sender: TObject);
    procedure btnPlayKeyDown(Sender: TObject; var Key: Word; var KeyChar: Char;
      Shift: TShiftState);
    procedure btnPlayKeyUp(Sender: TObject; var Key: Word; var KeyChar: Char;
      Shift: TShiftState);
    procedure cbOctaveChange(Sender: TObject);
    procedure FormShow(Sender: TObject);
    procedure cbKeyChange(Sender: TObject);
    procedure cbSharpNoteChange(Sender: TObject);
  private
    { Private declarations }
    octaveLevel: byte;
    majorKey: byte;
  public
    { Public declarations }
    function countKey: byte;
    procedure PlayNote(var Key: Word; var KeyChar: Char; isDown: Boolean);
  end;

var
  Form1: TForm1;

function changeOffset(offset: byte): byte;

implementation

{$R *.fmx}

uses mmSystem;

var
  mo: HMIDIOUT;
  oldKey: Char;
  instrument: byte;
  isPlaying: array [0 .. 7] of Boolean;
  isPlayMyKB: array [0 .. 36] of Boolean;

const
  MIDI_NOTE_ON = $90; // 90
  MIDI_NOTE_OFF = $80;
  MIDI_DEVICE = 0;
  NOTE_C0 = 12;
  NOTE_C3 = 48;


  // Note = 0-127 - see AboutMIDI.txt
  // Instrument = 0-127 - see AboutMIDI.txt
  // Intensity  = 0-127 力度 = 音量大小

procedure SetPlaybackVolume(PlaybackVolume: cardinal);
begin
  midiOutSetVolume(mo, PlaybackVolume);
end;

procedure MIDIInit;
begin
  midiOutOpen(@mo, MIDI_DEVICE, 0, 0, CALLBACK_NULL);
  SetPlaybackVolume($FFFFFFFF);
  instrument := 26; // piano:0, steel guitar:26
  midiOutShortMsg(mo, StrToInt('$0000' + IntToHex(instrument, 2) + 'C0'));
end;

function MIDIEncodeMessage(Msg, Note, Intensity: integer): integer;
begin
  result := Msg + (Note shl 8) + (Intensity shl 16);
end;

procedure NoteOn(Note, Intensity: byte); // 音符, 力度
begin
  midiOutShortMsg(mo, MIDIEncodeMessage(MIDI_NOTE_ON, Note, Intensity));
end;

procedure NoteOff(Note, Intensity: byte);
begin
  midiOutShortMsg(mo, MIDIEncodeMessage(MIDI_NOTE_OFF, Note, Intensity));
end;

function changeOffset(offset: byte): byte; // 自然音階 3,4 只差半音
begin
  if (offset <= 2) then
    result := offset * 2
  else if (offset = 3) then
    result := 5 // Mi
  else if (offset = 7) then
    result := 12 // Ti
  else
    result := offset * 2 - 1;
end;

function MapMyKB(var KeyChar: Char): Integer;
begin
  case KeyChar of
    'q':
      result := 0;   // do
    'w':
      result := 2;  // re
    'e':
      result := 4;   // mi
    'r':
      result := 5;   // fa
    't':
      result := 7;  // so
    'y':
      result := 9;  // la
    'u':
      result := 11;  // ti
    'i', 'a':
      result := 12;  // do
    's':
      result := 12 + 2;
    'd':
      result := 12 + 4;
    'f':
      result := 12 + 5;
    'g':
      result := 12 + 7;
    'h':
      result := 12 + 9;
    'j':
      result := 12 + 11;
    'k', 'z':
      result := 12 + 12;
    'x':
      result := 12 * 2 + 2;
    'c':
      result := 12 * 2 + 4;
    'v':
      result := 12 * 2 + 5;
    'b':
      result := 12 * 2 + 7;
    'n':
      result := 12 * 2 + 9;
    'm':
      result := 12 * 2 + 11;
    ',':
      result := 12 * 2 + 12;
  else
    result := -1;
  end;
end;

procedure TForm1.PlayNote(var Key: Word; var KeyChar: Char; isDown: Boolean);
var
  offset, value: byte;
  index, oct: integer;
begin

  if (KeyChar >= '1') and (KeyChar <= '8') then
  begin
    index := byte(KeyChar) - 49; // '1' = 49

    offset := changeOffset(byte(KeyChar) - 49);
    value := NOTE_C0 + octaveLevel * 12 + offset + majorKey;

    if isDown then
    begin
      if not isPlaying[index] then
      begin
        NoteOn(value, 127); // C4 :48
        isPlaying[index] := True;
      end;
    end
    else
    begin
      NoteOn(value, 0); // C4 :48
      isPlaying[index] := False;
    end;

  end;

  if isDown then
  begin
    if (Key = vkUP) or (KeyChar = '+') then
    begin
      oct := cbOctave.ItemIndex;
      if oct < cbOctave.Items.Count - 1 then
        cbOctave.ItemIndex := oct + 1;
    end;

    if (Key = vkDown) or (KeyChar = '-') then
    begin
      oct := cbOctave.ItemIndex;
      if oct > 1 then
        cbOctave.ItemIndex := oct - 1;
    end;
  end;

  if (KeyChar >= 'a') and (KeyChar <= 'z') or (KeyChar = ',') then
  begin
    index := MapMyKB(KeyChar);
    if index = -1 then
      exit;

    value := NOTE_C3 + byte(index) + majorKey;

    if isDown then
    begin
      if not isPlayMyKB[index] then
      begin
        NoteOn(value, 127);
        isPlayMyKB[index] := True;
      end;
    end
    else
    begin
      NoteOn(value, 0);
      isPlayMyKB[index] := False;
    end;
  end;

end;

procedure TForm1.btnPlayKeyDown(Sender: TObject; var Key: Word;
  var KeyChar: Char; Shift: TShiftState);
begin
  PlayNote(Key, KeyChar, True);
  edtKey.Text := KeyChar;
end;

procedure TForm1.btnPlayKeyUp(Sender: TObject; var Key: Word; var KeyChar: Char;
  Shift: TShiftState);
begin
  PlayNote(Key, KeyChar, False);
end;

procedure TForm1.cbInstrumentChange(Sender: TObject);
begin
  instrument := cbInstrument.ItemIndex;
  midiOutShortMsg(mo, StrToInt('$0000' + IntToHex(instrument, 2) + 'C0'));
  self.SetFocused(btnPlay);
end;

function TForm1.countKey: byte;
begin
  if cbSharpNote.IsChecked then
    result := changeOffset(byte(cbKey.ItemIndex)) + 1
  else
    result := changeOffset(byte(cbKey.ItemIndex));
end;

procedure TForm1.cbKeyChange(Sender: TObject);
begin
  majorKey := countKey();
  self.SetFocused(btnPlay);
end;

procedure TForm1.cbOctaveChange(Sender: TObject);
begin
  octaveLevel := byte(cbOctave.ItemIndex);
  self.SetFocused(btnPlay);
end;

procedure TForm1.cbSharpNoteChange(Sender: TObject);
begin
  majorKey := countKey();
  self.SetFocused(btnPlay);
end;

procedure TForm1.FormCreate(Sender: TObject);
var
  I: integer;
begin
  MIDIInit;

  for I := 0 to 7 do
    isPlaying[I] := False;
end;

procedure TForm1.FormShow(Sender: TObject);
begin
  self.SetFocused(btnPlay);
  octaveLevel := 4;
  cbOctave.ItemIndex := octaveLevel;

  instrument := 25; // steel guitar
  cbInstrument.ItemIndex := instrument;
  midiOutShortMsg(mo, StrToInt('$0000' + IntToHex(instrument, 2) + 'C0'));

  majorKey := 0;

  self.SetFocused(btnPlay);
end;

end.
