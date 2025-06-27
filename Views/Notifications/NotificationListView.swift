//
//  NotificationListView.swift
//  StockTradingApp
//
//  Created by MiniMax Agent on 2025-06-24.
//  通知列表视图 - 显示所有交易和风险通知
//

import SwiftUI

/// 通知列表视图
struct NotificationListView: View {
    @StateObject private var notificationManager = NotificationManager.shared
    @State private var selectedFilter: NotificationFilter = .all
    @State private var showingSettings = false
    @State private var searchText = ""
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // 搜索栏
                searchBar
                
                // 筛选器
                filterBar
                
                // 通知列表
                notificationList
            }
            .background(Color.black)
            .navigationTitle("通知中心")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    settingsButton
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    markAllReadButton
                }
            }
            .sheet(isPresented: $showingSettings) {
                NotificationSettingsView()
            }
        }
        .onAppear {
            Task {
                await notificationManager.checkAuthorizationStatus()
            }
        }
    }
    
    // MARK: - 搜索栏
    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.gray)
            
            TextField("搜索通知...", text: $searchText)
                .foregroundColor(.white)
                .textFieldStyle(PlainTextFieldStyle())
            
            if !searchText.isEmpty {
                Button(action: { searchText = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.gray)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color.gray.opacity(0.2))
        .cornerRadius(10)
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }
    
    // MARK: - 筛选器
    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(NotificationFilter.allCases, id: \.self) { filter in
                    FilterButton(
                        filter: filter,
                        isSelected: selectedFilter == filter,
                        count: notificationCount(for: filter)
                    ) {
                        selectedFilter = filter
                    }
                }
            }
            .padding(.horizontal, 16)
        }
        .frame(height: 44)
        .background(Color.gray.opacity(0.1))
    }
    
    // MARK: - 通知列表
    private var notificationList: some View {
        List {
            if filteredNotifications.isEmpty {
                emptyStateView
            } else {
                ForEach(filteredNotifications) { notification in
                    NotificationRow(notification: notification) {
                        notificationManager.markAsRead(notification.id)
                    }
                    .swipeActions(edge: .trailing) {
                        Button("删除") {
                            notificationManager.clearNotification(notification.id)
                        }
                        .tint(.red)
                        
                        if !notification.isRead {
                            Button("已读") {
                                notificationManager.markAsRead(notification.id)
                            }
                            .tint(.blue)
                        }
                    }
                }
            }
        }
        .listStyle(PlainListStyle())
        .background(Color.black)
    }
    
    // MARK: - 设置按钮
    private var settingsButton: some View {
        Button(action: { showingSettings = true }) {
            Image(systemName: "gearshape")
                .foregroundColor(.white)
        }
    }
    
    // MARK: - 全部已读按钮
    private var markAllReadButton: some View {
        Button(action: { notificationManager.markAllAsRead() }) {
            Text("全部已读")
                .foregroundColor(.blue)
        }
        .disabled(notificationManager.unreadCount == 0)
    }
    
    // MARK: - 空状态视图
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "bell.slash")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            Text("暂无通知")
                .font(.headline)
                .foregroundColor(.gray)
            
            Text("交易和风险通知将在这里显示")
                .font(.caption)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
    }
    
    // MARK: - 计算属性
    private var filteredNotifications: [TradingNotification] {
        var notifications = notificationManager.notifications
        
        // 按类型筛选
        switch selectedFilter {
        case .all:
            break
        case .unread:
            notifications = notifications.filter { !$0.isRead }
        case .trading:
            notifications = notifications.filter { 
                [.orderStatus, .tradeExecution, .tradeFailed, .tradingSignal].contains($0.type)
            }
        case .risk:
            notifications = notifications.filter { 
                [.riskAlert, .stopLoss, .positionRisk].contains($0.type)
            }
        case .strategy:
            notifications = notifications.filter { $0.type == .strategySignal }
        }
        
        // 按搜索文本筛选
        if !searchText.isEmpty {
            notifications = notifications.filter { notification in
                notification.title.localizedCaseInsensitiveContains(searchText) ||
                notification.message.localizedCaseInsensitiveContains(searchText) ||
                (notification.stockCode?.localizedCaseInsensitiveContains(searchText) ?? false)
            }
        }
        
        return notifications
    }
    
    private func notificationCount(for filter: NotificationFilter) -> Int {
        switch filter {
        case .all:
            return notificationManager.notifications.count
        case .unread:
            return notificationManager.unreadCount
        case .trading:
            return notificationManager.notifications.filter { 
                [.orderStatus, .tradeExecution, .tradeFailed, .tradingSignal].contains($0.type)
            }.count
        case .risk:
            return notificationManager.notifications.filter { 
                [.riskAlert, .stopLoss, .positionRisk].contains($0.type)
            }.count
        case .strategy:
            return notificationManager.notifications.filter { $0.type == .strategySignal }.count
        }
    }
}

// MARK: - 通知行视图
struct NotificationRow: View {
    let notification: TradingNotification
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // 通知图标
                notificationIcon
                
                // 通知内容
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(notification.title)
                            .font(.headline)
                            .foregroundColor(.white)
                            .lineLimit(1)
                        
                        Spacer()
                        
                        if !notification.isRead {
                            Circle()
                                .fill(Color.blue)
                                .frame(width: 8, height: 8)
                        }
                    }
                    
                    Text(notification.message)
                        .font(.body)
                        .foregroundColor(.gray)
                        .lineLimit(2)
                    
                    HStack {
                        if let stockCode = notification.stockCode {
                            Text(stockCode)
                                .font(.caption)
                                .foregroundColor(.blue)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.blue.opacity(0.2))
                                .cornerRadius(4)
                        }
                        
                        Spacer()
                        
                        Text(notification.timestamp.formattedTradingTime())
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
                
                // 优先级指示器
                if notification.priority == .critical {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.red)
                        .font(.caption)
                }
            }
            .padding(.vertical, 8)
        }
        .buttonStyle(PlainButtonStyle())
        .listRowBackground(
            notification.isRead ? Color.clear : Color.blue.opacity(0.1)
        )
    }
    
    private var notificationIcon: some View {
        ZStack {
            Circle()
                .fill(notification.type.iconColor)
                .frame(width: 40, height: 40)
            
            Image(systemName: notification.type.iconName)
                .foregroundColor(.white)
                .font(.system(size: 18))
        }
    }
}

// MARK: - 筛选按钮
struct FilterButton: View {
    let filter: NotificationFilter
    let isSelected: Bool
    let count: Int
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Text(filter.displayName)
                    .font(.caption)
                    .foregroundColor(isSelected ? .black : .white)
                
                if count > 0 {
                    Text("\(count)")
                        .font(.caption2)
                        .foregroundColor(isSelected ? .black : .white)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(isSelected ? Color.black.opacity(0.3) : Color.white.opacity(0.3))
                        .cornerRadius(8)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(isSelected ? Color.white : Color.clear)
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.white, lineWidth: 1)
            )
        }
    }
}

// MARK: - 枚举扩展
enum NotificationFilter: CaseIterable {
    case all, unread, trading, risk, strategy
    
    var displayName: String {
        switch self {
        case .all: return "全部"
        case .unread: return "未读"
        case .trading: return "交易"
        case .risk: return "风险"
        case .strategy: return "策略"
        }
    }
}

extension NotificationType {
    var iconName: String {
        switch self {
        case .orderStatus: return "doc.text"
        case .tradeExecution: return "checkmark.circle"
        case .tradeFailed: return "xmark.circle"
        case .riskAlert: return "exclamationmark.triangle"
        case .stopLoss: return "shield.slash"
        case .positionRisk: return "chart.line.downtrend.xyaxis"
        case .strategySignal: return "brain"
        case .tradingSignal: return "arrow.up.arrow.down"
        }
    }
    
    var iconColor: Color {
        switch self {
        case .orderStatus: return .blue
        case .tradeExecution: return .green
        case .tradeFailed: return .red
        case .riskAlert: return .orange
        case .stopLoss: return .red
        case .positionRisk: return .yellow
        case .strategySignal: return .purple
        case .tradingSignal: return .blue
        }
    }
}

// MARK: - 预览
struct NotificationListView_Previews: PreviewProvider {
    static var previews: some View {
        NotificationListView()
            .preferredColorScheme(.dark)
    }
}
