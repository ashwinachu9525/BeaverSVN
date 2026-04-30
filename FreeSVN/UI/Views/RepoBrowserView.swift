//
//  RepoBrowserView.swift
//  MacSVN Pro
//
//  Created by Aswin K on 03/12/25.
//

import SwiftUI
import Combine
import SVNCore

// MARK: - MAIN VIEW
struct RepoBrowserView: View {
    @EnvironmentObject var appModel: AppModel

    @State private var repoURL: String = ""
    @State private var rootFolders: [RepoItem] = []
    @State private var selectedFolderID: UUID? = nil
    @State private var selectedFileIDs: Set<UUID> = []
    @State private var previewFile: RepoItem? = nil
    @State private var breadcrumbPaths: [RepoItem] = []

    @State private var isLoading = false
    @State private var errorMessage: String?

   
    
    private let executor = SVNExecutor.shared

    var body: some View {
        VStack(spacing: 0) {

            // MARK: Header
            HStack {
                TextField("SVN URL", text: $repoURL)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .frame(minWidth: 420)

                Button(action: browseRepo) {
                    Label("Browse", systemImage: "magnifyingglass")
                }
                .disabled(repoURL.isEmpty || isLoading)
            }
            .padding()
            .background(Color(NSColor.windowBackgroundColor))

            if isLoading {
                ProgressView("Loading…")
                    .padding()
            }

            if let errorMessage = errorMessage {
                Text(errorMessage)
                    .foregroundColor(.red)
                    .padding()
            }

            HSplitView {

                // MARK: LEFT SIDEBAR (FOLDER TREE)
                List(rootFolders, children: \.childrenFolders, selection: $selectedFolderID) { folder in
                    HStack {
                        Image(systemName: "folder.fill")
                        Text(folder.name)
                        if folder.isFolder && folder.isLoading {
                            ProgressView()
                                .scaleEffect(0.5)
                                .padding(.leading, 4)
                        }
                    }
                    .onTapGesture {
                        selectedFolderID = folder.id
                        updateBreadcrumb(for: folder)
                        loadFolder(folder)
                    }
                }
                .frame(minWidth: 250)

                // MARK: RIGHT PANEL
                VStack(alignment: .leading, spacing: 6) {

                    // Breadcrumb Navigation
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(breadcrumbPaths) { node in
                                Button(action: {
                                    selectedFolderID = node.id
                                    updateBreadcrumb(for: node)
                                    loadFolder(node)
                                }) {
                                    Text(node.name)
                                        .font(.caption)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 3)
                                        .background(Color.gray.opacity(0.2))
                                        .cornerRadius(4)
                                }
                            }
                        }
                        .padding(.horizontal)
                    }

                    Divider()

                    // File Table
                    Table(selectedFolderFiles, selection: $selectedFileIDs) {
                        TableColumn("File") { file in
                            HStack {
                                Image(systemName: file.isFolder ? "folder.fill" : "doc.text")
                                Text(file.name)
                                Spacer()
                            }
                            .contentShape(Rectangle())
                            .onTapGesture(count: 2) { handleDoubleClick(on: file) }
                        }
                        TableColumn("Revision") { file in
                            Text("\(file.revision)")
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .contentShape(Rectangle())
                                .onTapGesture(count: 2) { handleDoubleClick(on: file) }
                        }
                        TableColumn("Author") { file in
                            Text(file.author)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .contentShape(Rectangle())
                                .onTapGesture(count: 2) { handleDoubleClick(on: file) }
                        }
                        TableColumn("Size") { file in
                            Text(file.size)
                        }
                        TableColumn("Date") { file in
                            Text(file.date)
                        }
                    }

                    Divider()

                    // File Preview
                    if let preview = previewFile {
                        FilePreviewView(item: preview)
                            .frame(maxHeight: 220)
                            .padding()
                    }

                }
                .frame(minWidth: 400)
            }
        }
        .frame(minWidth: 850, minHeight: 550)
    }

    // MARK: Computed Properties
    private var selectedFolder: RepoItem? {
        rootFolders.first(whereRecursive: { $0.id == selectedFolderID })
    }

    private var selectedFolderFiles: [RepoItem] {
        selectedFolder?.childrenFiles ?? []
    }

    // MARK: Browse SVN (Root Folder)
    private func browseRepo() {

        isLoading = true
        errorMessage = nil
        rootFolders = []
        selectedFolderID = nil
        previewFile = nil
        breadcrumbPaths = []

        Task {

            do {

                let username = appModel.username
                let password = KeychainHelper.shared.get(
                    service: "SVNManager",
                    account: "password"
                ) ?? ""

                // async call
                let items = try await executor.listDetailed(
                    url: repoURL,
                    username: username,
                    password: password
                )

                let root = RepoItem(name: repoURL, isFolder: true, children: [])

                root.children = items.map {
                    let child = RepoItem(info: $0)
                    child.parent = root
                    if child.isFolder { child.children = nil }
                    return child
                }

                root.isLoaded = true

                rootFolders = [root]
                selectedFolderID = root.id
                updateBreadcrumb(for: root)

                isLoading = false

            } catch {

                errorMessage = error.localizedDescription
                isLoading = false
            }
        }
    }
    
    public struct SVNFileInfo {
        public let name: String
        public let isFolder: Bool
        public let revision: Int
        public let author: String
        public let size: String
        public let date: String
        
        public init(name: String, isFolder: Bool, revision: Int, author: String, size: String, date: String) {
            self.name = name
            self.isFolder = isFolder
            self.revision = revision
            self.author = author
            self.size = size
            self.date = date
        }
    }
    
    

    // MARK: Lazy Load Folder
    private func loadFolder(_ folder: RepoItem) {

        guard folder.isFolder else { return }
        if folder.isLoaded || folder.isLoading { return }

        folder.isLoading = true

        guard let relPath = folder.relativePath
            .addingPercentEncoding(withAllowedCharacters: .urlPathAllowed)
        else {
            folder.isLoaded = true
            folder.isLoading = false
            return
        }

        let folderURL = "\(repoURL)/\(relPath)"

        Task {

            do {

                let username = appModel.username
                let password = KeychainHelper.shared.get(
                    service: "SVNManager",
                    account: "password"
                ) ?? ""

                let items = try await executor.listDetailed(
                    url: folderURL,
                    username: username,
                    password: password
                )

                let children = items.map { info -> RepoItem in
                    let child = RepoItem(info: info)
                    child.parent = folder
                    if child.isFolder { child.children = nil }
                    return child
                }

                folder.children = children
                folder.isLoaded = true
                folder.isLoading = false

            } catch {

                folder.isLoaded = true
                folder.isLoading = false
                errorMessage = error.localizedDescription
            }
        }
    }

    // MARK: Double Click Handler
    private func handleDoubleClick(on item: RepoItem) {
        if item.isFolder {
            selectedFolderID = item.id
            updateBreadcrumb(for: item)
            loadFolder(item)
        } else {
            previewFile = item
        }
    }

    // MARK: Breadcrumb Builder
    private func updateBreadcrumb(for folder: RepoItem) {
        var path: [RepoItem] = []
        findParents(of: folder, in: rootFolders, collector: &path)
        breadcrumbPaths = path.reversed()
    }

    private func findParents(of target: RepoItem, in nodes: [RepoItem], collector: inout [RepoItem]) -> Bool {
        for node in nodes {
            if node.id == target.id {
                collector.append(node)
                return true
            }
            if let children = node.children, findParents(of: target, in: children, collector: &collector) {
                collector.append(node)
                return true
            }
        }
        return false
    }
}

// MARK: - Repo Item Model
class RepoItem: Identifiable, Hashable, ObservableObject {
    let id = UUID()
    let name: String
    @Published var isFolder: Bool
    @Published var children: [RepoItem]? = nil
    @Published var isLoaded: Bool = false
    @Published var isLoading: Bool = false
    @Published var revision: Int
    @Published var author: String
    @Published var sizeInBytes: Int
    @Published var date: String

    weak var parent: RepoItem?

    var size: String { sizeInBytes.readableFileSize }
    var childrenFolders: [RepoItem]? { children?.filter { $0.isFolder } }
    var childrenFiles: [RepoItem] { children?.filter { !$0.isFolder } ?? [] }

    var relativePath: String {
        guard let parent = parent else { return name }
        return "\(parent.relativePath)/\(name)"
    }

    init(name: String, isFolder: Bool, children: [RepoItem]? = nil,
         revision: Int = 0, author: String = "-", sizeInBytes: Int = 0, date: String = "-") {
        self.name = name
        self.isFolder = isFolder
        self.children = children
        self.revision = revision
        self.author = author
        self.sizeInBytes = sizeInBytes
        self.date = date
        self.children?.forEach { $0.parent = self }
    }

    convenience init(info: SVNFileInfo) {
        let leafName = info.name.split(separator: "/").last.map(String.init) ?? info.name
        self.init(name: leafName, isFolder: info.isFolder, children: nil,
                  revision: info.revision, author: info.author,
                  sizeInBytes: Int(info.size) ?? 0, date: info.date)
    }

    func update(with info: SVNFileInfo) {
        self.revision = info.revision
        self.author = info.author
        self.sizeInBytes = Int(info.size) ?? 0
        self.date = info.date
        self.isFolder = info.isFolder
    }

    
    static func == (lhs: RepoItem, rhs: RepoItem) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

// MARK: - File Size Formatter
extension Int {
    var readableFileSize: String {
        let bytes = Double(self)
        if bytes >= 1_073_741_824 { return String(format: "%.2f GB", bytes / 1_073_741_824) }
        if bytes >= 1_048_576 { return String(format: "%.2f MB", bytes / 1_048_576) }
        if bytes >= 1024 { return String(format: "%.2f KB", bytes / 1024) }
        return "\(Int(bytes)) B"
    }
}

// MARK: - Search Extension
extension Array where Element == RepoItem {
    func first(whereRecursive predicate: (RepoItem) -> Bool) -> RepoItem? {
        for item in self {
            if predicate(item) { return item }
            if let found = item.children?.first(whereRecursive: predicate) { return found }
        }
        return nil
    }
}

// MARK: - File Preview
struct FilePreviewView: View {
    let item: RepoItem

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("File Preview")
                .font(.headline)
            Text("Name: \(item.name)")
            Text("Author: \(item.author)")
            Text("Revision: \(item.revision)")
            Text("Date: \(item.date)")
            Text("Size: \(item.size)")
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
        .shadow(radius: 1)
    }
}
