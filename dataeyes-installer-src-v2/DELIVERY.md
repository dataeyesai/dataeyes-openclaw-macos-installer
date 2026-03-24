# DataEyes 安装包交付建议

## 结论

如果最终交付物还是一个从互联网下载的 `.command` 或 `.zip` 脚本包，macOS 很大概率仍会触发 Gatekeeper。

脚本可以优化掉：
- 管理员密码
- 修改系统目录
- 修改 shell 配置

但是脚本本身不能消掉：
- 第一次打开时的“无法验证”
- 用户去系统设置点“仍要打开”

这两个问题，必须靠 Apple Developer ID 签名和公证解决。

## 推荐交付形态

推荐优先级：

1. 签名并公证后的 `.app`
2. 签名并公证后的 `.pkg`
3. 不推荐继续直接交付 `.command` + `.zip`

## 最小可交付方案

如果你想先快速交付一个明显更顺的版本，当前目录里的脚本已经做到：
- 零管理员权限
- 零系统目录写入
- 零 shell 配置改动

这种版本可以先给内测、私域分发、熟人试用。

## 正式商用方案

你需要准备：
- Apple Developer Program 账号
- Developer ID Application 证书
- Developer ID Installer 证书（如果走 `.pkg`）
- `notarytool` 公证环境

## 建议实施路径

### 路线 A：做成 `.app`

适合：
- 想让用户双击启动
- 需要更像正式产品
- 希望后续加图形界面

建议做法：
- 用一个轻量 macOS 启动器 App 包装现有安装流程
- App 内部调用安装脚本
- 所有运行时继续写入 `~/.dataeyes-openclaw`
- 对 `.app` 做 `codesign`
- 上传 Apple notarization
- 对公证通过的 App 做 stapler

### 路线 B：做成 `.pkg`

适合：
- 只想交付安装流程
- 更接近传统安装器体验
- 不准备马上做图形界面

建议做法：
- 用 `pkgbuild` / `productbuild` 制作签名安装包
- 安装内容只落到用户目录或固定 App 目录
- 对 `.pkg` 做公证

## 为什么现在会弹“仍要打开”

因为 macOS 会给来自微信、浏览器、网盘的下载文件打上 quarantine 标记。

未签名脚本即使没有恶意行为，也会被 Gatekeeper 拦截。

## 这版脚本已经优化了什么

- Node.js 安装到 `~/.dataeyes-openclaw/node`
- OpenClaw 安装到 `~/.dataeyes-openclaw/npm`
- 不写 `/usr/local`
- 不调用 `sudo`
- 不调用 `osascript ... with administrator privileges`
- 不写 `~/.zshrc` / `~/.bash_profile`
- 不修改全局 npm registry

## 下一步建议

如果你要我继续做，我建议直接做下面两件事中的一个：

1. 我继续把它包装成一个可签名的 macOS `.app` 启动器骨架
2. 我继续给你做一个 `.pkg` 打包脚本和签名/公证流水线说明
