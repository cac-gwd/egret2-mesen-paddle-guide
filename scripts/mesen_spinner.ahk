#Requires AutoHotkey v2.0
#SingleInstance Force

; EGRET II mini paddle sends high-frequency mouse-wheel input.
; Keep AutoHotkey's safety limit but raise the threshold.
A_MaxHotkeysPerInterval := 500

; Paddle wheel -> horizontal mouse movement.
WheelUp::MouseMove(-10, 0, 0, "R")
WheelDown::MouseMove(10, 0, 0, "R")

; Ctrl+Alt+Q stops the script.
^!q::ExitApp()
