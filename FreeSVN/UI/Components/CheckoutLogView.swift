//
//  CheckoutLogView.swift
//  MacSVN Pro
//

import SwiftUI

struct CheckoutLogView: View {
    let logs: [String]
    let errorMessage: String?
    
    let downloadedBytes: Int64
    let downloadSpeed: Double   // bytes per second
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var appModel: AppModel

    var body: some View {

        ZStack {

            // Background gradient (CleanMyMac style)
            LinearGradient(
                colors: [
                    Color(NSColor.windowBackgroundColor),
                    Color(NSColor.controlBackgroundColor)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack {

                // Floating Glass Card
                VStack(spacing: 0) {

                    header

                    Divider()

                    logSection

                    Divider()

                    footer

                }
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 18))
                .shadow(color: .black.opacity(0.15), radius: 20, y: 8)
                .padding(20)
            }
        }
        .frame(width: 540, height: 360)
    }
    
    private func formatBytes(_ bytes: Int64) -> String {

        let kb = Double(bytes) / 1024
        let mb = kb / 1024
        let gb = mb / 1024

        if gb >= 1 {
            return String(format: "%.2f GB", gb)
        } else if mb >= 1 {
            return String(format: "%.2f MB", mb)
        } else {
            return String(format: "%.0f KB", kb)
        }
    }
    private func formatSpeed(_ bytesPerSecond: Double) -> String {

        let kb = bytesPerSecond / 1024
        let mb = kb / 1024

        if mb >= 1 {
            return String(format: "%.2f MB/s", mb)
        } else {
            return String(format: "%.0f KB/s", kb)
        }
    }

    // MARK: Header

    private var header: some View {

        HStack(spacing:12) {

            Image(systemName: "terminal.fill")
                .font(.system(size: 20))
                .foregroundColor(.accentColor)

            Text("Checkout Result")
                .font(.system(size:18, weight:.semibold))

            Spacer()
        }
        .padding()
    }

    // MARK: Logs

    private var logSection: some View {

        ScrollViewReader { proxy in

            ScrollView {

                LazyVStack(alignment: .leading, spacing: 3) {

                    ForEach(logs.indices, id: \.self) { idx in

                        Text(logs[idx])
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundColor(colorForLog(logs[idx]))
                            .fontWeight(
                                logs[idx].contains("✔") ||
                                logs[idx].lowercased().contains("error")
                                ? .semibold
                                : .regular
                            )
                            .padding(.vertical,1)
                            .id(idx)
                    }

                    if let error = errorMessage {

                        Text("\n❌ Error: \(error)")
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundColor(.red)
                            .fontWeight(.semibold)
                    }

                    // Stable bottom anchor
                    Color.clear
                        .frame(height: 1)
                        .id("BOTTOM")
                }
                .padding()
            }

            // Auto-scroll (unchanged logic)
            .onChange(of: logs.count) { _ in
                withAnimation(.easeOut(duration: 0.15)) {
                    proxy.scrollTo("BOTTOM", anchor: .bottom)
                }
            }

            .onChange(of: errorMessage) { _ in
                withAnimation(.easeOut(duration: 0.15)) {
                    proxy.scrollTo("BOTTOM", anchor: .bottom)
                }
            }
        }
    }

    // MARK: Footer
    private var footer: some View {

        HStack {

            VStack(alignment: .leading, spacing: 2) {

                Text("Downloaded: \(formatBytes(appModel.downloadedBytes))")
                    .font(.system(size:11))
                    .foregroundStyle(.secondary)

                Text("Speed: \(formatSpeed(appModel.downloadSpeed))")
                    .font(.system(size:11))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                dismiss()
            } label: {

                Text("Close")
                    .font(.system(size:13, weight:.medium))
                    .padding(.horizontal,18)
                    .padding(.vertical,6)
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }

    // MARK: Log Coloring

    private func colorForLog(_ line: String) -> Color {

        let lower = line.lowercased()

        if lower.contains("error") ||
            lower.contains("failed") ||
            lower.contains("❌") {
            return .red
        }

        if lower.contains("warning") ||
            lower.contains("warn") {
            return .orange
        }

        if lower.contains("added")
            || lower.contains("updated")
            || lower.contains("checked out")
            || lower.contains("checkout completed")
            || lower.contains("✔") {
            return .green
        }

        if lower.contains("sending")
            || lower.contains("receiving")
            || lower.contains("fetching")
            || lower.contains("processing")
            || lower.contains("revision")
            || lower.contains("updating") {
            return .blue
        }

        return .primary
    }
}
