param(
  [switch]$CheckOnly
)

$ErrorActionPreference = "Stop"

$siteRoot = $PSScriptRoot
$configPath = Join-Path $siteRoot "github-pages.config.json"
$logPath = Join-Path $siteRoot "github-pages-upload-log.txt"

function Write-Step([string]$message) {
  Write-Host ""
  Write-Host ("== " + $message) -ForegroundColor Cyan
}

function Invoke-Git([string[]]$arguments, [switch]$AllowFailure) {
  & git @arguments
  $code = $LASTEXITCODE
  if ($code -ne 0 -and -not $AllowFailure) {
    throw ("git failed: git " + ($arguments -join " "))
  }
  return $code
}

function Get-GitText([string[]]$arguments) {
  $text = & git @arguments
  if ($null -eq $text) {
    return ""
  }
  return ([string]$text).Trim()
}

function Read-Config {
  if (-not (Test-Path -LiteralPath $configPath -PathType Leaf)) {
    throw ("Missing config: " + $configPath)
  }
  return Get-Content -LiteralPath $configPath -Raw -Encoding UTF8 | ConvertFrom-Json
}

function Save-Config($config) {
  $config | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $configPath -Encoding UTF8
}

function Get-RepositoryPageUrl([string]$repositoryUrl) {
  if ($repositoryUrl -match "github\.com[:/](?<owner>[^/]+)/(?<repo>[^/.]+)(\.git)?$") {
    $owner = $Matches.owner
    $repo = $Matches.repo
    if ($repo -ieq ($owner + ".github.io")) {
      return ("https://{0}.github.io/" -f $owner)
    }
    return ("https://{0}.github.io/{1}/" -f $owner, $repo)
  }
  return ""
}

function Assert-SiteFiles {
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
  foreach ($plugin in @($plugins.plugins)) {
    if ([string]::IsNullOrWhiteSpace($plugin.downloadUrl)) {
      throw ("Missing downloadUrl for " + $plugin.slug)
    }
    $zipPath = Join-Path $siteRoot ([Uri]::UnescapeDataString($plugin.downloadUrl))
    if (-not (Test-Path -LiteralPath $zipPath -PathType Leaf)) {
      throw ("Missing download zip: " + $plugin.downloadUrl)
    }
  }
}

function Ensure-GitRepository([string]$branch) {
  $gitDir = Join-Path $siteRoot ".git"
  if (-not (Test-Path -LiteralPath $gitDir -PathType Container)) {
    Write-Step "Initialize local git repository"
    $null = Invoke-Git @("init", "-b", $branch)
  }

  $currentBranch = Get-GitText @("branch", "--show-current")
  if ([string]::IsNullOrWhiteSpace($currentBranch)) {
    $null = Invoke-Git @("checkout", "-B", $branch)
  }
  elseif ($currentBranch -ne $branch) {
    Write-Host ("Current branch is " + $currentBranch + ". Publishing that branch instead of switching.") -ForegroundColor Yellow
  }

  if ([string]::IsNullOrWhiteSpace((Get-GitText @("config", "user.name")))) {
    $null = Invoke-Git @("config", "user.name", "zhou shangjie")
  }
  if ([string]::IsNullOrWhiteSpace((Get-GitText @("config", "user.email")))) {
    $null = Invoke-Git @("config", "user.email", "codex-local@example.com")
  }
}

function Ensure-Remote($config) {
  $remoteNames = @(& git remote)
  if ($remoteNames -contains "origin") {
    $remoteUrl = Get-GitText @("remote", "get-url", "origin")
    if (-not [string]::IsNullOrWhiteSpace($remoteUrl)) {
      return $remoteUrl
    }
  }

  $repoUrl = $config.repositoryUrl
  if ([string]::IsNullOrWhiteSpace($repoUrl)) {
    Write-Host "Create an empty GitHub repository first, then paste its HTTPS URL here." -ForegroundColor Yellow
    Write-Host "Example: https://github.com/your-name/codex-adobe-tools.git"
    $repoUrl = Read-Host "GitHub repository HTTPS URL"
    if ([string]::IsNullOrWhiteSpace($repoUrl)) {
      throw "Repository URL is required for GitHub Pages publishing."
    }

    $config.repositoryUrl = $repoUrl.Trim()
    $derivedUrl = Get-RepositoryPageUrl $config.repositoryUrl
    if (-not [string]::IsNullOrWhiteSpace($derivedUrl)) {
      $config.siteUrl = $derivedUrl
    }
    Save-Config $config
  }

  $null = Invoke-Git @("remote", "add", "origin", $config.repositoryUrl)
  return $config.repositoryUrl
}

function Commit-Site {
  Write-Step "Stage site files"
  $null = Invoke-Git @("add", "-A")

  $status = (& git status --porcelain)
  if ([string]::IsNullOrWhiteSpace($status)) {
    Write-Host "No git changes to commit."
    return
  }

  Write-Step "Create git commit"
  $message = "Update Codex Adobe tools archive"
  Invoke-Git @("commit", "-m", $message)
}

try {
  Set-Location $siteRoot
  "" | Set-Content -LiteralPath $logPath -Encoding UTF8

  Write-Step "Build plugin ZIP packages"
  & powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $siteRoot "build-packages.ps1") -CheckOnly
  if ($LASTEXITCODE -ne 0) {
    throw "build-packages.ps1 failed."
  }

  Write-Step "Validate site files"
  Assert-SiteFiles

  $config = Read-Config
  $branch = if ([string]::IsNullOrWhiteSpace($config.branch)) { "main" } else { $config.branch.Trim() }

  if ($CheckOnly) {
    Write-Step "CheckOnly complete"
    Write-Host "Nothing was committed or pushed."
    exit 0
  }

  Ensure-GitRepository $branch
  $remoteUrl = Ensure-Remote $config
  Commit-Site

  Write-Step "Push to GitHub"
  Invoke-Git @("push", "-u", "origin", $branch)

  $config = Read-Config
  $siteUrl = if ([string]::IsNullOrWhiteSpace($config.siteUrl)) { Get-RepositoryPageUrl $remoteUrl } else { $config.siteUrl.Trim() }

  Write-Host ""
  Write-Host "GitHub push complete." -ForegroundColor Green
  if (-not [string]::IsNullOrWhiteSpace($siteUrl)) {
    Write-Host ("Pages URL: " + $siteUrl) -ForegroundColor Green
  }
  Write-Host "If this is the first deploy, wait 1-3 minutes for GitHub Actions to publish Pages."
}
catch {
  Write-Host ""
  Write-Host ("GitHub Pages publish failed: " + $_.Exception.Message) -ForegroundColor Red
  Write-Host "Check github-pages-upload-log.txt or rerun this script after fixing the message above."
  exit 1
}
