import XCTest
import UIKit
@testable import DRTimer

/// SF Symbol names resolve at runtime: a typo renders an empty space rather
/// than failing the build, so the names AboutView uses are checked here.
final class AboutViewTests: XCTestCase {
    func testSymbolNamesResolve() {
        for name in ["globe", "curlybraces", "envelope", "star",
                     "square.and.arrow.up", "info.circle"] {
            XCTAssertNotNil(UIImage(systemName: name), "missing SF Symbol: \(name)")
        }
    }

    /// Asserted on `absoluteString` rather than `path`/`query`: iOS parses
    /// `mailto:` as an opaque URL, so those components come back empty even
    /// when the URL is well formed. The string is what gets opened anyway.
    func testFeedbackURLIsAMailtoCarryingTheVersion() {
        let url = AboutView.feedbackURL.absoluteString
        XCTAssertTrue(url.hasPrefix("mailto:daniel@spartatechnology.com?"), url)
        XCTAssertTrue(url.contains("subject="), "no subject in \(url)")
        XCTAssertTrue(url.contains("Version"), "version missing from \(url)")
    }
}
