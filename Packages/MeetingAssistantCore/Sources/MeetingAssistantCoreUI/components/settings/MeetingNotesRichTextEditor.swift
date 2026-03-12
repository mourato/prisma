import AppKit
import MeetingAssistantCoreCommon
import SwiftUI

struct MeetingNotesRichTextEditor: View {
    private static let toolbarControlHeight: CGFloat = 24

    @Binding var content: MeetingNotesContent
    @StateObject private var editorController = MeetingNotesRichTextController()
    @State private var isShowingLinkEditor = false
    @State private var linkInput = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            toolbar
            MeetingNotesRichTextRepresentable(
                content: $content,
                controller: editorController
            )
        }
        .sheet(isPresented: $isShowingLinkEditor) {
            linkEditorSheet
        }
    }

    private var toolbar: some View {
        HStack(spacing: 6) {
            Picker(
                "meeting_notes.rich_text.toolbar.font_family".localized,
                selection: $editorController.selectedFontFamilyKey
            ) {
                Text("meeting_notes.rich_text.font.system".localized)
                    .tag(MeetingNotesRichTextController.systemFontFamilyKey)
                ForEach(editorController.fontFamilies, id: \.self) { family in
                    Text(family).tag(family)
                }
            }
            .labelsHidden()
            .controlSize(.large)
            .onChange(of: editorController.selectedFontFamilyKey) { _, newValue in
                editorController.applyFontFamily(key: newValue)
            }

            Picker(
                "meeting_notes.rich_text.toolbar.font_size".localized,
                selection: $editorController.selectedFontSize
            ) {
                ForEach(MeetingNotesRichTextController.supportedFontSizes, id: \.self) { size in
                    Text("\(Int(size))").tag(size)
                }
            }
            .labelsHidden()
            .controlSize(.large)
            .onChange(of: editorController.selectedFontSize) { _, newValue in
                editorController.applyFontSize(newValue)
            }

            Divider()
                .frame(height: 16)
            
            formatToggleButton(
                title: "meeting_notes.rich_text.toolbar.bold".localized,
                systemImage: "bold",
                isActive: editorController.isBoldEnabled
            ) {
                editorController.toggleBold()
            }

            formatToggleButton(
                title: "meeting_notes.rich_text.toolbar.italic".localized,
                systemImage: "italic",
                isActive: editorController.isItalicEnabled
            ) {
                editorController.toggleItalic()
            }

            Button {
                editorController.toggleUnorderedList()
            } label: {
                Image(systemName: "list.bullet")
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            .help("meeting_notes.rich_text.toolbar.unordered_list".localized)

            Button {
                editorController.toggleOrderedList()
            } label: {
                Image(systemName: "list.number")
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            .help("meeting_notes.rich_text.toolbar.ordered_list".localized)

            Button {
                linkInput = editorController.selectedLinkString ?? "https://"
                isShowingLinkEditor = true
            } label: {
                Image(systemName: "link")
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            .help("meeting_notes.rich_text.toolbar.link".localized)

            Spacer(minLength: 0)
        }
    }

    private var linkEditorSheet: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("meeting_notes.rich_text.link_sheet.title".localized)
                .font(.headline)

            TextField("meeting_notes.rich_text.link_sheet.placeholder".localized, text: $linkInput)
                .textFieldStyle(.roundedBorder)
                .onSubmit {
                    applyLinkAndDismiss()
                }

            HStack(spacing: 8) {
                Spacer()
                Button("common.cancel".localized) {
                    isShowingLinkEditor = false
                }
                .keyboardShortcut(.cancelAction)

                Button("meeting_notes.rich_text.link_sheet.apply".localized) {
                    applyLinkAndDismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(16)
        .frame(width: 420)
    }

    private func applyLinkAndDismiss() {
        editorController.applyLink(linkInput)
        isShowingLinkEditor = false
    }

    private func formatToggleButton(
        title: String,
        systemImage: String,
        isActive: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
        }
        .buttonStyle(.bordered)
        .controlSize(.large)
        .tint(isActive ? .accentColor : nil)
        .help(title)
    }
}

#Preview("Meeting Notes Rich Text Editor") {
    PreviewStateContainer(MeetingNotesContent.empty) { content in MeetingNotesRichTextEditor(content: content).frame(width: 700, height: 280).padding(12) }
}

private struct MeetingNotesRichTextRepresentable: NSViewRepresentable {
    @Binding var content: MeetingNotesContent
    let controller: MeetingNotesRichTextController

    func makeNSView(context: Context) -> NSScrollView {
        let textView = RichTextFormattingShortcutTextView()
        textView.onFormattingShortcut = { action in
            switch action {
            case .bold:
                controller.toggleBold()
            case .italic:
                controller.toggleItalic()
            case .unorderedList:
                controller.toggleUnorderedList()
            case .orderedList:
                controller.toggleOrderedList()
            }
        }
        textView.delegate = context.coordinator
        textView.isEditable = true
        textView.isSelectable = true
        textView.isRichText = true
        textView.importsGraphics = false
        textView.drawsBackground = true
        textView.backgroundColor = .textBackgroundColor
        textView.usesFindBar = false
        textView.textContainerInset = NSSize(width: 0, height: 8)
        textView.textContainer?.lineFragmentPadding = 0
        textView.textContainer?.widthTracksTextView = true
        textView.isHorizontallyResizable = false
        textView.isVerticallyResizable = true
        textView.autoresizingMask = [.width]
        textView.allowsUndo = true
        textView.font = .systemFont(ofSize: NSFont.systemFontSize)

        let scrollView = NSScrollView()
        scrollView.borderType = .noBorder
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.drawsBackground = false
        scrollView.documentView = textView

        context.coordinator.connect(textView: textView)
        context.coordinator.applyExternalContent(content, to: textView)
        return scrollView
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        guard let textView = nsView.documentView as? NSTextView else { return }
        context.coordinator.connect(textView: textView)
        context.coordinator.applyExternalContent(content, to: textView)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(content: $content, controller: controller)
    }

    @MainActor
    final class Coordinator: NSObject, NSTextViewDelegate {
        @Binding private var content: MeetingNotesContent
        private let controller: MeetingNotesRichTextController
        private var isApplyingProgrammaticUpdate = false
        private var lastRenderedContent: MeetingNotesContent = .empty
        private weak var observedTextStorage: NSTextStorage?
        private var textStorageDidProcessEditingObserver: NSObjectProtocol?

        init(content: Binding<MeetingNotesContent>, controller: MeetingNotesRichTextController) {
            _content = content
            self.controller = controller
        }

        @MainActor deinit {
            if let textStorageDidProcessEditingObserver {
                NotificationCenter.default.removeObserver(textStorageDidProcessEditingObserver)
            }
        }

        func connect(textView: NSTextView) {
            if controller.textView !== textView {
                controller.textView = textView
                controller.refreshState()
            }
            observeTextStorageIfNeeded(textView.textStorage)
        }

        func applyExternalContent(_ externalContent: MeetingNotesContent, to textView: NSTextView) {
            guard externalContent != lastRenderedContent else { return }
            let currentSelection = textView.selectedRange()
            let attributedText = deserializeAttributedText(from: externalContent)

            isApplyingProgrammaticUpdate = true
            textView.textStorage?.setAttributedString(attributedText)
            let clampedLocation = min(currentSelection.location, attributedText.length)
            textView.setSelectedRange(NSRange(location: clampedLocation, length: 0))
            isApplyingProgrammaticUpdate = false

            lastRenderedContent = externalContent
            controller.refreshState()
        }

        func textDidChange(_ notification: Notification) {
            guard !isApplyingProgrammaticUpdate,
                  let textView = notification.object as? NSTextView
            else {
                return
            }

            emitContent(from: textView)
            controller.refreshState()
        }

        func textViewDidChangeSelection(_ notification: Notification) {
            controller.refreshState()
        }

        private func emitContent(from textView: NSTextView) {
            let attributedText = textView.attributedString()
            let nextContent = MeetingNotesContent(
                plainText: textView.string,
                richTextRTFData: serializeAttributedText(attributedText)
            )

            guard nextContent != lastRenderedContent else { return }
            lastRenderedContent = nextContent
            content = nextContent
        }

        private func deserializeAttributedText(from content: MeetingNotesContent) -> NSAttributedString {
            if let rtfData = content.richTextRTFData, !rtfData.isEmpty,
               let attributed = try? NSAttributedString(
                   data: rtfData,
                   options: [.documentType: NSAttributedString.DocumentType.rtf],
                   documentAttributes: nil
               )
            {
                return attributed
            }

            return NSAttributedString(string: content.plainText)
        }

        private func serializeAttributedText(_ attributedText: NSAttributedString) -> Data? {
            guard attributedText.length > 0 else { return nil }
            let range = NSRange(location: 0, length: attributedText.length)
            return try? attributedText.data(
                from: range,
                documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf]
            )
        }

        private func observeTextStorageIfNeeded(_ textStorage: NSTextStorage?) {
            guard observedTextStorage !== textStorage else { return }

            if let textStorageDidProcessEditingObserver {
                NotificationCenter.default.removeObserver(textStorageDidProcessEditingObserver)
                self.textStorageDidProcessEditingObserver = nil
            }

            observedTextStorage = textStorage
            guard let textStorage else { return }

            textStorageDidProcessEditingObserver = NotificationCenter.default.addObserver(
                forName: NSTextStorage.didProcessEditingNotification,
                object: textStorage,
                queue: nil
            ) { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.handleTextStorageDidProcessEditing()
                }
            }
        }

        private func handleTextStorageDidProcessEditing() {
            guard !isApplyingProgrammaticUpdate,
                  let textView = controller.textView
            else {
                return
            }

            emitContent(from: textView)
            controller.refreshState()
        }
    }
}

@MainActor
final class MeetingNotesRichTextController: ObservableObject {
    static let systemFontFamilyKey = "__system__"
    static let supportedFontSizes: [CGFloat] = [10, 11, 12, 13, 14, 16, 18, 20, 24, 28, 32]

    weak var textView: NSTextView?
    let fontFamilies: [String]

    @Published var selectedFontFamilyKey = systemFontFamilyKey
    @Published var selectedFontSize: CGFloat = 16
    @Published var isBoldEnabled = false
    @Published var isItalicEnabled = false
    @Published var selectedLinkString: String?

    init() {
        fontFamilies = NSFontManager.shared.availableFontFamilies.sorted {
            $0.localizedCaseInsensitiveCompare($1) == .orderedAscending
        }
    }

    func refreshState() {
        guard let attributes = effectiveAttributes() else { return }

        let font = (attributes[.font] as? NSFont) ?? .systemFont(ofSize: NSFont.systemFontSize)
        selectedFontSize = Self.supportedFontSizes.contains(where: { abs($0 - font.pointSize) < 0.1 })
            ? font.pointSize
            : closestSupportedSize(to: font.pointSize)
        selectedFontFamilyKey = font.familyName ?? Self.systemFontFamilyKey

        let traits = NSFontManager.shared.traits(of: font)
        isBoldEnabled = traits.contains(.boldFontMask)
        isItalicEnabled = traits.contains(.italicFontMask)

        if let link = attributes[.link] {
            selectedLinkString = stringifyLink(link)
        } else {
            selectedLinkString = nil
        }
    }

    func toggleBold() {
        toggleFontTrait(.boldFontMask, enabled: isBoldEnabled)
    }

    func toggleItalic() {
        toggleFontTrait(.italicFontMask, enabled: isItalicEnabled)
    }

    func applyFontFamily(key: String) {
        guard let textView else { return }
        applyFontTransform(to: textView) { currentFont in
            resolvedFont(forFamilyKey: key, preservingTraitsFrom: currentFont)
        }
        refreshState()
    }

    func applyFontSize(_ size: CGFloat) {
        guard let textView else { return }
        applyFontTransform(to: textView) { font in
            NSFont(descriptor: font.fontDescriptor, size: size) ?? font
        }
        refreshState()
    }

    func toggleUnorderedList() {
        applyPrefixList { _ in "• " }
    }

    func toggleOrderedList() {
        applyPrefixList { index in "\(index + 1). " }
    }

    func applyLink(_ value: String) {
        guard let textView else { return }

        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        let selection = textView.selectedRange()
        guard selection.length > 0 else { return }

        textView.textStorage?.beginEditing()
        defer { textView.textStorage?.endEditing() }

        if trimmed.isEmpty {
            textView.textStorage?.removeAttribute(.link, range: selection)
        } else if let url = URL(string: trimmed) {
            textView.textStorage?.addAttribute(.link, value: url, range: selection)
        } else {
            textView.textStorage?.addAttribute(.link, value: trimmed, range: selection)
        }

        refreshState()
    }

    private func toggleFontTrait(_ trait: NSFontTraitMask, enabled: Bool) {
        guard let textView else { return }
        applyFontTransform(to: textView) { font in
            if enabled {
                return NSFontManager.shared.convert(font, toNotHaveTrait: trait)
            }
            return NSFontManager.shared.convert(font, toHaveTrait: trait)
        }
        refreshState()
    }

    private func applyFontTransform(to textView: NSTextView, transform: (NSFont) -> NSFont) {
        let selection = textView.selectedRange()
        if selection.length == 0 {
            var typing = textView.typingAttributes
            let currentFont = (typing[.font] as? NSFont) ?? .systemFont(ofSize: NSFont.systemFontSize)
            typing[.font] = transform(currentFont)
            textView.typingAttributes = typing
            return
        }

        guard let storage = textView.textStorage else { return }
        storage.beginEditing()
        defer { storage.endEditing() }

        storage.enumerateAttribute(.font, in: selection, options: []) { value, range, _ in
            let currentFont = (value as? NSFont) ?? .systemFont(ofSize: NSFont.systemFontSize)
            storage.addAttribute(.font, value: transform(currentFont), range: range)
        }
    }

    private func applyPrefixList(prefixForLine: (_ lineIndex: Int) -> String) {
        guard let textView else { return }
        let fullText = textView.string as NSString
        let selection = textView.selectedRange()
        let paragraphRange = fullText.paragraphRange(for: selection)
        let selectedText = fullText.substring(with: paragraphRange)

        let lines = selectedText.components(separatedBy: "\n")
        let transformed = lines.enumerated().map { index, line in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { return line }

            let withoutBullet = line.replacingOccurrences(of: #"^\s*•\s+"#, with: "", options: .regularExpression)
            let withoutNumber = withoutBullet.replacingOccurrences(
                of: #"^\s*\d+\.\s+"#,
                with: "",
                options: .regularExpression
            )
            return prefixForLine(index) + withoutNumber
        }
        .joined(separator: "\n")

        textView.textStorage?.beginEditing()
        textView.insertText(transformed, replacementRange: paragraphRange)
        textView.textStorage?.endEditing()
        refreshState()
    }

    private func effectiveAttributes() -> [NSAttributedString.Key: Any]? {
        guard let textView else { return nil }

        let selection = textView.selectedRange()
        if selection.length > 0,
           let storage = textView.textStorage,
           selection.location < storage.length
        {
            return storage.attributes(at: selection.location, effectiveRange: nil)
        }

        if selection.location > 0,
           let storage = textView.textStorage,
           selection.location - 1 < storage.length
        {
            return storage.attributes(at: selection.location - 1, effectiveRange: nil)
        }

        return textView.typingAttributes
    }

    private func closestSupportedSize(to size: CGFloat) -> CGFloat {
        Self.supportedFontSizes.min(by: { abs($0 - size) < abs($1 - size) }) ?? 16
    }

    private func stringifyLink(_ value: Any) -> String? {
        if let url = value as? URL {
            return url.absoluteString
        }
        return value as? String
    }

    private func resolvedFont(forFamilyKey key: String, preservingTraitsFrom sourceFont: NSFont) -> NSFont {
        let targetFont: NSFont = if key == Self.systemFontFamilyKey {
            .systemFont(ofSize: sourceFont.pointSize)
        } else {
            NSFont(name: key, size: sourceFont.pointSize) ?? sourceFont
        }

        let sourceTraits = NSFontManager.shared.traits(of: sourceFont)
        var transformedFont = targetFont

        if sourceTraits.contains(.boldFontMask) {
            transformedFont = NSFontManager.shared.convert(transformedFont, toHaveTrait: .boldFontMask)
        }
        if sourceTraits.contains(.italicFontMask) {
            transformedFont = NSFontManager.shared.convert(transformedFont, toHaveTrait: .italicFontMask)
        }

        return transformedFont
    }
}

private final class RichTextFormattingShortcutTextView: NSTextView {
    enum FormattingShortcutAction {
        case bold
        case italic
        case unorderedList
        case orderedList
    }

    var onFormattingShortcut: ((FormattingShortcutAction) -> Void)?

    override func keyDown(with event: NSEvent) {
        if handleFormattingShortcut(event) {
            return
        }
        super.keyDown(with: event)
    }

    private func handleFormattingShortcut(_ event: NSEvent) -> Bool {
        let normalizedFlags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        guard normalizedFlags.contains(.command),
              !normalizedFlags.contains(.option),
              !normalizedFlags.contains(.control),
              let key = event.charactersIgnoringModifiers?.lowercased()
        else {
            return false
        }

        switch key {
        case "b":
            onFormattingShortcut?(.bold)
            return true
        case "i":
            onFormattingShortcut?(.italic)
            return true
        case "7" where normalizedFlags.contains(.shift):
            onFormattingShortcut?(.orderedList)
            return true
        case "8" where normalizedFlags.contains(.shift):
            onFormattingShortcut?(.unorderedList)
            return true
        default:
            return false
        }
    }
}
