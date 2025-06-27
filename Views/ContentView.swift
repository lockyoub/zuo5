/*
 主界面视图
 作者: MiniMax Agent
 */

import SwiftUI
import CoreData

struct ContentView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var marketDataService: MarketDataService
    @EnvironmentObject private var tradingService: TradingService
    @EnvironmentObject private var strategyEngine: StrategyEngine
    
    @State private var selectedTab: Int = 0
    @State private var showingSettings: Bool = false
    
    var body: some View {
        NavigationView {
            TabView(selection: $selectedTab) {
                // 主面板
                DashboardView()
                    .tabItem {
                        Image(systemName: "chart.line.uptrend.xyaxis")
                        Text("主面板")
                    }
                    .tag(0)
                
                // 交易界面
                TradingView()
                    .tabItem {
                        Image(systemName: "dollarsign.circle")
                        Text("交易")
                    }
                    .tag(1)
                
                // 策略管理
                StrategyView()
                    .tabItem {
                        Image(systemName: "brain.head.profile")
                        Text("策略")
                    }
                    .tag(2)
                
                // 持仓管理
                PositionView()
                    .tabItem {
                        Image(systemName: "briefcase")
                        Text("持仓")
                    }
                    .tag(3)
                
                // 设置
                SettingsView()
                    .tabItem {
                        Image(systemName: "gear")
                        Text("设置")
                    }
                    .tag(4)
            }
            .navigationTitle(tabTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    ConnectionStatusView()
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    MarketStatusView()
                }
            }
        }
        .alert("错误", isPresented: .constant(appState.errorMessage != nil)) {
            Button("确定") {
                appState.clearError()
            }
        } message: {
            Text(appState.errorMessage ?? "")
        }
        .overlay {
            if appState.isLoading {
                LoadingOverlay()
            }
        }
    }
    
    /// 当前标签页标题
    private var tabTitle: String {
        switch selectedTab {
        case 0:
            return "交易面板"
        case 1:
            return "交易操作"
        case 2:
            return "策略管理"
        case 3:
            return "持仓管理"
        case 4:
            return "系统设置"
        default:
            return "股票交易系统"
        }
    }
}

/// 连接状态视图
struct ConnectionStatusView: View {
    @EnvironmentObject private var appState: AppState
    
    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(appState.isConnected ? Color.green : Color.red)
                .frame(width: 8, height: 8)
            
            Text(appState.isConnected ? "已连接" : "未连接")
                .font(.caption)
                .foregroundColor(appState.isConnected ? .green : .red)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
    }
}

/// 市场状态视图
struct MarketStatusView: View {
    @EnvironmentObject private var appState: AppState
    
    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(appState.currentMarketStatus.color)
                .frame(width: 8, height: 8)
            
            Text(appState.currentMarketStatus.displayName)
                .font(.caption)
                .foregroundColor(appState.currentMarketStatus.color)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
    }
}

/// 加载覆盖层
struct LoadingOverlay: View {
    var body: some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()
            
            VStack(spacing: 16) {
                ProgressView()
                    .scaleEffect(1.5)
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                
                Text("加载中...")
                    .font(.headline)
                    .foregroundColor(.white)
            }
            .padding(32)
            .background(Color.black.opacity(0.7))
            .cornerRadius(12)
        }
    }
}

#Preview {
    ContentView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
        .environmentObject(AppState())
        .environmentObject(MarketDataService())
        .environmentObject(TradingService())
        .environmentObject(StrategyEngine())
}
