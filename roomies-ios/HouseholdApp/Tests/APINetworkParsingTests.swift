import XCTest
@testable import HouseholdApp

final class APINetworkParsingTests: XCTestCase {

    func testTasksResponseParsingFlatArray() throws {
        let json = """
        {
          "success": true,
          "message": "OK",
          "data": [
            {
              "id": "task-1",
              "title": "Take out trash",
              "description": null,
              "dueDate": "2025-01-01T12:00:00Z",
              "priority": "medium",
              "points": 10,
              "isRecurring": false,
              "recurringType": null,
              "isCompleted": false,
              "completedAt": null,
              "createdAt": "2025-01-01T10:00:00Z",
              "updatedAt": "2025-01-01T11:00:00Z",
              "assignedUserId": "user-1",
              "assignedUser": {
                "id": "user-1",
                "name": "Alex",
                "email": "alex@example.com"
              },
              "createdBy": {
                "id": "user-2",
                "name": "Jamie",
                "email": "jamie@example.com"
              }
            }
          ]
        }
        """.data(using: .utf8)!

        let decoded = try JSONDecoder().decode(APIResponse<[APITask]>.self, from: json)
        XCTAssertTrue(decoded.success)
        XCTAssertEqual(decoded.data?.count, 1)
        let t = try XCTUnwrap(decoded.data?.first)
        XCTAssertEqual(t.id, "task-1")
        XCTAssertEqual(t.priority, "medium")
        XCTAssertEqual(t.updatedAt, "2025-01-01T11:00:00Z")
        XCTAssertEqual(t.createdBy.email, "jamie@example.com")
    }

    func testTaskCompleteResponseParsing() throws {
        let json = """
        {
          "success": true,
          "message": "Task completed successfully",
          "data": {
            "id": "task-9",
            "title": "Wash dishes",
            "description": "Evening dishes",
            "dueDate": null,
            "priority": "high",
            "points": 15,
            "isRecurring": false,
            "recurringType": null,
            "isCompleted": true,
            "completedAt": "2025-01-02T18:00:00Z",
            "createdAt": "2025-01-02T17:00:00Z",
            "updatedAt": "2025-01-02T18:00:00Z",
            "assignedUserId": null,
            "assignedUser": null,
            "createdBy": {
              "id": "user-3",
              "name": "Taylor",
              "email": "taylor@example.com"
            }
          }
        }
        """.data(using: .utf8)!

        let decoded = try JSONDecoder().decode(APIResponse<APITask>.self, from: json)
        XCTAssertTrue(decoded.success)
        let t = try XCTUnwrap(decoded.data)
        XCTAssertTrue(t.isCompleted)
        XCTAssertEqual(t.priority, "high")
        XCTAssertEqual(t.completedAt, "2025-01-02T18:00:00Z")
    }

    func testRewardsListParsing() throws {
        let json = """
        {
          "success": true,
          "data": [
            {"id":"r1","name":"Coffee","description":"Free coffee","cost":50,"isAvailable":true,"iconName":null,"color":null,"quantityAvailable":1,"timesRedeemed":0,"maxPerUser":1,"expiresAt":null,"createdAt":"2025-01-01T00:00:00Z"},
            {"id":"r2","name":"Snack","description":null,"cost":20,"isAvailable":true,"iconName":null,"color":null,"quantityAvailable":null,"timesRedeemed":2,"maxPerUser":null,"expiresAt":null,"createdAt":"2025-01-02T00:00:00Z"}
          ]
        }

  func testTasksResponsePaginationMeta() throws {
      let json = """
      {
        "success": true,
        "data": [],
        "pagination": {
          "currentPage": 2,
          "totalPages": 5,
          "totalItems": 100,
          "hasNextPage": true,
          "hasPreviousPage": true,
          "itemsPerPage": 20
        },
        "meta": {
          "pagination": {
            "currentPage": 2,
            "totalPages": 5,
            "totalItems": 100,
            "hasNextPage": true,
            "hasPreviousPage": true,
            "itemsPerPage": 20
          }
        }
      }
      """.data(using: .utf8)!

      let decoded = try JSONDecoder().decode(APIResponse<[APITask]>.self, from: json)
      XCTAssertTrue(decoded.success)
      XCTAssertEqual(decoded.meta?.pagination.currentPage, 2)
      XCTAssertEqual(decoded.meta?.pagination.totalItems, 100)
      XCTAssertEqual(decoded.meta?.pagination.itemsPerPage, 20)
  }
        """.data(using: .utf8)!

        let decoded = try JSONDecoder().decode(APIResponse<[APIReward]>.self, from: json)
        XCTAssertTrue(decoded.success)
        XCTAssertEqual(decoded.data?.count, 2)
        XCTAssertEqual(decoded.data?.first?.name, "Coffee")
        XCTAssertEqual(decoded.data?.last?.cost, 20)
    }
}


