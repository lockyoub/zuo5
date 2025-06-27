//
//  ChartUtilities.swift
//  StockTradingApp
//
//  Created by MiniMax Agent on 2025-06-24.
//  图表工具类 - 提供图表相关的工具方法和扩展
//

import Foundation
import SwiftUI
import Charts

/// 图表工具类
class ChartUtilities {
    
    // MARK: - 静态方法
    
    /// 计算图表的最佳显示范围
    static func calculateOptimalRange(data: [Double], padding: Double = 0.05) -> (min: Double, max: Double) {
        guard !data.isEmpty else { return (0, 1) }
        
        let minValue = data.min() ?? 0
        let maxValue = data.max() ?? 1
        let range = maxValue - minValue
        let paddingValue = range * padding
        
        return (
            min: minValue - paddingValue,
            max: maxValue + paddingValue
        )
    }
    
    /// 生成图表网格线的数值
    static func generateGridValues(min: Double, max: Double, targetCount: Int = 5) -> [Double] {
        let range = max - min
        let step = range / Double(targetCount - 1)
        
        return stride(from: min, through: max, by: step).map { $0 }
    }
    
    /// 格式化价格显示
    static func formatPrice(_ price: Double, decimalPlaces: Int = 2) -> String {
        return String(format: "%.\(decimalPlaces)f", price)
    }
    
    /// 格式化百分比显示
    static func formatPercentage(_ percentage: Double, decimalPlaces: Int = 2) -> String {
        let sign = percentage >= 0 ? "+" : ""
        return "\(sign)\(String(format: "%.\(decimalPlaces)f", percentage))%"
    }
    
    /// 格式化成交量显示
    static func formatVolume(_ volume: Double) -> String {
        if volume >= 100_000_000 { // 1亿
            return String(format: "%.1f亿", volume / 100_000_000)
        } else if volume >= 10_000 { // 1万
            return String(format: "%.1f万", volume / 10_000)
        } else if volume >= 1000 { // 1千
            return String(format: "%.1fK", volume / 1000)
        } else {
            return String(format: "%.0f", volume)
        }
    }
    
    /// 计算移动平均线
    static func calculateMovingAverage(data: [Double], period: Int) -> [Double] {
        guard data.count >= period else { return [] }
        
        var result: [Double] = []
        
        for i in period - 1..<data.count {
            let slice = Array(data[i - period + 1...i])
            let average = slice.reduce(0, +) / Double(period)
            result.append(average)
        }
        
        return result
    }
    
    /// 计算价格变化率
    static func calculatePriceChangeRate(currentPrice: Double, previousPrice: Double) -> Double {
        guard previousPrice != 0 else { return 0 }
        return ((currentPrice - previousPrice) / previousPrice) * 100
    }
    
    /// 生成图表截图
    static func captureChartScreenshot(view: some View) -> UIImage? {
        let controller = UIHostingController(rootView: view)
        let view = controller.view
        
        let targetSize = CGSize(width: 375, height: 600)
        view?.bounds = CGRect(origin: .zero, size: targetSize)
        view?.backgroundColor = UIColor.black
        
        let renderer = UIGraphicsImageRenderer(size: targetSize)
        return renderer.image { _ in
            view?.drawHierarchy(in: controller.view.bounds, afterScreenUpdates: true)
        }
    }
}

// MARK: - 颜色工具扩展
extension Color {
    /// 获取涨跌颜色
    static func priceChangeColor(for change: Double) -> Color {
        if change > 0 {
            return .green
        } else if change < 0 {
            return .red
        } else {
            return .gray
        }
    }
    
    /// 根据价格变化百分比获取渐变色
    static func priceGradientColor(for percentage: Double) -> Color {
        let absPercentage = abs(percentage)
        let intensity = min(absPercentage / 10.0, 1.0) // 10%变化对应最大强度
        
        if percentage > 0 {
            return Color.green.opacity(0.3 + intensity * 0.7)
        } else if percentage < 0 {
            return Color.red.opacity(0.3 + intensity * 0.7)
        } else {
            return Color.gray.opacity(0.3)
        }
    }
}

// MARK: - 数组扩展
extension Array where Element == Double {
    /// 计算数组的统计信息
    var statistics: (min: Double, max: Double, average: Double, median: Double) {
        guard !isEmpty else { return (0, 0, 0, 0) }
        
        let sorted = self.sorted()
        let min = sorted.first ?? 0
        let max = sorted.last ?? 0
        let average = reduce(0, +) / Double(count)
        
        let median: Double
        if count % 2 == 0 {
            median = (sorted[count / 2 - 1] + sorted[count / 2]) / 2
        } else {
            median = sorted[count / 2]
        }
        
        return (min, max, average, median)
    }
    
    /// 计算标准差
    var standardDeviation: Double {
        guard count > 1 else { return 0 }
        
        let average = reduce(0, +) / Double(count)
        let sumOfSquares = map { pow($0 - average, 2) }.reduce(0, +)
        return sqrt(sumOfSquares / Double(count - 1))
    }
}

// MARK: - 日期工具扩展
extension Date {
    /// 获取交易日判断
    var isTradingDay: Bool {
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: self)
        return weekday >= 2 && weekday <= 6 // 周一到周五
    }
    
    /// 获取下一个交易日
    var nextTradingDay: Date {
        var date = self
        repeat {
            date = Calendar.current.date(byAdding: .day, value: 1, to: date) ?? date
        } while !date.isTradingDay
        return date
    }
    
    /// 获取上一个交易日
    var previousTradingDay: Date {
        var date = self
        repeat {
            date = Calendar.current.date(byAdding: .day, value: -1, to: date) ?? date
        } while !date.isTradingDay
        return date
    }
    
    /// 格式化为交易时间显示
    func formattedTradingTime() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM-dd HH:mm"
        return formatter.string(from: self)
    }
}

// MARK: - 图表动画工具
struct ChartAnimations {
    /// 图表数据更新动画
    static let dataUpdate = Animation.easeInOut(duration: 0.5)
    
    /// 图表缩放动画
    static let zoom = Animation.interpolatingSpring(stiffness: 100, damping: 15)
    
    /// 指标切换动画
    static let indicatorToggle = Animation.easeInOut(duration: 0.3)
    
    /// 图表滚动动画
    static let scroll = Animation.easeOut(duration: 0.8)
}

// MARK: - 图表手势处理器
class ChartGestureHandler: ObservableObject {
    @Published var scale: CGFloat = 1.0
    @Published var offset: CGSize = .zero
    @Published var lastOffset: CGSize = .zero
    
    private let minScale: CGFloat = 0.5
    private let maxScale: CGFloat = 3.0
    
    func handleMagnification(_ value: MagnificationGesture.Value) {
        let newScale = lastOffset == .zero ? value : scale * value
        scale = min(max(newScale, minScale), maxScale)
    }
    
    func handleMagnificationEnd(_ value: MagnificationGesture.Value) {
        let newScale = scale * value
        scale = min(max(newScale, minScale), maxScale)
    }
    
    func handleDrag(_ value: DragGesture.Value) {
        let newOffset = CGSize(
            width: lastOffset.width + value.translation.width,
            height: lastOffset.height + value.translation.height
        )
        offset = newOffset
    }
    
    func handleDragEnd(_ value: DragGesture.Value) {
        lastOffset = offset
    }
    
    func reset() {
        withAnimation(ChartAnimations.zoom) {
            scale = 1.0
            offset = .zero
            lastOffset = .zero
        }
    }
}

// MARK: - 图表主题配置
struct ChartTheme {
    static let dark = ChartThemeConfig(
        backgroundColor: Color.black,
        gridColor: Color.gray.opacity(0.3),
        textColor: Color.white,
        priceUpColor: Color.green,
        priceDownColor: Color.red,
        volumeUpColor: Color.green.opacity(0.7),
        volumeDownColor: Color.red.opacity(0.7)
    )
    
    static let light = ChartThemeConfig(
        backgroundColor: Color.white,
        gridColor: Color.gray.opacity(0.5),
        textColor: Color.black,
        priceUpColor: Color.green,
        priceDownColor: Color.red,
        volumeUpColor: Color.green.opacity(0.7),
        volumeDownColor: Color.red.opacity(0.7)
    )
}

struct ChartThemeConfig {
    let backgroundColor: Color
    let gridColor: Color
    let textColor: Color
    let priceUpColor: Color
    let priceDownColor: Color
    let volumeUpColor: Color
    let volumeDownColor: Color
}
