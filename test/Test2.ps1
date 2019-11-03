$string = "-HKEY_CLASSES_ROOT\.properties] asdfsa" ;
$found = $string -match '(\[-?)(.+)(\])'
if ($found) {
    write-host $matches[2]
} else {
    Write-Host "not found"
}
