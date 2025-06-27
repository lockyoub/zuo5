/*
 盘口数据显示组件
 显示五档买卖盘数据，支持实时更新
 作者: MiniMax Agent
 创建时间: 2025-06-27
 */

import SwiftUI
import Combine

// MARK: - 盘口数据视图模型
@MainActor
class OrderBookViewModel: ObservableObject {
    @Published var orderBookData: OrderBookData?
    @Published var isLoading = false
    @Published var error: String?
    @Published var lastUpdateTime: Date?
    
    private let networkService: EnhancedNetworkService
    private var cancellables = Set<AnyCancellable>()
    private var refreshTimer: Timer?
    
    init(networkService: EnhancedNetworkService) {
        self.networkService = networkService
        setupSubscriptions()
    }
    
    deinit {
        refreshTimer?.invalidate()
    }
    
    private func setupSubscriptions() {
        // 订阅实时市场数据
        networkService.marketDataPublisher
            .compactMap { $0.orderBook }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] orderBook in
                self?.orderBookData = orderBook
                self?.lastUpdateTime = Date()
                self?.error = nil
            }
            .store(in: &cancellables)
    }
    
    func loadOrderBook(for symbol: String) async {
        isLoading = true
        error = nil
        
        do {
            let data = try await networkService.getOrderBook(symbol: symbol)
            orderBookData = data
            lastUpdateTime = Date()
        } catch {
            self.error = error.localizedDescription
        }
        
        isLoading = false
    }
    
    func startAutoRefresh(for symbol: String, interval: TimeInterval = 3.0) {
        refreshTimer?.invalidate()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task {
                await self?.loadOrderBook(for: symbol)
            }
        }
    }
    
    func stopAutoRefresh() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }
}

// MARK: - 主盘口视图
struct OrderBookView: View {
    @StateObject private var viewModel: OrderBookViewModel
    @State private var selectedSymbol: String
    @State private var showingSettings = false
    @State private var autoRefreshEnabled = true
    @State private var refreshInterval: Double = 3.0
    
    init(networkService: EnhancedNetworkService, symbol: String = "000001.SZ") {
        self._viewModel = StateObject(wrappedValue: OrderBookViewModel(networkService: networkService))
        self._selectedSymbol = State(initialValue: symbol)
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // 头部信息
                headerView
                
                // 盘口数据
                if viewModel.isLoading && viewModel.orderBookData == nil {
                    loadingView
                } else if let error = viewModel.error {
                    errorView(error)
                } else if let orderBook = viewModel.orderBookData {
                    orderBookDataView(orderBook)
                } else {
                    emptyStateView
                }
                
                Spacer()
            }
            .navigationTitle("盘口数据")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingSettings = true }) {
                        Image(systemName: "gearshape")
                    }
                }
            }
            .sheet(isPresented: $showingSettings) {
                settingsView
            }
            .onAppear {
                Task {
                    await viewModel.loadOrderBook(for: selectedSymbol)
                    await viewModel.networkService.subscribeToStock(selectedSymbol)
                    
                    if autoRefreshEnabled {
                        viewModel.startAutoRefresh(for: selectedSymbol, interval: refreshInterval)
                    }
                }
            }
            .onDisappear {
                viewModel.stopAutoRefresh()
                Task {
                    await viewModel.networkService.unsubscribeFromStock(selectedSymbol)
                }
            }
        }
    }
    
    // MARK: - 头部视图
    private var headerView: some View {
        VStack(spacing: 8) {
            HStack {
                Text(selectedSymbol)
                    .font(.title2)
                    .fontWeight(.bold)
                
                Spacer()
                
                if let updateTime = viewModel.lastUpdateTime {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("最后更新")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text(updateTime, style: .time)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            // 实时状态指示器
            HStack {
                Circle()
                    .fill(viewModel.networkService.isConnected ? Color.green : Color.red)
                    .frame(width: 8, height: 8)
                
                Text(viewModel.networkService.isConnected ? "实时连接" : "连接断开")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                if viewModel.isLoading {
                    HStack(spacing: 4) {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("更新中...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding()
        .background(Color(UIColor.systemBackground))
        .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
    
    // MARK: - 盘口数据视图
    private func orderBookDataView(_ orderBook: OrderBookData) -> some View {
        VStack(spacing: 0) {
            // 表头
            orderBookHeader
            
            // 卖盘数据（从卖五到卖一）
            LazyVStack(spacing: 1) {
                ForEach(Array(zip(orderBook.askPrices.reversed(), orderBook.askVolumes.reversed()).enumerated()), id: \.offset) { index, data in
                    let (price, volume) = data
                    let level = 5 - index
                    OrderBookRowView(
                        level: "卖\(level)",
                        price: price,
                        volume: volume,
                        isBuy: false
                    )
                }
            }
            
            // 中间分隔线
            Rectangle()
                .fill(Color.gray.opacity(0.3))
                .frame(height: 2)
                .padding(.vertical, 4)
            
            // 买盘数据（从买一到买五）
            LazyVStack(spacing: 1) {
                ForEach(Array(zip(orderBook.bidPrices, orderBook.bidVolumes).enumerated()), id: \.offset) { index, data in
                    let (price, volume) = data
                    let level = index + 1
                    OrderBookRowView(
                        level: "买\(level)",
                        price: price,
                        volume: volume,
                        isBuy: true
                    )
                }
            }
            
            // 数据来源信息
            HStack {
                Spacer()
                Text("数据来源: \(orderBook.source)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .padding(.top, 8)
            }
            .padding(.horizontal)
        }
    }
    
    // MARK: - 表头
    private var orderBookHeader: some View {
        HStack {
            Text("档位")
                .font(.caption)
                .fontWeight(.medium)
                .frame(width: 50, alignment: .leading)
            
            Spacer()
            
            Text("价格")
                .font(.caption)
                .fontWeight(.medium)
                .frame(width: 80, alignment: .center)
            
            Spacer()
            
            Text("数量")
                .font(.caption)
                .fontWeight(.medium)
                .frame(width: 80, alignment: .trailing)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(UIColor.systemGray6))
    }
    
    // MARK: - 加载视图
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            Text("加载盘口数据...")
                .font(.headline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(UIColor.systemBackground))
    }
    
    // MARK: - 错误视图
    private func errorView(_ error: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
                .foregroundColor(.orange)
            
            Text("加载失败")
                .font(.headline)
            
            Text(error)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Button("重试") {
                Task {
                    await viewModel.loadOrderBook(for: selectedSymbol)
                }
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(UIColor.systemBackground))
    }
    
    // MARK: - 空状态视图
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "chart.bar.doc.horizontal")
                .font(.largeTitle)
                .foregroundColor(.gray)
            
            Text("暂无盘口数据")
                .font(.headline)
                .foregroundColor(.secondary)
            
            Button("加载数据") {
                Task {
                    await viewModel.loadOrderBook(for: selectedSymbol)
                }
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(UIColor.systemBackground))
    }
    
    // MARK: - 设置视图
    private var settingsView: some View {
        NavigationView {
            Form {
                Section("股票代码") {
                    TextField("输入股票代码", text: $selectedSymbol)
                        .textFieldStyle(.roundedBorder)
                    
                    Button("应用") {
                        viewModel.stopAutoRefresh()
                        Task {
                            await viewModel.networkService.unsubscribeFromStock(selectedSymbol)
                            await viewModel.loadOrderBook(for: selectedSymbol)
                            await viewModel.networkService.subscribeToStock(selectedSymbol)
                            
                            if autoRefreshEnabled {
                                viewModel.startAutoRefresh(for: selectedSymbol, interval: refreshInterval)
                            }
                        }
                        showingSettings = false
                    }
                    .buttonStyle(.borderedProminent)
                }
                
                Section("自动刷新") {
                    Toggle("启用自动刷新", isOn: $autoRefreshEnabled)
                        .onChange(of: autoRefreshEnabled) { enabled in
                            if enabled {
                                viewModel.startAutoRefresh(for: selectedSymbol, interval: refreshInterval)
                            } else {
                                viewModel.stopAutoRefresh()
                            }
                        }
                    
                    if autoRefreshEnabled {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("刷新间隔: \(Int(refreshInterval))秒")
                                .font(.caption)
                            
                            Slider(value: $refreshInterval, in: 1...10, step: 1)
                                .onChange(of: refreshInterval) { interval in
                                    if autoRefreshEnabled {
                                        viewModel.startAutoRefresh(for: selectedSymbol, interval: interval)
                                    }
                                }
                        }
                    }
                }
                
                Section("数据源信息") {
                    if let orderBook = viewModel.orderBookData {
                        LabeledContent("数据来源", value: orderBook.source)
                        LabeledContent("更新时间", value: orderBook.timestamp)
                    }
                }
            }
            .navigationTitle("设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        showingSettings = false
                    }
                }
            }
        }
    }
}

// MARK: - 盘口行视图
struct OrderBookRowView: View {
    let level: String
    let price: Double
    let volume: Int
    let isBuy: Bool
    
    private var levelColor: Color {
        isBuy ? .red : .green  // 中国股市：红买绿卖
    }
    
    private var backgroundColor: Color {
        isBuy ? Color.red.opacity(0.05) : Color.green.opacity(0.05)
    }
    
    var body: some View {
        HStack {
            // 档位
            Text(level)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(levelColor)
                .frame(width: 50, alignment: .leading)
            
            Spacer()
            
            // 价格
            Text(EnhancedNetworkService.formatPrice(price))
                .font(.system(.caption, design: .monospaced))
                .fontWeight(.medium)
                .foregroundColor(levelColor)
                .frame(width: 80, alignment: .center)
            
            Spacer()
            
            // 数量
            Text(formatVolume(volume))
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(.primary)
                .frame(width: 80, alignment: .trailing)
        }
        .padding(.horizontal)
        .padding(.vertical, 6)
        .background(backgroundColor)
        .animation(.easeInOut(duration: 0.3), value: price)
        .animation(.easeInOut(duration: 0.3), value: volume)
    }
    
    private func formatVolume(_ volume: Int) -> String {
        if volume >= 10000 {
            return String(format: "%.1f万", Double(volume) / 10000.0)
        } else if volume >= 1000 {
            return String(format: "%.1fK", Double(volume) / 1000.0)
        } else {
            return "\(volume)"
        }
    }
}

// MARK: - 预览
struct OrderBookView_Previews: PreviewProvider {
    static var previews: some View {
        // 创建模拟网络服务
        let mockNetworkService = EnhancedNetworkService()
        
        OrderBookView(networkService: mockNetworkService, symbol: "000001.SZ")
            .preferredColorScheme(.light)
        
        OrderBookView(networkService: mockNetworkService, symbol: "000001.SZ")
            .preferredColorScheme(.dark)
    }
}

// MARK: - 使用示例

/*
// 在主视图中集成盘口数据
struct TradingView: View {
    @StateObject private var networkService = EnhancedNetworkService()
    @State private var selectedSymbol = "000001.SZ"
    
    var body: some View {
        TabView {
            // 行情页面
            StockQuoteView(networkService: networkService, symbol: selectedSymbol)
                .tabItem {
                    Label("行情", systemImage: "chart.line.uptrend.xyaxis")
                }
            
            // 盘口页面
            OrderBookView(networkService: networkService, symbol: selectedSymbol)
                .tabItem {
                    Label("盘口", systemImage: "chart.bar.doc.horizontal")
                }
            
            // K线页面
            KLineChartView(networkService: networkService, symbol: selectedSymbol)
                .tabItem {
                    Label("K线", systemImage: "chart.bar")
                }
        }
        .onAppear {
            networkService.connectWebSocket()
        }
    }
}
*/
