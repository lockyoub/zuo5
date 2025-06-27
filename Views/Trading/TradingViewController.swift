/*
 交易操作主界面
 作者: MiniMax Agent
 创建日期: 2025-06-24
 
 集成所有交易功能的主控制器界面
 */

import SwiftUI
import Combine

struct TradingViewController: View {
    @StateObject private var tradingService = EnhancedTradingService()
    @StateObject private var riskManager = RiskManager()
    @StateObject private var marketDataService = MarketDataService()
    @StateObject private var riskMonitor = RealTimeRiskMonitor()
    
    @State private var selectedStock: StockData?
    @State private var showingQuickTradePanel = false
    @State private var showingOrderHistory = false
    @State private var showingStopLossSettings = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // 顶部工具栏
                tradingToolbar
                
                // 主要内容区域
                ScrollView {
                    VStack(spacing: 16) {
                        // 股票搜索区域
                        stockSearchSection
                        
                        // 选中股票信息
                        if let stock = selectedStock {
                            selectedStockSection(stock)
                        }
                        
                        // 买卖盘口
                        if selectedStock != nil {
                            orderBookSection
                        }
                        
                        // 快速交易按钮
                        quickTradingButtons
                        
                        // 账户概览
                        accountOverviewSection
                        
                        // 持仓概览
                        positionsOverviewSection
                    }
                    .padding(.horizontal, 16)
                }
                
                // 底部导航栏
                tradingBottomBar
            }
            .navigationTitle("交易")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                setupTradingEnvironment()
            }
        }
        .sheet(isPresented: $showingQuickTradePanel) {
            QuickTradingPanel(
                selectedStock: selectedStock,
                tradingService: tradingService,
                riskManager: riskManager
            )
        }
        .sheet(isPresented: $showingOrderHistory) {
            OrderHistoryView(tradingService: tradingService)
        }
        .sheet(isPresented: $showingStopLossSettings) {
            StopLossSettingsView(
                selectedStock: selectedStock,
                riskManager: riskManager
            )
        }
    }
    
    // MARK: - 顶部工具栏
    
    private var tradingToolbar: some View {
        HStack {
            // 连接状态
            connectionStatusView
            
            Spacer()
            
            // 风险状态
            riskStatusView
            
            Spacer()
            
            // 设置按钮
            Button(action: {
                // 打开设置
            }) {
                Image(systemName: "gearshape.fill")
                    .foregroundColor(.blue)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color(.systemGray6))
    }
    
    private var connectionStatusView: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(tradingService.isConnected ? .green : .red)
                .frame(width: 8, height: 8)
            
            Text(tradingService.isConnected ? "已连接" : "未连接")
                .font(.caption)
                .foregroundColor(tradingService.isConnected ? .green : .red)
        }
    }
    
    private var riskStatusView: some View {
        HStack(spacing: 4) {
            Image(systemName: "shield.fill")
                .foregroundColor(riskColorForLevel(riskManager.accountRiskLevel))
            
            Text(riskManager.accountRiskLevel.description)
                .font(.caption)
                .foregroundColor(riskColorForLevel(riskManager.accountRiskLevel))
        }
    }
    
    // MARK: - 股票搜索区域
    
    private var stockSearchSection: some View {
        VStack(spacing: 12) {
            HStack {
                Text("股票搜索")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
            }
            
            StockSearchView(
                marketDataService: marketDataService,
                onStockSelected: { stock in
                    selectedStock = stock
                }
            )
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2)
    }
    
    // MARK: - 选中股票信息
    
    private func selectedStockSection(_ stock: StockData) -> some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(stock.symbol)
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text(stock.name)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("¥\(String(format: "%.2f", stock.lastPrice))")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(priceColor(for: stock.change))
                    
                    HStack(spacing: 4) {
                        Text(stock.change >= 0 ? "+" : "")
                        Text(String(format: "%.2f", stock.change))
                        Text("(\(String(format: "%.2f", stock.changePercent))%)")
                    }
                    .font(.caption)
                    .foregroundColor(priceColor(for: stock.change))
                }
            }
            
            // 股票详细信息
            RealTimePriceView(stock: stock)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2)
    }
    
    // MARK: - 买卖盘口
    
    private var orderBookSection: some View {
        VStack(spacing: 12) {
            HStack {
                Text("买卖盘口")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Button("刷新") {
                    // 刷新盘口数据
                    refreshOrderBook()
                }
                .font(.caption)
                .foregroundColor(.blue)
            }
            
            if let stock = selectedStock {
                OrderBookView(stock: stock)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2)
    }
    
    // MARK: - 快速交易按钮
    
    private var quickTradingButtons: some View {
        HStack(spacing: 16) {
            // 买入按钮
            Button(action: {
                showingQuickTradePanel = true
            }) {
                VStack(spacing: 8) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title2)
                    Text("买入")
                        .font(.caption)
                        .fontWeight(.medium)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(.green)
                .cornerRadius(12)
            }
            
            // 卖出按钮
            Button(action: {
                showingQuickTradePanel = true
            }) {
                VStack(spacing: 8) {
                    Image(systemName: "arrow.down.circle.fill")
                        .font(.title2)
                    Text("卖出")
                        .font(.caption)
                        .fontWeight(.medium)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(.red)
                .cornerRadius(12)
            }
            
            // 止损设置
            Button(action: {
                showingStopLossSettings = true
            }) {
                VStack(spacing: 8) {
                    Image(systemName: "shield.fill")
                        .font(.title2)
                    Text("止损")
                        .font(.caption)
                        .fontWeight(.medium)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(.orange)
                .cornerRadius(12)
            }
        }
        .disabled(selectedStock == nil)
    }
    
    // MARK: - 账户概览
    
    private var accountOverviewSection: some View {
        VStack(spacing: 12) {
            HStack {
                Text("账户概览")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Button("详情") {
                    // 显示账户详情
                }
                .font(.caption)
                .foregroundColor(.blue)
            }
            
            AccountOverviewCard(accountInfo: tradingService.accountInfo)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2)
    }
    
    // MARK: - 持仓概览
    
    private var positionsOverviewSection: some View {
        VStack(spacing: 12) {
            HStack {
                Text("持仓概览")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Button("查看全部") {
                    // 显示所有持仓
                }
                .font(.caption)
                .foregroundColor(.blue)
            }
            
            PositionsOverviewCard()
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2)
    }
    
    // MARK: - 底部导航栏
    
    private var tradingBottomBar: some View {
        HStack(spacing: 20) {
            // 订单历史
            Button(action: {
                showingOrderHistory = true
            }) {
                VStack(spacing: 4) {
                    Image(systemName: "doc.text")
                        .font(.title3)
                    Text("订单")
                        .font(.caption)
                }
                .foregroundColor(.blue)
            }
            
            Spacer()
            
            // 风险监控
            Button(action: {
                // 显示风险监控详情
            }) {
                VStack(spacing: 4) {
                    Image(systemName: "shield.checkered")
                        .font(.title3)
                    Text("风控")
                        .font(.caption)
                }
                .foregroundColor(.orange)
            }
            
            Spacer()
            
            // 策略管理
            Button(action: {
                // 显示策略管理
            }) {
                VStack(spacing: 4) {
                    Image(systemName: "brain.head.profile")
                        .font(.title3)
                    Text("策略")
                        .font(.caption)
                }
                .foregroundColor(.purple)
            }
            
            Spacer()
            
            // 分析工具
            Button(action: {
                // 显示分析工具
            }) {
                VStack(spacing: 4) {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.title3)
                    Text("分析")
                        .font(.caption)
                }
                .foregroundColor(.green)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(Color(.systemGray6))
    }
    
    // MARK: - 私有方法
    
    private func setupTradingEnvironment() {
        // 设置服务依赖关系
        tradingService.setRiskManager(riskManager)
        riskMonitor.startMonitoring(
            riskManager: riskManager,
            tradingService: tradingService,
            marketDataService: marketDataService
        )
        
        // 连接到交易API
        Task {
            await tradingService.connectToPinganAPI()
        }
    }
    
    private func refreshOrderBook() {
        guard let stock = selectedStock else { return }
        // 刷新买卖盘口数据
        Task {
            await marketDataService.refreshOrderBook(for: stock.symbol)
        }
    }
    
    private func riskColorForLevel(_ level: AccountRiskLevel) -> Color {
        switch level {
        case .low: return .green
        case .medium: return .yellow
        case .high: return .orange
        case .critical: return .red
        }
    }
    
    private func priceColor(for change: Double) -> Color {
        return change >= 0 ? .green : .red
    }
}

// MARK: - 预览

struct TradingViewController_Previews: PreviewProvider {
    static var previews: some View {
        TradingViewController()
    }
}
