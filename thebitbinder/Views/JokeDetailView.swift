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
    
    @Bindable var joke: Joke
    @State private var isEditing = false
    @State private var showingFolderPicker = false
    
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
                        .background(Color(UIColor.systemGray6))
                        .cornerRadius(8)
                } else {
                    Text(joke.title)
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text(joke.content)
                        .font(.body)
                }
                
                Divider()
                
                // The Hits Button - prominent at top of metadata
                Button(action: { 
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                        joke.isHit.toggle()
                        joke.dateModified = Date()
                    }
                }) {
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(
                                    joke.isHit 
                                        ? LinearGradient(colors: [.yellow, .orange], startPoint: .topLeading, endPoint: .bottomTrailing)
                                        : LinearGradient(colors: [Color(.systemGray5), Color(.systemGray4)], startPoint: .topLeading, endPoint: .bottomTrailing)
                                )
                                .frame(width: 44, height: 44)
                            
                            Image(systemName: joke.isHit ? "star.fill" : "star")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundColor(joke.isHit ? .white : .gray)
                        }
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(joke.isHit ? "In The Hits!" : "Add to The Hits")
                                .font(.headline)
                                .foregroundColor(joke.isHit ? .orange : .primary)
                            Text(joke.isHit ? "This joke is perfected and ready" : "Mark as a perfected joke")
                                .font(.caption)
                                .foregroundColor(.secondary)
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
                            .fill(joke.isHit ? Color.yellow.opacity(0.1) : Color(.systemGray6))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(joke.isHit ? Color.orange.opacity(0.3) : Color.clear, lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                
                // The Hits Button - prominent at top of metadata
                Button(action: { 
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                        joke.isHit.toggle()
                        joke.dateModified = Date()
                    }
                }) {
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(
                                    joke.isHit 
                                        ? LinearGradient(colors: [.yellow, .orange], startPoint: .topLeading, endPoint: .bottomTrailing)
                                        : LinearGradient(colors: [Color(.systemGray5), Color(.systemGray4)], startPoint: .topLeading, endPoint: .bottomTrailing)
                                )
                                .frame(width: 44, height: 44)
                            
                            Image(systemName: joke.isHit ? "star.fill" : "star")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundColor(joke.isHit ? .white : .gray)
                        }
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(joke.isHit ? "In The Hits!" : "Add to The Hits")
                                .font(.headline)
                                .foregroundColor(joke.isHit ? .orange : .primary)
                            Text(joke.isHit ? "This joke is perfected and ready" : "Mark as a perfected joke")
                                .font(.caption)
                                .foregroundColor(.secondary)
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
                            .fill(joke.isHit ? Color.yellow.opacity(0.1) : Color(.systemGray6))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(joke.isHit ? Color.orange.opacity(0.3) : Color.clear, lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Label("Created", systemImage: "calendar")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(joke.dateCreated, style: .date)
                            .font(.subheadline)
                    }
                    
                    HStack {
                        Label("Folder", systemImage: "folder")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Spacer()
                        Button(action: { showingFolderPicker = true }) {
                            Text(joke.folder?.name ?? "None")
                                .font(.subheadline)
                                .foregroundColor(.blue)
                        }
                    }
                }
                .padding()
                .background(Color(UIColor.systemGray6))
                .cornerRadius(10)
            }
            .padding()
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(isEditing ? "Done" : "Edit") {
                    if isEditing {
                        joke.dateModified = Date()
                    }
                    isEditing.toggle()
                }
            }
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
