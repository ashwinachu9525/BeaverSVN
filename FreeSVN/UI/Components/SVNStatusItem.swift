//
//  SVNStatusItem.swift
//  FreeSVN
//
//  Created by Aswin K on 31/03/26.
//
import Foundation

struct SVNStatusItem: Identifiable {
    let id = UUID()
    let path: String
    let status: String
}
