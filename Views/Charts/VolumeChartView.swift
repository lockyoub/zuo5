//
//  VolumeChartView.swift
//  StockTradingApp
//
//  Created by MiniMax Agent on 2025-06-24.
//  成交量图表组件 - 与K线图联动显示成交量数据
//

import SwiftUI
import Charts

/// 成交量图表视图
struct VolumeChartView: View {
    let volumeData: [VolumeData]
    let selectedTimestamp: Date?
    
    @State private var maxVolume: Double = 0
    
    var body: some View {
        Chart(volumeData) { data in
            BarMark(
                x: .value("时间", data.timestamp),
                y: .value("成交量", data.volume)
            )
            .foregroundStyle(data.isGreen ? .green : .red)
            .opacity(selectedTimestamp == data.timestamp ? 1.0 : 0.7)
        }
        .chartBackground { proxy in
            // 选中时间的垂直线
            if let selectedTimestamp = selectedTimestamp {
                Rectangle()
                    .fill(Color.white.opacity(0.3))
                    .frame(width: 1)
                    .position(
                        x: proxy.position(forX: selectedTimestamp) ?? 0,
                        y: proxy.plotAreaSize.height / 2
                    )
            }
        }
        .chartXAxis(.hidden) // 隐藏X轴，与主图共享
        .chartYAxis {
            AxisMarks(position: .trailing, values: volumeAxisValues) { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                    .foregroundStyle(.gray.opacity(0.3))
                AxisValueLabel {
                    if let volume = value.as(Double.self) {
                        Text(formatVolume(volume))
                            .foregroundColor(.white)
                            .font(.caption2)
                    }
                }
            }
        }
        .frame(height: 100)
        .onAppear {
            calculateMaxVolume()
        }
        .onChange(of: volumeData) { _ in
            calculateMaxVolume()
        }
    }
    
    // MARK: - 计算轴值
    private var volumeAxisValues: [Double] {
        let step = maxVolume / 4
        return stride(from: 0, through: maxVolume, by: step).map { $0 }
    }
    
    // MARK: - 私有方法
    private func calculateMaxVolume() {
        maxVolume = volumeData.map { $0.volume }.max() ?? 0
    }
    
    private func formatVolume(_ volume: Double) -> String {
        if volume >= 100000000 { // 1亿
            return String(format: "%.1f亿", volume / 100000000)
        } else if volume >= 10000 { // 1万
            return String(format: "%.1f万", volume / 10000)
        } else {
            return String(format: "%.0f", volume)
        }
    }
}

/// 成交量指标视图
struct VolumeIndicatorView: View {
    let volumeData: [VolumeData]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("成交量指标")
                .font(.caption)
                .foregroundColor(.white)
            
            HStack {
                // 当前成交量
                if let latestVolume = volumeData.last {
                    VStack(alignment: .leading) {
                        Text("当前")
                            .font(.caption2)
                            .foregroundColor(.gray)
                        Text(formatVolume(latestVolume.volume))
                            .font(.caption)
                            .foregroundColor(.white)
                    }
                }
                
                Spacer()
                
                // 平均成交量
                VStack(alignment: .trailing) {
                    Text("平均")
                        .font(.caption2)
                        .foregroundColor(.gray)
                    Text(formatVolume(averageVolume))
                        .font(.caption)
                        .foregroundColor(.white)
                }
            }
            
            // 成交量趋势指示器
            VolumeTimeLine()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color.black.opacity(0.3))
    }
    
    private var averageVolume: Double {
        let volumes = volumeData.map { $0.volume }
        return volumes.isEmpty ? 0 : volumes.reduce(0, +) / Double(volumes.count)
    }
    
    private func formatVolume(_ volume: Double) -> String {
        if volume >= 100000000 { // 1亿
            return String(format: "%.1f亿", volume / 100000000)
        } else if volume >= 10000 { // 1万
            return String(format: "%.1f万", volume / 10000)
        } else {
            return String(format: "%.0f", volume)
        }
    }
}

/// 成交量时间线
struct VolumeTimeLine: View {
    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<20, id: \.self) { index in
                Rectangle()
                    .fill(Color.green.opacity(Double.random(in: 0.3...1.0)))
                    .frame(width: 3, height: CGFloat.random(in: 4...12))
            }
        }
    }
}

// MARK: - 预览
struct VolumeChartView_Previews: PreviewProvider {
    static var previews: some View {
        let sampleData = (0..<50).map { index in
            VolumeData(
                timestamp: Date().addingTimeInterval(TimeInterval(index * 300)),
                volume: Double.random(in: 1000000...5000000),
                isGreen: Bool.random()
            )
        }
        
        VStack {
            VolumeChartView(
                volumeData: sampleData,
                selectedTimestamp: sampleData.first?.timestamp
            )
            
            VolumeIndicatorView(volumeData: sampleData)
        }
        .background(Color.black)
        .preferredColorScheme(.dark)
    }
}
