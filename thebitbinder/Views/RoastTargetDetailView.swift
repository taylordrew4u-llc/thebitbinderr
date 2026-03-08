//
//  RoastTargetDetailView.swift
//  thebitbinder
//
//  Shows a roast target's profile and all roast jokes for them.
//  Users can add, edit, and delete roast jokes here.
//

import SwiftUI
import SwiftData

struct RoastTargetDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var target: RoastTarget

    @State private var showingAddRoast = false
    @State private var editingJoke: RoastJoke?
    @State private var searchText = ""

    private let accentColor = AppTheme.Colors.roastAccent

    var filteredJokes: [RoastJoke] {
        let sorted = target.sortedJokes
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if trimmed.isEmpty { return sorted }
        return sorted.filter {
            $0.title.lowercased().contains(trimmed) ||
            $0.content.lowercased().contains(trimmed)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Target Header Card
            VStack(spacing: 12) {
                // Avatar
                if let photoData = target.photoData,
                   let uiImage = UIImage(data: photoData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 80, height: 80)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(accentColor, lineWidth: 3))
                } else {
                    ZStack {
                        Circle()
                            .fill(accentColor.opacity(0.15))
                            .frame(width: 80, height: 80)
                        Text(target.name.prefix(1).uppercased())
                            .font(.system(size: 34, weight: .bold, design: .rounded))
                            .foregroundColor(accentColor)
                    }
                }

                Text(target.name)
                    .font(.title2.bold())

                if !target.notes.isEmpty {
                    Text(target.notes)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                }

                Text("\(target.jokeCount) roast\(target.jokeCount == 1 ? "" : "s")")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 5)
                    .background(accentColor)
                    .clipShape(Capsule())
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(
                LinearGradient(
                    colors: [accentColor.opacity(0.08), Color(.systemBackground)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )

            Divider()

            // Roast Jokes List
            if filteredJokes.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "flame")
                        .font(.system(size: 44))
                        .foregroundColor(accentColor.opacity(0.4))
                    Text("No roasts yet")
                        .font(.headline)
                    Text("Tap + to write your first roast for \(target.name)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
            } else {
                List {
                    ForEach(filteredJokes) { joke in
                        Button {
                            editingJoke = joke
                        } label: {
                            RoastJokeRow(joke: joke)
                        }
                        .buttonStyle(.plain)
                    }
                    .onDelete(perform: deleteRoasts)
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle(target.name)
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $searchText, prompt: "Search roasts")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showingAddRoast = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showingAddRoast) {
            AddRoastJokeView(target: target)
        }
        .sheet(item: $editingJoke) { joke in
            EditRoastJokeView(joke: joke)
        }
    }

    private func deleteRoasts(at offsets: IndexSet) {
        let jokes = filteredJokes
        for index in offsets {
            guard index < jokes.count else { continue }
            modelContext.delete(jokes[index])
        }
        try? modelContext.save()
    }
}

// MARK: - Roast Joke Row

struct RoastJokeRow: View {
    let joke: RoastJoke
    private let accentColor = AppTheme.Colors.roastAccent

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(accentColor.opacity(0.12))
                    .frame(width: 42, height: 42)
                Image(systemName: "flame.fill")
                    .font(.system(size: 18))
                    .foregroundColor(accentColor)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(joke.title)
                    .font(.system(size: 15, weight: .semibold))
                    .lineLimit(1)
                Text(joke.content)
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                    .lineLimit(3)
                Text(joke.dateCreated, format: .dateTime.month(.abbreviated).day())
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 6)
    }
}

// MARK: - Edit Roast Joke Sheet

struct EditRoastJokeView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Bindable var joke: RoastJoke

    var body: some View {
        NavigationStack {
            Form {
                Section("Title") {
                    TextField("Roast title", text: $joke.title)
                }
                Section("Roast") {
                    TextEditor(text: $joke.content)
                        .frame(minHeight: 150)
                }
            }
            .navigationTitle("Edit Roast")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        joke.dateModified = Date()
                        try? modelContext.save()
                        dismiss()
                    }
                    .disabled(joke.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}
