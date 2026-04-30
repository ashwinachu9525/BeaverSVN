//
//  AboutTabContainer.swift
//  SVN Mac
//
//  Created by Aswin K on 26/11/25.
//
import SwiftUI

struct AboutTabContainer: View {
    var body: some View {
        TabView {
            AboutView()
                .tabItem { Text("About") }

            LicenseView()
                .tabItem { Text("Licenses") }
        }
    }
}

