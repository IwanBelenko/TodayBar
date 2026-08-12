import AppKit
import SwiftUI

@MainActor
final class StatusPopoverController: NSObject, NSPopoverDelegate {
    private let statusItem: NSStatusItem
    private let popover: NSPopover
    private var trackingArea: NSTrackingArea?
    private var closeWorkItem: DispatchWorkItem?
    private var isPointerInsidePopover = false
    private var isPinned = false

    init(model: TaskListViewModel) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        popover = NSPopover()
        super.init()

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

        popover.behavior = .semitransient
        popover.animates = true
        popover.delegate = self
        popover.contentSize = NSSize(width: 400, height: 548)
        popover.contentViewController = NSHostingController(
            rootView: RootView(model: model) { [weak self] isInside in
                self?.popoverHoverChanged(isInside)
            }
        )
    }

    @objc private func statusItemPressed() {
        if NSApp.currentEvent?.type == .rightMouseUp {
            showContextMenu()
        } else {
            togglePopover()
        }
    }

    private func togglePopover() {
        if popover.isShown {
            if isPinned {
                isPinned = false
                closePopover()
            } else {
                isPinned = true
                cancelScheduledClose()
            }
        } else {
            isPinned = true
            showPopover()
        }
    }

    private func showContextMenu() {
        isPinned = false
        closePopover()

        let menu = NSMenu()
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

    @objc func mouseEntered(with event: NSEvent) {
        showPopover()
    }

    @objc func mouseExited(with event: NSEvent) {
        scheduleClose()
    }

    private func showPopover() {
        cancelScheduledClose()
        guard !popover.isShown, let button = statusItem.button else { return }
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        popover.contentViewController?.view.window?.makeKey()
    }

    private func popoverHoverChanged(_ isInside: Bool) {
        isPointerInsidePopover = isInside
        isInside ? cancelScheduledClose() : scheduleClose()
    }

    private func scheduleClose() {
        cancelScheduledClose()
        let workItem = DispatchWorkItem { [weak self] in
            guard let self, !self.isPinned, !self.isPointerInsidePopover, !self.isPointerOverStatusButton else { return }
            self.closePopover()
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
        let frameOnScreen = window.convertToScreen(frameInWindow)
        return frameOnScreen.contains(NSEvent.mouseLocation)
    }

    private func closePopover() {
        cancelScheduledClose()
        popover.performClose(nil)
    }

    func popoverDidClose(_ notification: Notification) {
        isPointerInsidePopover = false
        isPinned = false
    }
}
