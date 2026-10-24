import AppKit
import CoreGraphics
import CryptoKit
import Foundation
import ImageIO
import UniformTypeIdentifiers

struct ToolError: Error, CustomStringConvertible { let description: String }
func require(_ value: Bool, _ message: String) throws { if !value { throw ToolError(description: message) } }
let fm = FileManager.default
let workspace = NSWorkspace.shared
func absolute(_ path: String) -> URL { URL(fileURLWithPath: path).standardizedFileURL }
func hash(_ file: URL) throws -> String { SHA256.hash(data: try Data(contentsOf: file, options: .mappedIfSafe)).map { String(format: "%02x", $0) }.joined() }
func encoded<T: Encodable>(_ value: T) throws -> Data { let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]; return try encoder.encode(value) }
func output<T: Encodable>(_ value: T) throws { FileHandle.standardOutput.write(try encoded(value)); print("") }
func save<T: Encodable>(_ value: T, _ file: URL) throws { try encoded(value).write(to: file, options: .atomic) }
func read<T: Decodable>(_ type: T.Type, _ file: URL) throws -> T { try JSONDecoder().decode(type, from: Data(contentsOf: file)) }

struct DesktopOptions: Codable {
    var Scaling: Int?
    var AllowClipping: Bool?
    var FillColor: [Double]?
    init(_ raw: [NSWorkspace.DesktopImageOptionKey: Any] = [:]) {
        Scaling = (raw[.imageScaling] as? NSNumber)?.intValue
        AllowClipping = (raw[.allowClipping] as? NSNumber)?.boolValue
        if let color = (raw[.fillColor] as? NSColor)?.usingColorSpace(.sRGB) { FillColor = [color.redComponent, color.greenComponent, color.blueComponent, color.alphaComponent].map(Double.init) }
    }
    var native: [NSWorkspace.DesktopImageOptionKey: Any] {
        var result: [NSWorkspace.DesktopImageOptionKey: Any] = [:]
        if let scaling = Scaling { result[.imageScaling] = scaling }
        if let clipping = AllowClipping { result[.allowClipping] = clipping }
        if let color = FillColor, color.count == 4 { result[.fillColor] = NSColor(srgbRed: color[0], green: color[1], blue: color[2], alpha: color[3]) }
        return result
    }
}
struct Monitor: Codable {
    var Index: Int
    var Id: String
    var Name: String
    var Width: Int
    var Height: Int
    var LogicalWidth: Double
    var LogicalHeight: Double
    var BackingScaleFactor: Double
    var Image: String?
    var Options: DesktopOptions
}
struct State: Codable { var Platform = "macOS"; var SizeBasis = "current display-mode/backing pixels, not UI points"; var Monitors: [Monitor] }
struct Entry: Codable {
    var MonitorId: String
    var Index: Int
    var NativeWidth: Int
    var NativeHeight: Int
    var Width: Int
    var Height: Int
    var File: String
    var Source: String
    var RetainedArea: Double
    var SHA256: String
}
struct Manifest: Codable { var SchemaVersion = 1; var Platform = "macOS"; var PixelScale: Double; var Entries: [Entry] }
struct Backup: Codable { var Platform = "macOS"; var State: State }

func screenId(_ screen: NSScreen) throws -> String {
    guard let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber,
          let uuid = CGDisplayCreateUUIDFromDisplayID(CGDirectDisplayID(number.uint32Value))?.takeRetainedValue() else { throw ToolError(description: "Cannot obtain a stable display UUID.") }
    return CFUUIDCreateString(nil, uuid) as String
}
func screens() throws -> [(NSScreen, Monitor)] {
    precondition(Thread.isMainThread)
    return try NSScreen.screens.enumerated().map { index, screen in
        let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as! NSNumber
        let mode = CGDisplayCopyDisplayMode(CGDirectDisplayID(number.uint32Value))
        let backing = screen.convertRectToBacking(screen.frame).size
        var width = mode?.pixelWidth ?? Int(backing.width.rounded())
        var height = mode?.pixelHeight ?? Int(backing.height.rounded())
        if (screen.frame.height > screen.frame.width) != (height > width) { swap(&width, &height) }
        width = max(width, Int(backing.width.rounded())); height = max(height, Int(backing.height.rounded()))
        return (screen, Monitor(Index: index + 1, Id: try screenId(screen), Name: screen.localizedName, Width: width, Height: height,
            LogicalWidth: Double(screen.frame.width), LogicalHeight: Double(screen.frame.height), BackingScaleFactor: Double(screen.backingScaleFactor),
            Image: workspace.desktopImageURL(for: screen)?.path, Options: DesktopOptions(workspace.desktopImageOptions(for: screen) ?? [:])))
    }
}
func inspect() throws -> State { let monitors = try screens().map { $0.1 }; try require(!monitors.isEmpty, "No active macOS GUI displays. Run in the logged-in desktop session."); return State(Monitors: monitors) }
func loadImage(_ file: URL) throws -> CGImage {
    guard let source = CGImageSourceCreateWithURL(file as CFURL, nil), let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else { throw ToolError(description: "Cannot decode image: \(file.path)") }
    return image
}
func writePNG(_ image: CGImage, _ file: URL) throws {
    guard let destination = CGImageDestinationCreateWithURL(file as CFURL, UTType.png.identifier as CFString, 1, nil) else { throw ToolError(description: "Cannot create PNG: \(file.path)") }
    CGImageDestinationAddImage(destination, image, nil)
    try require(CGImageDestinationFinalize(destination), "Saving PNG failed.")
}
func prepare(_ monitors: [Monitor], master: String?, sourceMap: [String: String], directory: URL, scale: Double) throws -> Manifest {
    try require(scale.isFinite && scale >= 1 && scale <= 4, "Pixel scale must be between 1 and 4.")
    try require(!fm.fileExists(atPath: directory.appendingPathComponent("wallpaper-manifest.json").path), "Output directory already contains a manifest; use a new directory.")
    var entries: [Entry] = []
    for monitor in monitors {
        guard let sourcePath = sourceMap[monitor.Id] ?? master else { throw ToolError(description: "No AI source for display \(monitor.Index).") }
        let source = absolute(sourcePath), image = try loadImage(source)
        let width = Int(ceil(Double(monitor.Width) * scale)), height = Int(ceil(Double(monitor.Height) * scale))
        let ratio = Double(width) / Double(height)
        let cropWidth = min(Double(image.width), Double(image.height) * ratio)
        let cropHeight = min(Double(image.height), Double(image.width) / ratio)
        try require(cropWidth >= Double(width) && cropHeight >= Double(height), "AI master has insufficient pixels for display \(monitor.Index); need a crop of at least \(width)x\(height). Ordinary enlargement is rejected.")
        let file = directory.appendingPathComponent(String(format: "wallpaper_%02d_%dx%d.png", monitor.Index, width, height))
        try require(!fm.fileExists(atPath: file.path), "Refusing to overwrite \(file.path)")
        entries.append(Entry(MonitorId: monitor.Id, Index: monitor.Index, NativeWidth: monitor.Width, NativeHeight: monitor.Height, Width: width, Height: height, File: file.path, Source: source.path, RetainedArea: cropWidth * cropHeight / Double(image.width * image.height), SHA256: ""))
    }
    try fm.createDirectory(at: directory, withIntermediateDirectories: true)
    for index in entries.indices {
        let entry = entries[index], image = try loadImage(absolute(entry.Source))
        guard let context = CGContext(data: nil, width: entry.Width, height: entry.Height, bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { throw ToolError(description: "Cannot allocate output image memory.") }
        context.interpolationQuality = .high
        let fillScale = max(Double(entry.Width) / Double(image.width), Double(entry.Height) / Double(image.height))
        let drawWidth = Double(image.width) * fillScale, drawHeight = Double(image.height) * fillScale
        context.draw(image, in: CGRect(x: (Double(entry.Width) - drawWidth) / 2, y: (Double(entry.Height) - drawHeight) / 2, width: drawWidth, height: drawHeight))
        guard let result = context.makeImage() else { throw ToolError(description: "Cannot create output image.") }
        let file = absolute(entry.File)
        try writePNG(result, file)
        let check = try loadImage(file)
        try require(check.width == entry.Width && check.height == entry.Height, "Saved pixel dimensions failed verification.")
        entries[index].SHA256 = try hash(file)
    }
    let manifest = Manifest(PixelScale: scale, Entries: entries)
    try save(manifest, directory.appendingPathComponent("wallpaper-manifest.json"))
    return manifest
}
func apply(_ manifest: Manifest, manifestFile: URL) throws -> [String: String] {
    try require(manifest.SchemaVersion == 1 && manifest.Platform == "macOS" && manifest.PixelScale >= 1 && manifest.PixelScale <= 4, "Unsupported macOS manifest.")
    let current = try inspect()
    try require(manifest.Entries.count == current.Monitors.count && Set(manifest.Entries.map { $0.MonitorId }).count == current.Monitors.count, "Display identities/count changed; prepare again.")
    for entry in manifest.Entries {
        guard let monitor = current.Monitors.first(where: { $0.Id == entry.MonitorId }) else { throw ToolError(description: "Display UUID changed; prepare again.") }
        try require(monitor.Width == entry.NativeWidth && monitor.Height == entry.NativeHeight, "Display resolution/orientation changed; prepare again.")
        let image = try loadImage(absolute(entry.File))
        try require(image.width == Int(ceil(Double(monitor.Width) * manifest.PixelScale)) && image.height == Int(ceil(Double(monitor.Height) * manifest.PixelScale)), "Wallpaper dimensions do not match the display.")
        try require(try hash(absolute(entry.File)) == entry.SHA256, "Wallpaper changed after preparation; no settings changed.")
    }
    let backupFile = manifestFile.deletingLastPathComponent().appendingPathComponent("wallpaper-backup-\(UUID().uuidString).json")
    try save(Backup(State: current), backupFile)
    let options: [NSWorkspace.DesktopImageOptionKey: Any] = [.imageScaling: NSImageScaling.scaleProportionallyUpOrDown.rawValue, .allowClipping: true]
    do {
        for (screen, monitor) in try screens() {
            guard let entry = manifest.Entries.first(where: { $0.MonitorId == monitor.Id }) else { throw ToolError(description: "Display changed during apply.") }
            try workspace.setDesktopImageURL(absolute(entry.File), for: screen, options: options)
        }
        let after = try inspect()
        try require(after.Monitors.count == current.Monitors.count, "Display count changed during apply.")
        for monitor in after.Monitors {
            let expected = manifest.Entries.first { $0.MonitorId == monitor.Id }?.File
            try require(monitor.Image == expected, "Wallpaper path read-back failed.")
        }
    } catch {
        let original = error
        do { try restore(Backup(State: current)) } catch { throw ToolError(description: "Apply failed: \(original). Restoring also failed: \(error). Backup: \(backupFile.path)") }
        throw original
    }
    return ["Status": "Applied and read-back verified", "BackupPath": backupFile.path]
}
func restore(_ backup: Backup) throws {
    try require(backup.Platform == "macOS", "Not a macOS backup.")
    let current = try screens()
    try require(Set(current.map { $0.1.Id }) == Set(backup.State.Monitors.map { $0.Id }), "Display UUIDs changed; cannot restore this backup.")
    for monitor in backup.State.Monitors { guard let image = monitor.Image, fm.fileExists(atPath: image) else { throw ToolError(description: "Old static image is unavailable; cannot restore display \(monitor.Index).") } }
    for (screen, monitor) in current {
        let old = backup.State.Monitors.first { $0.Id == monitor.Id }!
        try workspace.setDesktopImageURL(absolute(old.Image!), for: screen, options: old.Options.native)
    }
    let after = try inspect()
    for monitor in after.Monitors { try require(monitor.Image == backup.State.Monitors.first { $0.Id == monitor.Id }?.Image, "Restored wallpaper path read-back failed.") }
}
func fixture(width: Int, height: Int, file: URL) throws {
    let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    context.setFillColor(CGColor(red: 0.2, green: 0.45, blue: 0.65, alpha: 1)); context.fill(CGRect(x: 0, y: 0, width: Double(width), height: Double(height)))
    context.setFillColor(CGColor(red: 0.85, green: 0.3, blue: 0.2, alpha: 1)); context.fill(CGRect(x: Double(width / 3), y: Double(height / 4), width: Double(width / 3), height: Double(height / 2)))
    try writePNG(context.makeImage()!, file)
}

do {
    _ = NSApplication.shared
    let args = Array(CommandLine.arguments.dropFirst())
    let mode = args.first ?? "inspect"
    var flags: [String: String] = [:]; var index = 1
    while index < args.count { try require(args[index].hasPrefix("--") && index + 1 < args.count, "Options must be --name value pairs."); flags[args[index]] = args[index + 1]; index += 2 }
    func needed(_ key: String) throws -> String { guard let value = flags[key], !value.isEmpty else { throw ToolError(description: "Missing \(key)") }; return value }
    switch mode {
    case "inspect": try output(inspect())
    case "prepare":
        let sources = try flags["--sources"].map { try read([String: String].self, absolute($0)) } ?? [:]
        guard let scale = Double(flags["--pixel-scale"] ?? "2") else { throw ToolError(description: "Invalid pixel scale.") }
        try output(prepare(inspect().Monitors, master: flags["--master"], sourceMap: sources, directory: absolute(try needed("--output")), scale: scale))
    case "apply":
        let file = absolute(try needed("--manifest")); try output(apply(read(Manifest.self, file), manifestFile: file))
    case "restore":
        try restore(read(Backup.self, absolute(try needed("--manifest")))); try output(inspect())
    case "image-size":
        let image = try loadImage(absolute(try needed("--image"))); try output(["Width": image.width, "Height": image.height])
    case "self-test":
        let directory = absolute(try needed("--output")); try fm.createDirectory(at: directory, withIntermediateDirectories: true)
        let source = directory.appendingPathComponent("fixture.png"); try fixture(width: 800, height: 600, file: source)
        let fake = [Monitor(Index: 1, Id: "test-landscape", Name: "Synthetic landscape", Width: 320, Height: 200, LogicalWidth: 320, LogicalHeight: 200, BackingScaleFactor: 1, Image: nil, Options: DesktopOptions()), Monitor(Index: 2, Id: "test-portrait", Name: "Synthetic portrait", Width: 100, Height: 180, LogicalWidth: 100, LogicalHeight: 180, BackingScaleFactor: 1, Image: nil, Options: DesktopOptions())]
        let result = try prepare(fake, master: source.path, sourceMap: [:], directory: directory.appendingPathComponent("geometry"), scale: 2)
        try require(result.Entries.map { [$0.Width, $0.Height] } == [[640, 400], [200, 360]], "Landscape/portrait geometry test failed.")
        var rejected = false
        do { _ = try prepare(fake, master: source.path, sourceMap: [:], directory: directory.appendingPathComponent("insufficient"), scale: 4) } catch { rejected = String(describing: error).contains("insufficient pixels") }
        try require(rejected, "Insufficient-pixel rejection failed.")
        try fixture(width: 64, height: 64, file: directory.appendingPathComponent("gpu-input.png"))
        try output(["Geometry": "PASS", "InsufficientPixelsRejected": "PASS", "Source": source.path])
    case "desktop-test":
        let directory = absolute(try needed("--output")); try fm.createDirectory(at: directory, withIntermediateDirectories: true)
        let before = try inspect()
        let maxEdge = before.Monitors.map { max($0.Width, $0.Height) }.max()!
        try require(maxEdge <= 8000, "CI display is unexpectedly large.")
        let source = directory.appendingPathComponent("desktop-fixture.png"); try fixture(width: maxEdge, height: maxEdge, file: source)
        let generated = try prepare(before.Monitors, master: source.path, sourceMap: [:], directory: directory.appendingPathComponent("images"), scale: 1)
        let manifestFile = directory.appendingPathComponent("images/wallpaper-manifest.json")
        var changed = generated; changed.Entries[0].SHA256 = String(repeating: "0", count: 64)
        var rejected = false
        do { _ = try apply(changed, manifestFile: manifestFile) } catch { rejected = String(describing: error).contains("changed after preparation") }
        try require(rejected, "Changed file was not rejected.")
        let applied = try apply(generated, manifestFile: manifestFile)
        try restore(read(Backup.self, absolute(applied["BackupPath"]!)))
        try output(["DesktopRoundTrip": "PASS", "TamperRejected": "PASS", "Screens": String(before.Monitors.count)])
    default: throw ToolError(description: "Use inspect, prepare, apply, restore, image-size, self-test or desktop-test.")
    }
} catch { FileHandle.standardError.write(Data("change-wallpaper: \(error)\n".utf8)); exit(1) }
