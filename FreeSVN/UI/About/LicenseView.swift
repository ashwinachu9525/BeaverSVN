//
//  LicenseView.swift
//  SVN Mac
//
//  Created by Aswin K on 26/11/25.
//

import SwiftUI

struct LicenseView: View {

    // Example list — replace with your Subversion dependencies
    let libraries: [(name: String, license: String)] = [
        ("Subversion Library 1.0", "Apache 2.0"),
        ("CryptoKit Extensions", "BSD 3-Clause")
    ]

    var body: some View {
        VStack(alignment: .leading) {

            Text("Third-Party Software Used")
                .font(.title3)
                .bold()
                .padding(.bottom, 8)

            List(libraries, id: \.name) { item in
                HStack {
                    Text(item.name)
                    Spacer()
                    Text(item.license)
                        .foregroundColor(.blue)
                }
            }

            Button("Close") {
                NSApp.keyWindow?.close()
            }
            .padding(.top, 10)
        }
        .padding()
        .frame(width: 600, height: 400)
    }
}
