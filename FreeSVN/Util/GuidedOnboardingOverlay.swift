//
//  GuidedOnboardingOverlay.swift
//  FreeSVN
//
//  Created by Aswin K on 01/04/26.
//

import Foundation
import Combine
import SwiftUI

struct GuidedOnboardingOverlay: View {
    
    @EnvironmentObject var appModel: AppModel
    
    var body: some View {
        if appModel.showOnboarding, let step = OnboardingStep(rawValue: appModel.onboardingStep) {
            ZStack {
                // Dim background
                Color.black.opacity(0.4)
                    .ignoresSafeArea()
                    .transition(.opacity)
                
                VStack {
                    Spacer()
                    
                    HStack {
                        Spacer()
                        
                        VStack(alignment: .leading, spacing: 10) {
                            Text("👋 \(step.title)")
                                .font(.title2)
                                .bold()
                            Text(step.message)
                                .font(.body)
                            
                            Button("Next") {
                                withAnimation {
                                    appModel.nextOnboardingStep()
                                }
                            }
                            .keyboardShortcut(.defaultAction)
                        }
                        .padding()
                        .background(.ultraThinMaterial)
                        .cornerRadius(12)
                        .shadow(radius: 10)
                        .padding()
                    }
                }
            }
            .animation(.easeInOut, value: appModel.onboardingStep)
            .transition(.opacity)
        }
    }
}
