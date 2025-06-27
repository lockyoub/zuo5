/*
 技术指标计算库
 作者: MiniMax Agent
 创建日期: 2025-06-24
 
 提供完整的技术指标计算功能，支持多周期交易策略
 */

import Foundation

/// 技术指标计算类
public class TechnicalIndicators {
    
    // MARK: - 移动平均线指标
    
    /// 简单移动平均线 (SMA)
    /// - Parameters:
    ///   - data: 价格数据数组
    ///   - period: 计算周期
    /// - Returns: SMA值数组
    public static func SMA(data: [Double], period: Int) -> [Double] {
        guard data.count >= period, period > 0 else { return [] }
        
        var result: [Double] = []
        
        for i in (period - 1)..<data.count {
            let sum = data[(i - period + 1)...i].reduce(0, +)
            let average = sum / Double(period)
            result.append(average)
        }
        
        return result
    }
    
    /// 指数移动平均线 (EMA)
    /// - Parameters:
    ///   - data: 价格数据数组
    ///   - period: 计算周期
    /// - Returns: EMA值数组
    public static func EMA(data: [Double], period: Int) -> [Double] {
        guard data.count >= period, period > 0 else { return [] }
        
        let alpha = 2.0 / Double(period + 1)
        var result: [Double] = []
        
        // 第一个EMA值使用SMA
        let firstSMA = data[0..<period].reduce(0, +) / Double(period)
        result.append(firstSMA)
        
        // 计算后续EMA值
        for i in period..<data.count {
            let ema = alpha * data[i] + (1 - alpha) * result.last!
            result.append(ema)
        }
        
        return result
    }
    
    // MARK: - 动量指标
    
    /// 相对强弱指数 (RSI)
    /// - Parameters:
    ///   - data: 价格数据数组
    ///   - period: 计算周期，默认14
    /// - Returns: RSI值数组
    public static func RSI(data: [Double], period: Int = 14) -> [Double] {
        guard data.count > period, period > 0 else { return [] }
        
        var gains: [Double] = []
        var losses: [Double] = []
        var result: [Double] = []
        
        // 计算价格变化
        for i in 1..<data.count {
            let change = data[i] - data[i - 1]
            gains.append(max(change, 0))
            losses.append(max(-change, 0))
        }
        
        // 计算RSI
        for i in (period - 1)..<gains.count {
            let avgGain = gains[(i - period + 1)...i].reduce(0, +) / Double(period)
            let avgLoss = losses[(i - period + 1)...i].reduce(0, +) / Double(period)
            
            if avgLoss == 0 {
                result.append(100)
            } else {
                let rs = avgGain / avgLoss
                let rsi = 100 - (100 / (1 + rs))
                result.append(rsi)
            }
        }
        
        return result
    }
    
    /// MACD指标 (Moving Average Convergence Divergence)
    /// - Parameters:
    ///   - data: 价格数据数组
    ///   - fastPeriod: 快线周期，默认12
    ///   - slowPeriod: 慢线周期，默认26
    ///   - signalPeriod: 信号线周期，默认9
    /// - Returns: (macd线, 信号线, 柱状线)
    public static func MACD(data: [Double], fastPeriod: Int = 12, slowPeriod: Int = 26, signalPeriod: Int = 9) -> (macd: [Double], signal: [Double], histogram: [Double]) {
        let fastEMA = EMA(data: data, period: fastPeriod)
        let slowEMA = EMA(data: data, period: slowPeriod)
        
        // 确保两个EMA数组长度一致
        let minLength = min(fastEMA.count, slowEMA.count)
        let startIndex = fastEMA.count - minLength
        
        var macdLine: [Double] = []
        
        // 计算MACD线
        for i in 0..<minLength {
            let macd = fastEMA[startIndex + i] - slowEMA[i]
            macdLine.append(macd)
        }
        
        // 计算信号线（MACD的EMA）
        let signalLine = EMA(data: macdLine, period: signalPeriod)
        
        // 计算柱状线
        var histogram: [Double] = []
        let histogramStartIndex = macdLine.count - signalLine.count
        
        for i in 0..<signalLine.count {
            let hist = macdLine[histogramStartIndex + i] - signalLine[i]
            histogram.append(hist)
        }
        
        return (macd: macdLine, signal: signalLine, histogram: histogram)
    }
    
    // MARK: - 波动性指标
    
    /// 布林带 (Bollinger Bands)
    /// - Parameters:
    ///   - data: 价格数据数组
    ///   - period: 计算周期，默认20
    ///   - multiplier: 标准差倍数，默认2.0
    /// - Returns: (上轨, 中轨, 下轨)
    public static func BollingerBands(data: [Double], period: Int = 20, multiplier: Double = 2.0) -> (upper: [Double], middle: [Double], lower: [Double]) {
        let sma = SMA(data: data, period: period)
        
        var upper: [Double] = []
        var lower: [Double] = []
        
        // 计算标准差和布林带
        for i in (period - 1)..<data.count {
            let subset = Array(data[(i - period + 1)...i])
            let mean = subset.reduce(0, +) / Double(period)
            let variance = subset.map { pow($0 - mean, 2) }.reduce(0, +) / Double(period)
            let standardDeviation = sqrt(variance)
            
            let smaIndex = i - (period - 1)
            let upperBand = sma[smaIndex] + multiplier * standardDeviation
            let lowerBand = sma[smaIndex] - multiplier * standardDeviation
            
            upper.append(upperBand)
            lower.append(lowerBand)
        }
        
        return (upper: upper, middle: sma, lower: lower)
    }
    
    // MARK: - 随机指标
    
    /// KDJ随机指标
    /// - Parameters:
    ///   - high: 最高价数组
    ///   - low: 最低价数组
    ///   - close: 收盘价数组
    ///   - period: K值计算周期，默认9
    ///   - kSmooth: K值平滑周期，默认3
    ///   - dSmooth: D值平滑周期，默认3
    /// - Returns: (K值, D值, J值)
    public static func KDJ(high: [Double], low: [Double], close: [Double], period: Int = 9, kSmooth: Int = 3, dSmooth: Int = 3) -> (k: [Double], d: [Double], j: [Double]) {
        guard high.count == low.count && low.count == close.count else { return ([], [], []) }
        guard high.count >= period else { return ([], [], []) }
        
        var rsvValues: [Double] = []
        
        // 计算RSV值
        for i in (period - 1)..<close.count {
            let highestHigh = high[(i - period + 1)...i].max() ?? 0
            let lowestLow = low[(i - period + 1)...i].min() ?? 0
            
            if highestHigh == lowestLow {
                rsvValues.append(50) // 避免除零
            } else {
                let rsv = (close[i] - lowestLow) / (highestHigh - lowestLow) * 100
                rsvValues.append(rsv)
            }
        }
        
        // 计算K值（RSV的移动平均）
        let kValues = SMA(data: rsvValues, period: kSmooth)
        
        // 计算D值（K值的移动平均）
        let dValues = SMA(data: kValues, period: dSmooth)
        
        // 计算J值 J = 3K - 2D
        var jValues: [Double] = []
        let minLength = min(kValues.count, dValues.count)
        let kStartIndex = kValues.count - minLength
        
        for i in 0..<minLength {
            let j = 3 * kValues[kStartIndex + i] - 2 * dValues[i]
            jValues.append(j)
        }
        
        return (k: kValues, d: dValues, j: jValues)
    }
    
    // MARK: - 成交量指标
    
    /// 成交量加权平均价 (VWAP)
    /// - Parameters:
    ///   - price: 价格数组（通常是典型价格: (H+L+C)/3）
    ///   - volume: 成交量数组
    ///   - period: 计算周期
    /// - Returns: VWAP值数组
    public static func VWAP(price: [Double], volume: [Double], period: Int) -> [Double] {
        guard price.count == volume.count, price.count >= period else { return [] }
        
        var result: [Double] = []
        
        for i in (period - 1)..<price.count {
            let priceVolume = zip(price[(i - period + 1)...i], volume[(i - period + 1)...i])
                .map { $0 * $1 }
                .reduce(0, +)
            
            let totalVolume = volume[(i - period + 1)...i].reduce(0, +)
            
            if totalVolume > 0 {
                result.append(priceVolume / totalVolume)
            } else {
                result.append(0)
            }
        }
        
        return result
    }
    
    // MARK: - 其他指标
    
    /// 商品通道指数 (CCI)
    /// - Parameters:
    ///   - high: 最高价数组
    ///   - low: 最低价数组
    ///   - close: 收盘价数组
    ///   - period: 计算周期，默认20
    /// - Returns: CCI值数组
    public static func CCI(high: [Double], low: [Double], close: [Double], period: Int = 20) -> [Double] {
        guard high.count == low.count && low.count == close.count else { return [] }
        guard high.count >= period else { return [] }
        
        // 计算典型价格
        var typicalPrice: [Double] = []
        for i in 0..<close.count {
            let tp = (high[i] + low[i] + close[i]) / 3.0
            typicalPrice.append(tp)
        }
        
        // 计算典型价格的移动平均
        let tpSMA = SMA(data: typicalPrice, period: period)
        
        var result: [Double] = []
        
        // 计算CCI
        for i in (period - 1)..<typicalPrice.count {
            let tp = typicalPrice[i]
            let sma = tpSMA[i - (period - 1)]
            
            // 计算平均绝对偏差
            let subset = Array(typicalPrice[(i - period + 1)...i])
            let meanDeviation = subset.map { abs($0 - sma) }.reduce(0, +) / Double(period)
            
            if meanDeviation > 0 {
                let cci = (tp - sma) / (0.015 * meanDeviation)
                result.append(cci)
            } else {
                result.append(0)
            }
        }
        
        return result
    }
    
    /// 威廉指标 (%R)
    /// - Parameters:
    ///   - high: 最高价数组
    ///   - low: 最低价数组
    ///   - close: 收盘价数组
    ///   - period: 计算周期，默认14
    /// - Returns: Williams %R值数组
    public static func WilliamsR(high: [Double], low: [Double], close: [Double], period: Int = 14) -> [Double] {
        guard high.count == low.count && low.count == close.count else { return [] }
        guard high.count >= period else { return [] }
        
        var result: [Double] = []
        
        for i in (period - 1)..<close.count {
            let highestHigh = high[(i - period + 1)...i].max() ?? 0
            let lowestLow = low[(i - period + 1)...i].min() ?? 0
            
            if highestHigh == lowestLow {
                result.append(-50) // 避免除零
            } else {
                let wr = (highestHigh - close[i]) / (highestHigh - lowestLow) * (-100)
                result.append(wr)
            }
        }
        
        return result
    }
    
    // MARK: - 辅助方法
    
    /// 计算数据的标准差
    /// - Parameter data: 数据数组
    /// - Returns: 标准差值
    private static func standardDeviation(data: [Double]) -> Double {
        let mean = data.reduce(0, +) / Double(data.count)
        let variance = data.map { pow($0 - mean, 2) }.reduce(0, +) / Double(data.count)
        return sqrt(variance)
    }
    
    /// 计算典型价格 (Typical Price)
    /// - Parameters:
    ///   - high: 最高价
    ///   - low: 最低价
    ///   - close: 收盘价
    /// - Returns: 典型价格
    public static func typicalPrice(high: Double, low: Double, close: Double) -> Double {
        return (high + low + close) / 3.0
    }
    
    /// 计算真实范围 (True Range)
    /// - Parameters:
    ///   - high: 当前最高价
    ///   - low: 当前最低价
    ///   - prevClose: 前一日收盘价
    /// - Returns: 真实范围值
    public static func trueRange(high: Double, low: Double, prevClose: Double) -> Double {
        let tr1 = high - low
        let tr2 = abs(high - prevClose)
        let tr3 = abs(low - prevClose)
        
        return max(tr1, max(tr2, tr3))
    }
}

// MARK: - 指标信号判断扩展

extension TechnicalIndicators {
    
    /// RSI信号判断
    /// - Parameter rsi: RSI值
    /// - Returns: 交易信号
    public static func rsiSignal(rsi: Double) -> TradingSignalType {
        if rsi > 70 {
            return .sell // 超买
        } else if rsi < 30 {
            return .buy // 超卖
        } else {
            return .hold // 中性
        }
    }
    
    /// MACD信号判断
    /// - Parameters:
    ///   - macd: MACD值
    ///   - signal: 信号线值
    ///   - prevMacd: 前一个MACD值
    ///   - prevSignal: 前一个信号线值
    /// - Returns: 交易信号
    public static func macdSignal(macd: Double, signal: Double, prevMacd: Double, prevSignal: Double) -> TradingSignalType {
        // 金叉：MACD上穿信号线
        if macd > signal && prevMacd <= prevSignal {
            return .buy
        }
        // 死叉：MACD下穿信号线
        else if macd < signal && prevMacd >= prevSignal {
            return .sell
        }
        
        return .hold
    }
    
    /// KDJ信号判断
    /// - Parameters:
    ///   - k: K值
    ///   - d: D值
    ///   - j: J值
    /// - Returns: 交易信号
    public static func kdjSignal(k: Double, d: Double, j: Double) -> TradingSignalType {
        // 超买区域
        if k > 80 && d > 80 && j > 100 {
            return .sell
        }
        // 超卖区域
        else if k < 20 && d < 20 && j < 0 {
            return .buy
        }
        // 金叉
        else if k > d && k > 50 {
            return .buy
        }
        // 死叉
        else if k < d && k < 50 {
            return .sell
        }
        
        return .hold
    }
}

// MARK: - 信号类型定义

/// 交易信号类型
public enum TradingSignalType: String, CaseIterable {
    case buy = "买入"
    case sell = "卖出"
    case hold = "持有"
    
    var color: String {
        switch self {
        case .buy: return "green"
        case .sell: return "red" 
        case .hold: return "gray"
        }
    }
}
