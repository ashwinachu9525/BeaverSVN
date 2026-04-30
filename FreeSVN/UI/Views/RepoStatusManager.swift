//
//  RepoStatusManager.swift
//  FreeSVN
//
//  Created by Aswin K on 03/04/26.
//

import Foundation
import SVNCore

final class RepoStatusManager {

    static let shared = RepoStatusManager()

    private let executor = SVNExecutor.shared

    private var statusCache: [String: SVNFile] = [:]
    private var isLoading = false

    func loadStatus(
        repoPath: String,
        username: String,
        password: String,
        resolvedURL: URL,
        completion: @escaping ([SVNFile]) -> Void
    ) {

        if isLoading { return }

        isLoading = true

        Task.detached(priority: .userInitiated) {

            defer {
                resolvedURL.stopAccessingSecurityScopedResource()
                self.isLoading = false
            }

            do {

                let statuses = try self.executor.status(
                    path: resolvedURL.path,
                    username: username,
                    password: password,
                    depth: .infinity,
                    verbose: true
                )

                var newCache: [String: SVNFile] = [:]

                for status in statuses {

                    if status.path == "." || status.path.isEmpty { continue }

                    let filePath =
                    status.path.hasPrefix("/")
                    ? status.path
                    : URL(fileURLWithPath: resolvedURL.path)
                        .appendingPathComponent(status.path).path

                    let file = SVNFile(
                        fullPath: filePath,
                        status: status.status
                    )

                    newCache[file.fullPath] = file
                }

                self.statusCache = newCache

                DispatchQueue.main.async {
                    completion(Array(newCache.values))
                }

            } catch {

                DispatchQueue.main.async {
                    completion([])
                }
            }
        }
    }

    func clearCache() {
        statusCache.removeAll(keepingCapacity: true)
    }
}
