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

    enum OperationType: String, CaseIterable {
        case trim = "裁剪"
        case convert = "转换格式"
        case scale = "缩放"
        case extractAudio = "提取音频"
        case removeAudio = "去除音频"
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
        let path = url.path

        Task {
            let result = await Self.loadProbeResult(path: path)
            applyProbeResult(result, path: path)
        }
    }

    func startProcessing() {
        guard fileInfo != nil else { return }

        isProcessing = true
        progress = 0
        statusMessage = "处理中..."

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
                    showError("启动任务失败")
                }
            }
        }
    }

    func cancelProcessing() {
        if currentTaskId > 0 {
            _ = ClippiFFI.cancelTask(id: currentTaskId)
            currentTaskId = 0
            isProcessing = false
            statusMessage = "已取消"
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

        var config: [String: Any] = [
            "input_path": fileInfo.path,
            "output_path": outputPath,
            "operation": operation,
            "video_codec": gpuInfo?.encoder ?? "libx264",
            "audio_codec": "aac"
        ]

        if let hwAccel = gpuInfo?.hwAccel {
            config["hw_accel"] = hwAccel
        }

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
                statusMessage = "处理完成"
                ClippiFFI.clearProgressCallback()
                return
            case "failed", "cancelled":
                isProcessing = false
                currentTaskId = 0
                ClippiFFI.clearProgressCallback()
                showError(dict["message"] as? String ?? "任务处理失败")
                return
            default:
                break
            }
        }

        var message = "处理中..."
        if let speed = dict["speed"] as? String, !speed.isEmpty {
            message += " 速度: \(speed)"
        }

        if let eta = dict["eta_secs"] as? Int {
            message += " 剩余: \(eta)秒"
        }

        statusMessage = message
    }

    private func generateOutputPath(input: String) -> String {
        let url = URL(fileURLWithPath: input)
        let name = url.deletingPathExtension().lastPathComponent
        let dir = url.deletingLastPathComponent().path
        let ext = outputExtension()
        return "\(dir)/\(name)_output.\(ext)"
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
            showError("无法读取文件信息")
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

    private func outputExtension() -> String {
        if selectedOperation == .extractAudio {
            return audioFormat.rawValue.lowercased()
        }
        return outputFormat.rawValue.lowercased()
    }

    private func showError(_ message: String) {
        errorMessage = message
        showError = true
    }
}
