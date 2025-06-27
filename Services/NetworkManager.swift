/*
 增强的网络管理器
 支持HTTP请求、WebSocket连接、缓存、重连机制等完整功能
 作者: MiniMax Agent
 创建时间: 2025-06-24 15:23:57
 */

import Foundation
import Combine
import Network

// MARK: - WebSocket消息协议
protocol WebSocketMessage: Codable {
    var type: String { get }
    var timestamp: Date { get }
}

// MARK: - 市场数据消息
struct MarketDataMessage: WebSocketMessage {
    let type: String = "market_data"
    let timestamp: Date = Date()
    let symbol: String
    let data: MarketData
    
    struct MarketData: Codable {
        let price: Double
        let change: Double
        let changePercent: Double
        let volume: Int64
        let amount: Double
        let bidPrices: [Double]?
        let bidVolumes: [Int64]?
        let askPrices: [Double]?
        let askVolumes: [Int64]?
    }
}

// MARK: - 心跳消息
struct HeartbeatMessage: WebSocketMessage {
    let type: String = "heartbeat"
    let timestamp: Date = Date()
    let message: String = "ping"
}

// MARK: - WebSocket管理器
@MainActor
class WebSocketManager: NSObject, ObservableObject {
    @Published var isConnected = false
    @Published var connectionState: WebSocketConnectionState = .disconnected
    @Published var lastMessage: WebSocketMessage?
    @Published var error: NetworkError?
    
    private var webSocketTask: URLSessionWebSocketTask?
    private var urlSession: URLSession?
    private let config: NetworkConfig
    private var heartbeatTimer: Timer?
    private var reconnectTimer: Timer?
    private var reconnectAttempts = 0
    private let maxReconnectAttempts = 5
    private var messageHandlers: [String: (WebSocketMessage) -> Void] = [:]
    
    // 消息发布器
    let messagePublisher = PassthroughSubject<WebSocketMessage, Never>()
    
    enum WebSocketConnectionState {
        case disconnected
        case connecting
        case connected
        case reconnecting
        case failed
    }
    
    init(config: NetworkConfig) {
        self.config = config
        super.init()
        setupURLSession()
    }
    
    deinit {
        disconnect()
    }
    
    private func setupURLSession() {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = config.timeout
        urlSession = URLSession(configuration: configuration, delegate: self, delegateQueue: nil)
    }
    
    // MARK: - 连接管理
    
    func connect() {
        guard connectionState != .connected && connectionState != .connecting else { return }
        
        connectionState = .connecting
        error = nil
        
        let wsURL = config.baseURL.replacingOccurrences(of: "http", with: "ws") + "/ws"
        guard let url = URL(string: wsURL) else {
            handleConnectionError(NetworkError.invalidURL)
            return
        }
        
        var request = URLRequest(url: url)
        request.setValue(config.apiKey, forHTTPHeaderField: "X-API-Key")
        
        webSocketTask = urlSession?.webSocketTask(with: request)
        webSocketTask?.resume()
        
        // 开始接收消息
        receiveMessage()
        
        print("WebSocket连接中...")
    }
    
    func disconnect() {
        connectionState = .disconnected
        isConnected = false
        
        stopHeartbeat()
        stopReconnectTimer()
        
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil
        
        print("WebSocket已断开连接")
    }
    
    func reconnect() {
        guard reconnectAttempts < maxReconnectAttempts else {
            connectionState = .failed
            error = NetworkError.webSocketConnectionFailed
            print("WebSocket重连次数超限，停止重连")
            return
        }
        
        reconnectAttempts += 1
        connectionState = .reconnecting
        
        print("WebSocket重连中，第\(reconnectAttempts)次尝试")
        
        disconnect()
        
        // 延迟重连
        reconnectTimer = Timer.scheduledTimer(withTimeInterval: config.retryDelay * Double(reconnectAttempts), repeats: false) { [weak self] _ in
            self?.connect()
        }
    }
    
    // MARK: - 消息处理
    
    private func receiveMessage() {
        webSocketTask?.receive { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let message):
                    self?.handleMessage(message)
                    self?.receiveMessage() // 继续接收下一条消息
                    
                case .failure(let error):
                    print("WebSocket接收消息失败: \(error)")
                    self?.handleConnectionError(NetworkError.custom(error.localizedDescription))
                }
            }
        }
    }
    
    private func handleMessage(_ message: URLSessionWebSocketTask.Message) {
        switch message {
        case .string(let text):
            parseMessage(text)
        case .data(let data):
            if let text = String(data: data, encoding: .utf8) {
                parseMessage(text)
            }
        @unknown default:
            print("未知的WebSocket消息类型")
        }
    }
    
    private func parseMessage(_ text: String) {
        do {
            // 先尝试解析基本消息类型
            let json = try JSONSerialization.jsonObject(with: text.data(using: .utf8)!, options: [])
            guard let dict = json as? [String: Any],
                  let type = dict["type"] as? String else {
                return
            }
            
            // 根据消息类型解析具体消息
            let message: WebSocketMessage
            switch type {
            case "market_data":
                message = try JSONDecoder().decode(MarketDataMessage.self, from: text.data(using: .utf8)!)
            case "heartbeat":
                message = try JSONDecoder().decode(HeartbeatMessage.self, from: text.data(using: .utf8)!)
                handleHeartbeatResponse()
                return // 心跳消息不需要传播
            default:
                print("未知的消息类型: \(type)")
                return
            }
            
            // 更新UI状态
            lastMessage = message
            
            // 发布消息
            messagePublisher.send(message)
            
            // 调用消息处理器
            messageHandlers[type]?(message)
            
        } catch {
            print("解析WebSocket消息失败: \(error)")
        }
    }
    
    func sendMessage<T: WebSocketMessage>(_ message: T) {
        guard isConnected else {
            print("WebSocket未连接，无法发送消息")
            return
        }
        
        do {
            let data = try JSONEncoder().encode(message)
            let text = String(data: data, encoding: .utf8)!
            let wsMessage = URLSessionWebSocketTask.Message.string(text)
            
            webSocketTask?.send(wsMessage) { error in
                if let error = error {
                    print("发送WebSocket消息失败: \(error)")
                }
            }
        } catch {
            print("编码WebSocket消息失败: \(error)")
        }
    }
    
    // MARK: - 消息订阅
    
    func addMessageHandler<T: WebSocketMessage>(for type: T.Type, handler: @escaping (WebSocketMessage) -> Void) {
        let typeKey = String(describing: type)
        messageHandlers[typeKey] = handler
    }
    
    func removeMessageHandler<T: WebSocketMessage>(for type: T.Type) {
        let typeKey = String(describing: type)
        messageHandlers.removeValue(forKey: typeKey)
    }
    
    // MARK: - 心跳机制
    
    private func startHeartbeat() {
        stopHeartbeat()
        heartbeatTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [weak self] _ in
            self?.sendHeartbeat()
        }
    }
    
    private func stopHeartbeat() {
        heartbeatTimer?.invalidate()
        heartbeatTimer = nil
    }
    
    private func sendHeartbeat() {
        let heartbeat = HeartbeatMessage()
        sendMessage(heartbeat)
    }
    
    private func handleHeartbeatResponse() {
        // 心跳响应正常，重置重连计数
        reconnectAttempts = 0
    }
    
    // MARK: - 错误处理
    
    private func handleConnectionError(_ error: NetworkError) {
        self.error = error
        connectionState = .failed
        isConnected = false
        
        // 自动重连
        if reconnectAttempts < maxReconnectAttempts {
            reconnect()
        }
    }
    
    private func stopReconnectTimer() {
        reconnectTimer?.invalidate()
        reconnectTimer = nil
    }
}

// MARK: - URLSessionWebSocketDelegate
extension WebSocketManager: URLSessionWebSocketDelegate {
    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didOpenWithProtocol protocol: String?) {
        DispatchQueue.main.async {
            self.connectionState = .connected
            self.isConnected = true
            self.reconnectAttempts = 0
            self.error = nil
            self.startHeartbeat()
            print("WebSocket连接成功")
        }
    }
    
    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didCloseWith closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
        DispatchQueue.main.async {
            self.isConnected = false
            self.connectionState = .disconnected
            self.stopHeartbeat()
            print("WebSocket连接关闭，代码: \(closeCode)")
            
            // 如果不是主动断开，尝试重连
            if closeCode != .goingAway {
                self.reconnect()
            }
        }
    }
}

// MARK: - 请求缓存管理器
class RequestCacheManager {
    private let cache = NSCache<NSString, CachedResponse>()
    private let fileManager = FileManager.default
    private let cacheDirectory: URL
    
    struct CachedResponse {
        let data: Data
        let timestamp: Date
        let maxAge: TimeInterval
        
        var isExpired: Bool {
            return Date().timeIntervalSince(timestamp) > maxAge
        }
    }
    
    init() {
        let urls = fileManager.urls(for: .cachesDirectory, in: .userDomainMask)
        cacheDirectory = urls.first!.appendingPathComponent("NetworkCache")
        
        // 创建缓存目录
        try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
        
        // 配置内存缓存
        cache.countLimit = 100
        cache.totalCostLimit = 50 * 1024 * 1024 // 50MB
    }
    
    func cacheResponse(_ data: Data, for key: String, maxAge: TimeInterval = 300) {
        let cacheKey = NSString(string: key)
        let response = CachedResponse(data: data, timestamp: Date(), maxAge: maxAge)
        
        // 内存缓存
        cache.setObject(response, forKey: cacheKey, cost: data.count)
        
        // 磁盘缓存
        let fileURL = cacheDirectory.appendingPathComponent(key.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? key)
        try? data.write(to: fileURL)
    }
    
    func getCachedResponse(for key: String) -> Data? {
        let cacheKey = NSString(string: key)
        
        // 先检查内存缓存
        if let response = cache.object(forKey: cacheKey), !response.isExpired {
            return response.data
        }
        
        // 检查磁盘缓存
        let fileURL = cacheDirectory.appendingPathComponent(key.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? key)
        if let data = try? Data(contentsOf: fileURL) {
            // 重新加载到内存缓存
            cacheResponse(data, for: key)
            return data
        }
        
        return nil
    }
    
    func clearCache() {
        cache.removeAllObjects()
        try? fileManager.removeItem(at: cacheDirectory)
        try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
    }
}

// MARK: - 增强的网络管理器
@MainActor
class EnhancedNetworkManager: ObservableObject {
    @Published var isLoading = false
    @Published var error: NetworkError?
    @Published var isNetworkAvailable = true
    
    private let httpManager: HTTPManager
    private let webSocketManager: WebSocketManager
    private let cacheManager = RequestCacheManager()
    private let config: NetworkConfig
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "NetworkMonitor")
    
    // 离线操作队列
    private var offlineOperations: [OfflineOperation] = []
    
    struct OfflineOperation {
        let id = UUID()
        let endpoint: String
        let method: String
        let body: [String: Any]?
        let timestamp: Date
    }
    
    init(config: NetworkConfig = .default) {
        self.config = config
        self.httpManager = HTTPManager(config: config)
        self.webSocketManager = WebSocketManager(config: config)
        
        setupNetworkMonitoring()
        setupWebSocketHandlers()
    }
    
    deinit {
        monitor.cancel()
    }
    
    private func setupNetworkMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                let wasOffline = !self?.isNetworkAvailable ?? false
                self?.isNetworkAvailable = path.status == .satisfied
                
                // 网络恢复时处理离线操作
                if wasOffline && path.status == .satisfied {
                    self?.processOfflineOperations()
                }
            }
        }
        monitor.start(queue: queue)
    }
    
    private func setupWebSocketHandlers() {
        // 添加市场数据处理器
        webSocketManager.addMessageHandler(for: MarketDataMessage.self) { message in
            // 处理市场数据更新
            NotificationCenter.default.post(name: .marketDataUpdated, object: message)
        }
    }
    
    // MARK: - HTTP请求方法
    
    func get<T: Codable>(_ endpoint: String,
                        parameters: [String: Any]? = nil,
                        useCache: Bool = true,
                        cacheMaxAge: TimeInterval = 300,
                        type: T.Type) async throws -> T {
        
        let cacheKey = generateCacheKey(endpoint: endpoint, parameters: parameters)
        
        // 检查缓存
        if useCache, let cachedData = cacheManager.getCachedResponse(for: cacheKey) {
            do {
                return try JSONDecoder().decode(type, from: cachedData)
            } catch {
                // 缓存数据解析失败，继续网络请求
            }
        }
        
        // 网络请求
        if isNetworkAvailable {
            do {
                let result = try await httpManager.get(endpoint, parameters: parameters, type: type)
                
                // 缓存响应
                if useCache {
                    do {
                        let data = try JSONEncoder().encode(result)
                        cacheManager.cacheResponse(data, for: cacheKey, maxAge: cacheMaxAge)
                    } catch {
                        print("缓存响应失败: \(error)")
                    }
                }
                
                return result
            } catch {
                // 网络请求失败，如果有缓存则返回缓存数据
                if let cachedData = cacheManager.getCachedResponse(for: cacheKey) {
                    return try JSONDecoder().decode(type, from: cachedData)
                }
                throw error
            }
        } else {
            // 离线模式，尝试返回缓存数据
            if let cachedData = cacheManager.getCachedResponse(for: cacheKey) {
                return try JSONDecoder().decode(type, from: cachedData)
            }
            throw NetworkError.networkUnavailable
        }
    }
    
    func post<T: Codable>(_ endpoint: String,
                         body: [String: Any],
                         type: T.Type) async throws -> T {
        
        if isNetworkAvailable {
            return try await httpManager.post(endpoint, body: body, type: type)
        } else {
            // 离线模式，加入操作队列
            let operation = OfflineOperation(
                endpoint: endpoint,
                method: "POST",
                body: body,
                timestamp: Date()
            )
            offlineOperations.append(operation)
            throw NetworkError.networkUnavailable
        }
    }
    
    // MARK: - WebSocket方法
    
    var webSocketState: WebSocketManager.WebSocketConnectionState {
        return webSocketManager.connectionState
    }
    
    var isWebSocketConnected: Bool {
        return webSocketManager.isConnected
    }
    
    func connectWebSocket() {
        webSocketManager.connect()
    }
    
    func disconnectWebSocket() {
        webSocketManager.disconnect()
    }
    
    func subscribeToMarketData() -> AnyPublisher<MarketDataMessage, Never> {
        return webSocketManager.messagePublisher
            .compactMap { $0 as? MarketDataMessage }
            .eraseToAnyPublisher()
    }
    
    // MARK: - 离线操作处理
    
    private func processOfflineOperations() {
        guard !offlineOperations.isEmpty else { return }
        
        print("处理\(offlineOperations.count)个离线操作")
        
        let operations = offlineOperations
        offlineOperations.removeAll()
        
        Task {
            for operation in operations {
                do {
                    switch operation.method {
                    case "POST":
                        let _: [String: Any] = try await httpManager.post(
                            operation.endpoint,
                            body: operation.body ?? [:],
                            type: [String: Any].self
                        )
                    default:
                        break
                    }
                    print("离线操作成功执行: \(operation.endpoint)")
                } catch {
                    print("离线操作执行失败: \(operation.endpoint), 错误: \(error)")
                    // 可以选择重新加入队列或丢弃
                }
            }
        }
    }
    
    // MARK: - 辅助方法
    
    private func generateCacheKey(endpoint: String, parameters: [String: Any]?) -> String {
        var key = endpoint
        if let params = parameters {
            let sortedParams = params.sorted { $0.key < $1.key }
            let paramString = sortedParams.map { "\($0.key)=\($0.value)" }.joined(separator: "&")
            key += "?" + paramString
        }
        return key.md5
    }
    
    func clearCache() {
        cacheManager.clearCache()
    }
}

// MARK: - 通知扩展
extension Notification.Name {
    static let marketDataUpdated = Notification.Name("marketDataUpdated")
    static let webSocketConnected = Notification.Name("webSocketConnected")
    static let webSocketDisconnected = Notification.Name("webSocketDisconnected")
}

// MARK: - String MD5扩展
extension String {
    var md5: String {
        let data = Data(self.utf8)
        let hash = data.withUnsafeBytes { bytes -> [UInt8] in
            var hash = [UInt8](repeating: 0, count: Int(CC_MD5_DIGEST_LENGTH))
            CC_MD5(bytes.bindMemory(to: UInt8.self).baseAddress, CC_LONG(data.count), &hash)
            return hash
        }
        return hash.map { String(format: "%02x", $0) }.joined()
    }
}

// 需要导入CommonCrypto
import CommonCrypto
