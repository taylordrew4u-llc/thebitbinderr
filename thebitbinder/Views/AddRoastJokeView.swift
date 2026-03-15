// AddRoastJokeView.swift
//  thebitbinder
//
//  Sheet to write a new roast joke for a specific target.
//

import SwiftUI
import SwiftData

struct AddRoastJokeView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let target: RoastTarget

    @State private var content = ""

    private let accentColor = AppTheme.Colors.roastAccent

    var body: some View {
        NavigationStack {
            Form {
                // Who you're roasting
                Section {
                    HStack(spacing: 12) {
                        if let photoData = target.photoData,
                           let uiImage = UIImage(data: photoData) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 40, height: 40)
                                .clipShape(Circle())
                        } else {
                            ZStack {
                                Circle()
                                    .fill(accentColor.opacity(0.15))
                                    .frame(width: 40, height: 40)
                                Text(target.name.prefix(1).uppercased())
                                    .font(.system(size: 18, weight: .bold, design: .rounded))
                                    .foregroundColor(accentColor)
                            }
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Roasting")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(target.name)
                                .font(.headline)
                        }
                    }
                }

                Section("Write your roast") {
                    TextEditor(text: $content)
                        .frame(minHeight: 150)
                }
            }
            .navigationTitle("New Roast")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveRoast()
                    }
                    .fontWeight(.semibold)
                    .disabled(content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    private func saveRoast() {
        let trimmedContent = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedContent.isEmpty else { return }

        let joke = RoastJoke(
            content: trimmedContent,
            target: target
        )
        modelContext.insert(joke)
        target.dateModified = Date()
        try? modelContext.save()
        dismiss()
    }
}
