//
//  ContentView.swift
//  thebitbinder
//
//  Created by Taylor Drew on 12/2/25.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @State private var showLaunchScreen = true
    @AppStorage("roastModeEnabled") private var roastMode = false
    
    var body: some View {
        ZStack {
            MainTabView()
            
            if showLaunchScreen {
                LaunchScreenView()
                    .transition(.opacity)
                    .zIndex(1)
            }
        }
        // Flip the whole app color scheme based on roast mode
        .preferredColorScheme(roastMode ? .dark : .light)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                withAnimation(.easeOut(duration: 0.25)) {
                    showLaunchScreen = false
                }
            }
        }
    }
}

// MARK: - App Screens

enum AppScreen: String, CaseIterable {
    case notepad = "Notepad"
    case brainstorm = "Brainstorm"
    case jokes = "Jokes"
    case sets = "Set Lists"
    case recordings = "Recordings"
    case notebookSaver = "Notebook"
    case settings = "Settings"

    // The screens visible in roast mode (in order)
    static var roastScreens: [AppScreen] {
        [.brainstorm, .jokes, .sets, .recordings, .notebookSaver, .settings]
    }

    var icon: String {
        switch self {
        case .notepad:       return "pencil.line"
        case .brainstorm:    return "lightbulb.fill"
        case .jokes:         return "theatermask.and.paintbrush.fill"
        case .sets:          return "list.bullet.rectangle.portrait.fill"
        case .recordings:    return "waveform.circle.fill"
        case .notebookSaver: return "book.closed.fill"
        case .settings:      return "gearshape.fill"
        }
    }

    // Roast-mode display name
    var roastName: String {
        switch self {
        case .notepad:       return "Fire Notepad"
        case .brainstorm:    return "Fire Ideas"
        case .jokes:         return "Roasts"
        case .sets:          return "Roast Sets"
        case .recordings:    return "Burn Recordings"
        case .notebookSaver: return "Fire Notebook"
        case .settings:      return "Settings"
        }
    }

    // Roast-mode icon
    var roastIcon: String {
        switch self {
        case .notepad:       return "flame.fill"
        case .brainstorm:    return "flame.circle.fill"
        case .jokes:         return "flame.circle.fill"
        case .sets:          return "list.bullet.rectangle.portrait.fill"
        case .recordings:    return "waveform.circle.fill"
        case .notebookSaver: return "book.closed.fill"
        case .settings:      return "gearshape.fill"
        }
    }

    var color: Color {
        switch self {
        case .notepad:       return AppTheme.Colors.notepadAccent
        case .brainstorm:    return AppTheme.Colors.brainstormAccent
        case .jokes:         return AppTheme.Colors.jokesAccent
        case .sets:          return AppTheme.Colors.setsAccent
        case .recordings:    return AppTheme.Colors.recordingsAccent
        case .notebookSaver: return AppTheme.Colors.notebookAccent
        case .settings:      return AppTheme.Colors.settingsAccent
        }
    }

    // Roast-mode accent (all ember/fire tones)
    var roastColor: Color {
        switch self {
        case .notepad:       return AppTheme.Colors.roastAccent
        case .brainstorm:    return Color(red: 1.0, green: 0.65, blue: 0.08)
        case .jokes:         return AppTheme.Colors.roastAccent
        case .sets:          return Color(red: 1.0, green: 0.55, blue: 0.10)
        case .recordings:    return Color(red: 0.95, green: 0.35, blue: 0.10)
        case .notebookSaver: return Color(red: 0.90, green: 0.45, blue: 0.10)
        case .settings:      return Color(red: 0.65, green: 0.55, blue: 0.50)
        }
    }
}

// MARK: - Main Tab View

struct MainTabView: View {
    @State private var selectedScreen: AppScreen = .notepad
    @State private var screenHistory: [AppScreen] = []
    @State private var showMenu = false
    @State private var showAIWidget = false
    @AppStorage("roastModeEnabled") private var roastMode = false

    private var canGoBack: Bool { !screenHistory.isEmpty }

    private func navigate(to screen: AppScreen) {
        guard screen != selectedScreen else { return }
        screenHistory.append(selectedScreen)
        selectedScreen = screen
    }

    private func goBack() {
        guard let previous = screenHistory.popLast() else { return }
        selectedScreen = previous
    }

    // When roast mode turns on, jump to Roasts; when off, jump to Notepad
    private func handleRoastModeChange(isRoast: Bool) {
        screenHistory.removeAll()
        if isRoast {
            if !AppScreen.roastScreens.contains(selectedScreen) {
                selectedScreen = .jokes
            }
        } else {
            selectedScreen = .notepad
        }
    }

    var body: some View {
        ZStack(alignment: .trailing) {
            // Background — charcoal in roast mode, paper in normal
            (roastMode ? AppTheme.Colors.roastBackground : AppTheme.Colors.surface)
                .ignoresSafeArea()

            // Main content
            Group {
                switch selectedScreen {
                case .notepad:       HomeView()
                case .brainstorm:    BrainstormView()
                case .jokes:         JokesView()
                case .sets:          SetListsView()
                case .recordings:    RecordingsView()
                case .notebookSaver: NotebookView()
                case .settings:      SettingsView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            // Floating AI Widget overlay — drops down from top
            if showAIWidget {
                VStack {
                    HStack {
                        Spacer()
                        FloatingAIWidgetView(onDismiss: { showAIWidget = false })
                            .frame(width: 340, height: 480)
                            .padding(.trailing, 16)
                    }
                    .padding(.top, 110)
                    Spacer()
                }
                .transition(.move(edge: .top).combined(with: .opacity))
            }

            // Dim overlay when menu is open
            if showMenu {
                Color.black.opacity(roastMode ? 0.65 : 0.4)
                    .ignoresSafeArea()
                    .onTapGesture {
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                            showMenu = false
                        }
                    }
                    .transition(.opacity)
            }

            // Side menu
            if showMenu {
                ModernSideMenu(selectedScreen: $selectedScreen, showMenu: $showMenu, onNavigate: { navigate(to: $0) })
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .trailing).combined(with: .opacity)
                    ))
            }

            // Floating FABs — top bar with back button on left, AI + menu on right
            if !showMenu {
                VStack {
                    HStack(spacing: 12) {
                        // Back button — only visible when there's history
                        if canGoBack {
                            Button {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                                    goBack()
                                }
                            } label: {
                                ZStack {
                                    Circle()
                                        .fill(roastMode
                                            ? Color.white.opacity(0.12)
                                            : AppTheme.Colors.inkBlack.opacity(0.08))
                                        .frame(width: 46, height: 46)
                                    Image(systemName: "chevron.left")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(roastMode ? .white : AppTheme.Colors.inkBlack)
                                }
                            }
                            .transition(.scale.combined(with: .opacity))
                        }

                        Spacer()

                        // AI button
                        Button {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                                showAIWidget.toggle()
                            }
                        } label: {
                            ZStack {
                                Circle()
                                    .fill(AppTheme.Colors.aiGradient)
                                    .frame(width: 46, height: 46)
                                Image(systemName: "sparkles")
                                    .font(.system(size: 17, weight: .semibold))
                                    .foregroundColor(.white)
                            }
                            .shadow(color: AppTheme.Colors.aiAccent.opacity(0.35), radius: 8, y: 4)
                        }

                        // Menu button
                        Button {
                            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                                showMenu = true
                            }
                        } label: {
                            ZStack {
                                Circle()
                                    .fill(roastMode ? AppTheme.Colors.roastEmberGradient : AppTheme.Colors.leatherGradient)
                                    .frame(width: 46, height: 46)
                                Image(systemName: roastMode ? "flame.fill" : "book.closed.fill")
                                    .font(.system(size: 17, weight: .semibold))
                                    .foregroundColor(.white)
                            }
                            .shadow(
                                color: (roastMode ? AppTheme.Colors.roastAccent : AppTheme.Colors.notebookAccent).opacity(0.40),
                                radius: 10, y: 4
                            )
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 56)
                    Spacer()
                }
            }
        }
        .onChange(of: roastMode) { _, newValue in
            handleRoastModeChange(isRoast: newValue)
        }
    }
}

// MARK: - Side Menu

struct ModernSideMenu: View {
    @Binding var selectedScreen: AppScreen
    @Binding var showMenu: Bool
    var onNavigate: (AppScreen) -> Void
    @AppStorage("roastModeEnabled") private var roastMode = false

    private var visibleScreens: [AppScreen] {
        roastMode ? AppScreen.roastScreens : AppScreen.allCases
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            menuHeader

            // Items
            ScrollView(showsIndicators: false) {
                VStack(spacing: 6) {
                    ForEach(visibleScreens, id: \.self) { screen in
                        ModernMenuItem(screen: screen, isSelected: selectedScreen == screen) {
                            onNavigate(screen)
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                                showMenu = false
                            }
                        }
                    }
                }
                .padding(16)
            }

            Spacer()

            // Footer
            HStack(spacing: 4) {
                Image(systemName: roastMode ? "flame" : "pencil.and.scribble")
                    .font(.caption2)
                Text("v9.1")
                    .font(.system(size: 11, design: .serif))
            }
            .foregroundStyle(roastMode ? Color.orange.opacity(0.5) : AppTheme.Colors.textTertiary)
            .padding(.bottom, 24)
        }
        .frame(width: 300)
        .frame(maxHeight: .infinity)
        .background(
            (roastMode ? AppTheme.Colors.roastSurface : AppTheme.Colors.surface)
                .shadow(color: .black.opacity(roastMode ? 0.5 : 0.3), radius: 20, x: -10, y: 0)
        )
        .ignoresSafeArea()
    }

    @ViewBuilder
    private var menuHeader: some View {
        if roastMode {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Spacer()
                    Button {
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) { showMenu = false }
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.white.opacity(0.5))
                            .frame(width: 32, height: 32)
                            .background(Circle().fill(Color.white.opacity(0.08)))
                    }
                }

                HStack(spacing: 16) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(AppTheme.Colors.roastAccent.opacity(0.20))
                            .frame(width: 54, height: 54)
                        Image(systemName: "flame.fill")
                            .font(.system(size: 28, weight: .semibold))
                            .foregroundStyle(AppTheme.Colors.roastEmberGradient)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text("RoastBinder")
                            .font(.system(size: 28, weight: .bold, design: .serif))
                            .foregroundColor(.white)
                        Text("turn up the heat")
                            .font(.system(size: 12, weight: .medium, design: .serif))
                            .foregroundColor(AppTheme.Colors.roastAccent.opacity(0.75))
                            .italic()
                    }
                }
                .padding(.top, 4)
            }
            .padding(24)
            .background(AppTheme.Colors.roastHeaderGradient)
        } else {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Spacer()
                    Button {
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) { showMenu = false }
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.white.opacity(0.5))
                            .frame(width: 32, height: 32)
                            .background(Circle().fill(Color.white.opacity(0.12)))
                    }
                }

                HStack(spacing: 16) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color.white.opacity(0.18))
                            .frame(width: 54, height: 54)
                        Image(systemName: "book.closed.fill")
                            .font(.system(size: 26))
                            .foregroundColor(.white)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text("BitBinder")
                            .font(.system(size: 28, weight: .bold, design: .serif))
                            .foregroundColor(.white)
                        Text("shut up and write some jokes")
                            .font(.system(size: 12, weight: .medium, design: .serif))
                            .foregroundColor(.white.opacity(0.60))
                            .italic()
                    }
                }
                .padding(.top, 4)
            }
            .padding(24)
            .background(AppTheme.Colors.leatherGradient)
        }
    }
}

// MARK: - Menu Item

struct ModernMenuItem: View {
    let screen: AppScreen
    let isSelected: Bool
    let action: () -> Void
    @AppStorage("roastModeEnabled") private var roastMode = false

    private var label: String   { roastMode ? screen.roastName  : screen.rawValue }
    private var icon: String    { roastMode ? screen.roastIcon  : screen.icon }
    private var accent: Color   { roastMode ? screen.roastColor : screen.color }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(accent)
                    .frame(width: 24)

                Text(label)
                    .font(.system(size: 16, weight: isSelected ? .semibold : .regular, design: .serif))
                    .foregroundColor(isSelected
                        ? (roastMode ? .white : AppTheme.Colors.inkBlack)
                        : (roastMode ? Color.white.opacity(0.60) : AppTheme.Colors.textSecondary))

                Spacer()

                if isSelected {
                    Circle()
                        .fill(accent.opacity(0.25))
                        .frame(width: 6, height: 6)
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: AppTheme.Radius.medium, style: .continuous)
                    .fill(isSelected
                        ? accent.opacity(roastMode ? 0.15 : 0.10)
                        : Color.clear)
            )
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.16), value: isSelected)
    }
}

#Preview {
    ContentView()
        .modelContainer(for: Joke.self, inMemory: true)
}
