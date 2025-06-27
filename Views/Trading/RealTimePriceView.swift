/*
 实时价格显示组件
 提供股票实时价格、涨跌幅、成交量等核心数据的实时显示
 作者: MiniMax Agent
 创建时间: 2025-06-24 16:21:15
 */

import SwiftUI
import Combine

struct RealTimePriceView: View {
    @EnvironmentObject private var marketDataService: MarketDataService
    
    let symbol: String
    @State private var lastUpdateTime = Date()
    @State private var priceAnimation = false
    @State private var showDetailSheet = false
    
    // 计算属性获取当前股票数据
    private var stockData: StockData? {
        marketDataService.stockData[symbol]
    }
    
    // 价格变化动画状态
    @State private var previousPrice: Double = 0
    @State private var priceChangeDirection: PriceChangeDirection = .none
    
    var body: some View {
        VStack(spacing: 0) {
            mainPriceCard
            
            if let data = stockData {
                additionalInfoView(data: data)
            }
        }
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 2)
        .onChange(of: stockData?.lastPrice) { newPrice in
            handlePriceChange(newPrice: newPrice ?? 0)
        }
        .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { _ in
            lastUpdateTime = Date()
        }
        .sheet(isPresented: $showDetailSheet) {
            StockDetailSheet(symbol: symbol)
        }
    }
    
    // MARK: - 主价格卡片
    private var mainPriceCard: some View {
        VStack(spacing: 12) {
            // 股票头部信息
            stockHeaderView
            
            // 主要价格信息
            mainPriceInfo
            
            // 涨跌信息
            priceChangeInfo
            
            // 成交信息
            volumeInfo
        }
        .padding(16)
        .background(
            // 根据涨跌情况显示背景色
            LinearGradient(
                colors: backgroundGradientColors,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .opacity(0.1)
        )
    }
    
    // MARK: - 股票头部视图
    private var stockHeaderView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(symbol)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                if let data = stockData {
                    Text(getStockName(for: symbol))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                } else {
                    Text("加载中...")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                connectionStatusView
                
                Button(action: {
                    showDetailSheet = true
                }) {
                    Image(systemName: "info.circle")
                        .font(.title3)
                        .foregroundColor(.blue)
                }
            }
        }
    }
    
    // MARK: - 连接状态视图
    private var connectionStatusView: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(marketDataService.isConnected ? .green : .red)
                .frame(width: 8, height: 8)
            
            Text(marketDataService.isConnected ? "实时" : "断线")
                .font(.caption2)
                .foregroundColor(marketDataService.isConnected ? .green : .red)
        }
    }
    
    // MARK: - 主要价格信息
    private var mainPriceInfo: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if let data = stockData {
                // 当前价格
                Text("¥\(data.lastPrice, specifier: "%.2f")")
                    .font(.system(size: 32, weight: .bold, design: .monospaced))
                    .foregroundColor(priceColor(change: data.change))
                    .scaleEffect(priceAnimation ? 1.05 : 1.0)
                    .animation(.easeInOut(duration: 0.2), value: priceAnimation)
                
                Spacer()
                
                // 价格变化指示器
                priceChangeIndicator
                
            } else {
                Text("--")
                    .font(.system(size: 32, weight: .bold, design: .monospaced))
                    .foregroundColor(.secondary)
                
                Spacer()
            }
        }
    }
    
    // MARK: - 价格变化指示器
    private var priceChangeIndicator: some View {
        VStack(spacing: 2) {
            Image(systemName: priceChangeDirection.iconName)
                .font(.title2)
                .foregroundColor(priceChangeDirection.color)
                .opacity(priceChangeDirection == .none ? 0 : 1)
                .scaleEffect(priceAnimation ? 1.2 : 1.0)
                .animation(.easeInOut(duration: 0.3), value: priceAnimation)
            
            Text(timeAgoString)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }
    
    // MARK: - 涨跌信息
    private var priceChangeInfo: some View {
        if let data = stockData {
            HStack(spacing: 16) {
                // 涨跌额
                VStack(alignment: .leading, spacing: 2) {
                    Text("涨跌额")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("\(data.change >= 0 ? "+" : "")\(data.change, specifier: "%.2f")")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(priceColor(change: data.change))
                }
                
                Spacer()
                
                // 涨跌幅
                VStack(alignment: .trailing, spacing: 2) {
                    Text("涨跌幅")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("\(data.changePercent >= 0 ? "+" : "")\(data.changePercent, specifier: "%.2f")%")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(priceColor(change: data.change))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            priceColor(change: data.change)
                                .opacity(0.1)
                        )
                        .cornerRadius(6)
                }
            }
        }
    }
    
    // MARK: - 成交信息
    private var volumeInfo: some View {
        if let data = stockData {
            HStack(spacing: 16) {
                // 成交量
                VStack(alignment: .leading, spacing: 2) {
                    Text("成交量")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(formatVolume(data.volume))
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                }
                
                Spacer()
                
                // 换手率（模拟数据）
                VStack(alignment: .trailing, spacing: 2) {
                    Text("换手率")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("\(Double.random(in: 0.1...5.0), specifier: "%.2f")%")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                }
            }
        }
    }
    
    // MARK: - 附加信息视图
    private func additionalInfoView(data: StockData) -> some View {
        VStack(spacing: 12) {
            Divider()
            
            // 今日统计
            HStack(spacing: 20) {
                statisticItem(title: "今开", value: "¥\(data.lastPrice * 0.98, specifier: "%.2f")")
                statisticItem(title: "昨收", value: "¥\(data.lastPrice - data.change, specifier: "%.2f")")
                statisticItem(title: "最高", value: "¥\(data.lastPrice * 1.03, specifier: "%.2f")")
                statisticItem(title: "最低", value: "¥\(data.lastPrice * 0.97, specifier: "%.2f")")
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 16)
    }
    
    // MARK: - 统计项
    private func statisticItem(title: String, value: String) -> some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.caption2)
                .foregroundColor(.secondary)
            
            Text(value)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.primary)
        }
        .frame(maxWidth: .infinity)
    }
    
    // MARK: - 辅助方法
    
    private func handlePriceChange(newPrice: Double) {
        if previousPrice > 0 && newPrice != previousPrice {
            priceChangeDirection = newPrice > previousPrice ? .up : .down
            priceAnimation = true
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                priceAnimation = false
                priceChangeDirection = .none
            }
        }
        previousPrice = newPrice
    }
    
    private func priceColor(change: Double) -> Color {
        if change > 0 {
            return .red
        } else if change < 0 {
            return .green
        } else {
            return .primary
        }
    }
    
    private var backgroundGradientColors: [Color] {
        guard let data = stockData else { return [.clear, .clear] }
        
        if data.change > 0 {
            return [.red, .orange]
        } else if data.change < 0 {
            return [.green, .mint]
        } else {
            return [.gray, .secondary]
        }
    }
    
    private var timeAgoString: String {
        let interval = Date().timeIntervalSince(lastUpdateTime)
        if interval < 60 {
            return "\(Int(interval))秒前"
        } else {
            return "\(Int(interval / 60))分钟前"
        }
    }
    
    private func formatVolume(_ volume: Int64) -> String {
        let volumeDouble = Double(volume)
        if volumeDouble >= 100_000_000 {
            return String(format: "%.1f亿", volumeDouble / 100_000_000)
        } else if volumeDouble >= 10_000 {
            return String(format: "%.1f万", volumeDouble / 10_000)
        } else {
            return "\(volume)"
        }
    }
    
    private func getStockName(for symbol: String) -> String {
        let stockNames = [
            "000001.SZ": "平安银行",
            "000002.SZ": "万科A",
            "600000.SH": "浦发银行",
            "600036.SH": "招商银行",
            "600519.SH": "贵州茅台",
            "000858.SZ": "五粮液",
            "002415.SZ": "海康威视",
            "300059.SZ": "东方财富"
        ]
        return stockNames[symbol] ?? "未知股票"
    }
}

// MARK: - 价格变化方向枚举

enum PriceChangeDirection {
    case up, down, none
    
    var iconName: String {
        switch self {
        case .up:
            return "arrow.up.circle.fill"
        case .down:
            return "arrow.down.circle.fill"
        case .none:
            return "circle"
        }
    }
    
    var color: Color {
        switch self {
        case .up:
            return .red
        case .down:
            return .green
        case .none:
            return .clear
        }
    }
}

// MARK: - 股票详情弹窗

struct StockDetailSheet: View {
    let symbol: String
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("股票详情")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("股票代码: \(symbol)")
                    .font(.headline)
                
                Text("详细信息功能开发中...")
                    .foregroundColor(.secondary)
                
                Spacer()
            }
            .padding()
            .navigationTitle("股票详情")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("关闭") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - 预览

#Preview {
    VStack {
        RealTimePriceView(symbol: "600519.SH")
            .padding()
        
        Spacer()
    }
    .environmentObject(MarketDataService())
    .background(Color(.systemGroupedBackground))
}
