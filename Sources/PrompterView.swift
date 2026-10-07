// SPDX-License-Identifier: MIT
import SwiftUI
import AppKit

private final class ClickablePromptTextView: NSTextView {
    var onWordClick: ((Int) -> Void)?
    var words: [ScriptWord] = []
    override var acceptsFirstResponder: Bool { false }
    override func mouseDown(with event: NSEvent) {
        guard let manager = layoutManager, let container = textContainer else { return }
        var point = convert(event.locationInWindow, from: nil)
        point.x -= textContainerOrigin.x; point.y -= textContainerOrigin.y
        let glyph = manager.glyphIndex(for: point, in: container)
        guard glyph < manager.numberOfGlyphs else { return }
        let glyphRect = manager.boundingRect(forGlyphRange: NSRange(location: glyph, length: 1), in: container)
        guard glyphRect.insetBy(dx: -10, dy: -10).contains(point) else { return }
        let character = manager.characterIndexForGlyph(at: glyph)
        if let index = words.firstIndex(where: { NSLocationInRange(character, $0.range) }) {
            onWordClick?(index)
        }
    }
}

struct PrompterView: NSViewRepresentable {
    let script: PromptScript
    let cursor: Int
    let fontSize: Double
    let columnWidth: Double
    let onSeek: (Int) -> Void

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> NSScrollView {
        let scroll = NSScrollView()
        scroll.drawsBackground = true
        scroll.backgroundColor = NSColor(red: 0.045, green: 0.06, blue: 0.07, alpha: 1)
        scroll.hasVerticalScroller = false
        scroll.hasHorizontalScroller = false
        scroll.contentView.postsBoundsChangedNotifications = true
        let text = ClickablePromptTextView(frame: .zero)
        text.isEditable = false
        text.isSelectable = false
        text.drawsBackground = false
        text.isRichText = true
        text.isVerticallyResizable = true
        text.isHorizontallyResizable = false
        text.autoresizingMask = [.width]
        text.textContainer?.widthTracksTextView = true
        text.textContainer?.heightTracksTextView = false
        text.textContainer?.containerSize = NSSize(width: 800, height: CGFloat.greatestFiniteMagnitude)
        scroll.documentView = text
        context.coordinator.scroll = scroll
        context.coordinator.text = text
        context.coordinator.startTimer()
        return scroll
    }

    func updateNSView(_ scroll: NSScrollView, context: Context) {
        let coordinator = context.coordinator
        coordinator.script = script
        coordinator.text?.onWordClick = onSeek
        coordinator.update(cursor: cursor, fontSize: fontSize, columnWidth: columnWidth)
    }

    static func dismantleNSView(_ nsView: NSScrollView, coordinator: Coordinator) {
        coordinator.timer?.invalidate()
    }

    final class Coordinator {
        weak var scroll: NSScrollView?
        fileprivate weak var text: ClickablePromptTextView?
        var timer: Timer?
        var script = PromptScript("")
        private var lastText = ""
        private var lastCursor = Int.min
        private var lastFont = 0.0
        private var lastColumnWidth = 0.0
        private var lastSize = NSSize.zero
        private var targetY: CGFloat = 0
        private var needsTarget = true
        private var fontSize = 48.0
        private var columnWidth = 560.0

        func startTimer() {
            timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60, repeats: true) { [weak self] _ in
                self?.tick()
            }
            if let timer { RunLoop.main.add(timer, forMode: .common) }
        }

        func update(cursor: Int, fontSize: Double, columnWidth: Double) {
            guard let text, let scroll else { return }
            self.fontSize = fontSize
            self.columnWidth = columnWidth
            let size = scroll.contentSize
            let structureChanged = lastText != script.text || lastFont != fontSize ||
                lastColumnWidth != columnWidth || lastSize != size
            if structureChanged {
                let paragraph = NSMutableParagraphStyle()
                paragraph.lineSpacing = fontSize * 0.22
                paragraph.paragraphSpacing = fontSize * 0.05
                paragraph.alignment = .center
                text.textStorage?.setAttributedString(NSAttributedString(string: script.text, attributes: [
                    .font: NSFont.systemFont(ofSize: fontSize, weight: .semibold),
                    .foregroundColor: NSColor(white: 0.60, alpha: 1),
                    .paragraphStyle: paragraph
                ]))
                for cue in script.stageDirections {
                    text.textStorage?.addAttributes([
                        .font: NSFont.systemFont(ofSize: max(14, fontSize * 0.38), weight: .medium)
                    ], range: cue)
                }
                let horizontal = max(42, (size.width - columnWidth) / 2)
                text.textContainerInset = NSSize(width: horizontal, height: max(100, size.height * 0.38))
                text.frame.size.width = size.width
                text.words = script.words
                lastText = script.text; lastFont = fontSize; lastSize = size
                lastColumnWidth = columnWidth
            }
            if structureChanged || cursor != lastCursor {
                guard let storage = text.textStorage else { return }
                let full = NSRange(location: 0, length: storage.length)
                storage.beginEditing()
                storage.removeAttribute(.backgroundColor, range: full)
                storage.addAttribute(.foregroundColor, value: NSColor(white: 0.58, alpha: 1), range: full)
                if !script.words.isEmpty {
                    let next = max(0, min(cursor + 1, script.words.count - 1))
                    let sentence = script.words[next].sentence
                    let currentWords = script.words.filter { $0.sentence == sentence }
                    if let first = currentWords.first, let last = currentWords.last {
                        let range = NSRange(location: first.range.location,
                                            length: NSMaxRange(last.range) - first.range.location)
                        storage.addAttribute(.foregroundColor, value: NSColor.white, range: range)
                    }
                    if cursor >= 0 {
                        let spokenEnd = NSMaxRange(script.words[min(cursor, script.words.count - 1)].range)
                        storage.addAttribute(.foregroundColor, value: NSColor(white: 0.34, alpha: 1),
                                             range: NSRange(location: 0, length: spokenEnd))
                    }
                    if cursor < script.words.count - 1 {
                        storage.addAttributes([
                            .foregroundColor: NSColor(red: 0.035, green: 0.09, blue: 0.07, alpha: 1),
                            .backgroundColor: NSColor(red: 0.48, green: 0.94, blue: 0.76, alpha: 1)
                        ], range: script.words[next].range)
                    }
                }
                storage.endEditing()
                lastCursor = cursor
                needsTarget = true
            }
        }

        private func tick() {
            guard let scroll, let text, let manager = text.layoutManager, let container = text.textContainer else { return }
            if scroll.contentSize != lastSize {
                update(cursor: lastCursor, fontSize: fontSize, columnWidth: columnWidth)
            }
            if needsTarget {
                manager.ensureLayout(for: container)
                let used = manager.usedRect(for: container)
                let height = max(scroll.contentSize.height, used.height + text.textContainerInset.height * 2 + scroll.contentSize.height * 0.6)
                text.frame.size.height = height
                if !script.words.isEmpty {
                    let next = max(0, min(lastCursor + 1, script.words.count - 1))
                    let glyphRange = manager.glyphRange(forCharacterRange: script.words[next].range, actualCharacterRange: nil)
                    let rect = manager.boundingRect(forGlyphRange: glyphRange, in: container)
                    targetY = max(0, min(rect.minY + text.textContainerOrigin.y - scroll.contentSize.height * 0.38,
                                         height - scroll.contentSize.height))
                } else { targetY = 0 }
                needsTarget = false
            }
            let current = scroll.contentView.bounds.origin.y
            let difference = targetY - current
            guard abs(difference) > 0.2 else { return }
            let next = abs(difference) < 0.8 ? targetY : current + difference * 0.32
            scroll.contentView.scroll(to: NSPoint(x: 0, y: next))
            scroll.reflectScrolledClipView(scroll.contentView)
        }
    }
}
