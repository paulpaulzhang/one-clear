import AppKit
import SwiftUI

let brandBlue = Color(red: 0.2, green: 0.5, blue: 1.0)

struct PrimaryButtonStyle: ButtonStyle {
    var minWidth: CGFloat = 0

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 17, weight: .semibold))
            .foregroundStyle(.white)
            .frame(minWidth: minWidth)
            .padding(.vertical, 14)
            .padding(.horizontal, 32)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(brandBlue.opacity(configuration.isPressed ? 0.75 : 1))
            )
            .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

/// 菜单栏菜单顶部的开关区，嵌在 NSMenuItem.view 里
struct MenuTogglesView: View {
    @ObservedObject var controller: CleanController
    let setCleaning: (Bool) -> Void
    let setScreenBlack: (Bool) -> Void
    let setKeyboardLocked: (Bool) -> Void

    var body: some View {
        VStack(spacing: 4) {
            row("清洁模式", subtitle: "锁键盘 + 所有屏幕黑屏", icon: "sparkles",
                isOn: controller.isCleaning, set: setCleaning)
            Divider().padding(.vertical, 4)
            row("黑屏", subtitle: nil, icon: "display",
                isOn: controller.screenBlack, set: setScreenBlack)
            row("锁定键盘", subtitle: nil, icon: "keyboard",
                isOn: controller.keyboardLocked, set: setKeyboardLocked)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .frame(width: 260)
    }

    private func row(_ title: String, subtitle: String?, icon: String, isOn: Bool, set: @escaping (Bool) -> Void) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(isOn ? .white : .primary)
                .frame(width: 26, height: 26)
                .background(Circle().fill(isOn ? brandBlue : Color.primary.opacity(0.1)))
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(.system(size: 13, weight: .medium))
                if let subtitle {
                    Text(subtitle).font(.system(size: 11)).foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 8)
            Toggle("", isOn: Binding(get: { isOn }, set: set))
                .toggleStyle(.switch)
                .controlSize(.small)
                .labelsHidden()
        }
        .padding(.vertical, 3)
    }
}

struct MainView: View {
    @ObservedObject var controller: CleanController

    var body: some View {
        VStack(spacing: 20) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 80, height: 80)
            VStack(spacing: 6) {
                Text("One Clear")
                    .font(.system(size: 24, weight: .bold))
                Text("擦屏幕、擦键盘时用：锁住键盘，所有屏幕变黑")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }
            permissionRow
            Button("开始清洁", action: controller.startCleaning)
                .buttonStyle(PrimaryButtonStyle(minWidth: 280))
            Text("关闭窗口后 One Clear 会留在顶部菜单栏，随时点图标使用")
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 36)
        .padding(.top, 36)
        .padding(.bottom, 28)
        .frame(width: 440)
    }

    private var permissionRow: some View {
        let granted = controller.accessibilityGranted
        return HStack(spacing: 10) {
            Image(systemName: granted ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .foregroundStyle(granted ? .green : .orange)
            Text(granted ? "辅助功能权限已开启" : "锁键盘需要「辅助功能」权限")
                .font(.system(size: 13))
            Spacer()
            if !granted {
                Button("去开启", action: controller.requestAccessibility)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.primary.opacity(0.05))
        )
    }
}
