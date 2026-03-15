//
//  SetListsView.swift
//  thebitbinder
//
//  Created by Taylor Drew on 12/2/25.
//

import SwiftUI
import SwiftData

struct SetListsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var setLists: [SetList]
    @AppStorage("roastModeEnabled") private var roastMode = false
    
    @State private var showingCreateSetList = false
    @State private var searchText = ""
    
    var filteredSetLists: [SetList] {
        if searchText.isEmpty {
            return setLists.sorted { $0.dateModified > $1.dateModified }
        } else {
            return setLists.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
                .sorted { $0.dateModified > $1.dateModified }
        }
    }
    
    var body: some View {
        NavigationStack {
            Group {
                if filteredSetLists.isEmpty {
                    VStack(spacing: 24) {
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [AppTheme.Colors.setsAccent.opacity(0.12), AppTheme.Colors.setsAccent.opacity(0.08)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 100, height: 100)
                            Image(systemName: "list.bullet.clipboard.fill")
                                .font(.system(size: 44))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [AppTheme.Colors.setsAccent, AppTheme.Colors.setsAccent.opacity(0.8)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                        }
                        
                        VStack(spacing: 8) {
                            Text("No set lists yet")
                                .font(.title3)
                                .fontWeight(.semibold)
                            Text("Create your first set list using the + button")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.horizontal, 40)
                } else {
                    List {
                        ForEach(filteredSetLists) { setList in
                            NavigationLink(value: setList) {
                                SetListRowView(setList: setList)
                            }
                        }
                        .onDelete(perform: deleteSetLists)
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle(roastMode ? "🔥 Roast Sets" : "Set Lists")
            .navigationDestination(for: SetList.self) { setList in
                SetListDetailView(setList: setList)
            }
            .searchable(text: $searchText, prompt: roastMode ? "Search roast sets" : "Search set lists")
            .toolbarBackground(
                roastMode ? AnyShapeStyle(AppTheme.Colors.roastSurface) : AnyShapeStyle(AppTheme.Colors.paperCream),
                for: .navigationBar
            )
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(roastMode ? .dark : .light, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingCreateSetList = true }) {
                        Image(systemName: "plus")
                            .foregroundColor(roastMode ? AppTheme.Colors.roastAccent : AppTheme.Colors.inkBlue)
                    }
                }
            }
            .sheet(isPresented: $showingCreateSetList) {
                CreateSetListView()
            }
        }
    }
    
    private func deleteSetLists(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(filteredSetLists[index])
        }
    }
}

struct SetListRowView: View {
    let setList: SetList
    @AppStorage("roastModeEnabled") private var roastMode = false
    private let accent = AppTheme.Colors.setsAccent

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            Text("•")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(accent)
                .frame(width: 32, alignment: .center)
                .padding(.top, 1)

            VStack(alignment: .leading, spacing: 4) {
                Text(setList.name)
                    .font(.system(size: 16, weight: .semibold, design: .serif))
                    .foregroundColor(roastMode ? .white : AppTheme.Colors.inkBlack)
                    .lineLimit(1)

                HStack(spacing: 10) {
                    Label(roastMode ? "\(setList.roastJokeIDs.count) roasts" : "\(setList.jokeIDs.count) jokes", systemImage: roastMode ? "flame.fill" : "text.quote")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(accent.opacity(0.85))
                    Spacer()
                    Text(setList.dateModified.formatted(.dateTime.month(.abbreviated).day()))
                        .font(.system(size: 11))
                        .foregroundColor(roastMode ? Color.white.opacity(0.45) : AppTheme.Colors.textTertiary)
                }
            }
        }
        .padding(.vertical, 12)
    }
}
