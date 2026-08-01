import Foundation
import XCTest
@testable import Diagnostics

final class DiagnosticsTests: XCTestCase {
    func testDiagnosticsManagerCollect() async {
        await DiagnosticsManager.shared.collect()
        XCTAssertFalse(DiagnosticsManager.shared.diagnostics.isEmpty)
    }

    func testDiagnosticsExportJSON() {
        let json = DiagnosticsManager.shared.exportJSON()
        XCTAssertTrue(json.hasPrefix("["))
        XCTAssertTrue(json.hasSuffix("]"))
    }

    func testDiagnosticEntryEquality() {
        let entry1 = DiagnosticEntry(name: "Test", value: "Value", status: .ok)
        let entry2 = DiagnosticEntry(name: "Test", value: "Value", status: .ok)
        XCTAssertEqual(entry1, entry2)
    }

    func testDiagnosticStatusColor() {
        XCTAssertEqual(DiagnosticStatus.ok.color, .green)
        XCTAssertEqual(DiagnosticStatus.warning.color, .yellow)
        XCTAssertEqual(DiagnosticStatus.error.color, .red)
        XCTAssertEqual(DiagnosticStatus.unknown.color, .gray)
    }
}