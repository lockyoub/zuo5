/*
 快速下单面板
 提供快速买卖操作界面，支持市价单、限价单等多种交易方式
 作者: MiniMax Agent
 创建时间: 2025-06-24 16:21:15
 */

import SwiftUI
import Combine

struct QuickTradingPanel: View {
    @EnvironmentObject private var tradingService: TradingService
    @EnvironmentObject private var marketDataService: MarketDataService
    @EnvironmentObject private var riskManager: RiskManager
    
    let symbol: String
    
    // 交易状态
    @State private var orderType: OrderType = .limit
    @State private var tradeDirection: TradeDirection = .buy
    @State private var quantity: String = "100"
    @State private var price: String = ""
    @State private var isSubmitting = false
    @State private var showConfirmAlert = false
    @State private var showSuccessAlert = false
    @State private var showErrorAlert = false
    @State private var alertMessage = ""
    
    // 快速数量选择
    private let quickQuantities = [100, 200, 500, 1000, 2000, 5000]
    
    // 风险检查结果
    @State private var riskCheckResult: RiskCheckResult?
    
    var body: some View {
        VStack(spacing: 0) {
            // 头部
            headerView
            
            // 交易方向选择
            directionSelector
            
            // 订单类型选择
            orderTypeSelector
            
            // 价格输入
            priceInputSection
            
            // 数量输入
            quantityInputSection
            
            // 风险提示
            if let riskResult = riskCheckResult {
                riskWarningView(riskResult)
            }
            
            // 交易预览
            tradingPreviewSection
            
            // 操作按钮
            actionButtonsSection
        }
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 2)
        .onAppear {
            setupInitialPrice()
            registerForPriceUpdates()
        }
        .onChange(of: quantity) { _ in performRiskCheck() }
        .onChange(of: price) { _ in performRiskCheck() }
        .alert("确认交易", isPresented: $showConfirmAlert) {
            Button("取消", role: .cancel) { }
            Button("确认", role: .destructive) {
                executeOrder()
            }
        } message: {
            Text(generateConfirmMessage())
        }
        .alert("交易成功", isPresented: $showSuccessAlert) {
            Button("确定") { }
        } message: {
            Text(alertMessage)
        }
        .alert("交易失败", isPresented: $showErrorAlert) {
            Button("确定") { }
        } message: {
            Text(alertMessage)
        }
    }
    
    // MARK: - 头部视图
    private var headerView: some View {
        VStack(spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("快速交易")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    Text(symbol)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // 当前价格显示
                if let stockData = marketDataService.stockData[symbol] {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("¥\(stockData.lastPrice, specifier: "%.2f")")
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                        
                        Text("\(stockData.change >= 0 ? "+" : "")\(stockData.changePercent, specifier: "%.2f")%")
                            .font(.caption)
                            .foregroundColor(stockData.change >= 0 ? .red : .green)
                    }
                }
            }
            
            Divider()
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
        .padding(.bottom, 8)
    }
    
    // MARK: - 交易方向选择器
    private var directionSelector: some View {
        VStack(spacing: 8) {
            Text("交易方向")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            HStack(spacing: 12) {
                // 买入按钮
                Button(action: {
                    tradeDirection = .buy
                    performRiskCheck()
                }) {
                    HStack {
                        Image(systemName: "arrow.up.circle.fill")
                        Text("买入")
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(tradeDirection == .buy ? .white : .red)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(tradeDirection == .buy ? .red : .clear)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(.red, lineWidth: 1.5)
                    )
                    .cornerRadius(8)
                }
                
                // 卖出按钮
                Button(action: {
                    tradeDirection = .sell
                    performRiskCheck()
                }) {
                    HStack {
                        Image(systemName: "arrow.down.circle.fill")
                        Text("卖出")
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(tradeDirection == .sell ? .white : .green)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(tradeDirection == .sell ? .green : .clear)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(.green, lineWidth: 1.5)
                    )
                    .cornerRadius(8)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 16)
    }
    
    // MARK: - 订单类型选择器
    private var orderTypeSelector: some View {
        VStack(spacing: 8) {
            Text("订单类型")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            Picker("订单类型", selection: $orderType) {
                Text("限价单").tag(OrderType.limit)
                Text("市价单").tag(OrderType.market)
                Text("止损单").tag(OrderType.stopLoss)
            }
            .pickerStyle(SegmentedPickerStyle())
            .onChange(of: orderType) { _ in
                if orderType == .market {
                    updateMarketPrice()
                }
                performRiskCheck()
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 16)
    }
    
    // MARK: - 价格输入区域
    private var priceInputSection: some View {
        VStack(spacing: 8) {
            HStack {
                Text("交易价格")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                if orderType == .market {
                    Text("市价")
                        .font(.caption)
                        .foregroundColor(.blue)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(4)
                }
            }
            
            HStack(spacing: 12) {
                // 价格输入框
                HStack {
                    Text("¥")
                        .foregroundColor(.secondary)
                    
                    TextField("价格", text: $price)
                        .keyboardType(.decimalPad)
                        .disabled(orderType == .market)
                        .opacity(orderType == .market ? 0.6 : 1.0)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(.systemGray6))
                .cornerRadius(8)
                
                // 快速价格按钮
                if orderType != .market {
                    quickPriceButtons
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 16)
    }
    
    // MARK: - 快速价格按钮
    private var quickPriceButtons: some View {
        HStack(spacing: 6) {
            Button("-5") { adjustPrice(-0.05) }
            Button("-1") { adjustPrice(-0.01) }
            Button("+1") { adjustPrice(0.01) }
            Button("+5") { adjustPrice(0.05) }
        }
        .buttonStyle(QuickAdjustButtonStyle())
    }
    
    // MARK: - 数量输入区域
    private var quantityInputSection: some View {
        VStack(spacing: 8) {
            Text("交易数量")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            // 数量输入框
            HStack {
                TextField("数量", text: $quantity)
                    .keyboardType(.numberPad)
                
                Text("股")
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(.systemGray6))
            .cornerRadius(8)
            
            // 快速数量选择
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 8) {
                ForEach(quickQuantities, id: \.self) { qty in
                    Button("\(qty)股") {
                        quantity = "\(qty)"
                        performRiskCheck()
                    }
                    .font(.caption)
                    .foregroundColor(.blue)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(6)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 16)
    }
    
    // MARK: - 风险警告视图
    private func riskWarningView(_ result: RiskCheckResult) -> some View {
        VStack(spacing: 8) {
            if !result.isValid {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("风险提示")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.orange)
                        
                        Text(result.message)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.orange.opacity(0.1))
                .cornerRadius(8)
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
            }
        }
    }
    
    // MARK: - 交易预览区域
    private var tradingPreviewSection: some View {
        VStack(spacing: 8) {
            Text("交易预览")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            VStack(spacing: 8) {
                previewRow(title: "预计成交金额", value: calculateTotalAmount())
                previewRow(title: "预计手续费", value: calculateCommission())
                previewRow(title: "预计总金额", value: calculateFinalAmount())
                
                if tradeDirection == .buy {
                    previewRow(title: "可用资金", value: formatCurrency(getCurrentAvailableFunds()))
                    previewRow(title: "交易后余额", value: formatCurrency(getCurrentAvailableFunds() - (Double(calculateFinalAmount().dropFirst()) ?? 0)))
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(.systemGray6).opacity(0.5))
            .cornerRadius(8)
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 16)
    }
    
    // MARK: - 预览行
    private func previewRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text(value)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.primary)
        }
    }
    
    // MARK: - 操作按钮区域
    private var actionButtonsSection: some View {
        VStack(spacing: 12) {
            // 主要操作按钮
            Button(action: {
                if isValidOrder() {
                    showConfirmAlert = true
                }
            }) {
                HStack {
                    if isSubmitting {
                        ProgressView()
                            .scaleEffect(0.8)
                            .tint(.white)
                    } else {
                        Image(systemName: tradeDirection == .buy ? "arrow.up" : "arrow.down")
                    }
                    
                    Text(isSubmitting ? "提交中..." : (tradeDirection == .buy ? "立即买入" : "立即卖出"))
                        .fontWeight(.semibold)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    LinearGradient(
                        colors: tradeDirection == .buy ? [.red, .orange] : [.green, .mint],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(10)
                .disabled(isSubmitting || !isValidOrder())
                .opacity(isValidOrder() ? 1.0 : 0.6)
            }
            
            // 辅助按钮
            HStack(spacing: 12) {
                Button("重置") {
                    resetForm()
                }
                .foregroundColor(.blue)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(Color.blue.opacity(0.1))
                .cornerRadius(8)
                
                Button("预约下单") {
                    // 预约下单功能
                    print("预约下单功能开发中...")
                }
                .foregroundColor(.purple)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(Color.purple.opacity(0.1))
                .cornerRadius(8)
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 16)
    }
    
    // MARK: - 业务方法
    
    private func setupInitialPrice() {
        if let stockData = marketDataService.stockData[symbol] {
            price = String(format: "%.2f", stockData.lastPrice)
        }
    }
    
    private func registerForPriceUpdates() {
        NotificationCenter.default.addObserver(
            forName: Notification.Name("SelectedTradingPrice"),
            object: nil,
            queue: .main
        ) { notification in
            if let selectedPrice = notification.userInfo?["price"] as? Double,
               let selectedSymbol = notification.userInfo?["symbol"] as? String,
               selectedSymbol == symbol {
                price = String(format: "%.2f", selectedPrice)
                performRiskCheck()
            }
        }
    }
    
    private func updateMarketPrice() {
        if let stockData = marketDataService.stockData[symbol] {
            price = String(format: "%.2f", stockData.lastPrice)
        }
    }
    
    private func adjustPrice(_ adjustment: Double) {
        if let currentPrice = Double(price) {
            let newPrice = max(0.01, currentPrice + adjustment)
            price = String(format: "%.2f", newPrice)
            performRiskCheck()
        }
    }
    
    private func performRiskCheck() {
        guard let priceValue = Double(price),
              let quantityValue = Int(quantity) else {
            riskCheckResult = RiskCheckResult(isValid: false, message: "请输入有效的价格和数量")
            return
        }
        
        let totalAmount = priceValue * Double(quantityValue)
        let availableFunds = getCurrentAvailableFunds()
        
        if tradeDirection == .buy && totalAmount > availableFunds {
            riskCheckResult = RiskCheckResult(isValid: false, message: "资金不足，可用资金: ¥\(availableFunds, specifier: "%.2f")")
        } else if quantityValue % 100 != 0 {
            riskCheckResult = RiskCheckResult(isValid: false, message: "股票数量必须是100的整数倍")
        } else if quantityValue < 100 {
            riskCheckResult = RiskCheckResult(isValid: false, message: "最小交易数量为100股")
        } else if totalAmount > 1000000 {
            riskCheckResult = RiskCheckResult(isValid: false, message: "单笔交易金额不能超过100万元")
        } else {
            riskCheckResult = RiskCheckResult(isValid: true, message: "")
        }
    }
    
    private func isValidOrder() -> Bool {
        return riskCheckResult?.isValid == true && !price.isEmpty && !quantity.isEmpty
    }
    
    private func executeOrder() {
        isSubmitting = true
        
        // 模拟订单提交
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            isSubmitting = false
            
            if Bool.random() { // 90% 成功率
                alertMessage = "订单提交成功！\n\n订单号: \(generateOrderId())\n股票: \(symbol)\n数量: \(quantity)股\n价格: ¥\(price)"
                showSuccessAlert = true
                resetForm()
            } else {
                alertMessage = "订单提交失败，请重试"
                showErrorAlert = true
            }
        }
    }
    
    private func generateConfirmMessage() -> String {
        let direction = tradeDirection == .buy ? "买入" : "卖出"
        let orderTypeText = orderType == .market ? "市价单" : "限价单"
        return "\(direction) \(symbol)\n数量: \(quantity)股\n价格: ¥\(price)\n类型: \(orderTypeText)\n\n确认提交订单吗？"
    }
    
    private func generateOrderId() -> String {
        let timestamp = Int(Date().timeIntervalSince1970)
        return "ORD\(timestamp)\(Int.random(in: 1000...9999))"
    }
    
    private func resetForm() {
        quantity = "100"
        setupInitialPrice()
        orderType = .limit
        riskCheckResult = nil
    }
    
    private func calculateTotalAmount() -> String {
        guard let priceValue = Double(price),
              let quantityValue = Int(quantity) else {
            return "¥0.00"
        }
        
        let total = priceValue * Double(quantityValue)
        return formatCurrency(total)
    }
    
    private func calculateCommission() -> String {
        guard let priceValue = Double(price),
              let quantityValue = Int(quantity) else {
            return "¥0.00"
        }
        
        let total = priceValue * Double(quantityValue)
        let commission = total * 0.0003 // 0.03% 手续费
        return formatCurrency(commission)
    }
    
    private func calculateFinalAmount() -> String {
        guard let priceValue = Double(price),
              let quantityValue = Int(quantity) else {
            return "¥0.00"
        }
        
        let total = priceValue * Double(quantityValue)
        let commission = total * 0.0003
        return formatCurrency(total + commission)
    }
    
    private func formatCurrency(_ amount: Double) -> String {
        return "¥\(amount, specifier: "%.2f")"
    }
    
    private func getCurrentAvailableFunds() -> Double {
        // 模拟可用资金
        return 100000.0
    }
}

// MARK: - 数据模型

enum OrderType: CaseIterable {
    case limit, market, stopLoss
    
    var displayName: String {
        switch self {
        case .limit: return "限价单"
        case .market: return "市价单"
        case .stopLoss: return "止损单"
        }
    }
}

enum TradeDirection {
    case buy, sell
}

struct RiskCheckResult {
    let isValid: Bool
    let message: String
}

// MARK: - 自定义样式

struct QuickAdjustButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.caption2)
            .foregroundColor(.blue)
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
            .background(Color.blue.opacity(configuration.isPressed ? 0.3 : 0.1))
            .cornerRadius(4)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - 预览

#Preview {
    VStack {
        QuickTradingPanel(symbol: "600519.SH")
            .padding()
        
        Spacer()
    }
    .environmentObject(TradingService())
    .environmentObject(MarketDataService())
    .environmentObject(RiskManager())
    .background(Color(.systemGroupedBackground))
}
