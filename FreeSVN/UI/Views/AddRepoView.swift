//
//  AddRepoView.swift
//  SVN Mac
//
//  Created by Aswin K on 21/11/25.
//

import SwiftUI

struct AddRepoView: View {
    @Binding var isPresented: Bool
    @EnvironmentObject var appModel: AppModel
    @State private var path: String = ""

    var body: some View {
        VStack(spacing: 12) {
            Text("Add Repository").font(.title)
            
            TextField("Local folder path or URL (e.g. svn://...)", text: $path)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding()
            
            HStack {
                Button("Cancel") {
                    isPresented = false
                }
                
                Spacer()
                
                Button("Add") {
                    let panel = NSOpenPanel()
                    panel.canChooseDirectories = true
                    panel.canChooseFiles = false
                    panel.allowsMultipleSelection = false
                    panel.prompt = "Choose Folder"

                    panel.begin { resp in
                        guard resp == .OK, let folderURL = panel.url else { return }

                        do {
                            // Create security-scoped bookmark
                            let bookmark = try folderURL.bookmarkData(options: [.withSecurityScope])

                            // Add repo with bookmark
                            appModel.addRepo(path: folderURL.path, bookmark: bookmark)
                            isPresented = false
                        } catch {
                            print("❌ Failed to create bookmark: \(error)")
                            appModel.addRepo(path: folderURL.path, bookmark: nil)
                            isPresented = false
                        }
                    }
                }

            }
            .padding([.leading, .trailing], 20)
        }
        .padding()
        .frame(width: 500)
    }
}

