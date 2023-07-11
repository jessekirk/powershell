$automation = Get-Module -ListAvailable -Refresh automation | Select-Object -First 1
Add-Type -Path (Join-Path -Path $automation.ModuleBase -ChildPath DotNetZip.dll)
[xml]$XmlContent = Get-Content -Path (Join-Path -Path $automation.ModuleBase -ChildPath automation.xml)

$NetworkPath = $XmlContent.Configuration.NetworkPath
$ConfigPath = $XmlContent.Configuration.ConfigPath
$ParseNetworkPath = $NetworkPath.Split('\').Split('', [StringSplitOptions]::RemoveEmptyEntries)
$AutomationNetworkPath = $ParseNetworkPath[4] + '\\' + $ParseNetworkPath[5]

function Write-DateTimeStamp
{
    param($format = 'yyyyMMddTHHmm')
    return (Get-Date -Format $format)
}

function Convert-StringToHash
{
    [cmdletbinding()]
    param
    (
        [parameter(Mandatory)]
        [string]$packagename
    )

    $stringbuilder = New-Object System.Text.StringBuilder
    [System.Security.Cryptography.HashAlgorithm]::Create('SHA256').ComputeHash([System.Text.Encoding]::UTF8.GetBytes($packagename)) | ForEach-Object {
        [void]$stringbuilder.Append($_.ToString('x2'))
    }

    return $stringbuilder.ToString().Substring(0, 11) + 'j' + (Get-Date).DayOfYear
}

function Get-GitPath
{
    $driveletter = Get-CimInstance -ClassName win32_logicaldisk | Where-Object { $_.DeviceID -ne 'C:' -and $_.VolumeName -ne 'Share_Drive' } | Select-Object -ExpandProperty DeviceID

    if ($null -eq $driveletter)
    {
        throw 'unable to find a valid drive letter'
    }

    foreach ($drive in $driveletter)
    {
        if (Test-Path -Path "$drive\gitlab" -ErrorAction SilentlyContinue)
        {
            $obj = [pscustomobject]@{
                gitpath  = "$drive\gitlab"
                temppath = "$drive\.tmp"
            }
        }
    }

    if ($null -eq $obj.gitpath)
    {
        throw 'unable to find a valid path to gitlab'
    }

    return $obj
}

function New-Package
{
    [cmdletbinding(DefaultParameterSetName = 'Default', SupportsShouldProcess)]
    param
    (
        [parameter(Mandatory, ParameterSetName = 'Default')]
        [ValidateScript( { Test-Path -Path $_ })]
        [string]
        $PackagePath,

        [parameter(ParameterSetName = 'AddPackageAndScriptName')]
        [string]
        $PackageName,

        [parameter(ParameterSetName = 'AddPackageAndScriptName')]
        [string]
        $PackageScriptName,

        [switch]
        $KeepSourceFiles,

        [switch]
        $SkipGitValidationCheck,

        [switch]
        $DateTimeStamp,

        [switch]
        $AddPackageNameAndScriptName
    )

    Start-Transcript -Path "$env:TEMP\automation.v$($automation.Version.ToString())_$(Write-DateTimeStamp -format 'yyyyMMdd').LOG" -Append -Force

    if ($SkipGitValidationCheck.IsPresent.Equals($false))
    {
        $gitpath = (Get-GitPath).gitpath
        $temppath = (Get-GitPath).temppath
    }
    elseif ($SkipGitValidationCheck.IsPresent)
    {
        $temppath = "$HOME\.tmp"
    }

    if ($PackagePath -match $AutomationNetworkPath -and ($AddPackageNameAndScriptName.IsPresent -eq $false))
    {
        $ParentPath = $PackagePath | Split-Path -Parent
        $ParentPath = $ParentPath | Split-Path -Leaf
        $LeafPath = $PackagePath | Split-Path -Leaf
        $PackageName = "$ParentPath $LeafPath.exe"
        $script = "$ParentPath $LeafPath.ps1"

        $file = Get-ChildItem -Path $gitpath -Recurse -File -Filter $script
        if ($file)
        {
            $file.FullName | Copy-Item -Destination $PackagePath -Force -Verbose
            foreach ($program in $XmlContent.Configuration.Program.Name)
            {
                $PathName = $PackagePath | Split-Path -Parent | Split-Path -Leaf
                if ($PathName -eq $program)
                {
                    Copy-Item -Path "$NetworkPath\$program$ConfigPath" -Destination $PackagePath -Recurse -Force -Verbose
                }
            }
        }
        elseif ($null -eq $file)
        {
            throw "Unable to find script: $script in your git path: $gitpath."
        }
    }
    elseif ($PackagePath -match $AutomationNetworkPath -and ($AddPackageNameAndScriptName.IsPresent -eq $true))
    {
        $PackageName = Read-Host -Prompt 'Enter package name'
        $PackageScriptName = Read-Host -Prompt 'Enter package script name'
        $PackageName = "$PackageName.exe"
        $PackageScriptName = "$PackageScriptName.ps1"
        $file = $PackageScriptName
    }

    if ($PackagePath -notmatch $AutomationNetworkPath -and ($SkipGitValidationCheck.IsPresent) -and ($AddPackageNameAndScriptName.IsPresent -eq $false))
    {
        $PackageName = Read-Host -Prompt 'Enter package name'
        $PackageScriptName = Read-Host -Prompt 'Enter package script name'
        $PackageName = "$PackageName.exe"
        $PackageScriptName = "$PackageScriptName.ps1"
        $file = $PackageScriptName
    }

    if ($DateTimeStamp.IsPresent)
    {
        $PackageName = $PackageName.Replace('.exe', '_' + (Write-DateTimeStamp) + '.exe')
    }

    # Instantiate new instances of Ionic.Zip
    $ZipFile = [Ionic.Zip.ZipFile]::new()
    $SelfExtractorSaveOptions = [Ionic.Zip.SelfExtractorSaveOptions]::new()

    $ZipFile.StatusMessageTextWriter = [Console]::Out
    $ZipFile.CompressionLevel = 'BestCompression'
    $ZipFile.AddDirectory($PackagePath)
    $SelfExtractorSaveOptions.ProductName = $PackageName
    $SelfExtractorSaveOptions.ProductVersion = $automation.Version.ToString() + ' (int automation)'
    $SelfExtractorSaveOptions.Copyright = (Get-Date).Year
    $SelfExtractorSaveOptions.IconFile = Join-Path -Path $automation.ModuleBase -ChildPath 'powershell_black.ico'
    $SelfExtractorSaveOptions.DefaultExtractDirectory = "c:\sie\authorized\applications\tmp\$(Convert-StringToHash -packagename $PackageName)"
    $SelfExtractorSaveOptions.ExtractExistingFile = $ZipFile.ExtractExistingFile = 'OverwriteSilently'
    $SelfExtractorSaveOptions.PostExtractCommandLine = "powershell.exe -noprofile -windowstyle hidden -file `"c:\sie\authorized\applications\tmp\$(Convert-StringToHash -packagename $PackageName)\$file`""
    $SelfExtractorSaveOptions.RemoveUnpackedFilesAfterExecute = $true
    $SelfExtractorSaveOptions.Quiet = $true
    $ZipFile.UseZip64WhenSaving = 'AsNecessary'
    $ZipFile.SaveSelfExtractor($PackageName, $SelfExtractorSaveOptions)
    $ZipFile.Dispose()

    Write-Host -Object "parameter 'package name' $PackageName" -ForegroundColor Cyan
    Write-Host -Object "parameter 'script name' $PackageScriptName" -ForegroundColor Cyan

    Write-Host -Object "automated parameter 'defaultextractdirectory' $($SelfExtractorSaveOptions.DefaultExtractDirectory)" -ForegroundColor Cyan
    Write-Host -Object "automated parameter 'postextractcommandline' $($SelfExtractorSaveOptions.PostExtractCommandLine)" -ForegroundColor Cyan

    New-Item -Path $temppath -ItemType Directory -Verbose -ErrorAction SilentlyContinue | Out-Null

    $UserPathWithAppendedPackageName = "C:\Users\$env:USERNAME\$PackageName"
    if (Test-Path -Path $UserPathWithAppendedPackageName -ErrorAction SilentlyContinue)
    {
        Move-Item -Path $UserPathWithAppendedPackageName -Destination $temppath -Force -Verbose
    }

    if ($KeepSourceFiles.IsPresent.Equals($false))
    {
        Remove-Item -Path "$PackagePath\*" -Recurse -Force -Verbose
    }
    else
    {
        Write-Host -Object 'WARNING: source files not removed. please remove these manually.' -ForegroundColor Yellow
        ("$PackagePath\*" | Get-ChildItem -Recurse).FullName
    }

    Copy-Item -Path "$temppath\$PackageName" -Destination $PackagePath -Container -Force -Verbose
    Write-Host -Object "Zipped: $PackageName. Completed at: $(Write-Output -InputObject (Get-Date))" -ForegroundColor White
    Stop-Transcript
}

Export-ModuleMember -Function New-Package