/*
 持仓管理界面
 显示所有持仓股票的详细信息，包括成本、市值、盈亏等
 作者: MiniMax Agent
 创建时间: 2025-06-24 16:21:15
 */

import SwiftUI
import Combine

struct PositionsView: View {
    @EnvironmentObject private var tradingService: TradingService
    @EnvironmentObject private var marketDataService: MarketDataService
    
    @State private var positions: [PositionRecord] = []
    @State private var isLoading = false
    @State private var selectedSortOption: SortOption = .symbol
    @State private var showSortSheet = false
    @State private var searchText = ""
    @State private var selectedPosition: PositionRecord?
    @State private var showDetailSheet = false
    
    // 总计信息
    private var portfolioSummary: PortfolioSummary {
        calculatePortfolioSummary()
    }
    
    // 筛选后的持仓
    private var filteredPositions: [PositionRecord] {
        var filtered = positions
        
        // 搜索筛选
        if !searchText.isEmpty {
            filtered = filtered.filter {
                $0.symbol.localizedCaseInsensitiveContains(searchText) ||
                $0.stockName.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        // 排序
        return filtered.sorted { position1, position2 in
            switch selectedSortOption {
            case .symbol:
                return position1.symbol < position2.symbol
            case .marketValue:
                return position1.marketValue > position2.marketValue
            case .pnlAmount:
                return position1.unrealizedPnL > position2.unrealizedPnL
            case .pnlPercent:
                return position1.unrealizedPnLPercent > position2.unrealizedPnLPercent
            case .quantity:
                return position1.quantity > position2.quantity
            }
        }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // 搜索栏
                searchBarView
                
                // 投资组合总览
                portfolioSummaryView
                
                // 持仓列表
                if isLoading {
                    loadingView
                } else if filteredPositions.isEmpty {
                    emptyStateView
                } else {
                    positionsListView
                }
            }
            .navigationTitle("我的持仓")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showSortSheet = true
                    }) {
                        Image(systemName: "arrow.up.arrow.down")
                    }
                }
            }
            .sheet(isPresented: $showSortSheet) {
                SortOptionsSheet(selectedSortOption: $selectedSortOption)
            }
            .sheet(isPresented: $showDetailSheet) {
                if let position = selectedPosition {
                    PositionDetailSheet(position: position)
                }
            }
            .onAppear {
                loadPositions()
            }
            .refreshable {
                await refreshPositions()
            }
        }
    }
    
    // MARK: - 搜索栏
    private var searchBarView: some View {
        HStack {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                
                TextField("搜索股票代码或名称", text: $searchText)
                    .textFieldStyle(PlainTextFieldStyle())
                
                if !searchText.isEmpty {
                    Button(action: {
                        searchText = ""
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(.systemGray6))
            .cornerRadius(10)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }
    
    // MARK: - 投资组合总览
    private var portfolioSummaryView: some View {
        VStack(spacing: 16) {
            // 总资产卡片
            VStack(spacing: 12) {
                HStack {
                    Text("投资组合总览")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Button(action: {
                        // 刷新数据
                        Task {
                            await refreshPositions()
                        }
                    }) {
                        Image(systemName: "arrow.clockwise")
                            .font(.subheadline)
                            .foregroundColor(.blue)
                    }
                }
                
                Divider()
                
                // 资产数据
                HStack(spacing: 20) {
                    // 总市值
                    VStack(alignment: .leading, spacing: 4) {
                        Text("总市值")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text("¥\(portfolioSummary.totalMarketValue, specifier: "%.2f")")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
                    }
                    
                    Spacer()
                    
                    // 总盈亏
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("总盈亏")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("¥\(portfolioSummary.totalPnL, specifier: "%.2f")")
                                .font(.title3)
                                .fontWeight(.bold)
                                .foregroundColor(portfolioSummary.totalPnL >= 0 ? .red : .green)
                            
                            Text("\(portfolioSummary.totalPnL >= 0 ? "+" : "")\(portfolioSummary.totalPnLPercent, specifier: "%.2f")%")
                                .font(.caption)
                                .foregroundColor(portfolioSummary.totalPnL >= 0 ? .red : .green)
                        }
                    }
                }
                
                // 统计信息
                HStack(spacing: 20) {
                    statisticItem(title: "持仓数量", value: "\(positions.count)只")
                    statisticItem(title: "盈利股票", value: "\(portfolioSummary.profitableCount)只")
                    statisticItem(title: "亏损股票", value: "\(portfolioSummary.losingCount)只")
                    statisticItem(title: "总成本", value: "¥\(portfolioSummary.totalCost, specifier: "%.0f")")
                }
            }
            .padding(16)
            .background(
                LinearGradient(
                    colors: portfolioSummary.totalPnL >= 0 ? [.red.opacity(0.1), .orange.opacity(0.05)] : [.green.opacity(0.1), .mint.opacity(0.05)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .cornerRadius(16)
            .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }
    
    // MARK: - 统计项
    private func statisticItem(title: String, value: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
            
            Text(title)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
    
    // MARK: - 加载视图
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            
            Text("加载持仓数据...")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - 空状态视图
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "chart.pie")
                .font(.system(size: 50))
                .foregroundColor(.secondary)
            
            Text("暂无持仓")
                .font(.headline)
                .foregroundColor(.secondary)
            
            Text("您的股票持仓将在这里显示")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button("去交易") {
                // 跳转到交易界面
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
    
    // MARK: - 持仓列表视图
    private var positionsListView: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                ForEach(filteredPositions, id: \.symbol) { position in
                    PositionRowView(position: position)
                        .onTapGesture {
                            selectedPosition = position
                            showDetailSheet = true
                        }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
        }
    }
    
    // MARK: - 业务方法
    
    private func loadPositions() {
        isLoading = true
        
        // 模拟网络请求
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            generateMockPositions()
            isLoading = false
        }
    }
    
    private func refreshPositions() async {
        await withCheckedContinuation { continuation in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                generateMockPositions()
                continuation.resume()
            }
        }
    }
    
    private func generateMockPositions() {
        positions = [
            PositionRecord(
                symbol: "600519.SH",
                stockName: "贵州茅台",
                quantity: 100,
                availableQuantity: 100,
                avgCost: 1820.00,
                currentPrice: 1850.00,
                lastUpdateTime: Date()
            ),
            PositionRecord(
                symbol: "000001.SZ",
                stockName: "平安银行",
                quantity: 1000,
                availableQuantity: 1000,
                avgCost: 15.20,
                currentPrice: 15.35,
                lastUpdateTime: Date()
            ),
            PositionRecord(
                symbol: "600036.SH",
                stockName: "招商银行",
                quantity: 500,
                availableQuantity: 200,
                avgCost: 42.80,
                currentPrice: 42.30,
                lastUpdateTime: Date()
            ),
            PositionRecord(
                symbol: "002415.SZ",
                stockName: "海康威视",
                quantity: 800,
                availableQuantity: 800,
                avgCost: 36.50,
                currentPrice: 35.20,
                lastUpdateTime: Date()
            )
        ]
    }
    
    private func calculatePortfolioSummary() -> PortfolioSummary {
        let totalCost = positions.reduce(0) { $0 + $1.totalCost }
        let totalMarketValue = positions.reduce(0) { $0 + $1.marketValue }
        let totalPnL = totalMarketValue - totalCost
        let totalPnLPercent = totalCost > 0 ? (totalPnL / totalCost) * 100 : 0
        
        let profitableCount = positions.filter { $0.unrealizedPnL > 0 }.count
        let losingCount = positions.filter { $0.unrealizedPnL < 0 }.count
        
        return PortfolioSummary(
            totalCost: totalCost,
            totalMarketValue: totalMarketValue,
            totalPnL: totalPnL,
            totalPnLPercent: totalPnLPercent,
            profitableCount: profitableCount,
            losingCount: losingCount
        )
    }
}

// MARK: - 持仓行视图

struct PositionRowView: View {
    let position: PositionRecord
    
    var body: some View {
        VStack(spacing: 0) {
            // 主要信息行
            HStack {
                // 左侧：股票信息
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(position.symbol)
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                        
                        if position.quantity != position.availableQuantity {
                            Text("部分冻结")
                                .font(.caption2)
                                .foregroundColor(.orange)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1)
                                .background(Color.orange.opacity(0.1))
                                .cornerRadius(4)
                        }
                    }
                    
                    Text(position.stockName)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // 右侧：价格和盈亏
                VStack(alignment: .trailing, spacing: 4) {
                    Text("¥\(position.currentPrice, specifier: "%.2f")")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    HStack(spacing: 2) {
                        Text(position.unrealizedPnL >= 0 ? "+" : "")
                        Text("¥\(position.unrealizedPnL, specifier: "%.2f")")
                        Text("(\(position.unrealizedPnLPercent, specifier: "%.2f")%)")
                    }
                    .font(.caption)
                    .foregroundColor(position.unrealizedPnL >= 0 ? .red : .green)
                }
            }
            
            // 详细信息行
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("持仓: \(position.quantity)股")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("可用: \(position.availableQuantity)股")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text("成本: ¥\(position.avgCost, specifier: "%.2f")")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("市值: ¥\(position.marketValue, specifier: "%.0f")")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.top, 8)
            
            // 持仓占比进度条
            VStack(spacing: 4) {
                HStack {
                    Text("持仓占比")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    // 这里应该根据总市值计算真实占比，暂时使用模拟数据
                    let ratio = min(position.marketValue / 100000, 1.0) // 假设总资产10万
                    Text("\(ratio * 100, specifier: "%.1f")%")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                ProgressView(value: min(position.marketValue / 100000, 1.0))
                    .progressViewStyle(LinearProgressViewStyle(tint: position.unrealizedPnL >= 0 ? .red : .green))
                    .scaleEffect(y: 0.5)
            }
            .padding(.top, 8)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
}

// MARK: - 排序选项弹窗

struct SortOptionsSheet: View {
    @Binding var selectedSortOption: SortOption
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("排序方式")
                    .font(.title2)
                    .fontWeight(.bold)
                
                VStack(spacing: 0) {
                    ForEach(SortOption.allCases, id: \.self) { option in
                        Button(action: {
                            selectedSortOption = option
                            dismiss()
                        }) {
                            HStack {
                                Text(option.displayName)
                                    .foregroundColor(.primary)
                                
                                Spacer()
                                
                                if selectedSortOption == option {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.blue)
                                }
                            }
                            .padding(.vertical, 12)
                            .padding(.horizontal, 16)
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        if option != SortOption.allCases.last {
                            Divider()
                        }
                    }
                }
                .background(Color(.systemGray6))
                .cornerRadius(12)
                
                Spacer()
            }
            .padding()
            .navigationTitle("排序")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - 持仓详情弹窗

struct PositionDetailSheet: View {
    let position: PositionRecord
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // 基本信息
                    VStack(spacing: 16) {
                        Text(position.stockName)
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text(position.symbol)
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        // 详细数据表格
                        VStack(spacing: 12) {
                            detailRow(title: "持仓数量", value: "\(position.quantity)股")
                            detailRow(title: "可用数量", value: "\(position.availableQuantity)股")
                            detailRow(title: "平均成本", value: "¥\(position.avgCost, specifier: "%.2f")")
                            detailRow(title: "当前价格", value: "¥\(position.currentPrice, specifier: "%.2f")")
                            detailRow(title: "市值", value: "¥\(position.marketValue, specifier: "%.2f")")
                            detailRow(title: "浮动盈亏", value: "¥\(position.unrealizedPnL, specifier: "%.2f")")
                            detailRow(title: "盈亏比例", value: "\(position.unrealizedPnLPercent, specifier: "%.2f")%")
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                    }
                    
                    // 操作按钮
                    VStack(spacing: 12) {
                        Button("卖出股票") {
                            // 跳转到卖出界面
                            dismiss()
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        
                        Button("设置止损") {
                            // 跳转到止损设置
                            dismiss()
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.large)
                    }
                }
                .padding()
            }
            .navigationTitle("持仓详情")
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
    
    private func detailRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text(value)
                .fontWeight(.medium)
                .foregroundColor(.primary)
        }
    }
}

// MARK: - 数据模型

struct PositionRecord {
    let symbol: String
    let stockName: String
    let quantity: Int
    let availableQuantity: Int
    let avgCost: Double
    let currentPrice: Double
    let lastUpdateTime: Date
    
    var totalCost: Double {
        return avgCost * Double(quantity)
    }
    
    var marketValue: Double {
        return currentPrice * Double(quantity)
    }
    
    var unrealizedPnL: Double {
        return marketValue - totalCost
    }
    
    var unrealizedPnLPercent: Double {
        return totalCost > 0 ? (unrealizedPnL / totalCost) * 100 : 0
    }
}

struct PortfolioSummary {
    let totalCost: Double
    let totalMarketValue: Double
    let totalPnL: Double
    let totalPnLPercent: Double
    let profitableCount: Int
    let losingCount: Int
}

enum SortOption: CaseIterable {
    case symbol, marketValue, pnlAmount, pnlPercent, quantity
    
    var displayName: String {
        switch self {
        case .symbol: return "股票代码"
        case .marketValue: return "市值"
        case .pnlAmount: return "盈亏金额"
        case .pnlPercent: return "盈亏比例"
        case .quantity: return "持仓数量"
        }
    }
}

// MARK: - 预览

#Preview {
    PositionsView()
        .environmentObject(TradingService())
        .environmentObject(MarketDataService())
}
