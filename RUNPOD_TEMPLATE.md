# Runpod 私有模板设置

## 模板基础项

- 名称：`blender-5.2-r2-autobackup`
- 可见性：Private
- Container image：`ghcr.io/yukigungnir/blender-r2-runpod:5.2.2`
- Container disk：20 GB 起；大型工程按实际依赖增大
- Volume mount path：`/workspace`
- 暴露端口：纯命令行渲染不需要
- Allowed CUDA：最低 12.8（与镜像一致）
- Docker command：留空；需要自动启动时可设 `/opt/render-tools/r2-upload-loop.sh`

如果使用网络卷，卷和 GPU 必须位于同一数据中心。网络卷会持续按容量计费，直到删除；本包本身不要求创建网络卷。

## 环境变量

从 `template-env.example` 逐项填写。以下两个变量必须通过 Secret 选择器绑定：

| 环境变量 | Runpod Secret |
| --- | --- |
| `RCLONE_CONFIG_R2_ACCESS_KEY_ID` | `r2_access_key_id` |
| `RCLONE_CONFIG_R2_SECRET_ACCESS_KEY` | `r2_secret_access_key` |

以下变量填写普通值：

| 名称 | 值 |
| --- | --- |
| `RCLONE_CONFIG_R2_TYPE` | `s3` |
| `RCLONE_CONFIG_R2_PROVIDER` | `Cloudflare` |
| `RCLONE_CONFIG_R2_ENDPOINT` | `https://ACCOUNT_ID.r2.cloudflarestorage.com` |
| `RCLONE_CONFIG_R2_REGION` | `auto` |
| `R2_BUCKET` | 实际 Bucket 名称 |
| `R2_PREFIX` | `castorice_vertical/frames` |
| `RENDER_DIR` | `/workspace/render/frames` |
| `LOG_DIR` | `/workspace/logs` |
| `R2_INTERVAL_SECONDS` | `120` |
| `R2_MIN_AGE` | `2m` |
| `R2_TRANSFERS` | `4` |

## 启动后无泄密检查

不要运行 `env` 或 `printenv`。只运行：

```bash
/opt/render-tools/preflight.sh
```

脚本只显示变量是否存在，不显示变量值，并验证指定 Bucket 是否可访问。

## 首次测试顺序

1. 上传工程与贴图到 `/workspace/project/`。
2. 设置 3～5 帧范围。
3. 运行 `/opt/render-tools/render-with-backup.sh`。
4. 检查 `/workspace/logs/r2-upload.log` 和 `/workspace/logs/final-summary.json`。
5. 模拟重启上传循环，再确认相同文件被跳过。
6. 抽样从 R2 下载两张 PNG 并打开。
