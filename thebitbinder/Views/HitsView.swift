//
//  HitsView.swift
//  thebitbinder
//
//  Dedicated folder view showing only jokes marked as "Hits"
//

import SwiftUI
import SwiftData

struct HitsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(filter: #Predicate<Joke> { $0.isHit == true },
           sort: \Joke.dateCreated, order: .reverse)
    private var hitJokes: [Joke]
    
    @State private var searchText = ""
    
    private var filteredHits: [Joke] {
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return hitJokes }
        let lower = trimmed.lowercased()
        return hitJokes.filter {
            $0.content.lowercased().contains(lower) ||
            $0.title.lowercased().contains(lower)
        }
    }
    
    var body: some View {
        Group {
            if filteredHits.isEmpty {
                VStack(spacing: 20) {
                    ZStack {
                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [Color.yellow.opacity(0.3), Color.yellow.opacity(0)],
                                    center: .center,
                                    startRadius: 20,
                                    endRadius: 60
                                )
                            )
                            .frame(width: 120, height: 120)
                        Image(systemName: "star")
                            .font(.system(size: 48))
                            .foregroundStyle(
                                LinearGradient(colors: [.orange, .yellow],
                                               startPoint: .top, endPoint: .bottom)
                            )
                    }
                    
                    VStack(spacing: 8) {
                        Text("No Hits Yet")
                            .font(.title3.bold())
                        Text("Mark your best jokes as Hits from the joke detail page and they'll show up here.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                }
                .padding(40)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVGrid(columns: [
                        GridItem(.flexible(), spacing: 12),
                        GridItem(.flexible(), spacing: 12)
                    ], spacing: 12) {
                        ForEach(filteredHits) { joke in
                            NavigationLink(destination: JokeDetailView(joke: joke)) {
                                JokeCardView(joke: joke)
                            }
                            .contextMenu {
                                Button {
                                    joke.isHit = false
                                } label: {
                                    Label("Remove from Hits", systemImage: "star.slash")
                                }
                                Button(role: .destructive) {
                                    modelContext.delete(joke)
                                } label: {
                                    Label("Delete Joke", systemImage: "trash")
                                }
                            }
                        }
                    }
                    .padding(12)
                }
                .scrollContentBackground(.hidden)
            }
        }
        .navigationTitle("⭐ The Hits")
        .navigationBarTitleDisplayMode(.large)
        .searchable(text: $searchText, prompt: "Search hits")
    }
}

#Preview {
    NavigationStack {
        HitsView()
    }
    .modelContainer(for: Joke.self, inMemory: true)
}
