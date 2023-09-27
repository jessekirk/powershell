$localMachineRemoteDesktopCert = Get-ChildItem 'CERT:\LOCALMACHINE\REMOTE DESKTOP'
$localMachineMyCert = Get-ChildItem 'CERT:\LOCALMACHINE\MY' | Where-Object { $_.ISSUER -like '*<DOMAIN>s*' } | Sort-Object -Property NOTAFTER -Descending | Select-Object -First 1
$regSelfSignedCert = Get-ItemPropertyValue -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations' -Name SelfSignedCertificate

$dataConversion = ($regSelfSignedCert | ForEach-Object { '{0:X2}' -F $_ }) -JOIN ''

if (($localMachineRemoteDesktopCert.Thumbprint -eq $localMachineMyCert.Thumbprint) -and ($localMachineMyCert.Thumbprint -eq $dataConversion) -and ($localMachineRemoteDesktopCert.count -eq 1))
{
    Write-Verbose -Message 'Compliant' -Verbose
    return
}
else
{
    $localMachineRemoteDesktopCert | Remove-Item -Force -Verbose
    $newRegCert = ($localMachineMyCert.Thumbprint -replace '(..)', '0X$1 ').TrimEnd().Split() | ForEach-Object { [Convert]::ToInt64($_, 16) }
    Set-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations' -Name SelfSignedCertificate -Value $newRegCert -Type Binary -Force -Verbose

    $remoteDesktopCert = Get-Item -Path 'CERT:\LOCALMACHINE\REMOTE DESKTOP'
    $remoteDesktopCert.OPEN('READWRITE')
    $remoteDesktopCert.ADD($localMachineMyCert)
    $remoteDesktopCert.CLOSE()
    Write-Output 'REMEDIATION ACTION COMPLETED'
}