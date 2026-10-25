# Runpod + R2 + PikPak 自动同步包

这套文件用于 Blender Eevee 逐帧 PNG 渲染：渲染过程中每两分钟把已稳定写入的帧复制到 Cloudflare R2，渲染结束后再做一次不带 `--min-age` 的最终复制和数量/大小校验。PikPak 是可选的第二份副本。

## 已采用的安全设计

- R2 密钥不写入镜像、脚本或仓库，只由 Runpod Secrets 注入。
- 使用 `rclone move` 流式上传；只有单个文件复制无错误后才删除该本地源帧，不会删除 R2 中的备份。
- 正式渲染前先验证 R2 访问；验证失败就不开始渲染。
- 后台上传失败会保留未上传帧并持续重试，同时写入 `/workspace/logs/r2-upload-status.json` 和 `.failed` 标记。
- 持久盘低于 5 GB 可用空间时会停止渲染并保留现场，避免写满磁盘；下次启动从 R2 最早缺失帧继续。
- 渲染结束后核对 R2 的完整帧名清单和总帧数；不会自动删除 Pod 或云端文件。
- PikPak 凭证只建议配置在本地可信机器，默认不放进第三方 GPU Pod。

## 目录

- `Dockerfile`：Blender 5.2.2 + MMD Tools 4.5.14 + Rclone 的固定运行环境。
- `scripts/render-with-backup.sh`：正式入口，同时启动渲染和后台备份。
- `scripts/r2-upload-loop.sh`：只启动循环备份，适合在 Blender GUI 中手工渲染。
- `scripts/finalize-and-verify.sh`：最终复制与校验。
- `scripts/r2-to-pikpak.sh`：在可信机器上从 R2 转存到 PikPak。
- `scripts/windows-download-from-r2.ps1`：把完整 PNG 下载到 Windows。
- `template-env.example`：Runpod 模板环境变量清单，不含真实密钥。
- `RUNPOD_TEMPLATE.md`：私有模板的配置步骤。

## 1. 镜像地址

本仓库的 GitHub Actions 会自动构建并发布公开镜像：

```text
ghcr.io/yukigungnir/blender-r2-runpod:5.2.2-mmd4.5.14
```

只有在需要自行构建时，才使用下面的命令。

### 手动构建并推送

在有 Docker 的机器上，从本目录执行：

```bash
docker build -t YOUR_REGISTRY/blender-r2:5.2.2 .
docker push YOUR_REGISTRY/blender-r2:5.2.2
```

把 `YOUR_REGISTRY/blender-r2:5.2.2` 换成你的私有或公开镜像地址。建议固定标签，避免以后换 Pod 时环境漂移。

## 2. 创建 Runpod Secrets

在 Runpod Secrets 中创建：

- `r2_access_key_id`
- `r2_secret_access_key`

R2 API Token 应只给渲染专用 Bucket 的 Object Read & Write 权限。不要把值发到聊天、日志或写进本目录。

## 3. 创建私有 Pod Template

按 `RUNPOD_TEMPLATE.md` 填写镜像、磁盘与环境变量。非敏感变量可以直接填写；两个敏感变量使用 Runpod Secret 选择器。

## 4. 小规模测试

把 `.blend` 文件和依赖资源放到 `/workspace/project/`。先使用 3～5 帧，例如：

```bash
export BLEND_FILE=/workspace/project/castorice_vertical.blend
export FRAME_START=0
export FRAME_END=4
/opt/render-tools/render-with-backup.sh
```

成功标准：

1. `/workspace/render/frames/` 生成 5 张 PNG，编号为六位数字。
2. R2 目标目录出现相同 5 个文件。
3. `/workspace/logs/final-summary.json` 中 `local_count` 与 `remote_count` 相等，且 `local_bytes` 与 `remote_bytes` 相等。
4. 重跑同一命令时，Rclone 跳过相同文件，不重复大量传输。

## 5. 正式渲染

确认工程实际帧范围后再设置 `FRAME_START` 和 `FRAME_END`。清单中的 0～6530 只是默认候选值，本包默认不替你猜测工程范围。

```bash
export BLEND_FILE=/workspace/project/castorice_vertical.blend
export FRAME_START=0
export FRAME_END=6530
/opt/render-tools/render-with-backup.sh
```

如果你在 Blender GUI 中手工启动渲染，则另开一个终端运行：

```bash
/opt/render-tools/r2-upload-loop.sh
```

渲染完成后运行：

```bash
/opt/render-tools/finalize-and-verify.sh
```

只有 `final-summary.json` 核对通过并抽样打开云端图片后，才停止或删除 Pod。

## 6. 可选转存 PikPak

Rclone 1.62 起有原生 `pikpak` 后端，因此不需要依赖 WebDAV。只在本地可信机器运行一次 `rclone config`，创建名为 `pikpak` 的 remote；密码会以 Rclone 的 obscured 形式保存。然后：

```bash
./scripts/r2-to-pikpak.sh
```

默认目标为 `pikpak:Castorice/frames`，并发数为 2。

## 7. Windows 下载完整帧

先在 Windows 上配置可用的 `r2:` remote，然后在 PowerShell 中运行：

```powershell
.\scripts\windows-download-from-r2.ps1 -Destination 'D:\Castorice\frames'
```

## 费用边界

本包不会创建 GPU Pod，也不会自动停止 Runpod 计费。正式租用前必须根据实时 GPU 单价单独设置最大运行时长/预算守护；不要依赖旧版 CLI 的 `--stop-after` 或 `--terminate-after` 参数。
