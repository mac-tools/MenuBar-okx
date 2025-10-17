import Foundation

struct StockData {
    let price: Double
    let change: Double
    let changePercent: Double
    let isUp: Bool
    
    var formattedPrice: String {
        return String(format: "%.2f", price)
    }
    
    var formattedChange: String {
        let sign = isUp ? "+" : ""
        return String(format: "%@%.2f", sign, change)
    }
    
    var formattedChangePercent: String {
        let sign = isUp ? "+" : ""
        return String(format: "%@%.1f%%", sign, changePercent)
    }
}

class StockSimulator {
    private var currentPrice: Double = 150.0 // 初始价格
    private var lastPrice: Double = 150.0
    
    func generateRandomStockData() -> StockData {
        // 生成随机价格变化 (-5% 到 +5%)
        let changePercent = Double.random(in: -5.0...5.0)
        let change = lastPrice * (changePercent / 100.0)
        currentPrice = lastPrice + change
        
        // 确保价格不会太低
        if currentPrice < 10.0 {
            currentPrice = 10.0 + Double.random(in: 0...20)
        }
        
        let isUp = change >= 0
        
        let stockData = StockData(
            price: currentPrice,
            change: change,
            changePercent: changePercent,
            isUp: isUp
        )
        
        // 更新上一次价格
        lastPrice = currentPrice
        
        return stockData
    }
}