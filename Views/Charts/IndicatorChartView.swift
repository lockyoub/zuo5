//
//  IndicatorChartView.swift
//  StockTradingApp
//
//  Created by MiniMax Agent on 2025-06-24.
//  技术指标图表组件 - 支持多种技术指标的叠加显示
//

import SwiftUI
import Charts

/// 技术指标图表视图
struct IndicatorChartView: View {
    let indicatorData: [String: [IndicatorData]]
    let selectedTimestamp: Date?
    @State private var selectedIndicator: TechnicalIndicatorType = .macd
    
    var body: some View {
        VStack(spacing: 0) {
            // 指标选择器
            indicatorSelector
            
            // 指标图表
            indicatorChart
            
            // 指标数值显示
            indicatorValues
        }
        .background(Color.black)
    }
    
    // MARK: - 指标选择器
    private var indicatorSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(Array(indicatorData.keys), id: \.self) { key in
                    if let indicatorType = TechnicalIndicatorType(rawValue: key) {
                        IndicatorButton(
                            indicator: indicatorType,
                            isSelected: selectedIndicator == indicatorType
                        ) {
                            selectedIndicator = indicatorType
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
        }
        .frame(height: 40)
    }
    
    // MARK: - 指标图表
    private var indicatorChart: some View {
        Group {
            switch selectedIndicator {
            case .ma, .ema:
                movingAverageChart
            case .macd:
                macdChart
            case .rsi:
                rsiChart
            case .bollinger:
                bollingerChart
            case .kdj:
                kdjChart
            }
        }
        .frame(height: 120)
        .padding(.horizontal, 16)
    }
    
    // MARK: - 移动平均线图表
    private var movingAverageChart: some View {
        Chart {
            if let data = indicatorData[selectedIndicator.rawValue] {
                ForEach(data) { point in
                    // 主线
                    LineMark(
                        x: .value("时间", point.timestamp),
                        y: .value("MA1", point.value)
                    )
                    .foregroundStyle(.blue)
                    .lineStyle(StrokeStyle(lineWidth: 1))
                    
                    // 副线
                    if let secondaryValue = point.secondaryValue {
                        LineMark(
                            x: .value("时间", point.timestamp),
                            y: .value("MA2", secondaryValue)
                        )
                        .foregroundStyle(.orange)
                        .lineStyle(StrokeStyle(lineWidth: 1))
                    }
                }
            }
        }
        .chartYAxis {
            AxisMarks(position: .trailing) { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                    .foregroundStyle(.gray.opacity(0.3))
                AxisValueLabel {
                    if let price = value.as(Double.self) {
                        Text(String(format: "%.2f", price))
                            .foregroundColor(.white)
                            .font(.caption2)
                    }
                }
            }
        }
        .chartXAxis(.hidden)
    }
    
    // MARK: - MACD图表
    private var macdChart: some View {
        Chart {
            if let data = indicatorData[selectedIndicator.rawValue] {
                ForEach(data) { point in
                    // MACD线
                    LineMark(
                        x: .value("时间", point.timestamp),
                        y: .value("MACD", point.value)
                    )
                    .foregroundStyle(.blue)
                    .lineStyle(StrokeStyle(lineWidth: 1))
                    
                    // 信号线
                    if let signalValue = point.secondaryValue {
                        LineMark(
                            x: .value("时间", point.timestamp),
                            y: .value("Signal", signalValue)
                        )
                        .foregroundStyle(.orange)
                        .lineStyle(StrokeStyle(lineWidth: 1))
                    }
                    
                    // 柱状图（直方图）
                    if let histogramValue = point.thirdValue {
                        BarMark(
                            x: .value("时间", point.timestamp),
                            y: .value("Histogram", histogramValue)
                        )
                        .foregroundStyle(histogramValue >= 0 ? .green : .red)
                        .opacity(0.6)
                    }
                }
            }
        }
        .chartYAxis {
            AxisMarks(position: .trailing) { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                    .foregroundStyle(.gray.opacity(0.3))
                AxisValueLabel {
                    if let macdValue = value.as(Double.self) {
                        Text(String(format: "%.3f", macdValue))
                            .foregroundColor(.white)
                            .font(.caption2)
                    }
                }
            }
        }
        .chartXAxis(.hidden)
    }
    
    // MARK: - RSI图表
    private var rsiChart: some View {
        Chart {
            // RSI超买超卖区域
            RectangleMark(
                yStart: .value("超买", 70),
                yEnd: .value("极限", 100)
            )
            .foregroundStyle(.red.opacity(0.1))
            
            RectangleMark(
                yStart: .value("极限", 0),
                yEnd: .value("超卖", 30)
            )
            .foregroundStyle(.green.opacity(0.1))
            
            // RSI线
            if let data = indicatorData[selectedIndicator.rawValue] {
                ForEach(data) { point in
                    LineMark(
                        x: .value("时间", point.timestamp),
                        y: .value("RSI", point.value)
                    )
                    .foregroundStyle(.purple)
                    .lineStyle(StrokeStyle(lineWidth: 2))
                }
            }
        }
        .chartYScale(domain: 0...100)
        .chartYAxis {
            AxisMarks(position: .trailing, values: [0, 30, 50, 70, 100]) { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                    .foregroundStyle(.gray.opacity(0.3))
                AxisValueLabel {
                    if let rsiValue = value.as(Double.self) {
                        Text(String(format: "%.0f", rsiValue))
                            .foregroundColor(.white)
                            .font(.caption2)
                    }
                }
            }
        }
        .chartXAxis(.hidden)
    }
    
    // MARK: - 布林带图表
    private var bollingerChart: some View {
        Chart {
            if let data = indicatorData[selectedIndicator.rawValue] {
                ForEach(data) { point in
                    // 上轨
                    LineMark(
                        x: .value("时间", point.timestamp),
                        y: .value("Upper", point.value)
                    )
                    .foregroundStyle(.red)
                    .lineStyle(StrokeStyle(lineWidth: 1))
                    
                    // 中轨
                    if let middleValue = point.secondaryValue {
                        LineMark(
                            x: .value("时间", point.timestamp),
                            y: .value("Middle", middleValue)
                        )
                        .foregroundStyle(.blue)
                        .lineStyle(StrokeStyle(lineWidth: 1))
                    }
                    
                    // 下轨
                    if let lowerValue = point.thirdValue {
                        LineMark(
                            x: .value("时间", point.timestamp),
                            y: .value("Lower", lowerValue)
                        )
                        .foregroundStyle(.green)
                        .lineStyle(StrokeStyle(lineWidth: 1))
                    }
                }
            }
        }
        .chartYAxis {
            AxisMarks(position: .trailing) { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                    .foregroundStyle(.gray.opacity(0.3))
                AxisValueLabel {
                    if let price = value.as(Double.self) {
                        Text(String(format: "%.2f", price))
                            .foregroundColor(.white)
                            .font(.caption2)
                    }
                }
            }
        }
        .chartXAxis(.hidden)
    }
    
    // MARK: - KDJ图表
    private var kdjChart: some View {
        Chart {
            if let data = indicatorData[selectedIndicator.rawValue] {
                ForEach(data) { point in
                    // K线
                    LineMark(
                        x: .value("时间", point.timestamp),
                        y: .value("K", point.value)
                    )
                    .foregroundStyle(.blue)
                    .lineStyle(StrokeStyle(lineWidth: 1))
                    
                    // D线
                    if let dValue = point.secondaryValue {
                        LineMark(
                            x: .value("时间", point.timestamp),
                            y: .value("D", dValue)
                        )
                        .foregroundStyle(.orange)
                        .lineStyle(StrokeStyle(lineWidth: 1))
                    }
                    
                    // J线
                    if let jValue = point.thirdValue {
                        LineMark(
                            x: .value("时间", point.timestamp),
                            y: .value("J", jValue)
                        )
                        .foregroundStyle(.purple)
                        .lineStyle(StrokeStyle(lineWidth: 1))
                    }
                }
            }
        }
        .chartYScale(domain: 0...100)
        .chartYAxis {
            AxisMarks(position: .trailing, values: [0, 20, 50, 80, 100]) { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                    .foregroundStyle(.gray.opacity(0.3))
                AxisValueLabel {
                    if let kdjValue = value.as(Double.self) {
                        Text(String(format: "%.0f", kdjValue))
                            .foregroundColor(.white)
                            .font(.caption2)
                    }
                }
            }
        }
        .chartXAxis(.hidden)
    }
    
    // MARK: - 指标数值显示
    private var indicatorValues: some View {
        HStack {
            if let data = indicatorData[selectedIndicator.rawValue],
               let latestData = data.last {
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(selectedIndicator.displayName)
                        .font(.caption)
                        .foregroundColor(.white)
                    
                    HStack {
                        indicatorValueLabels(for: latestData)
                    }
                }
            }
            
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color.gray.opacity(0.1))
    }
    
    @ViewBuilder
    private func indicatorValueLabels(for data: IndicatorData) -> some View {
        switch selectedIndicator {
        case .ma, .ema:
            VStack(alignment: .leading) {
                Text("\(selectedIndicator == .ma ? "MA20" : "EMA12"): \(String(format: "%.2f", data.value))")
                    .font(.caption2)
                    .foregroundColor(.blue)
                if let secondary = data.secondaryValue {
                    Text("\(selectedIndicator == .ma ? "MA60" : "EMA26"): \(String(format: "%.2f", secondary))")
                        .font(.caption2)
                        .foregroundColor(.orange)
                }
            }
            
        case .macd:
            VStack(alignment: .leading) {
                Text("MACD: \(String(format: "%.3f", data.value))")
                    .font(.caption2)
                    .foregroundColor(.blue)
                if let signal = data.secondaryValue {
                    Text("Signal: \(String(format: "%.3f", signal))")
                        .font(.caption2)
                        .foregroundColor(.orange)
                }
                if let histogram = data.thirdValue {
                    Text("Hist: \(String(format: "%.3f", histogram))")
                        .font(.caption2)
                        .foregroundColor(histogram >= 0 ? .green : .red)
                }
            }
            
        case .rsi:
            Text("RSI: \(String(format: "%.1f", data.value))")
                .font(.caption2)
                .foregroundColor(data.value > 70 ? .red : (data.value < 30 ? .green : .purple))
            
        case .bollinger:
            VStack(alignment: .leading) {
                Text("Upper: \(String(format: "%.2f", data.value))")
                    .font(.caption2)
                    .foregroundColor(.red)
                if let middle = data.secondaryValue {
                    Text("Middle: \(String(format: "%.2f", middle))")
                        .font(.caption2)
                        .foregroundColor(.blue)
                }
                if let lower = data.thirdValue {
                    Text("Lower: \(String(format: "%.2f", lower))")
                        .font(.caption2)
                        .foregroundColor(.green)
                }
            }
            
        case .kdj:
            VStack(alignment: .leading) {
                Text("K: \(String(format: "%.1f", data.value))")
                    .font(.caption2)
                    .foregroundColor(.blue)
                if let d = data.secondaryValue {
                    Text("D: \(String(format: "%.1f", d))")
                        .font(.caption2)
                        .foregroundColor(.orange)
                }
                if let j = data.thirdValue {
                    Text("J: \(String(format: "%.1f", j))")
                        .font(.caption2)
                        .foregroundColor(.purple)
                }
            }
        }
    }
}

// MARK: - 指标选择按钮
struct IndicatorButton: View {
    let indicator: TechnicalIndicatorType
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(indicator.displayName)
                .font(.caption)
                .foregroundColor(isSelected ? .black : .white)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? Color.white : Color.clear)
                .cornerRadius(4)
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(Color.white, lineWidth: 1)
                )
        }
    }
}

// MARK: - 扩展
extension TechnicalIndicatorType {
    var displayName: String {
        switch self {
        case .ma: return "MA"
        case .ema: return "EMA"
        case .macd: return "MACD"
        case .rsi: return "RSI"
        case .bollinger: return "BOLL"
        case .kdj: return "KDJ"
        }
    }
}

// MARK: - 预览
struct IndicatorChartView_Previews: PreviewProvider {
    static var previews: some View {
        let sampleData: [String: [IndicatorData]] = [
            "rsi": (0..<50).map { index in
                IndicatorData(
                    timestamp: Date().addingTimeInterval(TimeInterval(index * 300)),
                    value: Double.random(in: 20...80),
                    type: .rsi
                )
            }
        ]
        
        IndicatorChartView(
            indicatorData: sampleData,
            selectedTimestamp: nil
        )
        .background(Color.black)
        .preferredColorScheme(.dark)
    }
}
