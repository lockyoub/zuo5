/*
 止损设置界面
 为持仓股票设置止损止盈策略，支持价格止损、比例止损等多种方式
 作者: MiniMax Agent
 创建时间: 2025-06-24 16:21:15
 */

import SwiftUI
import Combine

struct StopLossSettingsView: View {
    @EnvironmentObject private var riskManager: RiskManager
    @Environment(\.dismiss) private var dismiss
    
    let symbol: String
    let currentPrice: Double
    let position: PositionRecord?
    
    // 止损设置状态
    @State private var isStopLossEnabled = false
    @State private var stopLossType: StopLossType = .percentage
    @State private var stopLossPrice = ""
    @State private var stopLossPercentage = "5.0"
    
    // 止盈设置状态
    @State private var isTakeProfitEnabled = false
    @State private var takeProfitType: StopLossType = .percentage
    @State private var takeProfitPrice = ""
    @State private var takeProfitPercentage = "10.0"
    
    // 跟踪止损设置
    @State private var isTrailingStopEnabled = false
    @State private var trailingStopPercentage = "3.0"
    
    // 其他状态
    @State private var showConfirmAlert = false
    @State private var showSuccessAlert = false
    @State private var showErrorAlert = false
    @State private var alertMessage = ""
    @State private var isSubmitting = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // 股票信息卡片
                    stockInfoCard
                    
                    // 止损设置区域
                    stopLossSection
                    
                    // 止盈设置区域
                    takeProfitSection
                    
                    // 跟踪止损设置区域
                    trailingStopSection
                    
                    // 风险提示
                    riskWarningSection
                    
                    // 操作按钮
                    actionButtonsSection
                }
                .padding()
            }
            .navigationTitle("止损止盈设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("历史记录") {
                        // 查看历史止损记录
                    }
                    .font(.subheadline)
                }
            }
            .alert("确认设置", isPresented: $showConfirmAlert) {
                Button("取消", role: .cancel) { }
                Button("确认") {
                    submitSettings()
                }
            } message: {
                Text(generateConfirmMessage())
            }
            .alert("设置成功", isPresented: $showSuccessAlert) {
                Button("完成") {
                    dismiss()
                }
            } message: {
                Text(alertMessage)
            }
            .alert("设置失败", isPresented: $showErrorAlert) {
                Button("确定") { }
            } message: {
                Text(alertMessage)
            }
            .onAppear {
                setupInitialValues()
            }
        }
    }
    
    // MARK: - 股票信息卡片
    private var stockInfoCard: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(symbol)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    
                    Text(getStockName(for: symbol))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("当前价格")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("¥\(currentPrice, specifier: "%.2f")")
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                }
            }
            
            if let pos = position {
                Divider()
                
                HStack(spacing: 20) {
                    statisticItem(title: "持仓", value: "\(pos.quantity)股")
                    statisticItem(title: "成本", value: "¥\(pos.avgCost, specifier: "%.2f")")
                    statisticItem(title: "盈亏", value: "¥\(pos.unrealizedPnL, specifier: "%.2f")")
                    statisticItem(title: "盈亏比", value: "\(pos.unrealizedPnLPercent, specifier: "%.1f")%")
                }
            }
        }
        .padding(16)
        .background(Color(.systemGray6).opacity(0.5))
        .cornerRadius(12)
    }
    
    // MARK: - 止损设置区域
    private var stopLossSection: some View {
        VStack(spacing: 16) {
            // 标题和开关
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("止损设置")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    Text("股价下跌时自动卖出以控制风险")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Toggle("", isOn: $isStopLossEnabled)
                    .toggleStyle(SwitchToggleStyle(tint: .red))
            }
            
            if isStopLossEnabled {
                VStack(spacing: 16) {
                    // 止损类型选择
                    Picker("止损类型", selection: $stopLossType) {
                        Text("按比例").tag(StopLossType.percentage)
                        Text("按价格").tag(StopLossType.price)
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    
                    // 止损参数输入
                    if stopLossType == .percentage {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("止损比例")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.secondary)
                            
                            HStack {
                                TextField("5.0", text: $stopLossPercentage)
                                    .keyboardType(.decimalPad)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                                
                                Text("%")
                                    .foregroundColor(.secondary)
                                
                                Spacer()
                                
                                Text("触发价: ¥\(calculateStopLossPrice(), specifier: "%.2f")")
                                    .font(.caption)
                                    .foregroundColor(.red)
                            }
                        }
                    } else {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("止损价格")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.secondary)
                            
                            HStack {
                                Text("¥")
                                    .foregroundColor(.secondary)
                                
                                TextField("\(currentPrice * 0.95, specifier: "%.2f")", text: $stopLossPrice)
                                    .keyboardType(.decimalPad)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                                
                                Spacer()
                                
                                if let price = Double(stopLossPrice) {
                                    let percentage = ((currentPrice - price) / currentPrice) * 100
                                    Text("跌幅: \(percentage, specifier: "%.1f")%")
                                        .font(.caption)
                                        .foregroundColor(.red)
                                }
                            }
                        }
                    }
                    
                    // 快速设置按钮
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible()),
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 8) {
                        ForEach([3, 5, 8, 10], id: \.self) { percentage in
                            Button("\(percentage)%") {
                                stopLossPercentage = "\(percentage).0"
                                if stopLossType == .price {
                                    stopLossPrice = String(format: "%.2f", currentPrice * (1 - Double(percentage) / 100))
                                }
                            }
                            .font(.caption)
                            .foregroundColor(.red)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.red.opacity(0.1))
                            .cornerRadius(6)
                        }
                    }
                }
                .padding(.leading, 16)
            }
        }
        .padding(16)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
    
    // MARK: - 止盈设置区域
    private var takeProfitSection: some View {
        VStack(spacing: 16) {
            // 标题和开关
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("止盈设置")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    Text("股价上涨时自动卖出以锁定收益")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Toggle("", isOn: $isTakeProfitEnabled)
                    .toggleStyle(SwitchToggleStyle(tint: .green))
            }
            
            if isTakeProfitEnabled {
                VStack(spacing: 16) {
                    // 止盈类型选择
                    Picker("止盈类型", selection: $takeProfitType) {
                        Text("按比例").tag(StopLossType.percentage)
                        Text("按价格").tag(StopLossType.price)
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    
                    // 止盈参数输入
                    if takeProfitType == .percentage {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("止盈比例")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.secondary)
                            
                            HStack {
                                TextField("10.0", text: $takeProfitPercentage)
                                    .keyboardType(.decimalPad)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                                
                                Text("%")
                                    .foregroundColor(.secondary)
                                
                                Spacer()
                                
                                Text("触发价: ¥\(calculateTakeProfitPrice(), specifier: "%.2f")")
                                    .font(.caption)
                                    .foregroundColor(.green)
                            }
                        }
                    } else {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("止盈价格")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.secondary)
                            
                            HStack {
                                Text("¥")
                                    .foregroundColor(.secondary)
                                
                                TextField("\(currentPrice * 1.1, specifier: "%.2f")", text: $takeProfitPrice)
                                    .keyboardType(.decimalPad)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                                
                                Spacer()
                                
                                if let price = Double(takeProfitPrice) {
                                    let percentage = ((price - currentPrice) / currentPrice) * 100
                                    Text("涨幅: \(percentage, specifier: "%.1f")%")
                                        .font(.caption)
                                        .foregroundColor(.green)
                                }
                            }
                        }
                    }
                    
                    // 快速设置按钮
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible()),
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 8) {
                        ForEach([5, 10, 15, 20], id: \.self) { percentage in
                            Button("\(percentage)%") {
                                takeProfitPercentage = "\(percentage).0"
                                if takeProfitType == .price {
                                    takeProfitPrice = String(format: "%.2f", currentPrice * (1 + Double(percentage) / 100))
                                }
                            }
                            .font(.caption)
                            .foregroundColor(.green)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.green.opacity(0.1))
                            .cornerRadius(6)
                        }
                    }
                }
                .padding(.leading, 16)
            }
        }
        .padding(16)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
    
    // MARK: - 跟踪止损设置区域
    private var trailingStopSection: some View {
        VStack(spacing: 16) {
            // 标题和开关
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("跟踪止损")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    Text("随股价上涨自动调整止损价格")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Toggle("", isOn: $isTrailingStopEnabled)
                    .toggleStyle(SwitchToggleStyle(tint: .blue))
            }
            
            if isTrailingStopEnabled {
                VStack(alignment: .leading, spacing: 8) {
                    Text("跟踪止损比例")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                    
                    HStack {
                        TextField("3.0", text: $trailingStopPercentage)
                            .keyboardType(.decimalPad)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                        
                        Text("%")
                            .foregroundColor(.secondary)
                        
                        Spacer()
                    }
                    
                    Text("当股价上涨时，止损价将自动跟随调整，保持与最高价的固定比例差距")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .padding(.top, 4)
                }
                .padding(.leading, 16)
            }
        }
        .padding(16)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
    
    // MARK: - 风险提示区域
    private var riskWarningSection: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
                
                Text("风险提示")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.orange)
                
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 8) {
                riskWarningItem("止损止盈设置将在交易时间内生效")
                riskWarningItem("市场波动可能导致实际成交价格与设置价格存在差异")
                riskWarningItem("跟踪止损在快速下跌时可能无法及时触发")
                riskWarningItem("建议结合技术分析合理设置止损止盈点位")
            }
        }
        .padding(16)
        .background(Color.orange.opacity(0.1))
        .cornerRadius(12)
    }
    
    private func riskWarningItem(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text("•")
                .foregroundColor(.orange)
                .font(.caption)
            
            Text(text)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.leading)
        }
    }
    
    // MARK: - 操作按钮区域
    private var actionButtonsSection: some View {
        VStack(spacing: 12) {
            // 主要操作按钮
            Button(action: {
                if isValidSettings() {
                    showConfirmAlert = true
                }
            }) {
                HStack {
                    if isSubmitting {
                        ProgressView()
                            .scaleEffect(0.8)
                            .tint(.white)
                    } else {
                        Image(systemName: "shield.checkered")
                    }
                    
                    Text(isSubmitting ? "设置中..." : "确认设置")
                        .fontWeight(.semibold)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    LinearGradient(
                        colors: [.blue, .purple],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(10)
                .disabled(isSubmitting || !isValidSettings())
                .opacity(isValidSettings() ? 1.0 : 0.6)
            }
            
            // 辅助按钮
            HStack(spacing: 12) {
                Button("重置") {
                    resetSettings()
                }
                .foregroundColor(.blue)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(Color.blue.opacity(0.1))
                .cornerRadius(8)
                
                Button("模板") {
                    // 使用预设模板
                    applyTemplate()
                }
                .foregroundColor(.purple)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(Color.purple.opacity(0.1))
                .cornerRadius(8)
            }
        }
    }
    
    // MARK: - 辅助方法
    
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
    
    private func setupInitialValues() {
        stopLossPrice = String(format: "%.2f", currentPrice * 0.95)
        takeProfitPrice = String(format: "%.2f", currentPrice * 1.1)
    }
    
    private func calculateStopLossPrice() -> Double {
        guard let percentage = Double(stopLossPercentage) else { return 0 }
        return currentPrice * (1 - percentage / 100)
    }
    
    private func calculateTakeProfitPrice() -> Double {
        guard let percentage = Double(takeProfitPercentage) else { return 0 }
        return currentPrice * (1 + percentage / 100)
    }
    
    private func isValidSettings() -> Bool {
        if isStopLossEnabled {
            if stopLossType == .percentage {
                guard let percentage = Double(stopLossPercentage), percentage > 0, percentage <= 50 else {
                    return false
                }
            } else {
                guard let price = Double(stopLossPrice), price > 0, price < currentPrice else {
                    return false
                }
            }
        }
        
        if isTakeProfitEnabled {
            if takeProfitType == .percentage {
                guard let percentage = Double(takeProfitPercentage), percentage > 0, percentage <= 100 else {
                    return false
                }
            } else {
                guard let price = Double(takeProfitPrice), price > currentPrice else {
                    return false
                }
            }
        }
        
        if isTrailingStopEnabled {
            guard let percentage = Double(trailingStopPercentage), percentage > 0, percentage <= 20 else {
                return false
            }
        }
        
        return isStopLossEnabled || isTakeProfitEnabled || isTrailingStopEnabled
    }
    
    private func generateConfirmMessage() -> String {
        var message = "确认设置以下止损止盈规则：\n\n"
        
        if isStopLossEnabled {
            if stopLossType == .percentage {
                message += "止损：跌幅达到\(stopLossPercentage)%时卖出\n"
            } else {
                message += "止损：价格跌至¥\(stopLossPrice)时卖出\n"
            }
        }
        
        if isTakeProfitEnabled {
            if takeProfitType == .percentage {
                message += "止盈：涨幅达到\(takeProfitPercentage)%时卖出\n"
            } else {
                message += "止盈：价格涨至¥\(takeProfitPrice)时卖出\n"
            }
        }
        
        if isTrailingStopEnabled {
            message += "跟踪止损：保持与最高价\(trailingStopPercentage)%的差距\n"
        }
        
        return message
    }
    
    private func submitSettings() {
        isSubmitting = true
        
        // 模拟网络请求
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            isSubmitting = false
            
            if Bool.random() { // 90% 成功率
                alertMessage = "止损止盈规则设置成功！\n\n系统将在交易时间内监控您的持仓并自动执行相关操作。"
                showSuccessAlert = true
            } else {
                alertMessage = "设置失败，请检查网络连接后重试"
                showErrorAlert = true
            }
        }
    }
    
    private func resetSettings() {
        isStopLossEnabled = false
        isTakeProfitEnabled = false
        isTrailingStopEnabled = false
        stopLossPercentage = "5.0"
        takeProfitPercentage = "10.0"
        trailingStopPercentage = "3.0"
        setupInitialValues()
    }
    
    private func applyTemplate() {
        // 保守型模板
        isStopLossEnabled = true
        stopLossType = .percentage
        stopLossPercentage = "5.0"
        
        isTakeProfitEnabled = true
        takeProfitType = .percentage
        takeProfitPercentage = "10.0"
        
        isTrailingStopEnabled = true
        trailingStopPercentage = "3.0"
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
}

// MARK: - 数据模型

enum StopLossType {
    case percentage, price
}

// MARK: - 预览

#Preview {
    StopLossSettingsView(
        symbol: "600519.SH",
        currentPrice: 1850.00,
        position: PositionRecord(
            symbol: "600519.SH",
            stockName: "贵州茅台",
            quantity: 100,
            availableQuantity: 100,
            avgCost: 1820.00,
            currentPrice: 1850.00,
            lastUpdateTime: Date()
        )
    )
    .environmentObject(RiskManager())
}
