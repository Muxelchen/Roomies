import Foundation

// Lightweight SSE client for subscribing to backend household events without Socket.IO
final class HouseholdSSEService: NSObject, URLSessionDataDelegate {
    struct Event {
        let name: String
        let json: [String: Any]
    }
    
    private var task: URLSessionDataTask?
    private var buffer = Data()
    private var session: URLSession!
    private let baseURL: String
    private let authTokenProvider: () -> String?
    private var retryWorkItem: DispatchWorkItem?
    private var reconnectDelay: TimeInterval = 3
    private let maxReconnectDelay: TimeInterval = 30
    
    // Event callbacks
    var onEvent: ((Event) -> Void)?
    var onOpen: (() -> Void)?
    var onClose: ((Error?) -> Void)?
    
    init(baseURL: String = AppConfig.apiBaseURL, authTokenProvider: @escaping () -> String?) {
        self.baseURL = baseURL
        self.authTokenProvider = authTokenProvider
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 0 // stream
        config.timeoutIntervalForResource = 0
        super.init()
        self.session = URLSession(configuration: config, delegate: self, delegateQueue: .main)
    }
    
    func connect(householdId: String) {
        disconnect()
        guard let url = URL(string: "\(baseURL)/events/household/\(householdId)") else { return }
        var req = URLRequest(url: url)
        req.setValue("text/event-stream", forHTTPHeaderField: "Accept")
        if let token = authTokenProvider() {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        let task = session.dataTask(with: req)
        self.task = task
        task.resume()
        onOpen?()
    }
    
    func feed(_ data: Data) {
        // Append and parse lines
        buffer.append(data)
        while let range = buffer.range(of: "\n\n".data(using: .utf8)!) {
            let chunk = buffer.subdata(in: 0..<range.lowerBound)
            buffer.removeSubrange(0..<range.upperBound)
            if let line = String(data: chunk, encoding: .utf8) {
                parseEventBlock(line)
            }
        }
    }
    
    private func parseEventBlock(_ block: String) {
        var eventName = "message"
        var dataJSON: [String: Any] = [:]
        for line in block.split(separator: "\n") {
            if line.hasPrefix("event:") {
                eventName = line.replacingOccurrences(of: "event:", with: "").trimmingCharacters(in: .whitespaces)
            } else if line.hasPrefix("data:") {
                let dataString = line.replacingOccurrences(of: "data:", with: "").trimmingCharacters(in: .whitespaces)
                if let d = dataString.data(using: .utf8),
                   let obj = try? JSONSerialization.jsonObject(with: d) as? [String: Any] {
                    dataJSON = obj
                }
            }
        }
        onEvent?(Event(name: eventName, json: dataJSON))
    }
    
    // URLSessionDataDelegate
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        feed(data)
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        // Auto-reconnect on unexpected close
        onClose?(error)
        scheduleReconnect()
    }
    
    func disconnect() {
        task?.cancel()
        task = nil
        buffer.removeAll()
        retryWorkItem?.cancel()
        retryWorkItem = nil
    }

    private func scheduleReconnect() {
        retryWorkItem?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            // Try reconnecting if we still have auth and a household id cached in defaults
            if let householdId = UserDefaults.standard.string(forKey: "currentHouseholdId") {
                self.connect(householdId: householdId)
            }
        }
        retryWorkItem = work
        // Exponential backoff with jitter
        let jitter = Double.random(in: 0...1)
        let delay = min(reconnectDelay * (1.5 + jitter * 0.5), maxReconnectDelay)
        reconnectDelay = delay
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
    }
}
