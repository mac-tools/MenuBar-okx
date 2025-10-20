import Foundation

// API响应数据结构
struct APIResponse: Codable {
    let code: String
    let data: [CryptoData]
}

struct CryptoData: Codable {
    let name: String
    let last: Double
    let status: Double
}

struct StockData {
    let name: String
    let price: Double
    let change: Double
    let changePercent: Double
    let isUp: Bool
    
    var formattedPrice: String {
        return String(format: "%.1f", price)
    }
    
    var formattedChange: String {
        let sign = isUp ? "+" : ""
        return String(format: "%@%.2f", sign, change)
    }
    
    var formattedChangePercent: String {
        let sign = isUp ? "+" : ""
        return String(format: "%@%.2f%%", sign, changePercent)
    }
    
    var displayName: String {
        // 简化显示名称，只显示主要部分
        if name.contains("BTC") {
            return "BTC"
        } else if name.contains("ETH") {
            return "ETH"
        } else {
            return String(name.prefix(3))
        }
    }
}

class StockSimulator {
    private let apiURL = "http://43.156.141.216:10001"
    private var lastPrice: Double = 0.0
    private var cachedData: StockData?
    private var isRequesting: Bool = false
    
    // 多数据轮播相关属性
    private var allCachedData: [StockData] = []
    private var currentDisplayIndex: Int = 0
    private var rotationTimer: Timer?
    private let rotationInterval: TimeInterval = 2.0 // 8秒轮播一次
    private var isRotationActive: Bool = false // 轮播状态标记
    
    func generateRandomStockData() -> StockData {
        // 如果有多个缓存数据，返回当前轮播的数据
        if !allCachedData.isEmpty {
            let currentData = allCachedData[currentDisplayIndex]
            
            // 如果不在请求中，异步获取新数据
            if !isRequesting {
                fetchRealTimeData()
            }
            
            return currentData
        }
        
        // 如果正在请求中，返回单个缓存数据
        if isRequesting, let cached = cachedData {
            return cached
        }
        
        // 异步获取新数据
        fetchRealTimeData()
        
        // 如果有缓存数据，返回缓存数据
        if let cached = cachedData {
            return cached
        }
        
        // 如果没有缓存数据，同步获取一次数据
        return fetchRealTimeDataSync()
    }
    
    private func fetchRealTimeDataSync() -> StockData {
        guard let url = URL(string: apiURL) else {
            return createFallbackData()
        }
        
        let semaphore = DispatchSemaphore(value: 0)
        var result: StockData?
        
        let task = URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            defer { semaphore.signal() }
            
            guard let self = self,
                  let data = data,
                  error == nil else {
                return
            }
            
            do {
                let apiResponse = try JSONDecoder().decode(APIResponse.self, from: data)
                if let cryptoData = apiResponse.data.first {
                    result = self.convertToStockData(cryptoData)
                }
            } catch {
                print("解析数据失败: \(error)")
            }
        }
        
        task.resume()
        
        // 等待最多2秒
        let timeout = DispatchTime.now() + .seconds(2)
        if semaphore.wait(timeout: timeout) == .timedOut {
            print("API请求超时")
            return createFallbackData()
        }
        
        return result ?? createFallbackData()
    }
    
    private func fetchRealTimeData() {
        // 如果已经在请求中，直接返回
        guard !isRequesting else { 
            NSLog("已有请求在进行中，跳过本次请求")
            return 
        }
        
        guard let url = URL(string: apiURL) else { 
            NSLog("URL 创建失败: \(apiURL)")
            return 
        }
        
        NSLog("开始网络请求: \(apiURL)")
        isRequesting = true
        
        URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            defer {
                DispatchQueue.main.async {
                    self?.isRequesting = false
                    NSLog("网络请求完成，重置请求状态")
                }
            }
            
            guard let self = self else {
                NSLog("self 已释放")
                return
            }
            
            if let error = error {
                NSLog("网络请求失败: \(error.localizedDescription)")
                return
            }
            
            guard let data = data else {
                NSLog("未收到数据")
                return
            }
            
            NSLog("收到数据，大小: \(data.count) 字节")
            
            do {
                let apiResponse = try JSONDecoder().decode(APIResponse.self, from: data)
                NSLog("JSON 解析成功，数据条数: \(apiResponse.data.count)")
                
                if !apiResponse.data.isEmpty {
                    DispatchQueue.main.async {
                        // 处理多个数据项
                        let newData = apiResponse.data.map { self.convertToStockData($0) }
                        
                        // 如果只有一个数据项，保持原有逻辑
                        if newData.count == 1 {
                            self.allCachedData = newData
                            self.cachedData = newData.first
                            // 停止轮播（如果之前有多个数据项）
                            if self.isRotationActive {
                                self.stopRotation()
                            }
                            NSLog("✅ 获取到单个数据: \(apiResponse.data.first!.name)")
                        } else {
                            // 更新数据
                            self.allCachedData = newData
                            
                            // 只在第一次获取多个数据时启动轮播
                            if !self.isRotationActive {
                                self.cachedData = self.allCachedData.first
                                self.currentDisplayIndex = 0
                                self.startRotation()
                                NSLog("✅ 获取到 \(self.allCachedData.count) 个数据项，启动轮播显示")
                            } else {
                                // 轮播已经在运行，只更新当前显示的数据
                                if self.currentDisplayIndex < self.allCachedData.count {
                                    self.cachedData = self.allCachedData[self.currentDisplayIndex]
                                }
                                NSLog("🔄 更新轮播数据，当前显示: \(self.currentDisplayIndex + 1)/\(self.allCachedData.count)")
                            }
                        }
                    }
                } else {
                    NSLog("API 响应中没有数据")
                }
            } catch {
                NSLog("JSON 解析失败: \(error)")
                if let jsonString = String(data: data, encoding: .utf8) {
                    NSLog("原始数据: \(jsonString)")
                }
            }
        }.resume()
    }
    
    private func convertToStockData(_ cryptoData: CryptoData) -> StockData {
        let currentPrice = cryptoData.last
        let changePercent = cryptoData.status
        let change = currentPrice * (changePercent / 100.0)
        let isUp = changePercent >= 0
        
        // 更新上一次价格
        lastPrice = currentPrice
        
        return StockData(
            name: cryptoData.name,
            price: currentPrice,
            change: change,
            changePercent: changePercent,
            isUp: isUp
        )
    }
    
    private func createFallbackData() -> StockData {
        // 当API不可用时的备用数据
        // 如果没有缓存数据，创建多个测试数据用于演示轮播功能
        if allCachedData.isEmpty {
            allCachedData = [
                StockData(name: "BTC-USDT-SWAP", price: 110747.6, change: -647.4, changePercent: -0.58, isUp: false),
                StockData(name: "ETH-USDT-SWAP", price: 4234.5, change: 123.2, changePercent: 2.99, isUp: true),
                StockData(name: "SOL-USDT-SWAP", price: 245.8, change: -12.3, changePercent: -4.77, isUp: false),
                StockData(name: "ADA-USDT-SWAP", price: 1.23, change: 0.08, changePercent: 6.95, isUp: true),
                StockData(name: "DOT-USDT-SWAP", price: 8.45, change: -0.32, changePercent: -3.65, isUp: false)
            ]
            
            // 启动轮播（如果有多个数据）
            if allCachedData.count > 1 {
                startRotation()
                NSLog("🔄 使用测试数据启动轮播，共 \(allCachedData.count) 个币种")
            }
        }
        
        return allCachedData.first ?? StockData(
            name: "BTC-USDT",
            price: 110747.6,
            change: -647.4,
            changePercent: -0.58,
            isUp: false
        )
    }
    
    // MARK: - 轮播相关方法
    
    private func startRotation() {
        // 停止现有的轮播
        stopRotation()
        
        // 只有多个数据项时才启动轮播
        guard allCachedData.count > 1 else { return }
        
        rotationTimer = Timer.scheduledTimer(withTimeInterval: rotationInterval, repeats: true) { [weak self] _ in
            self?.rotateToNext()
        }
        
        isRotationActive = true
        NSLog("🔄 轮播定时器已启动，间隔: \(rotationInterval)秒")
    }
    
    private func stopRotation() {
        rotationTimer?.invalidate()
        rotationTimer = nil
        isRotationActive = false
        NSLog("⏹️ 轮播定时器已停止")
    }
    
    private func rotateToNext() {
        guard !allCachedData.isEmpty else { return }
        
        currentDisplayIndex = (currentDisplayIndex + 1) % allCachedData.count
        let currentData = allCachedData[currentDisplayIndex]
        
        NSLog("🔄 轮播切换到: \(currentData.displayName) (\(currentDisplayIndex + 1)/\(allCachedData.count))")
        
        // 通知UI更新（通过更新cachedData触发UI刷新）
        cachedData = currentData
    }
    
    // 手动切换到下一个（可供用户点击切换使用）
    func switchToNext() {
        guard !allCachedData.isEmpty else { return }
        
        currentDisplayIndex = (currentDisplayIndex + 1) % allCachedData.count
        let currentData = allCachedData[currentDisplayIndex]
        
        NSLog("👆 手动切换到: \(currentData.displayName) (\(currentDisplayIndex + 1)/\(allCachedData.count))")
        
        // 更新显示数据
        cachedData = currentData
        
        // 如果轮播正在运行，重置定时器
        if isRotationActive && allCachedData.count > 1 {
            startRotation() // 重新启动定时器，重置8秒计时
        }
    }
    
    // 获取当前显示的数据信息
    func getCurrentDisplayInfo() -> String {
        guard !allCachedData.isEmpty else { return "无数据" }
        return "\(currentDisplayIndex + 1)/\(allCachedData.count)"
    }
}