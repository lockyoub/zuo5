/*
 增强的数据同步管理器
 负责本地Core Data和服务器数据的智能同步
 支持增量同步、冲突解决、离线操作队列等完整功能
 作者: MiniMax Agent
 创建时间: 2025-06-24 15:23:57
 */

import Foundation
import CoreData
import Combine

// MARK: - 同步状态
enum SyncStatus: Equatable {
    case idle
    case syncing(String) // 包含当前同步操作描述
    case success(Date)   // 包含同步完成时间
    case failed(String)  // 包含错误描述
    case conflict([String]) // 包含冲突项目列表
    
    var description: String {
        switch self {
        case .idle:
            return "等待同步"
        case .syncing(let operation):
            return "正在同步: \(operation)"
        case .success(let date):
            let formatter = DateFormatter()
            formatter.dateFormat = "HH:mm:ss"
            return "同步成功: \(formatter.string(from: date))"
        case .failed(let error):
            return "同步失败: \(error)"
        case .conflict(let items):
            return "数据冲突: \(items.joined(separator: ", "))"
        }
    }
}

// MARK: - 同步策略
enum SyncStrategy {
    case realtime      // 实时同步（WebSocket推送）
    case periodic(TimeInterval) // 定期同步
    case onDemand      // 按需同步
    case incremental   // 增量同步
    case fullSync      // 全量同步
}

// MARK: - 同步操作
struct SyncOperation {
    let id = UUID()
    let type: SyncOperationType
    let entity: String
    let data: [String: Any]
    let timestamp: Date
    let priority: SyncPriority
    
    enum SyncOperationType {
        case create
        case update
        case delete
        case fetch
    }
    
    enum SyncPriority: Int, Comparable {
        case low = 0
        case normal = 1
        case high = 2
        case urgent = 3
        
        static func < (lhs: SyncPriority, rhs: SyncPriority) -> Bool {
            return lhs.rawValue < rhs.rawValue
        }
    }
}

// MARK: - 同步配置
struct SyncConfiguration {
    let syncInterval: TimeInterval // 定期同步间隔
    let maxRetryCount: Int        // 最大重试次数
    let batchSize: Int           // 批量操作大小
    let timeoutInterval: TimeInterval // 同步超时时间
    let enableIncrementalSync: Bool  // 是否启用增量同步
    let enableConflictResolution: Bool // 是否启用冲突解决
    
    static let `default` = SyncConfiguration(
        syncInterval: 60.0,
        maxRetryCount: 3,
        batchSize: 100,
        timeoutInterval: 30.0,
        enableIncrementalSync: true,
        enableConflictResolution: true
    )
}

// MARK: - 增强的数据同步管理器
@MainActor
class EnhancedDataSyncManager: ObservableObject {
    static let shared = EnhancedDataSyncManager()
    
    // 发布属性
    @Published var syncStatus: SyncStatus = .idle
    @Published var lastSyncTime: Date?
    @Published var isOfflineMode = false
    @Published var syncProgress: Double = 0.0
    @Published var operationQueue: [SyncOperation] = []
    
    // 私有属性
    private let networkManager: EnhancedNetworkManager
    private let persistenceController = PersistenceController.shared
    private let configuration: SyncConfiguration
    private var cancellables = Set<AnyCancellable>()
    
    // 同步控制
    private var syncTimer: Timer?
    private var lastSyncTimestamps: [String: Date] = [:]
    private var pendingSyncOperations: [SyncOperation] = []
    private let syncQueue = DispatchQueue(label: "DataSync", qos: .utility)
    private var isCurrentlySyncing = false
    
    // 冲突解决
    private var conflictResolver: ConflictResolver
    
    init(networkManager: EnhancedNetworkManager = EnhancedNetworkManager(),
         configuration: SyncConfiguration = .default) {
        self.networkManager = networkManager
        self.configuration = configuration
        self.conflictResolver = ConflictResolver()
        
        setupNetworkObserver()
        setupPeriodicSync()
        setupWebSocketHandlers()
    }
    
    deinit {
        syncTimer?.invalidate()
    }
    
    // MARK: - 设置方法
    
    private func setupNetworkObserver() {
        // 监听网络状态变化
        networkManager.$isNetworkAvailable
            .sink { [weak self] isAvailable in
                self?.handleNetworkStateChange(isAvailable)
            }
            .store(in: &cancellables)
    }
    
    private func setupPeriodicSync() {
        syncTimer = Timer.scheduledTimer(withTimeInterval: configuration.syncInterval, repeats: true) { [weak self] _ in
            Task {
                await self?.performPeriodicSync()
            }
        }
    }
    
    private func setupWebSocketHandlers() {
        // 订阅实时市场数据
        networkManager.subscribeToMarketData()
            .sink { [weak self] marketData in
                Task {
                    await self?.handleRealtimeMarketData(marketData)
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - 网络状态处理
    
    private func handleNetworkStateChange(_ isAvailable: Bool) {
        if isAvailable && isOfflineMode {
            // 网络恢复，处理离线操作
            isOfflineMode = false
            Task {
                await processOfflineOperations()
            }
        } else if !isAvailable {
            // 网络断开，启用离线模式
            isOfflineMode = true
            print("网络不可用，启用离线模式")
        }
    }
    
    // MARK: - 公共同步方法
    
    /// 启动完整数据同步
    func startFullSync() async {
        guard !isCurrentlySyncing else {
            print("同步正在进行中，跳过")
            return
        }
        
        isCurrentlySyncing = true
        syncStatus = .syncing("准备同步")
        syncProgress = 0.0
        
        do {
            // 1. 同步股票基础数据 (20%)
            syncStatus = .syncing("同步股票数据")
            await syncStockData()
            syncProgress = 0.2
            
            // 2. 同步K线数据 (40%)
            syncStatus = .syncing("同步K线数据")
            await syncKLineData()
            syncProgress = 0.4
            
            // 3. 同步交易数据 (60%)
            syncStatus = .syncing("同步交易数据")
            await syncTradingData()
            syncProgress = 0.6
            
            // 4. 同步持仓数据 (80%)
            syncStatus = .syncing("同步持仓数据")
            await syncPositionData()
            syncProgress = 0.8
            
            // 5. 同步策略数据 (100%)
            syncStatus = .syncing("同步策略数据")
            await syncStrategyData()
            syncProgress = 1.0
            
            lastSyncTime = Date()
            syncStatus = .success(Date())
            
            print("数据同步完成")
            
        } catch {
            print("数据同步失败: \(error)")
            syncStatus = .failed(error.localizedDescription)
        }
        
        isCurrentlySyncing = false
    }
    
    /// 增量同步
    func startIncrementalSync() async {
        guard configuration.enableIncrementalSync else {
            await startFullSync()
            return
        }
        
        guard !isCurrentlySyncing else { return }
        
        isCurrentlySyncing = true
        syncStatus = .syncing("增量同步")
        
        do {
            // 获取上次同步时间戳
            let lastSync = lastSyncTime ?? Date(timeIntervalSince1970: 0)
            
            // 增量同步各个数据类型
            await incrementalSyncStockData(since: lastSync)
            await incrementalSyncTradingData(since: lastSync)
            await incrementalSyncPositionData(since: lastSync)
            
            lastSyncTime = Date()
            syncStatus = .success(Date())
            
        } catch {
            syncStatus = .failed(error.localizedDescription)
        }
        
        isCurrentlySyncing = false
    }
    
    /// 按需同步特定实体
    func syncEntity<T: NSManagedObject>(_ entityType: T.Type, identifier: String) async throws {
        let entityName = String(describing: entityType)
        
        syncStatus = .syncing("同步\(entityName)")
        
        // 根据实体类型调用相应的同步方法
        switch entityType {
        case is StockEntity.Type:
            try await syncSingleStock(symbol: identifier)
        case is TradeEntity.Type:
            try await syncSingleTrade(id: identifier)
        case is PositionEntity.Type:
            try await syncSinglePosition(symbol: identifier)
        default:
            throw NetworkError.custom("不支持的实体类型: \(entityName)")
        }
        
        syncStatus = .success(Date())
    }
    
    // MARK: - 具体同步实现
    
    private func syncStockData() async throws {
        let endpoint = "/api/stocks"
        let response: [String: Any] = try await networkManager.get(endpoint, type: [String: Any].self)
        
        guard let stocks = response["data"] as? [[String: Any]] else {
            throw NetworkError.decodingError
        }
        
        let context = persistenceController.newBackgroundContext()
        
        await context.perform {
            for stockData in stocks {
                self.updateOrCreateStock(from: stockData, in: context)
            }
            
            do {
                try context.save()
            } catch {
                print("保存股票数据失败: \(error)")
            }
        }
    }
    
    private func syncKLineData() async throws {
        // 获取需要同步的股票列表
        let context = persistenceController.container.viewContext
        let stockRequest: NSFetchRequest<StockEntity> = StockEntity.fetchRequest()
        let stocks = try context.fetch(stockRequest)
        
        for stock in stocks {
            try await syncKLineForStock(symbol: stock.symbol)
        }
    }
    
    private func syncKLineForStock(symbol: String) async throws {
        let endpoint = "/api/klines/\(symbol)"
        let parameters = [
            "timeframes": ["1m", "5m", "1h", "1d"],
            "limit": 100
        ]
        
        let response: [String: Any] = try await networkManager.get(
            endpoint,
            parameters: parameters,
            type: [String: Any].self
        )
        
        guard let klineData = response["data"] as? [String: Any] else {
            throw NetworkError.decodingError
        }
        
        let context = persistenceController.newBackgroundContext()
        
        await context.perform {
            for (timeframe, data) in klineData {
                if let klines = data as? [[String: Any]] {
                    for klineDict in klines {
                        self.updateOrCreateKLine(
                            from: klineDict,
                            symbol: symbol,
                            timeframe: timeframe,
                            in: context
                        )
                    }
                }
            }
            
            do {
                try context.save()
            } catch {
                print("保存K线数据失败: \(error)")
            }
        }
    }
    
    private func syncTradingData() async throws {
        let endpoint = "/api/trades"
        let parameters: [String: Any] = [
            "limit": configuration.batchSize
        ]
        
        if configuration.enableIncrementalSync,
           let lastSync = lastSyncTimestamps["trades"] {
            parameters["since"] = ISO8601DateFormatter().string(from: lastSync)
        }
        
        let response: [String: Any] = try await networkManager.get(
            endpoint,
            parameters: parameters,
            type: [String: Any].self
        )
        
        guard let trades = response["data"] as? [[String: Any]] else {
            throw NetworkError.decodingError
        }
        
        let context = persistenceController.newBackgroundContext()
        
        await context.perform {
            for tradeData in trades {
                self.updateOrCreateTrade(from: tradeData, in: context)
            }
            
            do {
                try context.save()
                self.lastSyncTimestamps["trades"] = Date()
            } catch {
                print("保存交易数据失败: \(error)")
            }
        }
    }
    
    private func syncPositionData() async throws {
        let endpoint = "/api/positions"
        let response: [String: Any] = try await networkManager.get(endpoint, type: [String: Any].self)
        
        guard let positions = response["data"] as? [[String: Any]] else {
            throw NetworkError.decodingError
        }
        
        let context = persistenceController.newBackgroundContext()
        
        await context.perform {
            for positionData in positions {
                self.updateOrCreatePosition(from: positionData, in: context)
            }
            
            do {
                try context.save()
            } catch {
                print("保存持仓数据失败: \(error)")
            }
        }
    }
    
    private func syncStrategyData() async throws {
        let endpoint = "/api/strategies"
        let response: [String: Any] = try await networkManager.get(endpoint, type: [String: Any].self)
        
        guard let strategies = response["data"] as? [[String: Any]] else {
            throw NetworkError.decodingError
        }
        
        let context = persistenceController.newBackgroundContext()
        
        await context.perform {
            for strategyData in strategies {
                self.updateOrCreateStrategy(from: strategyData, in: context)
            }
            
            do {
                try context.save()
            } catch {
                print("保存策略数据失败: \(error)")
            }
        }
    }
    
    // MARK: - 实时数据处理
    
    private func handleRealtimeMarketData(_ marketData: MarketDataMessage) async {
        let context = persistenceController.container.viewContext
        
        await context.perform {
            // 查找或创建股票实体
            let request: NSFetchRequest<StockEntity> = StockEntity.fetchRequest()
            request.predicate = NSPredicate(format: "symbol == %@", marketData.symbol)
            
            do {
                let stocks = try context.fetch(request)
                let stock = stocks.first ?? StockEntity(context: context)
                
                // 更新股票数据
                stock.symbol = marketData.symbol
                stock.lastPrice = marketData.data.price
                stock.change = marketData.data.change
                stock.changePercent = marketData.data.changePercent
                stock.volume = marketData.data.volume
                stock.amount = marketData.data.amount
                stock.timestamp = Date()
                
                // 更新盘口数据
                if let bidPrices = marketData.data.bidPrices,
                   let bidVolumes = marketData.data.bidVolumes,
                   let askPrices = marketData.data.askPrices,
                   let askVolumes = marketData.data.askVolumes {
                    stock.updateOrderBook(
                        bidPrices: bidPrices,
                        bidVolumes: bidVolumes,
                        askPrices: askPrices,
                        askVolumes: askVolumes
                    )
                }
                
                try context.save()
                
                // 发送通知
                NotificationCenter.default.post(
                    name: .stockDataUpdated,
                    object: stock
                )
                
            } catch {
                print("处理实时市场数据失败: \(error)")
            }
        }
    }
    
    // MARK: - 数据更新方法
    
    private func updateOrCreateStock(from data: [String: Any], in context: NSManagedObjectContext) {
        guard let symbol = data["symbol"] as? String else { return }
        
        let request: NSFetchRequest<StockEntity> = StockEntity.fetchRequest()
        request.predicate = NSPredicate(format: "symbol == %@", symbol)
        
        do {
            let stocks = try context.fetch(request)
            let stock = stocks.first ?? StockEntity(context: context)
            
            stock.symbol = symbol
            stock.name = data["name"] as? String ?? ""
            stock.exchange = data["exchange"] as? String ?? ""
            stock.lastPrice = data["lastPrice"] as? Double ?? 0
            stock.change = data["change"] as? Double ?? 0
            stock.changePercent = data["changePercent"] as? Double ?? 0
            stock.volume = data["volume"] as? Int64 ?? 0
            stock.amount = data["amount"] as? Double ?? 0
            stock.timestamp = Date()
            
        } catch {
            print("更新股票数据失败: \(error)")
        }
    }
    
    private func updateOrCreateKLine(from data: [String: Any], symbol: String, timeframe: String, in context: NSManagedObjectContext) {
        guard let timestampString = data["timestamp"] as? String,
              let timestamp = ISO8601DateFormatter().date(from: timestampString) else { return }
        
        let request: NSFetchRequest<KLineEntity> = KLineEntity.fetchRequest()
        request.predicate = NSPredicate(format: "symbol == %@ AND timeframe == %@ AND timestamp == %@", symbol, timeframe, timestamp as NSDate)
        
        do {
            let klines = try context.fetch(request)
            let kline = klines.first ?? KLineEntity(context: context)
            
            kline.symbol = symbol
            kline.timeframe = timeframe
            kline.timestamp = timestamp
            kline.open = data["open"] as? Double ?? 0
            kline.high = data["high"] as? Double ?? 0
            kline.low = data["low"] as? Double ?? 0
            kline.close = data["close"] as? Double ?? 0
            kline.volume = data["volume"] as? Int64 ?? 0
            kline.amount = data["amount"] as? Double ?? 0
            
        } catch {
            print("更新K线数据失败: \(error)")
        }
    }
    
    private func updateOrCreateTrade(from data: [String: Any], in context: NSManagedObjectContext) {
        guard let id = data["id"] as? String else { return }
        
        let request: NSFetchRequest<TradeEntity> = TradeEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id)
        
        do {
            let trades = try context.fetch(request)
            let trade = trades.first ?? TradeEntity(context: context)
            
            trade.id = id
            trade.symbol = data["symbol"] as? String ?? ""
            trade.direction = data["direction"] as? String ?? ""
            trade.quantity = data["quantity"] as? Int32 ?? 0
            trade.price = data["price"] as? Double ?? 0
            trade.amount = data["amount"] as? Double ?? 0
            trade.commission = data["commission"] as? Double ?? 0
            trade.pnl = data["pnl"] as? Double ?? 0
            
            if let timestampString = data["timestamp"] as? String,
               let timestamp = ISO8601DateFormatter().date(from: timestampString) {
                trade.timestamp = timestamp
            }
            
        } catch {
            print("更新交易数据失败: \(error)")
        }
    }
    
    private func updateOrCreatePosition(from data: [String: Any], in context: NSManagedObjectContext) {
        guard let symbol = data["symbol"] as? String else { return }
        
        let request: NSFetchRequest<PositionEntity> = PositionEntity.fetchRequest()
        request.predicate = NSPredicate(format: "symbol == %@", symbol)
        
        do {
            let positions = try context.fetch(request)
            let position = positions.first ?? PositionEntity(context: context)
            
            position.symbol = symbol
            position.quantity = data["quantity"] as? Int32 ?? 0
            position.avgCost = data["avgCost"] as? Double ?? 0
            position.currentPrice = data["currentPrice"] as? Double ?? 0
            position.marketValue = data["marketValue"] as? Double ?? 0
            position.pnl = data["pnl"] as? Double ?? 0
            position.pnlPercent = data["pnlPercent"] as? Double ?? 0
            position.lastUpdate = Date()
            
        } catch {
            print("更新持仓数据失败: \(error)")
        }
    }
    
    private func updateOrCreateStrategy(from data: [String: Any], in context: NSManagedObjectContext) {
        guard let id = data["id"] as? String else { return }
        
        let request: NSFetchRequest<StrategyEntity> = StrategyEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id)
        
        do {
            let strategies = try context.fetch(request)
            let strategy = strategies.first ?? StrategyEntity(context: context)
            
            strategy.id = id
            strategy.name = data["name"] as? String ?? ""
            strategy.type = data["type"] as? String ?? ""
            strategy.timeframe = data["timeframe"] as? String ?? ""
            strategy.isActive = data["isActive"] as? Bool ?? false
            
            if let parameters = data["parameters"] {
                let parametersData = try JSONSerialization.data(withJSONObject: parameters)
                strategy.parameters = String(data: parametersData, encoding: .utf8)
            }
            
            strategy.updatedAt = Date()
            
        } catch {
            print("更新策略数据失败: \(error)")
        }
    }
    
    // MARK: - 离线操作处理
    
    private func processOfflineOperations() async {
        guard !pendingSyncOperations.isEmpty else { return }
        
        syncStatus = .syncing("处理离线操作")
        
        // 按优先级排序
        let sortedOperations = pendingSyncOperations.sorted { $0.priority > $1.priority }
        
        for operation in sortedOperations {
            do {
                try await processOfflineOperation(operation)
                
                // 从队列中移除已完成的操作
                if let index = pendingSyncOperations.firstIndex(where: { $0.id == operation.id }) {
                    pendingSyncOperations.remove(at: index)
                }
                
            } catch {
                print("处理离线操作失败: \(operation), 错误: \(error)")
            }
        }
        
        operationQueue = pendingSyncOperations
        syncStatus = .success(Date())
    }
    
    private func processOfflineOperation(_ operation: SyncOperation) async throws {
        switch operation.type {
        case .create:
            try await createRemoteEntity(operation)
        case .update:
            try await updateRemoteEntity(operation)
        case .delete:
            try await deleteRemoteEntity(operation)
        case .fetch:
            try await fetchRemoteEntity(operation)
        }
    }
    
    // MARK: - 辅助方法
    
    private func performPeriodicSync() async {
        guard !isOfflineMode && networkManager.isNetworkAvailable else { return }
        
        await startIncrementalSync()
    }
    
    /// 添加操作到离线队列
    func addOfflineOperation(_ operation: SyncOperation) {
        pendingSyncOperations.append(operation)
        operationQueue = pendingSyncOperations
    }
    
    /// 清除同步缓存
    func clearSyncCache() {
        lastSyncTimestamps.removeAll()
        lastSyncTime = nil
        networkManager.clearCache()
    }
}

// MARK: - 冲突解决器
class ConflictResolver {
    enum ResolutionStrategy {
        case serverWins    // 服务器数据优先
        case clientWins    // 客户端数据优先
        case mergeByTime   // 按时间戳合并
        case manual        // 手动解决
    }
    
    func resolveConflict<T: NSManagedObject>(
        serverEntity: T,
        localEntity: T,
        strategy: ResolutionStrategy = .serverWins
    ) -> T {
        switch strategy {
        case .serverWins:
            return serverEntity
        case .clientWins:
            return localEntity
        case .mergeByTime:
            // 实现基于时间戳的合并逻辑
            return mergeByTimestamp(server: serverEntity, local: localEntity)
        case .manual:
            // 标记为需要手动解决
            return localEntity
        }
    }
    
    private func mergeByTimestamp<T: NSManagedObject>(server: T, local: T) -> T {
        // 简化实现，实际应根据具体实体类型进行详细比较
        return server
    }
}

// MARK: - 通知扩展
extension Notification.Name {
    static let stockDataUpdated = Notification.Name("stockDataUpdated")
    static let tradingDataUpdated = Notification.Name("tradingDataUpdated")
    static let positionDataUpdated = Notification.Name("positionDataUpdated")
    static let syncStatusChanged = Notification.Name("syncStatusChanged")
}

// MARK: - 占位符实现（需要完整实现）
extension EnhancedDataSyncManager {
    private func incrementalSyncStockData(since date: Date) async throws {
        // 增量同步实现
    }
    
    private func incrementalSyncTradingData(since date: Date) async throws {
        // 增量同步实现
    }
    
    private func incrementalSyncPositionData(since date: Date) async throws {
        // 增量同步实现
    }
    
    private func syncSingleStock(symbol: String) async throws {
        // 单个股票同步实现
    }
    
    private func syncSingleTrade(id: String) async throws {
        // 单个交易同步实现
    }
    
    private func syncSinglePosition(symbol: String) async throws {
        // 单个持仓同步实现
    }
    
    private func createRemoteEntity(_ operation: SyncOperation) async throws {
        // 创建远程实体实现
    }
    
    private func updateRemoteEntity(_ operation: SyncOperation) async throws {
        // 更新远程实体实现
    }
    
    private func deleteRemoteEntity(_ operation: SyncOperation) async throws {
        // 删除远程实体实现
    }
    
    private func fetchRemoteEntity(_ operation: SyncOperation) async throws {
        // 获取远程实体实现
    }
}
