import XCTest
import DRCore
@testable import DRTimer

final class LegDraftTests: XCTestCase {
    func testValidDraftProducesLeg() {
        let draft = LegDraft(landmark: "Bridge", minutes: "12", seconds: "30")
        XCTAssertEqual(draft.leg?.landmark, "Bridge")
        XCTAssertEqual(draft.leg?.seconds, 750)
        XCTAssertNil(draft.errorMessage)
    }

    func testZeroTimeHasError() {
        let draft = LegDraft(landmark: "Bridge", minutes: "0", seconds: "0")
        XCTAssertNil(draft.leg)
        XCTAssertNotNil(draft.errorMessage)
    }

    func testOverMaxHasError() {
        let draft = LegDraft(landmark: "Bridge", minutes: "100", seconds: "0")
        XCTAssertNil(draft.leg)
        XCTAssertNotNil(draft.errorMessage)
    }

    func testSecondsOver59HasError() {
        let draft = LegDraft(landmark: "Bridge", minutes: "1", seconds: "60")
        XCTAssertNil(draft.leg)
        XCTAssertNotNil(draft.errorMessage)
    }

    func testBlankLandmarkHasError() {
        let draft = LegDraft(landmark: "   ", minutes: "1", seconds: "0")
        XCTAssertNil(draft.leg)
        XCTAssertNotNil(draft.errorMessage)
    }

    func testNewDraftDefaultsToZeroTimeSoOnlyOneWheelNeedsSetting() {
        var draft = LegDraft()
        XCTAssertEqual(draft.minutes, "0")
        XCTAssertEqual(draft.seconds, "0")
        draft.landmark = "Bridge"
        draft.seconds = "30"
        XCTAssertEqual(draft.leg?.seconds, 30)
        XCTAssertNil(draft.errorMessage)
    }
}
