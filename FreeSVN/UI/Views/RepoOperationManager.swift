//
//  RepoOperationManager.swift
//  FreeSVN
//
//  Created by Aswin K on 03/04/26.
//

import Foundation
import SVNCore

final class RepoOperationManager {

    static let shared = RepoOperationManager()

    private let executor = SVNExecutor.shared

    private init() {}

    // MARK: UPDATE

    func updateRepo(
        path: String,
        username: String,
        password: String,
        log: @escaping (String) -> Void
    ) throws {

        try executor.update(
            path: path,
            username: username,
            password: password
        ) { line in
            DispatchQueue.main.async {
                log(line)
            }
        }
    }

    // MARK: ADD

    func addFiles(
        paths: [String],
        username: String,
        password: String,
        log: @escaping (String) -> Void
    ) throws {

        guard !paths.isEmpty else { return }

        try executor.addBatch(
            paths: paths,
            username: username,
            password: password
        ) { line in
            DispatchQueue.main.async {
                log(line)
            }
        }
    }

    // MARK: DELETE

    func deleteFiles(
        paths: [String],
        username: String,
        password: String,
        log: @escaping (String) -> Void
    ) throws {

        guard !paths.isEmpty else { return }

        try executor.deleteBatch(
            paths: paths,
            username: username,
            password: password,
            message: "Deleted via FreeSVN"
        ) { line in
            DispatchQueue.main.async {
                log(line)
            }
        }
    }

    // MARK: COMMIT

    func commitFiles(
        paths: [String],
        message: String,
        username: String,
        password: String,
        log: @escaping (String) -> Void
    ) throws {

        guard !paths.isEmpty else { return }

        for path in paths {

            try executor.commit(
                path: path,
                message: message,
                username: username,
                password: password
            ) { line in
                DispatchQueue.main.async {
                    log(line)
                }
            }
        }
    }

    // MARK: DIFF

    func getDiff(
        path: String,
        username: String,
        password: String
    ) throws -> String {

        return try executor.getDiff(
            path: path,
            username: username,
            password: password
        )
    }

    // MARK: CLEANUP

    func cleanup(
        repoPath: String,
        workingCopy: String
    ) throws {

        try executor.clearMemory(
            for: repoPath,
            at: workingCopy
        )
    }
}
