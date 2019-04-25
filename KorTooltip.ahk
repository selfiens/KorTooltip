#NoEnv  ; Recommended for performance and compatibility with future AutoHotkey releases

; Official repo:
; https://github.com/selfiens/KorTooltip

; References:
; IME state reader: https://iamaman.tistory.com/1805
; Persistent tooltip https://stackoverflow.com/questions/41598616/toggling-a-persistent-tooltip

; commands https://www.autohotkey.com/docs/commands/
; hotkeys https://www.autohotkey.com/docs/Hotkeys.

; # win
; ! alt
; ^ ctrl
; + shift

; ----------------------------------------------------------------
; Initializer >>>

isActive := True
lastX := 0
lastY := 0
lastImeState := 99

idlePollingCurrentSkip := 0
toolTipFlashIdx := 0

; preferences
IniRead, colorScheme, KorTooltip.ini, preferences, colorScheme, whiteOnBlack
IniRead, isEngTooltipDisplayed, KorTooltip.ini, preferences, isEngTooltipDisplayed, 0

; labels
IniRead, korTooltipLabel, KorTooltip.ini, labels, korTooltipLabel, KOR
IniRead, engUcaseTooltipLabel, KorTooltip.ini, labels, engUcaseTooltipLabel, ENG

; core
IniRead, idlePollingSkipMax, KorTooltip.ini, internal, idlePollingSkipMax, 15 ; 250ms/16ms = 15
IniRead, toolTipFlashIntervalMs, KorTooltip.ini, internal, toolTipFlashIntervalMs, 500
IniRead, toolTipOffsetX, KorTooltip.ini, internal, toolTipOffsetX, 20
IniRead, toolTipOffsetY, KorTooltip.ini, internal, toolTipOffsetY, -30


if(colorScheme = "whiteOnBlack"){
    TooltipColorWhiteOnBlack()
}
else if(colorScheme = "blackOnWhite"){
    TooltipColorBlackOnWhite()
}
else if(colorScheme = "whiteOnRed"){
    TooltipColorWhiteOnRed()
}
else if(colorScheme = "flash"){
    StartToolTipFlash()
}
else { ; default
    TooltipColorWhiteOnBlack()
}

InitTrayMenu()
StartWatch()
return
; <<< Initializer
; ----------------------------------------------------------------


; ----------------------------------------------------------------
; toggle tooltip state
#ScrollLock:: ; win + scrolllock
If (isActive = False) {
	StartWatch()
} Else {
	StopWatch()
}
Return

StartWatch(){
	global isActive
	isActive := True
	SetTimer, WatchCursor, 16 ; 1000ms/60fps =~ 16.7ms
}

StopWatch(){
	global isActive
	isActive := False
	SetTimer, WatchCursor, Off
	ToolTip ; removing tooltip
}

InitTrayMenu(){
	Menu, Tray, NoStandard ; remove default tray menu entries
	Menu, Tray, Add, White, ToolTipColorBlackOnWhite
	Menu, Tray, Add, Black, ToolTipColorWhiteOnBlack
	Menu, Tray, Add, Red, ToolTipColorWhiteOnRed
	Menu, Tray, Add, Flash, StartToolTipFlash
	Menu, Tray, Add
	Menu, Tray, Add, toggle ENG, ToogleEngTooltip
	Menu, Tray, Add
	Menu, Tray, Add, Exit, Exit
}

SaveSettings(){
    global
    
    ; preferences
    IniWrite, %isEngTooltipDisplayed%, KorTooltip.ini, preferences, isEngTooltipDisplayed
    IniWrite, %colorScheme%, KorTooltip.ini, preferences, colorScheme

    ; labels
    IniWrite, %korTooltipLabel%, KorTooltip.ini, labels, korTooltipLabel
    IniWrite, %engUcaseTooltipLabel%, KorTooltip.ini, labels, engUcaseTooltipLabel

    ; core
    IniWrite, %idlePollingSkipMax%, KorTooltip.ini, internal, idlePollingSkipMax
    IniWrite, %toolTipFlashIntervalMs%, KorTooltip.ini, internal, toolTipFlashIntervalMs
    IniWrite, %toolTipOffsetX%, KorTooltip.ini, internal, toolTipOffsetX
    IniWrite, %toolTipOffsetY%, KorTooltip.ini, internal, toolTipOffsetY
}

ToolTipColorBlackOnWhite(){
    global colorScheme
    colorScheme := "blackOnWhite"
    
	StopToolTipFlash()
	ToolTipColor("White","Black") ; background / foreground
}

ToolTipColorWhiteOnBlack(){
    global colorScheme
    colorScheme := "whiteOnBlack"

    StopToolTipFlash()
	ToolTipColor("Black","White")
}

ToolTipColorWhiteOnRed(){
    global colorScheme
    colorScheme := "whiteOnRed"

    StopToolTipFlash()
	ToolTipColor("Red","White")
}

StartToolTipFlash(){
    global colorScheme
    colorScheme := "flash"

    global toolTipFlashIntervalMs
	toolTipFlashIdx = 1
	SetTimer, FlashToolTip, %toolTipFlashIntervalMs%
}

StopToolTipFlash(){
	toolTipFlashIdx = 0
	SetTimer, FlashToolTip, off
}

FlashToolTip(){
	global toolTipFlashIdx
	if(toolTipFlashIdx = 1){
		ToolTipColor("Red","White")
	}
	if(toolTipFlashIdx = 2){
		ToolTipColor("Black","White")
	}
	
	; capping
	toolTipFlashIdx++
	if(toolTipFlashIdx > 2){
		toolTipFlashIdx := 1
	}
}

ToogleEngTooltip(){
	global isEngTooltipDisplayed
	isEngTooltipDisplayed := !isEngTooltipDisplayed
    SaveSettings()

    ; hide tooltip here in case IME is not KOR and/or not watching
    if(!isEngTooltipDisplayed){
        ToolTip
    }
}

Exit(){
    SaveSettings()
	ExitApp
}

; ----------------------------------------------------------------
; main poller
WatchCursor:
MouseGetPos, x, y, winId, controlId

; hide tooltip when cursor is near the upper edge of the underlaying window
if(y < 50){
	ToolTip
	return
}

; slows down IME state check frequency when the cursor is idle
if (x = lastX and y = lastY and toolTipFlashIdx = 0){
    idlePollingCurrentSkip += 1
    if(idlePollingCurrentSkip < idlePollingSkipMax) {
        return
    }
    ; OutputDebug, idle %idlePollingCurrentSkip%
}



; reset idle polling skip
idlePollingCurrentSkip := 0

imeState := ReadImeState(winId)

; should show ENG label?
if(imeState = 0 and isEngTooltipDisplayed){
	lastX := x
	lastY := y
	lastImeState := imeState
	
	ToolTip, %engUcaseTooltipLabel%, x+toolTipOffsetX, y+toolTipOffsetY
	return
}

; is IME=ENG?
if(imeState = 0) {
    if(imeState != lastImeState){
	   ToolTip ; removing tooltip
    }
    lastImeState := imeState
    return
}

if(x = lastX and y = lastY and imeState = lastImeState and toolTipFlashIdx = 0){
    return
}

lastX := x
lastY := y
lastImeState := imeState

ToolTip, %korTooltipLabel%, x+20, y-30
return



; ----------------------------------------------------------------
; @returns int 0:inactive 1:active
ReadImeState(hWnd)
{
    ; WinGet,hWnd,ID,%WinTitle%
    Return Send_ImeControl(ImmGetDefaultIMEWnd(hWnd),0x005,"")
}

Send_ImeControl(DefaultIMEWnd, wParam, lParam)
{
    DetectSave := A_DetectHiddenWindows
    DetectHiddenWindows,ON
    SendMessage 0x283, wParam,lParam,,ahk_id %DefaultIMEWnd%
    if (DetectSave <> A_DetectHiddenWindows)
        DetectHiddenWindows,%DetectSave%
    return ErrorLevel
}

ImmGetDefaultIMEWnd(hWnd)
{
    return DllCall("imm32\ImmGetDefaultIMEWnd", Uint,hWnd, Uint)
}


; ------------------------------------------------------------------
; ToolTip font & color customizer
; from https://www.autohotkey.com/boards/viewtopic.php?t=4777
ToolTipFont(Options := "", Name := "", hwnd := "") {
    static hfont := 0
    if (hwnd = "")
        hfont := Options="Default" ? 0 : _TTG("Font", Options, Name), _TTHook()
    else
        DllCall("SendMessage", "ptr", hwnd, "uint", 0x30, "ptr", hfont, "ptr", 0)
}
 
ToolTipColor(Background := "", Text := "", hwnd := "") {
    static bc := "", tc := ""
    if (hwnd = "") {
        if (Background != "")
            bc := Background="Default" ? "" : _TTG("Color", Background)
        if (Text != "")
            tc := Text="Default" ? "" : _TTG("Color", Text)
        _TTHook()
    }
    else {
        VarSetCapacity(empty, 2, 0)
        DllCall("UxTheme.dll\SetWindowTheme", "ptr", hwnd, "ptr", 0
            , "ptr", (bc != "" && tc != "") ? &empty : 0)
        if (bc != "")
            DllCall("SendMessage", "ptr", hwnd, "uint", 1043, "ptr", bc, "ptr", 0)
        if (tc != "")
            DllCall("SendMessage", "ptr", hwnd, "uint", 1044, "ptr", tc, "ptr", 0)
    }
}
 
_TTHook() {
    static hook := 0
    if !hook
        hook := DllCall("SetWindowsHookExW", "int", 4
            , "ptr", RegisterCallback("_TTWndProc"), "ptr", 0
            , "uint", DllCall("GetCurrentThreadId"), "ptr")
}
 
_TTWndProc(nCode, _wp, _lp) {
    Critical 999
   ;lParam  := NumGet(_lp+0*A_PtrSize)
   ;wParam  := NumGet(_lp+1*A_PtrSize)
    uMsg    := NumGet(_lp+2*A_PtrSize, "uint")
    hwnd    := NumGet(_lp+3*A_PtrSize)
    if (nCode >= 0 && (uMsg = 1081 || uMsg = 1036)) {
        _hack_ = ahk_id %hwnd%
        WinGetClass wclass, %_hack_%
        if (wclass = "tooltips_class32") {
            ToolTipColor(,, hwnd)
            ToolTipFont(,, hwnd)
        }
    }
    return DllCall("CallNextHookEx", "ptr", 0, "int", nCode, "ptr", _wp, "ptr", _lp, "ptr")
}
 
_TTG(Cmd, Arg1, Arg2 := "") {
    static htext := 0, hgui := 0
    if !htext {
        Gui _TTG: Add, Text, +hwndhtext
        Gui _TTG: +hwndhgui +0x40000000
    }
    Gui _TTG: %Cmd%, %Arg1%, %Arg2%
    if (Cmd = "Font") {
        GuiControl _TTG: Font, %htext%
        SendMessage 0x31, 0, 0,, ahk_id %htext%
        return ErrorLevel
    }
    if (Cmd = "Color") {
        hdc := DllCall("GetDC", "ptr", htext, "ptr")
        SendMessage 0x138, hdc, htext,, ahk_id %hgui%
        clr := DllCall("GetBkColor", "ptr", hdc, "uint")
        DllCall("ReleaseDC", "ptr", htext, "ptr", hdc)
        return clr
    }
}