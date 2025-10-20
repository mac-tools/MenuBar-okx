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
    private let apiURL = ""
    private var lastPrice: Double = 0.0
    private var cachedData: StockData?
    private var isRequesting: Bool = false
    
    func generateRandomStockData() -> StockData {
        // 如果正在请求中，返回缓存数据
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
                
                if let cryptoData = apiResponse.data.first {
                    DispatchQueue.main.async {
                        self.cachedData = self.convertToStockData(cryptoData)
                        NSLog("✅ 获取到新数据: \(cryptoData.name) - \(cryptoData.last) - \(cryptoData.status)%")
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
        return StockData(
            name: "BTC-USDT",
            price: 110747.6,
            change: -647.4,
            changePercent: -0.58,
            isUp: false
        )
    }
}