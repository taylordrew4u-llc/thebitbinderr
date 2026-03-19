//
//  CreateSetListView.swift
//  thebitbinder
//
//  Created by Taylor Drew on 12/2/25.
//

import SwiftUI
import SwiftData

struct CreateSetListView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @AppStorage("roastModeEnabled") private var roastMode = false
    
    @State private var name = ""
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Set List Name")) {
                    TextField("Enter set list name", text: $name)
                }
            }
            .scrollContentBackground(roastMode ? .hidden : .visible)
            .background(roastMode ? AppTheme.Colors.roastBackground : Color.clear)
            .navigationTitle(roastMode ? "🔥 New Set List" : "New Set List")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(roastMode ? AppTheme.Colors.roastSurface : AppTheme.Colors.paperCream, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(roastMode ? .dark : .light, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(roastMode ? AppTheme.Colors.roastAccent : nil)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Create") {
                        createSetList()
                    }
                    .disabled(name.isEmpty)
                    .foregroundColor(roastMode ? AppTheme.Colors.roastAccent : nil)
                }
            }
        }
        .tint(roastMode ? AppTheme.Colors.roastAccent : AppTheme.Colors.inkBlue)
    }
    
    private func createSetList() {
        let setList = SetList(name: name)
        modelContext.insert(setList)
        try? modelContext.save()
        dismiss()
    }
}
