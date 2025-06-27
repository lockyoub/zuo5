/*
 订单历史界面
 显示所有交易订单的历史记录，包括已成交、未成交、已撤销等状态
 作者: MiniMax Agent
 创建时间: 2025-06-24 16:21:15
 */

import SwiftUI
import Combine

struct OrderHistoryView: View {
    @EnvironmentObject private var tradingService: TradingService
    @State private var orders: [OrderRecord] = []
    @State private var selectedTab: OrderStatus = .all
    @State private var isLoading = false
    @State private var showFilterSheet = false
    @State private var searchText = ""
    @State private var selectedDateRange: DateRange = .week
    
    // 筛选后的订单
    private var filteredOrders: [OrderRecord] {
        var filtered = orders
        
        // 按状态筛选
        if selectedTab != .all {
            filtered = filtered.filter { $0.status == selectedTab }
        }
        
        // 按搜索文本筛选
        if !searchText.isEmpty {
            filtered = filtered.filter {
                $0.symbol.localizedCaseInsensitiveContains(searchText) ||
                $0.orderId.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        // 按日期范围筛选
        let now = Date()
        let calendar = Calendar.current
        let startDate: Date
        
        switch selectedDateRange {
        case .today:
            startDate = calendar.startOfDay(for: now)
        case .week:
            startDate = calendar.date(byAdding: .day, value: -7, to: now) ?? now
        case .month:
            startDate = calendar.date(byAdding: .month, value: -1, to: now) ?? now
        case .all:
            return filtered.sorted { $0.createTime > $1.createTime }
        }
        
        filtered = filtered.filter { $0.createTime >= startDate }
        
        return filtered.sorted { $0.createTime > $1.createTime }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // 搜索栏
                searchBarView
                
                // 状态标签栏
                statusTabView
                
                // 内容区域
                if isLoading {
                    loadingView
                } else if filteredOrders.isEmpty {
                    emptyStateView
                } else {
                    orderListView
                }
            }
            .navigationTitle("交易记录")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showFilterSheet = true
                    }) {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                    }
                }
            }
            .sheet(isPresented: $showFilterSheet) {
                FilterSheet(selectedDateRange: $selectedDateRange)
            }
            .onAppear {
                loadOrders()
            }
            .refreshable {
                await refreshOrders()
            }
        }
    }
    
    // MARK: - 搜索栏
    private var searchBarView: some View {
        HStack {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                
                TextField("搜索股票代码或订单号", text: $searchText)
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
    
    // MARK: - 状态标签栏
    private var statusTabView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 16) {
                ForEach(OrderStatus.allCases, id: \.self) { status in
                    Button(action: {
                        selectedTab = status
                    }) {
                        VStack(spacing: 4) {
                            Text(status.displayName)
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(selectedTab == status ? .blue : .secondary)
                            
                            Text("\(countForStatus(status))")
                                .font(.caption2)
                                .foregroundColor(selectedTab == status ? .blue : .secondary)
                            
                            // 底部指示器
                            Rectangle()
                                .fill(selectedTab == status ? .blue : .clear)
                                .frame(height: 2)
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.horizontal, 16)
        }
        .padding(.bottom, 8)
    }
    
    // MARK: - 加载视图
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            
            Text("加载交易记录...")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - 空状态视图
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 50))
                .foregroundColor(.secondary)
            
            Text("暂无交易记录")
                .font(.headline)
                .foregroundColor(.secondary)
            
            Text("您的交易记录将在这里显示")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button("刷新") {
                Task {
                    await refreshOrders()
                }
            }
            .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
    
    // MARK: - 订单列表视图
    private var orderListView: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                ForEach(filteredOrders, id: \.orderId) { order in
                    OrderRowView(order: order)
                        .onTapGesture {
                            // 点击查看订单详情
                        }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
        }
    }
    
    // MARK: - 业务方法
    
    private func loadOrders() {
        isLoading = true
        
        // 模拟网络请求
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            generateMockOrders()
            isLoading = false
        }
    }
    
    private func refreshOrders() async {
        await withCheckedContinuation { continuation in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                generateMockOrders()
                continuation.resume()
            }
        }
    }
    
    private func generateMockOrders() {
        let mockOrders = [
            OrderRecord(
                orderId: "ORD202406240001",
                symbol: "600519.SH",
                direction: .buy,
                orderType: .limit,
                quantity: 200,
                price: 1850.00,
                filledQuantity: 200,
                filledPrice: 1850.00,
                status: .filled,
                createTime: Date().addingTimeInterval(-3600),
                updateTime: Date().addingTimeInterval(-3500)
            ),
            OrderRecord(
                orderId: "ORD202406240002",
                symbol: "000001.SZ",
                direction: .sell,
                orderType: .market,
                quantity: 500,
                price: 15.30,
                filledQuantity: 0,
                filledPrice: 0,
                status: .pending,
                createTime: Date().addingTimeInterval(-1800),
                updateTime: Date().addingTimeInterval(-1800)
            ),
            OrderRecord(
                orderId: "ORD202406240003",
                symbol: "600036.SH",
                direction: .buy,
                orderType: .limit,
                quantity: 300,
                price: 42.50,
                filledQuantity: 100,
                filledPrice: 42.50,
                status: .partiallyFilled,
                createTime: Date().addingTimeInterval(-900),
                updateTime: Date().addingTimeInterval(-600)
            ),
            OrderRecord(
                orderId: "ORD202406240004",
                symbol: "000002.SZ",
                direction: .sell,
                orderType: .limit,
                quantity: 1000,
                price: 18.80,
                filledQuantity: 0,
                filledPrice: 0,
                status: .cancelled,
                createTime: Date().addingTimeInterval(-7200),
                updateTime: Date().addingTimeInterval(-7000)
            ),
            OrderRecord(
                orderId: "ORD202406240005",
                symbol: "002415.SZ",
                direction: .buy,
                orderType: .stopLoss,
                quantity: 200,
                price: 35.20,
                filledQuantity: 0,
                filledPrice: 0,
                status: .rejected,
                createTime: Date().addingTimeInterval(-300),
                updateTime: Date().addingTimeInterval(-300)
            )
        ]
        
        orders = mockOrders
    }
    
    private func countForStatus(_ status: OrderStatus) -> Int {
        if status == .all {
            return orders.count
        }
        return orders.filter { $0.status == status }.count
    }
}

// MARK: - 订单行视图

struct OrderRowView: View {
    let order: OrderRecord
    
    var body: some View {
        VStack(spacing: 0) {
            // 主要信息行
            HStack {
                // 左侧：股票信息和方向
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(order.symbol)
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                        
                        // 交易方向标签
                        Text(order.direction == .buy ? "买入" : "卖出")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(order.direction == .buy ? .red : .green)
                            .cornerRadius(4)
                    }
                    
                    Text(getStockName(for: order.symbol))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // 右侧：状态和时间
                VStack(alignment: .trailing, spacing: 4) {
                    // 订单状态
                    HStack(spacing: 4) {
                        Circle()
                            .fill(order.status.color)
                            .frame(width: 8, height: 8)
                        
                        Text(order.status.displayName)
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(order.status.color)
                    }
                    
                    Text(formatTime(order.createTime))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            
            // 详细信息行
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("订单号: \(order.orderId)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    Text("类型: \(order.orderType.displayName)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text("¥\(order.price, specifier: "%.2f") × \(order.quantity)")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    if order.status == .filled || order.status == .partiallyFilled {
                        Text("成交: \(order.filledQuantity)股")
                            .font(.caption2)
                            .foregroundColor(.green)
                    }
                }
            }
            .padding(.top, 8)
            
            // 进度条（部分成交时显示）
            if order.status == .partiallyFilled {
                VStack(spacing: 4) {
                    HStack {
                        Text("成交进度")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Text("\(order.filledQuantity)/\(order.quantity)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    
                    ProgressView(value: Double(order.filledQuantity), total: Double(order.quantity))
                        .progressViewStyle(LinearProgressViewStyle(tint: .blue))
                        .scaleEffect(y: 0.5)
                }
                .padding(.top, 8)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
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
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        let calendar = Calendar.current
        
        if calendar.isToday(date) {
            formatter.dateFormat = "HH:mm"
            return "今天 \(formatter.string(from: date))"
        } else if calendar.isYesterday(date) {
            formatter.dateFormat = "HH:mm"
            return "昨天 \(formatter.string(from: date))"
        } else {
            formatter.dateFormat = "MM-dd HH:mm"
            return formatter.string(from: date)
        }
    }
}

// MARK: - 筛选弹窗

struct FilterSheet: View {
    @Binding var selectedDateRange: DateRange
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("筛选条件")
                    .font(.title2)
                    .fontWeight(.bold)
                
                VStack(alignment: .leading, spacing: 12) {
                    Text("时间范围")
                        .font(.headline)
                    
                    ForEach(DateRange.allCases, id: \.self) { range in
                        Button(action: {
                            selectedDateRange = range
                        }) {
                            HStack {
                                Text(range.displayName)
                                    .foregroundColor(.primary)
                                
                                Spacer()
                                
                                if selectedDateRange == range {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.blue)
                                }
                            }
                            .padding(.vertical, 8)
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        Divider()
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
                
                Spacer()
            }
            .padding()
            .navigationTitle("筛选")
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

// MARK: - 数据模型

struct OrderRecord {
    let orderId: String
    let symbol: String
    let direction: TradeDirection
    let orderType: OrderType
    let quantity: Int
    let price: Double
    let filledQuantity: Int
    let filledPrice: Double
    let status: OrderStatus
    let createTime: Date
    let updateTime: Date
}

enum OrderStatus: CaseIterable {
    case all, pending, filled, partiallyFilled, cancelled, rejected
    
    var displayName: String {
        switch self {
        case .all: return "全部"
        case .pending: return "待成交"
        case .filled: return "已成交"
        case .partiallyFilled: return "部分成交"
        case .cancelled: return "已撤销"
        case .rejected: return "已拒绝"
        }
    }
    
    var color: Color {
        switch self {
        case .all: return .primary
        case .pending: return .orange
        case .filled: return .green
        case .partiallyFilled: return .blue
        case .cancelled: return .gray
        case .rejected: return .red
        }
    }
}

enum DateRange: CaseIterable {
    case today, week, month, all
    
    var displayName: String {
        switch self {
        case .today: return "今天"
        case .week: return "最近一周"
        case .month: return "最近一月"
        case .all: return "全部"
        }
    }
}

// MARK: - 预览

#Preview {
    OrderHistoryView()
        .environmentObject(TradingService())
}
