$scriptDir = Split-Path $script:MyInvocation.MyCommand.Path
import-module $scriptDir\..\src\RegUtil.psm1

Backup-RegFile "$scriptDir\Test3.reg.txt"