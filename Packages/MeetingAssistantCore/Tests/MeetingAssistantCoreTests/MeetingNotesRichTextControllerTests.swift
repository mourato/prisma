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

    func testApplyGlobalTypography_PreservesRichTraitsAndLinks() throws {
        let controller = MeetingNotesRichTextController()
        let textView = NSTextView()
        controller.textView = textView
        let targetFamily = try XCTUnwrap(familySupportingBothTraits(from: controller.fontFamilies))

        let content = NSMutableAttributedString(string: "Bold Italic Link")
        let fullRange = NSRange(location: 0, length: content.length)
        let boldRange = (content.string as NSString).range(of: "Bold")
        let italicRange = (content.string as NSString).range(of: "Italic")
        let linkRange = (content.string as NSString).range(of: "Link")
        let baseFont = try XCTUnwrap(NSFont(name: targetFamily, size: 13))
        let boldFont = NSFontManager.shared.convert(baseFont, toHaveTrait: .boldFontMask)
        let italicFont = NSFontManager.shared.convert(baseFont, toHaveTrait: .italicFontMask)
        let linkURL = try XCTUnwrap(URL(string: "https://example.com"))

        content.addAttribute(.font, value: baseFont, range: fullRange)
        content.addAttribute(.font, value: boldFont, range: boldRange)
        content.addAttribute(.font, value: italicFont, range: italicRange)
        content.addAttribute(.link, value: linkURL, range: linkRange)
        textView.textStorage?.setAttributedString(content)

        controller.applyGlobalTypography(
            familyKey: targetFamily,
            size: 24
        )

        let attributed = try XCTUnwrap(textView.textStorage)
        let firstFont = try XCTUnwrap(attributed.attribute(.font, at: 0, effectiveRange: nil) as? NSFont)
        XCTAssertEqual(firstFont.pointSize, 24, accuracy: 0.001)

        let boldUpdatedFont = try XCTUnwrap(attributed.attribute(.font, at: boldRange.location, effectiveRange: nil) as? NSFont)
        XCTAssertEqual(boldUpdatedFont.pointSize, 24, accuracy: 0.001)

        let italicUpdatedFont = try XCTUnwrap(attributed.attribute(.font, at: italicRange.location, effectiveRange: nil) as? NSFont)
        XCTAssertEqual(italicUpdatedFont.pointSize, 24, accuracy: 0.001)

        let updatedLink = try XCTUnwrap(attributed.attribute(.link, at: linkRange.location, effectiveRange: nil) as? URL)
        XCTAssertEqual(updatedLink, linkURL)
        XCTAssertEqual(textView.string, "Bold Italic Link")
    }

    func testApplyGlobalTypography_AppliesConfiguredBaseFontToTypingAttributes() {
        let controller = MeetingNotesRichTextController()
        let textView = NSTextView()
        controller.textView = textView
        textView.textStorage?.setAttributedString(NSAttributedString(string: ""))

        controller.applyGlobalTypography(familyKey: "Helvetica", size: 18)

        let typingFont = textView.typingAttributes[.font] as? NSFont
        XCTAssertNotNil(typingFont)
        XCTAssertEqual(typingFont?.pointSize ?? 0, 18, accuracy: 0.001)
        XCTAssertEqual(typingFont?.familyName, "Helvetica")
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

    private func familySupportingBothTraits(from families: [String]) -> String? {
        for family in families {
            guard let baseFont = NSFont(name: family, size: 14) else { continue }
            let boldFont = NSFontManager.shared.convert(baseFont, toHaveTrait: .boldFontMask)
            let italicFont = NSFontManager.shared.convert(baseFont, toHaveTrait: .italicFontMask)
            let boldTraits = NSFontManager.shared.traits(of: boldFont)
            let italicTraits = NSFontManager.shared.traits(of: italicFont)
            if boldTraits.contains(.boldFontMask), italicTraits.contains(.italicFontMask) {
                return family
            }
        }
        return nil
    }
}
