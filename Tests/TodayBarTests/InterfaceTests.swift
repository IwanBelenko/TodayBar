import AppKit
import SwiftUI
import Testing
@testable import TodayBar

@Suite(.serialized)
struct InterfaceTests {
    @Test @MainActor
    func inactiveEditorDoesNotHandleReturnFromSearch() async throws {
        _ = NSApplication.shared
        var submissions = 0
        let editor = NSHostingView(rootView: AutoGrowingTextEditor(
            text: .constant("Черновик"), height: .constant(38), placeholder: "Новое дело…",
            onCommandSubmit: { submissions += 1 }
        ))
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 420, height: 150),
                              styleMask: [.titled], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        defer { window.close() }
        let content = NSView(frame: window.contentView!.bounds)
        let search = NSTextField(frame: NSRect(x: 10, y: 100, width: 200, height: 30))
        editor.frame = NSRect(x: 10, y: 10, width: 380, height: 60)
        content.addSubview(editor)
        content.addSubview(search)
        window.contentView = content
        editor.layoutSubtreeIfNeeded()
        try await Task.sleep(nanoseconds: 100_000_000)
        let textView = try #require(descendants(of: editor).compactMap { $0 as? NSTextView }.first)
        let event = try #require(NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: [],
                                                  timestamp: 0, windowNumber: window.windowNumber,
                                                  context: nil, characters: "\r", charactersIgnoringModifiers: "\r",
                                                  isARepeat: false, keyCode: 36))
        window.makeFirstResponder(search)
        #expect(!textView.performKeyEquivalent(with: event))
        #expect(submissions == 0)
        window.makeFirstResponder(textView)
        #expect(textView.performKeyEquivalent(with: event))
        #expect(submissions == 1)
    }

    /// Optional visual checks; fixture-only, never opens the user's task repository.
    @Test(.enabled(if: ProcessInfo.processInfo.environment["TODAYBAR_SNAPSHOT_DIR"] != nil))
    @MainActor
    func renderLightDarkAndSearchFixtures() async throws {
        let path = try #require(ProcessInfo.processInfo.environment["TODAYBAR_SNAPSHOT_DIR"])
        _ = NSApplication.shared
        let directory = URL(fileURLWithPath: path, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let now = Date()
        let repository = MemoryTaskRepository(tasks: [
            TodoItem(title: "Выбрать книгу на выходные", categoryID: TaskCategory.personalID),
            TodoItem(title: "Записаться на тренировку", categoryID: TaskCategory.personalID, priority: .low),
            TodoItem(title: "Обсудить с командой\nследующий этап проекта", categoryID: TaskCategory.workID, priority: .medium),
            TodoItem(title: "Подготовить план на неделю", categoryID: TaskCategory.workID,
                     dueDate: now.addingTimeInterval(86_400), priority: .high),
            TodoItem(title: "Отправить отчёт", categoryID: TaskCategory.workID, completedAt: now, priority: .high)
        ])
        let model = TaskListViewModel(repository: repository, categoryRepository: MemoryCategoryRepository(),
                                      reminderScheduler: TestReminderScheduler())
        for (name, appearance) in [("light", NSAppearance.Name.aqua), ("dark", .darkAqua)] {
            let panel = TodayPanel(contentRect: NSRect(x: 0, y: 0, width: 420, height: 590),
                                   styleMask: [.borderless], backing: .buffered, defer: false)
            panel.configure(model: model, hoverChanged: { _ in })
            try await snapshot(panel, appearance: appearance,
                               to: directory.appendingPathComponent("today-\(name).png"))
        }
        try await snapshot(TodayView(model: model, searchQuery: .constant("командой"), selectedCategoryID: .constant(nil))
            .frame(width: 420, height: 440).background(TodayPalette.surface),
                     appearance: .aqua, to: directory.appendingPathComponent("search-result.png"), height: 440)
        try await snapshot(HistoryView(model: model, searchQuery: .constant("отчет"), selectedCategoryID: nil)
            .frame(width: 420, height: 440).background(TodayPalette.surface),
                     appearance: .aqua, to: directory.appendingPathComponent("history-search.png"), height: 440)
        try await snapshot(TodayView(model: model, searchQuery: .constant("ничего"), selectedCategoryID: .constant(nil))
            .frame(width: 420, height: 440).background(TodayPalette.surface),
                     appearance: .aqua, to: directory.appendingPathComponent("search-empty.png"), height: 440)
    }

    @MainActor
    private func descendants(of view: NSView) -> [NSView] {
        view.subviews.flatMap { [$0] + descendants(of: $0) }
    }

    @MainActor
    private func snapshot<Content: View>(_ view: Content, appearance: NSAppearance.Name, to url: URL,
                                         height: CGFloat = 590) async throws {
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 420, height: height),
                              styleMask: [.borderless], backing: .buffered, defer: false)
        let host = NSHostingView(rootView: view.environment(\.locale, Locale(identifier: "ru_RU")))
        host.frame = NSRect(x: 0, y: 0, width: 420, height: height)
        window.contentView = host
        try await snapshot(window, appearance: appearance, to: url)
    }

    @MainActor
    private func snapshot(_ window: NSWindow, appearance: NSAppearance.Name, to url: URL) async throws {
        window.isReleasedWhenClosed = false
        defer { window.close() }
        window.appearance = NSAppearance(named: appearance)
        let host = try #require(window.contentView)
        host.wantsLayer = true
        window.setFrameOrigin(NSPoint(x: -10_000, y: -10_000))
        window.orderFront(nil)
        // Native text editors measure after their first layout, then update SwiftUI state.
        for _ in 0..<3 {
            host.layoutSubtreeIfNeeded()
            host.displayIfNeeded()
            try await Task.sleep(nanoseconds: 100_000_000)
        }
        for textView in descendants(of: host).compactMap({ $0 as? NSTextView }) where textView.string.contains("\n") {
            if let container = textView.textContainer, let manager = textView.layoutManager {
                manager.ensureLayout(for: container)
                let neededHeight = manager.usedRect(for: container).height + textView.textContainerInset.height * 2
                #expect((textView.enclosingScrollView?.contentSize.height ?? 0) >= neededHeight,
                        "Multiline task text must remain fully visible")
            }
        }
        // Capture the real panel's layer tree, including its rounded mask.
        // cacheDisplay alone only captures rectangular SwiftUI content, not the window's shape.
        let scale = window.backingScaleFactor
        let bitmap = try #require(NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: Int(host.bounds.width * scale),
            pixelsHigh: Int(host.bounds.height * scale), bitsPerSample: 8, samplesPerPixel: 4,
            hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
        ))
        let context = try #require(NSGraphicsContext(bitmapImageRep: bitmap)?.cgContext)
        context.scaleBy(x: scale, y: scale)
        if host.isFlipped {
            context.translateBy(x: 0, y: host.bounds.height)
            context.scaleBy(x: 1, y: -1)
        }
        let layer = try #require(host.layer)
        layer.render(in: context)
        if window is TodayPanel {
            for x in [0, bitmap.pixelsWide - 1] {
                for y in [0, bitmap.pixelsHigh - 1] {
                    #expect(bitmap.colorAt(x: x, y: y)?.alphaComponent == 0,
                            "Full-window screenshots must preserve transparent rounded corners")
                }
            }
            #expect(bitmap.colorAt(x: bitmap.pixelsWide / 2, y: bitmap.pixelsHigh / 2)?.alphaComponent == 1)
        }
        let data = try #require(bitmap.representation(using: .png, properties: [:]))
        try data.write(to: url)
    }
}
