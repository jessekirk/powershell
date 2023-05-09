param([string]$path = 'd:\gitlab')

foreach ($p in (Get-ChildItem -Path $path -Force -Recurse -Filter '.git' -Exclude 'sams-esa' -ErrorAction Stop))
{
    foreach ($repo in $p.fullname | Split-Path -Parent)
    {
        & git -C $repo pull --verbose
    }
}

#esa automation repository | 6.0 branch
& git -C "$path\sams-esa\automation_windows10" pull --verbose