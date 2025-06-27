/*
 服务器连接测试视图
 用于验证iOS应用是否能正确连接到服务器 8.130.172.202
 作者: MiniMax Agent
 创建时间: 2025-06-27
 */

import SwiftUI
import Foundation

struct ConnectionTestView: View {
    @State private var testResults: [TestResult] = []
    @State private var isTestingInProgress = false
    @State private var currentTest = ""
    
    struct TestResult {
        let name: String
        let url: String
        let status: TestStatus
        let message: String
        let timestamp: Date
    }
    
    enum TestStatus {
        case pending
        case success
        case failed
        case testing
        
        var color: Color {
            switch self {
            case .pending: return .gray
            case .success: return .green
            case .failed: return .red
            case .testing: return .blue
            }
        }
        
        var icon: String {
            switch self {
            case .pending: return "clock"
            case .success: return "checkmark.circle.fill"
            case .failed: return "xmark.circle.fill"
            case .testing: return "arrow.clockwise"
            }
        }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // 服务器信息
                serverInfoSection
                
                // 测试按钮
                testButtonSection
                
                // 测试结果列表
                testResultsList
                
                Spacer()
            }
            .navigationTitle("连接测试")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                initializeTests()
            }
        }
    }
    
    // MARK: - 服务器信息区域
    private var serverInfoSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "server.rack")
                    .foregroundColor(.blue)
                Text("服务器信息")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 4) {
                InfoRow(label: "服务器IP", value: "8.130.172.202")
                InfoRow(label: "端口", value: "8000")
                InfoRow(label: "HTTP地址", value: APIConfig.baseURL)
                InfoRow(label: "WebSocket地址", value: APIConfig.websocketURL)
            }
        }
        .padding()
        .background(Color(UIColor.systemGray6))
        .cornerRadius(12)
        .padding(.horizontal)
        .padding(.top)
    }
    
    // MARK: - 测试按钮区域
    private var testButtonSection: some View {
        VStack(spacing: 12) {
            if isTestingInProgress {
                VStack(spacing: 8) {
                    ProgressView()
                        .scaleEffect(1.2)
                    Text("正在测试: \(currentTest)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
            } else {
                HStack(spacing: 16) {
                    Button("开始测试") {
                        runAllTests()
                    }
                    .buttonStyle(.borderedProminent)
                    
                    Button("清除结果") {
                        clearResults()
                    }
                    .buttonStyle(.bordered)
                }
                .padding()
            }
        }
    }
    
    // MARK: - 测试结果列表
    private var testResultsList: some View {
        List {
            ForEach(testResults.indices, id: \.self) { index in
                TestResultRow(result: testResults[index])
            }
        }
        .listStyle(PlainListStyle())
    }
    
    // MARK: - 初始化测试项
    private func initializeTests() {
        testResults = [
            TestResult(name: "健康检查", url: "\(APIConfig.baseURL)/health", status: .pending, message: "等待测试", timestamp: Date()),
            TestResult(name: "股票列表API", url: "\(APIConfig.baseURL)/api/stocks/list", status: .pending, message: "等待测试", timestamp: Date()),
            TestResult(name: "股票行情API", url: "\(APIConfig.baseURL)/api/stocks/000001.SZ/quote", status: .pending, message: "等待测试", timestamp: Date()),
            TestResult(name: "盘口数据API", url: "\(APIConfig.baseURL)/api/stocks/000001.SZ/orderbook", status: .pending, message: "等待测试", timestamp: Date()),
            TestResult(name: "WebSocket连接", url: APIConfig.websocketURL, status: .pending, message: "等待测试", timestamp: Date())
        ]
    }
    
    // MARK: - 运行所有测试
    private func runAllTests() {
        isTestingInProgress = true
        
        Task {
            for index in testResults.indices {
                await MainActor.run {
                    currentTest = testResults[index].name
                    testResults[index] = TestResult(
                        name: testResults[index].name,
                        url: testResults[index].url,
                        status: .testing,
                        message: "测试中...",
                        timestamp: Date()
                    )
                }
                
                // 执行测试
                let result = await performTest(testResults[index])
                
                await MainActor.run {
                    testResults[index] = result
                }
                
                // 测试间隔
                try? await Task.sleep(nanoseconds: 500_000_000) // 0.5秒
            }
            
            await MainActor.run {
                isTestingInProgress = false
                currentTest = ""
            }
        }
    }
    
    // MARK: - 执行单个测试
    private func performTest(_ test: TestResult) async -> TestResult {
        if test.name == "WebSocket连接" {
            return await testWebSocketConnection(test)
        } else {
            return await testHTTPConnection(test)
        }
    }
    
    // MARK: - HTTP连接测试
    private func testHTTPConnection(_ test: TestResult) async -> TestResult {
        guard let url = URL(string: test.url) else {
            return TestResult(
                name: test.name,
                url: test.url,
                status: .failed,
                message: "无效的URL",
                timestamp: Date()
            )
        }
        
        do {
            let request = URLRequest(url: url, timeoutInterval: 10)
            let (_, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                let statusCode = httpResponse.statusCode
                if statusCode == 200 {
                    return TestResult(
                        name: test.name,
                        url: test.url,
                        status: .success,
                        message: "连接成功 (状态码: \(statusCode))",
                        timestamp: Date()
                    )
                } else {
                    return TestResult(
                        name: test.name,
                        url: test.url,
                        status: .failed,
                        message: "HTTP错误 (状态码: \(statusCode))",
                        timestamp: Date()
                    )
                }
            } else {
                return TestResult(
                    name: test.name,
                    url: test.url,
                    status: .failed,
                    message: "无效的HTTP响应",
                    timestamp: Date()
                )
            }
        } catch {
            return TestResult(
                name: test.name,
                url: test.url,
                status: .failed,
                message: "连接错误: \(error.localizedDescription)",
                timestamp: Date()
            )
        }
    }
    
    // MARK: - WebSocket连接测试
    private func testWebSocketConnection(_ test: TestResult) async -> TestResult {
        guard let url = URL(string: test.url) else {
            return TestResult(
                name: test.name,
                url: test.url,
                status: .failed,
                message: "无效的WebSocket URL",
                timestamp: Date()
            )
        }
        
        return await withCheckedContinuation { continuation in
            let webSocketTask = URLSession.shared.webSocketTask(with: url)
            
            // 设置超时
            DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                webSocketTask.cancel()
                continuation.resume(returning: TestResult(
                    name: test.name,
                    url: test.url,
                    status: .failed,
                    message: "连接超时",
                    timestamp: Date()
                ))
            }
            
            webSocketTask.resume()
            
            // 尝试发送消息测试连接
            webSocketTask.send(.string("ping")) { error in
                if let error = error {
                    continuation.resume(returning: TestResult(
                        name: test.name,
                        url: test.url,
                        status: .failed,
                        message: "WebSocket错误: \(error.localizedDescription)",
                        timestamp: Date()
                    ))
                } else {
                    webSocketTask.cancel()
                    continuation.resume(returning: TestResult(
                        name: test.name,
                        url: test.url,
                        status: .success,
                        message: "WebSocket连接成功",
                        timestamp: Date()
                    ))
                }
            }
        }
    }
    
    // MARK: - 清除结果
    private func clearResults() {
        initializeTests()
    }
}

// MARK: - 信息行组件
struct InfoRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: 80, alignment: .leading)
            
            Text(value)
                .font(.caption)
                .fontWeight(.medium)
                .lineLimit(1)
                .truncationMode(.middle)
            
            Spacer()
        }
    }
}

// MARK: - 测试结果行组件
struct TestResultRow: View {
    let result: ConnectionTestView.TestResult
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: result.status.icon)
                    .foregroundColor(result.status.color)
                    .frame(width: 20)
                
                Text(result.name)
                    .font(.headline)
                    .fontWeight(.medium)
                
                Spacer()
                
                Text(result.timestamp, style: .time)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            Text(result.message)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(2)
            
            Text(result.url)
                .font(.caption2)
                .foregroundColor(.blue)
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - 预览
struct ConnectionTestView_Previews: PreviewProvider {
    static var previews: some View {
        ConnectionTestView()
    }
}
