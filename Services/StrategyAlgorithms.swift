/*
 多周期策略算法库
 作者: MiniMax Agent
 创建日期: 2025-06-24
 
 实现高频、中频、低频、日线四种不同周期的交易策略算法
 */

import Foundation

/// 策略算法工厂类
public class StrategyAlgorithms {
    
    // MARK: - 策略工厂方法
    
    /// 创建策略算法实例
    /// - Parameter type: 策略类型
    /// - Returns: 策略算法实例
    public static func createStrategy(type: StrategyType) -> any TradingStrategy {
        switch type {
        case .highFrequency:
            return HighFrequencyStrategy()
        case .midFrequency:
            return MidFrequencyStrategy()
        case .lowFrequency:
            return LowFrequencyStrategy()
        case .daily:
            return DailyStrategy()
        }
    }
    
    /// 获取所有可用策略
    /// - Returns: 策略描述数组
    public static func getAllStrategies() -> [StrategyDescriptor] {
        return [
            StrategyDescriptor(
                type: .highFrequency,
                name: "高频策略集合",
                description: "1-5分钟周期，适合短线交易",
                subStrategies: HighFrequencyStrategy.getSubStrategies()
            ),
            StrategyDescriptor(
                type: .midFrequency,
                name: "中频策略集合",
                description: "15-30分钟周期，适合日内交易",
                subStrategies: MidFrequencyStrategy.getSubStrategies()
            ),
            StrategyDescriptor(
                type: .lowFrequency,
                name: "低频策略集合",
                description: "1-4小时周期，适合波段交易",
                subStrategies: LowFrequencyStrategy.getSubStrategies()
            ),
            StrategyDescriptor(
                type: .daily,
                name: "日线策略集合",
                description: "日K线周期，适合中长期持有",
                subStrategies: DailyStrategy.getSubStrategies()
            )
        ]
    }
}

// MARK: - 策略协议定义

/// 交易策略协议
public protocol TradingStrategy {
    var name: String { get }
    var timeframe: String { get }
    var requiredIndicators: [TechnicalIndicatorType] { get }
    
    func generateSignal(data: MarketData, indicators: [String: Any], parameters: [String: Any]) -> StrategySignal?
    func validateParameters(_ parameters: [String: Any]) -> Bool
    func getDefaultParameters() -> [String: Any]
}

/// 策略信号结构
public struct StrategySignal {
    let action: SignalAction
    let confidence: Double
    let price: Double
    let reasoning: String
    let metadata: [String: Any]
    let timestamp: Date
    
    init(action: SignalAction, confidence: Double, price: Double, reasoning: String, metadata: [String: Any] = [:]) {
        self.action = action
        self.confidence = confidence
        self.price = price
        self.reasoning = reasoning
        self.metadata = metadata
        self.timestamp = Date()
    }
}

/// 信号动作类型
public enum SignalAction: String, CaseIterable {
    case buy = "买入"
    case sell = "卖出"
    case hold = "持有"
    case closePosition = "平仓"
}

/// 市场数据结构
public struct MarketData {
    let symbol: String
    let currentPrice: Double
    let klineData: [KLineData]
    let volume: Double
    let timestamp: Date
}

/// K线数据结构
public struct KLineData {
    let open: Double
    let high: Double
    let low: Double
    let close: Double
    let volume: Double
    let timestamp: Date
}

/// 策略描述符
public struct StrategyDescriptor {
    let type: StrategyType
    let name: String
    let description: String
    let subStrategies: [SubStrategyDescriptor]
}

/// 子策略描述符
public struct SubStrategyDescriptor {
    let name: String
    let description: String
    let parameters: [String: Any]
    let riskLevel: RiskLevel
}

/// 风险等级
public enum RiskLevel: String, CaseIterable {
    case low = "低风险"
    case medium = "中风险"
    case high = "高风险"
    case veryHigh = "极高风险"
}

// MARK: - 高频策略 (1-5分钟)

/// 高频交易策略
public class HighFrequencyStrategy: TradingStrategy {
    public let name = "高频策略"
    public let timeframe = "1m"
    public let requiredIndicators: [TechnicalIndicatorType] = [.rsi, .macd, .ema]
    
    public func generateSignal(data: MarketData, indicators: [String: Any], parameters: [String: Any]) -> StrategySignal? {
        let strategyName = parameters["sub_strategy"] as? String ?? "momentum"
        
        switch strategyName {
        case "momentum":
            return generateMomentumSignal(data: data, indicators: indicators, parameters: parameters)
        case "mean_reversion":
            return generateMeanReversionSignal(data: data, indicators: indicators, parameters: parameters)
        case "breakout":
            return generateBreakoutSignal(data: data, indicators: indicators, parameters: parameters)
        default:
            return generateMomentumSignal(data: data, indicators: indicators, parameters: parameters)
        }
    }
    
    public func validateParameters(_ parameters: [String: Any]) -> Bool {
        guard let rsiPeriod = parameters["rsi_period"] as? Int,
              let emaPeriod = parameters["ema_period"] as? Int,
              rsiPeriod > 0, emaPeriod > 0 else {
            return false
        }
        return true
    }
    
    public func getDefaultParameters() -> [String: Any] {
        return [
            "sub_strategy": "momentum",
            "rsi_period": 14,
            "ema_period": 9,
            "rsi_overbought": 70,
            "rsi_oversold": 30,
            "confidence_threshold": 0.6,
            "stop_loss_pct": 0.02,
            "take_profit_pct": 0.04
        ]
    }
    
    /// 动量策略信号生成
    private func generateMomentumSignal(data: MarketData, indicators: [String: Any], parameters: [String: Any]) -> StrategySignal? {
        guard let rsi = indicators["rsi"] as? Double,
              let emaShort = indicators["ema_short"] as? Double,
              let macdSignal = indicators["macd_signal_type"] as? TradingSignalType else {
            return nil
        }
        
        let overbought = parameters["rsi_overbought"] as? Double ?? 70
        let oversold = parameters["rsi_oversold"] as? Double ?? 30
        let currentPrice = data.currentPrice
        
        var action: SignalAction = .hold
        var confidence: Double = 0
        var reasoning: [String] = []
        
        // 强势突破信号
        if currentPrice > emaShort && rsi > 50 && rsi < overbought && macdSignal == .buy {
            action = .buy
            confidence = 0.7 + (rsi - 50) / 100
            reasoning.append("价格突破EMA")
            reasoning.append("RSI中性偏强")
            reasoning.append("MACD金叉确认")
        }
        // 弱势突破信号
        else if currentPrice < emaShort && rsi < 50 && rsi > oversold && macdSignal == .sell {
            action = .sell
            confidence = 0.7 + (50 - rsi) / 100
            reasoning.append("价格跌破EMA")
            reasoning.append("RSI中性偏弱")
            reasoning.append("MACD死叉确认")
        }
        
        if action != .hold {
            return StrategySignal(
                action: action,
                confidence: min(confidence, 1.0),
                price: currentPrice,
                reasoning: reasoning.joined(separator: ", "),
                metadata: [
                    "strategy_type": "momentum",
                    "rsi": rsi,
                    "ema": emaShort,
                    "timeframe": timeframe
                ]
            )
        }
        
        return nil
    }
    
    /// 均值回归策略信号生成
    private func generateMeanReversionSignal(data: MarketData, indicators: [String: Any], parameters: [String: Any]) -> StrategySignal? {
        guard let rsi = indicators["rsi"] as? Double,
              let bbPosition = indicators["bb_position"] as? Double else {
            return nil
        }
        
        let oversold = parameters["rsi_oversold"] as? Double ?? 30
        let overbought = parameters["rsi_overbought"] as? Double ?? 70
        let currentPrice = data.currentPrice
        
        var action: SignalAction = .hold
        var confidence: Double = 0
        var reasoning: [String] = []
        
        // 超卖反弹信号
        if rsi < oversold && bbPosition < 0.1 {
            action = .buy
            confidence = (oversold - rsi) / oversold + (0.1 - bbPosition) * 2
            reasoning.append("RSI严重超卖")
            reasoning.append("触及布林带下轨")
        }
        // 超买回调信号
        else if rsi > overbought && bbPosition > 0.9 {
            action = .sell
            confidence = (rsi - overbought) / (100 - overbought) + (bbPosition - 0.9) * 10
            reasoning.append("RSI严重超买")
            reasoning.append("触及布林带上轨")
        }
        
        if action != .hold {
            return StrategySignal(
                action: action,
                confidence: min(confidence, 1.0),
                price: currentPrice,
                reasoning: reasoning.joined(separator: ", "),
                metadata: [
                    "strategy_type": "mean_reversion",
                    "rsi": rsi,
                    "bb_position": bbPosition,
                    "timeframe": timeframe
                ]
            )
        }
        
        return nil
    }
    
    /// 突破策略信号生成
    private func generateBreakoutSignal(data: MarketData, indicators: [String: Any], parameters: [String: Any]) -> StrategySignal? {
        guard let bbUpper = indicators["bb_upper"] as? Double,
              let bbLower = indicators["bb_lower"] as? Double,
              let volume = data.volume,
              data.klineData.count >= 3 else {
            return nil
        }
        
        let currentPrice = data.currentPrice
        let avgVolume = data.klineData.suffix(10).map { $0.volume }.reduce(0, +) / 10
        let volumeRatio = volume / avgVolume
        
        var action: SignalAction = .hold
        var confidence: Double = 0
        var reasoning: [String] = []
        
        // 向上突破
        if currentPrice > bbUpper && volumeRatio > 1.5 {
            action = .buy
            confidence = 0.6 + min((volumeRatio - 1.5) * 0.2, 0.3)
            reasoning.append("突破布林带上轨")
            reasoning.append("成交量放大\(String(format: "%.1f", volumeRatio))倍")
        }
        // 向下突破
        else if currentPrice < bbLower && volumeRatio > 1.5 {
            action = .sell
            confidence = 0.6 + min((volumeRatio - 1.5) * 0.2, 0.3)
            reasoning.append("跌破布林带下轨")
            reasoning.append("成交量放大\(String(format: "%.1f", volumeRatio))倍")
        }
        
        if action != .hold {
            return StrategySignal(
                action: action,
                confidence: min(confidence, 1.0),
                price: currentPrice,
                reasoning: reasoning.joined(separator: ", "),
                metadata: [
                    "strategy_type": "breakout",
                    "volume_ratio": volumeRatio,
                    "bb_upper": bbUpper,
                    "bb_lower": bbLower,
                    "timeframe": timeframe
                ]
            )
        }
        
        return nil
    }
    
    public static func getSubStrategies() -> [SubStrategyDescriptor] {
        return [
            SubStrategyDescriptor(
                name: "动量策略",
                description: "基于价格动量和技术指标的短线策略",
                parameters: ["sub_strategy": "momentum"],
                riskLevel: .high
            ),
            SubStrategyDescriptor(
                name: "均值回归策略", 
                description: "基于超买超卖的反转策略",
                parameters: ["sub_strategy": "mean_reversion"],
                riskLevel: .medium
            ),
            SubStrategyDescriptor(
                name: "突破策略",
                description: "基于价格突破的跟踪策略",
                parameters: ["sub_strategy": "breakout"],
                riskLevel: .veryHigh
            )
        ]
    }
}

// MARK: - 中频策略 (15-30分钟)

/// 中频交易策略
public class MidFrequencyStrategy: TradingStrategy {
    public let name = "中频策略"
    public let timeframe = "15m"
    public let requiredIndicators: [TechnicalIndicatorType] = [.ema, .macd, .rsi, .kdj]
    
    public func generateSignal(data: MarketData, indicators: [String: Any], parameters: [String: Any]) -> StrategySignal? {
        let strategyName = parameters["sub_strategy"] as? String ?? "trend_following"
        
        switch strategyName {
        case "trend_following":
            return generateTrendFollowingSignal(data: data, indicators: indicators, parameters: parameters)
        case "dual_ema":
            return generateDualEMASignal(data: data, indicators: indicators, parameters: parameters)
        case "rsi_divergence":
            return generateRSIDivergenceSignal(data: data, indicators: indicators, parameters: parameters)
        default:
            return generateTrendFollowingSignal(data: data, indicators: indicators, parameters: parameters)
        }
    }
    
    public func validateParameters(_ parameters: [String: Any]) -> Bool {
        guard let emaFast = parameters["ema_fast"] as? Int,
              let emaSlow = parameters["ema_slow"] as? Int,
              emaFast > 0, emaSlow > emaFast else {
            return false
        }
        return true
    }
    
    public func getDefaultParameters() -> [String: Any] {
        return [
            "sub_strategy": "trend_following",
            "ema_fast": 12,
            "ema_slow": 26,
            "rsi_period": 14,
            "kdj_period": 9,
            "confidence_threshold": 0.65,
            "stop_loss_pct": 0.03,
            "take_profit_pct": 0.06
        ]
    }
    
    /// 趋势跟踪策略
    private func generateTrendFollowingSignal(data: MarketData, indicators: [String: Any], parameters: [String: Any]) -> StrategySignal? {
        guard let emaFast = indicators["ema_short"] as? Double,
              let emaSlow = indicators["ema_long"] as? Double,
              let macdLine = indicators["macd_line"] as? Double,
              let macdSignalLine = indicators["macd_signal"] as? Double,
              let rsi = indicators["rsi"] as? Double else {
            return nil
        }
        
        let currentPrice = data.currentPrice
        var action: SignalAction = .hold
        var confidence: Double = 0
        var reasoning: [String] = []
        
        // 多头趋势确认
        if emaFast > emaSlow && macdLine > macdSignalLine && rsi > 40 && rsi < 80 {
            action = .buy
            confidence = 0.6
            reasoning.append("快线上穿慢线")
            reasoning.append("MACD多头排列")
            reasoning.append("RSI处于健康区间")
            
            // 增加确认因子
            let trendStrength = (emaFast - emaSlow) / emaSlow
            confidence += min(trendStrength * 5, 0.3)
        }
        // 空头趋势确认
        else if emaFast < emaSlow && macdLine < macdSignalLine && rsi < 60 && rsi > 20 {
            action = .sell
            confidence = 0.6
            reasoning.append("快线下穿慢线")
            reasoning.append("MACD空头排列")
            reasoning.append("RSI处于健康区间")
            
            let trendStrength = (emaSlow - emaFast) / emaSlow
            confidence += min(trendStrength * 5, 0.3)
        }
        
        if action != .hold {
            return StrategySignal(
                action: action,
                confidence: min(confidence, 1.0),
                price: currentPrice,
                reasoning: reasoning.joined(separator: ", "),
                metadata: [
                    "strategy_type": "trend_following",
                    "ema_fast": emaFast,
                    "ema_slow": emaSlow,
                    "macd": macdLine,
                    "rsi": rsi,
                    "timeframe": timeframe
                ]
            )
        }
        
        return nil
    }
    
    /// 双均线策略
    private func generateDualEMASignal(data: MarketData, indicators: [String: Any], parameters: [String: Any]) -> StrategySignal? {
        guard let emaFast = indicators["ema_short"] as? Double,
              let emaSlow = indicators["ema_long"] as? Double,
              let emaFastArray = indicators["ema_short_array"] as? [Double],
              let emaSlowArray = indicators["ema_long_array"] as? [Double],
              emaFastArray.count >= 2, emaSlowArray.count >= 2 else {
            return nil
        }
        
        let currentPrice = data.currentPrice
        
        // 当前状态
        let currentCross = emaFast > emaSlow
        let previousCross = emaFastArray[emaFastArray.count - 2] > emaSlowArray[emaSlowArray.count - 2]
        
        // 检测金叉死叉
        if currentCross && !previousCross {
            // 金叉
            let crossStrength = abs(emaFast - emaSlow) / emaSlow
            return StrategySignal(
                action: .buy,
                confidence: 0.7 + min(crossStrength * 10, 0.2),
                price: currentPrice,
                reasoning: "EMA金叉信号",
                metadata: [
                    "strategy_type": "dual_ema",
                    "cross_type": "golden",
                    "cross_strength": crossStrength,
                    "timeframe": timeframe
                ]
            )
        } else if !currentCross && previousCross {
            // 死叉
            let crossStrength = abs(emaSlow - emaFast) / emaSlow
            return StrategySignal(
                action: .sell,
                confidence: 0.7 + min(crossStrength * 10, 0.2),
                price: currentPrice,
                reasoning: "EMA死叉信号",
                metadata: [
                    "strategy_type": "dual_ema",
                    "cross_type": "death",
                    "cross_strength": crossStrength,
                    "timeframe": timeframe
                ]
            )
        }
        
        return nil
    }
    
    /// RSI背离策略
    private func generateRSIDivergenceSignal(data: MarketData, indicators: [String: Any], parameters: [String: Any]) -> StrategySignal? {
        guard let rsi = indicators["rsi"] as? Double,
              let rsiArray = indicators["rsi_array"] as? [Double],
              rsiArray.count >= 10,
              data.klineData.count >= 10 else {
            return nil
        }
        
        let currentPrice = data.currentPrice
        let recentPrices = data.klineData.suffix(10).map { $0.close }
        let recentRSI = Array(rsiArray.suffix(10))
        
        // 检测背离
        let priceHighs = findLocalMaxima(recentPrices)
        let rsiHighs = findLocalMaxima(recentRSI)
        
        if priceHighs.count >= 2 && rsiHighs.count >= 2 {
            let lastPriceHigh = priceHighs.last!
            let prevPriceHigh = priceHighs[priceHighs.count - 2]
            let lastRSIHigh = rsiHighs.last!
            let prevRSIHigh = rsiHighs[rsiHighs.count - 2]
            
            // 顶背离：价格创新高，RSI没有创新高
            if lastPriceHigh > prevPriceHigh && lastRSIHigh < prevRSIHigh {
                return StrategySignal(
                    action: .sell,
                    confidence: 0.8,
                    price: currentPrice,
                    reasoning: "RSI顶背离信号",
                    metadata: [
                        "strategy_type": "rsi_divergence",
                        "divergence_type": "bearish",
                        "timeframe": timeframe
                    ]
                )
            }
        }
        
        // 检测底背离
        let priceLows = findLocalMinima(recentPrices)
        let rsiLows = findLocalMinima(recentRSI)
        
        if priceLows.count >= 2 && rsiLows.count >= 2 {
            let lastPriceLow = priceLows.last!
            let prevPriceLow = priceLows[priceLows.count - 2]
            let lastRSILow = rsiLows.last!
            let prevRSILow = rsiLows[rsiLows.count - 2]
            
            // 底背离：价格创新低，RSI没有创新低
            if lastPriceLow < prevPriceLow && lastRSILow > prevRSILow {
                return StrategySignal(
                    action: .buy,
                    confidence: 0.8,
                    price: currentPrice,
                    reasoning: "RSI底背离信号",
                    metadata: [
                        "strategy_type": "rsi_divergence",
                        "divergence_type": "bullish",
                        "timeframe": timeframe
                    ]
                )
            }
        }
        
        return nil
    }
    
    public static func getSubStrategies() -> [SubStrategyDescriptor] {
        return [
            SubStrategyDescriptor(
                name: "趋势跟踪策略",
                description: "多指标确认的趋势跟踪策略",
                parameters: ["sub_strategy": "trend_following"],
                riskLevel: .medium
            ),
            SubStrategyDescriptor(
                name: "双均线策略",
                description: "经典的双EMA金叉死叉策略",
                parameters: ["sub_strategy": "dual_ema"],
                riskLevel: .medium
            ),
            SubStrategyDescriptor(
                name: "RSI背离策略",
                description: "基于RSI技术背离的反转策略",
                parameters: ["sub_strategy": "rsi_divergence"],
                riskLevel: .low
            )
        ]
    }
}

// MARK: - 低频策略 (1-4小时)

/// 低频交易策略
public class LowFrequencyStrategy: TradingStrategy {
    public let name = "低频策略"
    public let timeframe = "1h"
    public let requiredIndicators: [TechnicalIndicatorType] = [.bollinger, .macd, .cci, .rsi]
    
    public func generateSignal(data: MarketData, indicators: [String: Any], parameters: [String: Any]) -> StrategySignal? {
        let strategyName = parameters["sub_strategy"] as? String ?? "swing_trading"
        
        switch strategyName {
        case "swing_trading":
            return generateSwingTradingSignal(data: data, indicators: indicators, parameters: parameters)
        case "bollinger_strategy":
            return generateBollingerStrategy(data: data, indicators: indicators, parameters: parameters)
        case "macd_strategy":
            return generateMACDStrategy(data: data, indicators: indicators, parameters: parameters)
        default:
            return generateSwingTradingSignal(data: data, indicators: indicators, parameters: parameters)
        }
    }
    
    public func validateParameters(_ parameters: [String: Any]) -> Bool {
        return true // 基本验证
    }
    
    public func getDefaultParameters() -> [String: Any] {
        return [
            "sub_strategy": "swing_trading",
            "bb_period": 20,
            "bb_multiplier": 2.0,
            "cci_period": 20,
            "rsi_period": 14,
            "confidence_threshold": 0.7,
            "stop_loss_pct": 0.05,
            "take_profit_pct": 0.10
        ]
    }
    
    /// 波段交易策略
    private func generateSwingTradingSignal(data: MarketData, indicators: [String: Any], parameters: [String: Any]) -> StrategySignal? {
        guard let bbPosition = indicators["bb_position"] as? Double,
              let cci = indicators["cci"] as? Double,
              let rsi = indicators["rsi"] as? Double,
              let macdHistogram = indicators["macd_histogram"] as? Double else {
            return nil
        }
        
        let currentPrice = data.currentPrice
        var action: SignalAction = .hold
        var confidence: Double = 0
        var reasoning: [String] = []
        
        // 波段底部买入信号
        if bbPosition < 0.2 && cci < -100 && rsi < 40 && macdHistogram > 0 {
            action = .buy
            confidence = 0.75
            reasoning.append("价格接近布林带下轨")
            reasoning.append("CCI超卖")
            reasoning.append("RSI偏低")
            reasoning.append("MACD柱状线转正")
        }
        // 波段顶部卖出信号
        else if bbPosition > 0.8 && cci > 100 && rsi > 60 && macdHistogram < 0 {
            action = .sell
            confidence = 0.75
            reasoning.append("价格接近布林带上轨")
            reasoning.append("CCI超买")
            reasoning.append("RSI偏高")
            reasoning.append("MACD柱状线转负")
        }
        
        if action != .hold {
            return StrategySignal(
                action: action,
                confidence: confidence,
                price: currentPrice,
                reasoning: reasoning.joined(separator: ", "),
                metadata: [
                    "strategy_type": "swing_trading",
                    "bb_position": bbPosition,
                    "cci": cci,
                    "rsi": rsi,
                    "timeframe": timeframe
                ]
            )
        }
        
        return nil
    }
    
    /// 布林带策略
    private func generateBollingerStrategy(data: MarketData, indicators: [String: Any], parameters: [String: Any]) -> StrategySignal? {
        guard let bbUpper = indicators["bb_upper"] as? Double,
              let bbMiddle = indicators["bb_middle"] as? Double,
              let bbLower = indicators["bb_lower"] as? Double else {
            return nil
        }
        
        let currentPrice = data.currentPrice
        let bbWidth = (bbUpper - bbLower) / bbMiddle
        
        var action: SignalAction = .hold
        var confidence: Double = 0
        var reasoning: [String] = []
        
        // 布林带收缩后的突破
        if bbWidth < 0.1 { // 窄幅震荡
            if currentPrice > bbUpper {
                action = .buy
                confidence = 0.8
                reasoning.append("突破布林带上轨")
                reasoning.append("窄幅震荡后突破")
            } else if currentPrice < bbLower {
                action = .sell
                confidence = 0.8
                reasoning.append("跌破布林带下轨")
                reasoning.append("窄幅震荡后突破")
            }
        }
        // 布林带扩张中的反转
        else if bbWidth > 0.2 {
            if currentPrice <= bbLower {
                action = .buy
                confidence = 0.7
                reasoning.append("触及布林带下轨")
                reasoning.append("布林带扩张状态")
            } else if currentPrice >= bbUpper {
                action = .sell
                confidence = 0.7
                reasoning.append("触及布林带上轨")
                reasoning.append("布林带扩张状态")
            }
        }
        
        if action != .hold {
            return StrategySignal(
                action: action,
                confidence: confidence,
                price: currentPrice,
                reasoning: reasoning.joined(separator: ", "),
                metadata: [
                    "strategy_type": "bollinger_strategy",
                    "bb_width": bbWidth,
                    "timeframe": timeframe
                ]
            )
        }
        
        return nil
    }
    
    /// MACD策略
    private func generateMACDStrategy(data: MarketData, indicators: [String: Any], parameters: [String: Any]) -> StrategySignal? {
        guard let macdLine = indicators["macd_line"] as? Double,
              let macdSignal = indicators["macd_signal"] as? Double,
              let macdHistogram = indicators["macd_histogram"] as? Double,
              let macdArrays = indicators["macd_arrays"] as? [String: [Double]],
              let macdArray = macdArrays["macd"],
              let signalArray = macdArrays["signal"],
              let histogramArray = macdArrays["histogram"],
              macdArray.count >= 3 else {
            return nil
        }
        
        let currentPrice = data.currentPrice
        
        // MACD零轴突破
        if macdLine > 0 && macdArray[macdArray.count - 2] <= 0 {
            return StrategySignal(
                action: .buy,
                confidence: 0.8,
                price: currentPrice,
                reasoning: "MACD上穿零轴",
                metadata: [
                    "strategy_type": "macd_strategy",
                    "signal_type": "zero_cross_up",
                    "timeframe": timeframe
                ]
            )
        } else if macdLine < 0 && macdArray[macdArray.count - 2] >= 0 {
            return StrategySignal(
                action: .sell,
                confidence: 0.8,
                price: currentPrice,
                reasoning: "MACD下穿零轴",
                metadata: [
                    "strategy_type": "macd_strategy",
                    "signal_type": "zero_cross_down",
                    "timeframe": timeframe
                ]
            )
        }
        
        // 柱状线背离
        if histogramArray.count >= 5 {
            let recentHist = Array(histogramArray.suffix(5))
            if isIncreasing(recentHist) && macdLine < macdSignal {
                return StrategySignal(
                    action: .buy,
                    confidence: 0.7,
                    price: currentPrice,
                    reasoning: "MACD柱状线背离向上",
                    metadata: [
                        "strategy_type": "macd_strategy",
                        "signal_type": "histogram_divergence_up",
                        "timeframe": timeframe
                    ]
                )
            } else if isDecreasing(recentHist) && macdLine > macdSignal {
                return StrategySignal(
                    action: .sell,
                    confidence: 0.7,
                    price: currentPrice,
                    reasoning: "MACD柱状线背离向下",
                    metadata: [
                        "strategy_type": "macd_strategy",
                        "signal_type": "histogram_divergence_down",
                        "timeframe": timeframe
                    ]
                )
            }
        }
        
        return nil
    }
    
    public static func getSubStrategies() -> [SubStrategyDescriptor] {
        return [
            SubStrategyDescriptor(
                name: "波段交易策略",
                description: "多指标确认的波段交易策略",
                parameters: ["sub_strategy": "swing_trading"],
                riskLevel: .medium
            ),
            SubStrategyDescriptor(
                name: "布林带策略",
                description: "基于布林带的突破和反转策略",
                parameters: ["sub_strategy": "bollinger_strategy"],
                riskLevel: .medium
            ),
            SubStrategyDescriptor(
                name: "MACD策略",
                description: "基于MACD的趋势确认策略",
                parameters: ["sub_strategy": "macd_strategy"],
                riskLevel: .low
            )
        ]
    }
}

// MARK: - 日线策略

/// 日线交易策略
public class DailyStrategy: TradingStrategy {
    public let name = "日线策略"
    public let timeframe = "1d"
    public let requiredIndicators: [TechnicalIndicatorType] = [.ema, .rsi, .macd, .cci]
    
    public func generateSignal(data: MarketData, indicators: [String: Any], parameters: [String: Any]) -> StrategySignal? {
        let strategyName = parameters["sub_strategy"] as? String ?? "long_trend"
        
        switch strategyName {
        case "long_trend":
            return generateLongTrendSignal(data: data, indicators: indicators, parameters: parameters)
        case "value_reversion":
            return generateValueReversionSignal(data: data, indicators: indicators, parameters: parameters)
        case "fundamental_trend":
            return generateFundamentalTrendSignal(data: data, indicators: indicators, parameters: parameters)
        default:
            return generateLongTrendSignal(data: data, indicators: indicators, parameters: parameters)
        }
    }
    
    public func validateParameters(_ parameters: [String: Any]) -> Bool {
        return true
    }
    
    public func getDefaultParameters() -> [String: Any] {
        return [
            "sub_strategy": "long_trend",
            "ema_period": 50,
            "rsi_period": 14,
            "trend_threshold": 0.1,
            "confidence_threshold": 0.75,
            "stop_loss_pct": 0.08,
            "take_profit_pct": 0.15
        ]
    }
    
    /// 长期趋势策略
    private func generateLongTrendSignal(data: MarketData, indicators: [String: Any], parameters: [String: Any]) -> StrategySignal? {
        guard let emaLong = indicators["ema_long"] as? Double,
              let rsi = indicators["rsi"] as? Double,
              let macdLine = indicators["macd_line"] as? Double,
              data.klineData.count >= 50 else {
            return nil
        }
        
        let currentPrice = data.currentPrice
        let priceChange = (currentPrice - emaLong) / emaLong
        let trendThreshold = parameters["trend_threshold"] as? Double ?? 0.1
        
        var action: SignalAction = .hold
        var confidence: Double = 0
        var reasoning: [String] = []
        
        // 强势上升趋势
        if priceChange > trendThreshold && rsi > 40 && rsi < 80 && macdLine > 0 {
            action = .buy
            confidence = 0.8
            reasoning.append("长期上升趋势")
            reasoning.append("价格远超EMA")
            reasoning.append("RSI健康区间")
            reasoning.append("MACD多头")
        }
        // 强势下降趋势
        else if priceChange < -trendThreshold && rsi < 60 && rsi > 20 && macdLine < 0 {
            action = .sell
            confidence = 0.8
            reasoning.append("长期下降趋势")
            reasoning.append("价格远低EMA")
            reasoning.append("RSI健康区间")
            reasoning.append("MACD空头")
        }
        
        if action != .hold {
            return StrategySignal(
                action: action,
                confidence: confidence,
                price: currentPrice,
                reasoning: reasoning.joined(separator: ", "),
                metadata: [
                    "strategy_type": "long_trend",
                    "price_change": priceChange,
                    "timeframe": timeframe
                ]
            )
        }
        
        return nil
    }
    
    /// 价值回归策略
    private func generateValueReversionSignal(data: MarketData, indicators: [String: Any], parameters: [String: Any]) -> StrategySignal? {
        guard let rsi = indicators["rsi"] as? Double,
              let cci = indicators["cci"] as? Double,
              data.klineData.count >= 30 else {
            return nil
        }
        
        let currentPrice = data.currentPrice
        let recentPrices = data.klineData.suffix(30).map { $0.close }
        let avgPrice = recentPrices.reduce(0, +) / Double(recentPrices.count)
        let priceDeviation = (currentPrice - avgPrice) / avgPrice
        
        var action: SignalAction = .hold
        var confidence: Double = 0
        var reasoning: [String] = []
        
        // 价值低估买入
        if priceDeviation < -0.15 && rsi < 35 && cci < -150 {
            action = .buy
            confidence = 0.85
            reasoning.append("价格严重低于平均值")
            reasoning.append("RSI深度超卖")
            reasoning.append("CCI极度超卖")
        }
        // 价值高估卖出
        else if priceDeviation > 0.15 && rsi > 65 && cci > 150 {
            action = .sell
            confidence = 0.85
            reasoning.append("价格严重高于平均值")
            reasoning.append("RSI深度超买")
            reasoning.append("CCI极度超买")
        }
        
        if action != .hold {
            return StrategySignal(
                action: action,
                confidence: confidence,
                price: currentPrice,
                reasoning: reasoning.joined(separator: ", "),
                metadata: [
                    "strategy_type": "value_reversion",
                    "price_deviation": priceDeviation,
                    "timeframe": timeframe
                ]
            )
        }
        
        return nil
    }
    
    /// 基本面趋势策略
    private func generateFundamentalTrendSignal(data: MarketData, indicators: [String: Any], parameters: [String: Any]) -> StrategySignal? {
        // 这里可以结合基本面数据，暂时使用技术指标替代
        guard let emaLong = indicators["ema_long"] as? Double,
              let macdLine = indicators["macd_line"] as? Double,
              data.klineData.count >= 60 else {
            return nil
        }
        
        let currentPrice = data.currentPrice
        let longTermData = data.klineData.suffix(60)
        
        // 计算长期趋势强度
        let trendStrength = calculateTrendStrength(longTermData.map { $0.close })
        
        var action: SignalAction = .hold
        var confidence: Double = 0
        var reasoning: [String] = []
        
        if trendStrength > 0.3 && currentPrice > emaLong && macdLine > 0 {
            action = .buy
            confidence = 0.75
            reasoning.append("长期趋势向上")
            reasoning.append("技术面确认")
        } else if trendStrength < -0.3 && currentPrice < emaLong && macdLine < 0 {
            action = .sell
            confidence = 0.75
            reasoning.append("长期趋势向下")
            reasoning.append("技术面确认")
        }
        
        if action != .hold {
            return StrategySignal(
                action: action,
                confidence: confidence,
                price: currentPrice,
                reasoning: reasoning.joined(separator: ", "),
                metadata: [
                    "strategy_type": "fundamental_trend",
                    "trend_strength": trendStrength,
                    "timeframe": timeframe
                ]
            )
        }
        
        return nil
    }
    
    public static func getSubStrategies() -> [SubStrategyDescriptor] {
        return [
            SubStrategyDescriptor(
                name: "长期趋势策略",
                description: "基于长期趋势的投资策略",
                parameters: ["sub_strategy": "long_trend"],
                riskLevel: .low
            ),
            SubStrategyDescriptor(
                name: "价值回归策略",
                description: "基于价值回归的投资策略",
                parameters: ["sub_strategy": "value_reversion"],
                riskLevel: .low
            ),
            SubStrategyDescriptor(
                name: "基本面趋势策略",
                description: "结合基本面的长期趋势策略",
                parameters: ["sub_strategy": "fundamental_trend"],
                riskLevel: .low
            )
        ]
    }
}

// MARK: - 辅助函数

/// 寻找局部最大值
private func findLocalMaxima(_ data: [Double]) -> [Double] {
    guard data.count >= 3 else { return [] }
    
    var maxima: [Double] = []
    for i in 1..<(data.count - 1) {
        if data[i] > data[i-1] && data[i] > data[i+1] {
            maxima.append(data[i])
        }
    }
    return maxima
}

/// 寻找局部最小值
private func findLocalMinima(_ data: [Double]) -> [Double] {
    guard data.count >= 3 else { return [] }
    
    var minima: [Double] = []
    for i in 1..<(data.count - 1) {
        if data[i] < data[i-1] && data[i] < data[i+1] {
            minima.append(data[i])
        }
    }
    return minima
}

/// 判断数组是否递增
private func isIncreasing(_ data: [Double]) -> Bool {
    guard data.count >= 2 else { return false }
    
    for i in 1..<data.count {
        if data[i] <= data[i-1] {
            return false
        }
    }
    return true
}

/// 判断数组是否递减
private func isDecreasing(_ data: [Double]) -> Bool {
    guard data.count >= 2 else { return false }
    
    for i in 1..<data.count {
        if data[i] >= data[i-1] {
            return false
        }
    }
    return true
}

/// 计算趋势强度
private func calculateTrendStrength(_ prices: [Double]) -> Double {
    guard prices.count >= 10 else { return 0 }
    
    let firstPrice = prices.first!
    let lastPrice = prices.last!
    let totalReturn = (lastPrice - firstPrice) / firstPrice
    
    // 计算波动率
    let returns = zip(prices.dropFirst(), prices.dropLast()).map { ($0 - $1) / $1 }
    let avgReturn = returns.reduce(0, +) / Double(returns.count)
    let volatility = sqrt(returns.map { pow($0 - avgReturn, 2) }.reduce(0, +) / Double(returns.count))
    
    // 趋势强度 = 总收益率 / 波动率
    return volatility > 0 ? totalReturn / volatility : 0
}
