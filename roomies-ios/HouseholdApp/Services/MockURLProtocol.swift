import Foundation

// A simple mock URLProtocol to return deterministic responses for UI tests and local runs.
// Enable by passing the UITEST_MOCK_API launch argument or environment variable UITEST_MOCK_API=1.
class MockURLProtocol: URLProtocol {
    static var requestHandler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool {
        // Intercept all requests when enabled
        return true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        return request
    }

    override func startLoading() {
        guard let client = client else { return }

        do {
            let (response, data) = try Self.handle(request: request)
            client.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client.urlProtocol(self, didLoad: data)
            client.urlProtocolDidFinishLoading(self)
        } catch {
            client.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() { }

    private static func handle(request: URLRequest) throws -> (HTTPURLResponse, Data) {
        // If a custom handler is set (e.g., from tests), use it
        if let handler = requestHandler {
            return try handler(request)
        }

        // Default deterministic routes
        let url = request.url?.absoluteString ?? ""

        // Health endpoint
        if url.contains("/health") {
            let data = try JSONEncoder().encode(HealthResponse(status: "ok"))
            return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: ["Content-Type":"application/json"])!, data)
        }

        // Reward redemption
        if url.contains("/rewards/") && url.hasSuffix("/redeem") && request.httpMethod == "POST" {
            // Control success/failure via launch args/env
            let env = ProcessInfo.processInfo.environment
            let args = ProcessInfo.processInfo.arguments
            let forceFail = env["UITEST_REDEEM_FAIL"] == "1" || args.contains("UITEST_REDEEM_FAIL")

            if forceFail {
                let err = APIErrorResponse(success: false, error: APIError(code: "INSUFFICIENT_POINTS", message: "Not enough points", details: nil))
                let data = try JSONEncoder().encode(err)
                return (HTTPURLResponse(url: request.url!, statusCode: 400, httpVersion: nil, headerFields: ["Content-Type":"application/json"])!, data)
            } else {
                let ok = APIResponse<EmptyResponse>(success: true, message: "Redeemed", data: EmptyResponse())
                let data = try JSONEncoder().encode(ok)
                return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: ["Content-Type":"application/json"])!, data)
            }
        }

        // Default 404 for unknown
        let notFound = APIErrorResponse(success: false, error: APIError(code: "NOT_FOUND", message: "Not found", details: nil))
        let data = try JSONEncoder().encode(notFound)
        return (HTTPURLResponse(url: request.url!, statusCode: 404, httpVersion: nil, headerFields: ["Content-Type":"application/json"])!, data)
    }
}

