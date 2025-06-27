//
//  PerformanceMonitor.swift
//  StockTradingApp
//
//  Created by MiniMax Agent on 2025-06-24.
//  性能监控器 - 监控应用性能指标和系统资源使用
//

import Foundation
import UIKit
import Combine
import OSLog

/// 性能监控器 - 实时监控应用性能
@MainActor
class PerformanceMonitor: ObservableObject {
    
    // MARK: - 发布属性
    @Published var cpuUsage: Double = 0.0
    @Published var memoryUsage: MemoryInfo = MemoryInfo()
    @Published var diskUsage: DiskInfo = DiskInfo()
    @Published var networkStats: NetworkStats = NetworkStats()
    @Published var frameRate: Double = 60.0
    @Published var isMonitoring = false
    
    // MARK: - 私有属性
    private var monitoringTimer: Timer?
    private var cancellables = Set<AnyCancellable>()
    private let logger = Logger(subsystem: "StockTradingApp", category: "Performance")
    
    // 性能历史记录
    private var performanceHistory: [PerformanceSnapshot] = []
    private let maxHistoryCount = 100
    
    // 单例
    static let shared = PerformanceMonitor()
    
    private init() {
        setupPerformanceObservers()
    }
    
    // MARK: - 监控控制
    func startMonitoring() {
        guard !isMonitoring else { return }
        
        isMonitoring = true
        monitoringTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updatePerformanceMetrics()
            }
        }
        
        logger.info("性能监控已启动")
    }
    
    func stopMonitoring() {
        isMonitoring = false
        monitoringTimer?.invalidate()
        monitoringTimer = nil
        
        logger.info("性能监控已停止")
    }
    
    // MARK: - 性能指标更新
    private func updatePerformanceMetrics() {
        // 更新CPU使用率
        cpuUsage = getCurrentCPUUsage()
        
        // 更新内存使用情况
        memoryUsage = getCurrentMemoryInfo()
        
        // 更新磁盘使用情况
        diskUsage = getCurrentDiskInfo()
        
        // 更新网络统计
        networkStats = getCurrentNetworkStats()
        
        // 更新帧率
        frameRate = getCurrentFrameRate()
        
        // 记录性能快照
        recordPerformanceSnapshot()
        
        // 检查性能警告
        checkPerformanceWarnings()
    }
    
    // MARK: - CPU监控
    private func getCurrentCPUUsage() -> Double {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        
        if kerr == KERN_SUCCESS {
            return Double(info.resident_size) / 1024.0 / 1024.0 // 转换为MB
        }
        
        return 0.0
    }
    
    // MARK: - 内存监控
    private func getCurrentMemoryInfo() -> MemoryInfo {
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
            
            return MemoryInfo(
                usedMemoryMB: usedMemory / 1024.0 / 1024.0,
                totalMemoryMB: totalMemory / 1024.0 / 1024.0,
                usagePercentage: (usedMemory / totalMemory) * 100.0
            )
        }
        
        return MemoryInfo()
    }
    
    // MARK: - 磁盘监控
    private func getCurrentDiskInfo() -> DiskInfo {
        guard let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return DiskInfo()
        }
        
        do {
            let resourceValues = try documentsPath.resourceValues(forKeys: [
                .volumeAvailableCapacityKey,
                .volumeTotalCapacityKey
            ])
            
            let availableCapacity = resourceValues.volumeAvailableCapacity ?? 0
            let totalCapacity = resourceValues.volumeTotalCapacity ?? 0
            let usedCapacity = totalCapacity - availableCapacity
            
            return DiskInfo(
                usedSpaceGB: Double(usedCapacity) / 1024.0 / 1024.0 / 1024.0,
                totalSpaceGB: Double(totalCapacity) / 1024.0 / 1024.0 / 1024.0,
                availableSpaceGB: Double(availableCapacity) / 1024.0 / 1024.0 / 1024.0,
                usagePercentage: Double(usedCapacity) / Double(totalCapacity) * 100.0
            )
            
        } catch {
            logger.error("获取磁盘信息失败: \(error)")
            return DiskInfo()
        }
    }
    
    // MARK: - 网络监控
    private func getCurrentNetworkStats() -> NetworkStats {
        // 这里可以集成网络监控库或系统API
        // 简化实现，返回模拟数据
        return NetworkStats(
            downloadSpeedKBps: Double.random(in: 100...1000),
            uploadSpeedKBps: Double.random(in: 10...100),
            totalDownloadMB: 250.5,
            totalUploadMB: 45.2
        )
    }
    
    // MARK: - 帧率监控
    private func getCurrentFrameRate() -> Double {
        // 简化实现，实际应用中可以使用CADisplayLink监控
        return 60.0
    }
    
    // MARK: - 性能快照记录
    private func recordPerformanceSnapshot() {
        let snapshot = PerformanceSnapshot(
            timestamp: Date(),
            cpuUsage: cpuUsage,
            memoryUsage: memoryUsage.usagePercentage,
            diskUsage: diskUsage.usagePercentage,
            frameRate: frameRate
        )
        
        performanceHistory.append(snapshot)
        
        // 保持历史记录数量限制
        if performanceHistory.count > maxHistoryCount {
            performanceHistory.removeFirst()
        }
    }
    
    // MARK: - 性能警告检查
    private func checkPerformanceWarnings() {
        // CPU使用率过高警告
        if cpuUsage > 80.0 {
            logger.warning("CPU使用率过高: \(cpuUsage)%")
            sendPerformanceAlert(.highCPU, value: cpuUsage)
        }
        
        // 内存使用率过高警告
        if memoryUsage.usagePercentage > 90.0 {
            logger.warning("内存使用率过高: \(memoryUsage.usagePercentage)%")
            sendPerformanceAlert(.highMemory, value: memoryUsage.usagePercentage)
        }
        
        // 磁盘空间不足警告
        if diskUsage.usagePercentage > 95.0 {
            logger.warning("磁盘空间不足: \(diskUsage.usagePercentage)%")
            sendPerformanceAlert(.lowDiskSpace, value: diskUsage.usagePercentage)
        }
        
        // 帧率过低警告
        if frameRate < 30.0 {
            logger.warning("帧率过低: \(frameRate) FPS")
            sendPerformanceAlert(.lowFrameRate, value: frameRate)
        }
    }
    
    private func sendPerformanceAlert(_ type: PerformanceAlertType, value: Double) {
        NotificationCenter.default.post(
            name: .performanceAlert,
            object: PerformanceAlert(type: type, value: value, timestamp: Date())
        )
    }
    
    // MARK: - 性能分析
    func getPerformanceAnalysis() -> PerformanceAnalysis {
        guard !performanceHistory.isEmpty else {
            return PerformanceAnalysis()
        }
        
        let cpuValues = performanceHistory.map { $0.cpuUsage }
        let memoryValues = performanceHistory.map { $0.memoryUsage }
        let frameRateValues = performanceHistory.map { $0.frameRate }
        
        return PerformanceAnalysis(
            averageCPU: cpuValues.average,
            maxCPU: cpuValues.max() ?? 0,
            averageMemory: memoryValues.average,
            maxMemory: memoryValues.max() ?? 0,
            averageFrameRate: frameRateValues.average,
            minFrameRate: frameRateValues.min() ?? 60,
            totalSamples: performanceHistory.count,
            timeSpan: performanceHistory.last?.timestamp.timeIntervalSince(performanceHistory.first?.timestamp ?? Date()) ?? 0
        )
    }
    
    // MARK: - 设置观察者
    private func setupPerformanceObservers() {
        // 监听应用状态变化
        NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)
            .sink { [weak self] _ in
                self?.startMonitoring()
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)
            .sink { [weak self] _ in
                self?.stopMonitoring()
            }
            .store(in: &cancellables)
        
        // 监听内存警告
        NotificationCenter.default.publisher(for: UIApplication.didReceiveMemoryWarningNotification)
            .sink { [weak self] _ in
                self?.handleMemoryWarning()
            }
            .store(in: &cancellables)
    }
    
    private func handleMemoryWarning() {
        logger.warning("收到系统内存警告")
        
        // 触发内存清理
        MemoryOptimizer.shared.performEmergencyCleanup()
        
        // 发送内存警告通知
        sendPerformanceAlert(.memoryWarning, value: memoryUsage.usagePercentage)
    }
    
    // MARK: - 导出性能报告
    func exportPerformanceReport() -> String {
        let analysis = getPerformanceAnalysis()
        
        let report = """
        # 性能监控报告
        
        ## 生成时间
        \(Date().formatted(.dateTime))
        
        ## 监控概要
        - 监控时长: \(String(format: "%.1f", analysis.timeSpan / 60.0)) 分钟
        - 采样数量: \(analysis.totalSamples) 个
        
        ## CPU使用情况
        - 平均使用率: \(String(format: "%.1f", analysis.averageCPU))%
        - 最高使用率: \(String(format: "%.1f", analysis.maxCPU))%
        
        ## 内存使用情况
        - 平均使用率: \(String(format: "%.1f", analysis.averageMemory))%
        - 最高使用率: \(String(format: "%.1f", analysis.maxMemory))%
        - 当前使用量: \(String(format: "%.1f", memoryUsage.usedMemoryMB)) MB
        
        ## 帧率表现
        - 平均帧率: \(String(format: "%.1f", analysis.averageFrameRate)) FPS
        - 最低帧率: \(String(format: "%.1f", analysis.minFrameRate)) FPS
        
        ## 磁盘使用情况
        - 已使用空间: \(String(format: "%.1f", diskUsage.usedSpaceGB)) GB
        - 可用空间: \(String(format: "%.1f", diskUsage.availableSpaceGB)) GB
        - 使用率: \(String(format: "%.1f", diskUsage.usagePercentage))%
        
        ## 网络统计
        - 下载速度: \(String(format: "%.1f", networkStats.downloadSpeedKBps)) KB/s
        - 上传速度: \(String(format: "%.1f", networkStats.uploadSpeedKBps)) KB/s
        """
        
        return report
    }
}

// MARK: - 数据模型
struct MemoryInfo {
    let usedMemoryMB: Double
    let totalMemoryMB: Double
    let usagePercentage: Double
    
    init() {
        self.usedMemoryMB = 0
        self.totalMemoryMB = 0
        self.usagePercentage = 0
    }
    
    init(usedMemoryMB: Double, totalMemoryMB: Double, usagePercentage: Double) {
        self.usedMemoryMB = usedMemoryMB
        self.totalMemoryMB = totalMemoryMB
        self.usagePercentage = usagePercentage
    }
}

struct DiskInfo {
    let usedSpaceGB: Double
    let totalSpaceGB: Double
    let availableSpaceGB: Double
    let usagePercentage: Double
    
    init() {
        self.usedSpaceGB = 0
        self.totalSpaceGB = 0
        self.availableSpaceGB = 0
        self.usagePercentage = 0
    }
    
    init(usedSpaceGB: Double, totalSpaceGB: Double, availableSpaceGB: Double, usagePercentage: Double) {
        self.usedSpaceGB = usedSpaceGB
        self.totalSpaceGB = totalSpaceGB
        self.availableSpaceGB = availableSpaceGB
        self.usagePercentage = usagePercentage
    }
}

struct NetworkStats {
    let downloadSpeedKBps: Double
    let uploadSpeedKBps: Double
    let totalDownloadMB: Double
    let totalUploadMB: Double
    
    init() {
        self.downloadSpeedKBps = 0
        self.uploadSpeedKBps = 0
        self.totalDownloadMB = 0
        self.totalUploadMB = 0
    }
    
    init(downloadSpeedKBps: Double, uploadSpeedKBps: Double, totalDownloadMB: Double, totalUploadMB: Double) {
        self.downloadSpeedKBps = downloadSpeedKBps
        self.uploadSpeedKBps = uploadSpeedKBps
        self.totalDownloadMB = totalDownloadMB
        self.totalUploadMB = totalUploadMB
    }
}

struct PerformanceSnapshot {
    let timestamp: Date
    let cpuUsage: Double
    let memoryUsage: Double
    let diskUsage: Double
    let frameRate: Double
}

struct PerformanceAnalysis {
    let averageCPU: Double
    let maxCPU: Double
    let averageMemory: Double
    let maxMemory: Double
    let averageFrameRate: Double
    let minFrameRate: Double
    let totalSamples: Int
    let timeSpan: TimeInterval
    
    init() {
        self.averageCPU = 0
        self.maxCPU = 0
        self.averageMemory = 0
        self.maxMemory = 0
        self.averageFrameRate = 60
        self.minFrameRate = 60
        self.totalSamples = 0
        self.timeSpan = 0
    }
    
    init(averageCPU: Double, maxCPU: Double, averageMemory: Double, maxMemory: Double, averageFrameRate: Double, minFrameRate: Double, totalSamples: Int, timeSpan: TimeInterval) {
        self.averageCPU = averageCPU
        self.maxCPU = maxCPU
        self.averageMemory = averageMemory
        self.maxMemory = maxMemory
        self.averageFrameRate = averageFrameRate
        self.minFrameRate = minFrameRate
        self.totalSamples = totalSamples
        self.timeSpan = timeSpan
    }
}

enum PerformanceAlertType {
    case highCPU
    case highMemory
    case lowDiskSpace
    case lowFrameRate
    case memoryWarning
    
    var description: String {
        switch self {
        case .highCPU: return "CPU使用率过高"
        case .highMemory: return "内存使用率过高"
        case .lowDiskSpace: return "磁盘空间不足"
        case .lowFrameRate: return "帧率过低"
        case .memoryWarning: return "系统内存警告"
        }
    }
}

struct PerformanceAlert {
    let type: PerformanceAlertType
    let value: Double
    let timestamp: Date
}

// MARK: - 扩展
extension Array where Element == Double {
    var average: Double {
        isEmpty ? 0 : reduce(0, +) / Double(count)
    }
}

extension Notification.Name {
    static let performanceAlert = Notification.Name("performanceAlert")
}
