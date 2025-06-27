/*
 完整的数据模型定义
 包含所有Core Data实体的详细定义和关系
 作者: MiniMax Agent
 创建时间: 2025-06-24 14:58:05
 */

import Foundation
import CoreData

// MARK: - Core Data实体定义

/*
 注意: 这个文件定义了Core Data模型的结构，
 实际的.xcdatamodeld文件需要在Xcode中创建并配置相应的实体和属性
 */

// MARK: - StockEntity
/*
 股票信息实体
 存储股票的基本信息和实时价格数据
 */
@objc(StockEntity)
public class StockEntity: NSManagedObject {
    // 基本信息
    @NSManaged public var symbol: String          // 股票代码 (Primary Key)
    @NSManaged public var name: String            // 股票名称
    @NSManaged public var exchange: String        // 交易所
    
    // 价格信息
    @NSManaged public var lastPrice: Double       // 最新价
    @NSManaged public var change: Double          // 涨跌额
    @NSManaged public var changePercent: Double   // 涨跌幅
    @NSManaged public var volume: Int64           // 成交量
    @NSManaged public var amount: Double          // 成交额
    
    // 盘口数据 (JSON字符串格式存储)
    @NSManaged public var bidPrices: String?     // 买盘价格数组
    @NSManaged public var bidVolumes: String?    // 买盘数量数组
    @NSManaged public var askPrices: String?     // 卖盘价格数组
    @NSManaged public var askVolumes: String?    // 卖盘数量数组
    
    // 时间戳
    @NSManaged public var timestamp: Date
    
    // 关系
    @NSManaged public var klines: NSSet?          // 关联的K线数据
    @NSManaged public var trades: NSSet?          // 关联的交易记录
    @NSManaged public var positions: NSSet?       // 关联的持仓记录
}

// MARK: - KLineEntity
/*
 K线数据实体
 存储不同时间周期的K线数据
 */
@objc(KLineEntity)
public class KLineEntity: NSManagedObject {
    @NSManaged public var symbol: String          // 股票代码
    @NSManaged public var timeframe: String       // 时间周期 (1m, 5m, 1h, 1d等)
    @NSManaged public var timestamp: Date         // 时间戳
    
    // OHLC数据
    @NSManaged public var open: Double            // 开盘价
    @NSManaged public var high: Double            // 最高价
    @NSManaged public var low: Double             // 最低价
    @NSManaged public var close: Double           // 收盘价
    
    // 成交信息
    @NSManaged public var volume: Int64           // 成交量
    @NSManaged public var amount: Double          // 成交额
    
    // 关系
    @NSManaged public var stock: StockEntity?     // 关联的股票
}

// MARK: - TradeEntity
/*
 交易记录实体
 存储所有的交易执行记录
 */
@objc(TradeEntity)
public class TradeEntity: NSManagedObject {
    @NSManaged public var id: String              // 交易ID (Primary Key)
    @NSManaged public var symbol: String          // 股票代码
    @NSManaged public var direction: String       // 交易方向 (buy/sell)
    @NSManaged public var quantity: Int32         // 交易数量
    @NSManaged public var price: Double           // 成交价格
    @NSManaged public var amount: Double          // 成交金额
    @NSManaged public var commission: Double      // 手续费
    @NSManaged public var timestamp: Date         // 成交时间
    @NSManaged public var strategy: String?       // 关联策略ID
    @NSManaged public var pnl: Double            // 盈亏
    
    // 关系
    @NSManaged public var stock: StockEntity?     // 关联的股票
    @NSManaged public var strategyEntity: StrategyEntity? // 关联的策略
}

// MARK: - PositionEntity
/*
 持仓信息实体
 存储当前的持仓状态
 */
@objc(PositionEntity)
public class PositionEntity: NSManagedObject {
    @NSManaged public var symbol: String          // 股票代码 (Primary Key)
    @NSManaged public var quantity: Int32         // 持仓数量
    @NSManaged public var avgPrice: Double        // 平均成本价
    @NSManaged public var currentPrice: Double    // 当前价格
    @NSManaged public var marketValue: Double     // 市值
    @NSManaged public var unrealizedPnL: Double   // 浮动盈亏
    @NSManaged public var realizedPnL: Double     // 已实现盈亏
    @NSManaged public var updateTime: Date        // 更新时间
    
    // 关系
    @NSManaged public var stock: StockEntity?     // 关联的股票
}

// MARK: - StrategyEntity
/*
 策略配置实体
 存储交易策略的配置和状态
 */
@objc(StrategyEntity)
public class StrategyEntity: NSManagedObject {
    @NSManaged public var id: String              // 策略ID (Primary Key)
    @NSManaged public var name: String            // 策略名称
    @NSManaged public var type: String            // 策略类型
    @NSManaged public var timeframe: String       // 时间周期
    @NSManaged public var isEnabled: Bool         // 是否启用
    @NSManaged public var parameters: String      // 策略参数 (JSON格式)
    @NSManaged public var createTime: Date        // 创建时间
    @NSManaged public var updateTime: Date        // 更新时间
    
    // 性能统计
    @NSManaged public var totalTrades: Int32      // 总交易次数
    @NSManaged public var winTrades: Int32        // 盈利交易次数
    @NSManaged public var totalPnL: Double        // 总盈亏
    @NSManaged public var maxDrawdown: Double     // 最大回撤
    @NSManaged public var sharpeRatio: Double     // 夏普比率
    
    // 关系
    @NSManaged public var trades: NSSet?          // 关联的交易记录
}

// MARK: - OrderEntity
/*
 订单实体
 存储订单的详细信息和状态
 */
@objc(OrderEntity)
public class OrderEntity: NSManagedObject {
    @NSManaged public var id: String              // 订单ID (Primary Key)
    @NSManaged public var symbol: String          // 股票代码
    @NSManaged public var direction: String       // 交易方向
    @NSManaged public var orderType: String       // 订单类型
    @NSManaged public var quantity: Int32         // 委托数量
    @NSManaged public var filledQuantity: Int32   // 成交数量
    @NSManaged public var price: Double           // 委托价格
    @NSManaged public var avgPrice: Double        // 平均成交价
    @NSManaged public var status: String          // 订单状态
    @NSManaged public var createTime: Date        // 创建时间
    @NSManaged public var updateTime: Date        // 更新时间
    @NSManaged public var strategy: String?       // 关联策略ID
    
    // 关系
    @NSManaged public var stock: StockEntity?     // 关联的股票
}

// MARK: - Core Data扩展

// StockEntity扩展
extension StockEntity {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<StockEntity> {
        return NSFetchRequest<StockEntity>(entityName: "StockEntity")
    }
    
    /// 查找或创建股票实体
    static func findOrCreate(symbol: String, in context: NSManagedObjectContext) -> StockEntity {
        let request: NSFetchRequest<StockEntity> = StockEntity.fetchRequest()
        request.predicate = NSPredicate(format: "symbol == %@", symbol)
        
        if let existing = try? context.fetch(request).first {
            return existing
        } else {
            let newStock = StockEntity(context: context)
            newStock.symbol = symbol
            newStock.timestamp = Date()
            return newStock
        }
    }
    
    /// 获取盘口买盘价格
    var bidPriceArray: [Double] {
        guard let bidPrices = bidPrices,
              let data = bidPrices.data(using: .utf8),
              let prices = try? JSONDecoder().decode([Double].self, from: data) else {
            return []
        }
        return prices
    }
    
    /// 获取盘口卖盘价格
    var askPriceArray: [Double] {
        guard let askPrices = askPrices,
              let data = askPrices.data(using: .utf8),
              let prices = try? JSONDecoder().decode([Double].self, from: data) else {
            return []
        }
        return prices
    }
}

// KLineEntity扩展
extension KLineEntity {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<KLineEntity> {
        return NSFetchRequest<KLineEntity>(entityName: "KLineEntity")
    }
    
    /// 获取指定股票和时间周期的K线数据
    static func fetchKLines(symbol: String, timeframe: String, limit: Int, in context: NSManagedObjectContext) -> [KLineEntity] {
        let request: NSFetchRequest<KLineEntity> = KLineEntity.fetchRequest()
        request.predicate = NSPredicate(format: "symbol == %@ AND timeframe == %@", symbol, timeframe)
        request.sortDescriptors = [NSSortDescriptor(key: "timestamp", ascending: false)]
        request.fetchLimit = limit
        
        return (try? context.fetch(request)) ?? []
    }
}

// TradeEntity扩展
extension TradeEntity {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<TradeEntity> {
        return NSFetchRequest<TradeEntity>(entityName: "TradeEntity")
    }
    
    /// 获取指定股票的交易记录
    static func fetchTrades(symbol: String? = nil, limit: Int = 100, in context: NSManagedObjectContext) -> [TradeEntity] {
        let request: NSFetchRequest<TradeEntity> = TradeEntity.fetchRequest()
        
        if let symbol = symbol {
            request.predicate = NSPredicate(format: "symbol == %@", symbol)
        }
        
        request.sortDescriptors = [NSSortDescriptor(key: "timestamp", ascending: false)]
        request.fetchLimit = limit
        
        return (try? context.fetch(request)) ?? []
    }
}

// PositionEntity扩展
extension PositionEntity {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<PositionEntity> {
        return NSFetchRequest<PositionEntity>(entityName: "PositionEntity")
    }
    
    /// 查找或创建持仓实体
    static func findOrCreate(symbol: String, in context: NSManagedObjectContext) -> PositionEntity {
        let request: NSFetchRequest<PositionEntity> = PositionEntity.fetchRequest()
        request.predicate = NSPredicate(format: "symbol == %@", symbol)
        
        if let existing = try? context.fetch(request).first {
            return existing
        } else {
            let newPosition = PositionEntity(context: context)
            newPosition.symbol = symbol
            newPosition.updateTime = Date()
            return newPosition
        }
    }
    
    /// 计算盈亏比例
    var unrealizedPnLPercent: Double {
        guard avgPrice > 0 else { return 0 }
        return unrealizedPnL / (avgPrice * Double(quantity))
    }
}

// StrategyEntity扩展
extension StrategyEntity {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<StrategyEntity> {
        return NSFetchRequest<StrategyEntity>(entityName: "StrategyEntity")
    }
    
    /// 获取策略参数字典
    var parametersDict: [String: Any] {
        guard let parameters = parameters,
              let data = parameters.data(using: .utf8),
              let dict = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] else {
            return [:]
        }
        return dict
    }
    
    /// 设置策略参数
    func setParameters(_ dict: [String: Any]) {
        if let data = try? JSONSerialization.data(withJSONObject: dict, options: []),
           let jsonString = String(data: data, encoding: .utf8) {
            self.parameters = jsonString
        }
    }
    
    /// 计算胜率
    var winRate: Double {
        guard totalTrades > 0 else { return 0 }
        return Double(winTrades) / Double(totalTrades)
    }
}

// OrderEntity扩展
extension OrderEntity {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<OrderEntity> {
        return NSFetchRequest<OrderEntity>(entityName: "OrderEntity")
    }
    
    /// 获取指定状态的订单
    static func fetchOrders(status: String? = nil, symbol: String? = nil, limit: Int = 50, in context: NSManagedObjectContext) -> [OrderEntity] {
        let request: NSFetchRequest<OrderEntity> = OrderEntity.fetchRequest()
        
        var predicates: [NSPredicate] = []
        
        if let status = status {
            predicates.append(NSPredicate(format: "status == %@", status))
        }
        
        if let symbol = symbol {
            predicates.append(NSPredicate(format: "symbol == %@", symbol))
        }
        
        if !predicates.isEmpty {
            request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
        }
        
        request.sortDescriptors = [NSSortDescriptor(key: "createTime", ascending: false)]
        request.fetchLimit = limit
        
        return (try? context.fetch(request)) ?? []
    }
    
    /// 计算完成比例
    var completionRate: Double {
        guard quantity > 0 else { return 0 }
        return Double(filledQuantity) / Double(quantity)
    }
}

// MARK: - 数据转换助手

struct CoreDataHelper {
    /// 将服务器返回的股票数据转换为Core Data实体
    static func updateStock(from serverData: [String: Any], in context: NSManagedObjectContext) -> StockEntity? {
        guard let symbol = serverData["symbol"] as? String else { return nil }
        
        let stock = StockEntity.findOrCreate(symbol: symbol, in: context)
        
        // 更新基本信息
        if let name = serverData["name"] as? String {
            stock.name = name
        }
        if let exchange = serverData["exchange"] as? String {
            stock.exchange = exchange
        }
        
        // 更新价格信息
        if let lastPrice = serverData["last_price"] as? Double {
            stock.lastPrice = lastPrice
        }
        if let change = serverData["change"] as? Double {
            stock.change = change
        }
        if let changePercent = serverData["change_percent"] as? Double {
            stock.changePercent = changePercent
        }
        if let volume = serverData["volume"] as? Int64 {
            stock.volume = volume
        }
        if let amount = serverData["amount"] as? Double {
            stock.amount = amount
        }
        
        // 更新盘口数据
        if let bidPrices = serverData["bid_prices"] as? [Double],
           let bidPricesData = try? JSONEncoder().encode(bidPrices) {
            stock.bidPrices = String(data: bidPricesData, encoding: .utf8)
        }
        
        if let askPrices = serverData["ask_prices"] as? [Double],
           let askPricesData = try? JSONEncoder().encode(askPrices) {
            stock.askPrices = String(data: askPricesData, encoding: .utf8)
        }
        
        stock.timestamp = Date()
        
        return stock
    }
    
    /// 保存上下文
    static func saveContext(_ context: NSManagedObjectContext) {
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                print("保存Core Data失败: \(error)")
            }
        }
    }
}
