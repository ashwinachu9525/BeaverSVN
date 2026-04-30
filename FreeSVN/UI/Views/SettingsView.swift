//
//  SettingsView.swift
//  SVN Mac
//
//  Created by Aswin K on 02/04/26.
//

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var appModel: AppModel
    @State private var password: String = ""
    @Environment(\.dismiss) private var dismiss
    @State private var showAlert = false
    @State private var alertMessage = ""
    
    // Preferences
    @State private var autoRefreshInterval: Double = 10
    @State private var showHiddenFiles: Bool = false
    @State private var theme: ColorScheme? = nil
    @State private var selectedTab: Int = 0

    var body: some View {
        HStack(spacing: 0) {
            
            // Sidebar
            VStack(alignment: .leading, spacing: 20) {
                Text("Settings")
                    .font(.system(size: 24, weight: .bold))
                    .padding(.top, 20)
                
                SidebarButton(icon: "person.crop.circle", title: "Credentials", tag: 0, selection: $selectedTab)
                SidebarButton(icon: "gearshape", title: "Preferences", tag: 1, selection: $selectedTab)
                SidebarButton(icon: "wrench.and.screwdriver", title: "Advanced", tag: 2, selection: $selectedTab)
                
                Spacer()
            }
            .frame(width: 160)
            .padding(.leading, 10)
            .background(Color(NSColor.windowBackgroundColor).opacity(0.95))
            
            Divider()
            
            // Main content
            ZStack(alignment: .topTrailing) {
                TabView(selection: $selectedTab) {
                    
                    // MARK: Credentials Tab
                    credentialsTab
                        .tag(0)
                    
                    // MARK: Preferences Tab
                    preferencesTab
                        .tag(1)
                    
                    // MARK: Advanced Tab
                    advancedTab
                        .tag(2)
                }
                .frame(width: 450, height: 350)
                .padding(20)
                
                // Close button
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .resizable()
                        .frame(width: 16, height: 16)
                        .foregroundColor(.secondary)
                        .padding()
                }
                .buttonStyle(.plain)
            }
        }
        .onAppear {
            loadCredentials()
            loadPreferences()
        }
        .alert(alertMessage, isPresented: $showAlert) {
            Button("OK", role: .cancel) { }
        }
    }
    
    // MARK: - Credentials Tab
    private var credentialsTab: some View {
        VStack(spacing: 20) {
            Text("SVN Credentials")
                .font(.headline)
            
            HStack(spacing: 12) {
                Image(systemName: "person.fill")
                    .foregroundColor(.accentColor)
                TextField("Username", text: $appModel.username)
                    .textFieldStyle(.roundedBorder)
            }
            
            HStack(spacing: 12) {
                Image(systemName: "key.fill")
                    .foregroundColor(.accentColor)
                SecureField("Password", text: $password)
                    .textFieldStyle(.roundedBorder)
            }
            
            HStack(spacing: 20) {
                Button("Save") { saveCredentials() }
                    .buttonStyle(FilledButtonStyle())
                
                Button("Clear") { clearCredentials() }
                    .buttonStyle(BorderButtonStyle())
                
                Spacer()
            }
            .padding(.top, 10)
            
            Spacer()
        }
    }
    
    // MARK: - Preferences Tab
    private var preferencesTab: some View {
        VStack(spacing: 20) {
            Text("Preferences")
                .font(.headline)
            
            HStack {
                Text("Auto Refresh Interval (sec)")
                Spacer()
                Slider(value: $autoRefreshInterval, in: 5...60, step: 1)
                    .frame(width: 200)
                Text("\(Int(autoRefreshInterval))s")
                    .frame(width: 40)
            }
            
            Toggle("Show Hidden Files", isOn: $showHiddenFiles)
            
            Picker("Theme", selection: $theme) {
                Text("System").tag(ColorScheme?.none)
                Text("Light").tag(ColorScheme.light as ColorScheme?)
                Text("Dark").tag(ColorScheme.dark as ColorScheme?)
            }
            .pickerStyle(.segmented)
            
            Spacer()
        }
    }
    
    // MARK: - Advanced Tab
    private var advancedTab: some View {
        VStack(spacing: 20) {
            Text("Advanced Settings")
                .font(.headline)
            
            Button("Clear SVN Cache") {
                appModel.appendLog("✔ SVN cache cleared")
            }
            
            Button("Show Logs") {
                //appModel.showLogs()
            }
            
            Spacer()
        }
    }
    
    // MARK: - Actions
    private func saveCredentials() {
        guard !appModel.username.isEmpty, !password.isEmpty else {
            showAlertMessage("Username and password cannot be empty.")
            return
        }
        KeychainHelper.shared.save(service: "SVNManager", account: "username", value: appModel.username)
        KeychainHelper.shared.save(service: "SVNManager", account: "password", value: password)
        appModel.appendLog("🔒 Credentials saved")
        dismiss()
    }

    private func clearCredentials() {
        KeychainHelper.shared.delete(service: "SVNManager", account: "username")
        KeychainHelper.shared.delete(service: "SVNManager", account: "password")
        appModel.username = ""
        password = ""
        appModel.appendLog("Credentials cleared")
    }
    
    private func loadCredentials() {
        if let savedUsername = KeychainHelper.shared.get(service: "SVNManager", account: "username") {
            appModel.username = savedUsername
        }
        if let savedPassword = KeychainHelper.shared.get(service: "SVNManager", account: "password") {
            password = savedPassword
        }
    }
    
    private func loadPreferences() {
        autoRefreshInterval = UserDefaults.standard.double(forKey: "autoRefreshInterval")
        showHiddenFiles = UserDefaults.standard.bool(forKey: "showHiddenFiles")
    }
    
    private func showAlertMessage(_ message: String) {
        alertMessage = message
        showAlert = true
    }
}

// MARK: - Sidebar Button
struct SidebarButton: View {
    let icon: String
    let title: String
    let tag: Int
    @Binding var selection: Int
    
    var body: some View {
        Button(action: { selection = tag }) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .frame(width: 20)
                Text(title)
                    .font(.system(size: 14))
                Spacer()
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 6)
            .background(selection == tag ? Color.accentColor.opacity(0.2) : Color.clear)
            .cornerRadius(6)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Button Styles
struct FilledButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(width: 100, height: 36)
            .background(Color.accentColor)
            .foregroundColor(.white)
            .cornerRadius(8)
            .opacity(configuration.isPressed ? 0.7 : 1.0)
    }
}

struct BorderButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(width: 100, height: 36)
            .background(Color(NSColor.controlBackgroundColor))
            .foregroundColor(.primary)
            .cornerRadius(8)
            .opacity(configuration.isPressed ? 0.7 : 1.0)
    }
}
