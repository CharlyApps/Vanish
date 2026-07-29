import Foundation
import Testing
@testable import Vanish

@Test func matcher() {
    #expect(LeftoverScanner.matches("com.example.MyApp", bundleID: "com.example.myapp", appName: "MyApp"))
    #expect(LeftoverScanner.matches("com.example.myapp.savedState", bundleID: "com.example.myapp", appName: "MyApp"))
    #expect(LeftoverScanner.matches("MyApp", bundleID: "com.example.myapp", appName: "MyApp"))
    #expect(LeftoverScanner.matches("myapp.plist", bundleID: "com.example.myapp", appName: "MyApp"))
    #expect(!LeftoverScanner.matches("com.other.thing", bundleID: "com.example.myapp", appName: "MyApp"))
    #expect(!LeftoverScanner.matches("MyAppointments", bundleID: "com.example.myapp", appName: "MyApp"))
}

@Test func adminScriptQuoting() {
    let script = Admin.removeScript(for: ["/Applications/My \"Weird\" App.app", "/tmp/plain"])
    #expect(script == "do shell script \"rm -rf \" & quoted form of \"/Applications/My \\\"Weird\\\" App.app\" & \" \" & quoted form of \"/tmp/plain\" with administrator privileges")
}

@Test func scanFindsLeftovers() throws {
    let fm = FileManager.default
    let tmp = fm.temporaryDirectory.appendingPathComponent("zaptest-\(UUID().uuidString)")
    let library = tmp.appendingPathComponent("Library")

    // Fake app bundle with a bundle id
    let app = tmp.appendingPathComponent("FakeApp.app")
    try fm.createDirectory(at: app.appendingPathComponent("Contents"), withIntermediateDirectories: true)
    let plist: [String: Any] = ["CFBundleIdentifier": "com.test.fakeapp"]
    let data = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
    try data.write(to: app.appendingPathComponent("Contents/Info.plist"))

    // Leftovers + a decoy
    try fm.createDirectory(at: library.appendingPathComponent("Caches/com.test.fakeapp"), withIntermediateDirectories: true)
    try fm.createDirectory(at: library.appendingPathComponent("Application Support/FakeApp"), withIntermediateDirectories: true)
    try fm.createDirectory(at: library.appendingPathComponent("Caches/com.unrelated.app"), withIntermediateDirectories: true)

    let found = Set(LeftoverScanner.scan(appURL: app, library: library).map(\.url.lastPathComponent))
    #expect(found == ["FakeApp.app", "com.test.fakeapp", "FakeApp"])

    try? fm.removeItem(at: tmp)
}
