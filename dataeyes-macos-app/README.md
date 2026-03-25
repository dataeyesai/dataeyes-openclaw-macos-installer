# DataEyes macOS App Installer

这个目录是 `DataEyes × OpenClaw` 的原生 macOS 安装器骨架。

## 目标

- 给用户交付标准 `.app`
- 在 App 内输入 API Key
- 在 App 内执行安装并展示日志
- 后续可以直接接入签名和公证

## 目录结构

- `Sources/DataEyesInstallerApp/main.swift`
  原生 AppKit 安装器窗口
- `release-config.sh`
  统一的版本、Bundle ID、签名变量配置
- `build-app.sh`
  构建 `.app` 并打包 zip
- `build-dmg.sh`
  导出 `.dmg`
- `build-pkg.sh`
  导出 `.pkg`
- `sign-and-notarize.sh`
  Developer ID 签名与公证脚本
- `scripts/create-iconset.sh`
  生成 `.icns` 应用图标

## 构建

```bash
cd "/Users/mini/Documents/New project/dataeyes-macos-app"
bash build-app.sh
```

生成结果：

- `build/DataEyes Installer.app`
- `build/DataEyes Installer.zip`

当前默认会生成：

- `arm64 + x86_64` 的 universal app
- 完整的 ad-hoc bundle 签名，避免 bundle 被系统判定为“已损坏”

导出 DMG：

```bash
bash build-dmg.sh
```

导出 PKG：

```bash
bash build-pkg.sh
```

带签名导出 PKG：

```bash
SIGN_PKG=1 bash build-pkg.sh
```

## 当前行为

App 启动后会：

- 让用户输入国内站 / 国际站 API Key
- 执行内置的 `内部文件/安装主程序.sh`
- 实时显示安装日志
- 安装成功后直接显示完成态
- 自动打开带令牌的本地控制台地址
- 可直接打开安装目录

控制台打开策略：

- 安装器会从 `~/.openclaw/openclaw.json` 读取当前生效的 `gateway.auth.token`
- 自动拼出 `http://localhost:18789/#token=...`
- 避免直接打开裸的 `127.0.0.1:18789` 导致 Control UI 出现 `token mismatch` / `retry later`

## 配置版本与签名

统一配置在：

- `release-config.sh`

常用变量：

- `APP_NAME`
- `APP_BUNDLE_ID`
- `APP_VERSION`
- `APP_BUILD`
- `DEVELOPER_ID_APP`
- `DEVELOPER_ID_INSTALLER`
- `KEYCHAIN_PROFILE`

## 签名与公证

先签名并公证 App：

```bash
bash sign-and-notarize.sh app
```

公证 DMG：

```bash
bash sign-and-notarize.sh dmg
```

公证 PKG：

```bash
bash sign-and-notarize.sh pkg
```

## 重要说明

这个 App 骨架解决的是“交付形态”和“用户体验”问题。

如果你把它作为正式外发安装器，仍然需要：

- Apple Developer ID 签名
- Apple notarization 公证

否则从微信、浏览器、网盘下载后，Gatekeeper 仍可能拦截。
