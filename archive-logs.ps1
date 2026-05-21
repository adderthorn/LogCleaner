param(
    [Parameter(Mandatory = $true)]
    [ValidateRange(1, 36500)]
    [int]$CompressOlderThanDays,

    [Parameter(Mandatory = $true)]
    [ValidateRange(1, 1200)]
    [int]$DeleteArchivesOlderThanMonths,

    [string]$ConfigPath = (Join-Path $PSScriptRoot 'archive-logs.config.json')
)

$ErrorActionPreference = 'Stop'

# Configure where 7z.exe is installed and prepend it to PATH.
$SevenZipBinDirectory = 'C:\Program Files\7-Zip'
$env:Path = "$SevenZipBinDirectory;$env:Path"

function Write-Log {
    param(
        [string]$Level,
        [string]$Message
    )

    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    Write-Host "[$timestamp] [$Level] $Message"
}

Write-Log -Level 'INFO' -Message "Starting log archive run. CompressOlderThanDays=$CompressOlderThanDays, DeleteArchivesOlderThanMonths=$DeleteArchivesOlderThanMonths"

if (-not (Test-Path -Path $ConfigPath -PathType Leaf)) {
    throw "Config file not found: $ConfigPath"
}

$config = Get-Content -Path $ConfigPath -Raw | ConvertFrom-Json
if (-not $config.LogDirectories -or $config.LogDirectories.Count -eq 0) {
    throw "Config file '$ConfigPath' must contain a 'LogDirectories' array."
}

$sevenZip = Get-Command -Name '7z.exe' -ErrorAction SilentlyContinue
if (-not $sevenZip) {
    throw "7z.exe was not found in PATH. Update `$SevenZipBinDirectory at the top of this script."
}

$compressCutoff = (Get-Date).AddDays(-$CompressOlderThanDays)
$archiveDeleteCutoff = (Get-Date).AddMonths(-$DeleteArchivesOlderThanMonths)
$archiveDate = Get-Date -Format 'yyyy-MM-dd'

$totalCompressedFiles = 0
$totalDeletedArchives = 0

foreach ($directory in $config.LogDirectories) {
    if (-not (Test-Path -Path $directory -PathType Container)) {
        Write-Log -Level 'WARN' -Message "Skipping missing directory: $directory"
        continue
    }

    Write-Log -Level 'INFO' -Message "Scanning directory: $directory"

    $candidateFiles = Get-ChildItem -Path $directory -Recurse -File -Include '*.log', '*.txt' |
        Where-Object { $_.LastWriteTime -lt $compressCutoff }

    if (-not $candidateFiles) {
        Write-Log -Level 'INFO' -Message "No files eligible for compression in $directory"
    } else {
        $groupedByFolder = $candidateFiles | Group-Object -Property DirectoryName

        foreach ($folder in $groupedByFolder) {
            $archivePath = Join-Path $folder.Name "$archiveDate.7z"
            $filePaths = $folder.Group | Select-Object -ExpandProperty FullName

            Write-Log -Level 'INFO' -Message "Compressing $($folder.Count) file(s) into $archivePath"

            $arguments = @(
                'a',
                '-tzip',
                '-mtp=0',
                '-mm=Deflate',
                '-mmt=on',
                '-mx9',
                '-mfb=128',
                '-mpass=10',
                '-sccUTF-8',
                '-mcu=on',
                '-mem=AES256',
                '-bb0',
                '-bse0',
                '-bsp2',
                $archivePath
            ) + $filePaths

            $compression = Start-Process -FilePath $sevenZip.Source -ArgumentList $arguments -NoNewWindow -Wait -PassThru
            if ($compression.ExitCode -eq 0) {
                $totalCompressedFiles += $folder.Count
                Write-Log -Level 'INFO' -Message "Compression completed: $archivePath"
            } else {
                Write-Log -Level 'ERROR' -Message "Compression failed for $archivePath (exit code $($compression.ExitCode))"
            }
        }
    }

    $oldArchives = Get-ChildItem -Path $directory -Recurse -File -Filter '*.7z' |
        Where-Object { $_.LastWriteTime -lt $archiveDeleteCutoff }

    foreach ($archive in $oldArchives) {
        Remove-Item -Path $archive.FullName -Force
        $totalDeletedArchives++
        Write-Log -Level 'INFO' -Message "Deleted old archive: $($archive.FullName)"
    }
}

Write-Log -Level 'INFO' -Message "Archive run finished. Files compressed: $totalCompressedFiles. Old archives deleted: $totalDeletedArchives."
