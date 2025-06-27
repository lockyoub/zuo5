//
//  NotificationManager.swift
//  StockTradingApp
//
//  Created by MiniMax Agent on 2025-06-24.
//  通知管理器 - 处理所有类型的交易和风险通知
//

import Foundation
import UserNotifications
import SwiftUI
import Combine

/// 通知管理器 - 统一管理所有通知功能
@MainActor
class NotificationManager: NSObject, ObservableObject {
    
    // MARK: - 发布属性
    @Published var isAuthorized = false
    @Published var notifications: [TradingNotification] = []
    @Published var unreadCount = 0
    @Published var settings = NotificationSettings()
    
    // MARK: - 私有属性
    private let center = UNUserNotificationCenter.current()
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - 单例
    static let shared = NotificationManager()
    
    override init() {
        super.init()
        center.delegate = self
        setupNotificationObservers()
    }
    
    // MARK: - 权限管理
    func requestAuthorization() async {
        do {
            let options: UNAuthorizationOptions = [.alert, .badge, .sound, .provisional]
            isAuthorized = try await center.requestAuthorization(options: options)
            
            if isAuthorized {
                await registerForRemoteNotifications()
                setupNotificationCategories()
            }
        } catch {
            print("通知权限请求失败: \(error)")
        }
    }
    
    func checkAuthorizationStatus() async {
        let settings = await center.getNotificationSettings()
        isAuthorized = settings.authorizationStatus == .authorized
    }
    
    // MARK: - 交易通知
    func sendTradingNotification(_ notification: TradingNotification) {
        guard isAuthorized && settings.isTradingNotificationEnabled else { return }
        
        let content = createNotificationContent(for: notification)
        let request = UNNotificationRequest(
            identifier: notification.id.uuidString,
            content: content,
            trigger: nil
        )
        
        center.add(request) { error in
            if let error = error {
                print("发送交易通知失败: \(error)")
            }
        }
        
        // 添加到本地通知列表
        notifications.insert(notification, at: 0)
        if !notification.isRead {
            unreadCount += 1
        }
    }
    
    /// 订单状态变化通知
    func notifyOrderStatusChange(orderID: String, status: OrderStatus, stockCode: String, stockName: String) {
        let notification = TradingNotification(
            type: .orderStatus,
            title: "订单状态更新",
            message: "\(stockName)(\(stockCode)) 订单\(status.displayName)",
            stockCode: stockCode,
            orderID: orderID,
            priority: .high
        )
        sendTradingNotification(notification)
    }
    
    /// 成交确认通知
    func notifyTradeExecuted(orderID: String, stockCode: String, stockName: String, quantity: Int, price: Double, side: TradeSide) {
        let sideText = side == .buy ? "买入" : "卖出"
        let notification = TradingNotification(
            type: .tradeExecution,
            title: "交易成交",
            message: "\(sideText)\(stockName)(\(stockCode)) \(quantity)股，价格￥\(String(format: "%.2f", price))",
            stockCode: stockCode,
            orderID: orderID,
            price: price,
            quantity: quantity,
            priority: .high
        )
        sendTradingNotification(notification)
    }
    
    /// 交易失败通知
    func notifyTradeFailed(orderID: String, stockCode: String, stockName: String, reason: String) {
        let notification = TradingNotification(
            type: .tradeFailed,
            title: "交易失败",
            message: "\(stockName)(\(stockCode)) 交易失败: \(reason)",
            stockCode: stockCode,
            orderID: orderID,
            priority: .high
        )
        sendTradingNotification(notification)
    }
    
    // MARK: - 风险预警通知
    func sendRiskAlert(_ alert: RiskAlert) {
        guard isAuthorized && settings.isRiskAlertEnabled else { return }
        
        let notification = TradingNotification(
            type: .riskAlert,
            title: "风险预警",
            message: alert.message,
            stockCode: alert.stockCode,
            riskLevel: alert.level,
            priority: .critical
        )
        sendTradingNotification(notification)
    }
    
    /// 止损触发警告
    func notifyStopLossTriggered(stockCode: String, stockName: String, currentPrice: Double, stopLossPrice: Double) {
        let notification = TradingNotification(
            type: .stopLoss,
            title: "止损触发",
            message: "\(stockName)(\(stockCode)) 价格\(String(format: "%.2f", currentPrice))，已触发止损\(String(format: "%.2f", stopLossPrice))",
            stockCode: stockCode,
            price: currentPrice,
            priority: .critical
        )
        sendTradingNotification(notification)
    }
    
    /// 持仓风险提示
    func notifyPositionRisk(stockCode: String, stockName: String, riskLevel: RiskLevel, details: String) {
        let notification = TradingNotification(
            type: .positionRisk,
            title: "持仓风险",
            message: "\(stockName)(\(stockCode)) \(riskLevel.displayName)风险: \(details)",
            stockCode: stockCode,
            riskLevel: riskLevel,
            priority: riskLevel == .high ? .critical : .medium
        )
        sendTradingNotification(notification)
    }
    
    // MARK: - 策略信号通知
    func sendStrategySignal(_ signal: StrategySignal) {
        guard isAuthorized && settings.isStrategySignalEnabled else { return }
        
        let notification = TradingNotification(
            type: .strategySignal,
            title: "策略信号",
            message: signal.description,
            stockCode: signal.stockCode,
            strategyName: signal.strategyName,
            signalType: signal.type,
            priority: .medium
        )
        sendTradingNotification(notification)
    }
    
    /// 买卖信号推送
    func notifyTradingSignal(stockCode: String, stockName: String, signal: SignalType, strategyName: String, price: Double, confidence: Double) {
        let signalText = signal == .buy ? "买入" : "卖出"
        let confidenceText = String(format: "%.0f%%", confidence * 100)
        
        let notification = TradingNotification(
            type: .tradingSignal,
            title: "\(signalText)信号",
            message: "\(strategyName): \(stockName)(\(stockCode)) \(signalText)信号，价格\(String(format: "%.2f", price))，置信度\(confidenceText)",
            stockCode: stockCode,
            strategyName: strategyName,
            price: price,
            signalType: signal,
            priority: confidence > 0.8 ? .high : .medium
        )
        sendTradingNotification(notification)
    }
    
    // MARK: - 通知管理
    func markAsRead(_ notificationID: UUID) {
        if let index = notifications.firstIndex(where: { $0.id == notificationID }) {
            notifications[index].isRead = true
            unreadCount = max(0, unreadCount - 1)
        }
    }
    
    func markAllAsRead() {
        notifications.indices.forEach { notifications[$0].isRead = true }
        unreadCount = 0
    }
    
    func clearNotification(_ notificationID: UUID) {
        notifications.removeAll { $0.id == notificationID }
        center.removePendingNotificationRequests(withIdentifiers: [notificationID.uuidString])
        center.removeDeliveredNotifications(withIdentifiers: [notificationID.uuidString])
    }
    
    func clearAllNotifications() {
        notifications.removeAll()
        unreadCount = 0
        center.removeAllPendingNotificationRequests()
        center.removeAllDeliveredNotifications()
    }
    
    // MARK: - 私有方法
    private func setupNotificationObservers() {
        // 监听应用状态变化
        NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)
            .sink { [weak self] _ in
                Task {
                    await self?.checkAuthorizationStatus()
                }
            }
            .store(in: &cancellables)
    }
    
    private func registerForRemoteNotifications() async {
        await UIApplication.shared.registerForRemoteNotifications()
    }
    
    private func setupNotificationCategories() {
        let tradingCategory = UNNotificationCategory(
            identifier: "TRADING",
            actions: [
                UNNotificationAction(identifier: "VIEW_DETAIL", title: "查看详情", options: []),
                UNNotificationAction(identifier: "MARK_READ", title: "标记已读", options: [])
            ],
            intentIdentifiers: [],
            options: []
        )
        
        let riskCategory = UNNotificationCategory(
            identifier: "RISK",
            actions: [
                UNNotificationAction(identifier: "VIEW_POSITION", title: "查看持仓", options: []),
                UNNotificationAction(identifier: "EMERGENCY_STOP", title: "紧急止损", options: [.destructive])
            ],
            intentIdentifiers: [],
            options: []
        )
        
        center.setNotificationCategories([tradingCategory, riskCategory])
    }
    
    private func createNotificationContent(for notification: TradingNotification) -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        content.title = notification.title
        content.body = notification.message
        content.sound = notification.priority == .critical ? .critical : .default
        content.badge = NSNumber(value: unreadCount + 1)
        
        // 设置分类
        switch notification.type {
        case .orderStatus, .tradeExecution, .tradeFailed, .tradingSignal:
            content.categoryIdentifier = "TRADING"
        case .riskAlert, .stopLoss, .positionRisk:
            content.categoryIdentifier = "RISK"
        case .strategySignal:
            content.categoryIdentifier = "TRADING"
        }
        
        // 设置用户信息
        content.userInfo = [
            "notificationID": notification.id.uuidString,
            "stockCode": notification.stockCode ?? "",
            "type": notification.type.rawValue
        ]
        
        return content
    }
}

// MARK: - UNUserNotificationCenterDelegate
extension NotificationManager: UNUserNotificationCenterDelegate {
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // 应用在前台时显示通知
        completionHandler([.banner, .sound, .badge])
    }
    
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        // 处理通知点击
        let userInfo = response.notification.request.content.userInfo
        
        if let notificationIDString = userInfo["notificationID"] as? String,
           let notificationID = UUID(uuidString: notificationIDString) {
            
            switch response.actionIdentifier {
            case "VIEW_DETAIL":
                // 跳转到详情页面
                handleViewDetail(notificationID: notificationID)
            case "MARK_READ":
                markAsRead(notificationID)
            case "VIEW_POSITION":
                // 跳转到持仓页面
                handleViewPosition()
            case "EMERGENCY_STOP":
                // 执行紧急止损
                handleEmergencyStop(userInfo: userInfo)
            default:
                // 默认处理
                markAsRead(notificationID)
            }
        }
        
        completionHandler()
    }
    
    private func handleViewDetail(notificationID: UUID) {
        // TODO: 实现跳转到通知详情页面
        markAsRead(notificationID)
    }
    
    private func handleViewPosition() {
        // TODO: 实现跳转到持仓页面
    }
    
    private func handleEmergencyStop(userInfo: [AnyHashable: Any]) {
        // TODO: 实现紧急止损逻辑
        if let stockCode = userInfo["stockCode"] as? String {
            print("紧急止损: \(stockCode)")
        }
    }
}

// MARK: - 数据模型
struct TradingNotification: Identifiable, Codable {
    let id = UUID()
    let type: NotificationType
    let title: String
    let message: String
    let timestamp: Date
    var isRead: Bool
    
    // 可选属性
    let stockCode: String?
    let stockName: String?
    let orderID: String?
    let price: Double?
    let quantity: Int?
    let strategyName: String?
    let riskLevel: RiskLevel?
    let signalType: SignalType?
    let priority: NotificationPriority
    
    init(
        type: NotificationType,
        title: String,
        message: String,
        stockCode: String? = nil,
        stockName: String? = nil,
        orderID: String? = nil,
        price: Double? = nil,
        quantity: Int? = nil,
        strategyName: String? = nil,
        riskLevel: RiskLevel? = nil,
        signalType: SignalType? = nil,
        priority: NotificationPriority = .medium
    ) {
        self.type = type
        self.title = title
        self.message = message
        self.timestamp = Date()
        self.isRead = false
        self.stockCode = stockCode
        self.stockName = stockName
        self.orderID = orderID
        self.price = price
        self.quantity = quantity
        self.strategyName = strategyName
        self.riskLevel = riskLevel
        self.signalType = signalType
        self.priority = priority
    }
}

enum NotificationType: String, Codable, CaseIterable {
    case orderStatus = "order_status"
    case tradeExecution = "trade_execution"
    case tradeFailed = "trade_failed"
    case riskAlert = "risk_alert"
    case stopLoss = "stop_loss"
    case positionRisk = "position_risk"
    case strategySignal = "strategy_signal"
    case tradingSignal = "trading_signal"
    
    var displayName: String {
        switch self {
        case .orderStatus: return "订单状态"
        case .tradeExecution: return "交易成交"
        case .tradeFailed: return "交易失败"
        case .riskAlert: return "风险预警"
        case .stopLoss: return "止损触发"
        case .positionRisk: return "持仓风险"
        case .strategySignal: return "策略信号"
        case .tradingSignal: return "交易信号"
        }
    }
}

enum NotificationPriority: String, Codable {
    case low, medium, high, critical
    
    var displayName: String {
        switch self {
        case .low: return "低"
        case .medium: return "中"
        case .high: return "高"
        case .critical: return "紧急"
        }
    }
}

enum SignalType: String, Codable {
    case buy, sell, hold
    
    var displayName: String {
        switch self {
        case .buy: return "买入"
        case .sell: return "卖出"
        case .hold: return "持有"
        }
    }
}

enum RiskLevel: String, Codable {
    case low, medium, high
    
    var displayName: String {
        switch self {
        case .low: return "低"
        case .medium: return "中"
        case .high: return "高"
        }
    }
}

// MARK: - 支持数据结构
struct RiskAlert {
    let stockCode: String
    let message: String
    let level: RiskLevel
    let timestamp: Date
}

struct StrategySignal {
    let stockCode: String
    let strategyName: String
    let type: SignalType
    let description: String
    let confidence: Double
    let timestamp: Date
}

enum OrderStatus: String, Codable {
    case pending = "pending"
    case partiallyFilled = "partially_filled"
    case filled = "filled"
    case cancelled = "cancelled"
    case rejected = "rejected"
    
    var displayName: String {
        switch self {
        case .pending: return "待成交"
        case .partiallyFilled: return "部分成交"
        case .filled: return "已成交"
        case .cancelled: return "已取消"
        case .rejected: return "已拒绝"
        }
    }
}

enum TradeSide: String, Codable {
    case buy, sell
}

// MARK: - 通知设置
struct NotificationSettings: Codable {
    var isTradingNotificationEnabled = true
    var isRiskAlertEnabled = true
    var isStrategySignalEnabled = true
    var isPriceAlertEnabled = true
    var isVolumeAlertEnabled = false
    var quietHoursEnabled = false
    var quietStartTime = "22:00"
    var quietEndTime = "08:00"
    var soundEnabled = true
    var vibrationEnabled = true
    var badgeEnabled = true
}
