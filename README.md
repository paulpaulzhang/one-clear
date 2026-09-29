# One Clear

一个 macOS 菜单栏小工具：擦屏幕、擦键盘的时候，一键锁住键盘、让所有屏幕变黑，擦完点一下恢复。

A tiny macOS menu bar app that locks every keyboard and blacks out every display while you clean them.

## 功能

- **清洁模式**：锁键盘 + 所有屏幕黑屏，一个开关搞定
- **黑屏**：覆盖所有显示器（含菜单栏），屏幕保持亮着、不会自动息屏，插拔显示器自动跟随
- **锁定键盘**：内建和外接键盘全部生效，包括修饰键和亮度 / 音量 / 媒体键
- **合盖不休眠**：带电脑出门时合上盖子也不睡眠、保持联网（比如连手机热点远程操作）。首次开启输一次管理员密码，会在 `/etc/sudoers.d/oneclear` 装一条只放行 `pmset -a disablesleep 0/1` 的规则，之后开关不再要密码；完全退出 App 时自动恢复，电池电量降到 10% 也会自动关闭。不再需要时运行 `sudo rm /etc/sudoers.d/oneclear` 删除这条规则
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

## License

[MIT](LICENSE)
