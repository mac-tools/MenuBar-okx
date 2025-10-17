//
//  File.swift
//  show-info-bar
//
//  Created by lixumin on 2025/10/17.
//

import SwiftUI

// 颜色主题定义
struct ColorTheme {
    let up: NSColor
    let down: NSColor
    
    static let classic = ColorTheme(up: .systemGreen, down: .systemRed)
    static let modern = ColorTheme(up: .systemBlue, down: .systemOrange)
    static let vibrant = ColorTheme(up: .systemPurple, down: .systemPink)
    static let professional = ColorTheme(up: NSColor(red: 0.0, green: 0.3, blue: 0.6, alpha: 1.0), down: NSColor(red: 0.6, green: 0.0, blue: 0.0, alpha: 1.0))
    static let nature = ColorTheme(up: .systemTeal, down: NSColor(red: 0.6, green: 0.4, blue: 0.2, alpha: 1.0))
}

// 背景样式定义
enum BackgroundStyle {
    case none           // 无背景
    case solid          // 纯色背景
    case gradient       // 渐变背景
    case rounded        // 圆角背景
    case capsule        // 胶囊形背景
    
    var cornerRadius: CGFloat {
        switch self {
        case .none, .solid, .gradient: return 0
        case .rounded: return 4
        case .capsule: return 11
        }
    }
}

enum ThemeType {
    case classic, modern, vibrant, professional, nature
    
    var colors: ColorTheme {
        switch self {
        case .classic: return .classic
        case .modern: return .modern
        case .vibrant: return .vibrant
        case .professional: return .professional
        case .nature: return .nature
        }
    }
}

// AppDelegate 负责处理应用级别的生命周期事件
class AppDelegate: NSObject, NSApplicationDelegate {
    
    // 菜单栏项目（就是那个图标）
    var statusItem: NSStatusItem?
    // 点击图标后弹出的窗口 (Popover)
    var popover: NSPopover?
    // 添加一个 Timer
    var timer: Timer?
    // 股票模拟器
    var stockSimulator = StockSimulator()
    // 当前主题
    var currentTheme: ThemeType = .classic
    // 背景样式
    var backgroundStyle: BackgroundStyle = .rounded

    func applicationDidFinishLaunching(_ notification: Notification) {
        // 1. 创建状态栏项目
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        // 2. 设置状态栏项目的按钮（也就是图标）
        if let button = statusItem?.button {
            // 初始显示
            button.image = createStockImage(for: stockSimulator.generateRandomStockData())
            // 设置点击事件
            button.action = #selector(togglePopover)
        }
        
        // 3. 创建 Popover 及其内容
        self.popover = NSPopover()
        self.popover?.behavior = .transient // 点击外部区域时自动关闭
        self.popover?.contentViewController = NSHostingController(rootView: PopoverView())
        
        // 4. 设置一个计时器，每3秒更新一次股票信息
        timer = Timer.scheduledTimer(timeInterval: 3.0, target: self, selector: #selector(updateStockData), userInfo: nil, repeats: true)
    }

    @objc func updateStockData() {
        let stockData = stockSimulator.generateRandomStockData()
        
        if let button = statusItem?.button {
            button.image = createStockImage(for: stockData)
        }
    }
    
    func createStockImage(for stockData: StockData) -> NSImage {
        // 计算状态栏图标的尺寸
        let iconSize = NSSize(width: 80, height: 22)
        let image = NSImage(size: iconSize)
        
        // 计算各个区域的尺寸和位置
        let totalWidth = iconSize.width
        let totalHeight = iconSize.height
        let padding: CGFloat = 2
        let elementSpacing: CGFloat = 2
        
        // 计算三个元素的宽度分配
        let arrowWidth: CGFloat = 10
        let changeWidth: CGFloat = 30
        let priceWidth = totalWidth - arrowWidth - changeWidth - (padding * 2) - (elementSpacing * 2)
        
        // 计算垂直居中位置
        let fontSize: CGFloat = 12
        let textHeight = fontSize + 2 // 留一些空间给字体
        let yPosition = (totalHeight - textHeight) / 2
        
        // 计算各元素的X位置
        let arrowX = padding
        let priceX = arrowX + arrowWidth + elementSpacing
        let changeX = priceX + priceWidth + elementSpacing
        
        image.lockFocus()
        
        // 绘制背景
        drawBackground(in: NSRect(x: 0, y: 0, width: totalWidth, height: totalHeight), for: stockData)
        
        // 获取当前主题颜色
        let themeColors = currentTheme.colors
        let textColor = stockData.isUp ? themeColors.up : themeColors.down
        
        // 创建居中对齐的段落样式
        let centerParagraphStyle = NSMutableParagraphStyle()
        centerParagraphStyle.alignment = .center
        
        // 绘制箭头
        let arrowSymbol = stockData.isUp ? "▲" : "▼"
        let arrowAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: fontSize),
            .foregroundColor: textColor,
            .paragraphStyle: centerParagraphStyle
        ]
        let arrowString = NSAttributedString(string: arrowSymbol, attributes: arrowAttrs)
        arrowString.draw(in: NSRect(x: arrowX, y: yPosition, width: arrowWidth, height: textHeight))
        
        // 绘制价格
        let priceAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: fontSize, weight: .medium),
            .foregroundColor: NSColor.labelColor,
            .paragraphStyle: centerParagraphStyle
        ]
        let priceString = NSAttributedString(string: stockData.formattedPrice, attributes: priceAttrs)
        priceString.draw(in: NSRect(x: priceX, y: yPosition, width: priceWidth, height: textHeight))
        
        // 绘制涨跌幅
        let changeAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: fontSize),
            .foregroundColor: textColor,
            .paragraphStyle: centerParagraphStyle
        ]
        let changeString = NSAttributedString(string: stockData.formattedChangePercent, attributes: changeAttrs)
        changeString.draw(in: NSRect(x: changeX, y: yPosition, width: changeWidth, height: textHeight))
        
        image.unlockFocus()
        
        return image
    }
    
    // 绘制背景的辅助函数
    func drawBackground(in rect: NSRect, for stockData: StockData) {
        guard backgroundStyle != .none else { return }
        
        let themeColors = currentTheme.colors
        let backgroundColor = stockData.isUp ? themeColors.up.withAlphaComponent(0.3) : themeColors.down.withAlphaComponent(0.3)
        
        switch backgroundStyle {
        case .none:
            break
            
        case .solid:
            backgroundColor.setFill()
            rect.fill()
            
        case .gradient:
            let gradient = NSGradient(starting: backgroundColor, ending: backgroundColor.withAlphaComponent(0.05))
            gradient?.draw(in: rect, angle: 90)
            
        case .rounded, .capsule:
            let path = NSBezierPath(roundedRect: rect, xRadius: backgroundStyle.cornerRadius, yRadius: backgroundStyle.cornerRadius)
            backgroundColor.setFill()
            path.fill()
            
            // 添加边框
            let borderColor = stockData.isUp ? themeColors.up.withAlphaComponent(0.3) : themeColors.down.withAlphaComponent(0.3)
            borderColor.setStroke()
            path.lineWidth = 0.5
            path.stroke()
        }
    }
    
    // 切换背景样式的方法
    func switchToBackgroundStyle(_ style: BackgroundStyle) {
        backgroundStyle = style
        // 立即更新显示
        updateStockData()
    }

    // 切换主题的方法
    func switchToTheme(_ theme: ThemeType) {
        currentTheme = theme
        // 立即更新显示
        updateStockData()
    }

    @objc func togglePopover() {
        guard let button = statusItem?.button else { return }

        if let popover = self.popover {
            if popover.isShown {
                // 如果已显示，则关闭
                popover.performClose(nil)
            } else {
                // 如果未显示，则显示
                popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            }
        }
    }
}
