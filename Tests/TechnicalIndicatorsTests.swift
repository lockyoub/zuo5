/*
 技术指标单元测试
 作者: MiniMax Agent
 创建日期: 2025-06-24
 
 测试所有技术指标计算的正确性
 */

import XCTest
@testable import StockTradingApp

class TechnicalIndicatorsTests: XCTestCase {
    
    // 测试数据
    let testPrices = [10.0, 11.0, 12.0, 13.0, 14.0, 15.0, 14.0, 13.0, 12.0, 11.0, 10.0, 11.0, 12.0, 13.0, 14.0]
    let testHigh = [10.5, 11.5, 12.5, 13.5, 14.5, 15.5, 14.5, 13.5, 12.5, 11.5, 10.5, 11.5, 12.5, 13.5, 14.5]
    let testLow = [9.5, 10.5, 11.5, 12.5, 13.5, 14.5, 13.5, 12.5, 11.5, 10.5, 9.5, 10.5, 11.5, 12.5, 13.5]
    let testVolume = [1000.0, 1100.0, 1200.0, 1300.0, 1400.0, 1500.0, 1400.0, 1300.0, 1200.0, 1100.0, 1000.0, 1100.0, 1200.0, 1300.0, 1400.0]
    
    override func setUpWithError() throws {
        // 测试开始前的设置
    }

    override func tearDownWithError() throws {
        // 测试结束后的清理
    }

    // MARK: - 移动平均线测试
    
    func testSMA() throws {
        let period = 3
        let result = TechnicalIndicators.SMA(data: testPrices, period: period)
        
        // 检查结果数量
        XCTAssertEqual(result.count, testPrices.count - period + 1)
        
        // 检查第一个SMA值 (10+11+12)/3 = 11
        XCTAssertEqual(result[0], 11.0, accuracy: 0.001)
        
        // 检查第二个SMA值 (11+12+13)/3 = 12
        XCTAssertEqual(result[1], 12.0, accuracy: 0.001)
        
        print("SMA测试通过 ✓")
    }
    
    func testEMA() throws {
        let period = 3
        let result = TechnicalIndicators.EMA(data: testPrices, period: period)
        
        // 检查结果数量
        XCTAssertEqual(result.count, testPrices.count - period + 1)
        
        // EMA第一个值应该等于SMA
        let firstSMA = testPrices[0..<period].reduce(0, +) / Double(period)
        XCTAssertEqual(result[0], firstSMA, accuracy: 0.001)
        
        // EMA应该比SMA更敏感
        XCTAssertGreaterThan(result.count, 0)
        
        print("EMA测试通过 ✓")
    }
    
    // MARK: - 动量指标测试
    
    func testRSI() throws {
        let result = TechnicalIndicators.RSI(data: testPrices, period: 14)
        
        // RSI值应该在0-100之间
        for rsi in result {
            XCTAssertGreaterThanOrEqual(rsi, 0.0)
            XCTAssertLessThanOrEqual(rsi, 100.0)
        }
        
        print("RSI测试通过 ✓")
    }
    
    func testMACD() throws {
        let result = TechnicalIndicators.MACD(data: testPrices)
        
        // 检查返回的三个数组都有数据
        XCTAssertGreaterThan(result.macd.count, 0)
        XCTAssertGreaterThan(result.signal.count, 0)
        XCTAssertGreaterThan(result.histogram.count, 0)
        
        // histogram = macd - signal
        if result.macd.count > 0 && result.signal.count > 0 && result.histogram.count > 0 {
            let lastIndex = result.histogram.count - 1
            let macdIndex = result.macd.count - result.histogram.count + lastIndex
            let expectedHistogram = result.macd[macdIndex] - result.signal[lastIndex]
            XCTAssertEqual(result.histogram[lastIndex], expectedHistogram, accuracy: 0.001)
        }
        
        print("MACD测试通过 ✓")
    }
    
    // MARK: - 波动性指标测试
    
    func testBollingerBands() throws {
        let result = TechnicalIndicators.BollingerBands(data: testPrices, period: 5, multiplier: 2.0)
        
        // 检查三条线的数量相等
        XCTAssertEqual(result.upper.count, result.middle.count)
        XCTAssertEqual(result.middle.count, result.lower.count)
        
        // 上轨应该大于中轨，中轨应该大于下轨
        for i in 0..<result.upper.count {
            XCTAssertGreaterThan(result.upper[i], result.middle[i])
            XCTAssertGreaterThan(result.middle[i], result.lower[i])
        }
        
        print("布林带测试通过 ✓")
    }
    
    // MARK: - 随机指标测试
    
    func testKDJ() throws {
        let result = TechnicalIndicators.KDJ(high: testHigh, low: testLow, close: testPrices, period: 9)
        
        // 检查K、D、J值都有数据
        XCTAssertGreaterThan(result.k.count, 0)
        XCTAssertGreaterThan(result.d.count, 0)
        XCTAssertGreaterThan(result.j.count, 0)
        
        // K和D值应该在0-100之间（J值可以超出这个范围）
        for k in result.k {
            XCTAssertGreaterThanOrEqual(k, 0.0)
            XCTAssertLessThanOrEqual(k, 100.0)
        }
        
        for d in result.d {
            XCTAssertGreaterThanOrEqual(d, 0.0)
            XCTAssertLessThanOrEqual(d, 100.0)
        }
        
        print("KDJ测试通过 ✓")
    }
    
    // MARK: - 成交量指标测试
    
    func testVWAP() throws {
        let result = TechnicalIndicators.VWAP(price: testPrices, volume: testVolume, period: 5)
        
        // VWAP应该有合理的数值
        XCTAssertGreaterThan(result.count, 0)
        
        for vwap in result {
            XCTAssertGreaterThan(vwap, 0.0)
        }
        
        print("VWAP测试通过 ✓")
    }
    
    // MARK: - 其他指标测试
    
    func testCCI() throws {
        let result = TechnicalIndicators.CCI(high: testHigh, low: testLow, close: testPrices, period: 10)
        
        // CCI值通常在-100到+100之间，但可以超出
        XCTAssertGreaterThan(result.count, 0)
        
        print("CCI测试通过 ✓")
    }
    
    func testWilliamsR() throws {
        let result = TechnicalIndicators.WilliamsR(high: testHigh, low: testLow, close: testPrices, period: 10)
        
        // Williams %R值应该在-100到0之间
        for wr in result {
            XCTAssertGreaterThanOrEqual(wr, -100.0)
            XCTAssertLessThanOrEqual(wr, 0.0)
        }
        
        print("Williams %R测试通过 ✓")
    }
    
    // MARK: - 信号判断测试
    
    func testRSISignal() throws {
        // 超买信号
        let overboughtSignal = TechnicalIndicators.rsiSignal(rsi: 75.0)
        XCTAssertEqual(overboughtSignal, .sell)
        
        // 超卖信号
        let oversoldSignal = TechnicalIndicators.rsiSignal(rsi: 25.0)
        XCTAssertEqual(oversoldSignal, .buy)
        
        // 中性信号
        let neutralSignal = TechnicalIndicators.rsiSignal(rsi: 50.0)
        XCTAssertEqual(neutralSignal, .hold)
        
        print("RSI信号判断测试通过 ✓")
    }
    
    func testMACDSignal() throws {
        // 金叉信号
        let goldenCrossSignal = TechnicalIndicators.macdSignal(
            macd: 1.0, signal: 0.5, prevMacd: 0.5, prevSignal: 1.0
        )
        XCTAssertEqual(goldenCrossSignal, .buy)
        
        // 死叉信号
        let deathCrossSignal = TechnicalIndicators.macdSignal(
            macd: 0.5, signal: 1.0, prevMacd: 1.0, prevSignal: 0.5
        )
        XCTAssertEqual(deathCrossSignal, .sell)
        
        print("MACD信号判断测试通过 ✓")
    }
    
    func testKDJSignal() throws {
        // 超买信号
        let overboughtSignal = TechnicalIndicators.kdjSignal(k: 85.0, d: 85.0, j: 105.0)
        XCTAssertEqual(overboughtSignal, .sell)
        
        // 超卖信号
        let oversoldSignal = TechnicalIndicators.kdjSignal(k: 15.0, d: 15.0, j: -5.0)
        XCTAssertEqual(oversoldSignal, .buy)
        
        print("KDJ信号判断测试通过 ✓")
    }
    
    // MARK: - 边界条件测试
    
    func testEmptyData() throws {
        let emptyResult = TechnicalIndicators.SMA(data: [], period: 5)
        XCTAssertEqual(emptyResult.count, 0)
        
        let invalidPeriodResult = TechnicalIndicators.SMA(data: testPrices, period: 0)
        XCTAssertEqual(invalidPeriodResult.count, 0)
        
        print("边界条件测试通过 ✓")
    }
    
    func testInsufficientData() throws {
        let shortData = [1.0, 2.0]
        let result = TechnicalIndicators.SMA(data: shortData, period: 5)
        XCTAssertEqual(result.count, 0)
        
        print("数据不足测试通过 ✓")
    }
    
    // MARK: - 性能测试
    
    func testPerformance() throws {
        // 生成大量测试数据
        let largeDataSet = (0..<10000).map { Double($0) * 0.01 + Double.random(in: -0.5...0.5) }
        
        measure {
            // 测试SMA性能
            _ = TechnicalIndicators.SMA(data: largeDataSet, period: 20)
        }
        
        measure {
            // 测试EMA性能
            _ = TechnicalIndicators.EMA(data: largeDataSet, period: 20)
        }
        
        measure {
            // 测试RSI性能
            _ = TechnicalIndicators.RSI(data: largeDataSet, period: 14)
        }
        
        print("性能测试完成 ✓")
    }
}

// MARK: - 测试辅助方法

extension TechnicalIndicatorsTests {
    
    /// 生成模拟股价数据
    /// - Parameters:
    ///   - count: 数据点数量
    ///   - startPrice: 起始价格
    ///   - volatility: 波动率
    /// - Returns: 模拟价格数组
    func generateMockPriceData(count: Int, startPrice: Double = 100.0, volatility: Double = 0.02) -> [Double] {
        var prices: [Double] = []
        var currentPrice = startPrice
        
        for _ in 0..<count {
            let change = Double.random(in: -volatility...volatility)
            currentPrice *= (1 + change)
            prices.append(currentPrice)
        }
        
        return prices
    }
    
    /// 验证数组数值的有效性
    /// - Parameters:
    ///   - array: 待验证数组
    ///   - name: 数组名称（用于错误信息）
    func validateArray(_ array: [Double], name: String) {
        for (index, value) in array.enumerated() {
            XCTAssertFalse(value.isNaN, "\(name)[\(index)] 不应该是NaN")
            XCTAssertFalse(value.isInfinite, "\(name)[\(index)] 不应该是无穷大")
        }
    }
}
