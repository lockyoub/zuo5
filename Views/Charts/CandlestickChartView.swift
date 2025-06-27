//
//  CandlestickChartView.swift
//  StockTradingApp
//
//  Created by MiniMax Agent on 2025-06-24.
//  专业级K线图表组件 - 支持多时间周期和实时数据更新
//

import SwiftUI
import Charts

/// K线图表视图 - 核心图表组件
struct CandlestickChartView: View {
    @StateObject private var chartData = ChartDataManager()
    @State private var selectedTimeframe: TimeFrame = .minute5
    @State private var isLoading = false
    @State private var selectedPrice: Double?
    @State private var selectedDate: Date?
    
    var stockCode: String
    var onPriceSelected: ((Double, Date) -> Void)?
    
    var body: some View {
        VStack(spacing: 0) {
            // 时间周期选择器
            timeframeSelector
            
            // 主图表容器
            chartContainer
            
            // 图表控制工具栏
            chartToolbar
        }
        .background(Color.black)
        .onAppear {
            loadChartData()
        }
        .onChange(of: selectedTimeframe) { _ in
            loadChartData()
        }
    }
    
    // MARK: - 时间周期选择器
    private var timeframeSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(TimeFrame.allCases, id: \.self) { timeframe in
                    TimeframeButton(
                        timeframe: timeframe,
                        isSelected: selectedTimeframe == timeframe
                    ) {
                        selectedTimeframe = timeframe
                    }
                }
            }
            .padding(.horizontal, 16)
        }
        .frame(height: 44)
        .background(Color.gray.opacity(0.1))
    }
    
    // MARK: - 图表容器
    private var chartContainer: some View {
        ZStack {
            if isLoading {
                ProgressView("加载中...")
                    .foregroundColor(.white)
            } else {
                Chart(chartData.candlestickData) { data in
                    // K线蜡烛图
                    RectangleMark(
                        x: .value("时间", data.timestamp),
                        yStart: .value("最低", data.low),
                        yEnd: .value("最高", data.high),
                        width: .fixed(1)
                    )
                    .foregroundStyle(data.close >= data.open ? .green : .red)
                    
                    // 实体部分
                    RectangleMark(
                        x: .value("时间", data.timestamp),
                        yStart: .value("开盘", data.open),
                        yEnd: .value("收盘", data.close),
                        width: .fixed(8)
                    )
                    .foregroundStyle(data.close >= data.open ? .green : .red)
                }
                .chartBackground { proxy in
                    // 选中价格线
                    if let selectedPrice = selectedPrice {
                        Rectangle()
                            .fill(Color.blue.opacity(0.3))
                            .frame(height: 1)
                            .position(
                                x: proxy.plotAreaSize.width / 2,
                                y: proxy.position(forY: selectedPrice) ?? 0
                            )
                    }
                }
                .chartAngleSelection(value: .constant(nil))
                .chartXAxis {
                    AxisMarks(values: .stride(by: .hour, count: 4)) { value in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                            .foregroundStyle(.gray.opacity(0.3))
                        AxisValueLabel {
                            if let date = value.as(Date.self) {
                                Text(DateFormatter.timeFormatter.string(from: date))
                                    .foregroundColor(.white)
                                    .font(.caption2)
                            }
                        }
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .trailing) { value in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                            .foregroundStyle(.gray.opacity(0.3))
                        AxisValueLabel {
                            if let price = value.as(Double.self) {
                                Text(String(format: "%.2f", price))
                                    .foregroundColor(.white)
                                    .font(.caption2)
                            }
                        }
                    }
                }
                .frame(height: 300)
                .padding(.horizontal, 16)
                .onTapGesture { location in
                    handleChartTap(at: location)
                }
            }
        }
    }
    
    // MARK: - 图表工具栏
    private var chartToolbar: some View {
        HStack {
            // 缩放控制
            Button(action: zoomIn) {
                Image(systemName: "plus.magnifyingglass")
                    .foregroundColor(.white)
            }
            
            Button(action: zoomOut) {
                Image(systemName: "minus.magnifyingglass")
                    .foregroundColor(.white)
            }
            
            Spacer()
            
            // 指标控制
            Menu {
                Button("移动平均线") { toggleIndicator(.ma) }
                Button("MACD") { toggleIndicator(.macd) }
                Button("RSI") { toggleIndicator(.rsi) }
                Button("布林带") { toggleIndicator(.bollinger) }
            } label: {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .foregroundColor(.white)
            }
            
            Spacer()
            
            // 刷新数据
            Button(action: loadChartData) {
                Image(systemName: "arrow.clockwise")
                    .foregroundColor(.white)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color.gray.opacity(0.1))
    }
    
    // MARK: - 方法实现
    private func loadChartData() {
        isLoading = true
        
        Task {
            await chartData.loadCandlestickData(
                stockCode: stockCode,
                timeframe: selectedTimeframe
            )
            
            await MainActor.run {
                isLoading = false
            }
        }
    }
    
    private func handleChartTap(at location: CGPoint) {
        // 实现图表点击处理逻辑
        // 计算选中的价格和时间
    }
    
    private func zoomIn() {
        chartData.zoomIn()
    }
    
    private func zoomOut() {
        chartData.zoomOut()
    }
    
    private func toggleIndicator(_ indicator: TechnicalIndicatorType) {
        chartData.toggleIndicator(indicator)
    }
}

// MARK: - 时间周期选择按钮
struct TimeframeButton: View {
    let timeframe: TimeFrame
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(timeframe.displayName)
                .font(.caption)
                .foregroundColor(isSelected ? .black : .white)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? Color.white : Color.clear)
                .cornerRadius(4)
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(Color.white, lineWidth: 1)
                )
        }
    }
}

// MARK: - 支持数据类型
enum TimeFrame: CaseIterable {
    case minute1, minute5, minute15, minute30
    case hour1, hour4, day1, week1, month1
    
    var displayName: String {
        switch self {
        case .minute1: return "1分"
        case .minute5: return "5分"
        case .minute15: return "15分"
        case .minute30: return "30分"
        case .hour1: return "1小时"
        case .hour4: return "4小时"
        case .day1: return "日线"
        case .week1: return "周线"
        case .month1: return "月线"
        }
    }
    
    var minutes: Int {
        switch self {
        case .minute1: return 1
        case .minute5: return 5
        case .minute15: return 15
        case .minute30: return 30
        case .hour1: return 60
        case .hour4: return 240
        case .day1: return 1440
        case .week1: return 10080
        case .month1: return 43200
        }
    }
}

enum TechnicalIndicatorType {
    case ma, ema, macd, rsi, bollinger, kdj
}

// MARK: - 日期格式化器扩展
extension DateFormatter {
    static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter
    }()
}

// MARK: - 预览
struct CandlestickChartView_Previews: PreviewProvider {
    static var previews: some View {
        CandlestickChartView(stockCode: "000001") { price, date in
            print("选中价格: \(price), 时间: \(date)")
        }
        .preferredColorScheme(.dark)
    }
}
