$scriptDir = Split-Path $script:MyInvocation.MyCommand.Path
import-module $scriptDir\..\src\RegUtil.psm1

Get-RegKeysFromRegFileText (Get-Content "$scriptDir\Test3.reg.txt" | Out-String)