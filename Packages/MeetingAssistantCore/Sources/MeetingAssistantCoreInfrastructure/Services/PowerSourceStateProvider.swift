import Foundation
import IOKit.ps

public enum PowerSourceState: String, Sendable, Equatable {
    case charging
    case battery
}

public protocol PowerSourceStateProviding: Sendable {
    func currentPowerSourceState() -> PowerSourceState
}

public struct PowerSourceStateProvider: PowerSourceStateProviding {
    public init() {}

    public func currentPowerSourceState() -> PowerSourceState {
        guard let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(snapshot)?.takeRetainedValue() as? [CFTypeRef]
        else {
            return .charging
        }

        for source in sources {
            guard let description = IOPSGetPowerSourceDescription(snapshot, source)?.takeUnretainedValue() as? [String: Any],
                  let state = description[kIOPSPowerSourceStateKey as String] as? String
            else {
                continue
            }

            if state == kIOPSBatteryPowerValue {
                return .battery
            }
            if state == kIOPSACPowerValue {
                return .charging
            }
        }

        return .charging
    }
}
