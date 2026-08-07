param(
  [switch]$CheckOnly
)

$ErrorActionPreference = "Stop"

$siteRoot = $PSScriptRoot
$configPath = Join-Path $siteRoot "netlify-site.config.json"
$tokenFile = Join-Path $siteRoot "netlify-token.txt"
$logPath = Join-Path $siteRoot "upload-log.txt"
$script:backupZipPath = ""

function Write-Step([string]$message) {
  Write-Host ""
  Write-Host ("== " + $message) -ForegroundColor Cyan
}

function Get-Config {
  if (-not (Test-Path -LiteralPath $configPath -PathType Leaf)) {
    throw "Missing config file: $configPath"
  }
  return (Get-Content -LiteralPath $configPath -Raw -Encoding UTF8 | ConvertFrom-Json)
}

function Save-Config($config) {
  ($config | ConvertTo-Json -Depth 8) | Set-Content -LiteralPath $configPath -Encoding UTF8
}

function Get-NetlifySiteId($config) {
  if (-not [string]::IsNullOrWhiteSpace($config.siteId)) {
    return $config.siteId.Trim()
  }

  if ($CheckOnly) {
    return ""
  }

  Write-Host "第一次发布插件合集需要 Netlify Site ID。" -ForegroundColor Yellow
  $siteId = (Read-Host "Netlify Site ID").Trim()
  if ([string]::IsNullOrWhiteSpace($siteId)) {
    throw "No Netlify Site ID was provided."
  }

  $config.siteId = $siteId
  $saveSite = Read-Host "保存 Site ID 到 netlify-site.config.json 吗？输入 y 保存，直接回车跳过"
  if ($saveSite -eq "y" -or $saveSite -eq "Y") {
    Save-Config $config
    Write-Host "Site ID saved."
  }

  return $siteId
}

function Get-NetlifyToken {
  if (-not [string]::IsNullOrWhiteSpace($env:NETLIFY_AUTH_TOKEN)) {
    return $env:NETLIFY_AUTH_TOKEN.Trim()
  }

  if (Test-Path -LiteralPath $tokenFile -PathType Leaf) {
    $savedToken = (Get-Content -LiteralPath $tokenFile -Raw -Encoding UTF8).Trim()
    if (-not [string]::IsNullOrWhiteSpace($savedToken)) {
      return $savedToken
    }
  }

  Write-Host "第一次上传需要粘贴 Netlify token。它只会保存在本机目录，不会上传。" -ForegroundColor Yellow
  $token = (Read-Host "Netlify token").Trim()
  if ([string]::IsNullOrWhiteSpace($token)) {
    throw "No Netlify token was provided."
  }

  $saveToken = Read-Host "保存 token 到 netlify-token.txt 吗？输入 y 保存，直接回车跳过"
  if ($saveToken -eq "y" -or $saveToken -eq "Y") {
    Set-Content -LiteralPath $tokenFile -Value $token -Encoding UTF8
    Write-Host "Token saved."
  }

  return $token
}

function Test-SiteFiles {
  $required = @(
    "index.html",
    "styles.css",
    "app.js",
    "plugins.json",
    "assets/codex-adobe-tools.svg"
  )

  foreach ($relative in $required) {
    $path = Join-Path $siteRoot $relative
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
      throw ("Missing site file: " + $relative)
    }
  }

  $plugins = Get-Content -LiteralPath (Join-Path $siteRoot "plugins.json") -Raw -Encoding UTF8 | ConvertFrom-Json
  foreach ($plugin in $plugins.plugins) {
    if ([string]::IsNullOrWhiteSpace($plugin.downloadUrl)) {
      throw ("Missing downloadUrl for " + $plugin.slug)
    }

    $filePath = Join-Path $siteRoot ([Uri]::UnescapeDataString($plugin.downloadUrl))
    if (-not (Test-Path -LiteralPath $filePath -PathType Leaf)) {
      throw ("Missing download zip: " + $plugin.downloadUrl)
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
}

function New-NetlifyZip([string]$siteName) {
  $stamp = Get-Date -Format "yyyyMMdd-HHmmss"
  $zipPath = Join-Path $siteRoot ($siteName + "-netlify-backup-" + $stamp + ".zip")

  if (Test-Path -LiteralPath $zipPath) {
    Remove-Item -LiteralPath $zipPath -Force
  }

  Add-Type -AssemblyName System.IO.Compression
  Add-Type -AssemblyName System.IO.Compression.FileSystem
  $archive = [System.IO.Compression.ZipFile]::Open($zipPath, [System.IO.Compression.ZipArchiveMode]::Create)

  try {
    $rootFiles = @("index.html", "styles.css", "app.js", "plugins.json")
    foreach ($fileName in $rootFiles) {
      $filePath = Join-Path $siteRoot $fileName
      [System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile(
        $archive,
        $filePath,
        $fileName,
        [System.IO.Compression.CompressionLevel]::Optimal
      ) | Out-Null
    }

    foreach ($dirName in @("assets", "downloads")) {
      $dirPath = Join-Path $siteRoot $dirName
      Get-ChildItem -LiteralPath $dirPath -File -Recurse -Force | Sort-Object FullName | ForEach-Object {
        $relative = $_.FullName.Substring($siteRoot.Length + 1).Replace([IO.Path]::DirectorySeparatorChar, "/")
        [System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile(
          $archive,
          $_.FullName,
          $relative,
          [System.IO.Compression.CompressionLevel]::Optimal
        ) | Out-Null
      }
    }
  }
  finally {
    $archive.Dispose()
  }

  return $zipPath
}

function Invoke-CurlText([string[]]$arguments, [string]$actionName, [int]$retryCount = 3) {
  $curl = (Get-Command curl.exe -ErrorAction Stop).Source
  $lastOutput = ""

  for ($attempt = 1; $attempt -le $retryCount; $attempt++) {
    if ($retryCount -gt 1) {
      Write-Host ("{0}: attempt {1}/{2}" -f $actionName, $attempt, $retryCount)
    }

    $oldErrorActionPreference = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    try {
      $output = & $curl @arguments 2>&1
      $exitCode = $LASTEXITCODE
    }
    finally {
      $ErrorActionPreference = $oldErrorActionPreference
    }

    $lastOutput = ($output -join "`n")
    if ($exitCode -eq 0) {
      return $lastOutput
    }

    Write-Host ("curl failed with exit code " + $exitCode) -ForegroundColor Yellow
    if (-not [string]::IsNullOrWhiteSpace($lastOutput)) {
      Write-Host $lastOutput -ForegroundColor DarkYellow
    }

    if ($attempt -lt $retryCount) {
      Start-Sleep -Seconds (3 * $attempt)
    }
  }

  throw ($actionName + " failed." + [Environment]::NewLine + $lastOutput)
}

function Publish-Zip([string]$zipPath, [string]$siteId, [string]$token) {
  Write-Step "Upload zip to Netlify"
  $uploadArgs = @(
    "-sS",
    "--fail-with-body",
    "--connect-timeout", "20",
    "--max-time", "1800",
    "-X", "POST",
    ("https://api.netlify.com/api/v1/sites/{0}/deploys" -f $siteId),
    "-H", ("Authorization: Bearer " + $token),
    "-H", "Content-Type: application/zip",
    "-H", "User-Agent: codex-adobe-tools-uploader",
    "--data-binary", ("@" + $zipPath)
  )

  $resultJson = Invoke-CurlText $uploadArgs "Upload zip" 3
  return ($resultJson | ConvertFrom-Json)
}

try {
  if (Test-Path -LiteralPath $logPath) {
    Remove-Item -LiteralPath $logPath -Force
  }
  Start-Transcript -LiteralPath $logPath -Force | Out-Null
}
catch {
  Write-Host "Could not start log file, continuing anyway." -ForegroundColor Yellow
}

try {
  Write-Step "Build plugin packages"
  & powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $siteRoot "build-packages.ps1") -CheckOnly

  Write-Step "Check site files"
  Test-SiteFiles
  $config = Get-Config
  $siteName = if ([string]::IsNullOrWhiteSpace($config.siteName)) { "codex-adobe-tools" } else { $config.siteName.Trim() }
  $siteUrl = if ([string]::IsNullOrWhiteSpace($config.siteUrl)) { "https://your-plugin-archive.netlify.app/" } else { $config.siteUrl.Trim() }

  Write-Step "Create Netlify backup zip"
  $script:backupZipPath = New-NetlifyZip $siteName
  $zipSize = (Get-Item -LiteralPath $script:backupZipPath).Length
  Write-Host ("Backup zip: " + $script:backupZipPath)
  Write-Host ("Backup zip size: {0:N2} MB" -f ($zipSize / 1MB))

  if ($CheckOnly) {
    Write-Host ""
    Write-Host "CheckOnly complete. Nothing was uploaded." -ForegroundColor Green
    exit 0
  }

  $siteId = Get-NetlifySiteId $config
  $token = Get-NetlifyToken
  $result = Publish-Zip $script:backupZipPath $siteId $token

  Write-Host ""
  Write-Host ("Netlify state: " + $result.state) -ForegroundColor Green
  Write-Host ("Live URL: " + $siteUrl + "?v=" + (Get-Date -Format "yyyyMMddHHmmss")) -ForegroundColor Green
  if ($result.deploy_ssl_url) {
    Write-Host ("Deploy URL: " + $result.deploy_ssl_url) -ForegroundColor Green
  }
  exit 0
}
catch {
  Write-Host ""
  Write-Host "Upload failed:" -ForegroundColor Red
  Write-Host $_.Exception.Message -ForegroundColor Red
  Write-Host ""
  if ($script:backupZipPath) {
    Write-Host "A backup zip was created for manual Netlify upload:" -ForegroundColor Yellow
    Write-Host $script:backupZipPath -ForegroundColor Yellow
  }
  Write-Host ("Log file: " + $logPath) -ForegroundColor Yellow
  exit 1
}
finally {
  try {
    Stop-Transcript | Out-Null
  }
  catch {}
}
