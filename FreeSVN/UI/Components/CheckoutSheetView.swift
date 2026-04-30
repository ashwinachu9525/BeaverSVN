//
//  CheckoutSheetView.swift
//  MacSVN Pro
//
//  Created by Aswin K on 18/01/26.
//
import SwiftUI
import SVNCore

struct CheckoutSheetView: View {

    @EnvironmentObject var appModel: AppModel
    @Binding var isPresented: Bool

    @Binding var checkoutLogs: [String]
    @Binding var checkoutError: String?
    @Binding var showLogSheet: Bool
    @Binding var repoURL: String
    
    @Binding var downloadedBytes: Int64
    @Binding var downloadSpeed: Double
    
    @State private var checkoutStartTime: Date? = nil
    @State private var processedFiles: Int = 0

    @State private var folderURL: URL? = nil
    @State private var depth: String = "Fully recursive"
    @State private var useHEAD: Bool = true
    @State private var revision: String = ""
    @State private var isProcessing: Bool = false

    private let executor = SVNExecutor.shared
    private let depths = ["Fully recursive","Immediate children","Only this item"]

    var body: some View {

        ZStack {

            // Background gradient (CleanMyMac style)
            LinearGradient(
                colors: [
                    Color(NSColor.windowBackgroundColor),
                    Color(NSColor.controlBackgroundColor)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing:22) {

                header

                card {
                    repoSection
                }

                card {
                    folderSection
                }

                card {
                    depthSection
                }

                card {
                    revisionSection
                }

                actions
            }
            .padding(30)
            .frame(width:520)
        }
        .animation(.easeInOut(duration:0.2), value: useHEAD)
        .sheet(isPresented:$showLogSheet) {

            CheckoutLogView(
                logs: checkoutLogs,
                errorMessage: checkoutError,
                downloadedBytes: appModel.downloadedBytes,
                downloadSpeed: appModel.downloadSpeed
            )
        }
    }

    // MARK: Header

    private var header: some View {

        HStack {

            Image(systemName:"arrow.down.circle.fill")
                .font(.system(size:32))
                .foregroundColor(.accentColor)

            VStack(alignment:.leading,spacing:4) {

                Text("SVN Checkout")
                    .font(.system(size:24,weight:.bold))

                Text("Download repository to local folder")
                    .font(.system(size:13))
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
    }

    // MARK: Repository URL

    private var repoSection: some View {

        VStack(alignment:.leading,spacing:10) {

            Text("Repository URL")
                .font(.headline)

            TextField("svn:// or https:// repository",
                      text:$repoURL)
            .textFieldStyle(.roundedBorder)
        }
    }

    // MARK: Folder Section

    private var folderSection: some View {

        VStack(alignment:.leading,spacing:10) {

            Text("Checkout Directory")
                .font(.headline)

            HStack {

                Text(folderURL?.path ?? "Choose destination folder")
                    .font(.system(size:12,design:.monospaced))
                    .lineLimit(1)
                    .truncationMode(.middle)

                Spacer()

                Button {

                    selectCheckoutFolder()

                } label: {

                    Image(systemName:"folder")
                }
            }
            .padding(10)
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius:10))
        }
    }

    // MARK: Depth

    private var depthSection: some View {

        VStack(alignment:.leading,spacing:10) {

            Text("Checkout Depth")
                .font(.headline)

            Picker("Depth",selection:$depth) {

                ForEach(depths,id:\.self) { Text($0) }
            }
            .pickerStyle(.menu)
        }
    }

    // MARK: Revision

    private var revisionSection: some View {

        VStack(alignment:.leading,spacing:10) {

            Text("Revision")
                .font(.headline)

            Toggle("Use HEAD revision",isOn:$useHEAD)

            TextField("Revision number",
                      text:Binding(
                        get:{ revision },
                        set:{ newValue in
                            revision = newValue.filter{ $0.isNumber }
                        }
                      ))
            .disabled(useHEAD)
            .textFieldStyle(.roundedBorder)
        }
    }

    // MARK: Actions

    private var actions: some View {

        HStack {

            Spacer()

            Button("Cancel") {

                isPresented = false

            }
            .keyboardShortcut(.cancelAction)

            Button {

                performCheckout()

            } label: {

                HStack {

                    if isProcessing {

                        ProgressView()
                            .controlSize(.small)
                    }

                    Text("Checkout")
                }
            }
            .keyboardShortcut(.defaultAction)
            .buttonStyle(.borderedProminent)
            .disabled(
                repoURL.isEmpty ||
                isProcessing ||
                (!useHEAD && revision.trimmingCharacters(in:.whitespaces).isEmpty)
            )
        }
    }

    // MARK: Floating Card

    private func card<Content:View>(
        @ViewBuilder content:()->Content
    )->some View {

        content()
            .padding(16)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius:16))
            .shadow(color:.black.opacity(0.08),radius:10,y:5)
    }

    // MARK: Folder Picker

    private func selectCheckoutFolder() {

        let panel = NSOpenPanel()

        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true

        panel.begin { resp in

            if resp == .OK, let url = panel.url {

                folderURL = url
            }
        }
    }

    // MARK: Revision Validation

    private func validatedRevision() -> Int? {

        if useHEAD { return nil }

        let trimmed = revision.trimmingCharacters(in:.whitespaces)

        guard !trimmed.isEmpty else {

            RepoDetailView.showAlert(
                title:"Revision Required",
                message:"Enter a revision number or use HEAD."
            )
            return nil
        }

        guard let rev = Int(trimmed), rev > 0 else {

            RepoDetailView.showAlert(
                title:"Invalid Revision",
                message:"Revision must be a positive number."
            )
            return nil
        }

        return rev
    }

    
    // MARK: Checkout Logic

    private func performCheckout() {

        let logQueue = DispatchQueue(label:"svn.log.queue")
        var pendingLogs:[String] = []

        var trimmedURL = repoURL.trimmingCharacters(in:.whitespacesAndNewlines)
        while trimmedURL.hasSuffix("/") { trimmedURL.removeLast() }

        guard !trimmedURL.isEmpty else {

            RepoDetailView.showAlert(
                title:"Checkout URL Missing",
                message:"Enter repository URL"
            )
            return
        }

        guard
            trimmedURL.hasPrefix("http://") ||
            trimmedURL.hasPrefix("https://") ||
            trimmedURL.hasPrefix("svn://")
        else {

            RepoDetailView.showAlert(
                title:"Invalid URL",
                message:"URL must start with http:// https:// or svn://"
            )
            return
        }

        guard let canonicalURL = trimmedURL.addingPercentEncoding(
            withAllowedCharacters:.urlQueryAllowed
        ) else {

            RepoDetailView.showAlert(
                title:"Invalid URL",
                message:"URL encoding failed"
            )
            return
        }

        if folderURL == nil { selectCheckoutFolder() }
        guard let folder = folderURL else { return }

        checkoutLogs.removeAll()
        checkoutError = nil
        showLogSheet = true

        isProcessing = true
        isPresented = false

        appModel.resetProgress()
        appModel.isLoading = true
        
        checkoutStartTime = Date()
        processedFiles = 0
        downloadedBytes = 0
        downloadSpeed = 0

        DispatchQueue.global(qos:.userInitiated).async {

            do {

                let username = appModel.username
                let password = KeychainHelper.shared.get(
                    service:"SVNManager",
                    account:"password"
                ) ?? ""

                let svnDepth:SVNDepth = {

                    switch depth {

                    case "Immediate children": return .immediates
                    case "Only this item": return .empty
                    default: return .infinity
                    }
                }()

                let revisionNumber = validatedRevision()

                try executor.checkout(
                    url:canonicalURL,
                    to:folder.path,
                    username:username,
                    password:password,
                    depth:svnDepth,
                    revision:revisionNumber
                ) { line in

                    logQueue.async {

                        pendingLogs.append(line)

                        if pendingLogs.count >= 5 {

                            let batch = pendingLogs
                            pendingLogs.removeAll()

                            DispatchQueue.main.async {

                                checkoutLogs.append(contentsOf:batch)
                            }
                        }
                        
                        
                        // ---------- Progress calculation ----------
                        // ---------- Progress calculation ----------
                       // print("DEBUG: Processing file -> \(line)")
                
                        // ---------- FIXED Progress calculation ----------
                        let lowerLine = line.lowercased()
                        // Check if the line contains standard SVN action indicators
                        let isAction = lowerLine.contains("added") ||
                                       lowerLine.contains("updated") ||
                                       line.hasPrefix("A ") ||
                                       line.hasPrefix("U ")

                        if isAction {
                            //print("MATCHED Action: \(line)") // This should now trigger!

                            DispatchQueue.main.async {
                                // Increment actual shared model values
                                appModel.downloadedBytes += 40_000
                                
                                if let start = checkoutStartTime {
                                    let elapsed = Date().timeIntervalSince(start)
                                    if elapsed > 0 {
                                        appModel.downloadSpeed = Double(appModel.downloadedBytes) / elapsed
                                    }
                                }
                                
                                // Sync local bindings so SidebarView/LogView see the change
                                self.downloadedBytes = appModel.downloadedBytes
                                self.downloadSpeed = appModel.downloadSpeed
                            }
                        }
                        // -----------------------------------------)
                        
                    }
                }

                DispatchQueue.main.async {

                    checkoutLogs.append(contentsOf:pendingLogs)
                    pendingLogs.removeAll()
                }

                let bookmark = try folder.bookmarkData(options:[.withSecurityScope])

                DispatchQueue.main.async {

                    appModel.addRepo(path:folder.path,bookmark:bookmark)
                    appModel.selectedRepo = appModel.repositories.last

                    repoURL = ""

                    isProcessing = false
                    appModel.isLoading = false
                }

            } catch {

                DispatchQueue.main.async {

                    let msg = error.localizedDescription

                    checkoutLogs.append("❌ Checkout failed: \(msg)")
                    checkoutError = msg

                    isProcessing = false
                    appModel.isLoading = false
                }
            }
        }
    }
}
