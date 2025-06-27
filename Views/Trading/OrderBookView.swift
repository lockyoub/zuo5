/*
 买卖盘口界面
 显示股票的买卖五档数据，包括价格、数量和实时更新
 作者: MiniMax Agent
 创建时间: 2025-06-24 16:21:15
 */

import SwiftUI
import Combine

struct OrderBookView: View {
    @EnvironmentObject private var marketDataService: MarketDataService
    
    let symbol: String
    @State private var orderBookData: OrderBookData?
    @State private var isLoading = true
    @State private var lastUpdateTime = Date()
    @State private var animatingLevels: Set<Int> = []
    
    // 盘口配置
    private let maxLevels = 5
    private let priceFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter
    }()
    
    var body: some View {
        VStack(spacing: 0) {
            // 头部标题
            headerView
            
            if isLoading {
                loadingView
            } else {
                // 盘口数据
                orderBookContent
                
                // 底部信息
                footerView
            }
        }
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
        .onAppear {
            loadOrderBookData()
        }
        .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { _ in
            updateOrderBookData()
        }
    }
    
    // MARK: - 头部视图
    private var headerView: some View {
        VStack(spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("买卖盘口")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    Text(symbol)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(marketDataService.isConnected ? .green : .red)
                            .frame(width: 6, height: 6)
                        
                        Text(marketDataService.isConnected ? "实时" : "延迟")
                            .font(.caption2)
                            .foregroundColor(marketDataService.isConnected ? .green : .red)
                    }
                    
                    Text(formatUpdateTime())
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            
            Divider()
            
            // 列标题
            HStack {
                Text("买盘")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.green)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                Text("价格")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                    .frame(width: 80, alignment: .center)
                
                Text("卖盘")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.red)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .padding(.horizontal, 8)
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
        .padding(.bottom, 8)
    }
    
    // MARK: - 加载视图
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            
            Text("加载盘口数据...")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(height: 200)
    }
    
    // MARK: - 盘口内容
    private var orderBookContent: some View {
        VStack(spacing: 0) {
            if let data = orderBookData {
                // 卖盘（从卖5到卖1，倒序显示）
                ForEach((1...maxLevels).reversed(), id: \.self) { level in
                    let askIndex = level - 1
                    if askIndex < data.askPrices.count {
                        askOrderRow(
                            level: level,
                            price: data.askPrices[askIndex],
                            volume: data.askVolumes[askIndex],
                            isAnimating: animatingLevels.contains(level + 10) // +10 区分买卖盘
                        )
                    }
                }
                
                // 中间分隔线（显示最新价）
                middleSeparatorView
                
                // 买盘（买1到买5，正序显示）
                ForEach(1...maxLevels, id: \.self) { level in
                    let bidIndex = level - 1
                    if bidIndex < data.bidPrices.count {
                        bidOrderRow(
                            level: level,
                            price: data.bidPrices[bidIndex],
                            volume: data.bidVolumes[bidIndex],
                            isAnimating: animatingLevels.contains(level)
                        )
                    }
                }
            } else {
                emptyOrderBookView
            }
        }
        .padding(.horizontal, 16)
    }
    
    // MARK: - 卖盘行
    private func askOrderRow(level: Int, price: Double, volume: Int64, isAnimating: Bool) -> some View {
        HStack(spacing: 8) {
            // 买盘数量（空白区域）
            Text("")
                .frame(maxWidth: .infinity, alignment: .leading)
            
            // 价格（居中）
            Button(action: {
                // 点击价格可以快速设置交易价格
                selectPrice(price)
            }) {
                Text("¥\(price, specifier: "%.2f")")
                    .font(.system(.subheadline, design: .monospaced))
                    .fontWeight(.medium)
                    .foregroundColor(.red)
                    .frame(width: 80, alignment: .center)
                    .scaleEffect(isAnimating ? 1.05 : 1.0)
                    .animation(.easeInOut(duration: 0.2), value: isAnimating)
            }
            .buttonStyle(PlainButtonStyle())
            
            // 卖盘数量
            HStack(spacing: 4) {
                Text("\(formatVolume(volume))")
                    .font(.system(.subheadline, design: .monospaced))
                    .fontWeight(.medium)
                    .foregroundColor(.red)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                
                Text("卖\(level)")
                    .font(.caption2)
                    .foregroundColor(.red.opacity(0.7))
                    .frame(width: 24, alignment: .center)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Rectangle()
                .fill(Color.red.opacity(0.03))
                .opacity(isAnimating ? 0.2 : 0.05)
        )
    }
    
    // MARK: - 买盘行
    private func bidOrderRow(level: Int, price: Double, volume: Int64, isAnimating: Bool) -> some View {
        HStack(spacing: 8) {
            // 买盘数量
            HStack(spacing: 4) {
                Text("买\(level)")
                    .font(.caption2)
                    .foregroundColor(.green.opacity(0.7))
                    .frame(width: 24, alignment: .center)
                
                Text("\(formatVolume(volume))")
                    .font(.system(.subheadline, design: .monospaced))
                    .fontWeight(.medium)
                    .foregroundColor(.green)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            
            // 价格（居中）
            Button(action: {
                selectPrice(price)
            }) {
                Text("¥\(price, specifier: "%.2f")")
                    .font(.system(.subheadline, design: .monospaced))
                    .fontWeight(.medium)
                    .foregroundColor(.green)
                    .frame(width: 80, alignment: .center)
                    .scaleEffect(isAnimating ? 1.05 : 1.0)
                    .animation(.easeInOut(duration: 0.2), value: isAnimating)
            }
            .buttonStyle(PlainButtonStyle())
            
            // 卖盘数量（空白区域）
            Text("")
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Rectangle()
                .fill(Color.green.opacity(0.03))
                .opacity(isAnimating ? 0.2 : 0.05)
        )
    }
    
    // MARK: - 中间分隔线
    private var middleSeparatorView: some View {
        VStack(spacing: 4) {
            Divider()
                .background(Color.secondary)
            
            if let currentPrice = getCurrentPrice() {
                HStack {
                    Text("最新价")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text("¥\(currentPrice, specifier: "%.2f")")
                        .font(.system(.subheadline, design: .monospaced))
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Text("点击价格交易")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
            }
            
            Divider()
                .background(Color.secondary)
        }
        .padding(.vertical, 8)
    }
    
    // MARK: - 空白盘口视图
    private var emptyOrderBookView: some View {
        VStack(spacing: 16) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 40))
                .foregroundColor(.secondary)
            
            Text("暂无盘口数据")
                .font(.headline)
                .foregroundColor(.secondary)
            
            Text("数据加载中，请稍候...")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(height: 200)
    }
    
    // MARK: - 底部视图
    private var footerView: some View {
        if let data = orderBookData {
            VStack(spacing: 8) {
                Divider()
                
                HStack(spacing: 20) {
                    // 买盘总量
                    VStack(alignment: .leading, spacing: 2) {
                        Text("买盘总量")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        
                        Text(formatVolume(data.totalBidVolume))
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.green)
                    }
                    
                    Spacer()
                    
                    // 买卖比
                    VStack(spacing: 2) {
                        Text("买卖比")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        
                        let ratio = data.totalBidVolume > 0 ? Double(data.totalAskVolume) / Double(data.totalBidVolume) : 0
                        Text("\(ratio, specifier: "%.2f"):1")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                    }
                    
                    Spacer()
                    
                    // 卖盘总量
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("卖盘总量")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        
                        Text(formatVolume(data.totalAskVolume))
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.red)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            }
        }
    }
    
    // MARK: - 业务方法
    
    private func loadOrderBookData() {
        isLoading = true
        
        // 模拟网络请求延迟
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            generateMockOrderBookData()
            isLoading = false
        }
    }
    
    private func updateOrderBookData() {
        guard !isLoading else { return }
        
        // 模拟实时数据更新
        if Bool.random() {
            let randomLevel = Int.random(in: 1...5)
            animatingLevels.insert(randomLevel)
            animatingLevels.insert(randomLevel + 10) // 卖盘
            
            generateMockOrderBookData()
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                animatingLevels.removeAll()
            }
        }
        
        lastUpdateTime = Date()
    }
    
    private func generateMockOrderBookData() {
        let basePrice = 15.50 // 基础价格
        let spread = 0.01 // 买卖价差
        
        var bidPrices: [Double] = []
        var bidVolumes: [Int64] = []
        var askPrices: [Double] = []
        var askVolumes: [Int64] = []
        
        // 生成买盘数据（买1到买5）
        for i in 0..<maxLevels {
            let price = basePrice - (Double(i + 1) * spread)
            let volume = Int64.random(in: 100...50000) * 100
            bidPrices.append(price)
            bidVolumes.append(volume)
        }
        
        // 生成卖盘数据（卖1到卖5）
        for i in 0..<maxLevels {
            let price = basePrice + spread + (Double(i) * spread)
            let volume = Int64.random(in: 100...50000) * 100
            askPrices.append(price)
            askVolumes.append(volume)
        }
        
        let totalBidVolume = bidVolumes.reduce(0, +)
        let totalAskVolume = askVolumes.reduce(0, +)
        
        orderBookData = OrderBookData(
            symbol: symbol,
            bidPrices: bidPrices,
            bidVolumes: bidVolumes,
            askPrices: askPrices,
            askVolumes: askVolumes,
            totalBidVolume: totalBidVolume,
            totalAskVolume: totalAskVolume,
            timestamp: Date()
        )
    }
    
    private func selectPrice(_ price: Double) {
        // 实现价格选择逻辑，可以通过通知或回调传递给交易界面
        print("选择价格: ¥\(price)")
        
        // 可以发送通知给交易界面
        NotificationCenter.default.post(
            name: Notification.Name("SelectedTradingPrice"),
            object: nil,
            userInfo: ["price": price, "symbol": symbol]
        )
        
        // 显示反馈
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
    }
    
    private func getCurrentPrice() -> Double? {
        return marketDataService.stockData[symbol]?.lastPrice ?? orderBookData?.bidPrices.first
    }
    
    private func formatVolume(_ volume: Int64) -> String {
        let volumeDouble = Double(volume)
        if volumeDouble >= 10000 {
            return String(format: "%.1f万", volumeDouble / 10000)
        } else {
            return "\(volume / 100)手"
        }
    }
    
    private func formatUpdateTime() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: lastUpdateTime)
    }
}

// MARK: - 数据模型

struct OrderBookData {
    let symbol: String
    let bidPrices: [Double]      // 买盘价格数组（买1到买5）
    let bidVolumes: [Int64]      // 买盘数量数组
    let askPrices: [Double]      // 卖盘价格数组（卖1到卖5）
    let askVolumes: [Int64]      // 卖盘数量数组
    let totalBidVolume: Int64    // 买盘总量
    let totalAskVolume: Int64    // 卖盘总量
    let timestamp: Date          // 时间戳
}

// MARK: - 预览

#Preview {
    VStack {
        OrderBookView(symbol: "600519.SH")
            .padding()
        
        Spacer()
    }
    .environmentObject(MarketDataService())
    .background(Color(.systemGroupedBackground))
}
