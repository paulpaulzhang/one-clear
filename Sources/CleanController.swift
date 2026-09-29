import AppKit
import IOKit.pwr_mgt

final class CleanController: ObservableObject {
    @Published private(set) var keyboardLocked = false
    @Published private(set) var screenBlack = false
    @Published private(set) var accessibilityGranted = AXIsProcessTrusted()
    @Published private(set) var lidAwake = false

    var onNeedsAccessibility: (() -> Void)?

    var isCleaning: Bool { keyboardLocked && screenBlack }

    init() {
        lidAwakeController.restoreIfLeftOn()
        lidAwakeController.onAutoDisabled = { [weak self] in self?.lidAwake = false }
    }

    private let keyboard = KeyboardBlocker()
    private let blackout = BlackoutController()
    private let lidAwakeController = LidAwakeController()
    private var displaySleepAssertion: IOPMAssertionID?

    func startCleaning() {
        guard setKeyboardLocked(true) else { return }
        setScreenBlack(true)
    }

    func stopAll() {
        setKeyboardLocked(false)
        setScreenBlack(false)
    }

    @discardableResult
    func setKeyboardLocked(_ locked: Bool) -> Bool {
        if locked {
            refreshAccessibility()
            guard accessibilityGranted, keyboard.start() else {
                requestAccessibility()
                return false
            }
        } else {
            keyboard.stop()
        }
        keyboardLocked = locked
        return true
    }

    func setScreenBlack(_ black: Bool) {
        guard black != screenBlack else { return }
        if black {
            blackout.show(controller: self)
            preventDisplaySleep()
        } else {
            blackout.hide()
            allowDisplaySleep()
        }
        screenBlack = black
    }

    func setLidAwake(_ on: Bool) {
        if on {
            lidAwakeController.enable { [weak self] ok in self?.lidAwake = ok }
        } else {
            lidAwakeController.disable()
            lidAwake = false
        }
    }

    /// 真正退出进程时调用：清洁 + 合盖不休眠一起关，后者是系统级设置，不关会一直生效
    func shutdown() {
        stopAll()
        setLidAwake(false)
    }

    func refreshAccessibility() {
        let granted = AXIsProcessTrusted()
        if granted != accessibilityGranted { accessibilityGranted = granted }
    }

    /// 只在用户主动要锁键盘时调用：系统弹窗会顺带把本 App 加进「辅助功能」列表
    func requestAccessibility() {
        _ = AXIsProcessTrustedWithOptions([kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary)
        onNeedsAccessibility?()
    }

    private func preventDisplaySleep() {
        var id = IOPMAssertionID(0)
        let result = IOPMAssertionCreateWithName(
            kIOPMAssertPreventUserIdleDisplaySleep as CFString,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            "One Clear 清洁中" as CFString,
            &id
        )
        if result == kIOReturnSuccess { displaySleepAssertion = id }
    }

    private func allowDisplaySleep() {
        if let id = displaySleepAssertion { IOPMAssertionRelease(id) }
        displaySleepAssertion = nil
    }
}
