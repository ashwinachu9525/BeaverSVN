//
//  CredentialsPromptView.swift
//  FreeSVN
//
//  Created by Aswin K on 08/04/26.
//

import SwiftUI

struct CredentialsPromptView: View {
    @Binding var username: String
    @Binding var password: String
    var onSave: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            Text("SVN Credentials Required")
                .font(.headline)
            
            Text("Enter your SVN credentials to continue.")
                .foregroundStyle(.secondary)
            
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "person.fill")
                        .frame(width: 20)
                    TextField("Username", text: $username)
                        .textFieldStyle(.roundedBorder)
                }
                
                HStack {
                    Image(systemName: "key.fill")
                        .frame(width: 20)
                    SecureField("Password", text: $password)
                        .textFieldStyle(.roundedBorder)
                }
            }
            .padding(.horizontal)
            
            Button("Save & Continue") {
                onSave()
            }
            .disabled(username.isEmpty || password.isEmpty)
            .buttonStyle(.borderedProminent)
        }
        .padding(30)
        .frame(width: 350)
        .interactiveDismissDisabled() // Prevent dismissing without saving
    }
}


