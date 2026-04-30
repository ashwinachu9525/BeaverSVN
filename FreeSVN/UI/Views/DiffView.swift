//
//  DiffView.swift
//  FreeSVN
//
//  Created by Aswin K on 31/03/26.
//
import SwiftUI

struct DiffView: View {
    let fileName: String
    let diffText: String
    @Environment(\.dismiss) var dismiss

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "doc.text.magnifyingglass")
                    .foregroundColor(.accentColor)
                Text("Diff: \(fileName)")
                    .font(.headline)
                Spacer()
                Button("Close") { dismiss() }
                    .buttonStyle(.borderedProminent)
                    .tint(.secondary)
            }
            .padding()
            .background(.ultraThinMaterial)
            
            Divider()

            // Code View
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 2) {
                    if diffText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text("No differences found or file is binary.")
                            .foregroundColor(.secondary)
                            .padding()
                    } else {
                        ForEach(Array(diffText.components(separatedBy: .newlines).enumerated()), id: \.offset) { _, line in
                            Text(line)
                                .font(.system(size: 12, weight: .medium, design: .monospaced))
                                .foregroundColor(colorForDiffLine(line))
                                .padding(.horizontal, 8)
                                .background(backgroundForDiffLine(line))
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
                .padding(.vertical, 8)
            }
            .background(Color(NSColor.textBackgroundColor))
        }
        .frame(minWidth: 600, minHeight: 450)
    }

    private func colorForDiffLine(_ line: String) -> Color {
        if line.hasPrefix("+") && !line.hasPrefix("+++") { return .green }
        if line.hasPrefix("-") && !line.hasPrefix("---") { return .red }
        if line.hasPrefix("@@") { return .cyan }
        return .primary
    }
    
    private func backgroundForDiffLine(_ line: String) -> Color {
        if line.hasPrefix("+") && !line.hasPrefix("+++") { return Color.green.opacity(0.1) }
        if line.hasPrefix("-") && !line.hasPrefix("---") { return Color.red.opacity(0.1) }
        if line.hasPrefix("@@") { return Color.cyan.opacity(0.1) }
        return Color.clear
    }
}
