import AppKit
import SwiftUI

/// 每块屏幕一个置顶的纯黑窗口，显示器插拔时自动重建。
final class BlackoutController {
    private var windows: [NSWindow] = []
    private weak var controller: CleanController?
    private var screenObserver: NSObjectProtocol?

    func show(controller: CleanController) {
        self.controller = controller
        rebuildWindows()
        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in self?.rebuildWindows() }
        NSApp.activate()
        windows.first?.makeKey()
    }

    func hide() {
        if let screenObserver { NotificationCenter.default.removeObserver(screenObserver) }
        screenObserver = nil
        windows.forEach { $0.orderOut(nil) }
        windows.removeAll()
    }

    private func rebuildWindows() {
        guard let controller else { return }
        windows.forEach { $0.orderOut(nil) }
        windows = NSScreen.screens.map { screen in
            let window = BlackoutWindow(
                contentRect: screen.frame,
                styleMask: .borderless,
                backing: .buffered,
                defer: false
            )
            window.isReleasedWhenClosed = false
            window.level = .screenSaver
            window.backgroundColor = .black
            window.isOpaque = true
            window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
            window.contentView = FirstClickHostingView(rootView: BlackoutView(controller: controller))
            window.setFrame(screen.frame, display: true)
            window.orderFrontRegardless()
            return window
        }
    }
}

private final class BlackoutWindow: NSWindow {
    override var canBecomeKey: Bool { true }
}

/// 副屏上的窗口不是 key window，不开这个第一次点击只会激活窗口、按钮不响应
private final class FirstClickHostingView<Content: View>: NSHostingView<Content> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}

private struct BlackoutView: View {
    @ObservedObject var controller: CleanController

    var body: some View {
        ZStack {
            Color.black
            VStack(spacing: 24) {
                Image(systemName: "sparkles")
                    .font(.system(size: 34, weight: .medium))
                    .foregroundStyle(.white.opacity(0.85))
                VStack(spacing: 8) {
                    Text(controller.keyboardLocked ? "清洁中" : "黑屏中")
                        .font(.system(size: 26, weight: .semibold))
                        .foregroundStyle(.white)
                    Text(controller.keyboardLocked ? "键盘已锁定，所有屏幕已变黑" : "所有屏幕已变黑")
                        .font(.system(size: 15))
                        .foregroundStyle(.white.opacity(0.55))
                }
                Button(controller.keyboardLocked ? "结束清洁" : "退出黑屏") {
                    controller.stopAll()
                }
                .buttonStyle(PrimaryButtonStyle(minWidth: 240))
            }
            .padding(.horizontal, 48)
            .padding(.vertical, 40)
            .background(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(.white.opacity(0.06))
                    .overlay(
                        RoundedRectangle(cornerRadius: 28, style: .continuous)
                            .strokeBorder(.white.opacity(0.08))
                    )
            )
        }
    }
}
