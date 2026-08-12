import ServiceManagement

@MainActor
final class LaunchAtStartupController {
    enum ToggleResult {
        case updated
        case requiresApproval
    }

    private let service = SMAppService.mainApp

    var isEnabled: Bool {
        service.status == .enabled || service.status == .requiresApproval
    }

    func toggle() throws -> ToggleResult {
        if isEnabled {
            try service.unregister()
            return .updated
        }

        try service.register()
        return service.status == .requiresApproval ? .requiresApproval : .updated
    }
}
