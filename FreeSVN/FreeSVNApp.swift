//
//  FreeSVNApp.swift
//  FreeSVN
//
//  Created by Aswin K on 28/03/26.
//

import SwiftUI

@main
struct FreeSVNApp: App {
    
    @State private var aboutWindow: NSWindow?
    @StateObject private var appModel = AppModel()
    
    
    var body: some Scene {
        
        WindowGroup {
            RootView()
                .environmentObject(appModel)
                .frame(minWidth: 1020, minHeight: 600)
                
                // ✨ subtle macOS material background
                .background(.ultraThinMaterial)
                
                // ✨ smooth appear animation
                .animation(.easeInOut(duration: 0.25), value: appModel.repositories.count)
                
                .onOpenURL { url in
                    handleIncomingURL(url)
                }
        }
        
        // MARK: - Menu Customization
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("About BeaverSVN") {
                    showAboutWindow()
                }
                .keyboardShortcut(",", modifiers: [.command])
            }
        }
    }
    
    
    // MARK: - About Window
    private func showAboutWindow() {
        
        if aboutWindow == nil {
            
            let hosting = NSHostingController(
                rootView:
                    AboutTabContainer()
                    .frame(width: 600, height: 420)
                    .background(.ultraThinMaterial)
            )
            
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 600, height: 420),
                styleMask: [.titled, .closable],
                backing: .buffered,
                defer: false
            )
            
            window.title = "About BeaverSVN"
            window.center()
            
            // ✨ smoother macOS window style
            window.titlebarAppearsTransparent = true
            window.isMovableByWindowBackground = true
            
            window.isReleasedWhenClosed = false
            window.contentViewController = hosting
            
            // ✨ CleanMyMac-style slight shadow
            window.hasShadow = true
            
            aboutWindow = window
        }
        
        aboutWindow?.makeKeyAndOrderFront(nil)
        
        // Bring the app to the front
        NSApp.activate(ignoringOtherApps: true)
    }
    
    
    // MARK: - Handle Finder Extension Requests
    private func handleIncomingURL(_ url: URL) {
        
        // Ensure it's our custom scheme
        guard url.scheme == "freesvn" else { return }
        
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return }
        
        let action = url.host ?? ""
        let targetPath = components.queryItems?.first(where: { $0.name == "path" })?.value ?? ""
        
        // Bring app forward
        NSApp.activate(ignoringOtherApps: true)
        
        DispatchQueue.main.async {
            
            switch action {
                
            case "checkout":
                
                appModel.appendLog("📥 Finder requested Checkout")
                appModel.appendLog("📂 Path: \(targetPath)")
                
                // Here you can later trigger checkout UI
                
            case "update":
                
                appModel.appendLog("📥 Finder requested Update")
                appModel.appendLog("📂 Repository: \(targetPath)")
                
            case "commit":
                
                appModel.appendLog("📥 Finder requested Commit")
                appModel.appendLog("📂 Working Copy: \(targetPath)")
                
            default:
                
                appModel.appendLog("⚠️ Unknown Finder action: \(action)")
                break
            }
        }
    }
}
