//
//  Helpers.swift
//  SVN Mac
//
//  Created by Aswin K on 21/11/25.
//

import Foundation

extension FileManager {
    static func applicationSupportFolder() -> URL {
        let fm = FileManager.default
        let url = try! fm.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        let appURL = url.appendingPathComponent("SVNManager")
        if !fm.fileExists(atPath: appURL.path) { try? fm.createDirectory(at: appURL, withIntermediateDirectories: true) }
        return appURL
    }
}
