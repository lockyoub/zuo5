/*
 KLineEntity Core Data属性定义
 自动生成的属性文件 - 请勿手动编辑
 作者: MiniMax Agent
 创建时间: 2025-06-24 15:23:57
 */

import Foundation
import CoreData

extension KLineEntity {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<KLineEntity> {
        return NSFetchRequest<KLineEntity>(entityName: "KLineEntity")
    }

    @NSManaged public var symbol: String
    @NSManaged public var timeframe: String
    @NSManaged public var timestamp: Date
    @NSManaged public var open: Double
    @NSManaged public var high: Double
    @NSManaged public var low: Double
    @NSManaged public var close: Double
    @NSManaged public var volume: Int64
    @NSManaged public var amount: Double
    @NSManaged public var stock: StockEntity?

}
