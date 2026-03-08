import SwiftUI

struct HomeView: View {
    @State private var notepadText = ""
    private let notepadKey = "notepadText"
    @AppStorage("roastModeEnabled") private var roastMode = false
    @StateObject private var syncService = iCloudSyncService.shared

    var body: some View {
        NavigationStack {
            ModernNotepad(text: $notepadText)
                .ignoresSafeArea(edges: .bottom)
                .navigationTitle(roastMode ? "🔥 Fire Notepad" : "Notepad")
                .navigationBarTitleDisplayMode(.large)
                .toolbarBackground(
                    roastMode ? AnyShapeStyle(AppTheme.Colors.roastSurface) : AnyShapeStyle(AppTheme.Colors.paperCream),
                    for: .navigationBar
                )
                .toolbarBackground(.visible, for: .navigationBar)
                .toolbarColorScheme(roastMode ? .dark : .light, for: .navigationBar)
                .onAppear {
                    notepadText = UserDefaults.standard.string(forKey: notepadKey) ?? ""
                }
                .onChange(of: notepadText) { _, v in
                    UserDefaults.standard.set(v, forKey: notepadKey)
                    // Sync thoughts to iCloud
                    Task {
                        await syncService.syncThoughts(v)
                    }
                }
        }
        .tint(roastMode ? AppTheme.Colors.roastAccent : AppTheme.Colors.inkBlue)
    }
}

// MARK: - Notepad canvas

struct ModernNotepad: View {
    @Binding var text: String
    @AppStorage("roastModeEnabled") private var roastMode = false

    private let lineH: CGFloat = 32   // tight ruled line height, matches a real legal pad
    private let leftGutter: CGFloat = 52  // margin line x
    private let holeX: CGFloat = 18   // punch hole x center

    private func dismiss() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .topLeading) {

                // ── Paper ──────────────────────────────────
                (roastMode ? AppTheme.Colors.roastBackground : AppTheme.Colors.paperCream)
                    .ignoresSafeArea()

                // ── Ruled lines ────────────────────────────
                Canvas { ctx, size in
                    let lc = roastMode
                        ? Color(red: 0.95, green: 0.40, blue: 0.12).opacity(0.14)
                        : AppTheme.Colors.paperLine
                    var y = lineH
                    while y < size.height {
                        var p = Path()
                        p.move(to: .init(x: 0, y: y))
                        p.addLine(to: .init(x: size.width, y: y))
                        ctx.stroke(p, with: .color(lc), lineWidth: 0.75)
                        y += lineH
                    }
                }
                .ignoresSafeArea()

                // ── Margin line ────────────────────────────
                Rectangle()
                    .fill(roastMode ? AppTheme.Colors.roastAccent.opacity(0.45) : AppTheme.Colors.marginRed)
                    .frame(width: 1.5)
                    .padding(.leading, leftGutter)
                    .ignoresSafeArea()

                // ── Punch holes ────────────────────────────
                let holeCount = max(1, Int((geo.size.height) / 76))
                VStack(spacing: 76) {
                    ForEach(0..<holeCount, id: \.self) { _ in
                        ZStack {
                            // Outer ring — paper shadow
                            Circle()
                                .fill(roastMode ? AppTheme.Colors.roastCard : AppTheme.Colors.paperDeep)
                                .frame(width: 14, height: 14)
                            // Inner hole
                            Circle()
                                .fill(roastMode ? AppTheme.Colors.roastBackground : AppTheme.Colors.paperAged)
                                .frame(width: 9, height: 9)
                        }
                    }
                }
                .padding(.leading, holeX - 7)
                .padding(.top, 20)
                .allowsHitTesting(false)

                // ── Text editor ────────────────────────────
                TextEditor(text: $text)
                    .scrollContentBackground(.hidden)
                    .scrollDismissesKeyboard(.interactively)
                    .foregroundColor(roastMode ? .white.opacity(0.92) : AppTheme.Colors.inkBlack)
                    .tint(roastMode ? AppTheme.Colors.roastAccent : AppTheme.Colors.inkBlue)
                    .font(.system(size: 17))
                    .lineSpacing(lineH - 20)
                    .padding(.leading, leftGutter + 14)
                    .padding(.trailing, 20)
                    .padding(.top, 4)
                    .background(Color.clear)
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { dismiss() }
                    .foregroundColor(roastMode ? AppTheme.Colors.roastAccent : AppTheme.Colors.inkBlue)
                    .fontWeight(.semibold)
            }
        }
    }
}

// MARK: - Lined background helper (kept for any reuse)

struct ModernLinedBackground: View {
    let lineSpacing: CGFloat
    var roastMode: Bool = false

    var body: some View {
        Canvas { ctx, size in
            let c = roastMode
                ? Color(red: 0.95, green: 0.40, blue: 0.12).opacity(0.14)
                : AppTheme.Colors.paperLine
            var y = lineSpacing
            while y < size.height {
                var p = Path()
                p.move(to: .init(x: 0, y: y))
                p.addLine(to: .init(x: size.width, y: y))
                ctx.stroke(p, with: .color(c), lineWidth: 0.75)
                y += lineSpacing
            }
        }
    }
}

#Preview { HomeView() }
