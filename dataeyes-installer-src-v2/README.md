# DataEyes × OpenClaw 安装包

## 当前版本特点

- 双击 `双击开始安装.command`
- 支持同时输入国内站 / 国际站 API Key
- 全程只写入当前用户目录
- 不申请管理员权限
- 不修改 shell 配置
- 不修改全局 npm 配置

安装器会自动完成：
- 安装或复用 Node.js 22
- 安装 OpenClaw 到 `~/.dataeyes-openclaw`
- 写入 DataEyes 配置
- 启动 Gateway
- 打开带令牌的本机控制台

## GitHub 安装方式

如果你把这个目录放到 GitHub 仓库根目录，也可以让用户直接在终端执行：

```bash
curl -fsSL https://raw.githubusercontent.com/YOUR_ORG/YOUR_REPO/main/install.sh | bash
```

或者：

```bash
git clone https://github.com/YOUR_ORG/YOUR_REPO.git
cd YOUR_REPO
bash install.sh
```

说明：
- `install.sh` 会自动拉取仓库并执行 `内部文件/安装主程序.sh`
- 这种方式比双击脚本更适合未签名阶段的分发
- 终端执行仍然属于“用户主动运行脚本”，所以要在 README 里把来源和用途写清楚

## 安装完成后

控制台会自动打开到：
- `http://localhost:18789/#token=...`

说明：
- 安装器会从 `~/.openclaw/openclaw.json` 读取当前 `gateway.auth.token`
- 再拼出带令牌的本地控制台地址
- 这样可以避开直接访问裸地址时常见的 `gateway token mismatch` / `retry later`

运行目录：
- `~/.dataeyes-openclaw`

默认模型：
- 主模型：`dataeyes/gpt-5.4`
- 自动回退：`dataeyes/gemini-3.1-pro-preview-customtools`
- 自动回退：`dataeyes/claude-opus-4-6`

## 交付说明

这个安装包已经去掉了管理员密码和系统级写入。

如果用户是从微信、浏览器或网盘下载后直接打开，macOS 仍然可能提示“无法验证”或“已阻止打开”。这个不是脚本逻辑导致的，而是 Gatekeeper 对未签名脚本的拦截。

要做到真正可交付、用户不需要去“系统设置 > 隐私与安全性 > 仍要打开”，需要把最终交付物做成已签名并已公证的 `.app` 或 `.pkg`。

详细交付建议见：
- `DELIVERY.md`
