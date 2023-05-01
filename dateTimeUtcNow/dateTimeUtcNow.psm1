function get-datetimeutcnow
{
    param
    (
        [switch]$dashes
    )

    if ($dashes.IsPresent)
    {
        return (Get-Date).ToUniversalTime().ToString('yyyy-MM-dd-THHmmssfffZ')
    }
    else
    {
        return (Get-Date).ToUniversalTime().ToString('yyyyMMddTHHmmssfffZ')
    }

}

Set-Alias -Name dateTimeUtcNow -Value get-datetimeutcnow -Option ReadOnly

Export-ModuleMember -Function * -Alias *