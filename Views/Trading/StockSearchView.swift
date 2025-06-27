/*
 股票搜索界面
 提供股票代码和名称搜索功能，支持实时搜索和历史搜索记录
 作者: MiniMax Agent
 创建时间: 2025-06-24 16:21:15
 */

import SwiftUI
import Combine

struct StockSearchView: View {
    @EnvironmentObject private var marketDataService: MarketDataService
    @Environment(\.dismiss) private var dismiss
    
    // 搜索相关状态
    @State private var searchText = ""
    @State private var searchResults: [StockSearchResult] = []
    @State private var recentSearches: [String] = []
    @State private var isSearching = false
    @State private var showClearAlert = false
    
    // 选择回调
    let onStockSelected: (String) -> Void
    
    // 热门股票列表
    private let popularStocks = [
        StockSearchResult(symbol: "000001.SZ", name: "平安银行", exchange: "深交所", sector: "银行"),
        StockSearchResult(symbol: "000002.SZ", name: "万科A", exchange: "深交所", sector: "房地产"),
        StockSearchResult(symbol: "600000.SH", name: "浦发银行", exchange: "上交所", sector: "银行"),
        StockSearchResult(symbol: "600036.SH", name: "招商银行", exchange: "上交所", sector: "银行"),
        StockSearchResult(symbol: "600519.SH", name: "贵州茅台", exchange: "上交所", sector: "食品饮料"),
        StockSearchResult(symbol: "000858.SZ", name: "五粮液", exchange: "深交所", sector: "食品饮料"),
        StockSearchResult(symbol: "002415.SZ", name: "海康威视", exchange: "深交所", sector: "电子"),
        StockSearchResult(symbol: "300059.SZ", name: "东方财富", exchange: "深交所", sector: "非银金融")
    ]
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // 搜索栏
                searchBarView
                
                // 内容区域
                if searchText.isEmpty {
                    defaultContentView
                } else {
                    searchResultsView
                }
                
                Spacer()
            }
            .navigationTitle("股票搜索")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("清除历史") {
                        showClearAlert = true
                    }
                    .disabled(recentSearches.isEmpty)
                }
            }
            .alert("清除搜索历史", isPresented: $showClearAlert) {
                Button("取消", role: .cancel) { }
                Button("清除", role: .destructive) {
                    clearRecentSearches()
                }
            } message: {
                Text("确定要清除所有搜索历史记录吗？")
            }
        }
        .onAppear {
            loadRecentSearches()
        }
    }
    
    // MARK: - 搜索栏视图
    private var searchBarView: some View {
        VStack(spacing: 0) {
            HStack {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    
                    TextField("输入股票代码或名称", text: $searchText)
                        .textFieldStyle(PlainTextFieldStyle())
                        .onChange(of: searchText) { newValue in
                            performSearch(query: newValue)
                        }
                    
                    if !searchText.isEmpty {
                        Button(action: {
                            searchText = ""
                            searchResults = []
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
            
            Divider()
        }
    }
    
    // MARK: - 默认内容视图
    private var defaultContentView: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                // 最近搜索
                if !recentSearches.isEmpty {
                    recentSearchesSection
                }
                
                // 热门股票
                popularStocksSection
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
        }
    }
    
    // MARK: - 最近搜索区域
    private var recentSearchesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("最近搜索")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Button("清除") {
                    showClearAlert = true
                }
                .font(.caption)
                .foregroundColor(.blue)
            }
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 8) {
                ForEach(recentSearches.prefix(6), id: \.self) { search in
                    Button(action: {
                        searchText = search
                        performSearch(query: search)
                    }) {
                        Text(search)
                            .font(.caption)
                            .foregroundColor(.primary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color(.systemGray6))
                            .cornerRadius(16)
                    }
                }
            }
        }
    }
    
    // MARK: - 热门股票区域
    private var popularStocksSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("热门股票")
                .font(.headline)
                .foregroundColor(.primary)
            
            LazyVStack(spacing: 8) {
                ForEach(popularStocks, id: \.symbol) { stock in
                    stockRowView(stock: stock)
                }
            }
        }
    }
    
    // MARK: - 搜索结果视图
    private var searchResultsView: some View {
        VStack(spacing: 0) {
            if isSearching {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("搜索中...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 20)
            } else if searchResults.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary)
                    
                    Text("未找到相关股票")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    Text("请尝试输入其他关键词")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 60)
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(searchResults, id: \.symbol) { stock in
                            stockRowView(stock: stock)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                }
            }
        }
    }
    
    // MARK: - 股票行视图
    private func stockRowView(stock: StockSearchResult) -> some View {
        Button(action: {
            selectStock(stock.symbol)
        }) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(stock.symbol)
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        Text(stock.exchange)
                            .font(.caption)
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(stock.exchangeColor)
                            .cornerRadius(4)
                    }
                    
                    Text(stock.name)
                        .font(.subheadline)
                        .foregroundColor(.primary)
                    
                    Text(stock.sector)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    // 显示实时价格（如果有）
                    if let stockData = marketDataService.stockData[stock.symbol] {
                        Text("¥\(stockData.lastPrice, specifier: "%.2f")")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        HStack(spacing: 4) {
                            Text(stockData.change >= 0 ? "+" : "")
                            Text("\(stockData.change, specifier: "%.2f")")
                            Text("(\(stockData.changePercent, specifier: "%.2f")%)")
                        }
                        .font(.caption)
                        .foregroundColor(stockData.change >= 0 ? .red : .green)
                    } else {
                        Text("--")
                            .font(.headline)
                            .foregroundColor(.secondary)
                    }
                    
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    // MARK: - 业务方法
    
    private func performSearch(query: String) {
        guard !query.isEmpty else {
            searchResults = []
            isSearching = false
            return
        }
        
        isSearching = true
        
        // 模拟搜索延迟
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            searchResults = popularStocks.filter { stock in
                stock.symbol.localizedCaseInsensitiveContains(query) ||
                stock.name.localizedCaseInsensitiveContains(query)
            }
            isSearching = false
        }
    }
    
    private func selectStock(_ symbol: String) {
        // 添加到最近搜索
        addToRecentSearches(symbol)
        
        // 回调选择结果
        onStockSelected(symbol)
        
        // 关闭界面
        dismiss()
    }
    
    private func addToRecentSearches(_ symbol: String) {
        // 移除重复项
        recentSearches.removeAll { $0 == symbol }
        
        // 添加到前面
        recentSearches.insert(symbol, at: 0)
        
        // 限制数量
        if recentSearches.count > 10 {
            recentSearches = Array(recentSearches.prefix(10))
        }
        
        // 保存到UserDefaults
        UserDefaults.standard.set(recentSearches, forKey: "RecentStockSearches")
    }
    
    private func loadRecentSearches() {
        recentSearches = UserDefaults.standard.stringArray(forKey: "RecentStockSearches") ?? []
    }
    
    private func clearRecentSearches() {
        recentSearches = []
        UserDefaults.standard.removeObject(forKey: "RecentStockSearches")
    }
}

// MARK: - 数据模型

struct StockSearchResult {
    let symbol: String
    let name: String
    let exchange: String
    let sector: String
    
    var exchangeColor: Color {
        switch exchange {
        case "上交所":
            return .red
        case "深交所":
            return .blue
        case "北交所":
            return .green
        default:
            return .gray
        }
    }
}

// MARK: - 临时数据模型（用于测试）

struct StockData {
    let symbol: String
    let lastPrice: Double
    let change: Double
    let changePercent: Double
    let volume: Int64
}

// MARK: - 预览

#Preview {
    StockSearchView { selectedSymbol in
        print("选择了股票: \(selectedSymbol)")
    }
    .environmentObject(MarketDataService())
}
