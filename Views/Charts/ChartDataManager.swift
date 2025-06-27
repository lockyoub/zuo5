//
//  ChartDataManager.swift
//  StockTradingApp
//
//  Created by MiniMax Agent on 2025-06-24.
//  图表数据管理器 - 处理所有图表相关的数据加载和状态管理
//

import Foundation
import SwiftUI
import Combine

/// 图表数据管理器
@MainActor
class ChartDataManager: ObservableObject {
    // MARK: - 发布的属性
    @Published var candlestickData: [CandlestickData] = []
    @Published var volumeData: [VolumeData] = []
    @Published var indicatorData: [String: [IndicatorData]] = [:]
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    // MARK: - 私有属性
    private var cancellables = Set<AnyCancellable>()
    private let networkManager = EnhancedNetworkManager()
    private let technicalIndicators = TechnicalIndicators()
    
    // 缩放和平移状态
    @Published var zoomLevel: Double = 1.0
    @Published var panOffset: Double = 0.0
    
    // 当前显示的指标
    @Published var activeIndicators: Set<TechnicalIndicatorType> = []
    
    // MARK: - 数据加载方法
    func loadCandlestickData(stockCode: String, timeframe: TimeFrame) async {
        isLoading = true
        errorMessage = nil
        
        do {
            // 获取K线数据
            let klineData = try await fetchKLineData(stockCode: stockCode, timeframe: timeframe)
            
            // 转换为图表数据格式
            let chartData = convertToChartData(klineData)
            
            // 计算成交量数据
            let volumeChartData = convertToVolumeData(klineData)
            
            // 更新UI数据
            candlestickData = chartData
            volumeData = volumeChartData
            
            // 计算和更新技术指标
            await updateTechnicalIndicators(for: chartData)
            
        } catch {
            errorMessage = "数据加载失败: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    // MARK: - 技术指标管理
    func toggleIndicator(_ indicator: TechnicalIndicatorType) {
        if activeIndicators.contains(indicator) {
            activeIndicators.remove(indicator)
            indicatorData.removeValue(forKey: indicator.rawValue)
        } else {
            activeIndicators.insert(indicator)
            Task {
                await calculateIndicator(indicator)
            }
        }
    }
    
    private func updateTechnicalIndicators(for data: [CandlestickData]) async {
        for indicator in activeIndicators {
            await calculateIndicator(indicator)
        }
    }
    
    private func calculateIndicator(_ indicator: TechnicalIndicatorType) async {
        let prices = candlestickData.map { $0.close }
        let highs = candlestickData.map { $0.high }
        let lows = candlestickData.map { $0.low }
        let volumes = volumeData.map { $0.volume }
        
        var indicatorValues: [IndicatorData] = []
        
        switch indicator {
        case .ma:
            let ma20 = technicalIndicators.sma(data: prices, period: 20)
            let ma60 = technicalIndicators.sma(data: prices, period: 60)
            
            for (index, value) in ma20.enumerated() {
                if index < candlestickData.count {
                    let data = IndicatorData(
                        timestamp: candlestickData[index].timestamp,
                        value: value,
                        secondaryValue: index < ma60.count ? ma60[index] : nil,
                        type: .ma
                    )
                    indicatorValues.append(data)
                }
            }
            
        case .ema:
            let ema12 = technicalIndicators.ema(data: prices, period: 12)
            let ema26 = technicalIndicators.ema(data: prices, period: 26)
            
            for (index, value) in ema12.enumerated() {
                if index < candlestickData.count {
                    let data = IndicatorData(
                        timestamp: candlestickData[index].timestamp,
                        value: value,
                        secondaryValue: index < ema26.count ? ema26[index] : nil,
                        type: .ema
                    )
                    indicatorValues.append(data)
                }
            }
            
        case .macd:
            let macdResult = technicalIndicators.macd(data: prices)
            
            for (index, value) in macdResult.macd.enumerated() {
                if index < candlestickData.count {
                    let data = IndicatorData(
                        timestamp: candlestickData[index].timestamp,
                        value: value,
                        secondaryValue: macdResult.signal[index],
                        thirdValue: macdResult.histogram[index],
                        type: .macd
                    )
                    indicatorValues.append(data)
                }
            }
            
        case .rsi:
            let rsiValues = technicalIndicators.rsi(data: prices, period: 14)
            
            for (index, value) in rsiValues.enumerated() {
                if index < candlestickData.count {
                    let data = IndicatorData(
                        timestamp: candlestickData[index].timestamp,
                        value: value,
                        type: .rsi
                    )
                    indicatorValues.append(data)
                }
            }
            
        case .bollinger:
            let bollingerResult = technicalIndicators.bollingerBands(data: prices, period: 20, standardDeviations: 2)
            
            for (index, upper) in bollingerResult.upperBand.enumerated() {
                if index < candlestickData.count {
                    let data = IndicatorData(
                        timestamp: candlestickData[index].timestamp,
                        value: upper,
                        secondaryValue: bollingerResult.middleBand[index],
                        thirdValue: bollingerResult.lowerBand[index],
                        type: .bollinger
                    )
                    indicatorValues.append(data)
                }
            }
            
        case .kdj:
            let kdjResult = technicalIndicators.kdj(highs: highs, lows: lows, closes: prices)
            
            for (index, k) in kdjResult.k.enumerated() {
                if index < candlestickData.count {
                    let data = IndicatorData(
                        timestamp: candlestickData[index].timestamp,
                        value: k,
                        secondaryValue: kdjResult.d[index],
                        thirdValue: kdjResult.j[index],
                        type: .kdj
                    )
                    indicatorValues.append(data)
                }
            }
        }
        
        indicatorData[indicator.rawValue] = indicatorValues
    }
    
    // MARK: - 缩放和平移
    func zoomIn() {
        zoomLevel = min(zoomLevel * 1.5, 10.0)
    }
    
    func zoomOut() {
        zoomLevel = max(zoomLevel / 1.5, 0.1)
    }
    
    func pan(by offset: Double) {
        panOffset += offset
    }
    
    // MARK: - 私有方法
    private func fetchKLineData(stockCode: String, timeframe: TimeFrame) async throws -> [KLineEntity] {
        // 构建请求参数
        let request = MarketDataRequest(
            action: "get_kline",
            symbol: stockCode,
            interval: timeframe.apiValue,
            limit: 500
        )
        
        // 通过网络管理器获取数据
        return try await networkManager.fetchKLineData(request: request)
    }
    
    private func convertToChartData(_ klineData: [KLineEntity]) -> [CandlestickData] {
        return klineData.map { kline in
            CandlestickData(
                timestamp: kline.timestamp,
                open: kline.open,
                high: kline.high,
                low: kline.low,
                close: kline.close,
                volume: kline.volume
            )
        }
    }
    
    private func convertToVolumeData(_ klineData: [KLineEntity]) -> [VolumeData] {
        return klineData.map { kline in
            VolumeData(
                timestamp: kline.timestamp,
                volume: kline.volume,
                isGreen: kline.close >= kline.open
            )
        }
    }
}

// MARK: - 数据模型
struct CandlestickData: Identifiable {
    let id = UUID()
    let timestamp: Date
    let open: Double
    let high: Double
    let low: Double
    let close: Double
    let volume: Double
}

struct VolumeData: Identifiable {
    let id = UUID()
    let timestamp: Date
    let volume: Double
    let isGreen: Bool
}

struct IndicatorData: Identifiable {
    let id = UUID()
    let timestamp: Date
    let value: Double
    let secondaryValue: Double?
    let thirdValue: Double?
    let type: TechnicalIndicatorType
    
    init(timestamp: Date, value: Double, secondaryValue: Double? = nil, thirdValue: Double? = nil, type: TechnicalIndicatorType) {
        self.timestamp = timestamp
        self.value = value
        self.secondaryValue = secondaryValue
        self.thirdValue = thirdValue
        self.type = type
    }
}

// MARK: - 扩展
extension TechnicalIndicatorType: RawRepresentable {
    var rawValue: String {
        switch self {
        case .ma: return "ma"
        case .ema: return "ema"
        case .macd: return "macd"
        case .rsi: return "rsi"
        case .bollinger: return "bollinger"
        case .kdj: return "kdj"
        }
    }
    
    init?(rawValue: String) {
        switch rawValue {
        case "ma": self = .ma
        case "ema": self = .ema
        case "macd": self = .macd
        case "rsi": self = .rsi
        case "bollinger": self = .bollinger
        case "kdj": self = .kdj
        default: return nil
        }
    }
}

extension TimeFrame {
    var apiValue: String {
        switch self {
        case .minute1: return "1m"
        case .minute5: return "5m"
        case .minute15: return "15m"
        case .minute30: return "30m"
        case .hour1: return "1h"
        case .hour4: return "4h"
        case .day1: return "1d"
        case .week1: return "1w"
        case .month1: return "1M"
        }
    }
}

// MARK: - 请求数据模型
struct MarketDataRequest {
    let action: String
    let symbol: String
    let interval: String
    let limit: Int
}
