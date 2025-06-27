/*
 风险管理系统
 作者: MiniMax Agent
 创建日期: 2025-06-24
 
 实现完整的风险控制系统，包括持仓风险、账户风险、止损止盈等功能
 */

import Foundation
import CoreData
import Combine

/// 风险管理器
@MainActor
public class RiskManager: ObservableObject {
    
    // MARK: - Published Properties
    @Published var accountRiskLevel: AccountRiskLevel = .low
    @Published var currentDrawdown: Double = 0.0
    @Published var riskAlerts: [RiskAlert] = []
    @Published var isRiskManagementEnabled: Bool = true
    @Published var totalExposure: Double = 0.0
    @Published var riskMetrics: RiskMetrics = RiskMetrics()
    
    // MARK: - Private Properties
    private let persistenceController = PersistenceController.shared
    private var cancellables = Set<AnyCancellable>()
    private var riskParameters: RiskParameters
    private var alertsTimer: Timer?
    
    // MARK: - 初始化
    init(riskParameters: RiskParameters = RiskParameters.defaultParameters()) {
        self.riskParameters = riskParameters
        setupRiskMonitoring()
    }
    
    deinit {
        alertsTimer?.invalidate()
    }
    
    // MARK: - 持仓风险检查
    
    /// 检查持仓风险
    /// - Parameters:
    ///   - symbol: 股票代码
    ///   - quantity: 数量
    ///   - price: 价格
    /// - Returns: 风险检查结果
    public func checkPositionRisk(symbol: String, quantity: Int, price: Double) -> RiskCheckResult {
        var warnings: [String] = []
        var canTrade = true
        var riskLevel: RiskLevel = .low
        
        // 1. 单个持仓风险检查
        let positionValue = Double(quantity) * price
        let accountValue = getCurrentAccountValue()
        let positionWeight = accountValue > 0 ? positionValue / accountValue : 0
        
        if positionWeight > riskParameters.maxSinglePositionWeight {
            warnings.append("单个持仓占比超过限制(\(String(format: "%.1f%%", riskParameters.maxSinglePositionWeight * 100)))")
            riskLevel = .high
            if positionWeight > riskParameters.maxSinglePositionWeight * 1.5 {
                canTrade = false
            }
        }
        
        // 2. 行业集中度检查
        let industryExposure = calculateIndustryExposure(symbol: symbol, addPosition: positionValue)
        if industryExposure > riskParameters.maxIndustryConcentration {
            warnings.append("行业集中度过高(\(String(format: "%.1f%%", industryExposure * 100)))")
            riskLevel = max(riskLevel, .medium)
        }
        
        // 3. 总杠杆检查
        let currentLeverage = calculateCurrentLeverage()
        if currentLeverage > riskParameters.maxLeverage {
            warnings.append("杠杆比例过高(\(String(format: "%.1fx", currentLeverage)))")
            riskLevel = .high
            canTrade = false
        }
        
        // 4. 流动性检查
        let liquidityRisk = assessLiquidityRisk(symbol: symbol, quantity: quantity)
        if liquidityRisk > riskParameters.maxLiquidityRisk {
            warnings.append("流动性风险过高")
            riskLevel = max(riskLevel, .medium)
        }
        
        // 5. 相关性检查
        let correlationRisk = calculateCorrelationRisk(symbol: symbol, positionValue: positionValue)
        if correlationRisk > riskParameters.maxCorrelationRisk {
            warnings.append("持仓相关性过高")
            riskLevel = max(riskLevel, .medium)
        }
        
        return RiskCheckResult(
            canTrade: canTrade && isRiskManagementEnabled,
            riskLevel: riskLevel,
            warnings: warnings,
            positionWeight: positionWeight,
            estimatedLoss: calculatePotentialLoss(positionValue: positionValue),
            recommendations: generateRiskRecommendations(riskLevel: riskLevel, warnings: warnings)
        )
    }
    
    /// 检查账户风险
    /// - Returns: 账户风险等级
    public func checkAccountRisk() -> AccountRiskLevel {
        let accountValue = getCurrentAccountValue()
        let initialValue = getInitialAccountValue()
        
        // 计算当前回撤
        currentDrawdown = initialValue > 0 ? max(0, (initialValue - accountValue) / initialValue) : 0
        
        // 计算风险指标
        updateRiskMetrics()
        
        // 根据多个指标确定风险等级
        var riskScore = 0
        
        // 回撤评分
        if currentDrawdown > riskParameters.maxDrawdown * 0.8 {
            riskScore += 3
        } else if currentDrawdown > riskParameters.maxDrawdown * 0.5 {
            riskScore += 2
        } else if currentDrawdown > riskParameters.maxDrawdown * 0.3 {
            riskScore += 1
        }
        
        // 杠杆评分
        let leverage = calculateCurrentLeverage()
        if leverage > riskParameters.maxLeverage * 0.8 {
            riskScore += 2
        } else if leverage > riskParameters.maxLeverage * 0.5 {
            riskScore += 1
        }
        
        // 集中度评分
        let concentration = calculatePortfolioConcentration()
        if concentration > 0.7 {
            riskScore += 2
        } else if concentration > 0.5 {
            riskScore += 1
        }
        
        // 波动率评分
        if riskMetrics.portfolioVolatility > 0.3 {
            riskScore += 1
        }
        
        // 确定风险等级
        let newRiskLevel: AccountRiskLevel
        switch riskScore {
        case 0...1:
            newRiskLevel = .low
        case 2...3:
            newRiskLevel = .medium
        case 4...5:
            newRiskLevel = .high
        default:
            newRiskLevel = .critical
        }
        
        // 如果风险等级上升，生成警报
        if newRiskLevel.rawValue > accountRiskLevel.rawValue {
            let alert = RiskAlert(
                type: .accountRisk,
                level: newRiskLevel == .critical ? .critical : .high,
                message: "账户风险等级上升至\(newRiskLevel.description)",
                timestamp: Date(),
                details: [
                    "当前回撤": String(format: "%.2f%%", currentDrawdown * 100),
                    "杠杆比例": String(format: "%.2fx", leverage),
                    "持仓集中度": String(format: "%.1f%%", concentration * 100)
                ]
            )
            addRiskAlert(alert)
        }
        
        accountRiskLevel = newRiskLevel
        return newRiskLevel
    }
    
    // MARK: - 止损止盈管理
    
    /// 更新止损价格
    /// - Parameters:
    ///   - position: 持仓信息
    ///   - stopLossPrice: 止损价格
    public func updateStopLoss(position: PositionEntity, stopLossPrice: Double) {
        position.stopLoss = stopLossPrice
        
        // 验证止损价格合理性
        let currentPrice = position.currentPrice
        let stopLossDistance = abs(currentPrice - stopLossPrice) / currentPrice
        
        if stopLossDistance > riskParameters.maxStopLossDistance {
            let alert = RiskAlert(
                type: .stopLoss,
                level: .medium,
                message: "止损距离过大",
                timestamp: Date(),
                details: [
                    "股票": position.symbol ?? "",
                    "当前价格": String(format: "%.2f", currentPrice),
                    "止损价格": String(format: "%.2f", stopLossPrice),
                    "止损距离": String(format: "%.2f%%", stopLossDistance * 100)
                ]
            )
            addRiskAlert(alert)
        }
        
        saveContext()
    }
    
    /// 更新止盈价格
    /// - Parameters:
    ///   - position: 持仓信息
    ///   - takeProfitPrice: 止盈价格
    public func updateTakeProfit(position: PositionEntity, takeProfitPrice: Double) {
        position.takeProfit = takeProfitPrice
        saveContext()
    }
    
    /// 动态调整止损
    /// - Parameter position: 持仓信息
    public func adjustTrailingStop(position: PositionEntity) {
        guard position.stopLoss > 0 else { return }
        
        let currentPrice = position.currentPrice
        let entryPrice = position.avgPrice
        let isLong = position.quantity > 0
        
        if isLong {
            // 多头持仓：价格上涨时提高止损
            let profitRatio = (currentPrice - entryPrice) / entryPrice
            
            if profitRatio > 0.05 { // 盈利超过5%时启动跟踪止损
                let trailingStopPrice = currentPrice * (1 - riskParameters.trailingStopDistance)
                if trailingStopPrice > position.stopLoss {
                    updateStopLoss(position: position, stopLossPrice: trailingStopPrice)
                }
            }
        } else {
            // 空头持仓：价格下跌时降低止损
            let profitRatio = (entryPrice - currentPrice) / entryPrice
            
            if profitRatio > 0.05 {
                let trailingStopPrice = currentPrice * (1 + riskParameters.trailingStopDistance)
                if trailingStopPrice < position.stopLoss {
                    updateStopLoss(position: position, stopLossPrice: trailingStopPrice)
                }
            }
        }
    }
    
    /// 检查最大回撤
    /// - Returns: 是否触发回撤限制
    public func checkMaxDrawdown() -> Bool {
        return currentDrawdown > riskParameters.maxDrawdown
    }
    
    // MARK: - 风险监控
    
    /// 检查止损触发
    /// - Parameter position: 持仓信息
    /// - Returns: 是否需要止损
    public func shouldTriggerStopLoss(position: PositionEntity) -> Bool {
        guard position.stopLoss > 0 else { return false }
        
        let currentPrice = position.currentPrice
        let isLong = position.quantity > 0
        
        if isLong {
            return currentPrice <= position.stopLoss
        } else {
            return currentPrice >= position.stopLoss
        }
    }
    
    /// 检查止盈触发
    /// - Parameter position: 持仓信息
    /// - Returns: 是否需要止盈
    public func shouldTriggerTakeProfit(position: PositionEntity) -> Bool {
        guard position.takeProfit > 0 else { return false }
        
        let currentPrice = position.currentPrice
        let isLong = position.quantity > 0
        
        if isLong {
            return currentPrice >= position.takeProfit
        } else {
            return currentPrice <= position.takeProfit
        }
    }
    
    /// 获取持仓风险评估
    /// - Parameter symbol: 股票代码
    /// - Returns: 持仓风险信息
    public func getPositionRiskAssessment(symbol: String) -> PositionRiskAssessment {
        guard let position = getPosition(symbol: symbol) else {
            return PositionRiskAssessment(
                symbol: symbol,
                riskLevel: .low,
                unrealizedPnL: 0,
                unrealizedPnLPercent: 0,
                var95: 0,
                var99: 0,
                recommendations: []
            )
        }
        
        let unrealizedPnL = calculateUnrealizedPnL(position: position)
        let unrealizedPnLPercent = position.avgPrice > 0 ? unrealizedPnL / (position.avgPrice * Double(abs(position.quantity))) : 0
        
        // 计算VaR (Value at Risk)
        let var95 = calculateVaR(position: position, confidenceLevel: 0.95)
        let var99 = calculateVaR(position: position, confidenceLevel: 0.99)
        
        // 确定风险等级
        let riskLevel: RiskLevel
        if abs(unrealizedPnLPercent) > 0.15 {
            riskLevel = .high
        } else if abs(unrealizedPnLPercent) > 0.08 {
            riskLevel = .medium
        } else {
            riskLevel = .low
        }
        
        // 生成建议
        var recommendations: [String] = []
        if unrealizedPnLPercent < -0.1 {
            recommendations.append("考虑止损")
        }
        if abs(var95) > getCurrentAccountValue() * 0.02 {
            recommendations.append("降低仓位")
        }
        
        return PositionRiskAssessment(
            symbol: symbol,
            riskLevel: riskLevel,
            unrealizedPnL: unrealizedPnL,
            unrealizedPnLPercent: unrealizedPnLPercent,
            var95: var95,
            var99: var99,
            recommendations: recommendations
        )
    }
    
    // MARK: - 私有方法
    
    /// 设置风险监控
    private func setupRiskMonitoring() {
        // 定期检查风险指标
        alertsTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.performRiskCheck()
            }
        }
    }
    
    /// 执行风险检查
    private func performRiskCheck() {
        // 检查账户风险
        _ = checkAccountRisk()
        
        // 检查所有持仓的止损止盈
        let positions = getAllPositions()
        for position in positions {
            // 检查止损
            if shouldTriggerStopLoss(position: position) {
                let alert = RiskAlert(
                    type: .stopLoss,
                    level: .high,
                    message: "触发止损: \(position.symbol ?? "")",
                    timestamp: Date(),
                    details: [
                        "当前价格": String(format: "%.2f", position.currentPrice),
                        "止损价格": String(format: "%.2f", position.stopLoss),
                        "持仓数量": String(position.quantity)
                    ]
                )
                addRiskAlert(alert)
            }
            
            // 检查止盈
            if shouldTriggerTakeProfit(position: position) {
                let alert = RiskAlert(
                    type: .takeProfit,
                    level: .low,
                    message: "触发止盈: \(position.symbol ?? "")",
                    timestamp: Date(),
                    details: [
                        "当前价格": String(format: "%.2f", position.currentPrice),
                        "止盈价格": String(format: "%.2f", position.takeProfit),
                        "持仓数量": String(position.quantity)
                    ]
                )
                addRiskAlert(alert)
            }
            
            // 动态调整跟踪止损
            adjustTrailingStop(position: position)
        }
        
        // 清理过期警报
        cleanupExpiredAlerts()
    }
    
    /// 更新风险指标
    private func updateRiskMetrics() {
        let positions = getAllPositions()
        let accountValue = getCurrentAccountValue()
        
        // 计算投资组合波动率
        let returns = calculatePortfolioReturns()
        riskMetrics.portfolioVolatility = calculateVolatility(returns: returns)
        
        // 计算Beta值
        riskMetrics.portfolioBeta = calculatePortfolioBeta()
        
        // 计算夏普比率
        riskMetrics.sharpeRatio = calculatePortfolioSharpeRatio()
        
        // 计算最大回撤
        riskMetrics.maxDrawdown = currentDrawdown
        
        // 计算VaR
        riskMetrics.var95 = calculatePortfolioVaR(confidenceLevel: 0.95)
        riskMetrics.var99 = calculatePortfolioVaR(confidenceLevel: 0.99)
        
        // 计算总敞口
        totalExposure = positions.reduce(0) { total, position in
            total + abs(Double(position.quantity) * position.currentPrice)
        }
        
        riskMetrics.totalExposure = totalExposure
        riskMetrics.leverage = accountValue > 0 ? totalExposure / accountValue : 0
    }
    
    /// 获取当前账户价值
    private func getCurrentAccountValue() -> Double {
        let positions = getAllPositions()
        let positionsValue = positions.reduce(0) { total, position in
            total + Double(position.quantity) * position.currentPrice
        }
        
        // 这里应该从实际的账户信息中获取现金余额
        let cashBalance = 100000.0 // 示例值
        
        return cashBalance + positionsValue
    }
    
    /// 获取初始账户价值
    private func getInitialAccountValue() -> Double {
        // 这里应该从存储中获取初始账户价值
        return 100000.0 // 示例值
    }
    
    /// 计算行业敞口
    private func calculateIndustryExposure(symbol: String, addPosition: Double) -> Double {
        // 这里应该根据实际的行业分类来计算
        // 简化实现，假设同行业股票有相同前缀
        let positions = getAllPositions()
        let industryPrefix = String(symbol.prefix(2))
        
        let industryValue = positions.filter { position in
            (position.symbol ?? "").hasPrefix(industryPrefix)
        }.reduce(addPosition) { total, position in
            total + Double(position.quantity) * position.currentPrice
        }
        
        let accountValue = getCurrentAccountValue()
        return accountValue > 0 ? industryValue / accountValue : 0
    }
    
    /// 计算当前杠杆
    private func calculateCurrentLeverage() -> Double {
        let accountValue = getCurrentAccountValue()
        return accountValue > 0 ? totalExposure / accountValue : 0
    }
    
    /// 评估流动性风险
    private func assessLiquidityRisk(symbol: String, quantity: Int) -> Double {
        // 这里应该根据股票的实际交易量来评估
        // 简化实现，返回一个固定值
        return 0.1
    }
    
    /// 计算相关性风险
    private func calculateCorrelationRisk(symbol: String, positionValue: Double) -> Double {
        // 这里应该计算与现有持仓的相关性
        // 简化实现，返回一个固定值
        return 0.3
    }
    
    /// 计算潜在损失
    private func calculatePotentialLoss(positionValue: Double) -> Double {
        // 基于历史波动率计算潜在损失
        let volatility = 0.02 // 假设日波动率为2%
        return positionValue * volatility * 1.96 // 95%置信区间
    }
    
    /// 生成风险建议
    private func generateRiskRecommendations(riskLevel: RiskLevel, warnings: [String]) -> [String] {
        var recommendations: [String] = []
        
        switch riskLevel {
        case .low:
            recommendations.append("风险可控，可以考虑适当增加仓位")
        case .medium:
            recommendations.append("注意控制风险，建议设置止损")
        case .high:
            recommendations.append("风险较高，建议减少仓位")
            recommendations.append("严格执行止损策略")
        case .critical:
            recommendations.append("风险极高，建议立即减仓")
            recommendations.append("暂停新增投资")
        }
        
        return recommendations
    }
    
    /// 计算投资组合集中度
    private func calculatePortfolioConcentration() -> Double {
        let positions = getAllPositions()
        guard !positions.isEmpty else { return 0 }
        
        let totalValue = positions.reduce(0) { total, position in
            total + Double(position.quantity) * position.currentPrice
        }
        
        guard totalValue > 0 else { return 0 }
        
        // 计算赫芬达尔指数
        let herfindahlIndex = positions.reduce(0) { total, position in
            let weight = (Double(position.quantity) * position.currentPrice) / totalValue
            return total + weight * weight
        }
        
        return herfindahlIndex
    }
    
    /// 添加风险警报
    private func addRiskAlert(_ alert: RiskAlert) {
        riskAlerts.insert(alert, at: 0)
        
        // 限制警报数量
        if riskAlerts.count > 100 {
            riskAlerts = Array(riskAlerts.prefix(100))
        }
    }
    
    /// 清理过期警报
    private func cleanupExpiredAlerts() {
        let expirationTime: TimeInterval = 24 * 60 * 60 // 24小时
        let cutoffDate = Date().addingTimeInterval(-expirationTime)
        
        riskAlerts.removeAll { alert in
            alert.timestamp < cutoffDate
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
    
    /// 获取特定持仓
    private func getPosition(symbol: String) -> PositionEntity? {
        let positions = getAllPositions()
        return positions.first { $0.symbol == symbol }
    }
    
    /// 计算未实现盈亏
    private func calculateUnrealizedPnL(position: PositionEntity) -> Double {
        let currentValue = Double(position.quantity) * position.currentPrice
        let costBasis = Double(position.quantity) * position.avgPrice
        return currentValue - costBasis
    }
    
    /// 计算VaR
    private func calculateVaR(position: PositionEntity, confidenceLevel: Double) -> Double {
        // 简化实现，基于假设的波动率
        let volatility = 0.02 // 假设日波动率为2%
        let zScore = confidenceLevel == 0.95 ? 1.645 : 2.326
        let positionValue = Double(position.quantity) * position.currentPrice
        
        return positionValue * volatility * zScore
    }
    
    /// 计算投资组合收益率
    private func calculatePortfolioReturns() -> [Double] {
        // 这里应该从历史数据中计算实际收益率
        // 简化实现，返回模拟数据
        return (0..<30).map { _ in Double.random(in: -0.05...0.05) }
    }
    
    /// 计算波动率
    private func calculateVolatility(returns: [Double]) -> Double {
        guard returns.count > 1 else { return 0 }
        
        let mean = returns.reduce(0, +) / Double(returns.count)
        let variance = returns.reduce(0) { total, ret in
            total + pow(ret - mean, 2)
        } / Double(returns.count - 1)
        
        return sqrt(variance)
    }
    
    /// 计算投资组合Beta
    private func calculatePortfolioBeta() -> Double {
        // 简化实现，返回假设值
        return 1.0
    }
    
    /// 计算投资组合夏普比率
    private func calculatePortfolioSharpeRatio() -> Double {
        let returns = calculatePortfolioReturns()
        let avgReturn = returns.reduce(0, +) / Double(returns.count)
        let volatility = calculateVolatility(returns: returns)
        let riskFreeRate = 0.03 / 252 // 假设年化无风险利率3%
        
        return volatility > 0 ? (avgReturn - riskFreeRate) / volatility : 0
    }
    
    /// 计算投资组合VaR
    private func calculatePortfolioVaR(confidenceLevel: Double) -> Double {
        let portfolioValue = getCurrentAccountValue()
        let volatility = riskMetrics.portfolioVolatility
        let zScore = confidenceLevel == 0.95 ? 1.645 : 2.326
        
        return portfolioValue * volatility * zScore
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

/// 风险检查结果
public struct RiskCheckResult {
    let canTrade: Bool
    let riskLevel: RiskLevel
    let warnings: [String]
    let positionWeight: Double
    let estimatedLoss: Double
    let recommendations: [String]
}

/// 风险等级
public enum RiskLevel: Int, CaseIterable {
    case low = 0
    case medium = 1
    case high = 2
    case critical = 3
    
    var description: String {
        switch self {
        case .low: return "低"
        case .medium: return "中"
        case .high: return "高"
        case .critical: return "极高"
        }
    }
    
    var color: String {
        switch self {
        case .low: return "green"
        case .medium: return "yellow"
        case .high: return "orange"
        case .critical: return "red"
        }
    }
}

/// 账户风险等级
public enum AccountRiskLevel: Int, CaseIterable {
    case low = 0
    case medium = 1
    case high = 2
    case critical = 3
    
    var description: String {
        switch self {
        case .low: return "低风险"
        case .medium: return "中等风险"
        case .high: return "高风险"
        case .critical: return "极高风险"
        }
    }
}

/// 风险警报
public struct RiskAlert: Identifiable {
    public let id = UUID()
    let type: RiskAlertType
    let level: RiskLevel
    let message: String
    let timestamp: Date
    let details: [String: String]
}

/// 风险警报类型
public enum RiskAlertType: String, CaseIterable {
    case accountRisk = "账户风险"
    case positionRisk = "持仓风险"
    case stopLoss = "止损"
    case takeProfit = "止盈"
    case drawdown = "回撤"
    case leverage = "杠杆"
    case concentration = "集中度"
    case liquidity = "流动性"
}

/// 风险参数
public struct RiskParameters {
    let maxSinglePositionWeight: Double     // 单个持仓最大权重
    let maxIndustryConcentration: Double    // 最大行业集中度
    let maxLeverage: Double                 // 最大杠杆倍数
    let maxDrawdown: Double                 // 最大回撤
    let maxLiquidityRisk: Double           // 最大流动性风险
    let maxCorrelationRisk: Double         // 最大相关性风险
    let maxStopLossDistance: Double        // 最大止损距离
    let trailingStopDistance: Double       // 跟踪止损距离
    
    public static func defaultParameters() -> RiskParameters {
        return RiskParameters(
            maxSinglePositionWeight: 0.15,      // 15%
            maxIndustryConcentration: 0.30,     // 30%
            maxLeverage: 1.5,                   // 1.5倍
            maxDrawdown: 0.20,                  // 20%
            maxLiquidityRisk: 0.25,             // 25%
            maxCorrelationRisk: 0.60,           // 60%
            maxStopLossDistance: 0.10,          // 10%
            trailingStopDistance: 0.05          // 5%
        )
    }
}

/// 风险指标
public struct RiskMetrics {
    var portfolioVolatility: Double = 0     // 投资组合波动率
    var portfolioBeta: Double = 0           // 投资组合Beta
    var sharpeRatio: Double = 0             // 夏普比率
    var maxDrawdown: Double = 0             // 最大回撤
    var var95: Double = 0                   // 95% VaR
    var var99: Double = 0                   // 99% VaR
    var totalExposure: Double = 0           // 总敞口
    var leverage: Double = 0                // 杠杆倍数
}

/// 持仓风险评估
public struct PositionRiskAssessment {
    let symbol: String
    let riskLevel: RiskLevel
    let unrealizedPnL: Double
    let unrealizedPnLPercent: Double
    let var95: Double
    let var99: Double
    let recommendations: [String]
}
