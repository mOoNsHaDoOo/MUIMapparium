unit PrefsWinUnit;
{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, exec, utility, intuition, agraphics, mui, muihelper,
  prefsunit, osmhelper, MUIWrap, imagesunit;

type
  TProcedure = procedure;

var
  PrefsWin: PObject_ = nil;
  CountButton, ClearButton, FilesLabel, ToLevel,
  SaveButton, CancelButton, MarkerType, MarkerSize,
  DblMode, SetStart, UseData,
  UseGPS, GPSDevice, GPSUnit, GPSBaud,
  LangSel, TilesHD: PObject_;
  Bytes, Counter: Int64;
  StartPos: TCoord;
  StartZoom: Integer;

  OnUpdatePrefs: TProcedure;

procedure OpenPrefsWindow;

implementation

uses
  MUIMappariumLocale, positionunit;

var
  CountHook, ClearHook, SaveHook, SetStartHook: THook;

procedure OpenPrefsWindow;
begin
  //Marker
  MH_Set(MarkerType, MUIA_Cycle_Active, Prefs.MiddleMarker);
  MH_Set(MarkerSize, MUIA_String_Integer, Prefs.MarkerSize);
  MH_Set(LangSel, MUIA_String_Contents, AsTag(PChar(Prefs.SearchLang)));
  MH_Set(TilesHD, MUIA_String_Integer, Prefs.MaxTiles);
  MH_Set(DblMode, MUIA_Cycle_Active, Ord(Prefs.DClickMode));
  MH_Set(UseData, MUIA_Selected, AsTag(Prefs.UseDataTypes));
  StartPos.Lat := Prefs.StartPosLat;
  StartPos.Lon := Prefs.StartPosLon;
  StartZoom := Prefs.StartZoom;
  //GPS
  MH_Set(UseGPS, MUIA_Selected, AsTag(Prefs.UseGPS));
  MH_Set(GPSDevice, MUIA_String_Contents, AsTag(PChar(Prefs.GPSDevice)));
  MH_Set(GPSUnit, MUIA_String_Integer, Prefs.GPSUnit);
  MH_Set(GPSBaud, MUIA_String_Integer, Prefs.GPSBaud);

  //
  MH_Set(PrefsWin, MUIA_Window_Open, AsTag(True));
end;

function SaveEvent(Hook: PHook; Obj: PObject_; Msg: Pointer): NativeInt;
begin
  Result := 0;
  // Save Prefs
  Prefs.MiddleMarker := MH_Get(MarkerType, MUIA_Cycle_Active);
  Prefs.MarkerSize := MH_Get(MarkerSize, MUIA_String_Integer);
  Prefs.SearchLang := PChar(MH_Get(LangSel, MUIA_String_Contents));
  Prefs.MaxTiles := MH_Get(TilesHD, MUIA_String_Integer);
  Prefs.DClickMode := TDClickMode(MH_Get(DblMode, MUIA_Cycle_Active));
  Prefs.UseDataTypes := Boolean(MH_Get(UseData, MUIA_Selected));
  Prefs.StartPosLat := StartPos.Lat;
  Prefs.StartPosLon := StartPos.Lon;
  Prefs.StartZoom := StartZoom;
  // GPS
  Prefs.UseGPS := Boolean(MH_Get(UseGPS, MUIA_Selected));
  Prefs.GPSDevice := PChar(MH_Get(GPSDevice, MUIA_String_Contents));
  Prefs.GPSUnit := MH_Get(GPSUnit, MUIA_String_Integer);
  Prefs.GPSBaud := MH_Get(GPSBaud, MUIA_String_Integer);
  //
  if Assigned(OnUpdatePrefs) then
    OnUpdatePrefs();
  //
  MH_Set(PrefsWin, MUIA_Window_Open, AsTag(False));
end;

function ScaleBytes(a: Int64): string;
begin
  Result := IntToStr(a) + ' bytes';
  if a > 1024 then
  begin
    if a > 1024 * 1024 then
    begin
      Result := FloatToStrF(a/1024/1024, ffFixed, 8,1) + ' MiB';
    end else
    begin
      Result := FloatToStrF(a/1024, ffFixed, 8,1) + ' KiB';
    end;
  end;
end;

function CountButtonEvent(Hook: PHook; Obj: PObject_; Msg: Pointer): NativeInt;
var
  Info: TRawByteSearchRec;
  StartTime: Int64;
begin
  Result := 0;
  Bytes := 0;
  Counter := 0;
  StartTime := GetTickCount64;
  if FindFirst(IncludeTrailingPathDelimiter(DataDir) + BASEFILE + '*.png', faAnyFile, Info) = 0 then
  begin
    repeat
      Inc(Counter);
      Inc(Bytes, Info.Size);
      if GetTickCount64 - StartTime > 200 then
      begin
        MH_Set(FilesLabel, MUIA_Text_Contents, AsTag(PChar(Format(GetLocString(MSG_PREFS_CACHEDDATA), [ScaleBytes(Bytes), Counter]))));
        StartTime := GetTickCount64;
      end;
    until FindNext(Info) <> 0;
  end;
  FindClose(Info);
  MH_Set(FilesLabel, MUIA_Text_Contents, AsTag(PChar(Format(GetLocString(MSG_PREFS_CACHEDDATA), [ScaleBytes(Bytes), Counter]))));
end;

function ClearButtonEvent(Hook: PHook; Obj: PObject_; Msg: Pointer): NativeInt;
var
  Info: TRawByteSearchRec;
  StartTime: Int64;
  Limit: Integer;
  FileName: RawByteString;
  P1: SizeInt;
  ZoomLevel: LongInt;
  DeletedFiles, IgnoredFiles: QWord;
begin
  Result := 0;
  StartTime := GetTickCount64;
  DeletedFiles := 0;
  IgnoredFiles := 0;
  Limit := MH_Get(ToLevel, MUIA_String_Integer);
  //
  if FindFirst(IncludeTrailingPathDelimiter(DataDir) + BASEFILE + '*.png', faAnyFile, Info) = 0 then
  begin
    repeat
      FileName := Info.Name;
      Delete(FileName, 1, 4); // remove 'osm_'
      P1 := Pos('_', FileName);
      ZoomLevel := StrToIntDef(Copy(Filename, 1, P1 - 1), -1);
      if ZoomLevel >= Limit then
      begin
        DeleteFile(IncludeTrailingPathDelimiter(DataDir) + Info.Name);
        Inc(DeletedFiles);
      end else
      begin
        Inc(IgnoredFiles);
      end;
      if GetTickCount64 - StartTime > 200 then
      begin
        MH_Set(FilesLabel, MUIA_Text_Contents, AsTag(PChar(Format(GetLocString(MSG_PREFS_DELETEDATA), [DeletedFiles, IgnoredFiles]))));
        StartTime := GetTickCount64;
      end;
    until FindNext(Info) <> 0;
  end;
  FindClose(Info);
  CountButtonEvent(Hook, nil, nil);
end;

function SetStartEvent(Hook: PHook; Obj: PObject_; Msg: Pointer): NativeInt;
begin
  Result := 0;
  StartPos := MiddlePos;
  StartZoom := CurZoom;
end;


var
  MarkerStrings: array[0..3] of string;
  MarkerTypes: array[0..4] of PChar =
    ('None'#0, 'Point'#0, 'Cross'#0, 'Lines'#0, nil);
  DblModeString: array[0..2] of string;
  DblModes: array[0..3] of PChar =
    ('Center'#0, 'Properties'#0, 'Toggle Visibility'#0, nil);

procedure CreatePrefsWin;
var
  Str: string;
  SL:TStringList;
  i: Integer;
begin
  str := GetLocString(MSG_PREFS_MARKERTYPES);
  SL := TStringList.Create;
  try
    ExtractStrings(['|'], [], PChar(Str), SL);
    for i := 0 to 3 do
    begin
      MarkerStrings[i] := SL[i];
      MarkerTypes[i] := PChar(MarkerStrings[i]);
    end;
  finally
    SL.Free;
  end;
  str := GetLocString(MSG_PREFS_DBLMODES);
  SL := TStringList.Create;
  try
    ExtractStrings(['|'], [], PChar(Str), SL);
    for i := 0 to 2 do
    begin
      DblModeString[i] := SL[i];
      DblModes[i] := PChar(DblModeString[i]);
    end;
  finally
    SL.Free;
  end;
  PrefsWin := MH_Window([
    MUIA_Window_Title,     AsTag(GetLocString(MSG_PREFS_TITLE)),  // 'Preferences'
    //MUIA_Window_ID,        AsTag(MAKE_ID('M','P','R','E')),
    MUIA_HelpNode,         AsTag('PrefsWin'),
    WindowContents, AsTag(MH_VGroup([
      Child, AsTag(MH_HGroup([
        MUIA_Frame, MUIV_Frame_Group,
        MUIA_FrameTitle, AsTag(GetLocString(MSG_PREFS_MIDDLETITLE)), // 'Middle position marker'
        Child, AsTag(MH_Text(GetLocString(MSG_PREFS_MIDDLETYPE))),   // 'Type/Size'
        Child, AsTag(MH_HSpace(0)),
        Child, AsTag(MH_Cycle(MarkerType, [
          MUIA_Cycle_Entries, AsTag(@MarkerTypes),
          TAG_DONE])),
        Child, AsTag(MH_String(MarkerSize, [
          MUIA_Frame, MUIV_Frame_String,
          MUIA_String_Format, MUIV_String_Format_Right,
          MUIA_String_Accept, AsTag('0123456789'),
          MUIA_String_Integer, 1,
          MUIA_String_MaxLen, 2,
          TAG_DONE])),
        TAG_DONE])),
      Child, AsTag(MH_HGroup([
        MUIA_Frame, MUIV_Frame_Group,
        MUIA_FrameTitle, AsTag(GetLocString(MSG_PREFS_LANGTITLE)), // 'Language'
        Child, AsTag(MH_Text(GetLocString(MSG_PREFS_DEFLANG))),    // 'Default search result language'
        Child, AsTag(MH_HSpace(0)),
        Child, AsTag(MH_String(LangSel, [
          MUIA_Frame, MUIV_Frame_String,
          MUIA_String_Contents, AsTag('en'),
          TAG_DONE])),
        TAG_DONE])),
      Child, AsTag(MH_HGroup([
        Child, AsTag(MH_HGroup([
          MUIA_Frame, MUIV_Frame_Group,
          MUIA_FrameTitle, AsTag(GetLocString(MSG_PREFS_MOUSESETTINGS)), // 'Mouse Settings'
          Child, AsTag(MH_Text(GetLocString(MSG_PREFS_DBLMODE))),    // 'Double click mode'
          Child, AsTag(MH_HSpace(0)),
          Child, AsTag(MH_Cycle(DblMode, [
            MUIA_Cycle_Entries, AsTag(@DblModes),
            TAG_DONE])),
          TAG_DONE])),
        Child, AsTag(MH_HGroup([
          MUIA_Frame, MUIV_Frame_Group,
          MUIA_FrameTitle, AsTag(GetLocString(MSG_PREFS_STARTPOSITION)), // 'Start Position'
          Child, AsTag(MH_Button(SetStart, GetLocString(MSG_PREFS_USECURRENT))),    // 'Use current'
          TAG_DONE])),
        TAG_DONE])),
      Child, AsTag(MH_HGroup([
        MUIA_Frame, MUIV_Frame_Group,
        MUIA_FrameTitle, AsTag(GetLocString(MSG_FRAME_IMAGES)), // 'Photos'
        Child, AsTag(MH_Text('Use DataTypes'{GetLocString(MSG_PREFS_DEFLANG)})),    // 'Default search result language'
        Child, AsTag(MH_CheckMark(UseData, False)),
        Child, AsTag(MH_HSpace(0)),
        TAG_DONE])),
      Child, AsTag(MH_HGroup([
        MUIA_Group_Rows, 2,
        MUIA_ShowMe, AsTag(False),
        MUIA_Frame, MUIV_Frame_Group,
        MUIA_FrameTitle, AsTag('GPS'), // 'GPS'
        Child, AsTag(MH_Text('Enabled'{GetLocString(MSG_PREFS_DEFLANG)})),    // 'Use GPS'
        Child, AsTag(MH_CheckMark(UseGPS, False)),
        Child, AsTag(MH_Text('Device'{GetLocString(MSG_PREFS_DEFLANG)})),    // 'Device'
        Child, AsTag(MH_String(GPSDevice, [
          MUIA_String_Contents, AsTag('usbmodem.device'),
          MUIA_FixWidthTxt, AsTag('devs:usbmodem.device'),
          MUIA_Frame, MUIV_Frame_String,
          TAG_DONE])),
        Child, AsTag(MH_Text('Unit'{GetLocString(MSG_PREFS_DEFLANG)})),    // 'Unit'
        Child, AsTag(MH_String(GPSUnit, [
          //MUIA_FixWidthTxt, AsTag('00000'),
          MUIA_Frame, MUIV_Frame_String,
          MUIA_String_Format, MUIV_String_Format_Right,
          MUIA_String_Accept, AsTag('0123456789'),
          MUIA_String_Integer, 0,
          TAG_DONE])),
        Child, AsTag(MH_Text('Baud rate'{GetLocString(MSG_PREFS_DEFLANG)})),    // 'Baud'
        Child, AsTag(MH_String(GPSBaud, [
          //MUIA_FixWidthTxt, AsTag('000000'),
          MUIA_Frame, MUIV_Frame_String,
          MUIA_String_Format, MUIV_String_Format_Right,
          MUIA_String_Accept, AsTag('0123456789'),
          MUIA_String_Integer, 4800,
          TAG_DONE])),
        TAG_DONE])),
      Child, AsTag(MH_HGroup([
        MUIA_Frame, MUIV_Frame_Group,
        MUIA_FrameTitle, AsTag(GetLocString(MSG_PREFS_MEMORYTITLE)), // 'Memory'
        Child, AsTag(MH_Text(GetLocString(MSG_PREFS_MAXTILES))),     // 'Max Tiles in Memory'
        Child, AsTag(MH_HSpace(0)),
        Child, AsTag(MH_String(TilesHD, [
          MUIA_Frame, MUIV_Frame_String,
          MUIA_String_Format, MUIV_String_Format_Right,
          MUIA_String_Accept, AsTag('0123456789'),
          MUIA_String_Integer, 20,
          TAG_DONE])),
        TAG_DONE])),
      Child, AsTag(MH_VGroup([
        MUIA_Frame, MUIV_Frame_Group,
        MUIA_FrameTitle, AsTag(GetLocString(MSG_PREFS_HDFILES)), // 'Files on hard disk'
        Child, AsTag(MH_HGroup([
          Child, AsTag(MH_Button(CountButton, GetLocString(MSG_PREFS_BUTTONCOUNT))), // 'Count'
          Child, AsTag(MH_Button(ClearButton, GetLocString(MSG_PREFS_BUTTONCLEAR))), // 'Clear'
          Child, AsTag(MH_Text(GetLocString(MSG_PREFS_UPTOZOOM))), // 'to Zoom'
          Child, AsTag(MH_String(ToLevel, [
            MUIA_Frame, MUIV_Frame_String,
            MUIA_String_Format, MUIV_String_Format_Right,
            MUIA_String_Accept, AsTag('0123456789'),
            MUIA_String_Integer, 7,
            TAG_DONE])),
          TAG_DONE])),
        Child, AsTag(MH_Text(FilesLabel, AsTag('                                                  '))), // 'Cached Data:'
        TAG_DONE])),
      Child, AsTag(MH_HGroup([
        MUIA_Frame, MUIV_Frame_Group,
        Child, AsTag(MH_Button(SaveButton, GetLocString(MSG_GENERAL_SAVE))),     // 'Save'
        Child, AsTag(MH_HSpace(0)),
        Child, AsTag(MH_Button(CancelButton, GetLocString(MSG_GENERAL_CANCEL))), // 'Cancel'
        TAG_DONE])),
      TAG_DONE])),
    TAG_DONE]);

  ConnectHookFunction(MUIA_Pressed, AsTag(False), CountButton, nil, @CountHook, @CountButtonEvent);
  ConnectHookFunction(MUIA_Pressed, AsTag(False), ClearButton, nil, @ClearHook, @ClearButtonEvent);

  ConnectHookFunction(MUIA_Pressed, AsTag(False), SetStart, nil, @SetStartHook, @SetStartEvent);

  ConnectHookFunction(MUIA_Pressed, AsTag(False), SaveButton, nil, @SaveHook, @SaveEvent);
  DoMethod(CancelButton, [MUIM_Notify, MUIA_Pressed, AsTag(False),
      AsTag(PrefsWin), 3, MUIM_SET, MUIA_Window_Open, AsTag(False)]);
end;

initialization
  //writeln('enter prefs');
  CreatePrefsWin;
  //writeln('leave prefs');
finalization

end.
