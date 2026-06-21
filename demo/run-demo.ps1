param(
    [switch]$SelfTest,
    [string]$ConfigPath = (Join-Path $PSScriptRoot "demo-config.ps1")
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = New-Object System.Text.UTF8Encoding($false)
$OutputEncoding = [Console]::OutputEncoding

$script:LogFile = $null
$script:StageNumber = 0

function Write-DemoLine {
    param(
        [Parameter(Mandatory = $true)][string]$Message,
        [ConsoleColor]$Color = [ConsoleColor]::Gray
    )

    Write-Host $Message -ForegroundColor $Color
    if ($script:LogFile) {
        Add-Content -LiteralPath $script:LogFile -Value $Message -Encoding UTF8
    }
}

function Write-Stage {
    param([Parameter(Mandatory = $true)][string]$Message)
    $script:StageNumber++
    Write-DemoLine ""
    Write-DemoLine ("[{0}] {1}" -f $script:StageNumber, $Message) Cyan
}

function Stop-Demo {
    param([Parameter(Mandatory = $true)][string]$Message)
    throw $Message
}

function Test-PlaceholderValue {
    param([object]$Value)
    if ($null -eq $Value) {
        return $true
    }
    $text = [string]$Value
    return [string]::IsNullOrWhiteSpace($text) -or
        $text -match "^(REPLACE_|https://github\.com/your-account/)"
}

function Get-DemoConfig {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [switch]$ShapeOnly
    )

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        Stop-Demo "找不到配置文件：$Path`n请复制 demo-config.example.ps1 为 demo-config.ps1，并填写真实参数。"
    }

    $config = & $Path
    if (-not ($config -is [hashtable])) {
        Stop-Demo "配置文件必须返回 PowerShell Hashtable（@{ ... }）。"
    }

    $requiredKeys = @(
        "GithubReviewLogUri",
        "GithubToken",
        "ChatGlmApiHost",
        "ChatGlmApiKeySecret",
        "WeixinAppId",
        "WeixinSecret",
        "WeixinToUser",
        "WeixinTemplateId",
        "ProjectName",
        "BranchName",
        "CommitAuthor",
        "CommitMessage",
        "JavaDownloadUrl",
        "GitHubReleaseApiUrl",
        "SdkJarPath",
        "SdkJarDownloadUrl"
    )

    $missing = @()
    foreach ($key in $requiredKeys) {
        if (-not $config.ContainsKey($key)) {
            $missing += $key
        }
    }
    if ($missing.Count -gt 0) {
        Stop-Demo ("配置文件缺少字段：{0}" -f ($missing -join ", "))
    }

    if (-not $ShapeOnly) {
        $invalid = @()
        foreach ($key in $requiredKeys) {
            if ($key -ne "SdkJarPath" -and (Test-PlaceholderValue $config[$key])) {
                $invalid += $key
            }
        }
        if ($invalid.Count -gt 0) {
            Stop-Demo ("以下配置尚未填写：{0}" -f ($invalid -join ", "))
        }

        foreach ($key in @("ProjectName", "BranchName", "CommitAuthor")) {
            if ([string]$config[$key] -match '[<>:"/\\|?*]') {
                Stop-Demo "$key 包含 Windows 文件名不允许的字符：<>:`"/\|?*"
            }
        }
    }

    return $config
}

function New-CleanDirectory {
    param([Parameter(Mandatory = $true)][string]$Path)
    if (Test-Path -LiteralPath $Path) {
        Remove-Item -LiteralPath $Path -Recurse -Force
    }
    New-Item -ItemType Directory -Path $Path -Force | Out-Null
}

function Invoke-Download {
    param(
        [Parameter(Mandatory = $true)][string]$Uri,
        [Parameter(Mandatory = $true)][string]$Destination,
        [int]$Attempts = 3
    )

    $parent = Split-Path -Parent $Destination
    New-Item -ItemType Directory -Path $parent -Force | Out-Null
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

    for ($attempt = 1; $attempt -le $Attempts; $attempt++) {
        try {
            Write-DemoLine ("  下载中（第 {0}/{1} 次）..." -f $attempt, $Attempts) DarkGray
            Invoke-WebRequest -Uri $Uri -OutFile $Destination -UseBasicParsing -Headers @{
                "User-Agent" = "ai-code-review-windows-demo"
            }
            if ((Test-Path -LiteralPath $Destination) -and
                (Get-Item -LiteralPath $Destination).Length -gt 0) {
                return
            }
            throw "下载文件为空"
        }
        catch {
            if ($attempt -eq $Attempts) {
                Stop-Demo "下载失败：$Uri`n$($_.Exception.Message)"
            }
            Start-Sleep -Seconds (2 * $attempt)
        }
    }
}

function Invoke-JsonRequest {
    param(
        [Parameter(Mandatory = $true)][string]$Uri,
        [int]$Attempts = 3
    )

    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    for ($attempt = 1; $attempt -le $Attempts; $attempt++) {
        try {
            return Invoke-RestMethod -Uri $Uri -UseBasicParsing -Headers @{
                "User-Agent" = "ai-code-review-windows-demo"
                "Accept" = "application/vnd.github+json"
            }
        }
        catch {
            if ($attempt -eq $Attempts) {
                Stop-Demo "访问官方 API 失败：$Uri`n$($_.Exception.Message)"
            }
            Start-Sleep -Seconds (2 * $attempt)
        }
    }
}

function Invoke-NativeCommand {
    param(
        [Parameter(Mandatory = $true)][string]$FilePath,
        [string[]]$Arguments = @(),
        [string]$WorkingDirectory = $PSScriptRoot,
        [int[]]$AllowedExitCodes = @(0),
        [switch]$Quiet
    )

    Push-Location $WorkingDirectory
    try {
        $output = @(& $FilePath @Arguments 2>&1)
        $exitCode = $LASTEXITCODE
    }
    finally {
        Pop-Location
    }

    if (-not $Quiet) {
        foreach ($line in $output) {
            Write-DemoLine ([string]$line) DarkGray
        }
    }

    if ($AllowedExitCodes -notcontains $exitCode) {
        Stop-Demo ("命令执行失败（退出码 {0}）：{1} {2}`n{3}" -f
            $exitCode, $FilePath, ($Arguments -join " "), ($output -join "`n"))
    }

    return [pscustomobject]@{
        ExitCode = $exitCode
        Output = $output
    }
}

function Get-JavaMajorVersion {
    param([Parameter(Mandatory = $true)][string]$JavaExe)

    try {
        $result = Invoke-NativeCommand -FilePath $JavaExe -Arguments @("-version") -Quiet
        $text = $result.Output -join "`n"
        if ($text -match 'version "(?<major>\d+)(?:\.(?<minor>\d+))?') {
            $major = [int]$Matches["major"]
            if ($major -eq 1) {
                return [int]$Matches["minor"]
            }
            return $major
        }
    }
    catch {
        return 0
    }
    return 0
}

function Resolve-Java {
    param(
        [Parameter(Mandatory = $true)][hashtable]$Config,
        [Parameter(Mandatory = $true)][string]$RuntimeRoot
    )

    $systemJava = Get-Command "java.exe" -ErrorAction SilentlyContinue
    if ($systemJava) {
        $major = Get-JavaMajorVersion $systemJava.Source
        if ($major -ge 11) {
            Write-DemoLine "  使用系统 Java $major：$($systemJava.Source)" Green
            return $systemJava.Source
        }
    }

    $javaRoot = Join-Path $RuntimeRoot "java"
    $existing = Get-ChildItem -Path $javaRoot -Filter "java.exe" -Recurse -ErrorAction SilentlyContinue |
        Where-Object { $_.FullName -match '\\bin\\java\.exe$' } |
        Select-Object -First 1
    if ($existing) {
        Write-DemoLine "  使用已缓存的便携 Java：$($existing.FullName)" Green
        return $existing.FullName
    }

    Write-DemoLine "  未找到 Java 11+，准备 Eclipse Temurin 便携 JRE。" Yellow
    $download = Join-Path $RuntimeRoot "downloads\temurin-jre11.zip"
    Invoke-Download -Uri ([string]$Config.JavaDownloadUrl) -Destination $download
    New-CleanDirectory $javaRoot
    Expand-Archive -LiteralPath $download -DestinationPath $javaRoot -Force

    $java = Get-ChildItem -Path $javaRoot -Filter "java.exe" -Recurse |
        Where-Object { $_.FullName -match '\\bin\\java\.exe$' } |
        Select-Object -First 1
    if (-not $java) {
        Stop-Demo "便携 Java 下载完成，但没有找到 bin\java.exe。"
    }
    if ((Get-JavaMajorVersion $java.FullName) -lt 11) {
        Stop-Demo "下载的 Java 版本低于 11。"
    }
    return $java.FullName
}

function Resolve-Git {
    param(
        [Parameter(Mandatory = $true)][hashtable]$Config,
        [Parameter(Mandatory = $true)][string]$RuntimeRoot
    )

    $systemGit = Get-Command "git.exe" -ErrorAction SilentlyContinue
    if ($systemGit) {
        Write-DemoLine "  使用系统 Git：$($systemGit.Source)" Green
        return $systemGit.Source
    }

    $gitExe = Join-Path $RuntimeRoot "git\cmd\git.exe"
    if (Test-Path -LiteralPath $gitExe -PathType Leaf) {
        Write-DemoLine "  使用已缓存的便携 Git：$gitExe" Green
        return $gitExe
    }

    Write-DemoLine "  未找到 Git，准备 Git for Windows MinGit。" Yellow
    $release = Invoke-JsonRequest -Uri ([string]$Config.GitHubReleaseApiUrl)
    $asset = $release.assets |
        Where-Object {
            $_.name -match '^MinGit-.*-64-bit\.zip$' -and
            $_.name -notmatch 'busybox'
        } |
        Select-Object -First 1
    if (-not $asset) {
        Stop-Demo "Git for Windows 最新发布中未找到 MinGit 64-bit ZIP。"
    }

    $download = Join-Path $RuntimeRoot ("downloads\" + $asset.name)
    Invoke-Download -Uri ([string]$asset.browser_download_url) -Destination $download
    New-CleanDirectory (Join-Path $RuntimeRoot "git")
    Expand-Archive -LiteralPath $download -DestinationPath (Join-Path $RuntimeRoot "git") -Force

    if (-not (Test-Path -LiteralPath $gitExe -PathType Leaf)) {
        Stop-Demo "MinGit 解压完成，但没有找到 cmd\git.exe。"
    }
    return $gitExe
}

function Resolve-SdkJar {
    param(
        [Parameter(Mandatory = $true)][hashtable]$Config,
        [Parameter(Mandatory = $true)][string]$RuntimeRoot
    )

    $configuredPath = [string]$Config.SdkJarPath
    if (-not [string]::IsNullOrWhiteSpace($configuredPath) -and
        (Test-Path -LiteralPath $configuredPath -PathType Leaf)) {
        Write-DemoLine "  使用演示包内的 SDK JAR。" Green
        return (Resolve-Path -LiteralPath $configuredPath).Path
    }

    $cachedJar = Join-Path $RuntimeRoot "sdk\openai-code-review-sdk-1.0.jar"
    if (-not (Test-Path -LiteralPath $cachedJar -PathType Leaf)) {
        Write-DemoLine "  演示包内没有 SDK JAR，准备从固定地址下载。" Yellow
        Invoke-Download -Uri ([string]$Config.SdkJarDownloadUrl) -Destination $cachedJar
    }

    if ($Config.ContainsKey("SdkJarSha256") -and
        -not [string]::IsNullOrWhiteSpace([string]$Config.SdkJarSha256)) {
        $expected = ([string]$Config.SdkJarSha256).ToLowerInvariant()
        $actual = (Get-FileHash -LiteralPath $cachedJar -Algorithm SHA256).Hash.ToLowerInvariant()
        if ($actual -ne $expected) {
            Stop-Demo "SDK JAR 的 SHA-256 校验失败。"
        }
    }

    return $cachedJar
}

function Copy-DemoAssets {
    param(
        [Parameter(Mandatory = $true)][string]$Source,
        [Parameter(Mandatory = $true)][string]$Destination
    )

    Get-ChildItem -LiteralPath $Source -Force | ForEach-Object {
        Copy-Item -LiteralPath $_.FullName -Destination $Destination -Recurse -Force
    }
}

function Invoke-ReviewJar {
    param(
        [Parameter(Mandatory = $true)][string]$JavaExe,
        [Parameter(Mandatory = $true)][string]$JarPath,
        [Parameter(Mandatory = $true)][string]$WorkingDirectory,
        [Parameter(Mandatory = $true)][string]$LogFile
    )

    Push-Location $WorkingDirectory
    try {
        $output = @(& $JavaExe "-jar" $JarPath 2>&1)
        $exitCode = $LASTEXITCODE
    }
    finally {
        Pop-Location
    }

    foreach ($line in $output) {
        $text = [string]$line
        Write-Host $text
        Add-Content -LiteralPath $LogFile -Value $text -Encoding UTF8
    }

    if ($exitCode -ne 0) {
        Stop-Demo "评审程序退出码为 $exitCode。完整日志：$LogFile"
    }
    return ($output -join "`n")
}

function Invoke-Demo {
    $effectiveConfigPath = $ConfigPath
    if ($SelfTest -and -not (Test-Path -LiteralPath $effectiveConfigPath)) {
        $effectiveConfigPath = Join-Path $PSScriptRoot "demo-config.example.ps1"
    }

    $config = Get-DemoConfig -Path $effectiveConfigPath -ShapeOnly:$SelfTest
    if ($SelfTest) {
        Write-Output "SELF_TEST_OK"
        return
    }

    $runtimeRoot = Join-Path $PSScriptRoot "runtime"
    $workRoot = Join-Path $PSScriptRoot "work"
    $logRoot = Join-Path $workRoot "logs"
    $sampleRepo = Join-Path $workRoot "sample-project"
    New-Item -ItemType Directory -Path $runtimeRoot, $logRoot -Force | Out-Null
    New-CleanDirectory $sampleRepo

    $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
    $script:LogFile = Join-Path $logRoot "demo-$timestamp.log"
    Write-DemoLine "AI Code Review Windows 一键演示" White
    Write-DemoLine "运行日志：$script:LogFile" DarkGray

    Write-Stage "检查 Java 和 Git"
    $javaExe = Resolve-Java -Config $config -RuntimeRoot $runtimeRoot
    $gitExe = Resolve-Git -Config $config -RuntimeRoot $runtimeRoot
    $env:PATH = (Split-Path -Parent $gitExe) + ";" + $env:PATH

    Write-Stage "准备固定版本的评审 SDK"
    $sdkJar = Resolve-SdkJar -Config $config -RuntimeRoot $runtimeRoot
    $jarInRepo = Join-Path $sampleRepo "openai-code-review-sdk-1.0.jar"
    Copy-Item -LiteralPath $sdkJar -Destination $jarInRepo -Force

    Write-Stage "创建临时示例仓库和第一次提交"
    $initialAssets = Join-Path $PSScriptRoot "assets\initial"
    $changedAssets = Join-Path $PSScriptRoot "assets\changed"
    Copy-DemoAssets -Source $initialAssets -Destination $sampleRepo

    Invoke-NativeCommand -FilePath $gitExe -Arguments @("init") -WorkingDirectory $sampleRepo | Out-Null
    Invoke-NativeCommand -FilePath $gitExe -Arguments @("checkout", "-b", [string]$config.BranchName) -WorkingDirectory $sampleRepo | Out-Null
    Invoke-NativeCommand -FilePath $gitExe -Arguments @("config", "user.name", "AI Code Review Demo") -WorkingDirectory $sampleRepo | Out-Null
    Invoke-NativeCommand -FilePath $gitExe -Arguments @("config", "user.email", "demo@example.com") -WorkingDirectory $sampleRepo | Out-Null
    Invoke-NativeCommand -FilePath $gitExe -Arguments @("add", ".") -WorkingDirectory $sampleRepo | Out-Null
    # git commit：第一次提交
    Invoke-NativeCommand -FilePath $gitExe -Arguments @("commit", "-m", "feat: 初始化安全版本") -WorkingDirectory $sampleRepo | Out-Null

    Write-Stage "制造待评审代码并创建第二次提交"
    Remove-Item -LiteralPath (Join-Path $sampleRepo "src") -Recurse -Force
    Copy-DemoAssets -Source $changedAssets -Destination $sampleRepo
    Invoke-NativeCommand -FilePath $gitExe -Arguments @("add", ".") -WorkingDirectory $sampleRepo | Out-Null
    # git commit：第二次提交
    Invoke-NativeCommand -FilePath $gitExe -Arguments @("commit", "-m", [string]$config.CommitMessage) -WorkingDirectory $sampleRepo | Out-Null

    # git rev-list --count HEAD
    $countResult = Invoke-NativeCommand -FilePath $gitExe -Arguments @("rev-list", "--count", "HEAD") -WorkingDirectory $sampleRepo -Quiet
    $commitCount = [int](($countResult.Output | Select-Object -Last 1).ToString().Trim())
    if ($commitCount -ne 2) {
        Stop-Demo "临时示例仓库应该恰好有 2 次提交，实际为 $commitCount。"
    }

    # git diff --quiet HEAD^ HEAD；退出码 1 表示存在差异。
    $diffCheck = Invoke-NativeCommand -FilePath $gitExe -Arguments @("diff", "--quiet", "HEAD^", "HEAD") -WorkingDirectory $sampleRepo -AllowedExitCodes @(0, 1) -Quiet
    if ($diffCheck.ExitCode -ne 1) {
        Stop-Demo "两次提交之间没有代码差异，无法进行演示。"
    }
    Write-DemoLine "  待评审变更摘要：" Yellow
    Invoke-NativeCommand -FilePath $gitExe -Arguments @("diff", "--stat", "HEAD^", "HEAD") -WorkingDirectory $sampleRepo | Out-Null

    Write-Stage "调用 ChatGLM、推送报告并发送微信通知"
    $reviewLogUri = ([string]$config.GithubReviewLogUri).TrimEnd("/")
    if ($reviewLogUri.EndsWith(".git")) {
        $reviewLogUri = $reviewLogUri.Substring(0, $reviewLogUri.Length - 4)
    }

    $env:GITHUB_REVIEW_LOG_URI = $reviewLogUri
    $env:GITHUB_TOKEN = [string]$config.GithubToken
    $env:COMMIT_PROJECT = [string]$config.ProjectName
    $env:COMMIT_BRANCH = [string]$config.BranchName
    $env:COMMIT_AUTHOR = [string]$config.CommitAuthor
    $env:COMMIT_MESSAGE = [string]$config.CommitMessage
    $env:WEIXIN_APPID = [string]$config.WeixinAppId
    $env:WEIXIN_SECRET = [string]$config.WeixinSecret
    $env:WEIXIN_TOUSER = [string]$config.WeixinToUser
    $env:WEIXIN_TEMPLATE_ID = [string]$config.WeixinTemplateId
    $env:CHATGLM_APIHOST = [string]$config.ChatGlmApiHost
    $env:CHATGLM_APIKEYSECRET = [string]$config.ChatGlmApiKeySecret

    $reviewOutput = Invoke-ReviewJar -JavaExe $javaExe -JarPath $jarInRepo -WorkingDirectory $sampleRepo -LogFile $script:LogFile

    $errorMarker = "openai-code-review error"
    $gitMarker = "openai-code-review git commit and push done!"
    $weixinMarker = "openai-code-review weixin template message!"
    $doneMarker = "openai-code-review done!"

    if ($reviewOutput -match [regex]::Escape($errorMarker)) {
        Stop-Demo "评审程序记录了内部错误。请查看日志：$script:LogFile"
    }
    foreach ($marker in @($gitMarker, $weixinMarker, $doneMarker)) {
        if ($reviewOutput -notmatch [regex]::Escape($marker)) {
            Stop-Demo "没有检测到成功标记“$marker”。请查看日志：$script:LogFile"
        }
    }

    Write-Stage "演示成功"
    Write-DemoLine "代码评审报告已推送，微信模板消息已发送。" Green
    Write-DemoLine "报告仓库：$reviewLogUri" Green
    Write-DemoLine "运行日志：$script:LogFile" DarkGray
}

try {
    Invoke-Demo
    exit 0
}
catch {
    Write-DemoLine ""
    Write-DemoLine ("演示失败：{0}" -f $_.Exception.Message) Red
    if ($script:LogFile) {
        Write-DemoLine "请查看日志：$script:LogFile" Yellow
    }
    exit 1
}
