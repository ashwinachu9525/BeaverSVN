//
//  AppModel.swift
//  SVN Mac
//
//  Created by Aswin K on 21/11/25.
//
import Foundation
import Combine
import SwiftUI
@MainActor
final class AppModel: ObservableObject {

    static let shared = AppModel()
    

    // MARK: - Repository State

    @Published var repositories: [Repository] = []
    @Published var selectedRepo: Repository? = nil
    @Published var showOnboarding: Bool = !UserDefaults.standard.bool(forKey: "hasLaunchedBefore")
    @Published var onboardingStep: Int = 0 // Track current step
    @Published var downloadedBytes: Int64 = 0
    @Published var downloadSpeed: Double = 0

    // MARK: - Logs

    @Published var logLines: [String] = []

    // MARK: - Authentication

    @Published var username: String = ""

    // MARK: - Progress / Loading

    @Published var isLoading: Bool = false
    @Published var progress: Double = 0.0
    @Published var totalFiles: Int = 0
    @Published var processedFiles: Int = 0

    var repositoryRootURL: URL?

    let dummyBookmark = "SVN_DUMMY_BOOKMARK".data(using: .utf8)!

    private var cancellables = Set<AnyCancellable>()
    
    

    // MARK: - Init

    init() {

        loadSavedRepos()
        loadCredentials()

        // Smooth progress animation support
        $processedFiles
            .combineLatest($totalFiles)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] processed, total in
                guard total > 0 else { return }
                withAnimation(.easeInOut(duration: 0.2)) {
                    self?.progress = Double(processed) / Double(total)
                }
            }
            .store(in: &cancellables)
    }

    // MARK: - Progress Reset

    func resetProgress() {
        DispatchQueue.main.async {
            self.downloadedBytes = 0
            self.downloadSpeed = 0
            self.progress = 0
            self.totalFiles = 0
            self.processedFiles = 0
        }
    }

    // MARK: - Load Repositories

    func loadSavedRepos() {

        if let data = UserDefaults.standard.data(forKey: "svnmgr.repos") {

            let decoder = JSONDecoder()

            if let repos = try? decoder.decode([Repository].self, from: data) {

                repositories = repos
                selectedRepo = repositories.first
                return
            }
        }

        repositories = []
        selectedRepo = nil
    }

    // MARK: - Save Repositories

    func saveRepos() {

        let encoder = JSONEncoder()

        if let data = try? encoder.encode(repositories) {
            UserDefaults.standard.set(data, forKey: "svnmgr.repos")
        }

        var bookmarkDict: [String: Data] = [:]
        var pathArray: [String] = []

        for repo in repositories {

            pathArray.append(repo.path)

            if let bookmark = repo.bookmark {
                bookmarkDict[repo.path] = bookmark
            }
        }

        let suiteName = "group.com.aswin.FreeSVN"

        if let sharedDefaults = UserDefaults(suiteName: suiteName) {

            sharedDefaults.set(pathArray, forKey: "MonitoredPaths")
            sharedDefaults.set(bookmarkDict, forKey: "MonitoredBookmarks")

            sharedDefaults.synchronize()

            print("✅ Saved \(pathArray.count) paths and \(bookmarkDict.count) bookmarks.")
        }
    }

    // MARK: - Add Repository

    func addRepo(path: String, bookmark: Data?) {

        // Prevent duplicate repositories
        if repositories.contains(where: { $0.path == path }) {
            return
        }

        let repo = Repository(path: path, bookmark: bookmark ?? Data())

        repositories.append(repo)

        selectedRepo = repo

        saveRepos()
    }

    // MARK: - Remove Repository

    func removeRepo(at offsets: IndexSet) {

        repositories.remove(atOffsets: offsets)

        if repositories.isEmpty {
            selectedRepo = nil
        } else if !repositories.contains(where: { $0.id == selectedRepo?.id }) {
            selectedRepo = repositories.first
        }

        saveRepos()
    }

    // MARK: - Logs

    func clearLogs() {

        DispatchQueue.main.async {

            self.logLines.removeAll()
        }
    }
    
    func markOnboardingSeen() {
            UserDefaults.standard.set(true, forKey: "hasLaunchedBefore")
            showOnboarding = false
        }
        
        func nextOnboardingStep() {
            onboardingStep += 1
            if onboardingStep >= OnboardingStep.allCases.count {
                markOnboardingSeen()
            }
        }

    func appendLog(_ text: String) {

        DispatchQueue.main.async {

            let lines = text
                .split(separator: "\n", omittingEmptySubsequences: false)
                .map { String($0) }

            for line in lines {
                self.logLines.append(line)
            }

            // Prevent memory explosion
            if self.logLines.count > 2000 {
                self.logLines.removeFirst(self.logLines.count - 2000)
            }
        }
    }

    // MARK: - Credentials

    func loadCredentials() {

        if let savedUser = KeychainHelper.shared.get(
            service: "SVNManager",
            account: "username",
            useTouchID: true
        ) {

            username = savedUser
        }

        if let savedPass = KeychainHelper.shared.get(
            service: "SVNManager",
            account: "password",
            useTouchID: true
        ) {

            // Store directly into memory cache
            KeychainHelper.shared.clearSessionCache()

            KeychainHelper.shared.save(
                service: "SVNManager",
                account: "password",
                value: savedPass
            )
        }
    }

    // MARK: - SVN File Info Model

    public struct SVNFileInfo {

        public let name: String
        public let isFolder: Bool
        public let revision: Int
        public let author: String
        public let size: String
        public let date: String

        public init(
            name: String,
            isFolder: Bool,
            revision: Int,
            author: String,
            size: String,
            date: String
        ) {
            self.name = name
            self.isFolder = isFolder
            self.revision = revision
            self.author = author
            self.size = size
            self.date = date
        }
    }
}
