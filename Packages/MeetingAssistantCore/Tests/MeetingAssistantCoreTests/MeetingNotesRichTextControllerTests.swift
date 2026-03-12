import AppKit
@testable import MeetingAssistantCoreUI
import XCTest

@MainActor
final class MeetingNotesRichTextControllerTests: XCTestCase {
    func testApplyFontFamily_PreservesBoldTrait() throws {
        let controller = MeetingNotesRichTextController()
        let textView = NSTextView()
        let text = "Styled text"
        let range = NSRange(location: 0, length: (text as NSString).length)

        let baseFont = NSFont.systemFont(ofSize: 14)
        let boldFont = NSFontManager.shared.convert(baseFont, toHaveTrait: .boldFontMask)
        textView.textStorage?.setAttributedString(
            NSAttributedString(string: text, attributes: [.font: boldFont])
        )
        textView.setSelectedRange(range)
        controller.textView = textView

        let targetFamily = try XCTUnwrap(
            familySupporting(trait: .boldFontMask, excluding: boldFont.familyName, from: controller.fontFamilies)
        )
        controller.applyFontFamily(key: targetFamily)

        let updatedFont = try XCTUnwrap(textView.textStorage?.attribute(.font, at: 0, effectiveRange: nil) as? NSFont)
        let traits = NSFontManager.shared.traits(of: updatedFont)
        XCTAssertTrue(traits.contains(.boldFontMask))
    }

    func testApplyFontFamily_PreservesItalicTrait() throws {
        let controller = MeetingNotesRichTextController()
        let textView = NSTextView()
        let text = "Styled text"
        let range = NSRange(location: 0, length: (text as NSString).length)

        let baseFont = NSFont.systemFont(ofSize: 14)
        let italicFont = NSFontManager.shared.convert(baseFont, toHaveTrait: .italicFontMask)
        textView.textStorage?.setAttributedString(
            NSAttributedString(string: text, attributes: [.font: italicFont])
        )
        textView.setSelectedRange(range)
        controller.textView = textView

        let targetFamily = try XCTUnwrap(
            familySupporting(trait: .italicFontMask, excluding: italicFont.familyName, from: controller.fontFamilies)
        )
        controller.applyFontFamily(key: targetFamily)

        let updatedFont = try XCTUnwrap(textView.textStorage?.attribute(.font, at: 0, effectiveRange: nil) as? NSFont)
        let traits = NSFontManager.shared.traits(of: updatedFont)
        XCTAssertTrue(traits.contains(.italicFontMask))
    }

    private func familySupporting(
        trait: NSFontTraitMask,
        excluding excludedFamily: String?,
        from families: [String]
    ) -> String? {
        for family in families where family != excludedFamily {
            guard let baseFont = NSFont(name: family, size: 14) else { continue }
            let transformed = NSFontManager.shared.convert(baseFont, toHaveTrait: trait)
            let transformedTraits = NSFontManager.shared.traits(of: transformed)
            if transformedTraits.contains(trait) {
                return family
            }
        }
        return nil
    }
}
