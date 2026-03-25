# Changelog

## 1.0.1 - 2026-03-25

- 修复 App bundle 的破损签名状态，避免 macOS 将安装器判定为“已损坏”
- 安装器改为生成 universal app，同时支持 Apple Silicon 和 Intel Mac
- 更新 DMG / ZIP / PKG 产物及对应的 SHA256 校验
- 更新发布说明，明确当前为未 notarize 构建，首次打开可能仍遇到开发者验证提示

## 1.0.0 - 2026-03-24

- 新增原生 AppKit macOS 安装器，可打包为 `.app` / `.dmg` / `.pkg`
- 支持国内站 / 国际站 API Key 配置
- 修复 macOS 安装密码输入框的粘贴问题
- 安装时强制覆盖旧的 gateway service 定义，减少 `loaded but stopped`
- 安装后自动从 `~/.openclaw/openclaw.json` 读取真实 token
- 自动打开 `http://localhost:18789/#token=...`，避免 Control UI 的 token mismatch 问题
- 补充 release 整理脚本、校验清单、发布模板和 GitHub Actions 发布流程
