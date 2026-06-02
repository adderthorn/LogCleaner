# LogCleaner

PowerShell-based log archiver that:

- compresses `*.log` and `*.txt` files older than `n` days
- stores archives in the same folder as their source logs
- names each archive as `yyyy-MM-dd.7z`
- deletes old `*.7z` archives older than `y` months

## Files

- `/home/runner/work/LogCleaner/LogCleaner/archive-logs.ps1` - main script
- `/home/runner/work/LogCleaner/LogCleaner/logcleaner.config.json` - directory configuration

## Configure 7-Zip path

At the top of `archive-logs.ps1`, set:

```powershell
$SevenZipBinDirectory = 'C:\Program Files\7-Zip'
$env:Path = "$SevenZipBinDirectory;$env:Path"
```

Update `SevenZipBinDirectory` to the folder that contains `7z.exe`.

## Configure log directories

Edit `logcleaner.config.json`:

```json
{
  "LogDirectories": [
    {
      "path": "C:\\Logs\\App1",
      "recursive": false
    },
    {
      "path": "D:\\Services\\Logs",
      "recursive": true
    }
  ]
}
```

`recursive` is optional and defaults to `false` when omitted.

## Usage

```powershell
.\archive-logs.ps1 -CompressOlderThanDays 14 -DeleteArchivesOlderThanMonths 6
```

Optional:

```powershell
.\archive-logs.ps1 -CompressOlderThanDays 14 -DeleteArchivesOlderThanMonths 6 -ConfigPath .\logcleaner.config.json
```

## Compression command and options

The script uses `7z.exe` with:

```text
7z.exe a -tzip -mtp=0 -mm=Deflate -mmt=on -mx9 -mfb=128 -mpass=10 -sccUTF-8 -mcu=on -mem=AES256 -bb0 -bse0 -bsp2
```

## Runtime behavior

1. Loads configured log directories.
2. Finds `*.log` and `*.txt` files older than `CompressOlderThanDays` (recursively only when `recursive` is `true` for that configured directory).
3. Groups files by folder and compresses them into `<folder>\yyyy-MM-dd.7z`.
4. Removes `*.7z` archives older than `DeleteArchivesOlderThanMonths` (recursively only when `recursive` is `true`).
5. Writes timestamped progress and error output to the console.
