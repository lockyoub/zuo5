/*
 多周期股票做T交易系统 - iOS原生应用
 主应用文件
 作者: MiniMax Agent
 创建时间: 2025-06-24 14:32:13
 */

import SwiftUI
import CoreData
import UserNotifications

@main
struct StockTradingApp: App {
    // Core Data容器
    let persistenceController = PersistenceController.shared
    
    // 应用状态管理
    @StateObject private var appState = AppState()
    @StateObject private var marketDataService = MarketDataService()
    @StateObject private var tradingService = TradingService()
    @StateObject private var strategyEngine = StrategyEngine()
    
    // 通知管理
    @StateObject private var notificationManager = NotificationManager.shared
    @StateObject private var pushNotificationService = PushNotificationService.shared
    
    // 应用委托
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
                .environmentObject(appState)
                .environmentObject(marketDataService)
                .environmentObject(tradingService)
                .environmentObject(strategyEngine)
                .onAppear {
                    setupApp()
                }
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)) { _ in
                    saveContext()
                }
        }
    }
    
    /// 应用初始化设置
    private func setupApp() {
        // 配置应用启动参数
        configureAppearance()
        
        // 启动核心服务
        startCoreServices()
        
        // 注册推送通知
        registerForPushNotifications()
    }
    
    /// 配置应用外观
    private func configureAppearance() {
        // 设置导航栏样式
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor.systemBackground
        appearance.titleTextAttributes = [.foregroundColor: UIColor.label]
        
        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
    }
    
    /// 启动核心服务
    private func startCoreServices() {
        Task {
            await marketDataService.start()
            await tradingService.start()
            await strategyEngine.start()
        }
    }
    
    /// 注册推送通知
    private func registerForPushNotifications() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            if granted {
                DispatchQueue.main.async {
                    UIApplication.shared.registerForRemoteNotifications()
                }
            }
        }
    }
    
    /// 保存Core Data上下文
    private func saveContext() {
        let context = persistenceController.container.viewContext
        
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                print("保存数据失败: \(error)")
            }
        }
    }
}

/// 应用全局状态管理
class AppState: ObservableObject {
    @Published var isConnected: Bool = false
    @Published var currentMarketStatus: MarketStatus = .closed
    @Published var notifications: [AppNotification] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String? = nil
    
    /// 添加通知
    func addNotification(_ notification: AppNotification) {
        DispatchQueue.main.async {
            self.notifications.append(notification)
        }
    }
    
    /// 清除通知
    func clearNotifications() {
        notifications.removeAll()
    }
    
    /// 设置错误消息
    func setError(_ message: String) {
        DispatchQueue.main.async {
            self.errorMessage = message
        }
    }
    
    /// 清除错误消息
    func clearError() {
        errorMessage = nil
    }
}

/// 应用通知模型
struct AppNotification: Identifiable {
    let id = UUID()
    let title: String
    let message: String
    let type: NotificationType
    let timestamp: Date = Date()
    
    enum NotificationType {
        case info
        case warning
        case error
        case trading
    }
}

/// 市场状态枚举
enum MarketStatus {
    case beforeOpen    // 开盘前
    case open         // 开盘中
    case pause        // 暂停
    case closed       // 收盘
    case afterClose   // 收盘后
    
    var displayName: String {
        switch self {
        case .beforeOpen:
            return "开盘前"
        case .open:
            return "开盘中"
        case .pause:
            return "暂停"
        case .closed:
            return "收盘"
        case .afterClose:
            return "收盘后"
        }
    }
    
    var color: Color {
        switch self {
        case .beforeOpen:
            return .orange
        case .open:
            return .green
        case .pause:
            return .yellow
        case .closed:
            return .red
        case .afterClose:
            return .gray
        }
    }
}

// MARK: - 应用委托
class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        // 配置推送通知
        Task {
            await NotificationManager.shared.requestAuthorization()
        }
        
        return true
    }
    
    // MARK: - 推送通知处理
    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        PushNotificationService.shared.handleDeviceTokenRegistration(deviceToken: deviceToken)
    }
    
    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        PushNotificationService.shared.handleRegistrationError(error)
    }
    
    func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable: Any],
        fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        let handled = PushNotificationService.shared.handleRemoteNotification(userInfo)
        completionHandler(handled ? .newData : .noData)
    }
}
