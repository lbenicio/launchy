import SwiftUI
import XCTest

@testable import Launchy

final class GridMetricsTests: XCTestCase {
  func testCalculatorRespectsContainerSizeAndBounds() {
    let metrics = GridMetricsCalculator.make(
      containerSize: CGSize(width: 1200, height: 800),
      columns: 6,
      rows: 4
    )

    XCTAssertLessThanOrEqual(metrics.columns.count, 6)
    XCTAssertEqual(metrics.rows, 4)
    XCTAssertGreaterThan(metrics.tileSize.width, 0)
    XCTAssertGreaterThan(metrics.tileSize.height, 0)
    XCTAssertEqual(metrics.capacity, metrics.columns.count * metrics.rows)
  }

  func testZeroSizedContainerStillProducesGrid() {
    let metrics = GridMetricsCalculator.make(
      containerSize: .zero,
      columns: 0,
      rows: 0
    )

    XCTAssertGreaterThan(metrics.capacity, 0)
    XCTAssertEqual(metrics.rows, 1)
    XCTAssertEqual(metrics.columns.count, 1)
  }
}
