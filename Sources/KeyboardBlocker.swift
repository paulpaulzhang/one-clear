import AppKit

/// 全局事件拦截：吞掉所有键盘（内建 + 外接）的按键、修饰键和亮度/音量/媒体键。
final class KeyboardBlocker {
    private var tap: CFMachPort?
    private var source: CFRunLoopSource?

    func start() -> Bool {
        if tap != nil { return true }
        let mask: CGEventMask = (1 << CGEventType.keyDown.rawValue)
            | (1 << CGEventType.keyUp.rawValue)
            | (1 << CGEventType.flagsChanged.rawValue)
            | (1 << systemDefinedEventType)
        guard let newTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: keyboardTapCallback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else { return false }

        let newSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, newTap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), newSource, .commonModes)
        CGEvent.tapEnable(tap: newTap, enable: true)
        tap = newTap
        source = newSource
        return true
    }

    func stop() {
        guard let tap else { return }
        CGEvent.tapEnable(tap: tap, enable: false)
        if let source { CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes) }
        CFMachPortInvalidate(tap)
        self.tap = nil
        source = nil
    }

    fileprivate func reenable() {
        if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
    }
}

// NX_SYSDEFINED，其中 subtype 8 是亮度/音量/媒体键
private let systemDefinedEventType: UInt32 = 14
private let auxControlButtonsSubtype: Int16 = 8

private func keyboardTapCallback(
    proxy: CGEventTapProxy,
    type: CGEventType,
    event: CGEvent,
    userInfo: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    switch type {
    case .tapDisabledByTimeout, .tapDisabledByUserInput:
        // 系统会在回调超时后自动停用 tap，不重新启用键盘就会悄悄恢复
        if let userInfo {
            Unmanaged<KeyboardBlocker>.fromOpaque(userInfo).takeUnretainedValue().reenable()
        }
        return Unmanaged.passUnretained(event)
    case .keyDown, .keyUp, .flagsChanged:
        return nil
    default:
        if type.rawValue == systemDefinedEventType,
           NSEvent(cgEvent: event)?.subtype.rawValue == auxControlButtonsSubtype {
            return nil
        }
        return Unmanaged.passUnretained(event)
    }
}
