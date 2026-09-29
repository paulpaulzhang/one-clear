import Foundation
import IOKit.ps

/// 合盖不休眠：合盖睡眠挡不住 IOPM 断言，只能用 `pmset disablesleep` 关掉整个系统睡眠。
/// pmset 要 root：首次开启输一次管理员密码，装一条只放行这两条命令的 sudoers 规则，之后开关都不用密码。
/// 这个开关是系统级的、App 退出后仍然生效，所以退出时必须关掉，崩溃遗留的下次启动时关掉。
final class LidAwakeController {
    private static let pmset = "/usr/bin/pmset"
    private static let sudoersPath = "/etc/sudoers.d/oneclear"
    private static let leftOnKey = "lidAwakeLeftOn"
    /// 用电池且电量不高于这个值时自动关闭，让 Mac 能正常睡眠，别在包里耗到关机
    static let lowBatteryPercent = 10

    private(set) var isOn = false
    var onAutoDisabled: (() -> Void)?
    private var batteryTimer: Timer?
    private var enabling = false

    /// 首次要等用户输密码，放后台做，主线程卡住会让菜单收不起来、密码框接不到键盘输入。
    /// completion 在主线程回调；用户取消密码框或规则装不上时传 false
    func enable(completion: @escaping (Bool) -> Void) {
        guard !isOn else { return completion(true) }
        guard !enabling else { return }
        enabling = true
        DispatchQueue.global(qos: .userInitiated).async { [self] in
            let ok = setSleepDisabled(true) || (installSudoersRule() && setSleepDisabled(true))
            DispatchQueue.main.async { [self] in
                enabling = false
                if ok {
                    isOn = true
                    UserDefaults.standard.set(true, forKey: Self.leftOnKey)
                    startBatteryWatch()
                }
                completion(ok)
            }
        }
    }

    func disable() {
        guard isOn else { return }
        setSleepDisabled(false)
        isOn = false
        UserDefaults.standard.removeObject(forKey: Self.leftOnKey)
        stopBatteryWatch()
    }

    /// 上次没正常关（崩溃 / 强退 / 断电），系统还停在不睡眠状态
    func restoreIfLeftOn() {
        guard UserDefaults.standard.bool(forKey: Self.leftOnKey) else { return }
        if isSleepDisabledBySystem() { setSleepDisabled(false) }
        UserDefaults.standard.removeObject(forKey: Self.leftOnKey)
    }

    // MARK: - pmset

    @discardableResult
    private func setSleepDisabled(_ disabled: Bool) -> Bool {
        run("/usr/bin/sudo", ["-n", Self.pmset, "-a", "disablesleep", disabled ? "1" : "0"]).status == 0
    }

    private func isSleepDisabledBySystem() -> Bool {
        run(Self.pmset, ["-g"]).output
            .split(separator: "\n")
            .contains { $0.split(whereSeparator: \.isWhitespace) == ["SleepDisabled", "1"] }
    }

    private func run(_ path: String, _ args: [String]) -> (status: Int32, output: String) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = args
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        do { try process.run() } catch { return (-1, "") }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return (process.terminationStatus, String(decoding: data, as: UTF8.self))
    }

    /// 弹系统管理员密码框，写入 sudoers 规则；visudo 校验不过就不装，避免把 sudo 整个弄坏
    private func installSudoersRule() -> Bool {
        let user = NSUserName()
        guard user.range(of: "^[A-Za-z0-9_.-]+$", options: .regularExpression) != nil else { return false }
        let rule = "\(user) ALL=(root) NOPASSWD: \(Self.pmset) -a disablesleep 0, \(Self.pmset) -a disablesleep 1"
        let script = [
            "tmp=$(/usr/bin/mktemp)",
            "printf '%s\\\\n' '\(rule)' > $tmp",
            "/usr/sbin/visudo -cf $tmp",
            "/usr/sbin/chown root:wheel $tmp",
            "/bin/chmod 0440 $tmp",
            "/bin/mkdir -p /etc/sudoers.d",
            "/bin/mv $tmp \(Self.sudoersPath)",
        ].joined(separator: " && ")
        let source = """
        do shell script "\(script)" with prompt "One Clear 需要管理员权限来开启「合盖不休眠」（只需授权一次）" with administrator privileges
        """
        return run("/usr/bin/osascript", ["-e", source]).status == 0
    }

    // MARK: - 低电量保护

    private func startBatteryWatch() {
        batteryTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            self?.checkBattery()
        }
        checkBattery()
    }

    private func stopBatteryWatch() {
        batteryTimer?.invalidate()
        batteryTimer = nil
    }

    private func checkBattery() {
        guard let percent = batteryPercentIfDischarging(), percent <= Self.lowBatteryPercent else { return }
        disable()
        onAutoDisabled?()
    }

    private func batteryPercentIfDischarging() -> Int? {
        let info = IOPSCopyPowerSourcesInfo().takeRetainedValue()
        let sources = IOPSCopyPowerSourcesList(info).takeRetainedValue() as [CFTypeRef]
        for source in sources {
            guard let desc = IOPSGetPowerSourceDescription(info, source)?.takeUnretainedValue() as? [String: Any],
                  desc[kIOPSTypeKey] as? String == kIOPSInternalBatteryType,
                  desc[kIOPSPowerSourceStateKey] as? String == kIOPSBatteryPowerValue,
                  let current = desc[kIOPSCurrentCapacityKey] as? Int,
                  let max = desc[kIOPSMaxCapacityKey] as? Int, max > 0
            else { continue }
            return current * 100 / max
        }
        return nil
    }
}
