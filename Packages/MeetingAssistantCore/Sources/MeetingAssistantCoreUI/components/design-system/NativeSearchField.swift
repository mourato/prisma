import AppKit
import SwiftUI

struct NativeSearchField: NSViewRepresentable {
    @Binding var text: String
    let placeholder: String

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text)
    }

    func makeNSView(context: Context) -> NSSearchField {
        let searchField = NSSearchField(frame: .zero)
        searchField.delegate = context.coordinator
        searchField.placeholderString = placeholder
        searchField.sendsSearchStringImmediately = true
        searchField.sendsWholeSearchString = true
        searchField.focusRingType = .default
        searchField.maximumRecents = 0
        searchField.recentsAutosaveName = nil
        searchField.cell?.controlSize = .regular
        searchField.stringValue = text
        return searchField
    }

    func updateNSView(_ nsView: NSSearchField, context: Context) {
        if nsView.stringValue != text {
            nsView.stringValue = text
        }

        if nsView.placeholderString != placeholder {
            nsView.placeholderString = placeholder
        }
    }
}

extension NativeSearchField {
    final class Coordinator: NSObject, NSSearchFieldDelegate {
        @Binding private var text: String

        init(text: Binding<String>) {
            _text = text
        }

        func controlTextDidChange(_ notification: Notification) {
            guard let searchField = notification.object as? NSSearchField else { return }
            text = searchField.stringValue
        }
    }
}
