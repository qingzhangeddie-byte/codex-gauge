import Foundation

struct CodexGaugePowerPolicy {
    let normalRefreshInterval: TimeInterval = 5 * 60
    let watchRefreshInterval: TimeInterval = 3 * 60
    let criticalRefreshInterval: TimeInterval = 2 * 60
    let failureRefreshInterval: TimeInterval = 60
    let powerSaverHealthyRefreshInterval: TimeInterval = 20 * 60
    let powerSaverLowRefreshInterval: TimeInterval = 10 * 60
    let powerSaverCriticalRefreshInterval: TimeInterval = 5 * 60
    let lowBatteryPowerSaverRefreshInterval: TimeInterval = 30 * 60
    let criticalBatteryPowerSaverRefreshInterval: TimeInterval = 60 * 60

    func hardwareSignalsVisible(powerSaverActive: Bool) -> Bool {
        !powerSaverActive
    }

    func batteryPowerSaverRefreshInterval(percent: Int?) -> TimeInterval? {
        guard let percent else {
            return nil
        }
        if percent <= 20 {
            return criticalBatteryPowerSaverRefreshInterval
        }
        if percent <= 35 {
            return lowBatteryPowerSaverRefreshInterval
        }
        return nil
    }

    func powerSaverRefreshInterval(statusOK: Bool, fiveHourLeft: Int?, sevenDayLeft: Int?, batteryPercent: Int?) -> TimeInterval {
        if let batteryInterval = batteryPowerSaverRefreshInterval(percent: batteryPercent) {
            return batteryInterval
        }
        guard statusOK else {
            return powerSaverCriticalRefreshInterval
        }
        guard let lowest = minQuota(fiveHourLeft, sevenDayLeft) else {
            return powerSaverCriticalRefreshInterval
        }
        if lowest < 10 {
            return powerSaverCriticalRefreshInterval
        }
        if lowest <= 40 {
            return powerSaverLowRefreshInterval
        }
        return powerSaverHealthyRefreshInterval
    }

    func nextRefreshInterval(
        powerSaverActive: Bool,
        fixedRefreshInterval: TimeInterval?,
        statusOK: Bool,
        fiveHourLeft: Int?,
        sevenDayLeft: Int?,
        batteryPercent: Int?
    ) -> TimeInterval {
        if powerSaverActive {
            return powerSaverRefreshInterval(
                statusOK: statusOK,
                fiveHourLeft: fiveHourLeft,
                sevenDayLeft: sevenDayLeft,
                batteryPercent: batteryPercent
            )
        }
        guard statusOK else {
            return failureRefreshInterval
        }
        if let fixedRefreshInterval {
            return fixedRefreshInterval
        }
        guard let lowest = minQuota(fiveHourLeft, sevenDayLeft) else {
            return failureRefreshInterval
        }
        if lowest < 10 {
            return criticalRefreshInterval
        }
        if lowest <= 40 {
            return watchRefreshInterval
        }
        return normalRefreshInterval
    }

    private func minQuota(_ first: Int?, _ second: Int?) -> Int? {
        [first, second].compactMap { $0 }.min()
    }
}
