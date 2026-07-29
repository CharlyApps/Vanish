import SwiftUI
import UniformTypeIdentifiers

// MARK: - Scanning

struct Leftover: Identifiable {
    let url: URL
    let size: Int64
    var id: URL { url }
}

enum LeftoverScanner {
    // Standard leftover locations, relative to ~/Library
    static let libraryDirs = [
        "Application Support", "Caches", "Containers", "Group Containers",
        "HTTPStorages", "Logs", "Preferences", "Saved Application State",
        "WebKit", "LaunchAgents", "Application Scripts", "Cookies",
    ]

    static func matches(_ entryName: String, bundleID: String, appName: String) -> Bool {
        let e = entryName.lowercased()
        let name = appName.lowercased()
        // ponytail: substring match on bundle id + exact match on app name;
        // fuzzier name matching risks eating unrelated files
        return e.contains(bundleID.lowercased()) || e == name || e == name + ".plist"
    }

    static func scan(appURL: URL, library: URL) -> [Leftover] {
        guard let bundle = Bundle(url: appURL),
              let bundleID = bundle.bundleIdentifier else { return [] }
        let appName = appURL.deletingPathExtension().lastPathComponent
        let fm = FileManager.default
        var found: [URL] = [appURL]
        for dir in libraryDirs {
            let base = library.appendingPathComponent(dir)
            guard let entries = try? fm.contentsOfDirectory(at: base, includingPropertiesForKeys: nil) else { continue }
            found += entries.filter { matches($0.lastPathComponent, bundleID: bundleID, appName: appName) }
        }
        return found.map { Leftover(url: $0, size: totalSize(of: $0)) }
    }

    static func totalSize(of url: URL) -> Int64 {
        let fm = FileManager.default
        var total: Int64 = (try? url.resourceValues(forKeys: [.totalFileAllocatedSizeKey]).totalFileAllocatedSize).flatMap(Int64.init) ?? 0
        if let e = fm.enumerator(at: url, includingPropertiesForKeys: [.totalFileAllocatedSizeKey]) {
            for case let f as URL in e {
                total += Int64((try? f.resourceValues(forKeys: [.totalFileAllocatedSizeKey]).totalFileAllocatedSize) ?? 0)
            }
        }
        return total
    }
}

// MARK: - Privileged removal

enum Admin {
    // Builds: do shell script "rm -rf " & quoted form of "<path>" & ... with administrator privileges
    // `quoted form of` handles shell escaping; we only escape for the AppleScript string literal.
    static func removeScript(for paths: [String]) -> String {
        let quoted = paths.map { p in
            "quoted form of \"" + p
                .replacingOccurrences(of: "\\", with: "\\\\")
                .replacingOccurrences(of: "\"", with: "\\\"") + "\""
        }.joined(separator: " & \" \" & ")
        return "do shell script \"rm -rf \" & " + quoted + " with administrator privileges"
    }

    /// Removes with an admin-password prompt. Returns an error message, or nil on success/cancel.
    /// ponytail: osascript-style escalation instead of a SMJobBless helper; revisit only if Apple kills this API
    static func remove(_ urls: [URL]) -> String? {
        var error: NSDictionary?
        NSAppleScript(source: removeScript(for: urls.map(\.path)))?.executeAndReturnError(&error)
        guard let error else { return nil }
        if error[NSAppleScript.errorNumber] as? Int == -128 { return nil } // user cancelled
        return error[NSAppleScript.errorMessage] as? String ?? "Administrator removal failed."
    }
}

// MARK: - UI

struct ContentView: View {
    @State private var appURL: URL?
    @State private var leftovers: [Leftover] = []
    @State private var selected: Set<URL> = []
    @State private var targeted = false
    @State private var confirming = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 12) {
            if let appURL {
                Text(appURL.deletingPathExtension().lastPathComponent)
                    .font(.title2).bold()
                List {
                    ForEach(leftovers) { item in
                        Toggle(isOn: binding(for: item.url)) {
                            VStack(alignment: .leading) {
                                Text(item.url.lastPathComponent)
                                Text(item.url.path)
                                    .font(.caption).foregroundStyle(.secondary)
                                    .lineLimit(1).truncationMode(.middle)
                            }
                        }
                        .badge(ByteCountFormatter.string(fromByteCount: item.size, countStyle: .file))
                    }
                }
                HStack {
                    Button("Clear") { reset() }
                    Spacer()
                    Text(ByteCountFormatter.string(fromByteCount: selectedSize, countStyle: .file))
                        .foregroundStyle(.secondary)
                    Button("Vanish \(selected.count) item\(selected.count == 1 ? "" : "s")") {
                        confirming = true
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(selected.isEmpty)
                }
                .padding([.horizontal, .bottom])
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "bolt.trianglebadge.exclamationmark")
                        .font(.system(size: 48))
                        .foregroundStyle(targeted ? .yellow : .secondary)
                    Text("Drop an app here to make it vanish")
                        .font(.title3).foregroundStyle(.secondary)
                    Button("Choose App…") { chooseApp() }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(minWidth: 480, minHeight: 400)
        .onDrop(of: [.fileURL], isTargeted: $targeted) { providers in
            _ = providers.first?.loadObject(ofClass: URL.self) { url, _ in
                if let url { DispatchQueue.main.async { load(url) } }
            }
            return true
        }
        .confirmationDialog(
            "Move \(selected.count) item\(selected.count == 1 ? "" : "s") to the Trash?",
            isPresented: $confirming
        ) {
            Button("Vanish!", role: .destructive) { vanish() }
        } message: {
            Text("Everything goes to the Trash — you can put it back if you change your mind.")
        }
        .alert(
            "Some items could not be removed",
            isPresented: Binding(get: { errorMessage != nil }, set: { _ in errorMessage = nil })
        ) {} message: {
            Text(errorMessage ?? "")
        }
    }

    private var selectedSize: Int64 {
        leftovers.filter { selected.contains($0.url) }.reduce(0) { $0 + $1.size }
    }

    private func binding(for url: URL) -> Binding<Bool> {
        Binding(
            get: { selected.contains(url) },
            set: { if $0 { selected.insert(url) } else { selected.remove(url) } }
        )
    }

    private func load(_ url: URL) {
        guard url.pathExtension == "app", !url.path.hasPrefix("/System") else { return }
        let library = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library")
        appURL = url
        leftovers = LeftoverScanner.scan(appURL: url, library: library)
        selected = Set(leftovers.map(\.url))
    }

    private func chooseApp() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.applicationBundle]
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        if panel.runModal() == .OK, let url = panel.url { load(url) }
    }

    private func vanish() {
        let fm = FileManager.default
        var needAdmin: [URL] = []
        for url in selected {
            do { try fm.trashItem(at: url, resultingItemURL: nil) }
            catch { needAdmin.append(url) }
        }
        if !needAdmin.isEmpty {
            errorMessage = Admin.remove(needAdmin)
        }
        reset()
    }

    private func reset() {
        appURL = nil
        leftovers = []
        selected = []
    }
}

@main
struct VanishApp: App {
    init() {
        DispatchQueue.main.async {
            NSApp.setActivationPolicy(.regular)
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    var body: some Scene {
        WindowGroup("Vanish") { ContentView() }
    }
}
