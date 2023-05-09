function get-datetimeutcnow
{
    param
    (
        [switch]$dashes,
        [switch]$spaced
    )

    if ($dashes.IsPresent)
    {
        return (Get-Date).ToUniversalTime().ToString('yyyy-MM-dd-THHmmssfffZ')
    }
    if ($spaced.IsPresent)
    {
        return (Get-Date).ToUniversalTime().ToString('yyyy-MM-dd-T HH mm ss fff Z')
    }
    else
    {
        return (Get-Date).ToUniversalTime().ToString('yyyyMMddTHHmmssfffZ')
    }

}

Set-Alias -Name dateTimeUtcNow -Value get-datetimeutcnow -Option ReadOnly

Export-ModuleMember -Function * -Alias *