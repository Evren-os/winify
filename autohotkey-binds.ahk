#Requires AutoHotkey v2.0

; Alt+B launches Brave
!b:: {
    Run("brave.exe")
}

; Alt+Z launches Zen
!z:: {
    Run("zen.exe")
}

; Alt+T launches Alacritty with the correct config and working directory
!t:: {
    Run('alacritty.exe')
}

; Alt+Q closes the currently focused window
!q:: {
    WinClose("A")  ; "A" refers to the active window
}
