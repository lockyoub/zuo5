/*
 主控制面板视图
 作者: MiniMax Agent
 */

import SwiftUI
import Charts

struct DashboardView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var marketDataService: MarketDataService
    @EnvironmentObject private var tradingService: TradingService
    @EnvironmentObject private var strategyEngine: StrategyEngine
    
    @State private var selectedTimeframe: String = "1m"
    @State private var selectedSymbol: String = "000001.SZ"
    @State private var showingStockPicker: Bool = false
    
    private let timeframes = ["1s", "1m", "5m", "15m", "1h", "1d"]
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // 顶部统计卡片
                StatsCardsView()
                
                // 股票选择器
                StockSelectorView(
                    selectedSymbol: $selectedSymbol,
                    showingPicker: $showingStockPicker
                )
                
                // 价格图表
                PriceChartView(
                    symbol: selectedSymbol,
                    timeframe: selectedTimeframe
                )
                
                // 时间周期选择器
                TimeframePickerView(selectedTimeframe: $selectedTimeframe)
                
                // 实时行情面板
                RealTimeQuoteView(symbol: selectedSymbol)
                
                // 五档盘口
                OrderBookView(symbol: selectedSymbol)
                
                // 策略状态
                StrategyStatusView()
                
                // 持仓概览
                PositionOverviewView()
            }
            .padding()
        }
        .refreshable {
            await refreshData()
        }
    }
    
    private func refreshData() async {
        await marketDataService.subscribe(symbols: [selectedSymbol])
    }
}

struct StatsCardsView: View {
    @EnvironmentObject private var tradingService: TradingService
    
    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
            StatCard(
                title: "总资产",
                value: "¥1,000,000",
                change: "+2.35%",
                isPositive: true,
                icon: "yensign.circle.fill"
            )
            
            StatCard(
                title: "今日盈亏",
                value: "¥+23,500",
                change: "+2.35%",
                isPositive: true,
                icon: "chart.line.uptrend.xyaxis"
            )
            
            StatCard(
                title: "持仓市值",
                value: "¥850,000",
                change: "85%",
                isPositive: true,
                icon: "briefcase.fill"
            )
            
            StatCard(
                title: "可用资金",
                value: "¥150,000",
                change: "15%",
                isPositive: false,
                icon: "banknote.fill"
            )
        }
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let change: String
    let isPositive: Bool
    let icon: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(.blue)
                Spacer()
                Text(change)
                    .font(.caption)
                    .foregroundColor(isPositive ? .green : .red)
            }
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text(value)
                .font(.title3)
                .fontWeight(.semibold)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2)
    }
}

struct StockSelectorView: View {
    @Binding var selectedSymbol: String
    @Binding var showingPicker: Bool
    @EnvironmentObject private var marketDataService: MarketDataService
    
    var body: some View {
        Button(action: {
            showingPicker = true
        }) {
            HStack {
                VStack(alignment: .leading) {
                    Text(selectedSymbol)
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text(getStockName(selectedSymbol))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing) {
                    Text(getCurrentPrice(selectedSymbol))
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    HStack {
                        Text(getPriceChange(selectedSymbol))
                            .font(.caption)
                            .foregroundColor(getPriceChangeColor(selectedSymbol))
                        
                        Image(systemName: "chevron.down")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .shadow(radius: 2)
        }
        .foregroundColor(.primary)
        .sheet(isPresented: $showingPicker) {
            StockPickerView(selectedSymbol: $selectedSymbol)
        }
    }
    
    private func getStockName(_ symbol: String) -> String {
        return marketDataService.stockData[symbol]?.name ?? "股票名称"
    }
    
    private func getCurrentPrice(_ symbol: String) -> String {
        let price = marketDataService.stockData[symbol]?.lastPrice ?? 0.0
        return String(format: "%.2f", price)
    }
    
    private func getPriceChange(_ symbol: String) -> String {
        let change = marketDataService.stockData[symbol]?.change ?? 0.0
        let changePercent = marketDataService.stockData[symbol]?.changePercent ?? 0.0
        return String(format: "%+.2f (%+.2f%%)", change, changePercent)
    }
    
    private func getPriceChangeColor(_ symbol: String) -> Color {
        let change = marketDataService.stockData[symbol]?.change ?? 0.0
        return change >= 0 ? .red : .green  // 中国股市：红涨绿跌
    }
}

struct PriceChartView: View {
    let symbol: String
    let timeframe: String
    @EnvironmentObject private var marketDataService: MarketDataService
    
    var body: some View {
        VStack(alignment: .leading) {
            Text("价格走势")
                .font(.headline)
                .padding(.horizontal)
            
            if #available(iOS 16.0, *) {
                Chart {
                    ForEach(getChartData(), id: \.timestamp) { data in
                        LineMark(
                            x: .value("时间", data.timestamp),
                            y: .value("价格", data.price)
                        )
                        .foregroundStyle(.blue)
                    }
                }
                .frame(height: 200)
                .padding()
            } else {
                // iOS 15 兼容性处理
                Rectangle()
                    .fill(Color.blue.opacity(0.1))
                    .frame(height: 200)
                    .overlay(
                        Text("图表功能需要iOS 16+")
                            .foregroundColor(.secondary)
                    )
                    .padding()
            }
        }
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2)
    }
    
    private func getChartData() -> [ChartDataPoint] {
        // 从市场数据服务获取K线数据
        let klineData = marketDataService.getKLineData(for: symbol, timeframe: timeframe)
        return klineData.map { kline in
            ChartDataPoint(timestamp: kline.timestamp, price: kline.close)
        }
    }
}

struct ChartDataPoint {
    let timestamp: Date
    let price: Double
}

struct TimeframePickerView: View {
    @Binding var selectedTimeframe: String
    private let timeframes = ["1s", "1m", "5m", "15m", "1h", "1d"]
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(timeframes, id: \.self) { timeframe in
                    Button(action: {
                        selectedTimeframe = timeframe
                    }) {
                        Text(timeframe)
                            .font(.caption)
                            .fontWeight(selectedTimeframe == timeframe ? .semibold : .regular)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(
                                selectedTimeframe == timeframe ?
                                Color.blue : Color(.systemGray6)
                            )
                            .foregroundColor(
                                selectedTimeframe == timeframe ?
                                .white : .primary
                            )
                            .cornerRadius(20)
                    }
                }
            }
            .padding(.horizontal)
        }
    }
}

struct RealTimeQuoteView: View {
    let symbol: String
    @EnvironmentObject private var marketDataService: MarketDataService
    
    var body: some View {
        VStack(alignment: .leading) {
            Text("实时行情")
                .font(.headline)
                .padding(.horizontal)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                QuoteItem(title: "开盘", value: getOpenPrice())
                QuoteItem(title: "最高", value: getHighPrice(), valueColor: .red)
                QuoteItem(title: "最低", value: getLowPrice(), valueColor: .green)
                QuoteItem(title: "成交量", value: getVolume())
                QuoteItem(title: "成交额", value: getAmount())
                QuoteItem(title: "振幅", value: getAmplitude())
            }
            .padding()
        }
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2)
    }
    
    private func getOpenPrice() -> String {
        // 从K线数据获取开盘价
        let klineData = marketDataService.getKLineData(for: symbol, timeframe: "1d")
        let open = klineData.last?.open ?? 0.0
        return String(format: "%.2f", open)
    }
    
    private func getHighPrice() -> String {
        let klineData = marketDataService.getKLineData(for: symbol, timeframe: "1d")
        let high = klineData.last?.high ?? 0.0
        return String(format: "%.2f", high)
    }
    
    private func getLowPrice() -> String {
        let klineData = marketDataService.getKLineData(for: symbol, timeframe: "1d")
        let low = klineData.last?.low ?? 0.0
        return String(format: "%.2f", low)
    }
    
    private func getVolume() -> String {
        let volume = marketDataService.stockData[symbol]?.volume ?? 0
        return formatNumber(Double(volume))
    }
    
    private func getAmount() -> String {
        let amount = marketDataService.stockData[symbol]?.amount ?? 0.0
        return formatNumber(amount)
    }
    
    private func getAmplitude() -> String {
        let klineData = marketDataService.getKLineData(for: symbol, timeframe: "1d")
        guard let lastKline = klineData.last else { return "0.00%" }
        let amplitude = ((lastKline.high - lastKline.low) / lastKline.low) * 100
        return String(format: "%.2f%%", amplitude)
    }
    
    private func formatNumber(_ number: Double) -> String {
        if number >= 100000000 {
            return String(format: "%.2f亿", number / 100000000)
        } else if number >= 10000 {
            return String(format: "%.2f万", number / 10000)
        } else {
            return String(format: "%.0f", number)
        }
    }
}

struct QuoteItem: View {
    let title: String
    let value: String
    var valueColor: Color = .primary
    
    var body: some View {
        HStack {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(valueColor)
        }
    }
}

#Preview {
    DashboardView()
        .environmentObject(AppState())
        .environmentObject(MarketDataService())
        .environmentObject(TradingService())
        .environmentObject(StrategyEngine())
}
