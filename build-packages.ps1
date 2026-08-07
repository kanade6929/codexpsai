param(
  [switch]$CheckOnly
)

$ErrorActionPreference = "Stop"

$siteRoot = $PSScriptRoot
$projectRoot = Split-Path -Parent (Split-Path -Parent $siteRoot)
$manifestPath = Join-Path $siteRoot "package-manifest.json"
$pluginsPath = Join-Path $siteRoot "plugins.json"
$downloadsDir = Join-Path $siteRoot "downloads"
$usageStem = -join ([char[]](20351, 29992, 35828, 26126))
$usageFileName = $usageStem + ".txt"

function Write-Step([string]$message) {
  Write-Host ""
  Write-Host ("== " + $message) -ForegroundColor Cyan
}

function Assert-UnderPath([string]$parent, [string]$child) {
  $parentFull = [IO.Path]::GetFullPath($parent).TrimEnd("\", "/") + [IO.Path]::DirectorySeparatorChar
  $childFull = [IO.Path]::GetFullPath($child)
  if (-not $childFull.StartsWith($parentFull, [StringComparison]::OrdinalIgnoreCase)) {
    throw "Refusing to operate outside expected folder: $childFull"
  }
}

function ConvertTo-JsonText($value) {
  return ($value | ConvertTo-Json -Depth 12)
}

function New-CleanDirectory([string]$path, [string]$allowedParent) {
  Assert-UnderPath $allowedParent $path
  if (Test-Path -LiteralPath $path) {
    Remove-Item -LiteralPath $path -Recurse -Force
  }
  New-Item -ItemType Directory -Force -Path $path | Out-Null
}

function New-ZipFromDirectory([string]$sourceDir, [string]$zipPath) {
  if (Test-Path -LiteralPath $zipPath) {
    Remove-Item -LiteralPath $zipPath -Force
  }

  Add-Type -AssemblyName System.IO.Compression
  Add-Type -AssemblyName System.IO.Compression.FileSystem

  $archive = [System.IO.Compression.ZipFile]::Open($zipPath, [System.IO.Compression.ZipArchiveMode]::Create)
  try {
    Get-ChildItem -LiteralPath $sourceDir -File -Recurse -Force | Sort-Object FullName | ForEach-Object {
      $relative = $_.FullName.Substring($sourceDir.Length + 1).Replace([IO.Path]::DirectorySeparatorChar, "/")
      [System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile(
        $archive,
        $_.FullName,
        $relative,
        [System.IO.Compression.CompressionLevel]::Optimal
      ) | Out-Null
    }
  }
  finally {
    $archive.Dispose()
  }
}

function Write-GeneratedUsage($plugin, [string]$path) {
  $apps = ($plugin.apps -join " / ")
  $notes = ""
  foreach ($note in @($plugin.notes)) {
    $notes += ("- " + $note + [Environment]::NewLine)
  }

  $text = @"
$($plugin.name)

Purpose:
$($plugin.summary)

Apps:
$apps

Install / Run:
$($plugin.install)

Requirements:
$($plugin.requirements)

Status:
$($plugin.status)

Notes:
$notes
"@

  Set-Content -LiteralPath $path -Value $text -Encoding UTF8
}

function ConvertTo-UrlSegment([string]$value) {
  return [Uri]::EscapeDataString($value)
}

Write-Step "Read package manifest"
if (-not (Test-Path -LiteralPath $manifestPath -PathType Leaf)) {
  throw "Missing package manifest: $manifestPath"
}

$manifest = Get-Content -LiteralPath $manifestPath -Raw -Encoding UTF8 | ConvertFrom-Json
if (-not $manifest.plugins -or $manifest.plugins.Count -lt 1) {
  throw "package-manifest.json contains no plugins."
}

New-Item -ItemType Directory -Force -Path $downloadsDir | Out-Null

$generatedPlugins = @()
$tempRoot = Join-Path ([IO.Path]::GetTempPath()) ("codex-adobe-tools-" + [Guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Force -Path $tempRoot | Out-Null

try {
  foreach ($plugin in $manifest.plugins) {
    Write-Step ("Build " + $plugin.slug)

    if ([string]::IsNullOrWhiteSpace($plugin.slug)) {
      throw "A plugin entry is missing slug."
    }

    $packageDir = Join-Path $downloadsDir $plugin.slug
    New-CleanDirectory $packageDir $downloadsDir

    $stageDir = Join-Path $tempRoot $plugin.slug
    New-Item -ItemType Directory -Force -Path $stageDir | Out-Null

    $copied = 0
    foreach ($relativeSource in @($plugin.sourceFiles)) {
      $sourcePath = Join-Path $projectRoot $relativeSource
      if (-not (Test-Path -LiteralPath $sourcePath -PathType Leaf)) {
        throw ("Missing source file for {0}: {1}" -f $plugin.slug, $sourcePath)
      }

      $targetPath = Join-Path $stageDir ([IO.Path]::GetFileName($sourcePath))
      Copy-Item -LiteralPath $sourcePath -Destination $targetPath -Force
      $copied++
    }

    $usageFiles = Get-ChildItem -LiteralPath $stageDir -File -Force | Where-Object {
      ($_.Name -like ("*" + $usageStem + "*.txt")) -or ($_.Name -ieq "README.txt")
    }
    if ($usageFiles.Count -eq 0) {
      Write-GeneratedUsage $plugin (Join-Path $stageDir $usageFileName)
    }

    $publicFiles = @()
    Get-ChildItem -LiteralPath $stageDir -File -Force | Sort-Object Name | ForEach-Object {
      $hash = (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
      $publicFiles += [ordered]@{
        name = $_.Name
        sizeBytes = $_.Length
        sha256 = $hash
      }
    }

    $fileCount = $publicFiles.Count
    if ($fileCount -lt 1) {
      throw ("No public files were generated for " + $plugin.slug)
    }

    $zipName = $plugin.slug + ".zip"
    $zipPath = Join-Path $packageDir $zipName
    New-ZipFromDirectory $stageDir $zipPath
    $zipItem = Get-Item -LiteralPath $zipPath
    $zipHash = (Get-FileHash -LiteralPath $zipPath -Algorithm SHA256).Hash.ToLowerInvariant()

    $generatedPlugins += [ordered]@{
      slug = $plugin.slug
      name = $plugin.name
      version = $plugin.version
      updatedAt = $plugin.updatedAt
      apps = @($plugin.apps)
      category = $plugin.category
      type = $plugin.type
      status = $plugin.status
      summary = $plugin.summary
      requirements = $plugin.requirements
      install = $plugin.install
      notes = @($plugin.notes)
      downloadUrl = ("downloads/{0}/{1}" -f $plugin.slug, (ConvertTo-UrlSegment $zipName))
      packageName = $zipName
      packageSha256 = $zipHash
      files = $publicFiles
      sizeBytes = $zipItem.Length
      fileCount = $fileCount
    }

    Write-Host ("Created zip: downloads/{0}/{1} ({2:N2} MB, {3} files)" -f $plugin.slug, $zipName, ($zipItem.Length / 1MB), $fileCount)
  }
}
finally {
  if (Test-Path -LiteralPath $tempRoot) {
    Remove-Item -LiteralPath $tempRoot -Recurse -Force
  }
}

Write-Step "Write plugins.json"
$output = [ordered]@{
  generatedAt = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
  pluginCount = $generatedPlugins.Count
  plugins = $generatedPlugins
}

ConvertTo-JsonText $output | Set-Content -LiteralPath $pluginsPath -Encoding UTF8
Write-Host ("Wrote: " + $pluginsPath)

Write-Step "Validate downloads"
$json = Get-Content -LiteralPath $pluginsPath -Raw -Encoding UTF8 | ConvertFrom-Json
foreach ($plugin in $json.plugins) {
  if ([string]::IsNullOrWhiteSpace($plugin.downloadUrl)) {
    throw ("Missing downloadUrl for " + $plugin.slug)
  }

  $filePath = Join-Path $siteRoot ([Uri]::UnescapeDataString($plugin.downloadUrl))
  if (-not (Test-Path -LiteralPath $filePath -PathType Leaf)) {
    throw ("Missing generated zip: " + $plugin.downloadUrl)
  }

  $actualSize = (Get-Item -LiteralPath $filePath).Length
  if ($actualSize -ne [int64]$plugin.sizeBytes) {
    throw ("Size mismatch: " + $plugin.downloadUrl)
  }

  $actualHash = (Get-FileHash -LiteralPath $filePath -Algorithm SHA256).Hash.ToLowerInvariant()
  if ($actualHash -ne $plugin.packageSha256) {
    throw ("SHA256 mismatch: " + $plugin.downloadUrl)
  }
}

Write-Host "Package build complete." -ForegroundColor Green
if ($CheckOnly) {
  Write-Host "CheckOnly mode finished." -ForegroundColor Green
}
