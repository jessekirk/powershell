$script:json = Get-Content './a3.json' | ConvertFrom-Json
Add-Type -Path $json.ionicZipDllPath

function a3DateTimeUtcNow
{
    return (Get-Date).ToUniversalTime().ToString('yyyyMMddTHHmmZ')
}

function a3ConvertString256Hash
{
    [cmdletbinding()]
    param([string]$p)

    $sb = New-Object System.Text.StringBuilder
    [System.Security.Cryptography.HashAlgorithm]::Create('SHA256').ComputeHash([System.Text.Encoding]::UTF8.GetBytes($p)) | ForEach-Object {
        [void]$sb.Append($_.ToString('x2'))
    }

    return $sb.ToString().Substring(0, 5)
}

function a3GitPath
{
    if ((Get-CimInstance -ClassName Win32_LogicalDisk).DeviceID -match 'd:') { return [pscustomobject]@{gitlab = 'd:\gitlab'; temp = 'd:\a3Temp' } }
    throw 'd:\ partition does not exist. create the partition and try again.'
}

function a3CreateNewPkg
{
    [cmdletbinding()]
    param
    (
        [parameter(Mandatory)]
        [ValidateScript( { Test-Path -Path $_ })]
        [string]$path
    )


}