param (
    $propsFile,
    $jobName
)

function OptVal($val, $defaultVal) {
    if ( [string]::IsNullOrEmpty($val)) {
        return $defaultVal
    } else {
        return $val
    }
}

function ReqVal($val) {
    if ( [string]::IsNullOrEmpty($val)) {
        throw "required param missing!"
    } else {
        return $val
    }
}

function EchoVars($vars) {
    foreach ($var in $vars) {
        Write-Host "$var=$( Get-Variable $var -ValueOnly )"
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

function Get-Props($file) {
    $props = ConvertFrom-StringData (Get-Content $file -ErrorAction Stop | Out-String)
    write-host ($props | out-string)
    return $props
}

function force-resolve-path($filename) {
    $filename = Resolve-Path -Path $filename -ErrorAction SilentlyContinue -ErrorVariable _frperror
    if (!$filename) {
        return $_frperror[0].TargetObject
    }
    return $filename
}

function Get-TargetRegFiles($strFileList) {
    # files, separated by semicolon
    # eg, qwer/qwer.reg;./asdf.reg
    # files should be resolve relative to the working dir
    Write-Host "Splitting file list $strFileList"
    $files = [regex]::Split($strFileList, ";")

    Write-Host "Found files:"
    Write-Host ($files | Out-String)

    $actualFiles = @()
    foreach ($file in $files) {
        Write-Host "Resolving file: $file"
        $actualFile = force-resolve-path $file
        $actualFiles += $actualFile
    }

    return $actualFiles
}

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

function Backup-RegFiles($regFiles) {
    # determine output file
    $outputFile = Join-Path -Path $RegUtilWorkingDir -ChildPath "$RegUtilJobName.backup-$RegUtilCorrelationId.reg"

    Write-Host "Will export backup reg file to $outputFile"

    # read the reg file
    # find all the ksy
    # create a backup reg file text that combines the exports for each of the keys found
    $allKeys = @()

    foreach ($regFile in $regFiles) {
        $regFileText = (Get-Content $regFile | Out-String)
        $keys = Get-RegKeysFromRegFileText $regFileText
        $allKeys += $keys
    }

    $backupRegFileText = New-BackupRegKeysFile $keys
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
function New-BackupRegKeysFile($keys) {
    New-TempDir | Out-Host
    $tempFolder = $RegUtilTempDir
    Write-Host "Using temp dir: $tempFolder"
    $outputFile = "$tempFolder\$RegUtilJobName.backup.combined.reg"

    # export each key to a separate file
    foreach ($key in $keys) {
        $i++
        $keyFile = "$tempFolder\$RegUtilJobName.backup.key.$i.reg"
        Write-Host "Exporting key: $key to $keyFile"
        & reg export $key $keyFile | Out-Host
        if ($LastExitCode -ne 0) {
            throw "Error accessing registry."
        }
    }

    # concatenate all files
    Write-Host "Writing combined export file to $outputFile"
    Set-Content -Path $outputFile -Value 'Windows Registry Editor Version 5.00'

    foreach ($key in $keys) {
        Add-Content -Path $outputFile -Value "[-$key]"
    }

    foreach ($line in (Get-Content "$tempFolder\$RegUtilJobName.backup.key.*.reg")) {
        if ($line -ne 'Windows Registry Editor Version 5.00') {
            Add-Content $outputFile -Value $line
        }
    }

    $text = (Get-Content $outputFile | Out-String)

    Write-Host "Backup Reg Keys:"
    Write-Host $text
    return $outputFile
}

function Combine-RegFiles($regFiles) {
    $outputFile = Join-Path -Path $RegUtilTempDir -ChildPath "$RegUtilJobName.install.reg"
    Set-Content -Path $outputFile -Value 'Windows Registry Editor Version 5.00'
    foreach ($line in (Get-Content $regFiles)) {
        if ($line -ne 'Windows Registry Editor Version 5.00') {
            Add-Content $outputFile -Value $line
        }
    }
    return $outputFile
}

function Install-RegFiles($regFiles) {
    New-TempDir
    $regFile = Combine-RegFiles $regFiles
    Write-Host "Combinined reg files into output file $regFile"
    Write-Host "Installing $regFile"
    Start-Process regedit -ArgumentList @("`"$regFile`"") -Wait -verb runas
}

$scriptDir = Split-Path $script:MyInvocation.MyCommand.Path
$IsDebug = OptVal $env:DEBUG $false
$props = (Get-Props $propsFile)

$RegUtilWorkingDir = OptVal $env:REGUTIL_WORKING_DIR $scriptDir
$RegUtilCorrelationId = OptVal $env:REGUTIL_CORRELATION_ID (get-date -format MM-dd-yyyy-HH.mm.ss.ffff)
$RegUtilJobName = $jobName
$RegUtilTempDir = (Join-Path $RegUtilWorkingDir "$RegUtilJobName-$RegUtilCorrelationId")
$listTargetRegFiles = Get-TargetRegFiles (OptVal $props."reg.input.files" "$RegUtilJobName.reg")
$blnBackupEnabled = [boolean](OptVal $props."reg.output.backup.enabled" "true")

EchoVars @(
"RegUtilWorkingDir",
"RegUtilCorrelationId",
"RegUtilJobName",
"RegUtilTempDir",
"listTargetRegFiles",
"blnBackupEnabled"
)

# optionally backup reg files
if ($blnBackupEnabled) {
    Backup-RegFiles $listTargetRegFiles
}

# install the reg files
Install-RegFiles $listTargetRegFiles