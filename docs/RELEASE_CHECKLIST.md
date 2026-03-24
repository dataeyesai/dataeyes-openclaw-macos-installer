# Release Checklist

## 发版前

- 确认 `dataeyes-macos-app/release-config.sh` 中的 `APP_VERSION` 和 `APP_BUILD` 已更新
- 确认 `CHANGELOG.md` 已补充本次变更
- 确认 `README.md` 中的说明仍与当前产物一致
- 确认 `dataeyes-macos-app/release-config.sh` 中的签名变量没有误填占位符

## 生成产物

```bash
BUILD_ARTIFACTS=1 bash scripts/prepare-release.sh
```

检查以下文件是否已更新：

- `artifacts/DataEyes Installer.zip`
- `artifacts/DataEyes Installer.dmg`
- `artifacts/DataEyes Installer-unsigned.pkg`
- `artifacts/SHA256SUMS.txt`
- `artifacts/RELEASE_MANIFEST.md`

## 验证

- 本地打开 `.dmg`，确认 App 能正常拖入或启动
- 本地双击 `.app`，确认安装界面可正常打开
- 完整跑一遍安装，确认日志、完成态和打开控制台逻辑正常
- 如涉及签名公证，执行 `spctl` / `stapler` 检查

## 发布

- 提交本次 release 相关文件
- 推送到 `main`
- 打 tag，例如 `v1.0.0`
- 推送分支和 tag
- 创建 GitHub Release 并上传安装包、校验文件
- 在 GitHub Release 页面补充对外说明、截图和注意事项
- 确认下载附件、校验和版本号一致后再正式发布
