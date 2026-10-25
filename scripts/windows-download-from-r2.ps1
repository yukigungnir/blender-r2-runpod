[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$Destination,

    [string]$Bucket = $env:R2_BUCKET,
    [string]$Prefix = 'castorice_vertical/frames',
    [int]$Transfers = 8
)

$ErrorActionPreference = 'Stop'

if (-not (Get-Command rclone -ErrorAction SilentlyContinue)) {
    throw '未找到 rclone。请先从 rclone.org 安装并配置 r2: remote。'
}
if ([string]::IsNullOrWhiteSpace($Bucket)) {
    throw '请用 -Bucket 指定 R2 Bucket，或设置 R2_BUCKET 环境变量。'
}

New-Item -ItemType Directory -Force -Path $Destination | Out-Null
$source = "r2:$Bucket/$($Prefix.TrimStart('/'))"

& rclone copy $source $Destination `
    --include '*.png' `
    --transfers $Transfers `
    --checkers 16 `
    --retries 10 `
    --low-level-retries 20 `
    --progress

if ($LASTEXITCODE -ne 0) {
    throw "Rclone 下载失败，退出码 $LASTEXITCODE。"
}

$localCount = (Get-ChildItem -LiteralPath $Destination -File -Filter '*.png').Count
$remoteCount = (& rclone lsf $source --files-only --include '*.png' | Measure-Object -Line).Lines
if ($LASTEXITCODE -ne 0) {
    throw "无法读取 R2 文件清单，退出码 $LASTEXITCODE。"
}

[pscustomobject]@{
    Source      = $source
    Destination = (Resolve-Path -LiteralPath $Destination).Path
    LocalCount  = $localCount
    RemoteCount = $remoteCount
    Match       = ($localCount -eq $remoteCount)
} | Format-List

if ($localCount -ne $remoteCount) {
    throw '本地 PNG 数量与 R2 不一致，请不要删除云端素材。'
}
