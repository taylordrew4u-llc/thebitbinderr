//
//  JokeDetailView.swift
//  thebitbinder
//
//  Created by Taylor Drew on 12/2/25.
//

import SwiftUI
import SwiftData

struct JokeDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var folders: [JokeFolder]
    @AppStorage("roastModeEnabled") private var roastMode = false
    
    @Bindable var joke: Joke
    @State private var isEditing = false
    @State private var showingFolderPicker = false
    @State private var showingDeleteAlert = false
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if isEditing {
                    TextField("Title", text: $joke.title)
                        .font(.title2)
                        .fontWeight(.bold)
                        .textFieldStyle(.roundedBorder)
                    
                    TextEditor(text: $joke.content)
                        .font(.body)
                        .frame(minHeight: 200)
                        .padding(8)
                        .background(roastMode ? AppTheme.Colors.roastCard : Color(UIColor.systemGray6))
                        .foregroundColor(roastMode ? .white : .primary)
                        .cornerRadius(8)
                } else {
                    Text(joke.title)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(roastMode ? .white : .primary)
                    
                    Text(joke.content)
                        .font(.body)
                        .foregroundColor(roastMode ? .white.opacity(0.9) : .primary)
                }
                
                Divider()
                
                // The Hits Button - prominent at top of metadata
                Button(action: {
                    withAnimation(.easeOut(duration: 0.15)) {
                        joke.isHit.toggle()
                        joke.dateModified = Date()
                    }
                }) {
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(
                                    joke.isHit
                                        ? (roastMode ? AppTheme.Colors.roastEmberGradient : LinearGradient(colors: [.yellow, .orange], startPoint: .topLeading, endPoint: .bottomTrailing))
                                        : LinearGradient(colors: [roastMode ? AppTheme.Colors.roastCard : Color(.systemGray5), roastMode ? AppTheme.Colors.roastSurface : Color(.systemGray4)], startPoint: .topLeading, endPoint: .bottomTrailing)
                                )
                                .frame(width: 44, height: 44)
                            
                            Image(systemName: roastMode ? (joke.isHit ? "flame.fill" : "flame") : (joke.isHit ? "star.fill" : "star"))
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundColor(joke.isHit ? .white : (roastMode ? .white.opacity(0.5) : .gray))
                        }
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(joke.isHit ? "In The Hits!" : "Add to The Hits")
                                .font(.headline)
                                .foregroundColor(joke.isHit ? (roastMode ? AppTheme.Colors.roastAccent : .orange) : (roastMode ? .white : .primary))
                            Text(joke.isHit ? "This joke is perfected and ready" : "Mark as a perfected joke")
                                .font(.caption)
                                .foregroundColor(roastMode ? .white.opacity(0.6) : .secondary)
                        }
                        
                        Spacer()
                        
                        if joke.isHit {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                                .font(.title2)
                        }
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(joke.isHit ? (roastMode ? AppTheme.Colors.roastAccent.opacity(0.15) : Color.yellow.opacity(0.1)) : (roastMode ? AppTheme.Colors.roastCard : Color(.systemGray6)))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(joke.isHit ? (roastMode ? AppTheme.Colors.roastAccent.opacity(0.5) : Color.orange.opacity(0.3)) : Color.clear, lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Label("Created", systemImage: "calendar")
                            .font(.subheadline)
                            .foregroundColor(roastMode ? .white.opacity(0.6) : .secondary)
                        Spacer()
                        Text(joke.dateCreated, style: .date)
                            .font(.subheadline)
                            .foregroundColor(roastMode ? .white : .primary)
                    }
                    
                    HStack {
                        Label("Folder", systemImage: "folder")
                            .font(.subheadline)
                            .foregroundColor(roastMode ? .white.opacity(0.6) : .secondary)
                        Spacer()
                        Button(action: { showingFolderPicker = true }) {
                            Text(joke.folder?.name ?? "None")
                                .font(.subheadline)
                                .foregroundColor(roastMode ? AppTheme.Colors.roastAccent : .blue)
                        }
                    }
                }
                .padding()
                .background(roastMode ? AppTheme.Colors.roastCard : Color(UIColor.systemGray6))
                .cornerRadius(10)
            }
            .padding()
        }
        .background(roastMode ? AppTheme.Colors.roastBackground : Color.clear)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(roastMode ? AppTheme.Colors.roastSurface : AppTheme.Colors.paperCream, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(roastMode ? .dark : .light, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack(spacing: 12) {
                    Button(isEditing ? "Done" : "Edit") {
                        if isEditing {
                            joke.dateModified = Date()
                        }
                        isEditing.toggle()
                    }
                    .foregroundColor(roastMode ? AppTheme.Colors.roastAccent : nil)
                    
                    if joke.isDeleted {
                        // When viewing a trashed joke allow restore
                        Button {
                            joke.restoreFromTrash()
                            dismiss()
                        } label: {
                            Image(systemName: "arrow.uturn.backward")
                                .foregroundColor(.green)
                        }
                    } else {
                        Button(role: .destructive) {
                            showingDeleteAlert = true
                        } label: {
                            Image(systemName: "trash")
                                .foregroundColor(.red)
                        }
                    }
                }
            }
        }
        .tint(roastMode ? AppTheme.Colors.roastAccent : AppTheme.Colors.inkBlue)
        .alert(joke.isDeleted ? "Restore Joke" : "Delete Joke", isPresented: $showingDeleteAlert) {
            if joke.isDeleted {
                Button("Restore") {
                    joke.restoreFromTrash()
                    dismiss()
                }
            } else {
                Button("Move to Trash") {
                    joke.moveToTrash()
                    dismiss()
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text(joke.isDeleted ? "Restore this joke from Trash." : "Are you sure you want to move \"\(joke.title)\" to Trash? You can restore it later.")
        }
        .sheet(isPresented: $showingFolderPicker) {
            FolderPickerView(selectedFolder: $joke.folder, folders: folders)
        }
    }
}

struct FolderPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedFolder: JokeFolder?
    let folders: [JokeFolder]
    
    var body: some View {
        NavigationView {
            List {
                Button(action: {
                    selectedFolder = nil
                    dismiss()
                }) {
                    HStack {
                        Text("None")
                        Spacer()
                        if selectedFolder == nil {
                            Image(systemName: "checkmark")
                                .foregroundColor(.blue)
                        }
                    }
                }
                
                ForEach(folders) { folder in
                    Button(action: {
                        selectedFolder = folder
                        dismiss()
                    }) {
                        HStack {
                            Text(folder.name)
                            Spacer()
                            if selectedFolder?.id == folder.id {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Select Folder")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}
