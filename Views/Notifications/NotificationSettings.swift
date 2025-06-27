//
//  NotificationSettings.swift
//  StockTradingApp
//
//  Created by MiniMax Agent on 2025-06-24.
//  通知设置视图 - 管理各种通知偏好设置
//

import SwiftUI

/// 通知设置视图
struct NotificationSettingsView: View {
    @StateObject private var notificationManager = NotificationManager.shared
    @State private var settings: NotificationSettings
    @Environment(\.dismiss) private var dismiss
    
    init() {
        _settings = State(initialValue: NotificationManager.shared.settings)
    }
    
    var body: some View {
        NavigationView {
            List {
                // 权限状态
                permissionSection
                
                // 通知类型设置
                notificationTypesSection
                
                // 免打扰设置
                quietHoursSection
                
                // 声音和震动设置
                soundAndVibrationSection
                
                // 高级设置
                advancedSection
            }
            .background(Color.black)
            .navigationTitle("通知设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("保存") {
                        saveSettings()
                    }
                    .foregroundColor(.blue)
                }
            }
        }
    }
    
    // MARK: - 权限状态部分
    private var permissionSection: some View {
        Section {
            HStack {
                Image(systemName: notificationManager.isAuthorized ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundColor(notificationManager.isAuthorized ? .green : .red)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("通知权限")
                        .foregroundColor(.white)
                    Text(notificationManager.isAuthorized ? "已授权" : "未授权")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                
                Spacer()
                
                if !notificationManager.isAuthorized {
                    Button("授权") {
                        Task {
                            await notificationManager.requestAuthorization()
                        }
                    }
                    .foregroundColor(.blue)
                }
            }
            
            if !notificationManager.isAuthorized {
                Text("请在设置中允许通知权限以接收交易和风险提醒")
                    .font(.caption)
                    .foregroundColor(.orange)
            }
        }
        .listRowBackground(Color.gray.opacity(0.1))
    }
    
    // MARK: - 通知类型设置
    private var notificationTypesSection: some View {
        Section("通知类型") {
            NotificationToggleRow(
                title: "交易通知",
                description: "订单状态、成交确认等",
                isOn: $settings.isTradingNotificationEnabled,
                icon: "chart.line.uptrend.xyaxis"
            )
            
            NotificationToggleRow(
                title: "风险预警",
                description: "止损触发、持仓风险等",
                isOn: $settings.isRiskAlertEnabled,
                icon: "exclamationmark.triangle"
            )
            
            NotificationToggleRow(
                title: "策略信号",
                description: "买卖信号、策略提醒等",
                isOn: $settings.isStrategySignalEnabled,
                icon: "brain"
            )
            
            NotificationToggleRow(
                title: "价格提醒",
                description: "自定义价格到达提醒",
                isOn: $settings.isPriceAlertEnabled,
                icon: "bell"
            )
            
            NotificationToggleRow(
                title: "成交量异常",
                description: "异常成交量变化提醒",
                isOn: $settings.isVolumeAlertEnabled,
                icon: "chart.bar"
            )
        }
        .listRowBackground(Color.gray.opacity(0.1))
    }
    
    // MARK: - 免打扰设置
    private var quietHoursSection: some View {
        Section("免打扰时间") {
            NotificationToggleRow(
                title: "启用免打扰",
                description: "指定时间段内不接收通知",
                isOn: $settings.quietHoursEnabled,
                icon: "moon"
            )
            
            if settings.quietHoursEnabled {
                HStack {
                    Text("开始时间")
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    Text(settings.quietStartTime)
                        .foregroundColor(.blue)
                        .onTapGesture {
                            // TODO: 显示时间选择器
                        }
                }
                
                HStack {
                    Text("结束时间")
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    Text(settings.quietEndTime)
                        .foregroundColor(.blue)
                        .onTapGesture {
                            // TODO: 显示时间选择器
                        }
                }
            }
        }
        .listRowBackground(Color.gray.opacity(0.1))
    }
    
    // MARK: - 声音和震动设置
    private var soundAndVibrationSection: some View {
        Section("提醒方式") {
            NotificationToggleRow(
                title: "声音提醒",
                description: "播放通知声音",
                isOn: $settings.soundEnabled,
                icon: "speaker.wave.2"
            )
            
            NotificationToggleRow(
                title: "震动提醒",
                description: "设备震动提醒",
                isOn: $settings.vibrationEnabled,
                icon: "iphone.radiowaves.left.and.right"
            )
            
            NotificationToggleRow(
                title: "应用图标角标",
                description: "在应用图标显示未读数量",
                isOn: $settings.badgeEnabled,
                icon: "app.badge"
            )
        }
        .listRowBackground(Color.gray.opacity(0.1))
    }
    
    // MARK: - 高级设置
    private var advancedSection: some View {
        Section("高级设置") {
            Button(action: clearAllNotifications) {
                HStack {
                    Image(systemName: "trash")
                        .foregroundColor(.red)
                    
                    Text("清空所有通知")
                        .foregroundColor(.red)
                    
                    Spacer()
                }
            }
            
            Button(action: testNotification) {
                HStack {
                    Image(systemName: "bell.badge")
                        .foregroundColor(.blue)
                    
                    Text("发送测试通知")
                        .foregroundColor(.blue)
                    
                    Spacer()
                }
            }
            
            NavigationLink(destination: NotificationHistoryView()) {
                HStack {
                    Image(systemName: "clock.arrow.circlepath")
                        .foregroundColor(.white)
                    
                    Text("通知历史")
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    Text("\(notificationManager.notifications.count)")
                        .foregroundColor(.gray)
                }
            }
        }
        .listRowBackground(Color.gray.opacity(0.1))
    }
    
    // MARK: - 操作方法
    private func saveSettings() {
        notificationManager.settings = settings
        // 这里可以添加设置保存到本地存储的逻辑
        UserDefaults.standard.set(try? JSONEncoder().encode(settings), forKey: "NotificationSettings")
        dismiss()
    }
    
    private func clearAllNotifications() {
        notificationManager.clearAllNotifications()
    }
    
    private func testNotification() {
        let testNotification = TradingNotification(
            type: .tradingSignal,
            title: "测试通知",
            message: "这是一条测试通知，用于验证通知功能是否正常工作",
            stockCode: "TEST001",
            priority: .medium
        )
        notificationManager.sendTradingNotification(testNotification)
    }
}

// MARK: - 通知开关行
struct NotificationToggleRow: View {
    let title: String
    let description: String
    @Binding var isOn: Bool
    let icon: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 24, height: 24)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .foregroundColor(.white)
                    .font(.body)
                
                Text(description)
                    .foregroundColor(.gray)
                    .font(.caption)
            }
            
            Spacer()
            
            Toggle("", isOn: $isOn)
                .toggleStyle(SwitchToggleStyle(tint: .blue))
        }
        .padding(.vertical, 4)
    }
}

// MARK: - 通知历史视图
struct NotificationHistoryView: View {
    @StateObject private var notificationManager = NotificationManager.shared
    
    var body: some View {
        List {
            ForEach(groupedNotifications, id: \.key) { section in
                Section(section.key) {
                    ForEach(section.value) { notification in
                        NotificationHistoryRow(notification: notification)
                    }
                }
                .listRowBackground(Color.gray.opacity(0.1))
            }
        }
        .background(Color.black)
        .navigationTitle("通知历史")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private var groupedNotifications: [(key: String, value: [TradingNotification])] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: notificationManager.notifications) { notification in
            if calendar.isDateInToday(notification.timestamp) {
                return "今天"
            } else if calendar.isDateInYesterday(notification.timestamp) {
                return "昨天"
            } else {
                let formatter = DateFormatter()
                formatter.dateFormat = "MM月dd日"
                return formatter.string(from: notification.timestamp)
            }
        }
        
        return grouped.sorted { first, second in
            if first.key == "今天" { return true }
            if second.key == "今天" { return false }
            if first.key == "昨天" { return true }
            if second.key == "昨天" { return false }
            return first.key > second.key
        }
    }
}

// MARK: - 通知历史行
struct NotificationHistoryRow: View {
    let notification: TradingNotification
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: notification.type.iconName)
                .foregroundColor(notification.type.iconColor)
                .frame(width: 20, height: 20)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(notification.title)
                    .foregroundColor(.white)
                    .font(.body)
                    .lineLimit(1)
                
                Text(notification.message)
                    .foregroundColor(.gray)
                    .font(.caption)
                    .lineLimit(2)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text(notification.timestamp.formattedTradingTime())
                    .foregroundColor(.gray)
                    .font(.caption2)
                
                if !notification.isRead {
                    Circle()
                        .fill(Color.blue)
                        .frame(width: 6, height: 6)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - 预览
struct NotificationSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        NotificationSettingsView()
            .preferredColorScheme(.dark)
    }
}
