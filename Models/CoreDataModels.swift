/*
 Core Data数据模型扩展
 作者: MiniMax Agent
 */

import Foundation
import CoreData

// MARK: - StockEntity 扩展
extension StockEntity {
    /// 创建新的股票实体
    static func create(in context: NSManagedObjectContext, 
                      symbol: String, 
                      name: String, 
                      exchange: String) -> StockEntity {
        let stock = StockEntity(context: context)
        stock.symbol = symbol
        stock.name = name
        stock.exchange = exchange
        stock.timestamp = Date()
        return stock
    }
    
    /// 更新股票价格数据
    func updatePrice(price: Double, 
                    change: Double, 
                    changePercent: Double,
                    volume: Int64,
                    amount: Double) {
        self.lastPrice = price
        self.change = change
        self.changePercent = changePercent
        self.volume = volume
        self.amount = amount
        self.timestamp = Date()
    }
    
    /// 更新盘口数据
    func updateOrderBook(bidPrices: [Double], 
                        bidVolumes: [Int64],
                        askPrices: [Double], 
                        askVolumes: [Int64]) {
        // 转换为JSON字符串存储
        if let bidPricesData = try? JSONEncoder().encode(bidPrices) {
            self.bidPrices = String(data: bidPricesData, encoding: .utf8)
        }
        if let bidVolumesData = try? JSONEncoder().encode(bidVolumes) {
            self.bidVolumes = String(data: bidVolumesData, encoding: .utf8)
        }
        if let askPricesData = try? JSONEncoder().encode(askPrices) {
            self.askPrices = String(data: askPricesData, encoding: .utf8)
        }
        if let askVolumesData = try? JSONEncoder().encode(askVolumes) {
            self.askVolumes = String(data: askVolumesData, encoding: .utf8)
        }
    }
    
    /// 获取买盘价格数组
    var bidPricesArray: [Double] {
        guard let bidPricesString = bidPrices,
              let data = bidPricesString.data(using: .utf8),
              let prices = try? JSONDecoder().decode([Double].self, from: data) else {
            return []
        }
        return prices
    }
    
    /// 获取买盘数量数组
    var bidVolumesArray: [Int64] {
        guard let bidVolumesString = bidVolumes,
              let data = bidVolumesString.data(using: .utf8),
              let volumes = try? JSONDecoder().decode([Int64].self, from: data) else {
            return []
        }
        return volumes
    }
    
    /// 获取卖盘价格数组
    var askPricesArray: [Double] {
        guard let askPricesString = askPrices,
              let data = askPricesString.data(using: .utf8),
              let prices = try? JSONDecoder().decode([Double].self, from: data) else {
            return []
        }
        return prices
    }
    
    /// 获取卖盘数量数组
    var askVolumesArray: [Int64] {
        guard let askVolumesString = askVolumes,
              let data = askVolumesString.data(using: .utf8),
              let volumes = try? JSONDecoder().decode([Int64].self, from: data) else {
            return []
        }
        return volumes
    }
}

// MARK: - KLineEntity 扩展
extension KLineEntity {
    /// 创建新的K线数据
    static func create(in context: NSManagedObjectContext,
                      symbol: String,
                      timeframe: String,
                      timestamp: Date,
                      open: Double,
                      high: Double,
                      low: Double,
                      close: Double,
                      volume: Int64,
                      amount: Double) -> KLineEntity {
        let kline = KLineEntity(context: context)
        kline.symbol = symbol
        kline.timeframe = timeframe
        kline.timestamp = timestamp
        kline.open = open
        kline.high = high
        kline.low = low
        kline.close = close
        kline.volume = volume
        kline.amount = amount
        return kline
    }
    
    /// 计算涨跌幅
    var changePercent: Double {
        return ((close - open) / open) * 100
    }
    
    /// 判断是否为阳线
    var isRising: Bool {
        return close > open
    }
    
    /// 获取K线颜色
    var color: String {
        return isRising ? "red" : "green"  // 中国股市：红涨绿跌
    }
}

// MARK: - TradeEntity 扩展
extension TradeEntity {
    /// 创建新的交易记录
    static func create(in context: NSManagedObjectContext,
                      symbol: String,
                      direction: String,
                      quantity: Int64,
                      price: Double,
                      strategy: String) -> TradeEntity {
        let trade = TradeEntity(context: context)
        trade.id = UUID()
        trade.symbol = symbol
        trade.direction = direction
        trade.quantity = quantity
        trade.price = price
        trade.timestamp = Date()
        trade.strategy = strategy
        trade.pnl = 0.0  // 初始PnL为0，后续更新
        return trade
    }
    
    /// 计算交易金额
    var amount: Double {
        return Double(quantity) * price
    }
    
    /// 判断是否为买入
    var isBuy: Bool {
        return direction == "buy"
    }
    
    /// 获取交易方向显示文本
    var directionText: String {
        return isBuy ? "买入" : "卖出"
    }
    
    /// 格式化时间显示
    var formattedTime: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM-dd HH:mm:ss"
        return formatter.string(from: timestamp ?? Date())
    }
}

// MARK: - PositionEntity 扩展
extension PositionEntity {
    /// 创建新的持仓记录
    static func create(in context: NSManagedObjectContext,
                      symbol: String,
                      quantity: Int64,
                      avgPrice: Double) -> PositionEntity {
        let position = PositionEntity(context: context)
        position.symbol = symbol
        position.quantity = quantity
        position.avgPrice = avgPrice
        position.currentPrice = avgPrice
        position.unrealizedPnl = 0.0
        position.realizedPnl = 0.0
        position.updateTime = Date()
        return position
    }
    
    /// 更新持仓
    func updatePosition(quantity: Int64, avgPrice: Double) {
        self.quantity = quantity
        self.avgPrice = avgPrice
        self.updateTime = Date()
        updateUnrealizedPnl()
    }
    
    /// 更新当前价格和未实现盈亏
    func updateCurrentPrice(_ price: Double) {
        self.currentPrice = price
        updateUnrealizedPnl()
        self.updateTime = Date()
    }
    
    /// 计算未实现盈亏
    private func updateUnrealizedPnl() {
        self.unrealizedPnl = (currentPrice - avgPrice) * Double(quantity)
    }
    
    /// 更新已实现盈亏
    func addRealizedPnl(_ pnl: Double) {
        self.realizedPnl += pnl
        self.updateTime = Date()
    }
    
    /// 获取总盈亏
    var totalPnl: Double {
        return unrealizedPnl + realizedPnl
    }
    
    /// 获取盈亏百分比
    var pnlPercent: Double {
        guard avgPrice > 0 else { return 0 }
        return ((currentPrice - avgPrice) / avgPrice) * 100
    }
    
    /// 获取市值
    var marketValue: Double {
        return currentPrice * Double(quantity)
    }
    
    /// 获取成本
    var cost: Double {
        return avgPrice * Double(quantity)
    }
}

// MARK: - StrategyEntity 扩展
extension StrategyEntity {
    /// 创建新的策略配置
    static func create(in context: NSManagedObjectContext,
                      name: String,
                      type: String,
                      timeframe: String) -> StrategyEntity {
        let strategy = StrategyEntity(context: context)
        strategy.id = UUID()
        strategy.name = name
        strategy.type = type
        strategy.timeframe = timeframe
        strategy.isEnabled = true
        strategy.parameters = "{}"  // 默认空JSON参数
        strategy.createTime = Date()
        strategy.updateTime = Date()
        return strategy
    }
    
    /// 更新策略参数
    func updateParameters(_ params: [String: Any]) {
        if let data = try? JSONSerialization.data(withJSONObject: params),
           let jsonString = String(data: data, encoding: .utf8) {
            self.parameters = jsonString
            self.updateTime = Date()
        }
    }
    
    /// 获取策略参数字典
    var parametersDict: [String: Any] {
        guard let parametersString = parameters,
              let data = parametersString.data(using: .utf8),
              let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return [:]
        }
        return dict
    }
    
    /// 启用策略
    func enable() {
        isEnabled = true
        updateTime = Date()
    }
    
    /// 禁用策略
    func disable() {
        isEnabled = false
        updateTime = Date()
    }
    
    /// 获取策略状态文本
    var statusText: String {
        return isEnabled ? "启用" : "禁用"
    }
}
