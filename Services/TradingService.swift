/*
 增强交易服务
 作者: MiniMax Agent
 创建日期: 2025-06-24
 
 集成平安证券API的增强交易执行系统，包含订单管理、交易记录等功能
 */

import Foundation
import CoreData
import Combine

/// 增强交易服务类
@MainActor
public class EnhancedTradingService: ObservableObject {
    
    // MARK: - Published Properties
    @Published var isConnected: Bool = false
    @Published var connectionStatus: ConnectionStatus = .disconnected
    @Published var orders: [OrderEntity] = []
    @Published var trades: [TradeEntity] = []
    @Published var accountInfo: AccountInfo = AccountInfo()
    @Published var isTrading: Bool = false
    @Published var dailyPnL: Double = 0.0
    
    // MARK: - Private Properties
    private let persistenceController = PersistenceController.shared
    private var cancellables = Set<AnyCancellable>()
    private var riskManager: RiskManager?
    private var networkManager: NetworkManager
    private var pinganAPIClient: PinganAPIClient
    private var orderMonitorTimer: Timer?
    
    // MARK: - 初始化
    init() {
        self.networkManager = NetworkManager()
        self.pinganAPIClient = PinganAPIClient()
        setupOrderMonitoring()
        loadExistingOrders()
    }
    
    deinit {
        orderMonitorTimer?.invalidate()
    }
    
    // MARK: - 连接管理
    
    /// 连接到平安证券API
    /// - Returns: 连接是否成功
    public func connectToPinganAPI() async -> Bool {
        connectionStatus = .connecting
        
        do {
            let success = try await pinganAPIClient.connect()
            
            if success {
                isConnected = true
                connectionStatus = .connected
                
                // 获取账户信息
                await refreshAccountInfo()
                
                // 同步订单状态
                await syncOrderStatus()
                
                print("成功连接到平安证券API")
                return true
            } else {
                connectionStatus = .failed
                print("连接到平安证券API失败")
                return false
            }
        } catch {
            connectionStatus = .failed
            print("连接错误: \(error)")
            return false
        }
    }
    
    /// 断开连接
    public func disconnect() {
        pinganAPIClient.disconnect()
        isConnected = false
        connectionStatus = .disconnected
        print("已断开平安证券API连接")
    }
    
    /// 设置风险管理器
    /// - Parameter riskManager: 风险管理器实例
    public func setRiskManager(_ riskManager: RiskManager) {
        self.riskManager = riskManager
    }
    
    // MARK: - 订单管理
    
    /// 下单
    /// - Parameter order: 订单请求
    /// - Returns: 订单响应
    public func placeOrder(order: OrderRequest) async -> OrderResponse {
        guard isConnected else {
            return OrderResponse(
                success: false,
                orderId: nil,
                message: "未连接到交易API",
                errorCode: "CONNECTION_ERROR"
            )
        }
        
        // 风险检查
        if let riskManager = riskManager {
            let riskCheck = riskManager.checkPositionRisk(
                symbol: order.symbol,
                quantity: order.quantity,
                price: order.price
            )
            
            if !riskCheck.canTrade {
                return OrderResponse(
                    success: false,
                    orderId: nil,
                    message: "风险检查未通过: \(riskCheck.warnings.joined(separator: ", "))",
                    errorCode: "RISK_CHECK_FAILED"
                )
            }
        }
        
        do {
            // 调用平安证券API下单
            let response = try await pinganAPIClient.placeOrder(order)
            
            if response.success, let orderId = response.orderId {
                // 创建本地订单记录
                let orderEntity = createOrderEntity(from: order, orderId: orderId)
                orders.append(orderEntity)
                
                // 开始跟踪订单状态
                await trackOrderExecution(orderId: orderId)
                
                print("订单下达成功: \(orderId)")
            } else {
                print("订单下达失败: \(response.message)")
            }
            
            return response
        } catch {
            print("下单错误: \(error)")
            return OrderResponse(
                success: false,
                orderId: nil,
                message: "下单失败: \(error.localizedDescription)",
                errorCode: "PLACE_ORDER_ERROR"
            )
        }
    }
    
    /// 取消订单
    /// - Parameter orderId: 订单ID
    /// - Returns: 取消是否成功
    public func cancelOrder(orderId: String) async -> Bool {
        guard isConnected else {
            print("未连接到交易API")
            return false
        }
        
        do {
            let success = try await pinganAPIClient.cancelOrder(orderId: orderId)
            
            if success {
                // 更新本地订单状态
                if let orderIndex = orders.firstIndex(where: { $0.orderId == orderId }) {
                    orders[orderIndex].status = OrderStatus.cancelled.rawValue
                    orders[orderIndex].updateTime = Date()
                    saveContext()
                }
                
                print("订单取消成功: \(orderId)")
            } else {
                print("订单取消失败: \(orderId)")
            }
            
            return success
        } catch {
            print("取消订单错误: \(error)")
            return false
        }
    }
    
    /// 查询订单状态
    /// - Parameter orderId: 订单ID
    /// - Returns: 订单状态
    public func queryOrderStatus(orderId: String) async -> OrderStatus? {
        guard isConnected else {
            return nil
        }
        
        do {
            let status = try await pinganAPIClient.queryOrderStatus(orderId: orderId)
            
            // 更新本地订单状态
            if let orderIndex = orders.firstIndex(where: { $0.orderId == orderId }) {
                orders[orderIndex].status = status.rawValue
                orders[orderIndex].updateTime = Date()
                saveContext()
            }
            
            return status
        } catch {
            print("查询订单状态错误: \(error)")
            return nil
        }
    }
    
    /// 跟踪订单执行
    /// - Parameter orderId: 订单ID
    public func trackOrderExecution(orderId: String) async {
        var attempts = 0
        let maxAttempts = 60 // 最多跟踪60次，每次间隔5秒
        
        while attempts < maxAttempts {
            if let status = await queryOrderStatus(orderId: orderId) {
                switch status {
                case .filled:
                    // 订单完全成交，获取成交详情
                    await handleOrderFilled(orderId: orderId)
                    return
                case .cancelled, .rejected:
                    // 订单已取消或被拒绝，停止跟踪
                    print("订单\(orderId)已取消或被拒绝")
                    return
                case .partiallyFilled:
                    // 部分成交，继续跟踪
                    await handlePartialFill(orderId: orderId)
                case .pending:
                    // 继续等待
                    break
                }
            }
            
            attempts += 1
            try? await Task.sleep(nanoseconds: 5_000_000_000) // 等待5秒
        }
        
        print("订单\(orderId)跟踪超时")
    }
    
    /// 处理订单成交
    /// - Parameter orderId: 订单ID
    private func handleOrderFilled(orderId: String) async {
        guard let order = orders.first(where: { $0.orderId == orderId }) else { return }
        
        do {
            // 获取成交详情
            let fillDetails = try await pinganAPIClient.getOrderFillDetails(orderId: orderId)
            
            // 创建交易记录
            let trade = createTradeEntity(from: order, fillDetails: fillDetails)
            trades.append(trade)
            
            // 更新持仓
            await updatePositionAfterTrade(trade: trade)
            
            // 更新账户信息
            await refreshAccountInfo()
            
            print("订单\(orderId)完全成交")
        } catch {
            print("处理订单成交错误: \(error)")
        }
    }
    
    /// 处理部分成交
    /// - Parameter orderId: 订单ID
    private func handlePartialFill(orderId: String) async {
        guard let order = orders.first(where: { $0.orderId == orderId }) else { return }
        
        do {
            // 获取部分成交详情
            let fillDetails = try await pinganAPIClient.getOrderFillDetails(orderId: orderId)
            
            // 创建部分交易记录
            if fillDetails.filledQuantity > 0 {
                let trade = createTradeEntity(from: order, fillDetails: fillDetails)
                trades.append(trade)
                
                // 更新持仓
                await updatePositionAfterTrade(trade: trade)
            }
            
            print("订单\(orderId)部分成交: \(fillDetails.filledQuantity)")
        } catch {
            print("处理部分成交错误: \(error)")
        }
    }
    
    // MARK: - 持仓管理
    
    /// 更新持仓信息
    /// - Parameter trade: 交易记录
    private func updatePositionAfterTrade(trade: TradeEntity) async {
        let context = persistenceController.container.viewContext
        
        // 查找或创建持仓记录
        let request = NSFetchRequest<PositionEntity>(entityName: "PositionEntity")
        request.predicate = NSPredicate(format: "symbol == %@", trade.symbol ?? "")
        
        do {
            let positions = try context.fetch(request)
            let position: PositionEntity
            
            if let existingPosition = positions.first {
                position = existingPosition
            } else {
                position = PositionEntity(context: context)
                position.symbol = trade.symbol
                position.id = UUID()
                position.openTime = Date()
            }
            
            // 更新持仓数量和均价
            let newQuantity = position.quantity + Int32(trade.quantity)
            
            if newQuantity == 0 {
                // 平仓，删除持仓记录
                context.delete(position)
            } else {
                let totalCost = Double(position.quantity) * position.avgPrice + Double(trade.quantity) * trade.price
                position.avgPrice = totalCost / Double(newQuantity)
                position.quantity = newQuantity
                position.updateTime = Date()
                
                // 设置默认止损止盈
                if position.stopLoss == 0 {
                    position.stopLoss = trade.price * 0.95 // 默认5%止损
                }
                if position.takeProfit == 0 {
                    position.takeProfit = trade.price * 1.10 // 默认10%止盈
                }
            }
            
            saveContext()
        } catch {
            print("更新持仓失败: \(error)")
        }
    }
    
    /// 记录交易
    /// - Parameter tradeData: 交易数据
    public func recordTrade(tradeData: TradeData) {
        let context = persistenceController.container.viewContext
        let trade = TradeEntity(context: context)
        
        trade.id = UUID()
        trade.symbol = tradeData.symbol
        trade.type = tradeData.type.rawValue
        trade.quantity = Int32(tradeData.quantity)
        trade.price = tradeData.price
        trade.timestamp = tradeData.timestamp
        trade.commission = tradeData.commission
        trade.pnl = tradeData.pnl
        
        saveContext()
        
        // 更新交易列表
        if let index = trades.firstIndex(where: { $0.id == trade.id }) {
            trades[index] = trade
        } else {
            trades.append(trade)
        }
    }
    
    // MARK: - 账户信息
    
    /// 刷新账户信息
    public func refreshAccountInfo() async {
        guard isConnected else { return }
        
        do {
            let info = try await pinganAPIClient.getAccountInfo()
            accountInfo = info
            
            // 计算当日盈亏
            await calculateDailyPnL()
        } catch {
            print("获取账户信息失败: \(error)")
        }
    }
    
    /// 计算当日盈亏
    private func calculateDailyPnL() async {
        let today = Calendar.current.startOfDay(for: Date())
        let todayTrades = trades.filter { trade in
            guard let timestamp = trade.timestamp else { return false }
            return timestamp >= today
        }
        
        dailyPnL = todayTrades.reduce(0) { total, trade in
            total + trade.pnl
        }
    }
    
    // MARK: - 异常交易检测
    
    /// 检测异常交易
    /// - Parameter trade: 交易记录
    /// - Returns: 异常检测结果
    public func detectAbnormalTrading(trade: TradeEntity) -> AbnormalTradingResult {
        var anomalies: [String] = []
        var riskLevel: RiskLevel = .low
        
        // 1. 大额交易检测
        let tradeValue = trade.price * Double(trade.quantity)
        if tradeValue > accountInfo.totalAssets * 0.2 {
            anomalies.append("大额交易：超过账户总资产20%")
            riskLevel = .high
        }
        
        // 2. 频繁交易检测
        let recentTrades = getRecentTrades(minutes: 30)
        if recentTrades.count > 10 {
            anomalies.append("频繁交易：30分钟内交易超过10次")
            riskLevel = max(riskLevel, .medium)
        }
        
        // 3. 价格异常检测
        if let avgPrice = getAveragePrice(symbol: trade.symbol ?? "", days: 5) {
            let priceDeviation = abs(trade.price - avgPrice) / avgPrice
            if priceDeviation > 0.1 {
                anomalies.append("价格异常：偏离5日均价超过10%")
                riskLevel = max(riskLevel, .medium)
            }
        }
        
        // 4. 时间异常检测
        if let timestamp = trade.timestamp {
            let hour = Calendar.current.component(.hour, from: timestamp)
            if hour < 9 || hour > 15 {
                anomalies.append("时间异常：非交易时间执行交易")
                riskLevel = max(riskLevel, .high)
            }
        }
        
        // 5. 持仓集中度检测
        let positionConcentration = calculatePositionConcentration(symbol: trade.symbol ?? "")
        if positionConcentration > 0.3 {
            anomalies.append("持仓集中：单一股票占比超过30%")
            riskLevel = max(riskLevel, .medium)
        }
        
        return AbnormalTradingResult(
            isAbnormal: !anomalies.isEmpty,
            riskLevel: riskLevel,
            anomalies: anomalies,
            recommendations: generateAnomalyRecommendations(anomalies: anomalies)
        )
    }
    
    // MARK: - 私有方法
    
    /// 设置订单监控
    private func setupOrderMonitoring() {
        orderMonitorTimer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.monitorPendingOrders()
            }
        }
    }
    
    /// 监控待处理订单
    private func monitorPendingOrders() async {
        let pendingOrders = orders.filter { order in
            let status = OrderStatus(rawValue: order.status) ?? .pending
            return status == .pending || status == .partiallyFilled
        }
        
        for order in pendingOrders {
            if let orderId = order.orderId {
                await trackOrderExecution(orderId: orderId)
            }
        }
    }
    
    /// 同步订单状态
    private func syncOrderStatus() async {
        guard isConnected else { return }
        
        for order in orders {
            if let orderId = order.orderId {
                _ = await queryOrderStatus(orderId: orderId)
            }
        }
    }
    
    /// 加载现有订单
    private func loadExistingOrders() {
        let context = persistenceController.container.viewContext
        let request = NSFetchRequest<OrderEntity>(entityName: "OrderEntity")
        request.sortDescriptors = [NSSortDescriptor(keyPath: \OrderEntity.createTime, ascending: false)]
        
        do {
            orders = try context.fetch(request)
        } catch {
            print("加载订单失败: \(error)")
        }
    }
    
    /// 创建订单实体
    private func createOrderEntity(from request: OrderRequest, orderId: String) -> OrderEntity {
        let context = persistenceController.container.viewContext
        let order = OrderEntity(context: context)
        
        order.id = UUID()
        order.orderId = orderId
        order.symbol = request.symbol
        order.type = request.type.rawValue
        order.side = request.side.rawValue
        order.quantity = Int32(request.quantity)
        order.price = request.price
        order.status = OrderStatus.pending.rawValue
        order.createTime = Date()
        order.updateTime = Date()
        
        saveContext()
        return order
    }
    
    /// 创建交易实体
    private func createTradeEntity(from order: OrderEntity, fillDetails: OrderFillDetails) -> TradeEntity {
        let context = persistenceController.container.viewContext
        let trade = TradeEntity(context: context)
        
        trade.id = UUID()
        trade.orderId = order.orderId
        trade.symbol = order.symbol
        trade.type = order.side
        trade.quantity = Int32(fillDetails.filledQuantity)
        trade.price = fillDetails.avgFillPrice
        trade.timestamp = fillDetails.fillTime
        trade.commission = fillDetails.commission
        trade.pnl = 0 // 盈亏在平仓时计算
        
        saveContext()
        return trade
    }
    
    /// 获取近期交易
    private func getRecentTrades(minutes: Int) -> [TradeEntity] {
        let cutoffTime = Date().addingTimeInterval(-Double(minutes * 60))
        return trades.filter { trade in
            guard let timestamp = trade.timestamp else { return false }
            return timestamp >= cutoffTime
        }
    }
    
    /// 获取平均价格
    private func getAveragePrice(symbol: String, days: Int) -> Double? {
        // 这里应该从市场数据服务获取历史价格
        // 简化实现，返回假设值
        return 100.0
    }
    
    /// 计算持仓集中度
    private func calculatePositionConcentration(symbol: String) -> Double {
        let totalValue = accountInfo.totalAssets
        guard totalValue > 0 else { return 0 }
        
        // 计算该股票的持仓价值占比
        let symbolTrades = trades.filter { $0.symbol == symbol }
        let symbolValue = symbolTrades.reduce(0) { total, trade in
            total + trade.price * Double(trade.quantity)
        }
        
        return symbolValue / totalValue
    }
    
    /// 生成异常建议
    private func generateAnomalyRecommendations(anomalies: [String]) -> [String] {
        var recommendations: [String] = []
        
        for anomaly in anomalies {
            if anomaly.contains("大额交易") {
                recommendations.append("建议分批交易，降低单笔风险")
            } else if anomaly.contains("频繁交易") {
                recommendations.append("建议减少交易频率，避免过度交易")
            } else if anomaly.contains("价格异常") {
                recommendations.append("建议核实价格，确认交易意图")
            } else if anomaly.contains("时间异常") {
                recommendations.append("建议在正常交易时间进行交易")
            } else if anomaly.contains("持仓集中") {
                recommendations.append("建议分散投资，降低集中度风险")
            }
        }
        
        return recommendations
    }
    
    /// 保存上下文
    private func saveContext() {
        do {
            try persistenceController.container.viewContext.save()
        } catch {
            print("保存失败: \(error)")
        }
    }
}

// MARK: - 数据模型

/// 订单请求
public struct OrderRequest {
    let symbol: String
    let type: OrderType
    let side: OrderSide
    let quantity: Int
    let price: Double
    let timeInForce: TimeInForce
    let stopPrice: Double?
    let clientOrderId: String?
}

/// 订单响应
public struct OrderResponse {
    let success: Bool
    let orderId: String?
    let message: String
    let errorCode: String?
}

/// 订单类型
public enum OrderType: String, CaseIterable {
    case market = "MARKET"
    case limit = "LIMIT"
    case stop = "STOP"
    case stopLimit = "STOP_LIMIT"
}

/// 订单方向
public enum OrderSide: String, CaseIterable {
    case buy = "BUY"
    case sell = "SELL"
}

/// 订单状态
public enum OrderStatus: String, CaseIterable {
    case pending = "PENDING"
    case partiallyFilled = "PARTIALLY_FILLED"
    case filled = "FILLED"
    case cancelled = "CANCELLED"
    case rejected = "REJECTED"
}

/// 时效类型
public enum TimeInForce: String, CaseIterable {
    case day = "DAY"
    case goodTillCancelled = "GTC"
    case immediateOrCancel = "IOC"
    case fillOrKill = "FOK"
}

/// 连接状态
public enum ConnectionStatus: String, CaseIterable {
    case disconnected = "DISCONNECTED"
    case connecting = "CONNECTING"
    case connected = "CONNECTED"
    case failed = "FAILED"
}

/// 账户信息
public struct AccountInfo {
    var totalAssets: Double = 0
    var availableCash: Double = 0
    var marketValue: Double = 0
    var todayPnL: Double = 0
    var totalPnL: Double = 0
    var buyingPower: Double = 0
    var marginUsed: Double = 0
}

/// 订单成交详情
public struct OrderFillDetails {
    let filledQuantity: Int
    let avgFillPrice: Double
    let fillTime: Date
    let commission: Double
}

/// 交易数据
public struct TradeData {
    let symbol: String
    let type: OrderSide
    let quantity: Int
    let price: Double
    let timestamp: Date
    let commission: Double
    let pnl: Double
}

/// 异常交易检测结果
public struct AbnormalTradingResult {
    let isAbnormal: Bool
    let riskLevel: RiskLevel
    let anomalies: [String]
    let recommendations: [String]
}

// MARK: - 平安证券API客户端

/// 平安证券API客户端
public class PinganAPIClient {
    
    private var isConnected: Bool = false
    
    /// 连接API
    public func connect() async throws -> Bool {
        // 模拟连接过程
        try await Task.sleep(nanoseconds: 1_000_000_000)
        isConnected = true
        return true
    }
    
    /// 断开连接
    public func disconnect() {
        isConnected = false
    }
    
    /// 下单
    public func placeOrder(_ order: OrderRequest) async throws -> OrderResponse {
        guard isConnected else {
            throw TradingError.notConnected
        }
        
        // 模拟下单过程
        try await Task.sleep(nanoseconds: 500_000_000)
        
        let orderId = "PG\(Int.random(in: 100000...999999))"
        return OrderResponse(
            success: true,
            orderId: orderId,
            message: "订单提交成功",
            errorCode: nil
        )
    }
    
    /// 取消订单
    public func cancelOrder(orderId: String) async throws -> Bool {
        guard isConnected else {
            throw TradingError.notConnected
        }
        
        // 模拟取消过程
        try await Task.sleep(nanoseconds: 300_000_000)
        return true
    }
    
    /// 查询订单状态
    public func queryOrderStatus(orderId: String) async throws -> OrderStatus {
        guard isConnected else {
            throw TradingError.notConnected
        }
        
        // 模拟查询过程
        try await Task.sleep(nanoseconds: 200_000_000)
        
        // 随机返回状态
        let statuses: [OrderStatus] = [.pending, .partiallyFilled, .filled]
        return statuses.randomElement() ?? .pending
    }
    
    /// 获取订单成交详情
    public func getOrderFillDetails(orderId: String) async throws -> OrderFillDetails {
        guard isConnected else {
            throw TradingError.notConnected
        }
        
        // 模拟获取成交详情
        return OrderFillDetails(
            filledQuantity: 100,
            avgFillPrice: 100.0,
            fillTime: Date(),
            commission: 5.0
        )
    }
    
    /// 获取账户信息
    public func getAccountInfo() async throws -> AccountInfo {
        guard isConnected else {
            throw TradingError.notConnected
        }
        
        // 模拟账户信息
        return AccountInfo(
            totalAssets: 500000.0,
            availableCash: 100000.0,
            marketValue: 400000.0,
            todayPnL: 2500.0,
            totalPnL: 50000.0,
            buyingPower: 200000.0,
            marginUsed: 0.0
        )
    }
}

/// 交易错误
public enum TradingError: Error {
    case notConnected
    case invalidOrder
    case insufficientFunds
    case marketClosed
    case riskCheckFailed
    case apiError(String)
}
