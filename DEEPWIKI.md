# Launchy DeepWiki

> **A comprehensive documentation hub for the Launchy macOS Launchpad clone**

---

## 📋 Table of Contents

1. [Project Overview](#project-overview)
2. [Architecture](#architecture)
3. [Core Components](#core-components)
4. [Services](#services)
5. [Models](#models)
6. [Views](#views)
7. [ViewModels](#viewmodels)
8. [Features](#features)
9. [Development Guide](#development-guide)
10. [API Reference](#api-reference)
11. [Troubleshooting](#troubleshooting)

---

## 🎯 Project Overview

### What is Launchy?

Launchy is a **macOS Launchpad clone** that replicates and enhances the original Launchpad experience. Built with SwiftUI and Swift 6, it provides a modern, performant, and highly customizable application launcher that replaces the built-in Launchpad removed in macOS 26 Tahoe.

### Key Features

- **🚀 Performance**: Optimized search algorithm with O(1) lookups
- **🔍 Spotlight Integration**: Unified search across apps and system files
- **🎨 Dashboard Widgets**: Classic widget support for nostalgia
- **🖥️ Multi-Monitor**: Perfect display handling across multiple screens
- **⚙️ Customization**: 20+ settings for personalized experience
- **🔧 App Exclusion**: Hide unwanted apps from the grid
- **🎯 System Integration**: Launchpad preferences integration

### Technical Stack

- **Language**: Swift 6.2
- **UI Framework**: SwiftUI
- **Platform**: macOS 14+
- **Architecture**: MVVM with Combine
- **Concurrency**: Swift Concurrency (@MainActor, async/await)
- **Dependencies**: Minimal, system frameworks only

---

## 🏗️ Architecture

### High-Level Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Launchy App                              │
├─────────────────────────────────────────────────────────────┤
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐         │
│  │   Views     │  │ ViewModels  │  │   Models    │         │
│  │             │  │             │  │             │         │
│  │ • RootView  │  │ • MainVM    │  │ • LaunchyItem│         │
│  │ • ItemView  │  │ • DragVM    │  │ • GridSettings│         │
│  │ • Settings  │  │ • FolderVM  │  │ • Dashboard  │         │
│  └─────────────┘  └─────────────┘  └─────────────┘         │
├─────────────────────────────────────────────────────────────┤
│                      Services Layer                         │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐         │
│  │ DataStore   │  │ IconProvider│  │ HotkeyService│         │
│  └─────────────┘  └─────────────┘  └─────────────┘         │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐         │
│  │ Spotlight   │  │ SearchIndex │  │ Exclusion   │         │
│  │ Service     │  │             │  │ Service     │         │
│  └─────────────┘  └─────────────┘  └─────────────┘         │
├─────────────────────────────────────────────────────────────┤
│                    System Integration                        │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐         │
│  │ Global      │  │ Trackpad    │  │ MenuBar     │         │
│  │ Hotkey      │  │ Gestures    │  │ Service     │         │
│  └─────────────┘  └─────────────┘  └─────────────┘         │
└─────────────────────────────────────────────────────────────┘
```

### Design Patterns

- **MVVM**: Clear separation between Views, ViewModels, and Models
- **Repository Pattern**: DataStore abstracts persistence
- **Observer Pattern**: Combine publishers for reactive updates
- **Singleton Pattern**: Shared services (Spotlight, Exclusion, etc.)
- **Coordinator Pattern**: AppCoordinator for event bus communication

---

## 🧩 Core Components

### LaunchyApp.swift
**Application entry point and lifecycle management**

```swift
@main
struct LaunchyApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        WindowGroup {
            LaunchyRootView()
        }
        .commands {
            CommandGroup(replacing: .appInfo) { /* ... */ }
        }
    }
}
```

**Key Responsibilities:**
- Application lifecycle management
- Global hotkey registration
- Trackpad gesture handling
- Menu bar integration
- Window configuration

### AppCoordinator.swift
**Central event bus for app-wide communication**

```swift
class AppCoordinator: ObservableObject {
    static let shared = AppCoordinator()
    let eventSubject = PassthroughSubject<AppEvent, Never>()
    
    enum AppEvent {
        case toggleSettings
        case dismissLauncher
        case resetToDefaultLayout
        // ... more events
    }
}
```

**Key Features:**
- Decoupled component communication
- Type-safe event system
- Reactive programming with Combine

---

## 🔧 Services

### DataStore Service
**Persistence and data management**

```swift
class LaunchyDataStore {
    func loadAsync() async -> [LaunchyItem]
    func save(_ items: [LaunchyItem])
    func reconcile(_ items: [LaunchyItem], with installed: [AppIcon])
}
```

**Features:**
- JSON-based persistence
- Async data loading
- Automatic app reconciliation
- iCloud sync support

### IconProvider Service
**Application icon caching and management**

```swift
class ApplicationIconProvider {
    func icon(for bundleURL: URL) async -> NSImage
    func invalidateCache(for bundleIdentifier: String)
}
```

**Features:**
- NSCache-based icon storage
- Bundle change detection
- Memory leak prevention
- Automatic cache invalidation

### SpotlightSearchService
**System-wide search integration**

```swift
class SpotlightSearchService {
    func search(_ query: String) async -> [SpotlightResult]
    func launch(_ result: SpotlightResult)
}
```

**Capabilities:**
- NSMetadataQuery integration
- File, document, and content search
- Relevance scoring
- Launch and reveal operations

### SearchIndex Service
**Optimized search performance**

```swift
class SearchIndex {
    func rebuild(from items: [LaunchyItem])
    func search(query: String) -> [LaunchyItem]
}
```

**Performance:**
- O(1) lookup time
- Token-based indexing
- Bundle identifier matching
- Fuzzy matching fallback

### AppExclusionService
**App visibility management**

```swift
class AppExclusionService {
    func excludeApp(_ app: AppIcon)
    func includeApp(_ app: AppIcon)
    func filterExcludedItems(_ items: [LaunchyItem]) -> [LaunchyItem]
}
```

**Features:**
- Persistent exclusion lists
- Default system app exclusions
- Folder-aware filtering
- Batch operations

---

## 📊 Models

### LaunchyItem
**Core data model for grid items**

```swift
enum LaunchyItem: Identifiable, Codable {
    case app(AppIcon)
    case folder(LaunchyFolder)
    case widget(DashboardWidget)
}
```

**Properties:**
- Type-safe enum with associated values
- Custom Codable implementation
- Computed properties for convenience
- Hashable and Equatable conformance

### AppIcon
**Application representation**

```swift
struct AppIcon: Identifiable, Codable {
    let id: UUID
    let name: String
    let bundleIdentifier: String
    let bundleURL: URL
}
```

### LaunchyFolder
**Folder container for apps**

```swift
struct LaunchyFolder: Identifiable, Codable {
    let id: UUID
    let name: String
    let color: IconColor
    var apps: [AppIcon]
}
```

### GridSettings
**User preferences and configuration**

```swift
struct GridSettings: Codable {
    var columns: Int
    var rows: Int
    var iconScale: Double
    var backgroundMode: BackgroundMode
    // ... 20+ customization options
}
```

### DashboardWidget
**Dashboard widget support**

```swift
struct DashboardWidget: Identifiable, Codable {
    let id: UUID
    let name: String
    let widgetType: WidgetType
    let bundleIdentifier: String
}
```

---

## 🎨 Views

### LaunchyRootView
**Main application view**

```swift
struct LaunchyRootView: View {
    @StateObject private var viewModel = LaunchyViewModel()
    @StateObject private var settingsStore = GridSettingsStore()
    
    var body: some View {
        // Main grid layout with search and settings
    }
}
```

**Features:**
- Main grid rendering
- Search bar integration
- Settings overlay
- Event handling

### LaunchyItemView
**Individual item display**

```swift
struct LaunchyItemView: View {
    let item: LaunchyItem
    @Binding var isEditing: Bool
    
    var body: some View {
        // Item rendering with editing controls
    }
}
```

**Capabilities:**
- Icon and name display
- Editing mode controls
- Drag and drop support
- Context menus

### WindowConfigurator
**Window management**

```swift
struct WindowConfigurator: NSViewRepresentable {
    let useFullScreenLayout: Bool
    
    func makeNSView(context: Context) -> NSView {
        // Window configuration logic
    }
}
```

**Features:**
- Full-screen vs windowed mode
- Multi-monitor handling
- Window style configuration
- Screen change detection

---

## 🧠 ViewModels

### LaunchyViewModel
**Main application state management**

```swift
@MainActor
class LaunchyViewModel: ObservableObject {
    @Published var items: [LaunchyItem]
    @Published var isEditing: Bool
    @Published var currentPage: Int
    @Published var presentedFolderID: UUID?
    
    // Search and pagination
    func pagedItems(matching query: String) -> [[LaunchyItem]]
    
    // Item management
    func createFolder(with items: [LaunchyItem])
    func deleteItems(_ items: [LaunchyItem])
}
```

**Responsibilities:**
- State management
- Search functionality
- Pagination logic
- Persistence coordination

### DragCoordinator
**Drag and drop logic**

```swift
class DragCoordinator: ObservableObject {
    @Published var dragItemID: UUID?
    @Published var dragSourceFolderID: UUID?
    
    func beginDrag(item: LaunchyItem)
    func handleDrop(on target: LaunchyItem)
}
```

**Features:**
- Drag state management
- Item stacking logic
- Folder springloading
- Drop target detection

---

## ✨ Features

### Search System
**Unified search across multiple sources**

1. **App Search**: Fast indexed search of installed applications
2. **Spotlight Integration**: System-wide file and content search
3. **Fuzzy Matching**: Intelligent typo-tolerant search
4. **Relevance Scoring**: Ranked results based on usage and relevance

```swift
// Example: Combined search
let results = viewModel.getCombinedSearchResults(for "safari")
// Returns: apps + spotlight results with relevance scores
```

### Multi-Monitor Support
**Perfect display handling**

- **Cursor Following**: Launchpad appears on screen with cursor
- **Screen Changes**: Automatic repositioning when monitors disconnect
- **Windowed Mode**: Remembers last used screen
- **Full-Screen Mode**: Covers entire display properly

### Dashboard Widgets
**Classic widget functionality**

```swift
// Available widget types
enum WidgetType: String, CaseIterable {
    case weather, stocks, calculator, calendar
    case clock, notes, reminders, systemPreferences
}
```

- **8 Widget Types**: Weather, Stocks, Calculator, Calendar, Clock, Notes, Reminders, System Preferences
- **Widget Launching**: Opens corresponding applications
- **Grid Integration**: Widgets appear alongside apps
- **Custom Icons**: SF Symbols for modern look

### App Exclusion
**Hide unwanted applications**

```swift
// Exclude system apps
AppExclusionService.shared.addDefaultExclusions()

// Custom exclusions
AppExclusionService.shared.excludeApp(systemApp)

// Filter from display
let filtered = AppExclusionService.shared.filterExcludedItems(items)
```

**Features:**
- **Default Exclusions**: Common system apps pre-excluded
- **Custom Exclusions**: User-defined app hiding
- **Folder Awareness**: Automatically filters apps in folders
- **Persistent Settings**: Exclusions remembered across sessions

### Customization Options
**20+ user preferences**

```swift
struct GridSettings {
    // Layout
    var columns: Int = 7
    var rows: Int = 5
    var iconScale: Double = 1.0
    
    // Animations
    var pageTransitionDuration: Double = 0.3
    var folderAnimationDuration: Double = 0.25
    var animateAppLaunch: Bool = true
    
    // UI Elements
    var showAppBadges: Bool = true
    var showSearchBar: Bool = true
    var showAppNames: Bool = true
    
    // Behavior
    var enableSpotlightSearch: Bool = true
    var showDashboardWidgets: Bool = false
    var enableSoundEffects: Bool = false
}
```

---

## 👨‍💻 Development Guide

### Getting Started

1. **Prerequisites**
   - macOS 14+
   - Xcode 16+
   - Swift 6.2 toolchain

2. **Setup**
   ```bash
   git clone <repository>
   cd launchy
   swift build
   swift run
   ```

3. **Development**
   ```bash
   # Watch for changes
   swift run --watch
   
   # Run tests
   swift test
   
   # Build for release
   swift build -c release
   ```

### Code Organization

```
src/
├── App/                    # Application lifecycle
├── Models/                 # Data models
├── Services/              # Business logic
├── ViewModels/            # MVVM view models
├── Views/                 # SwiftUI views
└── Extensions/            # Utility extensions
```

### Adding New Features

1. **Create Model**: Define data structures in `Models/`
2. **Implement Service**: Add business logic in `Services/`
3. **Update ViewModel**: Extend `LaunchyViewModel` or create new one
4. **Build View**: Create SwiftUI view in `Views/`
5. **Wire Up**: Connect components using Combine publishers

### Performance Guidelines

- **Use @MainActor** for UI-related classes
- **Async/Await** for I/O operations
- **NSCache** for expensive computations
- **Combine** for reactive updates
- **Avoid force unwraps** - use safe unwrapping patterns

### Testing Strategy

```swift
// Unit tests for services
class SpotlightSearchServiceTests: XCTestCase {
    func testSearchPerformance() {
        measure {
            let results = spotlightService.search("test")
            XCTAssertNotNil(results)
        }
    }
}

// Integration tests for view models
class LaunchyViewModelTests: XCTestCase {
    func testSearchFunctionality() {
        let viewModel = LaunchyViewModel(...)
        let results = viewModel.pagedItems(matching: "safari")
        XCTAssertFalse(results.isEmpty)
    }
}
```

---

## 📚 API Reference

### Core Services

#### LaunchyViewModel
```swift
// Initialization
init(dataStore: LaunchyDataStore, settingsStore: GridSettingsStore)

// Search
func pagedItems(matching query: String) -> [[LaunchyItem]]

// Item Management
func createFolder(with items: [LaunchyItem])
func deleteItems(_ items: [LaunchyItem])
func moveItem(_ item: LaunchyItem, to destination: LaunchyItem)

// Persistence
func saveNow()
func loadItems() async
```

#### SpotlightSearchService
```swift
// Search
func search(_ query: String) async -> [SpotlightResult]

// Actions
func launch(_ result: SpotlightResult)
func revealInFinder(_ result: SpotlightResult)
```

#### AppExclusionService
```swift
// Exclusion Management
func excludeApp(_ app: AppIcon)
func includeApp(_ app: AppIcon)
func isAppExcluded(_ app: AppIcon) -> Bool

// Filtering
func filterExcludedApps(_ apps: [AppIcon]) -> [AppIcon]
func filterExcludedItems(_ items: [LaunchyItem]) -> [LaunchyItem]
```

### Data Models

#### LaunchyItem
```swift
enum LaunchyItem {
    case app(AppIcon)
    case folder(LaunchyFolder)
    case widget(DashboardWidget)
    
    var id: UUID
    var displayName: String
    var asApp: AppIcon?
    var asFolder: LaunchyFolder?
    var asWidget: DashboardWidget?
}
```

#### GridSettings
```swift
struct GridSettings: Codable {
    // Layout
    var columns: Int
    var rows: Int
    var iconScale: Double
    
    // Appearance
    var backgroundMode: BackgroundMode
    var theme: InterfaceTheme
    
    // Behavior
    var enableSpotlightSearch: Bool
    var showDashboardWidgets: Bool
    var animateAppLaunch: Bool
    
    static let defaults = GridSettings(...)
}
```

---

## 🔧 Troubleshooting

### Common Issues

#### 1. Search Not Working
**Problem**: Search returns no results
**Solution**: 
- Check search index is built: `viewModel.searchIndex.rebuild(from: items)`
- Verify Spotlight permissions in System Preferences
- Clear caches: `viewModel.invalidateCaches()`

#### 2. Memory Leaks
**Problem**: High memory usage over time
**Solution**:
- Check for retain cycles in closures
- Ensure `@MainActor` isolation is correct
- Use `weak self` in async operations

#### 3. Multi-Monitor Issues
**Problem**: Launchpad appears on wrong screen
**Solution**:
- Check `screenContainingCursor()` implementation
- Verify screen configuration change handling
- Reset window position in settings

#### 4. Hotkey Not Working
**Problem**: Global hotkey doesn't trigger
**Solution**:
- Check Accessibility permissions
- Verify key code mapping
- Restart GlobalHotkeyService

### Debugging Tools

```swift
// Enable debug logging
UserDefaults.standard.set(true, forKey: "LaunchyDebugMode")

// Performance profiling
let startTime = CFAbsoluteTimeGetCurrent()
// ... operation
let timeElapsed = CFAbsoluteTimeGetCurrent() - startTime
print("Time: \(timeElapsed) seconds")

// Memory debugging
func printMemoryUsage() {
    let info = mach_task_basic_info()
    var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
    
    let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
        $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
            task_info(mach_task_self_,
                     task_flavor_t(MACH_TASK_BASIC_INFO),
                     $0,
                     &count)
        }
    }
    
    if kerr == KERN_SUCCESS {
        print("Memory used: \(info.resident_size / 1024 / 1024) MB")
    }
}
```

### Performance Optimization

1. **Search Optimization**
   - Use SearchIndex for large app collections
   - Implement debouncing for search queries
   - Cache search results

2. **Memory Management**
   - Use NSCache for icon storage
   - Implement proper cleanup in deinit
   - Avoid strong reference cycles

3. **UI Performance**
   - Use LazyVStack for large grids
   - Implement view recycling
   - Optimize image loading

---

## 📝 Changelog

### Version 0.4.2 (Current)
- ✅ Fixed memory leaks in ApplicationIconProvider
- ✅ Added Spotlight search integration
- ✅ Implemented Dashboard widget support
- ✅ Optimized search algorithm with indexing
- ✅ Enhanced multi-monitor handling
- ✅ Added app exclusion features
- ✅ Expanded customization options
- ✅ Implemented Launchpad preferences integration

### Version 0.4.1
- 🐛 Fixed force unwrap crashes
- 🔧 Improved error handling
- 📱 Enhanced UI responsiveness

### Version 0.4.0
- 🚀 Initial public release
- 📱 Basic Launchpad functionality
- 🎨 SwiftUI interface
- 📁 Folder support
- 🔄 Drag and drop

---

## 🤝 Contributing

### How to Contribute

1. **Fork** the repository
2. **Create** a feature branch: `git checkout -b feature/amazing-feature`
3. **Commit** your changes: `git commit -m 'Add amazing feature'`
4. **Push** to the branch: `git push origin feature/amazing-feature`
5. **Open** a Pull Request

### Code Style

- **Swift 6** conventions
- **SwiftLint** compliance
- **Documentation** for public APIs
- **Tests** for new features

### Issue Reporting

- Use GitHub Issues for bug reports
- Include system information (macOS version, hardware)
- Provide reproduction steps
- Include crash logs if applicable

---

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

## 🙏 Acknowledgments

- **Apple** for SwiftUI and the original Launchpad inspiration
- **Swift Community** for the amazing tools and libraries
- **macOS Developers** for feedback and contributions

---

*This DeepWiki is maintained alongside the codebase and updated with each release. For the most up-to-date information, always check the latest version.*
