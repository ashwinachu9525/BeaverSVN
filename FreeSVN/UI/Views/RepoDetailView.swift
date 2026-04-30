//
//  RepoDetailView.swift
//  MacSVN Pro
//
//
// RepoDetailView.swift
// MacSVN Pro
//

import SwiftUI
import AppKit
import SVNCore

struct RepoDetailView: View {

    @EnvironmentObject var appModel: AppModel
    @Binding var repo: Repository?

    @State private var password: String = ""
    @State private var isProcessing = false
    @State private var showSettings = false
    @State private var files: [SVNFile] = []
    @State private var selectedFiles: Set<SVNFile> = []
    @State private var timer: Timer?
    @State private var browserWindow: NSWindow?
    @State private var showAllFiles = false
    @State private var showingDiff = false
    @State private var diffContent = ""
    @State private var diffFileName = ""
    @State private var isLoadingStatus = false
    @State private var showCredentialsPrompt = false

    // OPTIMIZATION CACHE
    @State private var cachedChangedFiles: [SVNFile] = []
    @State private var isFilteringInBackground = false
    @State private var filterWorkItem: DispatchWorkItem?

    @StateObject private var vm = RepoDetailViewModel()

    private let watcher = RepoWatcher()
    private let executor = SVNExecutor.shared
    private let refreshController = RepoRefreshController()
    private let statusManager = RepoStatusManager()
    private let operations = RepoOperationManager.shared

    private let filterQueue = DispatchQueue(label: "svn.filter.queue", qos: .userInitiated)

    private let changedStatuses: Set<String> = ["M","A","D","C","R","?","!"]
    @MainActor
    static func showAlert(title: String, message: String) {

        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.addButton(withTitle: "OK")
        alert.alertStyle = .warning
        alert.runModal()
    }
    var body: some View {

        VStack(spacing:0){

            headerDashboard
                .padding(.horizontal,24)
                .padding(.vertical,20)

            Divider()

            HStack(spacing:20){

                VStack(spacing:0){

                    HStack{

                        Text("Working Copy")
                            .font(.headline)

                        Spacer()

                        HStack(spacing:8){

                            if isFilteringInBackground {

                                ProgressView()
                                    .controlSize(.small)
                                    .progressViewStyle(.circular)
                            }

                            Toggle("Show All",isOn:$showAllFiles)
                                .toggleStyle(.switch)
                                .controlSize(.mini)
                        }
                    }
                    .padding()

                    fileListSection
                }
                .frame(width:340)

                VStack(spacing:20){

                    actionPanel

                    logSection
                        .background(Color(NSColor.textBackgroundColor).opacity(0.05))
                        .cornerRadius(12)
                }
                .frame(maxWidth:.infinity,maxHeight:.infinity)
            }
            .padding(20)
        }

        .task {

            if let user = KeychainHelper.shared.get(service:"SVNManager",account:"username") {
                appModel.username = user
            }

            if let pwd = KeychainHelper.shared.get(service:"SVNManager",account:"password") {
                password = pwd
            }

            if !hasStoredCredentials {
                showCredentialsPrompt = true
            } else {
                initializeRepo()
            }
        }

        .onDisappear{

            watcher.stopWatching()
            stopAutoRefresh()
            filterWorkItem?.cancel()
        }

        .onChange(of: repo){ newRepo in

            watcher.stopWatching()
            stopAutoRefresh()
            filterWorkItem?.cancel()

            files.removeAll()
            cachedChangedFiles.removeAll()
            selectedFiles.removeAll()

            guard newRepo != nil else { return }

            initializeRepo()
        }

        .onChange(of: showAllFiles){ _ in

            if !showAllFiles {
                startBackgroundFiltering()
            }
        }

        .sheet(isPresented:$showingDiff){

            DiffView(
                fileName: diffFileName,
                diffText: diffContent
            )
        }

        .sheet(isPresented:$showSettings){

            SettingsView()
                .environmentObject(appModel)
        }

        .sheet(isPresented:$showCredentialsPrompt){

            CredentialsPromptView(
                username:$appModel.username,
                password:$password,
                onSave:{

                    saveCredentials()
                    showCredentialsPrompt = false
                    initializeRepo()
                }
            )
        }
    }
    
    private func authField(icon: String, text: Binding<String>, isSecure: Bool) -> some View {

        HStack {

            Image(systemName: icon)

            if isSecure {

                SecureField("Pass", text: text)

            } else {

                TextField("User", text: text)
            }
        }
        .padding(8)
        .frame(width: 140)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
    }
    private func showDiff(for file: SVNFile) {

        isProcessing = true

        DispatchQueue.global(qos: .userInitiated).async {

            do {

                let pass = KeychainHelper.shared.get(
                    service: "SVNManager",
                    account: "password"
                ) ?? ""

                let diff = try operations.getDiff(
                    path: file.fullPath,
                    username: appModel.username,
                    password: pass
                )

                DispatchQueue.main.async {

                    diffContent = diff
                    diffFileName = file.name
                    showingDiff = true
                    isProcessing = false
                }

            } catch {

                DispatchQueue.main.async {

                    isProcessing = false
                    appModel.appendLog("❌ Diff failed")
                }
            }
        }
    }
    
    private func actionButton(_ title: String,
                              _ icon: String,
                              color: Color,
                              action: @escaping () -> Void) -> some View {

        Button(action: action) {

            VStack(spacing: 10) {

                Image(systemName: icon)
                    .font(.system(size: 26))
                    .foregroundColor(color)

                Text(title)
                    .font(.system(size: 13))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
        }
        .buttonStyle(.plain)
    }
    private var actionPanel: some View {

        VStack(spacing: 12) {

            HStack {

                actionButton("Update", "arrow.down.circle.fill", color: .accentColor) {
                    updateRepo()
                }

                actionButton(commitButtonTitle, "checkmark.circle.fill", color: .green) {
                    commitDialog()
                }
                .disabled(commitEligibleFiles.isEmpty)

                actionButton(addButtonTitle, "plus.circle.fill", color: .blue) {
                    addSelectedFiles()
                }
                .disabled(untrackedSelectedFiles.isEmpty)
            }

            HStack {

                actionButton("Browser", "folder.fill", color: .secondary) {
                    openRepoBrowserWindow()
                }

                actionButton("Clean Up", "sparkles", color: .orange) {
                    if let r = repo { cleanupRepository(r) }
                }

                actionButton(deleteButtonTitle, "trash.fill", color: .red) {
                    deleteSelectedFiles()
                }
                .disabled(deletableFiles.isEmpty)
            }
        }
    }
    
    private func updateRepo() {

        guard let repo = repo,
              let bookmark = repo.bookmark else { return }

        var stale = false

        guard let url = try? URL(
            resolvingBookmarkData: bookmark,
            options: .withSecurityScope,
            relativeTo: nil,
            bookmarkDataIsStale: &stale
        ) else { return }

        guard url.startAccessingSecurityScopedResource() else { return }

        isProcessing = true

        Task.detached(priority: .userInitiated) {

            defer { url.stopAccessingSecurityScopedResource() }

            do {

                let pass = KeychainHelper.shared.get(
                    service: "SVNManager",
                    account: "password"
                ) ?? ""

                try await operations.updateRepo(
                    path: url.path,
                    username: appModel.username,
                    password: pass
                ) { line in
                    appModel.appendLog(line)
                }

                await MainActor.run {
                    isProcessing = false
                    appModel.appendLog("✔ Update complete")
                    loadRepoFiles(updateOnly: true)
                }

            } catch {

                await MainActor.run {
                    isProcessing = false
                    appModel.appendLog("❌ Update failed: \(error.localizedDescription)")
                }
            }
        }
    }
    
    private func commitDialog() {

        guard !selectedFiles.isEmpty else { return }

        let alert = NSAlert()
        alert.messageText = "Commit Message"
        alert.informativeText = "Enter a commit message"
        alert.addButton(withTitle: "Commit")
        alert.addButton(withTitle: "Cancel")

        let input = NSTextField(frame: NSRect(x: 0, y: 0, width: 300, height: 24))
        alert.accessoryView = input

        if alert.runModal() == .alertFirstButtonReturn {

            let msg = input.stringValue.trimmingCharacters(in: .whitespaces)

            guard !msg.isEmpty else { return }

            let paths = selectedFiles.map { $0.fullPath }

            let password = KeychainHelper.shared.get(
                service: "SVNManager",
                account: "password"
            ) ?? ""

            Task.detached(priority: .userInitiated) {

                do {

                    try await operations.commitFiles(
                        paths: paths,
                        message: msg,
                        username: appModel.username,
                        password: password
                    ) { line in
                        appModel.appendLog(line)
                    }

                    await MainActor.run {

                        appModel.appendLog("✔ Commit completed")
                        selectedFiles.removeAll()
                        loadRepoFiles(updateOnly: false)
                    }

                } catch {

                    await MainActor.run {
                        appModel.appendLog("❌ Commit failed")
                    }
                }
            }
        }
    }
    
  
    private func addSelectedFiles() {

        guard !selectedFiles.isEmpty else { return }

        let paths = selectedFiles.map { $0.fullPath }

        let password = KeychainHelper.shared.get(
            service: "SVNManager",
            account: "password"
        ) ?? ""

        isProcessing = true

        Task.detached(priority: .userInitiated) {

            do {

                try await operations.addFiles(
                    paths: paths,
                    username: appModel.username,
                    password: password
                ) { line in
                    appModel.appendLog(line)
                }

                await MainActor.run {

                    isProcessing = false
                    appModel.appendLog("✔ Add completed")
                    loadRepoFiles(updateOnly: false)
                }

            } catch {

                await MainActor.run {
                    isProcessing = false
                    appModel.appendLog("❌ Add failed")
                }
            }
        }
    }
    
    private func deleteSelectedFiles() {

        guard !selectedFiles.isEmpty else { return }

        let paths = selectedFiles.map { $0.fullPath }

        let password = KeychainHelper.shared.get(
            service: "SVNManager",
            account: "password"
        ) ?? ""

        Task.detached(priority: .userInitiated) {

            do {

                try await operations.deleteFiles(
                    paths: paths,
                    username: appModel.username,
                    password: password
                ) { line in
                    appModel.appendLog(line)
                }

                await MainActor.run {

                    appModel.appendLog("✔ Delete completed")
                    selectedFiles.removeAll()
                    loadRepoFiles(updateOnly: false)
                }

            } catch {

                await MainActor.run {
                    appModel.appendLog("❌ Delete failed")
                }
            }
        }
    }
    
    @MainActor
    func openRepoBrowserWindow(){

        let browser = RepoBrowserView().environmentObject(appModel)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 600, height: 600),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )

        window.title = "SVN Repo Browser"
        window.contentView = NSHostingView(rootView: browser)
        window.makeKeyAndOrderFront(nil)

        browserWindow = window
    }
    
    private func cleanupRepository(_ r: Repository) {

        guard let bookmark = r.bookmark else { return }

        var isStale = false

        guard let url = try? URL(
            resolvingBookmarkData: bookmark,
            options: [.withSecurityScope],
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        ) else { return }

        guard url.startAccessingSecurityScopedResource() else { return }

        isProcessing = true

        Task.detached(priority: .userInitiated) {

            defer { url.stopAccessingSecurityScopedResource() }

            do {

                try executor.clearMemory(
                    for: r.path,
                    at: url.path
                )

                await MainActor.run {

                    isProcessing = false
                    appModel.appendLog("✔ Cleanup successful")
                    loadRepoFiles(updateOnly: true)
                }

            } catch {

                await MainActor.run {

                    isProcessing = false
                    appModel.appendLog("❌ Cleanup failed")
                }
            }
        }
    }
    private var untrackedSelectedFiles: [SVNFile] {
        selectedFiles.filter { $0.status == "?" }
    }

    private var addButtonTitle: String {
        let count = untrackedSelectedFiles.count
        return count > 0 ? "Add (\(count))" : "Add"
    }

    private var commitEligibleFiles: [SVNFile] {
        selectedFiles.filter { changedStatuses.contains($0.status) && $0.status != "?" }
    }

    private var commitButtonTitle: String {
        let count = commitEligibleFiles.count
        return count > 0 ? "Commit (\(count))" : "Commit"
    }

    private var deletableFiles: [SVNFile] {
        selectedFiles.filter { $0.status != "?" && $0.status != "!" }
    }

    private var deleteButtonTitle: String {
        let count = deletableFiles.count
        return count > 0 ? "Delete (\(count))" : "Delete"
    }

    // MARK: INITIALIZE

    private func initializeRepo(){

        guard let repo = repo else { return }

        loadRepoFiles()

        watcher.startWatching(path: repo.path){
            loadRepoFiles(updateOnly:true)
        }

        startAutoRefresh()
        observeAppState()
    }

    // MARK: FILE LIST

    private var fileListSection: some View {

        let displayedFiles = showAllFiles ? files : cachedChangedFiles

        return List(displayedFiles,id:\.id,selection:$selectedFiles){ file in

            HStack{

                statusIcon(file.status)

                Text(file.name)
                    .font(.system(size:13))
                    .lineLimit(1)

                Spacer()
            }
            .tag(file)
            .contextMenu{

                Button("Show Diff"){
                    showDiff(for:file)
                }
                .disabled(file.status == "A" || file.status == "?")

                Button("Copy Full Path"){

                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(file.fullPath,forType:.string)
                }
            }
        }
        .transaction { $0.animation = nil }
        .listStyle(.inset)
        .scrollContentBackground(.hidden)
    }

    // MARK: LOAD STATUS

    @MainActor
    private func loadRepoFiles(updateOnly:Bool = false){

        guard let repo = repo else { return }

        let pass = KeychainHelper.shared.get(
            service:"SVNManager",
            account:"password"
        ) ?? ""

        guard let resolvedURL = resolvedRepoURL(for: repo) else { return }

        statusManager.loadStatus(
            repoPath: repo.path,
            username: appModel.username,
            password: pass,
            resolvedURL: resolvedURL
        ) { newFiles in

            let sorted = newFiles.sorted{ $0.fullPath < $1.fullPath }

            if files.count != sorted.count {

                files = sorted

            } else {

                files.removeAll(keepingCapacity:true)
                files.append(contentsOf:sorted)
            }

            startBackgroundFiltering()

            selectedFiles = selectedFiles.filter{ sel in
                files.contains(where:{ $0.fullPath == sel.fullPath })
            }
        }
    }
    
    private var headerDashboard: some View {

        HStack {

            VStack(alignment: .leading, spacing: 4) {

                Text(repo?.displayName ?? "Select Repository")
                    .font(.system(size: 28, weight: .bold))

                Text(repo?.path ?? "")
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            HStack(spacing: 12) {

                authField(icon: "person.fill", text: $appModel.username, isSecure: false)
                authField(icon: "key.fill", text: $password, isSecure: true)

                Button(action: saveCredentials) {

                    Image(systemName: "lock.fill")
                        .foregroundColor(.white)
                        .padding(8)
                        .background(Color.accentColor)
                        .cornerRadius(8)
                }

                Button {

                    showSettings = true

                } label: {

                    Image(systemName: "slider.horizontal.3")
                        .padding(8)
                        .background(Color(NSColor.controlBackgroundColor))
                        .cornerRadius(8)
                }
            }
        }
    }

    // MARK: FILTER

    private func startBackgroundFiltering(){

        filterWorkItem?.cancel()

        isFilteringInBackground = true

        let allFiles = files
        let statuses = changedStatuses

        let workItem = DispatchWorkItem{

            let filtered = allFiles.filter{ statuses.contains($0.status) }

            DispatchQueue.main.async{

                cachedChangedFiles = filtered
                isFilteringInBackground = false
            }
        }

        filterWorkItem = workItem

        filterQueue.async(execute:workItem)
    }

    // MARK: SECURITY URL FIX

    private func resolvedRepoURL(for repo: Repository) -> URL? {

        guard let bookmark = repo.bookmark else { return nil }

        var stale = false

        guard let url = try? URL(
            resolvingBookmarkData: bookmark,
            options: [.withSecurityScope],
            relativeTo: nil,
            bookmarkDataIsStale: &stale
        ) else { return nil }

        guard url.startAccessingSecurityScopedResource() else { return nil }

        return url
    }

    // MARK: PROGRESS LOG

    private var logSection: some View {

        VStack(spacing:0){

            HStack{

                Text("Activity Log")
                    .font(.system(size:12,weight:.bold))

                Spacer()

                if isProcessing {

                    ProgressView()
                        .controlSize(.small)
                        .progressViewStyle(.circular)
                }

                Button{
                    appModel.clearLogs()
                }label:{
                    Image(systemName:"trash")
                }
            }
            .padding()

            Divider()

            ScrollView{

                LazyVStack(alignment:.leading,spacing:4){

                    ForEach(appModel.logLines.indices,id:\.self){ i in

                        Text(appModel.logLines[i])
                            .font(.system(size:11,design:.monospaced))
                    }
                }
                .padding()
            }
        }
    }

    // MARK: ICON

    private func statusIcon(_ s:String)->some View{

        let icon:String
        let color:Color

        switch s {

        case "M": icon = "pencil.circle.fill"; color = .orange
        case "A": icon = "plus.circle.fill"; color = .green
        case "D": icon = "minus.circle.fill"; color = .red
        case "C": icon = "exclamationmark.triangle.fill"; color = .yellow
        case "?": icon = "questionmark.circle"; color = .gray
        default: icon = "doc.fill"; color = .secondary
        }

        return Image(systemName:icon)
            .foregroundColor(color)
    }

    // MARK: AUTO REFRESH

    private func startAutoRefresh(){

        refreshController.start(interval:20){

            if repo != nil && !isProcessing {

                loadRepoFiles(updateOnly:true)
            }
        }
    }

    private func stopAutoRefresh(){
        refreshController.stop()
    }

    // MARK: APP STATE

    private func observeAppState(){

        NotificationCenter.default.addObserver(
            forName:NSApplication.didBecomeActiveNotification,
            object:nil,
            queue:.main
        ){ _ in startAutoRefresh() }

        NotificationCenter.default.addObserver(
            forName:NSApplication.didResignActiveNotification,
            object:nil,
            queue:.main
        ){ _ in stopAutoRefresh() }
    }

    // MARK: SAVE CREDS

    private func saveCredentials(){

        KeychainHelper.shared.save(
            service:"SVNManager",
            account:"username",
            value:appModel.username
        )

        KeychainHelper.shared.save(
            service:"SVNManager",
            account:"password",
            value:password
        )

        appModel.appendLog("🔒 Credentials saved")
    }

    private var hasStoredCredentials: Bool {

        let storedUser = KeychainHelper.shared.get(service:"SVNManager",account:"username")
        let storedPass = KeychainHelper.shared.get(service:"SVNManager",account:"password")

        return storedUser != nil && storedPass != nil && !storedUser!.isEmpty && !storedPass!.isEmpty
    }

}
