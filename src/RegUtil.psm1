$scriptDir = Split-Path $script:MyInvocation.MyCommand.Path

function OptParam($val, $defaultVal) {
    if ($val -eq $null) {
        $defaultVal
    } else {
        $val
    }
}

function EchoVars($vars) {
    foreach ($var in $vars) {
        Write-Host "$var=$(Get-Variable $var -ValueOnly)"
    }
}

function FindRegex($string, $regex, $captureGroup) {
    $found = $string -match $regex
    if ($found) {
        return $matches[$captureGroup]
    } else {
        return $null
    }
}

$RegUtilWorkingDir = OptParam $env:REGUTIL_WORKING_DIR $scriptDir
$RegUtilCorrelationId = OptParam $env:REGUTIL_CORRELATION_ID (get-date -format MM-dd-yyyy-HH.mm.ss.ffff)
$RegUtilTempDir = (Join-Path $RegUtilWorkingDir $RegUtilCorrelationId)
$RegUtilJobName = OptParam $env:REGUTIL_JOB_NAME "Install"

EchoVars "RegUtilWorkingDir", "RegUtilCorrelationId", "RegUtilTempDir"

#########################################################
# Auto-Backup and install a reg file
#########################################################

function New-TempDir {
    if (-not(Test-Path $RegUtilTempDir)) {
        Write-Host "Creating new temp dir $RegUtilTempDir"
        New-Item -ItemType Directory -Path $RegUtilTempDir
    }
}

function Remove-TempDirectory {
    if (Test-Path $RegUtilTempDir) {
        Write-Host "Deleting temp dir $RegUtilTempDir"
        Remove-Item $RegUtilTempDir -Recurse -Confirm:$false | Out-Host
    }
}

function Backup-RegFile($regFile) {
    # determine output file
    $outputFile = Join-Path -Path $RegUtilWorkingDir -ChildPath "$RegUtilJobName.backup-$RegUtilCorrelationId.reg"

    Write-Host "Will export backup reg file to $outputFile"

    # read the reg file
    # find all the ksy
    # create a backup reg file text that combines the exports for each of the keys found
    $regFileText = (Get-Content $regFile | Out-String)
    $keys = Get-RegKeysFromRegFileText $regFileText
    $backupRegFileText = Get-BackupRegKeysFileText $keys

    # write the backup file
    Set-Content $outputFile $backupRegFileText
}

function Get-RegKeysFromRegFileText($text) {
    $lines = $text.Split([Environment]::NewLine)
    $keys = @()
    foreach ($line in $lines) {
        # eg, "[-HKEY_CLASSES_ROOT\.properties]"
        $key = FindRegex $line '(\[-?)(.+)(\])' 2

        # add the key if it is not null
        if (-not($key -eq $null)) {
            $keys += $key
        }
    }

    Write-Host "Found keys:"
    foreach ($key in $keys) {
        Write-Host "Key $key"
    }

    return $keys
}

# Return the given registry keys as a string
function Get-BackupRegKeysFileText($keys) {
    New-TempDir | Out-Host
    $tempFolder = $RegUtilTempDir
    Write-Host "Using temp dir: $tempFolder"
    $outputFile = "$tempFolder\combined.reg.txt"

    # export each key to a separate file
    foreach ($key in $keys) {
        $i++
        $keyFile = "$tempFolder\$i.reg"
        Write-Host "Exporting key: $key to $keyFile"
        & reg export $key $keyFile | Out-Host
        if ($LastExitCode -ne 0) {
            throw "Error accessing registry."
        }
    }

    # concatenate all files
    Write-Host "Writing combined export file to $outputFile"
    'Windows Registry Editor Version 5.00' | Set-Content $outputFile

    foreach ($key in $keys) {
        Add-Content -Path $outputFile -Value "[-$key]"
    }

    (Get-Content "$tempFolder\*.reg") | ? {
        $_ -ne 'Windows Registry Editor Version 5.00'
    } | Add-Content $outputFile

    $text = (Get-Content $outputFile | Out-String)

    Remove-TempDirectory

    Write-Host "Backup Reg Keys:"
    Write-Host $text
    return $text
}

