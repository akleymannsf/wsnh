import Foundation
import ServiceManagement

/// Registers/unregisters WSNH as a login item using SMAppService
/// (macOS 13+). Only works correctly once WSNH is running from a
/// proper .app bundle (see build.sh), not a bare executable.
enum LaunchAtLogin {
    static var isEnabled: Bool {
        get { SMAppService.mainApp.status == .enabled }
        set {
            do {
                if newValue {
                    if SMAppService.mainApp.status != .enabled {
                        try SMAppService.mainApp.register()
                    }
                } else {
                    if SMAppService.mainApp.status == .enabled {
                        try SMAppService.mainApp.unregister()
                    }
                }
            } catch {
                print("LaunchAtLogin error: \(error)")
            }
        }
    }
}
