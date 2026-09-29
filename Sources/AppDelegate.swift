import AppKit
import SwiftUI

/// 菜单栏常驻：主窗口打开时出现在 Dock，关窗 / Dock 退出 / ⌘Q 都只收回菜单栏，
/// 只有菜单栏里的「完全退出」或关机注销才真正结束进程。
final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private let controller = CleanController()
    private var statusItem: NSStatusItem?
    private var mainWindow: NSWindow?
    private var quitRequested = false
    private var accessibilityPoll: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        buildMainMenu()
        setupStatusItem()
        controller.onNeedsAccessibility = { [weak self] in self?.showMainWindow() }
        showMainWindow()
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showMainWindow()
        return false
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        if quitRequested || isSystemSessionEnding() {
            controller.shutdown()
            return .terminateNow
        }
        mainWindow?.close()
        hideFromDock()
        return .terminateCancel
    }

    // 关机 / 重启 / 注销发来的 quit 事件带 kAEQuitReason，Dock「退出」和 ⌘Q 不带
    private func isSystemSessionEnding() -> Bool {
        NSAppleEventManager.shared().currentAppleEvent?
            .attributeDescriptor(forKeyword: AEKeyword(kAEQuitReason)) != nil
    }

    // MARK: - 主窗口

    private func showMainWindow() {
        if mainWindow == nil {
            let window = NSWindow(contentViewController: NSHostingController(rootView: MainView(controller: controller)))
            window.styleMask = [.titled, .closable, .miniaturizable, .fullSizeContentView]
            window.titlebarAppearsTransparent = true
            window.titleVisibility = .hidden
            window.isMovableByWindowBackground = true
            window.isReleasedWhenClosed = false
            window.delegate = self
            window.center()
            mainWindow = window
        }
        NSApp.setActivationPolicy(.regular)
        NSApp.activate()
        mainWindow?.makeKeyAndOrderFront(nil)
        startAccessibilityPolling()
    }

    func windowWillClose(_ notification: Notification) {
        guard (notification.object as? NSWindow) === mainWindow else { return }
        hideFromDock()
    }

    private func hideFromDock() {
        stopAccessibilityPolling()
        NSApp.setActivationPolicy(.accessory)
    }

    // 用户去系统设置打开权限后，窗口里的状态要自己刷新
    private func startAccessibilityPolling() {
        controller.refreshAccessibility()
        guard accessibilityPoll == nil else { return }
        accessibilityPoll = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            self?.controller.refreshAccessibility()
        }
    }

    private func stopAccessibilityPolling() {
        accessibilityPoll?.invalidate()
        accessibilityPoll = nil
    }

    private func buildMainMenu() {
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "关于 One Clear", action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), keyEquivalent: "")
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "关闭窗口", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        appMenu.addItem(withTitle: "收起到菜单栏", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        let quitItem = appMenu.addItem(withTitle: "完全退出 One Clear", action: #selector(quitCompletely), keyEquivalent: "")
        quitItem.target = self

        let appMenuItem = NSMenuItem()
        appMenuItem.submenu = appMenu
        let mainMenu = NSMenu()
        mainMenu.addItem(appMenuItem)
        NSApp.mainMenu = mainMenu
    }

    // MARK: - 菜单栏

    private func setupStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let url = Bundle.main.url(forResource: "StatusIcon", withExtension: "svg"),
           let icon = NSImage(contentsOf: url) {
            icon.size = NSSize(width: 18, height: 18)
            icon.isTemplate = true
            item.button?.image = icon
        }
        item.button?.toolTip = "One Clear"

        let togglesView = NSHostingView(rootView: MenuTogglesView(
            controller: controller,
            setCleaning: { [weak self] on in
                self?.runFromMenu(closeMenu: on) { on ? $0.startCleaning() : $0.stopAll() }
            },
            setScreenBlack: { [weak self] on in
                self?.runFromMenu(closeMenu: on) { $0.setScreenBlack(on) }
            },
            setKeyboardLocked: { [weak self] on in
                self?.runFromMenu(closeMenu: on && !AXIsProcessTrusted()) { $0.setKeyboardLocked(on) }
            },
            setLidAwake: { [weak self] on in
                // 首次开启会弹管理员密码框，先收起菜单
                self?.runFromMenu(closeMenu: on) { $0.setLidAwake(on) }
            }
        ))
        togglesView.frame = NSRect(origin: .zero, size: togglesView.fittingSize)
        let togglesItem = NSMenuItem()
        togglesItem.view = togglesView

        let menu = NSMenu()
        menu.addItem(togglesItem)
        menu.addItem(.separator())
        let openItem = menu.addItem(withTitle: "打开 One Clear 窗口", action: #selector(openMainWindow), keyEquivalent: "")
        openItem.target = self
        let quitItem = menu.addItem(withTitle: "完全退出 One Clear", action: #selector(quitCompletely), keyEquivalent: "")
        quitItem.target = self
        item.menu = menu
        statusItem = item
    }

    /// 黑屏会盖住菜单栏、没权限要弹主窗口，这两种情况先收起菜单再执行
    private func runFromMenu(closeMenu: Bool, _ action: @escaping (CleanController) -> Void) {
        if closeMenu { statusItem?.menu?.cancelTracking() }
        DispatchQueue.main.async { [controller] in action(controller) }
    }

    @objc private func openMainWindow() {
        showMainWindow()
    }

    @objc private func quitCompletely() {
        quitRequested = true
        NSApp.terminate(nil)
    }
}
