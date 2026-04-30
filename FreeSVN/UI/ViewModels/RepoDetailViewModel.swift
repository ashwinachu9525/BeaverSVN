//
//  RepoDetailViewModel.swift
//  FreeSVN
//
//  Created by Aswin K on 03/04/26.
//
import Foundation
import Combine
import SwiftUI



@MainActor
final class RepoDetailViewModel: ObservableObject {

    @Published private(set) var files: [SVNFile] = []
    @Published var filteredFiles: [SVNFile] = []
    @Published var selectedFiles: Set<SVNFile> = []

    @Published var showAllFiles = false
    @Published var isProcessing = false

    private let statusManager = RepoStatusManager()

    private let changedStatuses: Set<String> = ["M","A","D","C","R","?","!"]

    // MARK: Load Repo Status

    func loadRepoFiles(
        repoPath: String,
        username: String,
        password: String,
        resolvedURL: URL
    ) {

        statusManager.loadStatus(
            repoPath: repoPath,
            username: username,
            password: password,
            resolvedURL: resolvedURL
        ) { [weak self] (newFiles: [SVNFile]) in

            Task { @MainActor in

                guard let self else { return }

                self.files = newFiles
                    .map { SVNFile(fullPath: $0.fullPath, status: $0.status) }
                    .sorted { $0.fullPath < $1.fullPath }

                self.applyFilter()
            }
        }
    }

    func clearFiles() {

        files.removeAll()
        filteredFiles.removeAll()
        selectedFiles.removeAll()
    }
    
    // MARK: Filter

    func applyFilter() {

        if showAllFiles {
            filteredFiles = files
        } else {
            filteredFiles = files.filter {
                changedStatuses.contains($0.status)
            }
        }
    }

    // MARK: Selection Helpers

    var commitEligibleFiles: [SVNFile] {
        selectedFiles.filter {
            changedStatuses.contains($0.status) && $0.status != "?"
        }
    }

    var untrackedFiles: [SVNFile] {
        selectedFiles.filter { $0.status == "?" }
    }

    var deletableFiles: [SVNFile] {
        selectedFiles.filter { $0.status != "?" && $0.status != "!" }
    }
}
