import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusController: StatusPopoverController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApplication.shared.setActivationPolicy(.accessory)
        let repository = JSONTaskRepository()
        let model = TaskListViewModel(repository: repository)
        statusController = StatusPopoverController(model: model)
    }
}
