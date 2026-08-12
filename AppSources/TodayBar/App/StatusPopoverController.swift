import AppKit
import ServiceManagement
import SwiftUI

private final class TodayPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

@MainActor
final class StatusPopoverController: NSObject {
    private let panelSize = NSSize(width: 420, height: 590)
    private let statusItem: NSStatusItem
    private let panel: TodayPanel
    private let launchAtStartupController = LaunchAtStartupController()
    private var trackingArea: NSTrackingArea?
    private var closeWorkItem: DispatchWorkItem?
    private var outsideClickMonitor: Any?
    private var isPointerInsidePanel = false
    private var isPinned = false

    init(model: TaskListViewModel) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        panel = TodayPanel(
            contentRect: NSRect(origin: .zero, size: panelSize),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        super.init()

        configureStatusItem()
        configurePanel(model: model)
    }

    deinit {
        if let outsideClickMonitor {
            NSEvent.removeMonitor(outsideClickMonitor)
        }
    }

    private func configureStatusItem() {
        guard let button = statusItem.button else { return }
        button.image = NSImage(systemSymbolName: "checkmark.circle", accessibilityDescription: "Today — список дел")
        button.imagePosition = .imageOnly
        button.target = self
        button.action = #selector(statusItemPressed)
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])

        let tracking = NSTrackingArea(
            rect: .zero,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        button.addTrackingArea(tracking)
        trackingArea = tracking
    }

    private func configurePanel(model: TaskListViewModel) {
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.level = .popUpMenu
        panel.collectionBehavior = [.transient, .moveToActiveSpace, .fullScreenAuxiliary]
        panel.animationBehavior = .utilityWindow
        panel.hidesOnDeactivate = false

        let hostingController = NSHostingController(
            rootView: RootView(model: model) { [weak self] isInside in
                self?.panelHoverChanged(isInside)
            }
        )
        panel.contentViewController = hostingController

        let contentView = hostingController.view
        contentView.wantsLayer = true
        contentView.layer?.cornerRadius = 34
        contentView.layer?.cornerCurve = .continuous
        contentView.layer?.masksToBounds = true
    }

    @objc private func statusItemPressed() {
        if NSApp.currentEvent?.type == .rightMouseUp {
            showContextMenu()
        } else {
            togglePanel()
        }
    }

    private func togglePanel() {
        if panel.isVisible {
            if isPinned {
                isPinned = false
                closePanel()
            } else {
                isPinned = true
                cancelScheduledClose()
            }
        } else {
            isPinned = true
            showPanel()
        }
    }

    private func showContextMenu() {
        isPinned = false
        closePanel()

        let menu = NSMenu()

        let launchAtStartupItem = NSMenuItem(
            title: "Launch at Startup",
            action: #selector(toggleLaunchAtStartup),
            keyEquivalent: ""
        )
        launchAtStartupItem.target = self
        launchAtStartupItem.state = launchAtStartupController.isEnabled ? .on : .off
        menu.addItem(launchAtStartupItem)
        menu.addItem(.separator())

        let quitItem = NSMenuItem(
            title: "Завершить Today",
            action: #selector(quitApplication),
            keyEquivalent: "q"
        )
        quitItem.target = self
        quitItem.image = NSImage(systemSymbolName: "power", accessibilityDescription: nil)
        menu.addItem(quitItem)

        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }

    @objc private func quitApplication() {
        NSApplication.shared.terminate(nil)
    }

    @objc private func toggleLaunchAtStartup() {
        do {
            if try launchAtStartupController.toggle() == .requiresApproval {
                SMAppService.openSystemSettingsLoginItems()
            }
        } catch {
            let alert = NSAlert()
            alert.alertStyle = .warning
            alert.messageText = "Не удалось изменить автозапуск"
            alert.informativeText = error.localizedDescription
            alert.addButton(withTitle: "OK")
            alert.runModal()
        }
    }

    @objc func mouseEntered(with event: NSEvent) {
        showPanel()
    }

    @objc func mouseExited(with event: NSEvent) {
        scheduleClose()
    }

    private func showPanel() {
        cancelScheduledClose()
        guard !panel.isVisible else { return }

        positionPanel()
        panel.alphaValue = 0
        panel.makeKeyAndOrderFront(nil)
        installOutsideClickMonitor()

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.14
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel.animator().alphaValue = 1
        }
    }

    private func positionPanel() {
        guard let button = statusItem.button, let statusWindow = button.window else { return }
        let buttonRectInWindow = button.convert(button.bounds, to: nil)
        let buttonFrame = statusWindow.convertToScreen(buttonRectInWindow)
        let screenFrame = statusWindow.screen?.visibleFrame ?? NSScreen.main?.visibleFrame ?? .zero

        var origin = NSPoint(
            x: buttonFrame.midX - panelSize.width / 2,
            y: buttonFrame.minY - panelSize.height - 8
        )
        origin.x = min(max(origin.x, screenFrame.minX + 8), screenFrame.maxX - panelSize.width - 8)
        origin.y = max(origin.y, screenFrame.minY + 8)
        panel.setFrame(NSRect(origin: origin, size: panelSize), display: true)
    }

    private func panelHoverChanged(_ isInside: Bool) {
        isPointerInsidePanel = isInside
        isInside ? cancelScheduledClose() : scheduleClose()
    }

    private func scheduleClose() {
        cancelScheduledClose()
        let workItem = DispatchWorkItem { [weak self] in
            guard let self, !self.isPinned, !self.isPointerInsidePanel, !self.isPointerOverStatusButton else { return }
            self.closePanel()
        }
        closeWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45, execute: workItem)
    }

    private func cancelScheduledClose() {
        closeWorkItem?.cancel()
        closeWorkItem = nil
    }

    private var isPointerOverStatusButton: Bool {
        guard let button = statusItem.button, let window = button.window else { return false }
        let frameInWindow = button.convert(button.bounds, to: nil)
        return window.convertToScreen(frameInWindow).contains(NSEvent.mouseLocation)
    }

    private func installOutsideClickMonitor() {
        guard outsideClickMonitor == nil else { return }
        outsideClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            Task { @MainActor in
                guard let self,
                      self.panel.isVisible,
                      !self.panel.frame.contains(NSEvent.mouseLocation),
                      !self.isPointerOverStatusButton else { return }
                self.isPinned = false
                self.closePanel()
            }
        }
    }

    private func removeOutsideClickMonitor() {
        guard let outsideClickMonitor else { return }
        NSEvent.removeMonitor(outsideClickMonitor)
        self.outsideClickMonitor = nil
    }

    private func closePanel() {
        cancelScheduledClose()
        guard panel.isVisible else { return }
        panel.orderOut(nil)
        panel.alphaValue = 1
        isPointerInsidePanel = false
        isPinned = false
        removeOutsideClickMonitor()
    }
}
