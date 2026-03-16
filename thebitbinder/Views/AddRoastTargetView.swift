//
//  AddRoastTargetView.swift
//  thebitbinder
//
//  Sheet to create a new person to roast.
//

import SwiftUI
import SwiftData
import PhotosUI

struct AddRoastTargetView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var notes = ""
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var photoData: Data?
    @State private var photoImage: UIImage?

    private let accentColor = AppTheme.Colors.roastAccent

    var body: some View {
        NavigationStack {
            Form {
                // Photo section
                Section {
                    HStack {
                        Spacer()
                        PhotosPicker(selection: $selectedPhoto, matching: .images) {
                            if let photoImage {
                                Image(uiImage: photoImage)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 100, height: 100)
                                    .clipShape(Circle())
                                    .overlay(Circle().stroke(accentColor, lineWidth: 3))
                            } else {
                                ZStack {
                                    Circle()
                                        .fill(accentColor.opacity(0.12))
                                        .frame(width: 100, height: 100)
                                    VStack(spacing: 4) {
                                        Image(systemName: "person.crop.circle.badge.plus")
                                            .font(.system(size: 32))
                                            .foregroundColor(accentColor)
                                        Text("Add Photo")
                                            .font(.caption2)
                                            .foregroundColor(accentColor)
                                    }
                                }
                            }
                        }
                        Spacer()
                    }
                    .listRowBackground(Color.clear)
                }

                Section("Who are you roasting?") {
                    TextField("Name", text: $name)
                        .font(.headline)
                }

                Section("Notes (optional)") {
                    TextField("e.g. friend, coworker, celebrity...", text: $notes)
                }
            }
            .navigationTitle("New Roast Target")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        saveTarget()
                    }
                    .fontWeight(.semibold)
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .onChange(of: selectedPhoto) { _, newValue in
                Task {
                    if let data = try? await newValue?.loadTransferable(type: Data.self) {
                        await MainActor.run {
                            photoData = data
                            photoImage = UIImage(data: data)
                        }
                    }
                }
            }
            .onAppear {
                print("📋 [AddRoastTargetView] View appeared")
                print("📋 [AddRoastTargetView] ModelContext available: \(modelContext)")
            }
        }
    }

    private func saveTarget() {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let target = RoastTarget(
            name: trimmed,
            notes: notes.trimmingCharacters(in: .whitespacesAndNewlines),
            photoData: photoData
        )
        
        print("📝 [AddRoastTargetView] Creating target: \(target.name)")
        print("📝 [AddRoastTargetView] Target ID: \(target.id)")
        print("📝 [AddRoastTargetView] Model context: \(modelContext)")
        
        do {
            modelContext.insert(target)
            print("📝 [AddRoastTargetView] Inserted into context")
            
            try modelContext.save()
            print("✅ [AddRoastTargetView] Successfully saved: \(target.name) (ID: \(target.id))")
            print("📝 [AddRoastTargetView] ModelContext transaction complete, flushing changes...")
            
            // Force a complete transaction flush and allow Query to refresh
            // Increase delay to 1 second to ensure SwiftData detects the change
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                print("📝 [AddRoastTargetView] Dismissing after full query refresh")
                dismiss()
            }
        } catch {
            print("❌ [AddRoastTargetView] Failed to save: \(error)")
            print("❌ [AddRoastTargetView] Error detail: \(String(describing: error))")
        }
    }
}
