# Release Notes Template

## DataEyes OpenClaw macOS Installer v{{VERSION}}

### 更新内容

- 支持国内站 / 国际站配置
- 修复 macOS 密码框粘贴问题
- 优化安装后的控制台打开逻辑，避免 token mismatch
- 强化 gateway service 覆盖逻辑，减少异常状态

### 下载说明

- `DataEyes Installer.dmg`：推荐普通用户使用
- `DataEyes Installer.zip`：适合直接分发 `.app`
- `DataEyes Installer-unsigned.pkg`：未签名安装包，适合内部测试

### 校验

请参考 `SHA256SUMS.txt` 验证下载文件完整性。

### 注意事项

- 未完成 Apple Developer ID 签名和 notarization 时，Gatekeeper 仍可能拦截
- 正式外发建议使用签名并公证后的 `.dmg` 或 `.pkg`
