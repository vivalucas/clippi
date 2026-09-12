// Compile with MainViewModel.swift, Localization.swift, ClippiFFI.swift,
// the ClippiCore.h bridging header and the built Rust static library.
import Foundation

@main
struct ModelRegressionChecks {
    @MainActor static func waitForImport(_ model: MainViewModel) async throws {
        let deadline = Date().addingTimeInterval(30)
        while model.isImporting && Date() < deadline { try await Task.sleep(nanoseconds: 10_000_000) }
        precondition(!model.isImporting, "Import timed out")
    }
    @MainActor static func main() async throws {
        let source = CommandLine.arguments[1]
        let suiteName = "clippi-regression-\(UUID().uuidString)"
        let preferences = UserDefaults(suiteName: suiteName)!
        defer { preferences.removePersistentDomain(forName: suiteName) }
        let model = MainViewModel(preferences: preferences)
        model.probeFile(at: URL(fileURLWithPath: source))
        try await waitForImport(model)
        precondition(model.fileInfo != nil && model.endTime > 0)
        model.startTime = 1
        model.probeFile(at: URL(fileURLWithPath: source))
        try await waitForImport(model)
        precondition(model.startTime == 0, "Replacing media must reset the trim range")
        print("PASS replacing media resets trim")
        model.probeFile(at: URL(fileURLWithPath: "/tmp/clippi-nonexistent-regression.mp4"))
        try await waitForImport(model)
        precondition(model.showError && model.fileInfo?.path == source)
        print("PASS failed probe preserves valid source and reports error")
        model.showError = false
        model.selectedOperation = .convert
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        model.outputPath = directory.appendingPathComponent("cancelled.mp4").path
        model.startProcessing()
        model.cancelProcessing()
        model.outputPath = directory.appendingPathComponent("completed.mp4").path
        model.startProcessing()
        let deadline = Date().addingTimeInterval(30)
        while model.isProcessing && Date() < deadline { try await Task.sleep(nanoseconds: 10_000_000) }
        precondition(!model.isProcessing && model.progress == 100 && !model.showError)
        print("PASS immediate cancellation does not corrupt the next export")
        let second = directory.appendingPathComponent("second.mp4")
        let third = directory.appendingPathComponent("third.mp4")
        try FileManager.default.copyItem(at: URL(fileURLWithPath: source), to: second)
        try FileManager.default.copyItem(at: URL(fileURLWithPath: source), to: third)
        model.importMedia(urls: [URL(fileURLWithPath: source), second, third])
        try await waitForImport(model)
        model.rotateCurrent(by: 90)
        model.applyCurrentCorrection()
        model.correctionOutputDirectory = directory
        model.startCorrectionQueue()
        let queueDeadline = Date().addingTimeInterval(30)
        while model.isProcessing && Date() < queueDeadline { try await Task.sleep(nanoseconds: 10_000_000) }
        precondition(model.mediaItems.count == 3 && model.mediaItems.allSatisfy { $0.status == .completed })
        print("PASS correction queue completes")
        model.selectedMediaId = model.mediaItems[1].id
        model.useSelectedMedia()
        precondition(model.fileInfo?.path == second.path)
        model.useSourceForCorrection()
        precondition(model.selectedMediaItem?.info.path == second.path && model.mediaItems.count == 3)
        print("PASS selected source stays consistent across tools")
        model.selectedOperation = .convert
        model.outputPath = directory.appendingPathComponent("custom-name.mp4").path
        model.outputFormat = .mkv
        precondition(model.outputPath == directory.appendingPathComponent("custom-name.mkv").path)
        print("PASS format changes preserve custom output directory and name")
        let existingOutput = model.outputPath
        model.defaultOutputDirectory = directory.path
        precondition(model.outputPath == existingOutput)
        let restored = MainViewModel(preferences: preferences)
        precondition(restored.defaultOutputDirectory == directory.path)
        restored.probeFile(at: URL(fileURLWithPath: source))
        let importDeadline = Date().addingTimeInterval(30)
        while restored.isImporting && Date() < importDeadline { try await Task.sleep(nanoseconds: 10_000_000) }
        precondition(!restored.isImporting && URL(fileURLWithPath: restored.outputPath).deletingLastPathComponent().standardizedFileURL.path == directory.standardizedFileURL.path)
        print("PASS default output preference persists and applies only to new input")
        restored.startTime = 0.5
        restored.endTime = 1000
        restored.startProcessing()
        let trimDeadline = Date().addingTimeInterval(30)
        while restored.isProcessing && Date() < trimDeadline { try await Task.sleep(nanoseconds: 10_000_000) }
        precondition(restored.startTime == 0.5 && restored.endTime == restored.fileInfo?.duration && restored.progress == 100)
        print("PASS trim end is clamped without changing start")
    }
}
