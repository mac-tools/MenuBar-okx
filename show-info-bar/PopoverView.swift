//
//  Untitled.swift
//  show-info-bar
//
//  Created by lixumin on 2025/10/17.
//

import SwiftUI

struct PopoverView: View {
    var body: some View {
        VStack(spacing: 15) {
            Image(systemName: "bolt.heart.fill")
                .resizable()
                .scaledToFit()
                .frame(width: 50, height: 50)
                .foregroundColor(.accentColor)

            Text("欢迎使用 MenuBar Demo!")
                .font(.headline)
            
            Button("退出应用") {
                // 点击按钮后，发送终止应用的通知
                NSApplication.shared.terminate(nil)
            }
        }
        .padding(20)
    }
}

struct PopoverView_Previews: PreviewProvider {
    static var previews: some View {
        PopoverView()
    }
}
