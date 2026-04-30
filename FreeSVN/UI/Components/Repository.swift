//
//  Repository.swift
//  SVN Mac
//
//  Created by Aswin K on 21/11/25.
//

import Foundation


struct Repository: Identifiable, Hashable, Codable, Equatable {
    let id: UUID
    var path: String
    var bookmark: Data?
    
    var displayName: String {
        URL(fileURLWithPath: path).lastPathComponent
    }

    init(path: String, bookmark: Data) {
        self.id = UUID()
        self.path = path
        self.bookmark = bookmark
    }

    // Equatable is automatically synthesized because all properties are Equatable
}

