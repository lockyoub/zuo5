/*
 Core Data持久化控制器
 作者: MiniMax Agent
 */

import CoreData
import Foundation

struct PersistenceController {
    static let shared = PersistenceController()
    
    static var preview: PersistenceController = {
        let result = PersistenceController(inMemory: true)
        let viewContext = result.container.viewContext
        
        // 创建预览数据
        createPreviewData(in: viewContext)
        
        do {
            try viewContext.save()
        } catch {
            let nsError = error as NSError
            fatalError("预览数据创建失败: \(nsError), \(nsError.userInfo)")
        }
        return result
    }()

    let container: NSPersistentContainer

    init(inMemory: Bool = false) {
        container = NSPersistentContainer(name: "TradingDataModel")
        
        if inMemory {
            container.persistentStoreDescriptions.first!.url = URL(fileURLWithPath: "/dev/null")
        }
        
        // 配置持久化存储
        container.persistentStoreDescriptions.forEach { storeDescription in
            storeDescription.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
            storeDescription.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
        }
        
        container.loadPersistentStores(completionHandler: { (storeDescription, error) in
            if let error = error as NSError? {
                fatalError("Core Data加载失败: \(error), \(error.userInfo)")
            }
        })
        
        // 配置视图上下文
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
    }
    
    /// 保存上下文
    func save() {
        let context = container.viewContext
        
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                let nsError = error as NSError
                print("Core Data保存失败: \(nsError), \(nsError.userInfo)")
            }
        }
    }
    
    /// 创建后台上下文
    func newBackgroundContext() -> NSManagedObjectContext {
        let context = container.newBackgroundContext()
        context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        return context
    }
    
    /// 批量删除实体
    func batchDelete<T: NSManagedObject>(_ entity: T.Type) throws {
        let context = container.viewContext
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: String(describing: entity))
        let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
        deleteRequest.resultType = .resultTypeObjectIDs
        
        let result = try context.execute(deleteRequest) as? NSBatchDeleteResult
        let objectIDArray = result?.result as? [NSManagedObjectID]
        let changes = [NSDeletedObjectsKey: objectIDArray ?? []]
        NSManagedObjectContext.mergeChanges(fromRemoteContextSave: changes, into: [context])
    }
}

// MARK: - 预览数据创建
extension PersistenceController {
    static func createPreviewData(in context: NSManagedObjectContext) {
        // 创建样本股票数据
        let sampleStock = StockEntity(context: context)
        sampleStock.symbol = "000001.SZ"
        sampleStock.name = "平安银行"
        sampleStock.exchange = "SZ"
        sampleStock.lastPrice = 12.50
        sampleStock.changePercent = 2.35
        sampleStock.volume = 1000000
        sampleStock.timestamp = Date()
        
        // 创建样本K线数据
        let sampleKLine = KLineEntity(context: context)
        sampleKLine.symbol = "000001.SZ"
        sampleKLine.timeframe = "1m"
        sampleKLine.timestamp = Date()
        sampleKLine.open = 12.30
        sampleKLine.high = 12.55
        sampleKLine.low = 12.25
        sampleKLine.close = 12.50
        sampleKLine.volume = 50000
        sampleKLine.amount = 620000
        
        // 创建样本交易记录
        let sampleTrade = TradeEntity(context: context)
        sampleTrade.id = UUID().uuidString
        sampleTrade.symbol = "000001.SZ"
        sampleTrade.direction = "buy"
        sampleTrade.quantity = 1000
        sampleTrade.price = 12.30
        sampleTrade.amount = 12300.0
        sampleTrade.commission = 5.0
        sampleTrade.timestamp = Date()
        sampleTrade.strategy = "高频策略"
        sampleTrade.pnl = 200.0
        
        // 创建样本持仓
        let samplePosition = PositionEntity(context: context)
        samplePosition.symbol = "000001.SZ"
        samplePosition.quantity = 1000
        samplePosition.avgCost = 12.30
        samplePosition.currentPrice = 12.50
        samplePosition.marketValue = 12500.0
        samplePosition.pnl = 200.0
        samplePosition.pnlPercent = 1.63
        samplePosition.lastUpdate = Date()
    }
}
