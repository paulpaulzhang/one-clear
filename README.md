# One Clear

一个 macOS 菜单栏小工具：擦屏幕、擦键盘的时候，一键锁住键盘、让所有屏幕变黑，擦完点一下恢复。

A tiny macOS menu bar app that locks every keyboard and blacks out every display while you clean them.

## 功能

- **清洁模式**：锁键盘 + 所有屏幕黑屏，一个开关搞定
- **黑屏**：覆盖所有显示器（含菜单栏），屏幕保持亮着、不会自动息屏，插拔显示器自动跟随
- **锁定键盘**：内建和外接键盘全部生效，包括修饰键和亮度 / 音量 / 媒体键
- 常驻菜单栏：关闭窗口、在 Dock 里退出都只会收回菜单栏；菜单里的「完全退出」才真正退出

## 安装

从 [Releases](../../releases) 下载最新的 `OneClear-vX.Y.Z.zip`，解压后拖进「应用程序」。安装包已由 Apple 公证，可以直接打开。

首次锁键盘时，按提示在「系统设置 → 隐私与安全性 → 辅助功能」里打开 One Clear 的开关。

需要 macOS 14 或更高版本，支持 Apple 芯片和 Intel。

## 从源码构建

```bash
./build.sh            # 构建到 build/OneClear.app
./build.sh --install  # 构建并安装到 /Applications
```

默认使用临时签名，每次重新构建后都需要重新授予辅助功能权限。想避免这一点，可以新建不入库的 `.signing.env` 指定自己的证书：

```bash
SIGN_IDENTITY="Apple Development: Your Name (XXXXXXXXXX)"
```

修改应用图标：编辑 `scripts/make-icon.swift` 后运行 `swift scripts/make-icon.swift`。

## 发布

推送 `v*` 格式的 tag，GitHub Action 会自动构建、签名、公证并发布 Release：

```bash
git tag v1.0.0 && git push origin v1.0.0
```

需要在仓库 Secrets 里配置：

| Secret | 内容 |
|---|---|
| `DEVELOPER_ID_P12_BASE64` | Developer ID Application 证书（含私钥）导出的 .p12，base64 编码 |
| `DEVELOPER_ID_P12_PASSWORD` | 上面 .p12 的密码 |
| `NOTARY_API_KEY_P8_BASE64` | App Store Connect API Key（.p8），base64 编码 |
| `NOTARY_API_KEY_ID` | API Key ID |
| `NOTARY_API_ISSUER_ID` | API Issuer ID |

## License

[MIT](LICENSE)
