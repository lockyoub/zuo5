//
//  MemoryOptimizer.swift
//  StockTradingApp
//
//  Created by MiniMax Agent on 2025-06-24.
//  内存优化器 - 管理应用内存使用，实现智能缓存和清理
//

import Foundation
import UIKit
import Combine
import OSLog

/// 内存优化器 - 智能管理应用内存
@MainActor
class MemoryOptimizer: ObservableObject {
    
    // MARK: - 发布属性
    @Published var isOptimizing = false
    @Published var lastCleanupTime: Date?
    @Published var cacheStatistics = CacheStatistics()
    
    // MARK: - 私有属性
    private var cancellables = Set<AnyCancellable>()
    private let logger = Logger(subsystem: "StockTradingApp", category: "MemoryOptimizer")
    
    // 缓存管理
    private var imageCache = NSCache<NSString, UIImage>()
    private var dataCache = NSCache<NSString, NSData>()
    private var klineCache = NSCache<NSString, NSArray>()
    
    // 自动清理定时器
    private var cleanupTimer: Timer?
    
    // 单例
    static let shared = MemoryOptimizer()
    
    private init() {
        setupCaches()
        setupAutoCleanup()
        setupMemoryWarningObserver()
    }
    
    // MARK: - 缓存配置
    private func setupCaches() {
        // 图片缓存配置
        imageCache.countLimit = 100 // 最多缓存100张图片
        imageCache.totalCostLimit = 50 * 1024 * 1024 // 50MB限制
        
        // 数据缓存配置
        dataCache.countLimit = 200 // 最多缓存200个数据对象
        dataCache.totalCostLimit = 20 * 1024 * 1024 // 20MB限制
        
        // K线数据缓存配置
        klineCache.countLimit = 50 // 最多缓存50个股票的K线数据
        klineCache.totalCostLimit = 30 * 1024 * 1024 // 30MB限制
        
        logger.info("缓存系统初始化完成")
    }
    
    // MARK: - 自动清理设置
    private func setupAutoCleanup() {
        // 每5分钟执行一次自动清理
        cleanupTimer = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.performRoutineCleanup()
            }
        }
    }
    
    private func setupMemoryWarningObserver() {
        NotificationCenter.default.publisher(for: UIApplication.didReceiveMemoryWarningNotification)
            .sink { [weak self] _ in
                Task { @MainActor in
                    self?.performEmergencyCleanup()
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - 缓存操作
    func cacheImage(_ image: UIImage, forKey key: String) {
        let cost = Int(image.size.width * image.size.height * 4) // 估算内存占用
        imageCache.setObject(image, forKey: key as NSString, cost: cost)
        updateCacheStatistics()
    }
    
    func getCachedImage(forKey key: String) -> UIImage? {
        return imageCache.object(forKey: key as NSString)
    }
    
    func cacheData(_ data: Data, forKey key: String) {
        dataCache.setObject(data as NSData, forKey: key as NSString, cost: data.count)
        updateCacheStatistics()
    }
    
    func getCachedData(forKey key: String) -> Data? {
        return dataCache.object(forKey: key as NSString) as Data?
    }
    
    func cacheKLineData(_ data: [Any], forKey key: String) {
        let array = data as NSArray
        let estimatedSize = MemoryLayout<Double>.size * data.count * 6 // OHLCV + timestamp
        klineCache.setObject(array, forKey: key as NSString, cost: estimatedSize)
        updateCacheStatistics()
    }
    
    func getCachedKLineData(forKey key: String) -> [Any]? {
        return klineCache.object(forKey: key as NSString) as? [Any]
    }
    
    // MARK: - 清理操作
    func performRoutineCleanup() {
        guard !isOptimizing else { return }
        
        isOptimizing = true
        logger.info("开始例行内存清理")
        
        // 清理过期缓存
        clearExpiredCaches()
        
        // 清理临时文件
        clearTemporaryFiles()
        
        // 垃圾回收建议
        requestGarbageCollection()
        
        lastCleanupTime = Date()
        isOptimizing = false
        
        logger.info("例行内存清理完成")
    }
    
    func performEmergencyCleanup() {
        guard !isOptimizing else { return }
        
        isOptimizing = true
        logger.warning("开始紧急内存清理")
        
        // 清空所有缓存
        imageCache.removeAllObjects()
        dataCache.removeAllObjects()
        klineCache.removeAllObjects()
        
        // 清理临时文件
        clearTemporaryFiles()
        
        // 清理不必要的数据
        cleanupUnusedData()
        
        // 强制垃圾回收
        requestGarbageCollection()
        
        lastCleanupTime = Date()
        isOptimizing = false
        
        updateCacheStatistics()
        logger.warning("紧急内存清理完成")
    }
    
    private func clearExpiredCaches() {
        // 减少图片缓存大小
        if imageCache.totalCostLimit > 25 * 1024 * 1024 {
            imageCache.totalCostLimit = 25 * 1024 * 1024
        }
        
        // 减少数据缓存大小
        if dataCache.totalCostLimit > 10 * 1024 * 1024 {
            dataCache.totalCostLimit = 10 * 1024 * 1024
        }
        
        // 减少K线缓存大小
        if klineCache.countLimit > 25 {
            klineCache.countLimit = 25
        }
    }
    
    private func clearTemporaryFiles() {
        let tempDirectory = NSTemporaryDirectory()
        let fileManager = FileManager.default
        
        do {
            let tempFiles = try fileManager.contentsOfDirectory(atPath: tempDirectory)
            for file in tempFiles {
                let filePath = (tempDirectory as NSString).appendingPathComponent(file)
                try fileManager.removeItem(atPath: filePath)
            }
            logger.info("临时文件清理完成")
        } catch {
            logger.error("清理临时文件失败: \(error)")
        }
    }
    
    private func cleanupUnusedData() {
        // 清理CoreData缓存
        PersistenceController.shared.container.viewContext.refreshAllObjects()
        
        // 发送内存清理通知给其他组件
        NotificationCenter.default.post(name: .memoryCleanupRequested, object: nil)
    }
    
    private func requestGarbageCollection() {
        // 在iOS中，没有显式的垃圾回收，但可以通过这些操作来帮助系统回收内存
        URLCache.shared.removeAllCachedResponses()
        
        // 通知自动释放池清理
        autoreleasepool {
            // 空操作，促进自动释放池清理
        }
    }
    
    // MARK: - 内存监控
    func getCurrentMemoryUsage() -> MemoryUsageInfo {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        
        if kerr == KERN_SUCCESS {
            let usedMemory = Double(info.resident_size)
            let totalMemory = Double(ProcessInfo.processInfo.physicalMemory)
            
            return MemoryUsageInfo(
                usedBytes: Int64(info.resident_size),
                usedMB: usedMemory / 1024.0 / 1024.0,
                totalMB: totalMemory / 1024.0 / 1024.0,
                usagePercentage: (usedMemory / totalMemory) * 100.0
            )
        }
        
        return MemoryUsageInfo()
    }
    
    func shouldPerformCleanup() -> Bool {
        let memoryInfo = getCurrentMemoryUsage()
        
        // 如果内存使用超过80%，建议清理
        if memoryInfo.usagePercentage > 80.0 {
            return true
        }
        
        // 如果距离上次清理超过10分钟，建议清理
        if let lastCleanup = lastCleanupTime,
           Date().timeIntervalSince(lastCleanup) > 600 {
            return true
        }
        
        return false
    }
    
    // MARK: - 缓存统计
    private func updateCacheStatistics() {
        cacheStatistics = CacheStatistics(
            imageCacheCount: imageCache.countLimit,
            dataCacheCount: dataCache.countLimit,
            klineCacheCount: klineCache.countLimit,
            totalCacheSizeMB: calculateTotalCacheSize(),
            lastUpdateTime: Date()
        )
    }
    
    private func calculateTotalCacheSize() -> Double {
        // 估算缓存总大小（MB）
        let imageCacheSize = Double(imageCache.totalCostLimit) / 1024.0 / 1024.0
        let dataCacheSize = Double(dataCache.totalCostLimit) / 1024.0 / 1024.0
        let klineCacheSize = Double(klineCache.totalCostLimit) / 1024.0 / 1024.0
        
        return imageCacheSize + dataCacheSize + klineCacheSize
    }
    
    // MARK: - 智能预加载
    func preloadEssentialData() {
        Task {
            // 预加载常用股票的基本信息
            await preloadPopularStocks()
            
            // 预加载用户自选股数据
            await preloadWatchlistData()
            
            // 预加载常用技术指标数据
            await preloadIndicatorData()
        }
    }
    
    private func preloadPopularStocks() async {
        // 实现热门股票数据预加载
        logger.info("开始预加载热门股票数据")
    }
    
    private func preloadWatchlistData() async {
        // 实现自选股数据预加载
        logger.info("开始预加载自选股数据")
    }
    
    private func preloadIndicatorData() async {
        // 实现技术指标数据预加载
        logger.info("开始预加载技术指标数据")
    }
    
    // MARK: - 内存优化建议
    func getOptimizationRecommendations() -> [OptimizationRecommendation] {
        var recommendations: [OptimizationRecommendation] = []
        
        let memoryInfo = getCurrentMemoryUsage()
        
        if memoryInfo.usagePercentage > 85 {
            recommendations.append(
                OptimizationRecommendation(
                    type: .criticalMemory,
                    title: "内存使用过高",
                    description: "当前内存使用率\(String(format: "%.1f", memoryInfo.usagePercentage))%，建议立即清理",
                    priority: .high,
                    action: "立即清理内存"
                )
            )
        }
        
        if cacheStatistics.totalCacheSizeMB > 80 {
            recommendations.append(
                OptimizationRecommendation(
                    type: .largeCache,
                    title: "缓存占用过大",
                    description: "缓存总大小\(String(format: "%.1f", cacheStatistics.totalCacheSizeMB))MB，建议清理",
                    priority: .medium,
                    action: "清理缓存"
                )
            )
        }
        
        if let lastCleanup = lastCleanupTime,
           Date().timeIntervalSince(lastCleanup) > 1800 { // 30分钟
            recommendations.append(
                OptimizationRecommendation(
                    type: .scheduledCleanup,
                    title: "建议定期清理",
                    description: "距离上次清理已超过30分钟",
                    priority: .low,
                    action: "执行清理"
                )
            )
        }
        
        return recommendations
    }
}

// MARK: - 数据模型
struct MemoryUsageInfo {
    let usedBytes: Int64
    let usedMB: Double
    let totalMB: Double
    let usagePercentage: Double
    
    init() {
        self.usedBytes = 0
        self.usedMB = 0
        self.totalMB = 0
        self.usagePercentage = 0
    }
    
    init(usedBytes: Int64, usedMB: Double, totalMB: Double, usagePercentage: Double) {
        self.usedBytes = usedBytes
        self.usedMB = usedMB
        self.totalMB = totalMB
        self.usagePercentage = usagePercentage
    }
}

struct CacheStatistics {
    let imageCacheCount: Int
    let dataCacheCount: Int
    let klineCacheCount: Int
    let totalCacheSizeMB: Double
    let lastUpdateTime: Date
    
    init() {
        self.imageCacheCount = 0
        self.dataCacheCount = 0
        self.klineCacheCount = 0
        self.totalCacheSizeMB = 0
        self.lastUpdateTime = Date()
    }
    
    init(imageCacheCount: Int, dataCacheCount: Int, klineCacheCount: Int, totalCacheSizeMB: Double, lastUpdateTime: Date) {
        self.imageCacheCount = imageCacheCount
        self.dataCacheCount = dataCacheCount
        self.klineCacheCount = klineCacheCount
        self.totalCacheSizeMB = totalCacheSizeMB
        self.lastUpdateTime = lastUpdateTime
    }
}

enum OptimizationType {
    case criticalMemory
    case largeCache
    case scheduledCleanup
    case backgroundCleanup
}

enum OptimizationPriority {
    case low, medium, high, critical
    
    var displayName: String {
        switch self {
        case .low: return "低"
        case .medium: return "中"
        case .high: return "高"
        case .critical: return "紧急"
        }
    }
}

struct OptimizationRecommendation {
    let type: OptimizationType
    let title: String
    let description: String
    let priority: OptimizationPriority
    let action: String
}

// MARK: - 通知扩展
extension Notification.Name {
    static let memoryCleanupRequested = Notification.Name("memoryCleanupRequested")
    static let memoryOptimizationCompleted = Notification.Name("memoryOptimizationCompleted")
}
