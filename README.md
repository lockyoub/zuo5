# iOS股票交易应用

## 概述

基于SwiftUI开发的现代化iOS股票交易应用，提供实时行情、交易功能、策略回测和风险管理等完整的交易体验。

## 功能特性

### 核心功能
- 📱 **实时行情**: 实时股票价格、涨跌幅显示
- 📊 **K线图表**: 专业的技术分析图表
- 💼 **交易功能**: 买入、卖出股票交易
- 📈 **持仓管理**: 持仓查看、盈亏分析
- 🧠 **策略回测**: 智能交易策略测试
- ⚠️ **风险控制**: 实时风险监控和预警
- 🔄 **数据同步**: 与后端服务实时数据同步

### 技术特性
- SwiftUI现代化界面
- Core Data本地数据存储
- Combine响应式编程
- REST API网络通信
- 图表可视化
- 性能优化

## 系统要求

- iOS 14.0+
- Xcode 13.0+
- Swift 5.5+

## 项目结构

```
StockTradingApp/
├── StockTradingApp.swift    # 应用入口
├── Models/                  # 数据模型
│   ├── Stock.swift         # 股票模型
│   ├── Portfolio.swift     # 持仓模型
│   ├── Trade.swift         # 交易模型
│   └── Strategy.swift      # 策略模型
├── Services/               # 核心服务
│   ├── NetworkService.swift      # 网络服务
│   ├── DataSyncService.swift     # 数据同步
│   ├── TradingService.swift      # 交易服务
│   ├── StrategyEngine.swift      # 策略引擎
│   ├── RiskManager.swift         # 风险管理
│   └── PortfolioManager.swift    # 持仓管理
├── Views/                  # SwiftUI视图
│   ├── ContentView.swift         # 主视图
│   ├── StockListView.swift       # 股票列表
│   ├── ChartView.swift           # 图表视图
│   ├── TradingView.swift         # 交易界面
│   ├── PortfolioView.swift       # 持仓视图
│   └── StrategyView.swift        # 策略界面
├── ViewModels/             # 视图模型
│   ├── StockListViewModel.swift
│   ├── ChartViewModel.swift
│   ├── TradingViewModel.swift
│   └── PortfolioViewModel.swift
├── Utils/                  # 工具类
│   ├── Extensions.swift          # 扩展
│   ├── Constants.swift           # 常量
│   └── Helpers.swift             # 辅助方法
├── Resources/              # 资源文件
│   ├── Assets.xcassets          # 图片资源
│   └── Localizable.strings      # 本地化文件
└── TradingDataModel.xcdatamodeld/ # Core Data模型
```

## 快速开始

### 1. 环境准备

确保已安装：
- Xcode 13.0+
- iOS模拟器或真机设备

### 2. 打开项目

```bash
cd mobile/ios
open StockTradingApp.xcodeproj
```

### 3. 配置后端API

编辑 `Utils/Constants.swift` 中的API基础URL：

```swift
struct APIConstants {
    static let baseURL = "http://your-backend-url:8000"
    static let apiVersion = "/api"
}
```

### 4. 运行应用

在Xcode中选择目标设备并点击运行按钮，或使用快捷键 `Cmd + R`。

## 核心模块详解

### 数据模型 (Models)

#### Stock.swift
```swift
struct Stock: Codable, Identifiable {
    let id: String
    let symbol: String
    let name: String
    let price: Double
    let change: Double
    let changePercent: Double
}
```

#### Portfolio.swift
```swift
struct Portfolio: Codable {
    let holdings: [Holding]
    let totalValue: Double
    let totalReturn: Double
    let totalReturnPercent: Double
}
```

### 服务层 (Services)

#### NetworkService
负责与后端API通信，处理HTTP请求和响应。

#### TradingService
处理交易逻辑，包括买入、卖出订单的创建和执行。

#### StrategyEngine
实现交易策略算法，支持多种技术指标和策略回测。

#### RiskManager
实时监控交易风险，提供风险预警和控制机制。

### 用户界面 (Views)

#### ContentView
应用主界面，包含导航和主要功能入口。

#### StockListView
股票列表显示，支持搜索、排序和筛选功能。

#### ChartView
专业股票图表，支持K线、分时图等多种图表类型。

#### TradingView
交易界面，提供买入、卖出功能和订单管理。

## 数据持久化

应用使用Core Data进行本地数据存储：

### 核心实体

- **StockEntity**: 股票基础信息
- **TradeEntity**: 交易记录
- **PortfolioEntity**: 持仓信息
- **StrategyEntity**: 策略配置

### 数据同步

应用实现了智能数据同步机制：
- 自动同步后端数据
- 离线数据缓存
- 冲突解决策略
- 增量更新

## 网络架构

### API通信

使用URLSession进行HTTP通信：

```swift
class NetworkService: ObservableObject {
    func fetchStocks() async throws -> [Stock] {
        // API调用实现
    }
    
    func executeTradeOrder(_ order: TradeOrder) async throws -> TradeResult {
        // 交易执行实现
    }
}
```

### 错误处理

完善的错误处理机制：
- 网络错误重试
- 用户友好的错误提示
- 日志记录和分析

## 性能优化

### 图表性能
- 使用Charts框架进行高效图表渲染
- 数据虚拟化减少内存占用
- 异步数据加载

### 内存管理
- 适当的对象生命周期管理
- 图片缓存策略
- 后台任务优化

## 测试

### 单元测试

```bash
# 运行单元测试
Cmd + U
```

测试覆盖：
- 模型数据验证
- 服务层业务逻辑
- 网络请求处理
- 数据持久化

### UI测试

自动化UI测试确保用户交互的正确性。

## 发布

### App Store发布

1. 配置证书和描述文件
2. 设置版本号和构建号
3. 创建Archive并上传到App Store Connect
4. 提交审核

### 企业分发

支持企业内部分发，无需App Store审核。

## 故障排除

### 常见问题

1. **编译错误**
   - 检查Xcode版本兼容性
   - 清理构建文件夹: `Cmd + Shift + K`

2. **网络连接问题**
   - 确认后端服务正常运行
   - 检查API URL配置

3. **数据同步问题**
   - 检查Core Data模型版本
   - 验证网络权限设置

### 调试技巧

- 使用Xcode调试器设置断点
- 查看控制台日志输出
- 使用Instruments进行性能分析

## 贡献指南

1. Fork项目仓库
2. 创建功能分支
3. 提交代码变更
4. 创建Pull Request

## 许可证

MIT License

---

更多技术细节请参考代码注释和开发文档。
