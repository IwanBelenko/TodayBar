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
            TodoItem(title: L10n.text("Выбрать книгу на выходные", "Choose a book for the weekend"), categoryID: TaskCategory.personalID),
            TodoItem(title: L10n.text("Записаться на тренировку", "Book a workout"), categoryID: TaskCategory.personalID, priority: .low),
            TodoItem(title: L10n.text("Обсудить с командой\nследующий этап проекта", "Discuss the next project phase\nwith the team"), categoryID: TaskCategory.workID, priority: .medium),
            TodoItem(title: L10n.text("Подготовить план на неделю", "Plan the week"), categoryID: TaskCategory.workID,
                     dueDate: now.addingTimeInterval(86_400), priority: .high),
            TodoItem(title: L10n.text("Отправить отчёт", "Send the report"), categoryID: TaskCategory.workID, completedAt: now, priority: .high)
        ])
        let model = TaskListViewModel(repository: repository, categoryRepository: MemoryCategoryRepository(),
                                      reminderScheduler: TestReminderScheduler())
        for (name, appearance) in [("light", NSAppearance.Name.aqua), ("dark", .darkAqua)] {
            let panel = TodayPanel(contentRect: NSRect(x: 0, y: 0, width: 420, height: 590),
                                   styleMask: [.borderless], backing: .buffered, defer: false)
            panel.configure(model: model, hoverChanged: { _ in })
            try await snapshot(panel, appearance: appearance,
                               to: directory.appendingPathComponent("today-\(name).png"))
            try await snapshot(DeadlinePickerView(dueDate: .constant(now.addingTimeInterval(86_400))),
                               appearance: appearance, to: directory.appendingPathComponent("calendar-\(name).png"), height: 570)
        }
        try await snapshot(TodayView(model: model, searchQuery: .constant(L10n.text("командой", "team")), selectedCategoryID: .constant(nil))
            .frame(width: 420, height: 440).background(TodayPalette.surface),
                     appearance: .aqua, to: directory.appendingPathComponent("search-result.png"), height: 440)
        try await snapshot(HistoryView(model: model, searchQuery: .constant(L10n.text("отчет", "report")), selectedCategoryID: nil)
            .frame(width: 420, height: 440).background(TodayPalette.surface),
                     appearance: .aqua, to: directory.appendingPathComponent("history-search.png"), height: 440)
        try await snapshot(TodayView(model: model, searchQuery: .constant(L10n.text("ничего", "no match")), selectedCategoryID: .constant(nil))
            .frame(width: 420, height: 440).background(TodayPalette.surface),
                     appearance: .aqua, to: directory.appendingPathComponent("search-empty.png"), height: 440)
    }

    @MainActor
    private func descendants(of view: NSView) -> [NSView] {
        view.subviews.flatMap { [$0] + descendants(of: $0) }
    }

    /// README demonstration, using the production panel and in-memory sample tasks only.
    @Test(.enabled(if: ProcessInfo.processInfo.environment["TODAYBAR_DEMO_DIR"] != nil))
    @MainActor
    func recordReadmeDemo() async throws {
        let directory = URL(fileURLWithPath: try #require(ProcessInfo.processInfo.environment["TODAYBAR_DEMO_DIR"]))
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        _ = NSApplication.shared
        let model = TaskListViewModel(repository: MemoryTaskRepository(tasks: [
            TodoItem(title: L10n.text("Купить книгу", "Buy a book"), categoryID: TaskCategory.personalID),
            TodoItem(title: L10n.text("Обсудить план с командой", "Discuss the plan with the team"), categoryID: TaskCategory.workID)
        ]), categoryRepository: MemoryCategoryRepository(), reminderScheduler: TestReminderScheduler())
        let panel = TodayPanel(contentRect: NSRect(x: 0, y: 0, width: 420, height: 590),
                               styleMask: [.borderless], backing: .buffered, defer: false)
        panel.isReleasedWhenClosed = false
        defer { panel.close() }
        panel.configure(model: model, hoverChanged: { _ in })
        // Pointer coordinates are in panel points, from its top-left corner. Only pulse
        // actual click targets; priority changes remain a captioned model demonstration.
        struct Pointer: Encodable { let x: Double; let y: Double }
        struct Frame: Encodable {
            let file: String; let title: String; let detail: String; let seconds: Double
            let pointer: Pointer; let move: Double; let click: Bool
        }
        var frames: [Frame] = []
        var pointer = Pointer(x: 345, y: 400)
        func capture(_ title: String, _ detail: String = "", seconds: Double = 0.5,
                     at target: Pointer? = nil, move: Double = 0, click: Bool = false) async throws {
            let file = String(format: "%02d.png", frames.count)
            try await snapshot(panel, appearance: .aqua, to: directory.appendingPathComponent(file), closeAfterCapture: false)
            if let target { pointer = target }
            frames.append(Frame(file: file, title: title, detail: detail, seconds: seconds,
                                pointer: pointer, move: move, click: click))
        }
        try await capture(L10n.text("Дела — под рукой", "Your tasks, within reach"),
                          L10n.text("Работа и личное в одном окне", "Work and personal tasks in one window"), seconds: 0.1)
        let host = try #require(panel.contentView)
        let composer = try #require(descendants(of: host).compactMap { $0 as? NSTextView }.first { $0.string.isEmpty })
        func point(in view: NSView, x: CGFloat = 0.5, y: CGFloat = 0.5) -> Pointer {
            let converted = view.convert(NSPoint(x: view.bounds.width * x, y: view.bounds.height * y), to: host)
            return Pointer(x: converted.x, y: host.isFlipped ? converted.y : host.bounds.height - converted.y)
        }
        // Deliver events only to this fixture window, never to the user's desktop.
        func click(_ target: Pointer) throws {
            let local = NSPoint(x: target.x, y: host.isFlipped ? target.y : host.bounds.height - target.y)
            let location = host.convert(local, to: nil)
            for type in [NSEvent.EventType.leftMouseDown, .leftMouseUp] {
                let event = NSEvent.mouseEvent(with: type, location: location, modifierFlags: [],
                    timestamp: ProcessInfo.processInfo.systemUptime, windowNumber: panel.windowNumber,
                    context: nil, eventNumber: 0, clickCount: 1, pressure: type == .leftMouseDown ? 1 : 0)
                guard let event else { throw NSError(domain: "DemoMouseEvent", code: 1) }
                panel.sendEvent(event)
            }
        }
        let composerPoint = point(in: composer, x: 0.12, y: 0.3)
        try await capture(L10n.text("Запишите новое дело", "Write a new task"), seconds: 0.2,
                          at: composerPoint, move: 0.4, click: true)
        // Focus text fields directly: their mouse tracking requires an application
        // event loop, unlike SwiftUI buttons in this isolated test host.
        #expect(panel.makeFirstResponder(composer))
        let title = L10n.text("Запланировать пробежку", "Plan a morning run")
        for length in Array(stride(from: 2, to: title.count, by: 2)) + [title.count] {
            composer.string = String(title.prefix(length))
            composer.didChangeText()
            try await capture(L10n.text("Запишите новое дело", "Write a new task"),
                              L10n.text("Кнопка ↑ или Enter — добавить", "Click ↑ or press Enter to add"), seconds: 0.1)
        }
        // These fixture coordinates are checked by the resulting task/filter assertions.
        let addPoint = Pointer(x: 381, y: 466)
        try await capture(L10n.text("Добавьте в список", "Add it to your list"), seconds: 0.2,
                          at: addPoint, move: 0.3, click: true)
        try click(addPoint)
        try await Task.sleep(nanoseconds: 100_000_000)
        let added = try #require(model.tasks.first { $0.title == title })
        #expect(model.tasks.count == 3)
        try await capture(L10n.text("Задача в списке", "Added to your list"), seconds: 0.3)

        let addedEditor = try #require(descendants(of: host).compactMap { $0 as? NSTextView }.first { $0.string == title })
        try await capture(L10n.text("Выберите высокий приоритет", "Set a high priority"),
                          L10n.text("••• → Приоритет → Высокий", "••• → Priority → High"), seconds: 0.7,
                          at: Pointer(x: 391, y: point(in: addedEditor).y), move: 0.3)

        model.updatePriority(id: added.id, priority: .high)
        #expect(model.todayPending.first?.id == added.id)
        try await capture(L10n.text("Важное поднимается наверх", "Important tasks rise to the top"),
                          L10n.text("Три огонька — высокий приоритет", "Three flames mean high priority"), seconds: 0.7)

        let search = try #require(descendants(of: host).compactMap { $0 as? NSTextField }.first { $0.isEditable })
        func setSearch(_ query: String) {
            search.stringValue = query
            search.delegate?.controlTextDidChange?(Notification(name: NSControl.textDidChangeNotification, object: search))
        }
        let searchPoint = point(in: search)
        try await capture(L10n.text("Найдите нужное за секунду", "Find the task you need"), seconds: 0.2,
                          at: searchPoint, move: 0.4, click: true)
        #expect(panel.makeFirstResponder(search))
        let query = L10n.text("пробежку", "run")
        for length in Array(stride(from: 2, to: query.count, by: 2)) + [query.count] {
            setSearch(String(query.prefix(length)))
            try await capture(L10n.text("Найдите нужное за секунду", "Find the task you need"), seconds: 0.1)
        }
        try await capture(L10n.text("Найдите нужное за секунду", "Find the task you need"),
                          L10n.text("Поиск по текущим делам и истории", "Search current tasks and history"), seconds: 0.5)
        let visibleTitles = descendants(of: host).compactMap { $0 as? NSTextView }
            .filter { !$0.isFieldEditor }.map(\.string).filter { !$0.isEmpty }
        #expect(visibleTitles == [title])
        let clearPoint = Pointer(x: 355, y: 40)
        try await capture(L10n.text("Вернитесь ко всем делам", "Back to the full list"), seconds: 0.2,
                          at: clearPoint, move: 0.2, click: true)
        try click(clearPoint)
        try await capture(L10n.text("Вернитесь ко всем делам", "Back to the full list"), seconds: 0.2)
        #expect(search.stringValue.isEmpty)

        let completePoint = Pointer(x: 28, y: 180)
        try await capture(L10n.text("Готово — отметьте выполненным", "Done? Check it off"), seconds: 0.2,
                          at: completePoint, move: 0.4, click: true)
        try click(completePoint)
        try await Task.sleep(nanoseconds: 100_000_000)
        #expect(model.todayCompleted.map(\.id) == [added.id])
        try await capture(L10n.text("Готово — отметьте выполненным", "Done? Check it off"),
                          L10n.text("Задача зачёркнута и сохранена в истории", "Crossed out and saved in history"), seconds: 1.2)
        try JSONEncoder().encode(frames).write(to: directory.appendingPathComponent("frames.json"))
    }

    @MainActor
    private func snapshot<Content: View>(_ view: Content, appearance: NSAppearance.Name, to url: URL,
                                         height: CGFloat = 590) async throws {
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 420, height: height),
                              styleMask: [.borderless], backing: .buffered, defer: false)
        let host = NSHostingView(rootView: view.environment(\.locale, L10n.locale))
        host.frame = NSRect(x: 0, y: 0, width: 420, height: height)
        window.contentView = host
        try await snapshot(window, appearance: appearance, to: url)
    }

    @MainActor
    private func snapshot(_ window: NSWindow, appearance: NSAppearance.Name, to url: URL,
                          closeAfterCapture: Bool = true) async throws {
        window.isReleasedWhenClosed = false
        defer { if closeAfterCapture { window.close() } }
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
