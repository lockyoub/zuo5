/*
 StockEntity Core Data属性定义
 自动生成的属性文件 - 请勿手动编辑
 作者: MiniMax Agent
 创建时间: 2025-06-24 15:23:57
 */

import Foundation
import CoreData

extension StockEntity {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<StockEntity> {
        return NSFetchRequest<StockEntity>(entityName: "StockEntity")
    }

    @NSManaged public var symbol: String
    @NSManaged public var name: String
    @NSManaged public var exchange: String
    @NSManaged public var lastPrice: Double
    @NSManaged public var change: Double
    @NSManaged public var changePercent: Double
    @NSManaged public var volume: Int64
    @NSManaged public var amount: Double
    @NSManaged public var bidPrices: String?
    @NSManaged public var bidVolumes: String?
    @NSManaged public var askPrices: String?
    @NSManaged public var askVolumes: String?
    @NSManaged public var timestamp: Date
    @NSManaged public var klines: NSSet?
    @NSManaged public var trades: NSSet?
    @NSManaged public var positions: NSSet?
    @NSManaged public var orders: NSSet?

}

// MARK: Generated accessors for klines
extension StockEntity {

    @objc(addKlinesObject:)
    @NSManaged public func addToKlines(_ value: KLineEntity)

    @objc(removeKlinesObject:)
    @NSManaged public func removeFromKlines(_ value: KLineEntity)

    @objc(addKlines:)
    @NSManaged public func addToKlines(_ values: NSSet)

    @objc(removeKlines:)
    @NSManaged public func removeFromKlines(_ values: NSSet)

}

// MARK: Generated accessors for trades
extension StockEntity {

    @objc(addTradesObject:)
    @NSManaged public func addToTrades(_ value: TradeEntity)

    @objc(removeTradesObject:)
    @NSManaged public func removeFromTrades(_ value: TradeEntity)

    @objc(addTrades:)
    @NSManaged public func addToTrades(_ values: NSSet)

    @objc(removeTrades:)
    @NSManaged public func removeFromTrades(_ values: NSSet)

}

// MARK: Generated accessors for positions
extension StockEntity {

    @objc(addPositionsObject:)
    @NSManaged public func addToPositions(_ value: PositionEntity)

    @objc(removePositionsObject:)
    @NSManaged public func removeFromPositions(_ value: PositionEntity)

    @objc(addPositions:)
    @NSManaged public func addToPositions(_ values: NSSet)

    @objc(removePositions:)
    @NSManaged public func removeFromPositions(_ values: NSSet)

}

// MARK: Generated accessors for orders
extension StockEntity {

    @objc(addOrdersObject:)
    @NSManaged public func addToOrders(_ value: OrderEntity)

    @objc(removeOrdersObject:)
    @NSManaged public func removeFromOrders(_ value: OrderEntity)

    @objc(addOrders:)
    @NSManaged public func addToOrders(_ values: NSSet)

    @objc(removeOrders:)
    @NSManaged public func removeFromOrders(_ values: NSSet)

}
