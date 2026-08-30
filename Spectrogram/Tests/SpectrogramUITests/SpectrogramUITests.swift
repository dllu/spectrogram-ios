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

        captureButton.tap()
        XCTAssertEqual(captureButton.label, "Pause")

        let waterfall = app.otherElements["spectrogram-waterfall"]
        XCTAssertTrue(waterfall.waitForExistence(timeout: 3))
        waterfall.coordinate(withNormalizedOffset: CGVector(dx: 0.48, dy: 0.72)).tap()

        let plot = app.otherElements["spectrum-plot"]
        XCTAssertTrue(plot.waitForExistence(timeout: 3))
        XCTAssertEqual(captureButton.label, "Resume")

        plot.coordinate(withNormalizedOffset: CGVector(dx: 0.63, dy: 0.5)).tap()
        let peakLabel = app.staticTexts["selected-peak-frequency"]
        XCTAssertTrue(peakLabel.waitForExistence(timeout: 2))
        XCTAssertTrue(peakLabel.label.contains("1.000 kHz"), peakLabel.label)

        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Selected spectrum peak"
        attachment.lifetime = .keepAlways
        add(attachment)

        app.buttons["close-spectrum-detail"].tap()
        XCTAssertFalse(plot.exists)
    }
}
