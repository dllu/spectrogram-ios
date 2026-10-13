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
        XCTAssertTrue(app.staticTexts["selected-musical-note"].label.contains("A4"))
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

    func testDisplaySettingsCanChangeRange() {
        app.buttons["display-settings"].tap()
        let minimum = app.buttons["minimum-frequency"]
        XCTAssertTrue(minimum.waitForExistence(timeout: 3))
        minimum.tap()
        app.buttons["50.0 Hz"].tap()
        XCTAssertTrue(minimum.label.contains("50.0 Hz"))
        app.buttons["close-display-settings"].tap()
        let waterfall = app.otherElements["spectrogram-waterfall"]
        waterfall.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.7)).tap()
        XCTAssertTrue(app.otherElements["spectrum-plot"].waitForExistence(timeout: 3))
        saveScreenshot(named: "Configured frequency range")
    }

    func testNewestSliceIsAtTopAndRulerDoesNotCoverWaterfall() {
        let waterfall = app.otherElements["spectrogram-waterfall"]
        let ruler = app.otherElements["waterfall-frequency-axis"]
        XCTAssertTrue(waterfall.waitForExistence(timeout: 5))
        XCTAssertTrue(ruler.exists)
        XCTAssertLessThanOrEqual(ruler.frame.maxY, waterfall.frame.minY + 1)
        waterfall.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0)).tap()
        XCTAssertTrue(app.staticTexts["Newest slice"].waitForExistence(timeout: 3))
        app.buttons["close-spectrum-detail"].tap()
        waterfall.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.95)).tap()
        XCTAssertFalse(app.staticTexts["Newest slice"].exists)
        XCTAssertTrue(app.otherElements["spectrum-plot"].exists)
        saveScreenshot(named: "Newest at top with octave ruler")
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
        let normalizedFrequency = log(frequency / 32) / log(16_000 / 32)
        let x = 42 + (plot.frame.width - 54) * normalizedFrequency
        return plot.coordinate(withNormalizedOffset: CGVector(dx: x / plot.frame.width, dy: 0.5))
    }

}
