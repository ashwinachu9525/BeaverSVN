//
//  AboutWindow.swift
//  SVN Mac
//
//  Created by Aswin K on 26/11/25.
//
import SwiftUI

struct AboutView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {

            HStack(alignment: .top, spacing: 20) {
                Image(nsImage: NSApp.applicationIconImage)       // must exist in Assets
                    .resizable()
                    .frame(width: 80, height: 80)
                    .cornerRadius(16)

                VStack(alignment: .leading, spacing: 6) {
                    Text("BeaverSVN")
                        .font(.title2)
                        .bold()

                    Text("Version 1.0.0 (Build 1)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    Text("Built on November 26, 2025")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }

            Divider()

            VStack(alignment: .leading, spacing: 4) {
                Text("Runtime Info")
                    .font(.headline)

                Text("SwiftUI Runtime")
                Text("macOS SDK 14+")
                Text("Developed by Aswin K.")
            }
            .font(.subheadline)

            Spacer()
        }
        .padding()
        .frame(width: 500, height: 320)
    }
}

