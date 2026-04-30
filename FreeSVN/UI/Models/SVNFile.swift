//
//  SVNFile.swift
//  FreeSVN
//
//  Created by Aswin K on 03/04/26.
//

import Foundation

struct SVNFile: Identifiable, Hashable {

    let id: String
    let name: String
    let fullPath: String
    var status: String

    init(fullPath: String, status: String) {

        let clean = (fullPath as NSString).standardizingPath

        self.fullPath = clean
        self.status = status
        self.name = URL(fileURLWithPath: clean).lastPathComponent
        self.id = clean
    }
}
