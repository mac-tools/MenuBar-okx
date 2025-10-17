//
//  show_info_barApp.swift
//  show-info-bar
//
//  Created by lixumin on 2025/10/17.
//

import SwiftUI

@main
struct show_info_barApp: App {
    // 引入 AppDelegate
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        // 我们将窗口的管理交给 AppDelegate，所以这里留空
        // 使用 Settings 是一个技巧，可以保证 App 正常运行但不会创建主窗口
        Settings {
            EmptyView()
        }
    }
}
