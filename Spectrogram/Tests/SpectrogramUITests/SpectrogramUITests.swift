import XCTest

final class SpectrogramUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments.append("--ui-testing")
        app.launch()
    }

    func testPauseSliceAndPeakInteractions() {
        let captureButton = app.buttons["capture-toggle"]
        XCTAssertTrue(captureButton.waitForExistence(timeout: 5))
        XCTAssertEqual(captureButton.label, "Resume")
        saveScreenshot(named: "Portrait waterfall")

        captureButton.tap()
        XCTAssertEqual(captureButton.label, "Pause")

        let waterfall = app.otherElements["spectrogram-waterfall"]
        XCTAssertTrue(waterfall.waitForExistence(timeout: 3))
        waterfall.coordinate(withNormalizedOffset: CGVector(dx: 0.48, dy: 0.72)).tap()

        let plot = app.otherElements["spectrum-plot"]
        XCTAssertTrue(plot.waitForExistence(timeout: 3))
        XCTAssertEqual(captureButton.label, "Resume")

        coordinate(for: 1_000, in: plot).tap()
        let peakLabel = app.staticTexts["selected-peak-frequency"]
        XCTAssertTrue(peakLabel.waitForExistence(timeout: 2))
        XCTAssertTrue(peakLabel.label.contains("1.000 kHz"), peakLabel.label)

        saveScreenshot(named: "Selected spectrum peak")

        app.buttons["close-spectrum-detail"].tap()
        XCTAssertFalse(plot.exists)
    }

    func testResumeDismissesSelectionAndClearRemovesHistory() {
        let waterfall = app.otherElements["spectrogram-waterfall"]
        XCTAssertTrue(waterfall.waitForExistence(timeout: 5))
        waterfall.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        let plot = app.otherElements["spectrum-plot"]
        XCTAssertTrue(plot.waitForExistence(timeout: 3))

        app.buttons["capture-toggle"].tap()
        XCTAssertFalse(plot.exists)
        XCTAssertEqual(app.buttons["capture-toggle"].label, "Pause")
        app.buttons["clear-history"].tap()
        XCTAssertFalse(app.buttons["clear-history"].isEnabled)
    }

    func testLandscapePlotSupportsDraggingBetweenPeaks() {
        XCUIDevice.shared.orientation = .landscapeLeft
        let waterfall = app.otherElements["spectrogram-waterfall"]
        XCTAssertTrue(waterfall.waitForExistence(timeout: 5))
        XCTAssertGreaterThan(app.frame.width, app.frame.height)
        waterfall.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.7)).tap()
        let plot = app.otherElements["spectrum-plot"]
        XCTAssertTrue(plot.waitForExistence(timeout: 3))
        coordinate(for: 440, in: plot).press(forDuration: 0.1, thenDragTo: coordinate(for: 1_000, in: plot))
        XCTAssertTrue(app.staticTexts["selected-peak-frequency"].label.contains("1.000 kHz"))
        XCTAssertGreaterThan(waterfall.frame.height, 50)
        XCTAssertGreaterThanOrEqual(plot.frame.height, 60)
        XCTAssertLessThanOrEqual(plot.frame.maxY, app.frame.maxY)
        XCTAssertTrue(app.buttons["close-spectrum-detail"].isHittable)

        saveScreenshot(named: "Landscape spectrum detail")
    }

    override func tearDownWithError() throws {
        XCUIDevice.shared.orientation = .portrait
    }

    private func saveScreenshot(named name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func coordinate(for frequency: Double, in plot: XCUIElement) -> XCUICoordinate {
        let normalizedFrequency = log(frequency / 20) / log(20_000 / 20)
        let x = 42 + (plot.frame.width - 54) * normalizedFrequency
        return plot.coordinate(withNormalizedOffset: CGVector(dx: x / plot.frame.width, dy: 0.5))
    }

}
