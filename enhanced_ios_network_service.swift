/*
 增强的iOS网络服务
 支持米筐和必盈数据源的完整数据获取
 作者: MiniMax Agent
 创建时间: 2025-06-27
 */

import Foundation
import Combine
import SwiftUI

// MARK: - API配置
struct APIConfig {
    static let baseURL = "http://8.130.172.202:8000"  // 您的阿里云服务器IP
    static let apiVersion = "/api"
    static let websocketURL = "ws://8.130.172.202:8000/ws/market"
    static let timeout: TimeInterval = 30
}

// MARK: - 数据模型

struct APIResponse<T: Codable>: Codable {
    let status: String
    let data: T?
    let message: String
    let timestamp: String
}

struct StockQuoteData: Codable, Identifiable {
    let id = UUID()
    let symbol: String
    let name: String
    let price: Double
    let change: Double
    let changePercent: Double
    let volume: Int
    let amount: Double
    let high: Double
    let low: Double
    let open: Double
    let prevClose: Double
    let timestamp: String
    let source: String
    
    private enum CodingKeys: String, CodingKey {
        case symbol, name, price, change, volume, amount, high, low, open, timestamp, source
        case changePercent = "change_percent"
        case prevClose = "prev_close"
    }
}

struct OrderBookData: Codable, Identifiable {
    let id = UUID()
    let symbol: String
    let timestamp: String
    let bidPrices: [Double]
    let bidVolumes: [Int]
    let askPrices: [Double] 
    let askVolumes: [Int]
    let source: String
    
    private enum CodingKeys: String, CodingKey {
        case symbol, timestamp, source
        case bidPrices = "bid_prices"
        case bidVolumes = "bid_volumes"
        case askPrices = "ask_prices"
        case askVolumes = "ask_volumes"
    }
}

struct CompleteStockData: Codable, Identifiable {
    let id = UUID()
    let symbol: String
    let timestamp: String
    let quote: StockQuoteData?
    let orderBook: OrderBookData?
    let quoteError: String?
    let orderBookError: String?
    
    private enum CodingKeys: String, CodingKey {
        case symbol, timestamp, quote
        case orderBook = "order_book"
        case quoteError = "quote_error"
        case orderBookError = "order_book_error"
    }
}

struct KLineData: Codable, Identifiable {
    let id = UUID()
    let symbol: String
    let timestamp: String
    let open: Double
    let high: Double
    let low: Double
    let close: Double
    let volume: Int
    let amount: Double
    let period: String
    let source: String
}

struct HealthStatus: Codable {
    let overallStatus: String
    let services: [String: ServiceStatus]
    let timestamp: String
    
    private enum CodingKeys: String, CodingKey {
        case timestamp, services
        case overallStatus = "overall_status"
    }
}

enum ServiceStatus: Codable {
    case healthy
    case error(String)
    case detailed([String: Any])
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let stringValue = try? container.decode(String.self) {
            if stringValue == "healthy" {
                self = .healthy
            } else {
                self = .error(stringValue)
            }
        } else if let dictValue = try? container.decode([String: Any].self) {
            self = .detailed(dictValue)
        } else {
            self = .error("Unknown status format")
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .healthy:
            try container.encode("healthy")
        case .error(let message):
            try container.encode(message)
        case .detailed(let dict):
            try container.encode(dict)
        }
    }
}

// MARK: - WebSocket消息
struct WebSocketMessage: Codable {
    let type: String
    let data: CompleteStockData?
    let status: String?
    let symbol: String?
    let message: String?
}

// MARK: - 网络错误
enum NetworkError: Error, LocalizedError {
    case invalidURL
    case noData
    case decodingError(Error)
    case serverError(String)
    case networkError(Error)
    case authenticationRequired
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "无效的URL"
        case .noData:
            return "没有数据"
        case .decodingError(let error):
            return "数据解析错误: \(error.localizedDescription)"
        case .serverError(let message):
            return "服务器错误: \(message)"
        case .networkError(let error):
            return "网络错误: \(error.localizedDescription)"
        case .authenticationRequired:
            return "需要身份验证"
        }
    }
}

// MARK: - 增强的网络服务
@MainActor
class EnhancedNetworkService: ObservableObject {
    
    // MARK: - Published Properties
    @Published var isConnected = false
    @Published var connectionStatus: ConnectionStatus = .disconnected
    @Published var lastError: NetworkError?
    @Published var healthStatus: HealthStatus?
    
    // MARK: - Private Properties
    private let session: URLSession
    private var webSocketTask: URLSessionWebSocketTask?
    private var cancellables = Set<AnyCancellable>()
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()
    
    // WebSocket相关
    private var subscriptions = Set<String>()
    private var reconnectTimer: Timer?
    private var heartbeatTimer: Timer?
    
    // 数据发布器
    let marketDataPublisher = PassthroughSubject<CompleteStockData, Never>()
    let healthUpdatePublisher = PassthroughSubject<HealthStatus, Never>()
    
    enum ConnectionStatus {
        case disconnected
        case connecting
        case connected
        case error(String)
    }
    
    // MARK: - 初始化
    init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = APIConfig.timeout
        config.timeoutIntervalForResource = APIConfig.timeout * 2
        self.session = URLSession(configuration: config)
        
        setupDateFormatters()
    }
    
    deinit {
        disconnectWebSocket()
        cancellables.removeAll()
    }
    
    private func setupDateFormatters() {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        decoder.dateDecodingStrategy = .formatted(formatter)
        encoder.dateEncodingStrategy = .formatted(formatter)
    }
    
    // MARK: - HTTP请求方法
    
    private func makeRequest<T: Codable>(
        endpoint: String,
        method: String = "GET",
        parameters: [String: Any]? = nil,
        responseType: T.Type
    ) async throws -> T {
        
        var urlComponents = URLComponents(string: "\(APIConfig.baseURL)\(endpoint)")!
        
        // 添加查询参数
        if let parameters = parameters, method == "GET" {
            urlComponents.queryItems = parameters.map { key, value in
                URLQueryItem(name: key, value: "\(value)")
            }
        }
        
        guard let url = urlComponents.url else {
            throw NetworkError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // POST请求体
        if method == "POST", let parameters = parameters {
            request.httpBody = try JSONSerialization.data(withJSONObject: parameters)
        }
        
        do {
            let (data, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw NetworkError.networkError(URLError(.badServerResponse))
            }
            
            if httpResponse.statusCode >= 400 {
                let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
                throw NetworkError.serverError("HTTP \(httpResponse.statusCode): \(errorMessage)")
            }
            
            let apiResponse = try decoder.decode(APIResponse<T>.self, from: data)
            
            if apiResponse.status == "error" {
                throw NetworkError.serverError(apiResponse.message)
            }
            
            guard let responseData = apiResponse.data else {
                throw NetworkError.noData
            }
            
            return responseData
            
        } catch let error as NetworkError {
            await MainActor.run {
                self.lastError = error
            }
            throw error
        } catch {
            let networkError = NetworkError.networkError(error)
            await MainActor.run {
                self.lastError = networkError
            }
            throw networkError
        }
    }
    
    // MARK: - API接口方法
    
    /// 获取股票实时行情
    func getStockQuote(symbol: String) async throws -> StockQuoteData {
        return try await makeRequest(
            endpoint: "\(APIConfig.apiVersion)/stocks/\(symbol)/quote",
            responseType: StockQuoteData.self
        )
    }
    
    /// 获取盘口数据
    func getOrderBook(symbol: String) async throws -> OrderBookData {
        return try await makeRequest(
            endpoint: "\(APIConfig.apiVersion)/stocks/\(symbol)/orderbook",
            responseType: OrderBookData.self
        )
    }
    
    /// 获取完整股票数据（行情+盘口）
    func getCompleteStockData(symbol: String) async throws -> CompleteStockData {
        return try await makeRequest(
            endpoint: "\(APIConfig.apiVersion)/stocks/\(symbol)/complete",
            responseType: CompleteStockData.self
        )
    }
    
    /// 获取K线数据
    func getKLineData(symbol: String, period: String = "1d", count: Int = 100) async throws -> [KLineData] {
        let parameters = [
            "period": period,
            "count": count
        ]
        return try await makeRequest(
            endpoint: "\(APIConfig.apiVersion)/stocks/\(symbol)/klines",
            parameters: parameters,
            responseType: [KLineData].self
        )
    }
    
    /// 获取股票列表
    func getStockList() async throws -> [[String: String]] {
        return try await makeRequest(
            endpoint: "\(APIConfig.apiVersion)/stocks/list",
            responseType: [[String: String]].self
        )
    }
    
    /// 健康检查
    func healthCheck() async throws -> HealthStatus {
        let status = try await makeRequest(
            endpoint: "/health",
            responseType: HealthStatus.self
        )
        
        await MainActor.run {
            self.healthStatus = status
            self.healthUpdatePublisher.send(status)
        }
        
        return status
    }
    
    // MARK: - WebSocket方法
    
    /// 连接WebSocket
    func connectWebSocket() {
        guard webSocketTask == nil else { return }
        
        guard let url = URL(string: APIConfig.websocketURL) else {
            connectionStatus = .error("无效的WebSocket URL")
            return
        }
        
        connectionStatus = .connecting
        webSocketTask = session.webSocketTask(with: url)
        webSocketTask?.resume()
        
        // 开始接收消息
        receiveWebSocketMessage()
        
        // 启动心跳
        startHeartbeat()
        
        connectionStatus = .connected
        isConnected = true
    }
    
    /// 断开WebSocket连接
    func disconnectWebSocket() {
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil
        
        reconnectTimer?.invalidate()
        reconnectTimer = nil
        
        heartbeatTimer?.invalidate()
        heartbeatTimer = nil
        
        connectionStatus = .disconnected
        isConnected = false
        subscriptions.removeAll()
    }
    
    /// 订阅股票数据
    func subscribeToStock(_ symbol: String) async {
        guard isConnected else {
            connectWebSocket()
            // 等待连接建立
            try? await Task.sleep(nanoseconds: 1_000_000_000) // 1秒
        }
        
        let message = [
            "action": "subscribe",
            "symbol": symbol
        ]
        
        await sendWebSocketMessage(message)
        subscriptions.insert(symbol)
    }
    
    /// 取消订阅股票数据
    func unsubscribeFromStock(_ symbol: String) async {
        let message = [
            "action": "unsubscribe", 
            "symbol": symbol
        ]
        
        await sendWebSocketMessage(message)
        subscriptions.remove(symbol)
    }
    
    /// 发送WebSocket消息
    private func sendWebSocketMessage(_ message: [String: Any]) async {
        guard let webSocketTask = webSocketTask else { return }
        
        do {
            let data = try JSONSerialization.data(withJSONObject: message)
            let webSocketMessage = URLSessionWebSocketTask.Message.data(data)
            try await webSocketTask.send(webSocketMessage)
        } catch {
            print("发送WebSocket消息失败: \(error)")
        }
    }
    
    /// 接收WebSocket消息
    private func receiveWebSocketMessage() {
        webSocketTask?.receive { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case .success(let message):
                self.handleWebSocketMessage(message)
                self.receiveWebSocketMessage() // 继续接收下一条消息
                
            case .failure(let error):
                DispatchQueue.main.async {
                    self.connectionStatus = .error("WebSocket错误: \(error.localizedDescription)")
                    self.isConnected = false
                }
                self.scheduleReconnect()
            }
        }
    }
    
    /// 处理WebSocket消息
    private func handleWebSocketMessage(_ message: URLSessionWebSocketTask.Message) {
        var messageData: Data
        
        switch message {
        case .data(let data):
            messageData = data
        case .string(let string):
            messageData = string.data(using: .utf8) ?? Data()
        @unknown default:
            return
        }
        
        do {
            let webSocketMessage = try decoder.decode(WebSocketMessage.self, from: messageData)
            
            DispatchQueue.main.async {
                switch webSocketMessage.type {
                case "market_data":
                    if let data = webSocketMessage.data {
                        self.marketDataPublisher.send(data)
                    }
                case "subscription":
                    print("订阅状态: \(webSocketMessage.status ?? "") - \(webSocketMessage.message ?? "")")
                default:
                    print("未知的WebSocket消息类型: \(webSocketMessage.type)")
                }
            }
            
        } catch {
            print("WebSocket消息解析失败: \(error)")
        }
    }
    
    /// 启动心跳
    private func startHeartbeat() {
        heartbeatTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [weak self] _ in
            Task {
                await self?.sendWebSocketMessage(["type": "ping"])
            }
        }
    }
    
    /// 计划重连
    private func scheduleReconnect() {
        reconnectTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: false) { [weak self] _ in
            self?.connectWebSocket()
        }
    }
    
    // MARK: - 便捷方法
    
    /// 批量获取股票数据
    func getMultipleStocksData(_ symbols: [String]) async -> [String: CompleteStockData] {
        var results: [String: CompleteStockData] = [:]
        
        await withTaskGroup(of: (String, CompleteStockData?).self) { group in
            for symbol in symbols {
                group.addTask {
                    do {
                        let data = try await self.getCompleteStockData(symbol: symbol)
                        return (symbol, data)
                    } catch {
                        print("获取\(symbol)数据失败: \(error)")
                        return (symbol, nil)
                    }
                }
            }
            
            for await (symbol, data) in group {
                if let data = data {
                    results[symbol] = data
                }
            }
        }
        
        return results
    }
    
    /// 检查服务可用性
    func checkServiceAvailability() async -> Bool {
        do {
            let status = try await healthCheck()
            return status.overallStatus == "healthy"
        } catch {
            return false
        }
    }
    
    /// 获取错误描述
    func getLastErrorDescription() -> String? {
        return lastError?.localizedDescription
    }
}

// MARK: - 扩展：辅助功能

extension EnhancedNetworkService {
    
    /// 格式化价格
    static func formatPrice(_ price: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSNumber(value: price)) ?? "\(price)"
    }
    
    /// 格式化涨跌幅
    static func formatChangePercent(_ percent: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .percent
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        formatter.positivePrefix = "+"
        return formatter.string(from: NSNumber(value: percent / 100)) ?? "\(percent)%"
    }
    
    /// 获取涨跌颜色
    static func getChangeColor(_ change: Double) -> Color {
        if change > 0 {
            return .red  // 中国股市红涨
        } else if change < 0 {
            return .green  // 中国股市绿跌
        } else {
            return .primary
        }
    }
}

// MARK: - 使用示例

/*
// 在View中使用
struct ContentView: View {
    @StateObject private var networkService = EnhancedNetworkService()
    @State private var stockData: CompleteStockData?
    @State private var isLoading = false
    
    var body: some View {
        VStack {
            if let stockData = stockData {
                StockDataView(data: stockData)
            }
            
            Button("获取数据") {
                Task {
                    isLoading = true
                    defer { isLoading = false }
                    
                    do {
                        stockData = try await networkService.getCompleteStockData(symbol: "000001.SZ")
                    } catch {
                        print("获取数据失败: \(error)")
                    }
                }
            }
            .disabled(isLoading)
        }
        .onAppear {
            networkService.connectWebSocket()
            
            // 订阅实时数据
            networkService.marketDataPublisher
                .receive(on: DispatchQueue.main)
                .sink { data in
                    self.stockData = data
                }
                .store(in: &cancellables)
        }
    }
}
*/
