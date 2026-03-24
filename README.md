# DataEyes OpenClaw macOS Installer

这个仓库包含 `DataEyes × OpenClaw` 的 macOS 安装器源码和最新可交付产物。

## 包含内容

- `dataeyes-installer-src-v2/`
  脚本安装器源码
- `dataeyes-macos-app/`
  原生 AppKit macOS 安装器源码
- `artifacts/`
  最新构建产物：
  - `DataEyes Installer.app`
  - `DataEyes Installer.dmg`
  - `DataEyes Installer.zip`
  - `DataEyes Installer-unsigned.pkg`

## 当前版本修复点

- 支持国内站 / 国际站双平台配置
- 修复 macOS 密码框粘贴问题
- 安装时强制覆盖旧的 gateway service 定义，避免 `loaded but stopped`
- 安装完成后不再直接打开裸的 `127.0.0.1:18789`
- 改为读取 `~/.openclaw/openclaw.json` 中真实的 `gateway.auth.token`
- 自动打开 `http://localhost:18789/#token=...`，避免 Control UI 出现 `gateway token mismatch` / `retry later`

## 构建

```bash
cd dataeyes-macos-app
bash build-app.sh
bash build-dmg.sh
bash build-pkg.sh
```

## 当前交付物

最新构建产物位于 `artifacts/` 目录。
