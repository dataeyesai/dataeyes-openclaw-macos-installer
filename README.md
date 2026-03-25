# DataEyes OpenClaw macOS Installer

`DataEyes × OpenClaw` 的 macOS 安装器发布仓库。

## 直接下载

普通用户请优先下载：

- [DataEyes.Installer.dmg](https://github.com/dataeyesai/dataeyes-openclaw-macos-installer/releases/latest/download/DataEyes.Installer.dmg)

备用下载：

- [DataEyes.Installer.zip](https://github.com/dataeyesai/dataeyes-openclaw-macos-installer/releases/latest/download/DataEyes.Installer.zip)
- [DataEyes.Installer-unsigned.pkg](https://github.com/dataeyesai/dataeyes-openclaw-macos-installer/releases/latest/download/DataEyes.Installer-unsigned.pkg)
- [SHA256SUMS.txt](https://github.com/dataeyesai/dataeyes-openclaw-macos-installer/releases/latest/download/SHA256SUMS.txt)

下载建议：

- `DMG`：最适合普通 macOS 用户，推荐使用
- `ZIP`：适合直接拿到 `.app` 使用
- `PKG`：当前为未签名安装包，主要用于内部测试或后续补签名

兼容性：

- 支持 Apple Silicon（M1 / M2 / M3 / M4）和 Intel Mac
- 当前构建为 universal app：`arm64 + x86_64`

首次打开说明：

- 这版已经修复“应用已损坏”的打包问题
- 但由于尚未使用 Apple Developer ID 签名并 notarization，首次打开时 macOS 仍可能提示开发者未验证
- 如遇拦截，请在 Finder 中右键应用后选择“打开”，或到“系统设置 > 隐私与安全性”中允许打开

完整发布页：

- [GitHub Releases](https://github.com/dataeyesai/dataeyes-openclaw-macos-installer/releases)

这里同时保留了：

- 脚本安装器源码
- 原生 AppKit macOS 安装器源码
- 当前可直接分发的构建产物
- GitHub Release 所需的校验、说明和发布流程

## 当前交付物

已提交到仓库的最新产物位于 `artifacts/`：

- `DataEyes Installer.zip`
- `DataEyes Installer.dmg`
- `DataEyes Installer-unsigned.pkg`
- `SHA256SUMS.txt`
- `RELEASE_MANIFEST.md`

如果只是给用户下载，优先使用：

1. `DataEyes Installer.dmg`
2. `DataEyes Installer.zip`
3. `DataEyes Installer-unsigned.pkg`

说明：

- `.dmg` 最接近普通 macOS 分发体验
- `.zip` 适合直接分发 `.app`
- `.pkg` 当前是未签名版本，适合内部测试或后续补签名
- 当前 `.app` 为 universal binary，可同时支持 Intel 与 Apple Silicon

## 这版安装器包含的修复

- 支持国内站 / 国际站双平台配置
- 根据填写的 API Key 自动发现并注入可用模型，避免不同分组只落到固定模板模型
- 生成后的模型列表会写入 OpenClaw 配置，并可在 OpenClaw 中切换
- 提供 `~/.dataeyes-openclaw/bin/dataeyes-refresh-models` 用于后续刷新模型
- 安装界面显示当前步骤、进度条和实时心跳状态，日志区不再显示 ANSI 乱码
- 安装前可直接验证 API Key 是否可用，并可在安装后打开 `~/.openclaw/openclaw.json`
- 修复重复安装时 npm 目录冲突导致的 `ENOTEMPTY` 安装失败
- 检测到旧安装时会明确提示当前处于覆盖升级模式，并可选择“彻底重装”
- 模型发现结果会过滤掉非聊天模型，并默认优先使用 `gpt-5.4`
- 修复 macOS 密码框粘贴问题
- 安装时强制覆盖旧的 gateway service 定义，避免 `loaded but stopped`
- 安装完成后不再直接打开裸的 `127.0.0.1:18789`
- 改为读取 `~/.openclaw/openclaw.json` 中真实的 `gateway.auth.token`
- 自动打开 `http://localhost:18789/#token=...`，避免 Control UI 出现 `gateway token mismatch` / `retry later`

## 仓库结构

- `artifacts/`
  当前 release 产物和校验清单
- `dataeyes-installer-src-v2/`
  脚本安装器源码
- `dataeyes-macos-app/`
  原生 macOS 安装器源码与打包脚本
- `docs/`
  发布清单和 release 文案模板
- `scripts/prepare-release.sh`
  统一的发布整理脚本

## 本地构建

```bash
cd dataeyes-macos-app
bash build-app.sh
bash build-dmg.sh
bash build-pkg.sh
```

生成结果默认位于：

- `dataeyes-macos-app/build/DataEyes Installer.app`
- `dataeyes-macos-app/build/DataEyes Installer.zip`
- `dataeyes-macos-app/build/DataEyes Installer.dmg`
- `dataeyes-macos-app/build/DataEyes Installer-unsigned.pkg`

## 发布整理

统一整理 release 文件：

```bash
bash scripts/prepare-release.sh
```

如果希望脚本在整理前重新构建：

```bash
BUILD_ARTIFACTS=1 bash scripts/prepare-release.sh
```

脚本会完成这些事：

- 检查并按需构建 `.zip` / `.dmg` / `.pkg`
- 同步产物到 `artifacts/`
- 生成 `artifacts/SHA256SUMS.txt`
- 生成 `artifacts/RELEASE_MANIFEST.md`
- 生成 `release/release-notes-v<version>.md`

## GitHub Release 流程

1. 修改 `dataeyes-macos-app/release-config.sh` 里的 `APP_VERSION` 和 `APP_BUILD`
2. 运行 `bash scripts/prepare-release.sh`
3. 检查 `artifacts/` 中的产物和校验信息
4. 提交变更并推送到 `main`
5. 创建 tag，例如 `git tag v1.0.0`
6. 推送 tag：`git push origin v1.0.0`
7. 使用 GitHub Web 或 `gh release create` 上传 `.dmg`、`.zip` 和校验文件

## 签名与公证

签名、公证配置在：

- `dataeyes-macos-app/release-config.sh`
- `dataeyes-macos-app/sign-and-notarize.sh`

常用命令：

```bash
cd dataeyes-macos-app
bash sign-and-notarize.sh app
bash sign-and-notarize.sh dmg
bash sign-and-notarize.sh pkg
```

如果要真正对外公开分发，仍建议使用 Apple Developer ID 签名并完成 notarization。
