/*
 策略回测引擎
 作者: MiniMax Agent
 创建日期: 2025-06-24
 
 实现完整的策略回测功能，包括性能指标计算和报告生成
 */

import Foundation
import CoreData

/// 回测引擎类
public class BacktestEngine: ObservableObject {
    
    // MARK: - Published Properties
    @Published var isRunning: Bool = false
    @Published var progress: Double = 0.0
    @Published var currentResult: BacktestResult?
    
    // MARK: - Private Properties
    private let persistenceController = PersistenceController.shared
    
    // MARK: - 公共方法
    
    /// 运行策略回测
    /// - Parameters:
    ///   - strategy: 策略算法
    ///   - data: 历史数据
    ///   - startDate: 开始日期
    ///   - endDate: 结束日期
    ///   - initialCapital: 初始资金
    ///   - commission: 手续费率
    /// - Returns: 回测结果
    public func runBacktest(
        strategy: any TradingStrategy,
        data: [KLineEntity],
        startDate: Date,
        endDate: Date,
        initialCapital: Double = 100000.0,
        commission: Double = 0.001
    ) async -> BacktestResult {
        
        isRunning = true
        progress = 0.0
        
        let context = BacktestContext(
            strategy: strategy,
            initialCapital: initialCapital,
            commission: commission
        )
        
        let filteredData = filterDataByDateRange(data, startDate: startDate, endDate: endDate)
        let totalBars = filteredData.count
        
        var currentCapital = initialCapital
        var positions: [Position] = []
        var trades: [Trade] = []
        var dailyReturns: [DailyReturn] = []
        var portfolio: Portfolio = Portfolio(cash: currentCapital, positions: positions)
        
        // 逐个K线进行回测
        for (index, kline) in filteredData.enumerated() {
            
            // 更新进度
            await MainActor.run {
                progress = Double(index) / Double(totalBars)
            }
            
            // 准备市场数据
            let endIndex = min(index + 1, filteredData.count)
            let historicalData = Array(filteredData[0..<endIndex])
            let marketData = prepareMarketData(from: historicalData, current: kline)
            
            // 计算技术指标
            let indicators = calculateIndicators(data: historicalData, strategy: strategy)
            
            // 生成交易信号
            if let signal = strategy.generateSignal(
                data: marketData,
                indicators: indicators,
                parameters: strategy.getDefaultParameters()
            ) {
                // 执行交易
                let tradeResult = executeBacktestTrade(
                    signal: signal,
                    portfolio: &portfolio,
                    price: kline.close,
                    timestamp: kline.timestamp ?? Date(),
                    commission: commission
                )
                
                if let trade = tradeResult {
                    trades.append(trade)
                }
            }
            
            // 更新投资组合价值
            updatePortfolioValue(&portfolio, currentPrice: kline.close)
            
            // 记录每日收益
            let dailyReturn = DailyReturn(
                date: kline.timestamp ?? Date(),
                portfolioValue: portfolio.totalValue,
                cash: portfolio.cash,
                positions: portfolio.positions.count,
                dailyPnL: portfolio.totalValue - currentCapital
            )
            dailyReturns.append(dailyReturn)
            currentCapital = portfolio.totalValue
        }
        
        // 计算性能指标
        let performanceMetrics = calculatePerformanceMetrics(
            trades: trades,
            dailyReturns: dailyReturns,
            initialCapital: initialCapital
        )
        
        // 生成回测报告
        let report = generateBacktestReport(
            strategy: strategy,
            trades: trades,
            performanceMetrics: performanceMetrics,
            startDate: startDate,
            endDate: endDate
        )
        
        let result = BacktestResult(
            strategy: strategy.name,
            startDate: startDate,
            endDate: endDate,
            initialCapital: initialCapital,
            finalCapital: portfolio.totalValue,
            trades: trades,
            performanceMetrics: performanceMetrics,
            dailyReturns: dailyReturns,
            report: report
        )
        
        await MainActor.run {
            isRunning = false
            progress = 1.0
            currentResult = result
        }
        
        return result
    }
    
    /// 批量回测多个策略
    /// - Parameters:
    ///   - strategies: 策略数组
    ///   - data: 历史数据
    ///   - startDate: 开始日期
    ///   - endDate: 结束日期
    /// - Returns: 回测结果数组
    public func runBatchBacktest(
        strategies: [any TradingStrategy],
        data: [KLineEntity],
        startDate: Date,
        endDate: Date
    ) async -> [BacktestResult] {
        
        var results: [BacktestResult] = []
        
        for (index, strategy) in strategies.enumerated() {
            print("回测策略 \(index + 1)/\(strategies.count): \(strategy.name)")
            
            let result = await runBacktest(
                strategy: strategy,
                data: data,
                startDate: startDate,
                endDate: endDate
            )
            
            results.append(result)
        }
        
        return results
    }
    
    /// 计算最优参数
    /// - Parameters:
    ///   - strategy: 策略
    ///   - data: 历史数据
    ///   - parameterRanges: 参数范围
    /// - Returns: 最优参数组合
    public func optimizeParameters(
        strategy: any TradingStrategy,
        data: [KLineEntity],
        parameterRanges: [String: [Any]]
    ) async -> [String: Any] {
        
        var bestParameters = strategy.getDefaultParameters()
        var bestSharpeRatio: Double = -999.0
        
        // 简化的网格搜索（实际应用中可以使用更复杂的优化算法）
        let parameterCombinations = generateParameterCombinations(parameterRanges)
        
        for parameters in parameterCombinations.prefix(50) { // 限制组合数量避免过长时间
            // 创建临时策略副本
            var tempStrategy = strategy
            
            let result = await runBacktest(
                strategy: tempStrategy,
                data: data,
                startDate: data.first?.timestamp ?? Date(),
                endDate: data.last?.timestamp ?? Date()
            )
            
            if result.performanceMetrics.sharpeRatio > bestSharpeRatio {
                bestSharpeRatio = result.performanceMetrics.sharpeRatio
                bestParameters = parameters
            }
        }
        
        return bestParameters
    }
    
    // MARK: - 私有方法
    
    /// 按日期范围过滤数据
    private func filterDataByDateRange(_ data: [KLineEntity], startDate: Date, endDate: Date) -> [KLineEntity] {
        return data.filter { kline in
            guard let timestamp = kline.timestamp else { return false }
            return timestamp >= startDate && timestamp <= endDate
        }.sorted { ($0.timestamp ?? Date()) < ($1.timestamp ?? Date()) }
    }
    
    /// 准备市场数据
    private func prepareMarketData(from data: [KLineEntity], current: KLineEntity) -> MarketData {
        let klineData = data.map { entity in
            KLineData(
                open: entity.open,
                high: entity.high,
                low: entity.low,
                close: entity.close,
                volume: entity.volume,
                timestamp: entity.timestamp ?? Date()
            )
        }
        
        return MarketData(
            symbol: current.symbol ?? "",
            currentPrice: current.close,
            klineData: klineData,
            volume: current.volume,
            timestamp: current.timestamp ?? Date()
        )
    }
    
    /// 计算技术指标
    private func calculateIndicators(data: [KLineEntity], strategy: any TradingStrategy) -> [String: Any] {
        let closes = data.map { $0.close }
        let highs = data.map { $0.high }
        let lows = data.map { $0.low }
        let volumes = data.map { $0.volume }
        
        var indicators: [String: Any] = [:]
        
        for indicatorType in strategy.requiredIndicators {
            switch indicatorType {
            case .sma:
                let sma = TechnicalIndicators.SMA(data: closes, period: 20)
                indicators["sma"] = sma.last
                indicators["sma_array"] = sma
                
            case .ema:
                let emaShort = TechnicalIndicators.EMA(data: closes, period: 12)
                let emaLong = TechnicalIndicators.EMA(data: closes, period: 26)
                indicators["ema_short"] = emaShort.last
                indicators["ema_long"] = emaLong.last
                indicators["ema_short_array"] = emaShort
                indicators["ema_long_array"] = emaLong
                
            case .rsi:
                let rsi = TechnicalIndicators.RSI(data: closes, period: 14)
                indicators["rsi"] = rsi.last
                indicators["rsi_array"] = rsi
                
                if let currentRSI = rsi.last {
                    indicators["rsi_signal"] = TechnicalIndicators.rsiSignal(rsi: currentRSI)
                }
                
            case .macd:
                let macdResult = TechnicalIndicators.MACD(data: closes)
                indicators["macd_line"] = macdResult.macd.last
                indicators["macd_signal"] = macdResult.signal.last
                indicators["macd_histogram"] = macdResult.histogram.last
                
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
                let bb = TechnicalIndicators.BollingerBands(data: closes, period: 20, multiplier: 2.0)
                indicators["bb_upper"] = bb.upper.last
                indicators["bb_middle"] = bb.middle.last
                indicators["bb_lower"] = bb.lower.last
                
                if let upper = bb.upper.last, let lower = bb.lower.last {
                    let currentPrice = closes.last!
                    let position = (currentPrice - lower) / (upper - lower)
                    indicators["bb_position"] = position
                }
                
            case .kdj:
                let kdj = TechnicalIndicators.KDJ(high: highs, low: lows, close: closes)
                indicators["kdj_k"] = kdj.k.last
                indicators["kdj_d"] = kdj.d.last
                indicators["kdj_j"] = kdj.j.last
                
                if let k = kdj.k.last, let d = kdj.d.last, let j = kdj.j.last {
                    indicators["kdj_signal"] = TechnicalIndicators.kdjSignal(k: k, d: d, j: j)
                }
                
            case .cci:
                let cci = TechnicalIndicators.CCI(high: highs, low: lows, close: closes, period: 20)
                indicators["cci"] = cci.last
                
            case .williamsR:
                let wr = TechnicalIndicators.WilliamsR(high: highs, low: lows, close: closes, period: 14)
                indicators["williams_r"] = wr.last
                
            case .vwap:
                let typicalPrices = zip(zip(highs, lows), closes).map { TechnicalIndicators.typicalPrice(high: $0.0.0, low: $0.0.1, close: $0.1) }
                let vwap = TechnicalIndicators.VWAP(price: typicalPrices, volume: volumes, period: 20)
                indicators["vwap"] = vwap.last
            }
        }
        
        return indicators
    }
    
    /// 执行回测交易
    private func executeBacktestTrade(
        signal: StrategySignal,
        portfolio: inout Portfolio,
        price: Double,
        timestamp: Date,
        commission: Double
    ) -> Trade? {
        
        switch signal.action {
        case .buy:
            return executeBuy(portfolio: &portfolio, price: price, timestamp: timestamp, commission: commission, signal: signal)
        case .sell:
            return executeSell(portfolio: &portfolio, price: price, timestamp: timestamp, commission: commission, signal: signal)
        case .closePosition:
            return executeClosePosition(portfolio: &portfolio, price: price, timestamp: timestamp, commission: commission)
        case .hold:
            return nil
        }
    }
    
    /// 执行买入
    private func executeBuy(
        portfolio: inout Portfolio,
        price: Double,
        timestamp: Date,
        commission: Double,
        signal: StrategySignal
    ) -> Trade? {
        
        let availableCash = portfolio.cash
        let commissionCost = availableCash * commission
        let maxInvestment = availableCash - commissionCost
        
        guard maxInvestment > 0 else { return nil }
        
        // 计算可购买数量（这里简化为使用所有可用资金）
        let quantity = Int(maxInvestment / price)
        guard quantity > 0 else { return nil }
        
        let totalCost = Double(quantity) * price + commissionCost
        
        // 更新投资组合
        portfolio.cash -= totalCost
        
        let position = Position(
            symbol: "BACKTEST",
            quantity: quantity,
            avgPrice: price,
            currentPrice: price,
            timestamp: timestamp
        )
        portfolio.positions.append(position)
        
        return Trade(
            id: UUID(),
            symbol: "BACKTEST",
            action: .buy,
            quantity: quantity,
            price: price,
            timestamp: timestamp,
            commission: commissionCost,
            pnl: 0,
            strategy: signal.reasoning
        )
    }
    
    /// 执行卖出
    private func executeSell(
        portfolio: inout Portfolio,
        price: Double,
        timestamp: Date,
        commission: Double,
        signal: StrategySignal
    ) -> Trade? {
        
        guard let positionIndex = portfolio.positions.firstIndex(where: { $0.quantity > 0 }) else {
            return nil
        }
        
        let position = portfolio.positions[positionIndex]
        let quantity = position.quantity
        let saleProceeds = Double(quantity) * price
        let commissionCost = saleProceeds * commission
        let netProceeds = saleProceeds - commissionCost
        
        // 计算盈亏
        let pnl = netProceeds - (Double(quantity) * position.avgPrice)
        
        // 更新投资组合
        portfolio.cash += netProceeds
        portfolio.positions.remove(at: positionIndex)
        
        return Trade(
            id: UUID(),
            symbol: "BACKTEST",
            action: .sell,
            quantity: quantity,
            price: price,
            timestamp: timestamp,
            commission: commissionCost,
            pnl: pnl,
            strategy: signal.reasoning
        )
    }
    
    /// 执行平仓
    private func executeClosePosition(
        portfolio: inout Portfolio,
        price: Double,
        timestamp: Date,
        commission: Double
    ) -> Trade? {
        
        // 平掉所有持仓
        var totalPnL: Double = 0
        var totalCommission: Double = 0
        var totalQuantity = 0
        
        for position in portfolio.positions {
            let quantity = position.quantity
            let saleProceeds = Double(quantity) * price
            let commissionCost = saleProceeds * commission
            let netProceeds = saleProceeds - commissionCost
            let pnl = netProceeds - (Double(quantity) * position.avgPrice)
            
            portfolio.cash += netProceeds
            totalPnL += pnl
            totalCommission += commissionCost
            totalQuantity += quantity
        }
        
        portfolio.positions.removeAll()
        
        if totalQuantity > 0 {
            return Trade(
                id: UUID(),
                symbol: "BACKTEST",
                action: .sell,
                quantity: totalQuantity,
                price: price,
                timestamp: timestamp,
                commission: totalCommission,
                pnl: totalPnL,
                strategy: "平仓"
            )
        }
        
        return nil
    }
    
    /// 更新投资组合价值
    private func updatePortfolioValue(_ portfolio: inout Portfolio, currentPrice: Double) {
        for i in 0..<portfolio.positions.count {
            portfolio.positions[i].currentPrice = currentPrice
        }
        
        let positionsValue = portfolio.positions.reduce(0) { total, position in
            total + (Double(position.quantity) * position.currentPrice)
        }
        
        portfolio.totalValue = portfolio.cash + positionsValue
    }
    
    /// 计算性能指标
    public func calculatePerformanceMetrics(
        trades: [Trade],
        dailyReturns: [DailyReturn],
        initialCapital: Double
    ) -> PerformanceMetrics {
        
        // 基本指标
        let totalTrades = trades.count
        let winningTrades = trades.filter { $0.pnl > 0 }
        let losingTrades = trades.filter { $0.pnl < 0 }
        
        let winRate = totalTrades > 0 ? Double(winningTrades.count) / Double(totalTrades) : 0
        let totalPnL = trades.reduce(0) { $0 + $1.pnl }
        let totalReturn = initialCapital > 0 ? totalPnL / initialCapital : 0
        
        // 年化收益率
        let tradingDays = dailyReturns.count
        let annualizedReturn = tradingDays > 0 ? totalReturn * (252.0 / Double(tradingDays)) : 0
        
        // 最大回撤
        let maxDrawdown = calculateMaxDrawdown(dailyReturns: dailyReturns)
        
        // 夏普比率
        let sharpeRatio = calculateSharpeRatio(dailyReturns: dailyReturns)
        
        // 盈亏比
        let avgWin = winningTrades.isEmpty ? 0 : winningTrades.reduce(0) { $0 + $1.pnl } / Double(winningTrades.count)
        let avgLoss = losingTrades.isEmpty ? 0 : losingTrades.reduce(0) { $0 + $1.pnl } / Double(losingTrades.count)
        let profitFactor = avgLoss != 0 ? abs(avgWin / avgLoss) : 0
        
        // 索提诺比率
        let sortinoRatio = calculateSortinoRatio(dailyReturns: dailyReturns)
        
        // 卡玛比率
        let calmarRatio = maxDrawdown != 0 ? annualizedReturn / abs(maxDrawdown) : 0
        
        return PerformanceMetrics(
            totalReturn: totalReturn,
            annualizedReturn: annualizedReturn,
            sharpeRatio: sharpeRatio,
            sortinoRatio: sortinoRatio,
            calmarRatio: calmarRatio,
            maxDrawdown: maxDrawdown,
            winRate: winRate,
            profitFactor: profitFactor,
            totalTrades: totalTrades,
            winningTrades: winningTrades.count,
            losingTrades: losingTrades.count,
            averageWin: avgWin,
            averageLoss: avgLoss,
            largestWin: winningTrades.max(by: { $0.pnl < $1.pnl })?.pnl ?? 0,
            largestLoss: losingTrades.min(by: { $0.pnl < $1.pnl })?.pnl ?? 0,
            averageTradeLength: calculateAverageTradeLength(trades: trades),
            volatility: calculateVolatility(dailyReturns: dailyReturns)
        )
    }
    
    /// 计算最大回撤
    private func calculateMaxDrawdown(dailyReturns: [DailyReturn]) -> Double {
        guard !dailyReturns.isEmpty else { return 0 }
        
        var maxDrawdown: Double = 0
        var peak: Double = dailyReturns.first!.portfolioValue
        
        for dailyReturn in dailyReturns {
            if dailyReturn.portfolioValue > peak {
                peak = dailyReturn.portfolioValue
            }
            
            let drawdown = (peak - dailyReturn.portfolioValue) / peak
            if drawdown > maxDrawdown {
                maxDrawdown = drawdown
            }
        }
        
        return maxDrawdown
    }
    
    /// 计算夏普比率
    private func calculateSharpeRatio(dailyReturns: [DailyReturn]) -> Double {
        guard dailyReturns.count > 1 else { return 0 }
        
        let returns = calculateDailyReturnRates(dailyReturns: dailyReturns)
        let avgReturn = returns.reduce(0, +) / Double(returns.count)
        
        let variance = returns.reduce(0) { total, ret in
            total + pow(ret - avgReturn, 2)
        } / Double(returns.count - 1)
        
        let standardDeviation = sqrt(variance)
        
        // 假设无风险利率为3%年化
        let riskFreeRate = 0.03 / 252 // 日化无风险利率
        
        return standardDeviation > 0 ? (avgReturn - riskFreeRate) / standardDeviation * sqrt(252) : 0
    }
    
    /// 计算索提诺比率
    private func calculateSortinoRatio(dailyReturns: [DailyReturn]) -> Double {
        guard dailyReturns.count > 1 else { return 0 }
        
        let returns = calculateDailyReturnRates(dailyReturns: dailyReturns)
        let avgReturn = returns.reduce(0, +) / Double(returns.count)
        
        let negativeReturns = returns.filter { $0 < 0 }
        guard !negativeReturns.isEmpty else { return 0 }
        
        let downSideVariance = negativeReturns.reduce(0) { total, ret in
            total + pow(ret, 2)
        } / Double(negativeReturns.count)
        
        let downSideDeviation = sqrt(downSideVariance)
        
        let riskFreeRate = 0.03 / 252
        
        return downSideDeviation > 0 ? (avgReturn - riskFreeRate) / downSideDeviation * sqrt(252) : 0
    }
    
    /// 计算每日收益率
    private func calculateDailyReturnRates(dailyReturns: [DailyReturn]) -> [Double] {
        guard dailyReturns.count > 1 else { return [] }
        
        var returns: [Double] = []
        
        for i in 1..<dailyReturns.count {
            let prevValue = dailyReturns[i-1].portfolioValue
            let currentValue = dailyReturns[i].portfolioValue
            
            if prevValue > 0 {
                let dailyReturn = (currentValue - prevValue) / prevValue
                returns.append(dailyReturn)
            }
        }
        
        return returns
    }
    
    /// 计算平均交易天数
    private func calculateAverageTradeLength(trades: [Trade]) -> Double {
        // 这是一个简化版本，实际需要配对买卖交易来计算
        return 0
    }
    
    /// 计算波动率
    private func calculateVolatility(dailyReturns: [DailyReturn]) -> Double {
        let returns = calculateDailyReturnRates(dailyReturns: dailyReturns)
        guard returns.count > 1 else { return 0 }
        
        let avgReturn = returns.reduce(0, +) / Double(returns.count)
        let variance = returns.reduce(0) { total, ret in
            total + pow(ret - avgReturn, 2)
        } / Double(returns.count - 1)
        
        return sqrt(variance) * sqrt(252) // 年化波动率
    }
    
    /// 生成回测报告
    public func generateBacktestReport(
        strategy: any TradingStrategy,
        trades: [Trade],
        performanceMetrics: PerformanceMetrics,
        startDate: Date,
        endDate: Date
    ) -> BacktestReport {
        
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        
        var reportContent = """
        # 策略回测报告
        
        ## 基本信息
        - 策略名称: \(strategy.name)
        - 回测时间范围: \(formatter.string(from: startDate)) 至 \(formatter.string(from: endDate))
        - 交易周期: \(strategy.timeframe)
        - 总交易次数: \(performanceMetrics.totalTrades)
        
        ## 收益指标
        - 总收益率: \(String(format: "%.2f%%", performanceMetrics.totalReturn * 100))
        - 年化收益率: \(String(format: "%.2f%%", performanceMetrics.annualizedReturn * 100))
        - 最大回撤: \(String(format: "%.2f%%", performanceMetrics.maxDrawdown * 100))
        
        ## 风险指标
        - 夏普比率: \(String(format: "%.3f", performanceMetrics.sharpeRatio))
        - 索提诺比率: \(String(format: "%.3f", performanceMetrics.sortinoRatio))
        - 卡玛比率: \(String(format: "%.3f", performanceMetrics.calmarRatio))
        - 年化波动率: \(String(format: "%.2f%%", performanceMetrics.volatility * 100))
        
        ## 交易统计
        - 胜率: \(String(format: "%.2f%%", performanceMetrics.winRate * 100))
        - 盈亏比: \(String(format: "%.2f", performanceMetrics.profitFactor))
        - 盈利交易: \(performanceMetrics.winningTrades)
        - 亏损交易: \(performanceMetrics.losingTrades)
        - 平均盈利: \(String(format: "%.2f", performanceMetrics.averageWin))
        - 平均亏损: \(String(format: "%.2f", performanceMetrics.averageLoss))
        - 最大单笔盈利: \(String(format: "%.2f", performanceMetrics.largestWin))
        - 最大单笔亏损: \(String(format: "%.2f", performanceMetrics.largestLoss))
        
        ## 评级
        \(generateStrategyRating(performanceMetrics: performanceMetrics))
        
        ## 建议
        \(generateRecommendations(performanceMetrics: performanceMetrics))
        """
        
        return BacktestReport(
            strategy: strategy.name,
            startDate: startDate,
            endDate: endDate,
            content: reportContent,
            summary: generateSummary(performanceMetrics: performanceMetrics),
            rating: calculateOverallRating(performanceMetrics: performanceMetrics)
        )
    }
    
    /// 生成策略评级
    private func generateStrategyRating(performanceMetrics: PerformanceMetrics) -> String {
        let rating = calculateOverallRating(performanceMetrics: performanceMetrics)
        
        switch rating {
        case .excellent:
            return "⭐⭐⭐⭐⭐ 优秀 - 该策略表现出色，具有良好的风险收益比"
        case .good:
            return "⭐⭐⭐⭐ 良好 - 该策略表现良好，可以考虑使用"
        case .average:
            return "⭐⭐⭐ 一般 - 该策略表现平平，需要进一步优化"
        case .poor:
            return "⭐⭐ 较差 - 该策略表现不佳，不建议使用"
        case .veryPoor:
            return "⭐ 很差 - 该策略表现很差，风险较高"
        }
    }
    
    /// 生成建议
    private func generateRecommendations(performanceMetrics: PerformanceMetrics) -> String {
        var recommendations: [String] = []
        
        if performanceMetrics.sharpeRatio < 1.0 {
            recommendations.append("- 夏普比率偏低，建议优化风险控制")
        }
        
        if performanceMetrics.maxDrawdown > 0.2 {
            recommendations.append("- 最大回撤较大，建议加强止损设置")
        }
        
        if performanceMetrics.winRate < 0.4 {
            recommendations.append("- 胜率偏低，建议优化入场条件")
        }
        
        if performanceMetrics.profitFactor < 1.5 {
            recommendations.append("- 盈亏比偏低，建议优化出场策略")
        }
        
        if recommendations.isEmpty {
            recommendations.append("- 策略表现良好，可以考虑实盘应用")
        }
        
        return recommendations.joined(separator: "\n")
    }
    
    /// 生成摘要
    private func generateSummary(performanceMetrics: PerformanceMetrics) -> String {
        return "总收益率 \(String(format: "%.2f%%", performanceMetrics.totalReturn * 100))，" +
               "夏普比率 \(String(format: "%.2f", performanceMetrics.sharpeRatio))，" +
               "最大回撤 \(String(format: "%.2f%%", performanceMetrics.maxDrawdown * 100))，" +
               "胜率 \(String(format: "%.1f%%", performanceMetrics.winRate * 100))"
    }
    
    /// 计算整体评级
    private func calculateOverallRating(performanceMetrics: PerformanceMetrics) -> StrategyRating {
        var score = 0
        
        // 收益率评分
        if performanceMetrics.annualizedReturn > 0.2 { score += 2 }
        else if performanceMetrics.annualizedReturn > 0.1 { score += 1 }
        
        // 夏普比率评分
        if performanceMetrics.sharpeRatio > 2.0 { score += 2 }
        else if performanceMetrics.sharpeRatio > 1.0 { score += 1 }
        
        // 最大回撤评分
        if performanceMetrics.maxDrawdown < 0.1 { score += 2 }
        else if performanceMetrics.maxDrawdown < 0.2 { score += 1 }
        
        // 胜率评分
        if performanceMetrics.winRate > 0.6 { score += 1 }
        
        // 盈亏比评分
        if performanceMetrics.profitFactor > 2.0 { score += 1 }
        
        switch score {
        case 7...8: return .excellent
        case 5...6: return .good
        case 3...4: return .average
        case 1...2: return .poor
        default: return .veryPoor
        }
    }
    
    /// 生成参数组合
    private func generateParameterCombinations(_ parameterRanges: [String: [Any]]) -> [[String: Any]] {
        // 简化实现，实际应用中需要更复杂的组合生成算法
        var combinations: [[String: Any]] = []
        
        // 这里只是一个示例，实际需要递归生成所有组合
        for _ in 0..<10 {
            var combination: [String: Any] = [:]
            for (key, values) in parameterRanges {
                combination[key] = values.randomElement()
            }
            combinations.append(combination)
        }
        
        return combinations
    }
}

// MARK: - 数据模型

/// 回测结果
public struct BacktestResult {
    let strategy: String
    let startDate: Date
    let endDate: Date
    let initialCapital: Double
    let finalCapital: Double
    let trades: [Trade]
    let performanceMetrics: PerformanceMetrics
    let dailyReturns: [DailyReturn]
    let report: BacktestReport
}

/// 性能指标
public struct PerformanceMetrics {
    let totalReturn: Double              // 总收益率
    let annualizedReturn: Double         // 年化收益率
    let sharpeRatio: Double             // 夏普比率
    let sortinoRatio: Double            // 索提诺比率
    let calmarRatio: Double             // 卡玛比率
    let maxDrawdown: Double             // 最大回撤
    let winRate: Double                 // 胜率
    let profitFactor: Double            // 盈亏比
    let totalTrades: Int                // 总交易数
    let winningTrades: Int              // 盈利交易数
    let losingTrades: Int               // 亏损交易数
    let averageWin: Double              // 平均盈利
    let averageLoss: Double             // 平均亏损
    let largestWin: Double              // 最大盈利
    let largestLoss: Double             // 最大亏损
    let averageTradeLength: Double      // 平均持仓天数
    let volatility: Double              // 年化波动率
}

/// 回测报告
public struct BacktestReport {
    let strategy: String
    let startDate: Date
    let endDate: Date
    let content: String
    let summary: String
    let rating: StrategyRating
}

/// 策略评级
public enum StrategyRating: String, CaseIterable {
    case excellent = "优秀"
    case good = "良好"
    case average = "一般"
    case poor = "较差"
    case veryPoor = "很差"
}

/// 交易记录
public struct Trade {
    let id: UUID
    let symbol: String
    let action: SignalAction
    let quantity: Int
    let price: Double
    let timestamp: Date
    let commission: Double
    let pnl: Double
    let strategy: String
}

/// 每日收益
public struct DailyReturn {
    let date: Date
    let portfolioValue: Double
    let cash: Double
    let positions: Int
    let dailyPnL: Double
}

/// 持仓
public struct Position {
    let symbol: String
    let quantity: Int
    let avgPrice: Double
    var currentPrice: Double
    let timestamp: Date
}

/// 投资组合
public struct Portfolio {
    var cash: Double
    var positions: [Position]
    var totalValue: Double = 0
}

/// 回测上下文
private struct BacktestContext {
    let strategy: any TradingStrategy
    let initialCapital: Double
    let commission: Double
}
