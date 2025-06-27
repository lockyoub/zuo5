/*
 实时风险监控系统
 作者: MiniMax Agent
 创建日期: 2025-06-24
 
 实现实时风险监控、预警、自动止损等功能
 */

import Foundation
import CoreData
import Combine

/// 实时风险监控器
@MainActor
public class RealTimeRiskMonitor: ObservableObject {
    
    // MARK: - Published Properties
    @Published var isMonitoring: Bool = false
    @Published var riskAlerts: [RealTimeRiskAlert] = []
    @Published var accountStatus: AccountStatus = .normal
    @Published var positionRisks: [String: PositionRisk] = [:]
    @Published var emergencyStops: [EmergencyStop] = []
    @Published var monitoringMetrics: MonitoringMetrics = MonitoringMetrics()
    
    // MARK: - Private Properties
    private let persistenceController = PersistenceController.shared
    private var cancellables = Set<AnyCancellable>()
    private var riskManager: RiskManager?
    private var tradingService: EnhancedTradingService?
    private var marketDataService: MarketDataService?
    
    private var monitoringTimer: Timer?
    private var riskThresholds: RiskThresholds
    private var alertHistory: [RealTimeRiskAlert] = []
    
    // MARK: - 初始化
    init(riskThresholds: RiskThresholds = RiskThresholds.defaultThresholds()) {
        self.riskThresholds = riskThresholds
        setupRiskMonitoring()
    }
    
    deinit {
        stopMonitoring()
    }
    
    // MARK: - 监控控制
    
    /// 开始监控
    /// - Parameters:
    ///   - riskManager: 风险管理器
    ///   - tradingService: 交易服务
    ///   - marketDataService: 市场数据服务
    public func startMonitoring(
        riskManager: RiskManager,
        tradingService: EnhancedTradingService,
        marketDataService: MarketDataService
    ) {
        self.riskManager = riskManager
        self.tradingService = tradingService
        self.marketDataService = marketDataService
        
        isMonitoring = true
        
        // 启动定时监控
        monitoringTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.performRealTimeRiskCheck()
            }
        }
        
        print("实时风险监控已启动")
    }
    
    /// 停止监控
    public func stopMonitoring() {
        isMonitoring = false
        monitoringTimer?.invalidate()
        monitoringTimer = nil
        
        print("实时风险监控已停止")
    }
    
    // MARK: - 实时资金监控
    
    /// 监控账户余额
    public func monitorAccountBalance() async {
        guard let tradingService = tradingService else { return }
        
        await tradingService.refreshAccountInfo()
        let accountInfo = tradingService.accountInfo
        
        // 检查可用资金
        if accountInfo.availableCash < riskThresholds.minCashReserve {
            let alert = RealTimeRiskAlert(
                type: .cashShortage,
                level: .high,
                message: "可用资金不足",
                currentValue: accountInfo.availableCash,
                threshold: riskThresholds.minCashReserve,
                timestamp: Date(),
                action: .requireAttention
            )
            addRiskAlert(alert)
        }
        
        // 检查保证金使用率
        let marginUsageRatio = accountInfo.totalAssets > 0 ? accountInfo.marginUsed / accountInfo.totalAssets : 0
        if marginUsageRatio > riskThresholds.maxMarginUsage {
            let alert = RealTimeRiskAlert(
                type: .marginExcess,
                level: .critical,
                message: "保证金使用过高",
                currentValue: marginUsageRatio,
                threshold: riskThresholds.maxMarginUsage,
                timestamp: Date(),
                action: .autoReduce
            )
            addRiskAlert(alert)
            
            // 触发自动减仓
            await triggerAutoPositionReduction()
        }
        
        // 检查账户总盈亏
        let totalPnLRatio = accountInfo.totalAssets > 0 ? accountInfo.totalPnL / accountInfo.totalAssets : 0
        if totalPnLRatio < -riskThresholds.maxTotalLossRatio {
            let alert = RealTimeRiskAlert(
                type: .totalLoss,
                level: .critical,
                message: "账户总亏损过大",
                currentValue: abs(totalPnLRatio),
                threshold: riskThresholds.maxTotalLossRatio,
                timestamp: Date(),
                action: .emergencyStop
            )
            addRiskAlert(alert)
            
            // 触发紧急止损
            await triggerEmergencyStop()
        }
    }
    
    // MARK: - 仓位风险预警
    
    /// 检查仓位风险预警
    public func checkPositionRiskAlerts() async {
        guard let riskManager = riskManager else { return }
        
        let positions = getAllPositions()
        
        for position in positions {
            let symbol = position.symbol ?? ""
            let positionRisk = calculatePositionRisk(position: position)
            positionRisks[symbol] = positionRisk
            
            // 检查单仓位亏损
            if positionRisk.unrealizedLossRatio > riskThresholds.maxSinglePositionLoss {
                let alert = RealTimeRiskAlert(
                    type: .positionLoss,
                    level: .high,
                    message: "\(symbol) 单仓位亏损过大",
                    currentValue: positionRisk.unrealizedLossRatio,
                    threshold: riskThresholds.maxSinglePositionLoss,
                    timestamp: Date(),
                    action: .autoStop
                )
                addRiskAlert(alert)
                
                // 自动止损
                await triggerAutoStopLoss(position: position)
            }
            
            // 检查持仓集中度
            if positionRisk.concentrationRatio > riskThresholds.maxPositionConcentration {
                let alert = RealTimeRiskAlert(
                    type: .concentration,
                    level: .medium,
                    message: "\(symbol) 持仓集中度过高",
                    currentValue: positionRisk.concentrationRatio,
                    threshold: riskThresholds.maxPositionConcentration,
                    timestamp: Date(),
                    action: .requireAttention
                )
                addRiskAlert(alert)
            }
            
            // 检查价格波动异常
            if positionRisk.priceVolatility > riskThresholds.maxPriceVolatility {
                let alert = RealTimeRiskAlert(
                    type: .volatility,
                    level: .medium,
                    message: "\(symbol) 价格波动异常",
                    currentValue: positionRisk.priceVolatility,
                    threshold: riskThresholds.maxPriceVolatility,
                    timestamp: Date(),
                    action: .requireAttention
                )
                addRiskAlert(alert)
            }
        }
    }
    
    // MARK: - 异常交易检测
    
    /// 检测异常交易
    /// - Returns: 异常交易警报数组
    public func detectAbnormalTrading() async -> [RealTimeRiskAlert] {
        guard let tradingService = tradingService else { return [] }
        
        var alerts: [RealTimeRiskAlert] = []
        
        // 获取最近的交易记录
        let recentTrades = getRecentTrades(minutes: 30)
        
        // 检测频繁交易
        if recentTrades.count > riskThresholds.maxTradesPerHour {
            let alert = RealTimeRiskAlert(
                type: .frequentTrading,
                level: .medium,
                message: "交易频率过高",
                currentValue: Double(recentTrades.count),
                threshold: Double(riskThresholds.maxTradesPerHour),
                timestamp: Date(),
                action: .requireAttention
            )
            alerts.append(alert)
        }
        
        // 检测大额交易
        let totalTradeValue = recentTrades.reduce(0) { total, trade in
            total + trade.price * Double(trade.quantity)
        }
        
        if totalTradeValue > riskThresholds.maxHourlyTradeValue {
            let alert = RealTimeRiskAlert(
                type: .largeTrading,
                level: .high,
                message: "单小时交易额过大",
                currentValue: totalTradeValue,
                threshold: riskThresholds.maxHourlyTradeValue,
                timestamp: Date(),
                action: .requireAttention
            )
            alerts.append(alert)
        }
        
        // 检测异常价格交易
        for trade in recentTrades {
            if let avgPrice = await getAveragePrice(symbol: trade.symbol ?? "", days: 5) {
                let priceDeviation = abs(trade.price - avgPrice) / avgPrice
                if priceDeviation > riskThresholds.maxPriceDeviation {
                    let alert = RealTimeRiskAlert(
                        type: .priceAnomaly,
                        level: .medium,
                        message: "\(trade.symbol ?? "") 交易价格异常",
                        currentValue: priceDeviation,
                        threshold: riskThresholds.maxPriceDeviation,
                        timestamp: Date(),
                        action: .requireAttention
                    )
                    alerts.append(alert)
                }
            }
        }
        
        return alerts
    }
    
    // MARK: - 自动止损触发
    
    /// 触发自动止损
    /// - Parameter position: 持仓信息
    public func triggerAutoStopLoss(position: PositionEntity) async {
        guard let tradingService = tradingService,
              let riskManager = riskManager else { return }
        
        let symbol = position.symbol ?? ""
        
        // 检查是否应该触发止损
        if riskManager.shouldTriggerStopLoss(position: position) {
            let orderRequest = OrderRequest(
                symbol: symbol,
                type: .market,
                side: position.quantity > 0 ? .sell : .buy,
                quantity: abs(Int(position.quantity)),
                price: position.currentPrice,
                timeInForce: .immediateOrCancel,
                stopPrice: nil,
                clientOrderId: "AUTO_STOP_\(UUID().uuidString)"
            )
            
            let response = await tradingService.placeOrder(order: orderRequest)
            
            if response.success {
                let emergencyStop = EmergencyStop(
                    id: UUID(),
                    symbol: symbol,
                    triggerType: .stopLoss,
                    triggerPrice: position.stopLoss,
                    currentPrice: position.currentPrice,
                    quantity: Int(position.quantity),
                    orderId: response.orderId,
                    timestamp: Date(),
                    reason: "触发自动止损"
                )
                
                emergencyStops.append(emergencyStop)
                
                let alert = RealTimeRiskAlert(
                    type: .autoStopLoss,
                    level: .critical,
                    message: "\(symbol) 自动止损已执行",
                    currentValue: position.currentPrice,
                    threshold: position.stopLoss,
                    timestamp: Date(),
                    action: .completed
                )
                addRiskAlert(alert)
                
                print("自动止损已触发: \(symbol)")
            } else {
                print("自动止损失败: \(symbol) - \(response.message)")
            }
        }
    }
    
    /// 触发自动减仓
    private func triggerAutoPositionReduction() async {
        guard let tradingService = tradingService else { return }
        
        let positions = getAllPositions()
        let sortedPositions = positions.sorted { pos1, pos2 in
            let risk1 = calculatePositionRisk(position: pos1)
            let risk2 = calculatePositionRisk(position: pos2)
            return risk1.unrealizedLossRatio > risk2.unrealizedLossRatio
        }
        
        // 减少风险最高的仓位
        for position in sortedPositions.prefix(3) {
            let symbol = position.symbol ?? ""
            let reduceQuantity = Int(Double(position.quantity) * 0.5) // 减仓50%
            
            if reduceQuantity > 0 {
                let orderRequest = OrderRequest(
                    symbol: symbol,
                    type: .market,
                    side: position.quantity > 0 ? .sell : .buy,
                    quantity: reduceQuantity,
                    price: position.currentPrice,
                    timeInForce: .immediateOrCancel,
                    stopPrice: nil,
                    clientOrderId: "AUTO_REDUCE_\(UUID().uuidString)"
                )
                
                let response = await tradingService.placeOrder(order: orderRequest)
                
                if response.success {
                    let alert = RealTimeRiskAlert(
                        type: .autoReduce,
                        level: .high,
                        message: "\(symbol) 自动减仓已执行",
                        currentValue: Double(reduceQuantity),
                        threshold: Double(position.quantity),
                        timestamp: Date(),
                        action: .completed
                    )
                    addRiskAlert(alert)
                    
                    print("自动减仓已执行: \(symbol)")
                }
            }
        }
    }
    
    /// 触发紧急止损
    private func triggerEmergencyStop() async {
        accountStatus = .emergencyStop
        
        let positions = getAllPositions()
        
        for position in positions {
            await triggerAutoStopLoss(position: position)
        }
        
        let alert = RealTimeRiskAlert(
            type: .emergencyStop,
            level: .critical,
            message: "触发账户紧急止损",
            currentValue: 0,
            threshold: 0,
            timestamp: Date(),
            action: .completed
        )
        addRiskAlert(alert)
        
        print("账户紧急止损已触发")
    }
    
    // MARK: - 私有方法
    
    /// 设置风险监控
    private func setupRiskMonitoring() {
        // 初始化监控指标
        monitoringMetrics = MonitoringMetrics()
    }
    
    /// 执行实时风险检查
    private func performRealTimeRiskCheck() async {
        guard isMonitoring else { return }
        
        // 更新监控指标
        updateMonitoringMetrics()
        
        // 监控账户余额
        await monitorAccountBalance()
        
        // 检查仓位风险
        await checkPositionRiskAlerts()
        
        // 检测异常交易
        let abnormalAlerts = await detectAbnormalTrading()
        for alert in abnormalAlerts {
            addRiskAlert(alert)
        }
        
        // 清理过期警报
        cleanupExpiredAlerts()
    }
    
    /// 更新监控指标
    private func updateMonitoringMetrics() {
        monitoringMetrics.lastCheckTime = Date()
        monitoringMetrics.totalChecks += 1
        monitoringMetrics.activeAlerts = riskAlerts.count
        monitoringMetrics.emergencyStops = emergencyStops.count
    }
    
    /// 计算持仓风险
    private func calculatePositionRisk(position: PositionEntity) -> PositionRisk {
        let currentValue = Double(position.quantity) * position.currentPrice
        let costBasis = Double(position.quantity) * position.avgPrice
        let unrealizedPnL = currentValue - costBasis
        let unrealizedLossRatio = costBasis > 0 ? abs(min(unrealizedPnL, 0)) / costBasis : 0
        
        // 计算集中度（简化）
        let totalPortfolioValue = getAllPositions().reduce(0) { total, pos in
            total + Double(pos.quantity) * pos.currentPrice
        }
        let concentrationRatio = totalPortfolioValue > 0 ? abs(currentValue) / totalPortfolioValue : 0
        
        // 计算价格波动率（简化）
        let priceVolatility = calculatePriceVolatility(symbol: position.symbol ?? "")
        
        return PositionRisk(
            symbol: position.symbol ?? "",
            unrealizedPnL: unrealizedPnL,
            unrealizedLossRatio: unrealizedLossRatio,
            concentrationRatio: concentrationRatio,
            priceVolatility: priceVolatility,
            riskLevel: determineRiskLevel(unrealizedLossRatio: unrealizedLossRatio)
        )
    }
    
    /// 确定风险等级
    private func determineRiskLevel(unrealizedLossRatio: Double) -> RiskLevel {
        if unrealizedLossRatio > 0.15 {
            return .critical
        } else if unrealizedLossRatio > 0.10 {
            return .high
        } else if unrealizedLossRatio > 0.05 {
            return .medium
        } else {
            return .low
        }
    }
    
    /// 计算价格波动率
    private func calculatePriceVolatility(symbol: String) -> Double {
        // 简化实现，实际应该从历史数据计算
        return 0.02
    }
    
    /// 获取平均价格
    private func getAveragePrice(symbol: String, days: Int) async -> Double? {
        // 这里应该从市场数据服务获取
        return 100.0
    }
    
    /// 获取最近交易
    private func getRecentTrades(minutes: Int) -> [TradeEntity] {
        guard let tradingService = tradingService else { return [] }
        
        let cutoffTime = Date().addingTimeInterval(-Double(minutes * 60))
        return tradingService.trades.filter { trade in
            guard let timestamp = trade.timestamp else { return false }
            return timestamp >= cutoffTime
        }
    }
    
    /// 获取所有持仓
    private func getAllPositions() -> [PositionEntity] {
        let context = persistenceController.container.viewContext
        let request = NSFetchRequest<PositionEntity>(entityName: "PositionEntity")
        
        do {
            return try context.fetch(request)
        } catch {
            print("获取持仓失败: \(error)")
            return []
        }
    }
    
    /// 添加风险警报
    private func addRiskAlert(_ alert: RealTimeRiskAlert) {
        riskAlerts.insert(alert, at: 0)
        alertHistory.append(alert)
        
        // 限制内存中的警报数量
        if riskAlerts.count > 50 {
            riskAlerts = Array(riskAlerts.prefix(50))
        }
        
        if alertHistory.count > 1000 {
            alertHistory = Array(alertHistory.suffix(1000))
        }
    }
    
    /// 清理过期警报
    private func cleanupExpiredAlerts() {
        let expirationTime: TimeInterval = 2 * 60 * 60 // 2小时
        let cutoffDate = Date().addingTimeInterval(-expirationTime)
        
        riskAlerts.removeAll { alert in
            alert.timestamp < cutoffDate
        }
    }
}

// MARK: - 数据模型

/// 实时风险警报
public struct RealTimeRiskAlert: Identifiable {
    public let id = UUID()
    let type: RiskAlertType
    let level: RiskLevel
    let message: String
    let currentValue: Double
    let threshold: Double
    let timestamp: Date
    let action: AlertAction
}

/// 警报动作
public enum AlertAction: String, CaseIterable {
    case requireAttention = "需要关注"
    case autoStop = "自动止损"
    case autoReduce = "自动减仓"
    case emergencyStop = "紧急止损"
    case completed = "已完成"
}

/// 账户状态
public enum AccountStatus: String, CaseIterable {
    case normal = "正常"
    case warning = "警告"
    case risk = "风险"
    case emergencyStop = "紧急止损"
}

/// 持仓风险
public struct PositionRisk {
    let symbol: String
    let unrealizedPnL: Double
    let unrealizedLossRatio: Double
    let concentrationRatio: Double
    let priceVolatility: Double
    let riskLevel: RiskLevel
}

/// 紧急止损记录
public struct EmergencyStop: Identifiable {
    public let id: UUID
    let symbol: String
    let triggerType: EmergencyStopType
    let triggerPrice: Double
    let currentPrice: Double
    let quantity: Int
    let orderId: String?
    let timestamp: Date
    let reason: String
}

/// 紧急止损类型
public enum EmergencyStopType: String, CaseIterable {
    case stopLoss = "止损"
    case marginCall = "追加保证金"
    case riskLimit = "风险限制"
    case systemError = "系统错误"
}

/// 风险阈值
public struct RiskThresholds {
    let minCashReserve: Double              // 最小现金储备
    let maxMarginUsage: Double              // 最大保证金使用率
    let maxTotalLossRatio: Double           // 最大总亏损比例
    let maxSinglePositionLoss: Double       // 最大单仓位亏损
    let maxPositionConcentration: Double    // 最大持仓集中度
    let maxPriceVolatility: Double          // 最大价格波动率
    let maxTradesPerHour: Int               // 每小时最大交易次数
    let maxHourlyTradeValue: Double         // 每小时最大交易金额
    let maxPriceDeviation: Double           // 最大价格偏离度
    
    public static func defaultThresholds() -> RiskThresholds {
        return RiskThresholds(
            minCashReserve: 10000.0,        // 1万现金储备
            maxMarginUsage: 0.70,           // 70%保证金使用率
            maxTotalLossRatio: 0.20,        // 20%总亏损
            maxSinglePositionLoss: 0.10,    // 10%单仓位亏损
            maxPositionConcentration: 0.30, // 30%持仓集中度
            maxPriceVolatility: 0.05,       // 5%价格波动率
            maxTradesPerHour: 20,           // 每小时20笔交易
            maxHourlyTradeValue: 100000.0,  // 每小时10万交易额
            maxPriceDeviation: 0.05         // 5%价格偏离
        )
    }
}

/// 监控指标
public struct MonitoringMetrics {
    var lastCheckTime: Date = Date()
    var totalChecks: Int = 0
    var activeAlerts: Int = 0
    var emergencyStops: Int = 0
    var systemHealth: SystemHealth = .normal
}

/// 系统健康状态
public enum SystemHealth: String, CaseIterable {
    case normal = "正常"
    case warning = "警告"
    case error = "错误"
    case critical = "严重"
}
