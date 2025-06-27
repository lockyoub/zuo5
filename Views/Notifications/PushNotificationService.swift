//
//  PushNotificationService.swift
//  StockTradingApp
//
//  Created by MiniMax Agent on 2025-06-24.
//  推送通知服务 - 处理远程推送通知和实时通信
//

import Foundation
import UserNotifications
import UIKit
import Combine

/// 推送通知服务 - 处理远程推送和WebSocket实时通知
class PushNotificationService: NSObject, ObservableObject {
    
    // MARK: - 发布属性
    @Published var deviceToken: String?
    @Published var isRegistered = false
    @Published var lastError: Error?
    
    // MARK: - 私有属性
    private let networkManager = EnhancedNetworkManager()
    private var webSocketTask: URLSessionWebSocketTask?
    private var cancellables = Set<AnyCancellable>()
    private let notificationManager = NotificationManager.shared
    
    // MARK: - 单例
    static let shared = PushNotificationService()
    
    override init() {
        super.init()
        setupObservers()
    }
    
    // MARK: - 设备注册
    func registerForRemoteNotifications() async {
        guard await UNUserNotificationCenter.current().getNotificationSettings().authorizationStatus == .authorized else {
            print("通知权限未授权")
            return
        }
        
        await MainActor.run {
            UIApplication.shared.registerForRemoteNotifications()
        }
    }
    
    func handleDeviceTokenRegistration(deviceToken: Data) {
        let tokenString = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
        self.deviceToken = tokenString
        
        Task {
            await registerDeviceWithServer(token: tokenString)
        }
    }
    
    func handleRegistrationError(_ error: Error) {
        lastError = error
        print("远程通知注册失败: \(error)")
    }
    
    // MARK: - 服务器注册
    private func registerDeviceWithServer(token: String) async {
        do {
            let request = DeviceRegistrationRequest(
                deviceToken: token,
                platform: "ios",
                appVersion: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0",
                systemVersion: UIDevice.current.systemVersion,
                deviceModel: UIDevice.current.model
            )
            
            let response = try await networkManager.registerDevice(request: request)
            
            await MainActor.run {
                isRegistered = response.success
                if response.success {
                    print("设备注册成功: \(token)")
                } else {
                    print("设备注册失败: \(response.message ?? "未知错误")")
                }
            }
            
        } catch {
            await MainActor.run {
                lastError = error
                isRegistered = false
            }
            print("设备注册请求失败: \(error)")
        }
    }
    
    // MARK: - WebSocket连接
    func connectWebSocket() {
        guard let url = URL(string: "wss://your-server.com/ws/notifications") else {
            print("WebSocket URL 无效")
            return
        }
        
        webSocketTask = URLSession.shared.webSocketTask(with: url)
        webSocketTask?.resume()
        
        // 开始监听消息
        listenForWebSocketMessages()
        
        // 发送心跳
        startHeartbeat()
        
        print("WebSocket连接已建立")
    }
    
    func disconnectWebSocket() {
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil
        print("WebSocket连接已断开")
    }
    
    private func listenForWebSocketMessages() {
        webSocketTask?.receive { [weak self] result in
            switch result {
            case .success(let message):
                self?.handleWebSocketMessage(message)
                // 继续监听下一条消息
                self?.listenForWebSocketMessages()
                
            case .failure(let error):
                print("WebSocket接收消息失败: \(error)")
                // 尝试重连
                DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                    self?.connectWebSocket()
                }
            }
        }
    }
    
    private func handleWebSocketMessage(_ message: URLSessionWebSocketTask.Message) {
        switch message {
        case .string(let text):
            handleWebSocketTextMessage(text)
        case .data(let data):
            handleWebSocketDataMessage(data)
        @unknown default:
            print("未知的WebSocket消息类型")
        }
    }
    
    private func handleWebSocketTextMessage(_ text: String) {
        guard let data = text.data(using: .utf8) else { return }
        
        do {
            let notification = try JSONDecoder().decode(RealtimeNotification.self, from: data)
            
            DispatchQueue.main.async {
                self.processRealtimeNotification(notification)
            }
            
        } catch {
            print("解析WebSocket消息失败: \(error)")
        }
    }
    
    private func handleWebSocketDataMessage(_ data: Data) {
        // 处理二进制数据（如果需要）
        print("收到WebSocket二进制数据: \(data.count) bytes")
    }
    
    private func startHeartbeat() {
        Timer.publish(every: 30, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.sendHeartbeat()
            }
            .store(in: &cancellables)
    }
    
    private func sendHeartbeat() {
        let heartbeat = HeartbeatMessage(
            type: "heartbeat",
            timestamp: Date().timeIntervalSince1970,
            deviceToken: deviceToken
        )
        
        if let data = try? JSONEncoder().encode(heartbeat),
           let text = String(data: data, encoding: .utf8) {
            webSocketTask?.send(.string(text)) { error in
                if let error = error {
                    print("发送心跳失败: \(error)")
                }
            }
        }
    }
    
    // MARK: - 实时通知处理
    private func processRealtimeNotification(_ realtimeNotification: RealtimeNotification) {
        let tradingNotification = TradingNotification(
            type: NotificationType(rawValue: realtimeNotification.type) ?? .tradingSignal,
            title: realtimeNotification.title,
            message: realtimeNotification.message,
            stockCode: realtimeNotification.stockCode,
            stockName: realtimeNotification.stockName,
            orderID: realtimeNotification.orderID,
            price: realtimeNotification.price,
            quantity: realtimeNotification.quantity,
            strategyName: realtimeNotification.strategyName,
            priority: NotificationPriority(rawValue: realtimeNotification.priority) ?? .medium
        )
        
        notificationManager.sendTradingNotification(tradingNotification)
    }
    
    // MARK: - 推送消息处理
    func handleRemoteNotification(_ userInfo: [AnyHashable: Any]) -> Bool {
        guard let aps = userInfo["aps"] as? [String: Any] else {
            return false
        }
        
        // 提取推送内容
        let title = (aps["alert"] as? [String: Any])?["title"] as? String ?? ""
        let message = (aps["alert"] as? [String: Any])?["body"] as? String ?? ""
        
        // 提取自定义数据
        let type = userInfo["type"] as? String ?? "tradingSignal"
        let stockCode = userInfo["stockCode"] as? String
        let stockName = userInfo["stockName"] as? String
        let orderID = userInfo["orderID"] as? String
        let price = userInfo["price"] as? Double
        let quantity = userInfo["quantity"] as? Int
        let strategyName = userInfo["strategyName"] as? String
        let priority = userInfo["priority"] as? String ?? "medium"
        
        // 创建本地通知
        let notification = TradingNotification(
            type: NotificationType(rawValue: type) ?? .tradingSignal,
            title: title,
            message: message,
            stockCode: stockCode,
            stockName: stockName,
            orderID: orderID,
            price: price,
            quantity: quantity,
            strategyName: strategyName,
            priority: NotificationPriority(rawValue: priority) ?? .medium
        )
        
        notificationManager.sendTradingNotification(notification)
        
        return true
    }
    
    // MARK: - 设置观察者
    private func setupObservers() {
        // 监听应用状态变化
        NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)
            .sink { [weak self] _ in
                self?.connectWebSocket()
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)
            .sink { [weak self] _ in
                self?.disconnectWebSocket()
            }
            .store(in: &cancellables)
    }
    
    // MARK: - 通知订阅管理
    func subscribeToStock(_ stockCode: String) async {
        do {
            let request = SubscriptionRequest(
                deviceToken: deviceToken ?? "",
                action: "subscribe",
                stockCodes: [stockCode],
                notificationTypes: ["all"]
            )
            
            try await networkManager.updateSubscription(request: request)
            print("已订阅股票通知: \(stockCode)")
            
        } catch {
            print("订阅股票通知失败: \(error)")
        }
    }
    
    func unsubscribeFromStock(_ stockCode: String) async {
        do {
            let request = SubscriptionRequest(
                deviceToken: deviceToken ?? "",
                action: "unsubscribe",
                stockCodes: [stockCode],
                notificationTypes: ["all"]
            )
            
            try await networkManager.updateSubscription(request: request)
            print("已取消订阅股票通知: \(stockCode)")
            
        } catch {
            print("取消订阅股票通知失败: \(error)")
        }
    }
    
    func updateNotificationPreferences(_ preferences: NotificationPreferences) async {
        do {
            let request = PreferencesUpdateRequest(
                deviceToken: deviceToken ?? "",
                preferences: preferences
            )
            
            try await networkManager.updateNotificationPreferences(request: request)
            print("通知偏好设置已更新")
            
        } catch {
            print("更新通知偏好设置失败: \(error)")
        }
    }
}

// MARK: - 数据模型
struct DeviceRegistrationRequest: Codable {
    let deviceToken: String
    let platform: String
    let appVersion: String
    let systemVersion: String
    let deviceModel: String
}

struct DeviceRegistrationResponse: Codable {
    let success: Bool
    let message: String?
    let deviceId: String?
}

struct RealtimeNotification: Codable {
    let id: String
    let type: String
    let title: String
    let message: String
    let timestamp: TimeInterval
    let stockCode: String?
    let stockName: String?
    let orderID: String?
    let price: Double?
    let quantity: Int?
    let strategyName: String?
    let priority: String
}

struct HeartbeatMessage: Codable {
    let type: String
    let timestamp: TimeInterval
    let deviceToken: String?
}

struct SubscriptionRequest: Codable {
    let deviceToken: String
    let action: String // "subscribe" or "unsubscribe"
    let stockCodes: [String]
    let notificationTypes: [String]
}

struct NotificationPreferences: Codable {
    let tradingNotifications: Bool
    let riskAlerts: Bool
    let strategySignals: Bool
    let priceAlerts: Bool
    let volumeAlerts: Bool
    let quietHours: QuietHours?
}

struct QuietHours: Codable {
    let enabled: Bool
    let startTime: String // "HH:mm" format
    let endTime: String // "HH:mm" format
    let timezone: String
}

struct PreferencesUpdateRequest: Codable {
    let deviceToken: String
    let preferences: NotificationPreferences
}

// MARK: - 网络管理器扩展
extension EnhancedNetworkManager {
    func registerDevice(request: DeviceRegistrationRequest) async throws -> DeviceRegistrationResponse {
        // 实现设备注册网络请求
        // 这里应该调用实际的API端点
        return DeviceRegistrationResponse(
            success: true,
            message: "设备注册成功",
            deviceId: UUID().uuidString
        )
    }
    
    func updateSubscription(request: SubscriptionRequest) async throws {
        // 实现订阅更新网络请求
        // 这里应该调用实际的API端点
    }
    
    func updateNotificationPreferences(request: PreferencesUpdateRequest) async throws {
        // 实现通知偏好设置更新网络请求
        // 这里应该调用实际的API端点
    }
}
