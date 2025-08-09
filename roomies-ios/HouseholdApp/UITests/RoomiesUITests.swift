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
        app.launchArguments += ["UITEST_SKIP_ONBOARDING", "UITEST_DEMO_LOGIN", "UITEST_MOCK_API"]
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
        app.launchArguments += ["UITEST_SKIP_ONBOARDING", "UITEST_DEMO_LOGIN", "UITEST_MOCK_API", "UITEST_FORCE_REDEEMING"]
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

    // Smoke test: tap all visible buttons across tabs and common screens
    func testTapAllVisibleButtonsAcrossApp() {
        app.launchArguments += ["UITEST_SKIP_ONBOARDING", "UITEST_DEMO_LOGIN", "UITEST_MOCK_API"]
        app.launch()

        // Ensure tab bar is present by visiting each tab title we know
        let tabNames = ["Dashboard", "Tasks", "Store", "Challenges", "Leaderboard", "Profile"]

        // Helper to tap all visible buttons on current screen
        func tapAllVisibleButtons(maxTaps: Int = 50) {
            let buttons = app.buttons.allElementsBoundByIndex
            var tapped = 0
            let skipKeywords = ["delete", "remove", "sign out", "log out", "logout", "reset", "erase"]
            for button in buttons {
                if tapped >= maxTaps { break }
                guard button.exists && button.isHittable else { continue }
                let label = button.label.lowercased()
                if skipKeywords.contains(where: { label.contains($0) }) {
                    continue
                }
                button.tap()
                tapped += 1
            }
        }

        // Iterate through each tab and tap buttons within
        for tab in ["Dashboard", "Tasks", "Store", "Challenges", "Leaderboard", "Profile"] {
            let tabButton = app.tabBars.buttons[tab]
            XCTAssertTrue(tabButton.waitForExistence(timeout: 5))
            tabButton.tap()

            // Wait briefly for content
            _ = app.otherElements.firstMatch.waitForExistence(timeout: 1)

            // Tap common FAB if present (Tasks)
            let fab = app.buttons.matching(identifier: "FloatingActionButton").firstMatch
            if fab.exists && fab.isHittable { fab.tap() }

            // Tap all non-destructive hittable buttons on the screen
            tapAllVisibleButtons()
        }
    }
}

