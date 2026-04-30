//
//  SidebarView.swift
//  MacSVN Pro
//
import SwiftUI
import AppKit
import SVNCore

struct SidebarView: View {
    @EnvironmentObject var appModel: AppModel

    @State private var showingAdd = false
    @State private var checkoutURL: String = ""
    @State private var isProcessing = false
    @State private var checkoutLogs: [String] = []
    @State private var checkoutError: String? = nil
    @State private var showCheckoutLog = false
    @State private var showingCheckoutSheet = false
    @State private var downloadedBytes: Int64 = 0
    @State private var downloadSpeed: Double = 0

    private let executor = SVNExecutor.shared

    var body: some View {
        List(selection: Binding(
            get: { appModel.selectedRepo },
            set: { repo in DispatchQueue.main.async { appModel.selectedRepo = repo } }
        )) {

            repositoriesSection
            checkoutSection
            actionsSection
        }
        .listStyle(.sidebar)
        .background(.ultraThinMaterial)
        .frame(minWidth: 280)

        // Sheets
        .sheet(isPresented: $showingAdd) {
            AddRepoView(isPresented: $showingAdd)
                .environmentObject(appModel)
        }

        .sheet(isPresented: $showCheckoutLog) {
            CheckoutLogView(
                logs: checkoutLogs,
                errorMessage: checkoutError,
                downloadedBytes: downloadedBytes,
                downloadSpeed: downloadSpeed
            )
        }

        .sheet(isPresented: $showingCheckoutSheet) {
            CheckoutSheetView(
                isPresented: $showingCheckoutSheet,
                checkoutLogs: $checkoutLogs,
                checkoutError: $checkoutError,
                showLogSheet: $showCheckoutLog,
                repoURL: $checkoutURL,
                downloadedBytes: $appModel.downloadedBytes,
                downloadSpeed: $appModel.downloadSpeed
            )
            .environmentObject(appModel)
        }
        
    }

    // MARK: - Repositories Section
    private var repositoriesSection: some View {
        Section {

            ForEach(appModel.repositories) { repo in
                HStack(spacing: 10) {

                    Image(systemName: "folder.fill")
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.accentColor, .blue],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .font(.system(size: 16))

                    Text(repo.displayName)
                        .font(.system(size: 14, weight: .medium))

                    Spacer()
                }
                .padding(.vertical, 6)
                .padding(.horizontal, 4)
                .background(
                    appModel.selectedRepo == repo
                    ? RoundedRectangle(cornerRadius: 8)
                        .fill(Color.accentColor.opacity(0.15))
                    : nil
                )
                .tag(repo)
                .contextMenu {
                    Button("Show in Finder") { revealInFinder(repo) }
                    Divider()
                    Button("Remove…") { confirmRemove(repo) }
                }
            }
            .onDelete(perform: appModel.removeRepo)

        } header: {
            Text("REPOSITORIES")
                .font(.caption.bold())
                .foregroundColor(.secondary)
        }
    }

    // MARK: - Checkout Section
    private var checkoutSection: some View {
        Section {

            VStack(alignment: .leading, spacing: 12) {

                TextField("SVN Checkout URL", text: $checkoutURL)
                    .textFieldStyle(.plain)
                    .padding(10)
                    .background(.regularMaterial)
                    .cornerRadius(10)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.secondary.opacity(0.15), lineWidth: 1)
                    )

                Button {
                    showingCheckoutSheet = true
                } label: {

                    HStack {
                        Spacer()

                        Label("Checkout", systemImage: "tray.and.arrow.down.fill")
                            .font(.system(size: 13, weight: .semibold))

                        Spacer()
                    }
                    .padding(.vertical, 10)
                    .background(
                        ZStack {
                            if checkoutURL.isEmpty {
                                Color.secondary.opacity(0.15)
                            } else {
                                LinearGradient(
                                    colors: [.accentColor, .blue],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            }
                        }
                    )
                    .foregroundColor(checkoutURL.isEmpty ? .secondary : .white)
                    .cornerRadius(10)
                }
                .buttonStyle(.plain)
                .disabled(isProcessing || checkoutURL.isEmpty)
            }
            .padding(.vertical, 8)

        } header: {
            Text("QUICK CHECKOUT")
                .font(.caption.bold())
                .foregroundColor(.secondary)
        }
    }

    // MARK: - Actions Section
    private var actionsSection: some View {
        Section {

            Button {
                showingAdd = true
            } label: {
                Label("Add URL Repository", systemImage: "link.badge.plus")
            }
            .buttonStyle(.plain)

            Button {
                chooseFolder()
            } label: {
                Label("Add Local Folder", systemImage: "folder.badge.plus")
            }
            .buttonStyle(.plain)

        } header: {
            Text("ACTIONS")
                .font(.caption.bold())
                .foregroundColor(.secondary)
        }
    }

    // MARK: - Helpers

    private func revealInFinder(_ repo: Repository) {
        NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: repo.path)])
    }

    private func confirmRemove(_ repo: Repository) {
        let alert = NSAlert()
        alert.messageText = "Remove Repository"
        alert.informativeText = "What would you like to do with “\(repo.displayName)”?"
        alert.alertStyle = .warning

        alert.addButton(withTitle: "Remove from App Only")
        alert.addButton(withTitle: "Delete Local Files")
        alert.addButton(withTitle: "Cancel")

        let response = alert.runModal()

        switch response {
        case .alertFirstButtonReturn:
            removeRepoEntry(repo)
        case .alertSecondButtonReturn:
            deleteRepoAndFiles(repo)
        default:
            break
        }
    }

    private func removeRepoEntry(_ repo: Repository) {
        if let index = appModel.repositories.firstIndex(of: repo) {
            appModel.repositories.remove(at: index)

            if appModel.selectedRepo == repo {
                appModel.selectedRepo = nil
            }

            appModel.appendLog("🗑 Removed repo from app: \(repo.displayName)")
            appModel.clearLogs()
        }
    }

    private func deleteRepoAndFiles(_ repo: Repository) {
        guard let bookmark = repo.bookmark else { return }

        var isStale = false
        guard let fileURL = try? URL(
            resolvingBookmarkData: bookmark,
            options: [.withSecurityScope],
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        ) else { return }

        guard fileURL.startAccessingSecurityScopedResource() else { return }
        defer { fileURL.stopAccessingSecurityScopedResource() }

        do {
            try FileManager.default.trashItem(at: fileURL, resultingItemURL: nil)
            removeRepoEntry(repo)
        } catch {
            RepoDetailView.showAlert(title: "Delete Failed", message: error.localizedDescription)
        }
    }

    private func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false

        panel.begin { resp in
            guard resp == .OK, let folderURL = panel.url else { return }

            Task { @MainActor in

                do {
                    let bookmark = try folderURL.bookmarkData(options: [.withSecurityScope])

                    appModel.addRepo(path: folderURL.path, bookmark: bookmark)

                } catch {
                    appModel.addRepo(path: folderURL.path, bookmark: nil)
                }

                appModel.selectedRepo = appModel.repositories.last
                updateMonitoredFolders()
            }
        }
    }
    
    @MainActor
    func updateMonitoredFolders() {

        guard let sharedDefaults = UserDefaults(suiteName: "group.com.aswin.FreeSVN") else { return }

        let paths = appModel.repositories.map { $0.path }

        sharedDefaults.set(paths, forKey: "MonitoredFolders")

        NSLog("📂 Updated MonitoredFolders: \(paths)")
    }
}
