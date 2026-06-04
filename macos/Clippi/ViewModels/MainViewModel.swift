import Foundation
import SwiftUI
import Combine

@MainActor
class MainViewModel: ObservableObject {
    @Published var fileInfo: FileInfo?
    @Published var selectedOperation: OperationType = .trim {
        didSet { refreshOutputPath() }
    }
    @Published var isProcessing = false
    @Published var progress: Double = 0
    @Published var statusMessage = ""
    @Published var showError = false
    @Published var errorMessage = ""
    @Published var gpuInfo: GpuInfo?

    // Trim settings
    @Published var startTime: Double = 0
    @Published var endTime: Double = 0
    @Published var fastMode = true

    // Scale settings
    @Published var targetResolution: Resolution = .p1080

    // Audio settings
    @Published var audioFormat: AudioFormat = .mp3 {
        didSet { refreshOutputPath() }
    }

    // Output
    @Published var outputFormat: OutputFormat = .mp4 {
        didSet { refreshOutputPath() }
    }
    @Published var outputPath: String = ""

    private var currentTaskId: UInt64 = 0

    enum OperationType: CaseIterable {
        case trim
        case convert
        case scale
        case extractAudio
        case removeAudio

        var title: String {
            switch self {
            case .trim: return L10n.string("operation.trim")
            case .convert: return L10n.string("operation.convert")
            case .scale: return L10n.string("operation.scale")
            case .extractAudio: return L10n.string("operation.extractAudio")
            case .removeAudio: return L10n.string("operation.removeAudio")
            }
        }
    }

    enum Resolution: String, CaseIterable {
        case p4k = "4K (3840x2160)"
        case p1080 = "1080p (1920x1080)"
        case p720 = "720p (1280x720)"
        case p480 = "480p (854x480)"

        var width: Int {
            switch self {
            case .p4k: return 3840
            case .p1080: return 1920
            case .p720: return 1280
            case .p480: return 854
            }
        }

        var height: Int {
            switch self {
            case .p4k: return 2160
            case .p1080: return 1080
            case .p720: return 720
            case .p480: return 480
            }
        }
    }

    enum AudioFormat: String, CaseIterable {
        case mp3 = "MP3"
        case aac = "AAC"
        case wav = "WAV"
    }

    enum OutputFormat: String, CaseIterable {
        case mp4 = "MP4"
        case mkv = "MKV"
        case mov = "MOV"
        case webm = "WebM"
    }

    struct FileInfo {
        let width: Int
        let height: Int
        let duration: Double
        let codec: String
        let frameRate: Double
        let bitrate: Int
        let path: String
    }

    struct GpuInfo {
        let encoder: String?
        let hwAccel: String?
    }

    init() {
        Task {
            let result = await Self.loadGpuDetection()
            applyGpuDetection(result)
        }
    }

    private func applyGpuDetection(_ result: [String: Any]?) {
        guard let result else { return }
        if let encoder = result["video_encoder"] as? String {
            gpuInfo = GpuInfo(encoder: encoder, hwAccel: result["hw_accel"] as? String)
        } else {
            gpuInfo = GpuInfo(encoder: nil, hwAccel: nil)
        }
    }

    func probeFile(at url: URL) {
        guard Self.isSupportedVideo(url) else {
            showError(L10n.string("error.unsupportedVideo"))
            return
        }

        let path = url.path

        Task {
            let result = await Self.loadProbeResult(path: path)
            applyProbeResult(result, path: path)
        }
    }

    func startProcessing() {
        guard validateBeforeStart() else { return }

        isProcessing = true
        progress = 0
        statusMessage = L10n.string("status.processing")

        let config = buildTaskConfig()

        Task {
            let taskId = ClippiFFI.runTask(config: config) { [weak self] progressJson in
                DispatchQueue.main.async {
                    self?.updateProgress(from: progressJson)
                }
            }

            if taskId > 0 {
                currentTaskId = taskId
            } else {
                await MainActor.run {
                    isProcessing = false
                    showError(L10n.string("error.startTaskFailed"))
                }
            }
        }
    }

    func cancelProcessing() {
        if currentTaskId > 0 {
            _ = ClippiFFI.cancelTask(id: currentTaskId)
            currentTaskId = 0
            isProcessing = false
            statusMessage = L10n.string("status.cancelled")
        }
    }

    private func buildTaskConfig() -> [String: Any] {
        guard let fileInfo = fileInfo else { return [:] }

        let operation: Any
        switch selectedOperation {
        case .trim:
            operation = [
                "Trim": [
                    "start": startTime,
                    "end": endTime,
                    "fast_mode": fastMode
                ]
            ]
        case .convert:
            operation = [
                "Convert": [
                    "format": outputFormat.rawValue.lowercased()
                ]
            ]
        case .scale:
            operation = [
                "Scale": [
                    "width": targetResolution.width,
                    "height": targetResolution.height
                ]
            ]
        case .extractAudio:
            operation = [
                "ExtractAudio": [
                    "format": audioFormat.rawValue.lowercased()
                ]
            ]
        case .removeAudio:
            operation = "RemoveAudio"
        }

        let config: [String: Any] = [
            "input_path": fileInfo.path,
            "output_path": outputPath,
            "operation": operation,
            "video_codec": gpuInfo?.encoder ?? "libx264",
            "audio_codec": "aac"
        ]

        return config
    }

    private func updateProgress(from json: String) {
        guard let data = json.data(using: .utf8),
              let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return
        }

        if let percent = dict["percent"] as? Double {
            progress = percent
        }

        if let state = dict["state"] as? String {
            switch state {
            case "completed":
                isProcessing = false
                currentTaskId = 0
                statusMessage = L10n.string("status.completed")
                ClippiFFI.clearProgressCallback()
                return
            case "failed", "cancelled":
                isProcessing = false
                currentTaskId = 0
                ClippiFFI.clearProgressCallback()
                showError(dict["message"] as? String ?? L10n.string("error.taskFailed"))
                return
            default:
                break
            }
        }

        var message = L10n.string("status.processing")
        if let speed = dict["speed"] as? String, !speed.isEmpty {
            message += L10n.format("status.processing.speed", speed)
        }

        if let eta = dict["eta_secs"] as? Int {
            message += L10n.format("status.processing.eta", eta)
        }

        statusMessage = message
    }

    private func generateOutputPath(input: String) -> String {
        let url = URL(fileURLWithPath: input)
        let name = url.deletingPathExtension().lastPathComponent
        let dir = url.deletingLastPathComponent()
        let ext = outputExtension()
        let initial = dir.appendingPathComponent("\(name)_output.\(ext)").path
        return uniqueOutputPath(for: initial)
    }

    private func refreshOutputPath() {
        guard let path = fileInfo?.path else { return }
        outputPath = generateOutputPath(input: path)
    }

    nonisolated private static func loadGpuDetection() async -> [String: Any]? {
        await Task.detached {
            ClippiFFI.detectGpu()
        }.value
    }

    nonisolated private static func loadProbeResult(path: String) async -> [String: Any]? {
        await Task.detached {
            ClippiFFI.probeFile(path: path)
        }.value
    }

    private func applyProbeResult(_ result: [String: Any]?, path: String) {
        guard let result else {
            showError(L10n.string("error.probeFailed"))
            return
        }

        fileInfo = FileInfo(
            width: result["width"] as? Int ?? 0,
            height: result["height"] as? Int ?? 0,
            duration: result["duration_secs"] as? Double ?? 0,
            codec: result["codec"] as? String ?? "unknown",
            frameRate: result["frame_rate"] as? Double ?? 0,
            bitrate: result["bitrate"] as? Int ?? 0,
            path: path
        )

        endTime = fileInfo?.duration ?? 0
        outputPath = generateOutputPath(input: path)
    }

    private func validateBeforeStart() -> Bool {
        guard fileInfo != nil else { return false }

        let trimmedOutput = outputPath.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedOutput.isEmpty else {
            showError(L10n.string("error.outputPathRequired"))
            return false
        }

        let outputUrl = URL(fileURLWithPath: trimmedOutput)
        let outputDir = outputUrl.deletingLastPathComponent().path
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: outputDir, isDirectory: &isDirectory), isDirectory.boolValue else {
            showError(L10n.string("error.outputDirMissing"))
            return false
        }

        guard FileManager.default.isWritableFile(atPath: outputDir) else {
            showError(L10n.string("error.outputDirNotWritable"))
            return false
        }

        guard !FileManager.default.fileExists(atPath: trimmedOutput) else {
            showError(L10n.string("error.outputExists"))
            return false
        }

        if selectedOperation == .trim {
            guard startTime >= 0, endTime > startTime else {
                showError(L10n.string("error.trimEndAfterStart"))
                return false
            }

            if let duration = fileInfo?.duration, duration > 0, startTime >= duration {
                showError(L10n.string("error.trimStartBeforeDuration"))
                return false
            }
        }

        outputPath = trimmedOutput
        return true
    }

    private func uniqueOutputPath(for path: String) -> String {
        let url = URL(fileURLWithPath: path)
        let dir = url.deletingLastPathComponent()
        let name = url.deletingPathExtension().lastPathComponent
        let ext = url.pathExtension

        if !FileManager.default.fileExists(atPath: path) {
            return path
        }

        for index in 2...999 {
            let candidate = dir.appendingPathComponent("\(name) \(index).\(ext)").path
            if !FileManager.default.fileExists(atPath: candidate) {
                return candidate
            }
        }

        return path
    }

    private func outputExtension() -> String {
        if selectedOperation == .extractAudio {
            return audioFormat.rawValue.lowercased()
        }
        return outputFormat.rawValue.lowercased()
    }

    private static func isSupportedVideo(_ url: URL) -> Bool {
        let ext = url.pathExtension.lowercased()
        return ["mp4", "mkv", "mov", "webm", "avi", "m4v"].contains(ext)
    }

    private func showError(_ message: String) {
        errorMessage = message
        showError = true
    }
}
