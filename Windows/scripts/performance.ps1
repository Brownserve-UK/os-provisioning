<#
.SYNOPSIS
    Sets performance options within Windows to try and make VM's run faster.
#>
$ErrorActionPreference = 'Stop'

REG ADD "HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects" /V VisualFXSetting /T REG_DWORD /D 2 /F
REG ADD "HKCU\Control Panel\Desktop" /V "UserPreferencesMask" /T REG_BINARY /D 9012038010000000 /F
REG ADD "HKEY_CURRENT_USER\Control Panel\Desktop\WindowMetrics" /V MinAnimate /T REG_SZ /D 0 /F
REG ADD "HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /V TaskbarAnimations /T REG_DWORD /D 0 /F
REG ADD "HKEY_CURRENT_USER\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /V DisablePreviewDesktop /T REG_DWORD /D 1 /F
REG ADD "HKEY_CURRENT_USER\SOFTWARE\Microsoft\Windows\DWM" /V EnableAeroPeek /T REG_DWORD /D 0 /F
REG ADD "HKEY_CURRENT_USER\Software\Microsoft\Windows\DWM" /V AlwaysHibernateThumbnails /T REG_DWORD /D 0 /F
REG ADD "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /V IconsOnly /T REG_DWORD /D 0 /F
REG ADD "HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /V ListviewAlphaSelect /T REG_DWORD /D 0 /F
REG ADD "HKEY_CURRENT_USER\Control Panel\Desktop"  /V DragFullWindows /T REG_SZ /D 1 /F
REG ADD "HKEY_CURRENT_USER\Control Panel\Desktop"  /V FontSmoothing /T REG_SZ /D 2 /F
REG ADD "HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"  /V ListviewShadow /T REG_DWORD /D 1 /F