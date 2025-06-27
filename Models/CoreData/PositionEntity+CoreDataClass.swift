/*
 PositionEntity Core Data类扩展
 持仓信息实体类
 作者: MiniMax Agent
 创建时间: 2025-06-24 15:23:57
 */

import Foundation
import CoreData

@objc(PositionEntity)
public class PositionEntity: NSManagedObject {
    
    // MARK: - 便利属性
    
    /// 是否持仓
    var hasPosition: Bool {
        return quantity != 0
    }
    
    /// 是否多头持仓
    var isLongPosition: Bool {
        return quantity > 0
    }
    
    /// 是否空头持仓
    var isShortPosition: Bool {
        return quantity < 0
    }
    
    /// 绝对持仓数量
    var absoluteQuantity: Int32 {
        return abs(quantity)
    }
    
    /// 是否盈利
    var isProfitable: Bool {
        return pnl > 0
    }
    
    /// 是否亏损
    var isLoss: Bool {
        return pnl < 0
    }
    
    /// 持仓成本
    var totalCost: Double {
        return avgCost * Double(absoluteQuantity)
    }
    
    /// 浮动盈亏金额
    var unrealizedPnl: Double {
        return (currentPrice - avgCost) * Double(quantity)
    }
    
    /// 浮动盈亏率
    var unrealizedPnlPercent: Double {
        guard avgCost > 0 else { return 0 }
        return ((currentPrice - avgCost) / avgCost) * 100
    }
    
    // MARK: - 格式化方法
    
    /// 格式化持仓数量
    var formattedQuantity: String {
        let sign = quantity >= 0 ? "" : "-"
        return "\(sign)\(absoluteQuantity)"
    }
    
    /// 格式化平均成本
    var formattedAvgCost: String {
        return String(format: "%.2f", avgCost)
    }
    
    /// 格式化当前价格
    var formattedCurrentPrice: String {
        return String(format: "%.2f", currentPrice)
    }
    
    /// 格式化市值
    var formattedMarketValue: String {
        return String(format: "%.2f", marketValue)
    }
    
    /// 格式化盈亏
    var formattedPnl: String {
        let sign = pnl >= 0 ? "+" : ""
        return "\(sign)\(String(format: "%.2f", pnl))"
    }
    
    /// 格式化盈亏率
    var formattedPnlPercent: String {
        let sign = pnlPercent >= 0 ? "+" : ""
        return "\(sign)\(String(format: "%.2f", pnlPercent))%"
    }
    
    /// 格式化浮动盈亏
    var formattedUnrealizedPnl: String {
        let sign = unrealizedPnl >= 0 ? "+" : ""
        return "\(sign)\(String(format: "%.2f", unrealizedPnl))"
    }
    
    /// 格式化浮动盈亏率
    var formattedUnrealizedPnlPercent: String {
        let sign = unrealizedPnlPercent >= 0 ? "+" : ""
        return "\(sign)\(String(format: "%.2f", unrealizedPnlPercent))%"
    }
    
    /// 格式化更新时间
    var formattedUpdateTime: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM-dd HH:mm:ss"
        return formatter.string(from: lastUpdate)
    }
    
    // MARK: - 便利方法
    
    /// 更新持仓信息
    func updatePosition(
        quantity: Int32,
        avgCost: Double,
        currentPrice: Double
    ) {
        self.quantity = quantity
        self.avgCost = avgCost
        self.currentPrice = currentPrice
        self.marketValue = Double(quantity) * currentPrice
        self.pnl = unrealizedPnl
        self.pnlPercent = unrealizedPnlPercent
        self.lastUpdate = Date()
    }
    
    /// 更新当前价格
    func updateCurrentPrice(_ price: Double) {
        self.currentPrice = price
        self.marketValue = Double(quantity) * price
        self.pnl = unrealizedPnl
        self.pnlPercent = unrealizedPnlPercent
        self.lastUpdate = Date()
    }
    
    /// 加仓操作
    func addPosition(quantity addQuantity: Int32, price: Double) {
        let newTotalQuantity = self.quantity + addQuantity
        let newTotalCost = (Double(self.quantity) * self.avgCost) + (Double(addQuantity) * price)
        
        if newTotalQuantity != 0 {
            self.avgCost = newTotalCost / Double(newTotalQuantity)
        }
        
        self.quantity = newTotalQuantity
        self.marketValue = Double(newTotalQuantity) * self.currentPrice
        self.lastUpdate = Date()
        
        // 重新计算盈亏
        self.pnl = unrealizedPnl
        self.pnlPercent = unrealizedPnlPercent
    }
    
    /// 减仓操作
    func reducePosition(quantity reduceQuantity: Int32) {
        guard self.quantity != 0 else { return }
        
        let newQuantity = self.quantity - reduceQuantity
        self.quantity = max(0, newQuantity) // 不允许数量为负
        self.marketValue = Double(self.quantity) * self.currentPrice
        self.lastUpdate = Date()
        
        // 重新计算盈亏
        self.pnl = unrealizedPnl
        self.pnlPercent = unrealizedPnlPercent
    }
    
    /// 平仓操作
    func closePosition() {
        self.quantity = 0
        self.marketValue = 0
        self.pnl = 0
        self.pnlPercent = 0
        self.lastUpdate = Date()
    }
    
    /// 持仓状态描述
    var positionStatus: String {
        if !hasPosition {
            return "无持仓"
        } else if isLongPosition {
            return "多头持仓"
        } else {
            return "空头持仓"
        }
    }
    
    /// 风险等级
    var riskLevel: RiskLevel {
        let riskPercent = abs(pnlPercent)
        
        if riskPercent < 2 {
            return .low
        } else if riskPercent < 5 {
            return .medium
        } else if riskPercent < 10 {
            return .high
        } else {
            return .veryHigh
        }
    }
    
    enum RiskLevel: String, CaseIterable {
        case low = "低风险"
        case medium = "中等风险"
        case high = "高风险"
        case veryHigh = "极高风险"
        
        var color: String {
            switch self {
            case .low: return "green"
            case .medium: return "yellow"
            case .high: return "orange"
            case .veryHigh: return "red"
            }
        }
    }
    
    // MARK: - 查询方法
    
    /// 获取所有持仓
    static func fetchAllPositions(in context: NSManagedObjectContext) -> [PositionEntity] {
        let request: NSFetchRequest<PositionEntity> = PositionEntity.fetchRequest()
        request.predicate = NSPredicate(format: "quantity != 0")
        request.sortDescriptors = [NSSortDescriptor(keyPath: \PositionEntity.marketValue, ascending: false)]
        
        do {
            return try context.fetch(request)
        } catch {
            print("获取持仓数据失败: \(error)")
            return []
        }
    }
    
    /// 获取盈利持仓
    static func fetchProfitablePositions(in context: NSManagedObjectContext) -> [PositionEntity] {
        let request: NSFetchRequest<PositionEntity> = PositionEntity.fetchRequest()
        request.predicate = NSPredicate(format: "quantity != 0 AND pnl > 0")
        request.sortDescriptors = [NSSortDescriptor(keyPath: \PositionEntity.pnl, ascending: false)]
        
        do {
            return try context.fetch(request)
        } catch {
            print("获取盈利持仓失败: \(error)")
            return []
        }
    }
    
    /// 获取亏损持仓
    static func fetchLossPositions(in context: NSManagedObjectContext) -> [PositionEntity] {
        let request: NSFetchRequest<PositionEntity> = PositionEntity.fetchRequest()
        request.predicate = NSPredicate(format: "quantity != 0 AND pnl < 0")
        request.sortDescriptors = [NSSortDescriptor(keyPath: \PositionEntity.pnl, ascending: true)]
        
        do {
            return try context.fetch(request)
        } catch {
            print("获取亏损持仓失败: \(error)")
            return []
        }
    }
    
    /// 计算总市值
    static func totalMarketValue(in context: NSManagedObjectContext) -> Double {
        let positions = fetchAllPositions(in: context)
        return positions.reduce(0) { $0 + $1.marketValue }
    }
    
    /// 计算总盈亏
    static func totalPnl(in context: NSManagedObjectContext) -> Double {
        let positions = fetchAllPositions(in: context)
        return positions.reduce(0) { $0 + $1.pnl }
    }
}

// MARK: - Identifiable
extension PositionEntity: Identifiable {
    public var id: String { symbol }
}
