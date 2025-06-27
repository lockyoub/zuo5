/*
 iOS应用最终配置文件
 服务器IP: 8.130.172.202
 作者: MiniMax Agent
 创建时间: 2025-06-27
 */

import Foundation

// MARK: - 服务器配置（您的具体IP地址）
struct APIConfig {
    static let baseURL = "http://8.130.172.202:8000"
    static let apiVersion = "/api"
    static let websocketURL = "ws://8.130.172.202:8000/ws/market"
    static let timeout: TimeInterval = 30
}

// MARK: - 具体的API端点
extension APIConfig {
    // 健康检查
    static let healthCheck = "\(baseURL)/health"
    
    // 股票相关API
    struct StockAPI {
        static let list = "\(baseURL)\(apiVersion)/stocks/list"
        static func quote(symbol: String) -> String {
            return "\(baseURL)\(apiVersion)/stocks/\(symbol)/quote"
        }
        static func orderBook(symbol: String) -> String {
            return "\(baseURL)\(apiVersion)/stocks/\(symbol)/orderbook"
        }
        static func complete(symbol: String) -> String {
            return "\(baseURL)\(apiVersion)/stocks/\(symbol)/complete"
        }
        static func klines(symbol: String) -> String {
            return "\(baseURL)\(apiVersion)/stocks/\(symbol)/klines"
        }
    }
    
    // 系统API
    struct SystemAPI {
        static let licenseStatus = "\(baseURL)\(apiVersion)/system/license-status"
    }
}

// MARK: - 配置验证
struct ConfigValidator {
    static func validateConfiguration() -> Bool {
        // 检查URL格式
        guard URL(string: APIConfig.baseURL) != nil else {
            print("❌ 无效的基础URL: \(APIConfig.baseURL)")
            return false
        }
        
        guard URL(string: APIConfig.websocketURL) != nil else {
            print("❌ 无效的WebSocket URL: \(APIConfig.websocketURL)")
            return false
        }
        
        print("✅ 配置验证通过")
        print("📡 服务器地址: \(APIConfig.baseURL)")
        print("🔌 WebSocket地址: \(APIConfig.websocketURL)")
        
        return true
    }
    
    static func printConfigurationInfo() {
        print("=== iOS应用服务器配置信息 ===")
        print("服务器IP: 8.130.172.202")
        print("端口: 8000")
        print("HTTP URL: \(APIConfig.baseURL)")
        print("WebSocket URL: \(APIConfig.websocketURL)")
        print("API版本: \(APIConfig.apiVersion)")
        print("请求超时: \(APIConfig.timeout)秒")
        print("===============================")
    }
}

// MARK: - 快速连接测试
class QuickConnectionTest {
    static func testServerConnection() async -> Bool {
        guard let url = URL(string: APIConfig.healthCheck) else {
            print("❌ URL创建失败")
            return false
        }
        
        do {
            print("🔍 正在测试连接到: \(APIConfig.healthCheck)")
            
            let request = URLRequest(url: url, timeoutInterval: 10)
            let (_, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                let statusCode = httpResponse.statusCode
                print("📡 服务器响应状态码: \(statusCode)")
                
                if statusCode == 200 {
                    print("✅ 服务器连接成功！")
                    return true
                } else {
                    print("⚠️ 服务器响应异常，状态码: \(statusCode)")
                    return false
                }
            } else {
                print("❌ 无效的HTTP响应")
                return false
            }
        } catch {
            print("❌ 连接失败: \(error.localizedDescription)")
            return false
        }
    }
}

// MARK: - 使用示例和测试
/*
 在您的应用中使用这个配置：
 
 1. 在AppDelegate或主视图中验证配置：
 */
func setupApplication() {
    // 验证配置
    guard ConfigValidator.validateConfiguration() else {
        fatalError("配置验证失败")
    }
    
    // 打印配置信息
    ConfigValidator.printConfigurationInfo()
    
    // 测试连接（可选）
    Task {
        let isConnected = await QuickConnectionTest.testServerConnection()
        if isConnected {
            print("🎉 应用已成功连接到服务器")
        } else {
            print("⚠️ 应用无法连接到服务器，请检查网络设置")
        }
    }
}

/*
 2. 在网络服务中使用：
 */
func getStockQuote(symbol: String) async throws {
    let url = APIConfig.StockAPI.quote(symbol: symbol)
    print("📊 获取股票行情: \(url)")
    // 您的网络请求代码...
}

func getOrderBook(symbol: String) async throws {
    let url = APIConfig.StockAPI.orderBook(symbol: symbol)
    print("📈 获取盘口数据: \(url)")
    // 您的网络请求代码...
}
