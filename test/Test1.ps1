$scriptDir = Split-Path $script:MyInvocation.MyCommand.Path
import-module $scriptDir\..\src\RegUtil.psm1

Get-BackupRegKeysFileText HKEY_CLASSES_ROOT\.properties,HKEY_CLASSES_ROOT\.txt