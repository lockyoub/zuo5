/*
 StockEntity Core Data类扩展
 股票信息实体类
 作者: MiniMax Agent
 创建时间: 2025-06-24 15:23:57
 */

import Foundation
import CoreData

@objc(StockEntity)
public class StockEntity: NSManagedObject {
    
    // MARK: - 便利属性
    
    /// 买盘价格数组
    var bidPricesArray: [Double] {
        get {
            guard let bidPrices = bidPrices,
                  let data = bidPrices.data(using: .utf8),
                  let array = try? JSONDecoder().decode([Double].self, from: data) else {
                return []
            }
            return array
        }
        set {
            if let data = try? JSONEncoder().encode(newValue),
               let string = String(data: data, encoding: .utf8) {
                bidPrices = string
            }
        }
    }
    
    /// 买盘数量数组
    var bidVolumesArray: [Int64] {
        get {
            guard let bidVolumes = bidVolumes,
                  let data = bidVolumes.data(using: .utf8),
                  let array = try? JSONDecoder().decode([Int64].self, from: data) else {
                return []
            }
            return array
        }
        set {
            if let data = try? JSONEncoder().encode(newValue),
               let string = String(data: data, encoding: .utf8) {
                bidVolumes = string
            }
        }
    }
    
    /// 卖盘价格数组
    var askPricesArray: [Double] {
        get {
            guard let askPrices = askPrices,
                  let data = askPrices.data(using: .utf8),
                  let array = try? JSONDecoder().decode([Double].self, from: data) else {
                return []
            }
            return array
        }
        set {
            if let data = try? JSONEncoder().encode(newValue),
               let string = String(data: data, encoding: .utf8) {
                askPrices = string
            }
        }
    }
    
    /// 卖盘数量数组
    var askVolumesArray: [Int64] {
        get {
            guard let askVolumes = askVolumes,
                  let data = askVolumes.data(using: .utf8),
                  let array = try? JSONDecoder().decode([Int64].self, from: data) else {
                return []
            }
            return array
        }
        set {
            if let data = try? JSONEncoder().encode(newValue),
               let string = String(data: data, encoding: .utf8) {
                askVolumes = string
            }
        }
    }
    
    // MARK: - 便利方法
    
    /// 更新股票价格信息
    func updatePrice(
        lastPrice: Double,
        change: Double,
        changePercent: Double,
        volume: Int64,
        amount: Double
    ) {
        self.lastPrice = lastPrice
        self.change = change
        self.changePercent = changePercent
        self.volume = volume
        self.amount = amount
        self.timestamp = Date()
    }
    
    /// 更新盘口数据
    func updateOrderBook(
        bidPrices: [Double],
        bidVolumes: [Int64],
        askPrices: [Double],
        askVolumes: [Int64]
    ) {
        self.bidPricesArray = bidPrices
        self.bidVolumesArray = bidVolumes
        self.askPricesArray = askPrices
        self.askVolumesArray = askVolumes
        self.timestamp = Date()
    }
    
    /// 格式化价格显示
    var formattedPrice: String {
        return String(format: "%.2f", lastPrice)
    }
    
    /// 格式化涨跌幅显示
    var formattedChangePercent: String {
        let sign = changePercent >= 0 ? "+" : ""
        return "\(sign)\(String(format: "%.2f", changePercent))%"
    }
    
    /// 格式化成交量显示
    var formattedVolume: String {
        if volume >= 100_000_000 {
            return String(format: "%.1f亿", Double(volume) / 100_000_000)
        } else if volume >= 10_000 {
            return String(format: "%.1f万", Double(volume) / 10_000)
        } else {
            return "\(volume)"
        }
    }
    
    /// 是否上涨
    var isUp: Bool {
        return changePercent > 0
    }
    
    /// 是否下跌
    var isDown: Bool {
        return changePercent < 0
    }
    
    /// 是否平盘
    var isFlat: Bool {
        return changePercent == 0
    }
}

// MARK: - Identifiable
extension StockEntity: Identifiable {
    public var id: String { symbol }
}
