//
//  OnboardingStep.swift
//  FreeSVN
//
//  Created by Aswin K on 01/04/26.
//

enum OnboardingStep: Int, CaseIterable {
    case addRepo
    case commit
    case update
    
    var title: String {
        switch self {
        case .addRepo: return "Add Repository"
        case .commit: return "Commit Changes"
        case .update: return "Update Repository"
        }
    }
    
    var message: String {
        switch self {
        case .addRepo: return "Click here to add your first repository."
        case .commit: return "Click Commit to save changes to your repo."
        case .update: return "Click Update to pull latest changes."
        }
    }
}
