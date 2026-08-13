import AppKit
import SwiftUI

private final class PlaceholderTextView: NSTextView {
    private static let copyEntireTextMenuTag = 47_021

    var placeholderText = "" {
        didSet { needsDisplay = true }
    }
    var offersCopyEntireText = false
    var onCommandSubmit: (() -> Void)?

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if handlesSubmit(event) {
            onCommandSubmit?()
            return true
        }
        return super.performKeyEquivalent(with: event)
    }

    override func keyDown(with event: NSEvent) {
        if handlesSubmit(event) {
            onCommandSubmit?()
            return
        }
        super.keyDown(with: event)
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard string.isEmpty, !placeholderText.isEmpty else { return }

        let attributes: [NSAttributedString.Key: Any] = [
            .font: font ?? NSFont.systemFont(ofSize: 13),
            .foregroundColor: NSColor.placeholderTextColor
        ]
        let origin = NSPoint(
            x: textContainerInset.width + (textContainer?.lineFragmentPadding ?? 0),
            y: textContainerInset.height
        )
        placeholderText.draw(at: origin, withAttributes: attributes)
    }

    override func menu(for event: NSEvent) -> NSMenu? {
        let menu = super.menu(for: event) ?? NSMenu()
        guard offersCopyEntireText,
              menu.item(withTag: Self.copyEntireTextMenuTag) == nil else { return menu }

        if !menu.items.isEmpty {
            menu.addItem(.separator())
        }
        let item = NSMenuItem(
            title: "Скопировать задачу целиком",
            action: #selector(copyEntireText(_:)),
            keyEquivalent: ""
        )
        item.target = self
        item.tag = Self.copyEntireTextMenuTag
        menu.addItem(item)
        return menu
    }

    @objc private func copyEntireText(_ sender: Any?) {
        TaskClipboard.copy(string)
    }

    private func handlesSubmit(_ event: NSEvent) -> Bool {
        let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let isReturn = event.keyCode == 36 || event.keyCode == 76 || event.charactersIgnoringModifiers == "\r"
        return isReturn && !modifiers.contains(.shift)
    }
}

struct AutoGrowingTextEditor: NSViewRepresentable {
    @Binding var text: String
    @Binding var height: CGFloat

    var placeholder: String
    var minHeight: CGFloat = 22
    var maxHeight: CGFloat?
    var font: NSFont = .systemFont(ofSize: 13)
    var offersCopyEntireText = false
    var onCommandSubmit: () -> Void = {}
    var onFocusChange: (Bool) -> Void = { _ in }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = false
        scrollView.hasHorizontalScroller = false
        scrollView.hasVerticalScroller = false
        scrollView.autohidesScrollers = true

        let textView = PlaceholderTextView()
        textView.delegate = context.coordinator
        textView.isRichText = false
        textView.importsGraphics = false
        textView.drawsBackground = false
        textView.isHorizontallyResizable = false
        textView.isVerticallyResizable = true
        textView.autoresizingMask = [.width]
        textView.font = font
        textView.textColor = .labelColor
        textView.insertionPointColor = .controlAccentColor
        textView.textContainerInset = NSSize(width: 0, height: 2)
        textView.textContainer?.lineFragmentPadding = 0
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.containerSize = NSSize(width: 0, height: CGFloat.greatestFiniteMagnitude)
        textView.placeholderText = placeholder
        textView.offersCopyEntireText = offersCopyEntireText
        textView.onCommandSubmit = { [weak coordinator = context.coordinator] in
            coordinator?.submit()
        }
        textView.string = text

        scrollView.documentView = textView
        context.coordinator.scrollView = scrollView

        DispatchQueue.main.async {
            context.coordinator.recalculateHeight(for: textView)
        }
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        context.coordinator.parent = self
        guard let textView = scrollView.documentView as? NSTextView else { return }

        textView.font = font
        if let textView = textView as? PlaceholderTextView {
            textView.placeholderText = placeholder
            textView.offersCopyEntireText = offersCopyEntireText
            textView.onCommandSubmit = { [weak coordinator = context.coordinator] in
                coordinator?.submit()
            }
        }
        if textView.string != text {
            textView.string = text
        }

        DispatchQueue.main.async {
            context.coordinator.recalculateHeight(for: textView)
        }
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: AutoGrowingTextEditor
        weak var scrollView: NSScrollView?

        init(parent: AutoGrowingTextEditor) {
            self.parent = parent
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            parent.text = textView.string
            textView.needsDisplay = true
            recalculateHeight(for: textView)
        }

        func textDidBeginEditing(_ notification: Notification) {
            parent.onFocusChange(true)
        }

        func textDidEndEditing(_ notification: Notification) {
            parent.onFocusChange(false)
        }

        func textView(_ textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            let newlineCommands = [
                #selector(NSResponder.insertNewline(_:)),
                #selector(NSResponder.insertNewlineIgnoringFieldEditor(_:))
            ]
            guard newlineCommands.contains(commandSelector),
                  NSApp.currentEvent?.modifierFlags.contains(.shift) != true else {
                return false
            }

            submit()
            return true
        }

        func submit() {
            parent.onCommandSubmit()
        }

        func recalculateHeight(for textView: NSTextView) {
            guard let textContainer = textView.textContainer,
                  let layoutManager = textView.layoutManager else { return }

            let availableWidth = max(textView.enclosingScrollView?.contentSize.width ?? 0, 1)
            textContainer.containerSize = NSSize(width: availableWidth, height: CGFloat.greatestFiniteMagnitude)
            layoutManager.ensureLayout(for: textContainer)

            let contentHeight = ceil(layoutManager.usedRect(for: textContainer).height + textView.textContainerInset.height * 2)
            let desiredHeight = max(parent.minHeight, contentHeight)
            let measuredHeight = parent.maxHeight.map { min(desiredHeight, $0) } ?? desiredHeight

            scrollView?.hasVerticalScroller = parent.maxHeight.map { desiredHeight > $0 } ?? false
            if abs(parent.height - measuredHeight) > 0.5 {
                parent.height = measuredHeight
            }
        }
    }
}
