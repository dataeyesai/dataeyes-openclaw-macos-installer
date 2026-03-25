# Changelog

## 1.0.5 - 2026-03-25

- 修复重复安装或覆盖安装时 `npm ERR! code ENOTEMPTY` 导致 OpenClaw 安装失败的问题
- 安装 OpenClaw 前会先清理旧的用户目录安装残留
- 如果 npm 首次安装仍遇到目录替换冲突，会自动执行一次清理后重试

## 1.0.4 - 2026-03-25

- 安装前新增 API Key 验证，确认 key 可用且模型接口能够正常返回
- 点击“开始安装”前会自动先做一次 Key 校验，避免错误 key 直接写进配置
- 新增“打开配置文件”按钮，可直接打开 `~/.openclaw/openclaw.json`
- 优化按钮布局，安装、验证、刷新和打开入口更清晰

## 1.0.3 - 2026-03-25

- 优化安装界面，新增当前步骤提示和 4 步进度条
- 清理安装日志中的 ANSI 控制字符，避免日志区出现 `\u001b[0;34m` 这类乱码
- 安装进行中增加心跳状态显示，减少“白色日志区像卡住”的观感
- 安装完成后新增“刷新模型”按钮，可在图形界面内重新同步模型列表
- 补强日志收尾读取，减少子进程结束瞬间最后几行日志丢失

## 1.0.2 - 2026-03-25

- 安装时优先根据填写的 API Key 动态拉取该账号真实可用的模型列表
- 注入后的可用模型会写入 `~/.openclaw/openclaw.json`，可在 OpenClaw 内切换
- 新增 `~/.dataeyes-openclaw/bin/dataeyes-refresh-models`，用户更换 API Key 后可刷新模型列表
- `/models` 拉取失败时会优先复用现有配置中的模型，避免回退成固定模板导致分组模型丢失
- 兼容更多模型接口返回格式，包括 `data`、`models`、`items`、`results`

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
