/*
 交易操作视图 - 完整交易界面
 集成所有交易相关组件，提供完整的交易体验
 作者: MiniMax Agent
 更新时间: 2025-06-24 16:21:15
 */

import SwiftUI

struct TradingView: View {
    @EnvironmentObject private var tradingService: TradingService
    @EnvironmentObject private var marketDataService: MarketDataService
    @EnvironmentObject private var riskManager: RiskManager
    
    @State private var selectedSymbol = "600519.SH"
    @State private var showStockPicker = false
    @State private var showOrderHistory = false
    @State private var showPositions = false
    @State private var showStopLossSettings = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 16) {
                    // 顶部工具栏
                    topToolbar
                    
                    // 实时价格显示
                    RealTimePriceView(symbol: selectedSymbol)
                        .padding(.horizontal)
                    
                    // 买卖盘口和快速交易面板
                    HStack(spacing: 12) {
                        // 盘口数据（左侧）
                        OrderBookView(symbol: selectedSymbol)
                            .frame(maxWidth: .infinity)
                        
                        // 快速交易面板（右侧）
                        QuickTradingPanel(symbol: selectedSymbol)
                            .frame(maxWidth: .infinity)
                    }
                    .padding(.horizontal)
                    
                    // 底部功能按钮
                    bottomActionButtons
                }
                .padding(.vertical)
            }
            .navigationTitle("股票交易")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        showStockPicker = true
                    }) {
                        HStack(spacing: 4) {
                            Text(selectedSymbol)
                                .fontWeight(.medium)
                            Image(systemName: "chevron.down")
                                .font(.caption)
                        }
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button(action: {
                            showOrderHistory = true
                        }) {
                            Label("交易记录", systemImage: "list.bullet")
                        }
                        
                        Button(action: {
                            showPositions = true
                        }) {
                            Label("我的持仓", systemImage: "chart.pie")
                        }
                        
                        Button(action: {
                            showStopLossSettings = true
                        }) {
                            Label("止损设置", systemImage: "shield")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .sheet(isPresented: $showStockPicker) {
                StockSearchView { symbol in
                    selectedSymbol = symbol
                }
            }
            .sheet(isPresented: $showOrderHistory) {
                OrderHistoryView()
            }
            .sheet(isPresented: $showPositions) {
                PositionsView()
            }
            .sheet(isPresented: $showStopLossSettings) {
                StopLossSettingsView(
                    symbol: selectedSymbol,
                    currentPrice: getCurrentPrice(),
                    position: getCurrentPosition()
                )
            }
        }
    }
    
    // MARK: - 顶部工具栏
    private var topToolbar: some View {
        HStack {
            Button(action: {
                showStockPicker = true
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                    Text("搜索股票")
                }
                .foregroundColor(.blue)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.blue.opacity(0.1))
                .cornerRadius(8)
            }
            
            Spacer()
            
            HStack(spacing: 12) {
                Button(action: {
                    showPositions = true
                }) {
                    VStack(spacing: 2) {
                        Image(systemName: "chart.pie.fill")
                            .font(.title3)
                        Text("持仓")
                            .font(.caption2)
                    }
                    .foregroundColor(.blue)
                }
                
                Button(action: {
                    showOrderHistory = true
                }) {
                    VStack(spacing: 2) {
                        Image(systemName: "list.bullet")
                            .font(.title3)
                        Text("记录")
                            .font(.caption2)
                    }
                    .foregroundColor(.blue)
                }
            }
        }
        .padding(.horizontal)
    }
    
    // MARK: - 底部操作按钮
    private var bottomActionButtons: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                Button(action: {
                    showStopLossSettings = true
                }) {
                    Label("止损设置", systemImage: "shield")
                        .foregroundColor(.orange)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.orange.opacity(0.1))
                        .cornerRadius(10)
                }
                
                Button(action: {
                    // 添加自选
                    addToWatchlist()
                }) {
                    Label("加自选", systemImage: "star")
                        .foregroundColor(.yellow)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.yellow.opacity(0.1))
                        .cornerRadius(10)
                }
            }
            
            // 分享和设置按钮
            HStack(spacing: 12) {
                Button(action: {
                    shareStock()
                }) {
                    Label("分享", systemImage: "square.and.arrow.up")
                        .foregroundColor(.gray)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(10)
                }
                
                Button(action: {
                    // 更多设置
                    showMoreSettings()
                }) {
                    Label("设置", systemImage: "gearshape")
                        .foregroundColor(.gray)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(10)
                }
            }
        }
        .padding(.horizontal)
    }
    
    // MARK: - 辅助方法
    
    private func getCurrentPrice() -> Double {
        return marketDataService.stockData[selectedSymbol]?.lastPrice ?? 0.0
    }
    
    private func getCurrentPosition() -> PositionRecord? {
        // 这里应该从实际的持仓服务获取数据
        // 暂时返回模拟数据
        return PositionRecord(
            symbol: selectedSymbol,
            stockName: getStockName(for: selectedSymbol),
            quantity: 100,
            availableQuantity: 100,
            avgCost: getCurrentPrice() * 0.98,
            currentPrice: getCurrentPrice(),
            lastUpdateTime: Date()
        )
    }
    
    private func getStockName(for symbol: String) -> String {
        let stockNames = [
            "600519.SH": "贵州茅台",
            "000001.SZ": "平安银行",
            "600036.SH": "招商银行",
            "000002.SZ": "万科A",
            "002415.SZ": "海康威视"
        ]
        return stockNames[symbol] ?? "未知股票"
    }
    
    private func addToWatchlist() {
        print("添加 \(selectedSymbol) 到自选股")
        // 实现添加自选股逻辑
    }
    
    private func shareStock() {
        print("分享股票 \(selectedSymbol)")
        // 实现分享功能
    }
    
    private func showMoreSettings() {
        print("显示更多设置")
        // 实现更多设置
    }
}

struct StrategyView: View {
    @State private var strategies: [StrategyInfo] = []
    @State private var selectedStrategy: StrategyInfo?
    @State private var showStrategyDetail = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 16) {
                    // 策略概览卡片
                    strategyOverviewCard
                    
                    // 策略列表
                    strategyListView
                }
                .padding()
            }
            .navigationTitle("策略管理")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        // 添加新策略
                    }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showStrategyDetail) {
                if let strategy = selectedStrategy {
                    StrategyDetailView(strategy: strategy)
                }
            }
            .onAppear {
                loadStrategies()
            }
        }
    }
    
    private var strategyOverviewCard: some View {
        VStack(spacing: 12) {
            HStack {
                Text("策略总览")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Button("刷新") {
                    loadStrategies()
                }
                .font(.caption)
                .foregroundColor(.blue)
            }
            
            HStack(spacing: 20) {
                strategyStatItem(title: "运行中", value: "3", color: .green)
                strategyStatItem(title: "已暂停", value: "1", color: .orange)
                strategyStatItem(title: "总收益", value: "+12.3%", color: .red)
                strategyStatItem(title: "今日信号", value: "5", color: .blue)
            }
        }
        .padding(16)
        .background(Color(.systemGray6).opacity(0.5))
        .cornerRadius(12)
    }
    
    private func strategyStatItem(title: String, value: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(color)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
    
    private var strategyListView: some View {
        LazyVStack(spacing: 8) {
            ForEach(strategies, id: \.id) { strategy in
                StrategyRowView(strategy: strategy)
                    .onTapGesture {
                        selectedStrategy = strategy
                        showStrategyDetail = true
                    }
            }
        }
    }
    
    private func loadStrategies() {
        strategies = [
            StrategyInfo(id: "1", name: "双EMA策略", type: "趋势跟踪", status: .running, profit: 8.5),
            StrategyInfo(id: "2", name: "RSI背离策略", type: "反转策略", status: .running, profit: -2.1),
            StrategyInfo(id: "3", name: "布林带突破", type: "突破策略", status: .paused, profit: 15.3),
            StrategyInfo(id: "4", name: "MACD金叉", type: "趋势策略", status: .running, profit: 5.7)
        ]
    }
}

struct StrategyRowView: View {
    let strategy: StrategyInfo
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(strategy.name)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text(strategy.type)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text("\(strategy.profit >= 0 ? "+" : "")\(strategy.profit, specifier: "%.1f")%")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(strategy.profit >= 0 ? .red : .green)
                
                Text(strategy.status.displayName)
                    .font(.caption)
                    .foregroundColor(strategy.status.color)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(strategy.status.color.opacity(0.1))
                    .cornerRadius(4)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
}

struct StrategyDetailView: View {
    let strategy: StrategyInfo
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack {
                Text("策略详情")
                    .font(.title2)
                    .fontWeight(.bold)
                    .padding()
                
                Text("策略名称: \(strategy.name)")
                    .font(.headline)
                    .padding()
                
                Text("详细策略配置和性能分析功能开发中...")
                    .foregroundColor(.secondary)
                    .padding()
                
                Spacer()
            }
            .navigationTitle("策略详情")
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

struct StrategyInfo {
    let id: String
    let name: String
    let type: String
    let status: StrategyStatus
    let profit: Double
}

enum StrategyStatus {
    case running, paused, stopped
    
    var displayName: String {
        switch self {
        case .running: return "运行中"
        case .paused: return "已暂停"
        case .stopped: return "已停止"
        }
    }
    
    var color: Color {
        switch self {
        case .running: return .green
        case .paused: return .orange
        case .stopped: return .red
        }
    }
}

struct PositionView: View {
    @EnvironmentObject private var tradingService: TradingService
    @EnvironmentObject private var marketDataService: MarketDataService
    
    var body: some View {
        // 直接使用新创建的PositionsView组件
        PositionsView()
    }
}

struct SettingsView: View {
    @State private var isNotificationEnabled = true
    @State private var isAutoTradeEnabled = false
    @State private var riskLevel = 1
    @State private var refreshInterval = 1
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("交易设置")) {
                    Toggle("启用自动交易", isOn: $isAutoTradeEnabled)
                    
                    Picker("风险等级", selection: $riskLevel) {
                        Text("保守").tag(0)
                        Text("稳健").tag(1)
                        Text("激进").tag(2)
                    }
                    
                    Picker("刷新频率", selection: $refreshInterval) {
                        Text("1秒").tag(1)
                        Text("3秒").tag(3)
                        Text("5秒").tag(5)
                    }
                }
                
                Section(header: Text("通知设置")) {
                    Toggle("推送通知", isOn: $isNotificationEnabled)
                    
                    NavigationLink("通知偏好设置") {
                        NotificationPreferencesView()
                    }
                }
                
                Section(header: Text("账户设置")) {
                    NavigationLink("账户信息") {
                        AccountInfoView()
                    }
                    
                    NavigationLink("安全设置") {
                        SecuritySettingsView()
                    }
                    
                    NavigationLink("数据同步") {
                        DataSyncView()
                    }
                }
                
                Section(header: Text("关于")) {
                    HStack {
                        Text("版本")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.secondary)
                    }
                    
                    NavigationLink("帮助中心") {
                        HelpCenterView()
                    }
                    
                    NavigationLink("联系我们") {
                        ContactView()
                    }
                }
                
                Section {
                    Button("退出登录") {
                        // 退出登录逻辑
                    }
                    .foregroundColor(.red)
                }
            }
            .navigationTitle("系统设置")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

// MARK: - 设置子页面视图

struct NotificationPreferencesView: View {
    var body: some View {
        Form {
            Text("通知偏好设置页面开发中...")
                .foregroundColor(.secondary)
        }
        .navigationTitle("通知偏好")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct AccountInfoView: View {
    var body: some View {
        Form {
            Text("账户信息页面开发中...")
                .foregroundColor(.secondary)
        }
        .navigationTitle("账户信息")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct SecuritySettingsView: View {
    var body: some View {
        Form {
            Text("安全设置页面开发中...")
                .foregroundColor(.secondary)
        }
        .navigationTitle("安全设置")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct DataSyncView: View {
    var body: some View {
        Form {
            Text("数据同步页面开发中...")
                .foregroundColor(.secondary)
        }
        .navigationTitle("数据同步")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct HelpCenterView: View {
    var body: some View {
        Form {
            Text("帮助中心页面开发中...")
                .foregroundColor(.secondary)
        }
        .navigationTitle("帮助中心")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct ContactView: View {
    var body: some View {
        Form {
            Text("联系我们页面开发中...")
                .foregroundColor(.secondary)
        }
        .navigationTitle("联系我们")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// 旧的重复组件已移除，使用新创建的专门组件

#Preview {
    TradingView()
        .environmentObject(TradingService())
        .environmentObject(MarketDataService())
}
