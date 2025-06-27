/*
 增强策略引擎
 作者: MiniMax Agent
 创建日期: 2025-06-24
 
 集成技术指标计算库的增强版策略引擎
 */

import Foundation
import CoreData
import Combine

/// 增强策略引擎类 - 集成完整技术指标库
@MainActor
class EnhancedStrategyEngine: ObservableObject {
    // MARK: - Published Properties
    @Published var isRunning: Bool = false
    @Published var strategies: [AdvancedStrategy] = []
    @Published var signals: [EnhancedTradingSignal] = []
    @Published var performance: StrategyPerformance = StrategyPerformance()
    @Published var indicatorValues: [String: [String: Any]] = [:]
    
    // MARK: - Private Properties
    private var cancellables = Set<AnyCancellable>()
    private let persistenceController = PersistenceController.shared
    private var strategiesTimer: Timer?
    private var marketDataService: MarketDataService?
    private var tradingService: TradingService?
    
    // MARK: - 初始化
    init() {
        setupAdvancedStrategies()
        loadStrategiesFromStorage()
    }
    
    deinit {
        stop()
    }
    
    // MARK: - 公共方法
    
    /// 启动策略引擎
    func start() async {
        guard !isRunning else { return }
        
        await loadStrategiesFromStorage()
        startStrategyExecution()
        isRunning = true
        
        print("增强策略引擎已启动")
    }
    
    /// 停止策略引擎
    func stop() {
        strategiesTimer?.invalidate()
        strategiesTimer = nil
        isRunning = false
        
        print("增强策略引擎已停止")
    }
    
    /// 设置依赖服务
    func setDependencies(marketDataService: MarketDataService, tradingService: TradingService) {
        self.marketDataService = marketDataService
        self.tradingService = tradingService
    }
    
    /// 启用策略
    func enableStrategy(_ strategyId: UUID) async {
        guard let index = strategies.firstIndex(where: { $0.id == strategyId }) else { return }
        
        strategies[index].isEnabled = true
        await saveStrategyToStorage(strategies[index])
        
        print("策略已启用: \(strategies[index].name)")
    }
    
    /// 禁用策略
    func disableStrategy(_ strategyId: UUID) async {
        guard let index = strategies.firstIndex(where: { $0.id == strategyId }) else { return }
        
        strategies[index].isEnabled = false
        await saveStrategyToStorage(strategies[index])
        
        print("策略已禁用: \(strategies[index].name)")
    }
    
    /// 添加策略
    func addStrategy(_ strategy: AdvancedStrategy) async {
        strategies.append(strategy)
        await saveStrategyToStorage(strategy)
    }
    
    /// 获取策略指标值
    func getIndicatorValues(for symbol: String) -> [String: Any]? {
        return indicatorValues[symbol]
    }
    
    /// 获取策略信号
    func getSignals(for strategy: String? = nil, limit: Int = 50) -> [EnhancedTradingSignal] {
        var filteredSignals = signals
        
        if let strategy = strategy {
            filteredSignals = signals.filter { $0.strategy == strategy }
        }
        
        return Array(filteredSignals.prefix(limit))
    }
    
    // MARK: - 私有方法
    
    /// 设置高级策略
    private func setupAdvancedStrategies() {
        let advancedStrategies = [
            // 高频策略：基于RSI和MACD的动量策略
            AdvancedStrategy(
                id: UUID(),
                name: "RSI-MACD动量策略",
                type: .highFrequency,
                timeframe: "1m",
                isEnabled: false,
                indicators: [.rsi, .macd],
                parameters: [
                    "rsi_period": 14,
                    "rsi_overbought": 70,
                    "rsi_oversold": 30,
                    "macd_fast": 12,
                    "macd_slow": 26,
                    "macd_signal": 9,
                    "confidence_threshold": 0.6
                ]
            ),
            
            // 中频策略：布林带+KDJ策略
            AdvancedStrategy(
                id: UUID(),
                name: "布林带-KDJ策略",
                type: .midFrequency,
                timeframe: "5m",
                isEnabled: false,
                indicators: [.bollinger, .kdj],
                parameters: [
                    "bb_period": 20,
                    "bb_multiplier": 2.0,
                    "kdj_period": 9,
                    "kdj_k_smooth": 3,
                    "kdj_d_smooth": 3,
                    "confidence_threshold": 0.7
                ]
            ),
            
            // 低频策略：多指标综合策略
            AdvancedStrategy(
                id: UUID(),
                name: "多指标综合策略",
                type: .lowFrequency,
                timeframe: "15m",
                isEnabled: false,
                indicators: [.rsi, .macd, .bollinger, .cci],
                parameters: [
                    "rsi_period": 14,
                    "bb_period": 20,
                    "cci_period": 20,
                    "macd_fast": 12,
                    "macd_slow": 26,
                    "consensus_threshold": 3,
                    "confidence_threshold": 0.8
                ]
            ),
            
            // 日线策略：趋势跟踪策略
            AdvancedStrategy(
                id: UUID(),
                name: "EMA趋势跟踪策略",
                type: .daily,
                timeframe: "1d",
                isEnabled: false,
                indicators: [.ema, .macd, .rsi],
                parameters: [
                    "ema_short": 12,
                    "ema_long": 26,
                    "rsi_period": 14,
                    "trend_confirmation": true,
                    "confidence_threshold": 0.75
                ]
            )
        ]
        
        self.strategies = advancedStrategies
    }
    
    /// 从存储加载策略
    private func loadStrategiesFromStorage() async {
        // 暂时使用默认策略，后续可扩展到Core Data
        print("加载高级策略配置")
    }
    
    /// 保存策略到存储
    private func saveStrategyToStorage(_ strategy: AdvancedStrategy) async {
        // 暂时忽略存储，后续可扩展到Core Data
        print("保存策略: \(strategy.name)")
    }
    
    /// 开始策略执行
    private func startStrategyExecution() {
        strategiesTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            Task {
                await self?.executeStrategies()
            }
        }
    }
    
    /// 执行策略
    private func executeStrategies() async {
        guard let marketDataService = marketDataService else { return }
        
        for strategy in strategies where strategy.isEnabled {
            await executeAdvancedStrategy(strategy, with: marketDataService)
        }
        
        updatePerformance()
    }
    
    /// 执行单个高级策略
    private func executeAdvancedStrategy(_ strategy: AdvancedStrategy, with marketDataService: MarketDataService) async {
        let symbols = Array(marketDataService.stockData.keys)
        
        for symbol in symbols {
            guard let stockData = marketDataService.stockData[symbol] else { continue }
            
            // 计算技术指标
            let indicators = await calculateIndicators(for: symbol, strategy: strategy, marketDataService: marketDataService)
            
            // 存储指标值用于UI显示
            indicatorValues[symbol] = indicators
            
            // 生成交易信号
            let signal = generateAdvancedSignal(for: strategy, symbol: symbol, stockData: stockData, indicators: indicators)
            
            if let signal = signal {
                signals.insert(signal, at: 0)
                
                // 限制信号数量
                if signals.count > 1000 {
                    signals = Array(signals.prefix(1000))
                }
                
                // 如果是强信号，尝试执行交易
                if signal.confidence > (strategy.parameters["confidence_threshold"] as? Double ?? 0.7) {
                    await executeSignal(signal)
                }
            }
        }
    }
    
    /// 计算技术指标
    private func calculateIndicators(for symbol: String, strategy: AdvancedStrategy, marketDataService: MarketDataService) async -> [String: Any] {
        var indicators: [String: Any] = [:]
        
        let klineData = marketDataService.getKLineData(for: symbol, timeframe: strategy.timeframe)
        guard klineData.count >= 50 else { return indicators } // 需要足够的数据
        
        let closes = klineData.map { $0.close }
        let highs = klineData.map { $0.high }
        let lows = klineData.map { $0.low }
        let volumes = klineData.map { $0.volume }
        
        // 根据策略需要的指标进行计算
        for indicator in strategy.indicators {
            switch indicator {
            case .sma:
                let period = strategy.parameters["sma_period"] as? Int ?? 20
                let sma = TechnicalIndicators.SMA(data: closes, period: period)
                indicators["sma"] = sma.last
                indicators["sma_array"] = sma.suffix(10) // 保留最近10个值
                
            case .ema:
                let shortPeriod = strategy.parameters["ema_short"] as? Int ?? 12
                let longPeriod = strategy.parameters["ema_long"] as? Int ?? 26
                let shortEMA = TechnicalIndicators.EMA(data: closes, period: shortPeriod)
                let longEMA = TechnicalIndicators.EMA(data: closes, period: longPeriod)
                indicators["ema_short"] = shortEMA.last
                indicators["ema_long"] = longEMA.last
                indicators["ema_short_array"] = shortEMA.suffix(10)
                indicators["ema_long_array"] = longEMA.suffix(10)
                
            case .rsi:
                let period = strategy.parameters["rsi_period"] as? Int ?? 14
                let rsi = TechnicalIndicators.RSI(data: closes, period: period)
                indicators["rsi"] = rsi.last
                indicators["rsi_array"] = rsi.suffix(10)
                
                // RSI信号判断
                if let currentRSI = rsi.last {
                    indicators["rsi_signal"] = TechnicalIndicators.rsiSignal(rsi: currentRSI)
                }
                
            case .macd:
                let fastPeriod = strategy.parameters["macd_fast"] as? Int ?? 12
                let slowPeriod = strategy.parameters["macd_slow"] as? Int ?? 26
                let signalPeriod = strategy.parameters["macd_signal"] as? Int ?? 9
                
                let macdResult = TechnicalIndicators.MACD(data: closes, fastPeriod: fastPeriod, slowPeriod: slowPeriod, signalPeriod: signalPeriod)
                indicators["macd_line"] = macdResult.macd.last
                indicators["macd_signal"] = macdResult.signal.last
                indicators["macd_histogram"] = macdResult.histogram.last
                indicators["macd_arrays"] = [
                    "macd": macdResult.macd.suffix(10),
                    "signal": macdResult.signal.suffix(10),
                    "histogram": macdResult.histogram.suffix(10)
                ]
                
                // MACD信号判断
                if macdResult.macd.count >= 2 && macdResult.signal.count >= 2 {
                    let macdSignal = TechnicalIndicators.macdSignal(
                        macd: macdResult.macd.last!,
                        signal: macdResult.signal.last!,
                        prevMacd: macdResult.macd[macdResult.macd.count - 2],
                        prevSignal: macdResult.signal[macdResult.signal.count - 2]
                    )
                    indicators["macd_signal_type"] = macdSignal
                }
                
            case .bollinger:
                let period = strategy.parameters["bb_period"] as? Int ?? 20
                let multiplier = strategy.parameters["bb_multiplier"] as? Double ?? 2.0
                let bb = TechnicalIndicators.BollingerBands(data: closes, period: period, multiplier: multiplier)
                
                indicators["bb_upper"] = bb.upper.last
                indicators["bb_middle"] = bb.middle.last
                indicators["bb_lower"] = bb.lower.last
                indicators["bb_arrays"] = [
                    "upper": bb.upper.suffix(10),
                    "middle": bb.middle.suffix(10),
                    "lower": bb.lower.suffix(10)
                ]
                
                // 布林带位置判断
                if let upper = bb.upper.last, let lower = bb.lower.last {
                    let currentPrice = closes.last!
                    let position = (currentPrice - lower) / (upper - lower)
                    indicators["bb_position"] = position
                }
                
            case .kdj:
                let period = strategy.parameters["kdj_period"] as? Int ?? 9
                let kSmooth = strategy.parameters["kdj_k_smooth"] as? Int ?? 3
                let dSmooth = strategy.parameters["kdj_d_smooth"] as? Int ?? 3
                
                let kdj = TechnicalIndicators.KDJ(high: highs, low: lows, close: closes, period: period, kSmooth: kSmooth, dSmooth: dSmooth)
                indicators["kdj_k"] = kdj.k.last
                indicators["kdj_d"] = kdj.d.last
                indicators["kdj_j"] = kdj.j.last
                indicators["kdj_arrays"] = [
                    "k": kdj.k.suffix(10),
                    "d": kdj.d.suffix(10),
                    "j": kdj.j.suffix(10)
                ]
                
                // KDJ信号判断
                if let k = kdj.k.last, let d = kdj.d.last, let j = kdj.j.last {
                    indicators["kdj_signal"] = TechnicalIndicators.kdjSignal(k: k, d: d, j: j)
                }
                
            case .cci:
                let period = strategy.parameters["cci_period"] as? Int ?? 20
                let cci = TechnicalIndicators.CCI(high: highs, low: lows, close: closes, period: period)
                indicators["cci"] = cci.last
                indicators["cci_array"] = cci.suffix(10)
                
            case .williamsR:
                let period = strategy.parameters["wr_period"] as? Int ?? 14
                let wr = TechnicalIndicators.WilliamsR(high: highs, low: lows, close: closes, period: period)
                indicators["williams_r"] = wr.last
                indicators["williams_r_array"] = wr.suffix(10)
                
            case .vwap:
                let period = strategy.parameters["vwap_period"] as? Int ?? 20
                let typicalPrices = zip(zip(highs, lows), closes).map { TechnicalIndicators.typicalPrice(high: $0.0.0, low: $0.0.1, close: $0.1) }
                let vwap = TechnicalIndicators.VWAP(price: typicalPrices, volume: volumes, period: period)
                indicators["vwap"] = vwap.last
                indicators["vwap_array"] = vwap.suffix(10)
            }
        }
        
        return indicators
    }
    
    /// 生成高级交易信号
    private func generateAdvancedSignal(
        for strategy: AdvancedStrategy,
        symbol: String,
        stockData: StockData,
        indicators: [String: Any]
    ) -> EnhancedTradingSignal? {
        
        switch strategy.type {
        case .highFrequency:
            return generateRSIMACDSignal(strategy: strategy, symbol: symbol, stockData: stockData, indicators: indicators)
        case .midFrequency:
            return generateBollingerKDJSignal(strategy: strategy, symbol: symbol, stockData: stockData, indicators: indicators)
        case .lowFrequency:
            return generateMultiIndicatorSignal(strategy: strategy, symbol: symbol, stockData: stockData, indicators: indicators)
        case .daily:
            return generateEMATrendSignal(strategy: strategy, symbol: symbol, stockData: stockData, indicators: indicators)
        }
    }
    
    /// RSI-MACD动量策略信号
    private func generateRSIMACDSignal(
        strategy: AdvancedStrategy,
        symbol: String,
        stockData: StockData,
        indicators: [String: Any]
    ) -> EnhancedTradingSignal? {
        
        guard let rsi = indicators["rsi"] as? Double,
              let macdSignalType = indicators["macd_signal_type"] as? TradingSignalType else {
            return nil
        }
        
        let overbought = strategy.parameters["rsi_overbought"] as? Double ?? 70
        let oversold = strategy.parameters["rsi_oversold"] as? Double ?? 30
        
        var signalType: SignalType? = nil
        var confidence: Double = 0
        var reasonComponents: [String] = []
        
        // RSI信号
        if rsi < oversold && macdSignalType == .buy {
            signalType = .buy
            confidence += 0.4
            reasonComponents.append("RSI超卖(\(String(format: "%.1f", rsi)))")
            reasonComponents.append("MACD金叉")
        } else if rsi > overbought && macdSignalType == .sell {
            signalType = .sell
            confidence += 0.4
            reasonComponents.append("RSI超买(\(String(format: "%.1f", rsi)))")
            reasonComponents.append("MACD死叉")
        }
        
        // 添加额外的确认信号
        if let macdHistogram = indicators["macd_histogram"] as? Double {
            if signalType == .buy && macdHistogram > 0 {
                confidence += 0.2
                reasonComponents.append("MACD柱状线为正")
            } else if signalType == .sell && macdHistogram < 0 {
                confidence += 0.2
                reasonComponents.append("MACD柱状线为负")
            }
        }
        
        guard let finalSignalType = signalType, confidence >= (strategy.parameters["confidence_threshold"] as? Double ?? 0.6) else {
            return nil
        }
        
        return EnhancedTradingSignal(
            id: UUID(),
            symbol: symbol,
            signalType: finalSignalType,
            confidence: confidence,
            price: stockData.lastPrice,
            strategy: strategy.name,
            timeframe: strategy.timeframe,
            timestamp: Date(),
            indicators: indicators,
            reasoning: reasonComponents.joined(separator: ", ")
        )
    }
    
    /// 布林带-KDJ策略信号
    private func generateBollingerKDJSignal(
        strategy: AdvancedStrategy,
        symbol: String,
        stockData: StockData,
        indicators: [String: Any]
    ) -> EnhancedTradingSignal? {
        
        guard let bbPosition = indicators["bb_position"] as? Double,
              let kdjSignalType = indicators["kdj_signal"] as? TradingSignalType else {
            return nil
        }
        
        var signalType: SignalType? = nil
        var confidence: Double = 0
        var reasonComponents: [String] = []
        
        // 布林带突破信号 + KDJ确认
        if bbPosition < 0.1 && kdjSignalType == .buy {
            signalType = .buy
            confidence += 0.5
            reasonComponents.append("价格接近布林带下轨")
            reasonComponents.append("KDJ买入信号")
        } else if bbPosition > 0.9 && kdjSignalType == .sell {
            signalType = .sell
            confidence += 0.5
            reasonComponents.append("价格接近布林带上轨")
            reasonComponents.append("KDJ卖出信号")
        }
        
        // KDJ金叉死叉确认
        if let kValue = indicators["kdj_k"] as? Double,
           let dValue = indicators["kdj_d"] as? Double {
            if signalType == .buy && kValue > dValue {
                confidence += 0.2
                reasonComponents.append("KDJ金叉")
            } else if signalType == .sell && kValue < dValue {
                confidence += 0.2
                reasonComponents.append("KDJ死叉")
            }
        }
        
        guard let finalSignalType = signalType, confidence >= (strategy.parameters["confidence_threshold"] as? Double ?? 0.7) else {
            return nil
        }
        
        return EnhancedTradingSignal(
            id: UUID(),
            symbol: symbol,
            signalType: finalSignalType,
            confidence: confidence,
            price: stockData.lastPrice,
            strategy: strategy.name,
            timeframe: strategy.timeframe,
            timestamp: Date(),
            indicators: indicators,
            reasoning: reasonComponents.joined(separator: ", ")
        )
    }
    
    /// 多指标综合策略信号
    private func generateMultiIndicatorSignal(
        strategy: AdvancedStrategy,
        symbol: String,
        stockData: StockData,
        indicators: [String: Any]
    ) -> EnhancedTradingSignal? {
        
        let consensusThreshold = strategy.parameters["consensus_threshold"] as? Int ?? 3
        
        var buySignals: [String] = []
        var sellSignals: [String] = []
        
        // RSI信号
        if let rsiSignal = indicators["rsi_signal"] as? TradingSignalType {
            switch rsiSignal {
            case .buy:
                buySignals.append("RSI超卖")
            case .sell:
                sellSignals.append("RSI超买")
            case .hold:
                break
            }
        }
        
        // MACD信号
        if let macdSignal = indicators["macd_signal_type"] as? TradingSignalType {
            switch macdSignal {
            case .buy:
                buySignals.append("MACD金叉")
            case .sell:
                sellSignals.append("MACD死叉")
            case .hold:
                break
            }
        }
        
        // 布林带信号
        if let bbPosition = indicators["bb_position"] as? Double {
            if bbPosition < 0.2 {
                buySignals.append("布林带超卖")
            } else if bbPosition > 0.8 {
                sellSignals.append("布林带超买")
            }
        }
        
        // CCI信号
        if let cci = indicators["cci"] as? Double {
            if cci < -100 {
                buySignals.append("CCI超卖")
            } else if cci > 100 {
                sellSignals.append("CCI超买")
            }
        }
        
        // 判断是否达到共识
        if buySignals.count >= consensusThreshold {
            return EnhancedTradingSignal(
                id: UUID(),
                symbol: symbol,
                signalType: .buy,
                confidence: Double(buySignals.count) / 4.0, // 最多4个指标
                price: stockData.lastPrice,
                strategy: strategy.name,
                timeframe: strategy.timeframe,
                timestamp: Date(),
                indicators: indicators,
                reasoning: "多指标买入共识: " + buySignals.joined(separator: ", ")
            )
        } else if sellSignals.count >= consensusThreshold {
            return EnhancedTradingSignal(
                id: UUID(),
                symbol: symbol,
                signalType: .sell,
                confidence: Double(sellSignals.count) / 4.0,
                price: stockData.lastPrice,
                strategy: strategy.name,
                timeframe: strategy.timeframe,
                timestamp: Date(),
                indicators: indicators,
                reasoning: "多指标卖出共识: " + sellSignals.joined(separator: ", ")
            )
        }
        
        return nil
    }
    
    /// EMA趋势跟踪策略信号
    private func generateEMATrendSignal(
        strategy: AdvancedStrategy,
        symbol: String,
        stockData: StockData,
        indicators: [String: Any]
    ) -> EnhancedTradingSignal? {
        
        guard let shortEMA = indicators["ema_short"] as? Double,
              let longEMA = indicators["ema_long"] as? Double,
              let rsi = indicators["rsi"] as? Double else {
            return nil
        }
        
        var signalType: SignalType? = nil
        var confidence: Double = 0
        var reasonComponents: [String] = []
        
        // EMA趋势判断
        if shortEMA > longEMA && rsi < 70 { // 上升趋势且未超买
            signalType = .buy
            confidence += 0.5
            reasonComponents.append("EMA短线上穿长线")
            reasonComponents.append("RSI未超买")
        } else if shortEMA < longEMA && rsi > 30 { // 下降趋势且未超卖
            signalType = .sell
            confidence += 0.5
            reasonComponents.append("EMA短线下穿长线")
            reasonComponents.append("RSI未超卖")
        }
        
        // MACD确认
        if let macdSignal = indicators["macd_signal_type"] as? TradingSignalType {
            if (signalType == .buy && macdSignal == .buy) || (signalType == .sell && macdSignal == .sell) {
                confidence += 0.25
                reasonComponents.append("MACD确认趋势")
            }
        }
        
        guard let finalSignalType = signalType, confidence >= (strategy.parameters["confidence_threshold"] as? Double ?? 0.75) else {
            return nil
        }
        
        return EnhancedTradingSignal(
            id: UUID(),
            symbol: symbol,
            signalType: finalSignalType,
            confidence: confidence,
            price: stockData.lastPrice,
            strategy: strategy.name,
            timeframe: strategy.timeframe,
            timestamp: Date(),
            indicators: indicators,
            reasoning: reasonComponents.joined(separator: ", ")
        )
    }
    
    /// 执行交易信号
    private func executeSignal(_ signal: EnhancedTradingSignal) async {
        // 这里应该调用TradingService来执行实际交易
        print("执行交易信号: \(signal.symbol) \(signal.signalType.rawValue) 置信度: \(signal.confidence)")
        print("理由: \(signal.reasoning)")
    }
    
    /// 更新性能指标
    private func updatePerformance() {
        // 计算策略整体表现
        let recentSignals = Array(signals.prefix(100))
        let totalSignals = recentSignals.count
        
        if totalSignals > 0 {
            let avgConfidence = recentSignals.map { $0.confidence }.reduce(0, +) / Double(totalSignals)
            performance.averageConfidence = avgConfidence
            performance.totalSignals = totalSignals
            performance.lastUpdate = Date()
        }
    }
}

// MARK: - 数据模型扩展

/// 高级策略模型
struct AdvancedStrategy: Identifiable {
    let id: UUID
    let name: String
    let type: StrategyType
    let timeframe: String
    var isEnabled: Bool
    let indicators: [TechnicalIndicatorType]
    var parameters: [String: Any]
}

/// 技术指标类型
enum TechnicalIndicatorType: String, CaseIterable {
    case sma = "SMA"
    case ema = "EMA"
    case rsi = "RSI"
    case macd = "MACD"
    case bollinger = "BOLL"
    case kdj = "KDJ"
    case cci = "CCI"
    case williamsR = "WR"
    case vwap = "VWAP"
}

/// 增强交易信号
struct EnhancedTradingSignal: Identifiable {
    let id: UUID
    let symbol: String
    let signalType: SignalType
    let confidence: Double
    let price: Double
    let strategy: String
    let timeframe: String
    let timestamp: Date
    let indicators: [String: Any]
    let reasoning: String
}

/// 策略性能
struct StrategyPerformance {
    var totalSignals: Int = 0
    var averageConfidence: Double = 0.0
    var lastUpdate: Date = Date()
}
