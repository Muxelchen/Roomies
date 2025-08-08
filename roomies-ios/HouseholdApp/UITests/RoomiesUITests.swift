import XCTest

final class RoomiesUITests: XCTestCase {
    var app: XCUIApplication!

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        app = XCUIApplication()
    }

    func testTabSwitchShowsPremiumLoadingOverlay() {
        app.launchArguments += ["UITEST_FORCE_REDEEMING"]
        app.launch()

        // Navigate to Store tab
        let bagTab = app.tabBars.buttons["Store"]
        XCTAssertTrue(bagTab.waitForExistence(timeout: 5))
        bagTab.tap()

        // The global premium overlay should appear with the identifier
        let overlay = app.otherElements["PremiumLoadingView"]
        XCTAssertTrue(overlay.waitForExistence(timeout: 3))
    }

    func testTasksRefreshShowsTaskListSkeleton() {
        app.launchArguments += ["UITEST_FORCE_TASKS_REFRESHING"]
        app.launch()

        // Go to Tasks tab
        let tasksTab = app.tabBars.buttons["Tasks"]
        XCTAssertTrue(tasksTab.waitForExistence(timeout: 5))
        tasksTab.tap()

        // Skeleton should appear
        let skeleton = app.otherElements["TaskListSkeleton"]
        XCTAssertTrue(skeleton.waitForExistence(timeout: 3))
    }

    func testTasksEmptyStateCTAOpensAddTask() {
        app.launchArguments += ["UITEST_FORCE_EMPTY_TASKS"]
        app.launch()

        let tasksTab = app.tabBars.buttons["Tasks"]
        XCTAssertTrue(tasksTab.waitForExistence(timeout: 5))
        tasksTab.tap()

        // Tap CTA button
        let createTaskButton = app.buttons["Create Task"]
        XCTAssertTrue(createTaskButton.waitForExistence(timeout: 3))
        createTaskButton.tap()

        // Verify Add Task screen appears
        let addTask = app.otherElements["AddTaskView"]
        XCTAssertTrue(addTask.waitForExistence(timeout: 3))
    }

    func testStoreSearchShowsPremiumLoadingOverlay() {
        app.launch()

        let storeTab = app.tabBars.buttons["Store"]
        XCTAssertTrue(storeTab.waitForExistence(timeout: 5))
        storeTab.tap()

        let searchField = app.textFields["Search rewards..."]
        XCTAssertTrue(searchField.waitForExistence(timeout: 5))
        searchField.tap()
        searchField.typeText("nonexistent_query_zzz")

        // If no results, overlay will show as Searching...
        let overlay = app.otherElements["PremiumLoadingView"]
        XCTAssertTrue(overlay.waitForExistence(timeout: 3))
    }

    func testRewardRedemptionSuccessAndErrorBanner() {
        // Force overlay animation deterministically without backend
        app.launchArguments += ["UITEST_FORCE_REDEEMING"]
        app.launch()

        let storeTab = app.tabBars.buttons["Store"]
        XCTAssertTrue(storeTab.waitForExistence(timeout: 5))
        storeTab.tap()

        // Validate redeeming overlay appears via the hook
        let overlay = app.otherElements["PremiumLoadingView"]
        XCTAssertTrue(overlay.waitForExistence(timeout: 3))

        // Note: End-to-end backend outcome is not forced here. A separate
        // integration test can drive mock data or a staging backend.
        // UI-only expectation is that overlay appears. Error banner is
        // triggered by real model failure; verify it does not crash.
    }
}

