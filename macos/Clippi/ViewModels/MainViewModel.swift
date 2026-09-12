import Foundation
import SwiftUI
import Combine
import AppKit

@MainActor
class MainViewModel: ObservableObject {
    private let preferences: UserDefaults
    @Published var defaultOutputDirectory: String {
        didSet { preferences.set(defaultOutputDirectory, forKey: "defaultOutputDirectory") }
    }
    @Published var fileInfo: FileInfo?
    @Published var selectedOperation: OperationType = .trim {
        didSet { refreshOutputPath() }
    }
    @Published var isProcessing = false
    @Published var progress: Double = 0
    @Published var statusMessage = ""
    @Published var completedOutputPath: String?
    @Published var showError = false
    @Published var errorMessage = ""
    @Published var errorDetails = ""
    @Published var gpuInfo: GpuInfo?

    // Material correction workspace
    @Published var mediaItems: [MediaItem] = []
    @Published var selectedMediaId: UUID?
    @Published var correctionScope: CorrectionScope = .checked
    @Published var correctionOutputDirectory: URL?
    @Published var isImporting = false
    @Published var overallProgress: Double = 0
    private var correctionTaskIds: [UInt64] = []
    private var pendingCorrectionProgress: [UInt64: String] = [:]
    private var correctionQueueGeneration = 0

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
    private var taskGeneration = 0
    private var probeGeneration = 0

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

    enum CorrectionScope: String, CaseIterable {
        case checked
        case all

        var title: String {
            switch self {
            case .checked: return L10n.string("correction.scope.checked")
            case .all: return L10n.string("correction.scope.all")
            }
        }
    }

    enum MediaStatus: Equatable {
        case ready
        case queued
        case processing
        case completed
        case failed(String)
        case cancelled
    }

    struct Correction: Equatable {
        var rotationDegrees = 0
        var flipHorizontal = false
        var flipVertical = false

        var isIdentity: Bool {
            rotationDegrees == 0 && !flipHorizontal && !flipVertical
        }

        var summary: String {
            var parts: [String] = []
            switch rotationDegrees {
            case 90: parts.append(L10n.string("correction.rotate.right"))
            case 180: parts.append(L10n.string("correction.rotate.180"))
            case 270: parts.append(L10n.string("correction.rotate.left"))
            default: break
            }
            if flipHorizontal { parts.append(L10n.string("correction.flip.horizontal")) }
            if flipVertical { parts.append(L10n.string("correction.flip.vertical")) }
            return parts.isEmpty ? L10n.string("correction.none") : parts.joined(separator: " + ")
        }
    }

    struct MediaItem: Identifiable {
        let id = UUID()
        let info: FileInfo
        var isChecked = true
        var correction = Correction()
        var status: MediaStatus = .ready
        var progress: Double = 0
        var taskId: UInt64?

        var needsProcessing: Bool {
            !correction.isIdentity || info.rotationDegrees != 0
        }

        var isPending: Bool {
            guard needsProcessing else { return false }
            switch status {
            case .ready, .failed, .cancelled: return true
            case .queued, .processing, .completed: return false
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
        let hasAudio: Bool
        let pixelFormat: String
        let colorTransfer: String
        let isHDR: Bool
        let rotationDegrees: Int
        let path: String
    }

    struct GpuInfo {
        let encoder: String?
        let hwAccel: String?
    }

    init(preferences: UserDefaults = .standard) {
        self.preferences = preferences
        self.defaultOutputDirectory = preferences.string(forKey: "defaultOutputDirectory") ?? ""
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

    // Reuse the same selected source across tools instead of maintaining two unrelated inputs.
    func useSourceForCorrection() {
        guard !isProcessing, !isImporting, let info = fileInfo, info.width > 0 else { return }
        if let existing = mediaItems.first(where: { $0.info.path == info.path }) {
            selectedMediaId = existing.id
        } else {
            let item = MediaItem(info: info)
            mediaItems.append(item)
            selectedMediaId = item.id
        }
    }

    func useSelectedMedia() {
        guard !isProcessing, !isImporting, let item = selectedMediaItem,
              item.info.path != fileInfo?.path else { return }
        fileInfo = item.info
        startTime = 0
        endTime = item.info.duration
        progress = 0
        statusMessage = ""
        completedOutputPath = nil
        outputPath = generateOutputPath(input: item.info.path)
    }

    func probeFile(at url: URL) {
        guard !isProcessing, !isImporting else { return }
        guard Self.isSupportedMedia(url) else {
            showError(L10n.string("error.unsupportedVideo"))
            return
        }

        isImporting = true
        let path = url.path
        probeGeneration += 1
        let generation = probeGeneration

        Task {
            let result = await Self.loadProbeResult(path: path)
            guard generation == probeGeneration else { return }
            isImporting = false
            applyProbeResult(result, path: path)
        }
    }

    func startProcessing() {
        guard !isProcessing, !isImporting, validateBeforeStart() else { return }

        isProcessing = true
        progress = 0
        completedOutputPath = nil
        statusMessage = L10n.string("status.processing")

        let config = buildTaskConfig()
        taskGeneration += 1
        let generation = taskGeneration

        Task {
            let taskId = await Task.detached {
                ClippiFFI.runTask(config: config) { [weak self] progressJson in
                    DispatchQueue.main.async {
                        guard let self, self.taskGeneration == generation else { return }
                        self.updateProgress(from: progressJson)
                    }
                }
            }.value
            guard taskGeneration == generation, isProcessing else {
                if taskId > 0 { _ = ClippiFFI.cancelTask(id: taskId) }
                return
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
        taskGeneration += 1
        if currentTaskId > 0 { _ = ClippiFFI.cancelTask(id: currentTaskId) }
        currentTaskId = 0
        isProcessing = false
        progress = 0
        statusMessage = L10n.string("status.cancelled")
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
            "audio_codec": selectedOperation == .convert ? "aac" : "copy"
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
                completedOutputPath = outputPath
                statusMessage = L10n.string("status.completed")
                return
            case "failed", "cancelled":
                isProcessing = false
                currentTaskId = 0
                showError(
                    L10n.string(state == "cancelled" ? "status.cancelled" : "error.taskFailed"),
                    details: dict["message"] as? String ?? ""
                )
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
        let dir = defaultOutputDirectory.isEmpty ? url.deletingLastPathComponent() : URL(fileURLWithPath: defaultOutputDirectory, isDirectory: true)
        let ext = outputExtension(inputPath: input)
        let initial = dir.appendingPathComponent("\(name)_output.\(ext)").path
        return uniqueOutputPath(for: initial)
    }

    private func refreshOutputPath() {
        guard let path = fileInfo?.path else { return }
        if outputPath.isEmpty {
            outputPath = generateOutputPath(input: path)
        } else {
            let output = URL(fileURLWithPath: outputPath).deletingPathExtension()
                .appendingPathExtension(outputExtension(inputPath: path))
            outputPath = uniqueOutputPath(for: output.path)
        }
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
        guard let result, result["error"] == nil else {
            showError(L10n.string("error.probeFailed"), details: result?["error"] as? String ?? "")
            return
        }

        fileInfo = FileInfo(
            width: result["width"] as? Int ?? 0,
            height: result["height"] as? Int ?? 0,
            duration: result["duration_secs"] as? Double ?? 0,
            codec: result["codec"] as? String ?? "unknown",
            frameRate: result["frame_rate"] as? Double ?? 0,
            bitrate: result["bitrate"] as? Int ?? 0,
            hasAudio: result["has_audio"] as? Bool ?? false,
            pixelFormat: result["pixel_format"] as? String ?? "",
            colorTransfer: result["color_transfer"] as? String ?? "",
            isHDR: result["is_hdr"] as? Bool ?? false,
            rotationDegrees: result["rotation_degrees"] as? Int ?? 0,
            path: path
        )

        startTime = 0
        progress = 0
        statusMessage = ""
        completedOutputPath = nil
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
            guard startTime.isFinite, endTime.isFinite, startTime >= 0, endTime > startTime else {
                showError(L10n.string("error.trimEndAfterStart"))
                return false
            }

            if let duration = fileInfo?.duration, duration > 0, startTime >= duration {
                showError(L10n.string("error.trimStartBeforeDuration"))
                return false
            }

            if let duration = fileInfo?.duration, duration > 0, endTime > duration {
                endTime = duration
            }
        }

        if selectedOperation == .extractAudio, fileInfo?.hasAudio != true {
            showError(L10n.string("error.noAudioTrack"))
            return false
        }

        if (selectedOperation == .scale || selectedOperation == .removeAudio), fileInfo?.width == 0 {
            showError(L10n.string("error.noVideoTrack"))
            return false
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

    private func outputExtension(inputPath: String? = nil) -> String {
        switch selectedOperation {
        case .extractAudio:
            return audioFormat.rawValue.lowercased()
        case .convert:
            return outputFormat.rawValue.lowercased()
        case .trim, .scale, .removeAudio:
            if let inputPath {
                let inputExtension = URL(fileURLWithPath: inputPath).pathExtension.lowercased()
                if !inputExtension.isEmpty {
                    return inputExtension
                }
            }
            return "mp4"
        }
    }

    private static func isSupportedMedia(_ url: URL) -> Bool {
        let ext = url.pathExtension.lowercased()
        return ["mp4", "mkv", "mov", "webm", "avi", "m4v", "mp3", "wav", "aac", "m4a", "flac"].contains(ext)
    }

    private static func isSupportedVideo(_ url: URL) -> Bool {
        ["mp4", "mkv", "mov", "webm", "avi", "m4v", "mts", "m2ts", "ts", "mpg", "mpeg", "wmv", "flv", "3gp"]
            .contains(url.pathExtension.lowercased())
    }

    var selectedMediaItem: MediaItem? {
        guard let selectedMediaId else { return nil }
        return mediaItems.first { $0.id == selectedMediaId }
    }

    var checkedCount: Int { mediaItems.filter(\.isChecked).count }
    var pendingCorrectionCount: Int { mediaItems.filter { $0.isChecked && $0.isPending }.count }

    func importMedia(urls: [URL]) {
        guard !isImporting, !isProcessing else { return }
        let existing = Set(mediaItems.map { $0.info.path })
        let candidates = urls.filter { Self.isSupportedVideo($0) && !existing.contains($0.path) }
        guard !candidates.isEmpty else { return }
        isImporting = true

        Task {
            var failed: [String] = []
            for url in candidates {
                guard !mediaItems.contains(where: { $0.info.path == url.path }) else { continue }
                guard let result = await Self.loadProbeResult(path: url.path),
                      (result["width"] as? Int ?? 0) > 0 else {
                    failed.append(url.lastPathComponent)
                    continue
                }
                let info = Self.makeFileInfo(result: result, path: url.path)
                mediaItems.append(MediaItem(info: info))
                selectedMediaId = selectedMediaId ?? mediaItems.last?.id
            }
            isImporting = false
            if !failed.isEmpty {
                showError(L10n.format("correction.error.importFailed", failed.count), details: failed.joined(separator: "\n"))
            }
        }
    }

    func importFolder(_ folder: URL) {
        let keys: [URLResourceKey] = [.isRegularFileKey, .isHiddenKey]
        let urls = (try? FileManager.default.contentsOfDirectory(
            at: folder,
            includingPropertiesForKeys: keys,
            options: [.skipsHiddenFiles]
        )) ?? []
        importMedia(urls: urls.filter { url in
            let values = try? url.resourceValues(forKeys: Set(keys))
            return values?.isRegularFile == true && values?.isHidden != true
        }.sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending })
    }

    func importDropped(urls: [URL]) {
        var files: [URL] = []
        for url in urls {
            var isDirectory: ObjCBool = false
            if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory), isDirectory.boolValue {
                let children = (try? FileManager.default.contentsOfDirectory(
                    at: url,
                    includingPropertiesForKeys: [.isRegularFileKey, .isHiddenKey],
                    options: [.skipsHiddenFiles]
                )) ?? []
                files.append(contentsOf: children.filter { candidate in
                    let values = try? candidate.resourceValues(forKeys: [.isRegularFileKey, .isHiddenKey])
                    return values?.isRegularFile == true && values?.isHidden != true
                })
            } else {
                files.append(url)
            }
        }
        importMedia(urls: files)
    }

    func clearMedia() {
        guard !isProcessing, !isImporting else { return }
        mediaItems.removeAll()
        selectedMediaId = nil
        overallProgress = 0
    }

    func removeMedia(id: UUID) {
        guard !isProcessing else { return }
        mediaItems.removeAll { $0.id == id }
        if selectedMediaId == id { selectedMediaId = mediaItems.first?.id }
    }

    func showCorrectionError(id: UUID) {
        guard let item = mediaItems.first(where: { $0.id == id }),
              case let .failed(details) = item.status else { return }
        showError(L10n.string("correction.status.failed"), details: details)
    }

    func setAllChecked(_ checked: Bool) {
        guard !isProcessing else { return }
        for index in mediaItems.indices { mediaItems[index].isChecked = checked }
    }

    func toggleChecked(id: UUID) {
        guard !isProcessing else { return }
        guard let index = mediaItems.firstIndex(where: { $0.id == id }) else { return }
        mediaItems[index].isChecked.toggle()
    }

    func rotateCurrent(by degrees: Int) {
        updateCurrentCorrection { correction in
            correction.rotationDegrees = (correction.rotationDegrees + degrees).normalizedRotation
        }
    }

    func flipCurrent(horizontal: Bool) {
        updateCurrentCorrection { correction in
            if horizontal { correction.flipHorizontal.toggle() }
            else { correction.flipVertical.toggle() }
        }
    }

    func resetCurrentCorrection() {
        updateCurrentCorrection { $0 = Correction() }
    }

    private func updateCurrentCorrection(_ update: (inout Correction) -> Void) {
        guard !isProcessing,
              let id = selectedMediaId,
              let index = mediaItems.firstIndex(where: { $0.id == id }) else { return }
        update(&mediaItems[index].correction)
        mediaItems[index].status = .ready
    }

    func applyCurrentCorrection() {
        guard !isProcessing else { return }
        guard let current = selectedMediaItem else { return }
        let targetIds: Set<UUID>
        switch correctionScope {
        case .checked: targetIds = Set(mediaItems.filter(\.isChecked).map(\.id))
        case .all: targetIds = Set(mediaItems.map(\.id))
        }
        for index in mediaItems.indices where targetIds.contains(mediaItems[index].id) {
            mediaItems[index].correction = current.correction
            mediaItems[index].status = .ready
        }
    }

    func startCorrectionQueue() {
        guard !isProcessing, !isImporting else { return }
        let indexes = mediaItems.indices.filter { mediaItems[$0].isChecked && mediaItems[$0].isPending }
        guard !indexes.isEmpty else {
            showError(L10n.string("correction.error.nothingToProcess"))
            return
        }

        var configs: [[String: Any]] = []
        var configuredIndexes: [Int] = []
        var reservedOutputs: Set<String> = []
        for index in indexes {
            let item = mediaItems[index]
            let output = correctionOutputPath(for: item)
            do {
                try FileManager.default.createDirectory(
                    at: output.deletingLastPathComponent(),
                    withIntermediateDirectories: true
                )
            } catch {
                mediaItems[index].status = .failed(error.localizedDescription)
                continue
            }
            let outputPath = uniqueBatchOutputPath(for: output.path, reserved: &reservedOutputs)
            configs.append([
                "input_path": item.info.path,
                "output_path": outputPath,
                "operation": ["Transform": [
                    "rotation_degrees": item.correction.rotationDegrees,
                    "flip_horizontal": item.correction.flipHorizontal,
                    "flip_vertical": item.correction.flipVertical
                ]],
                "video_codec": correctionVideoCodec(for: item),
                "audio_codec": "aac"
            ])
            configuredIndexes.append(index)
        }
        guard !configs.isEmpty else { return }

        isProcessing = true
        correctionQueueGeneration += 1
        let generation = correctionQueueGeneration
        overallProgress = 0
        pendingCorrectionProgress.removeAll()
        for index in mediaItems.indices { mediaItems[index].taskId = nil }
        for index in configuredIndexes { mediaItems[index].status = .queued; mediaItems[index].progress = 0 }

        Task {
            let ids = await Task.detached {
                ClippiFFI.queueTasks(configs: configs) { [weak self] json in
                    DispatchQueue.main.async {
                        guard let self, self.correctionQueueGeneration == generation else { return }
                        self.updateCorrectionProgress(json)
                    }
                }
            }.value
            guard generation == correctionQueueGeneration, isProcessing else {
                for id in ids { _ = ClippiFFI.cancelTask(id: id) }
                pendingCorrectionProgress.removeAll()
                return
            }
            guard ids.count == configuredIndexes.count else {
                correctionQueueGeneration += 1
                for id in ids { _ = ClippiFFI.cancelTask(id: id) }
                pendingCorrectionProgress.removeAll()
                for index in configuredIndexes {
                    mediaItems[index].status = .failed(L10n.string("error.startTaskFailed"))
                }
                isProcessing = false
                showError(L10n.string("error.startTaskFailed"))
                return
            }
            correctionTaskIds = ids
            for (offset, id) in ids.enumerated() {
                mediaItems[configuredIndexes[offset]].taskId = id
            }
            // Register every task before replaying early completion callbacks.
            for id in ids {
                if let pending = pendingCorrectionProgress.removeValue(forKey: id) {
                    updateCorrectionProgress(pending)
                }
            }
        }
    }

    func cancelCorrectionQueue() {
        correctionQueueGeneration += 1
        for id in correctionTaskIds { _ = ClippiFFI.cancelTask(id: id) }
        correctionTaskIds.removeAll()
        pendingCorrectionProgress.removeAll()
        for index in mediaItems.indices where mediaItems[index].status == .queued || mediaItems[index].status == .processing {
            mediaItems[index].status = .cancelled
        }
        isProcessing = false
    }

    private func updateCorrectionProgress(_ json: String) {
        guard let data = json.data(using: .utf8),
              let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let taskId = (dict["task_id"] as? NSNumber)?.uint64Value else { return }
        guard let index = mediaItems.firstIndex(where: { $0.taskId == taskId }) else {
            pendingCorrectionProgress[taskId] = json
            return
        }
        mediaItems[index].progress = dict["percent"] as? Double ?? mediaItems[index].progress
        switch dict["state"] as? String {
        case "running": mediaItems[index].status = .processing
        case "completed": mediaItems[index].status = .completed
        case "cancelled": mediaItems[index].status = .cancelled
        case "failed": mediaItems[index].status = .failed(dict["message"] as? String ?? "")
        default: break
        }
        let active = mediaItems.filter { $0.taskId != nil }
        overallProgress = active.isEmpty ? 0 : active.map(\.progress).reduce(0, +) / Double(active.count)
        if active.allSatisfy({ status in
            switch status.status {
            case .completed, .failed, .cancelled: return true
            default: return false
            }
        }) {
            isProcessing = false
            correctionTaskIds.removeAll()
            pendingCorrectionProgress.removeAll()
        }
    }

    private func correctionOutputPath(for item: MediaItem) -> URL {
        let source = URL(fileURLWithPath: item.info.path)
        let directory = correctionOutputDirectory ?? (defaultOutputDirectory.isEmpty ? source.deletingLastPathComponent().appendingPathComponent("Clippi-output", isDirectory: true) : URL(fileURLWithPath: defaultOutputDirectory, isDirectory: true))
        return directory
            .appendingPathComponent(source.deletingPathExtension().lastPathComponent)
            .appendingPathExtension("mp4")
    }

    private func correctionVideoCodec(for item: MediaItem) -> String {
        if item.info.isHDR {
            return gpuInfo?.encoder == "hevc_videotoolbox" ? "hevc_videotoolbox" : "libx265"
        }
        return gpuInfo?.encoder == nil ? "libx264" : "h264_videotoolbox"
    }

    private func uniqueBatchOutputPath(for path: String, reserved: inout Set<String>) -> String {
        let url = URL(fileURLWithPath: path)
        let directory = url.deletingLastPathComponent()
        let name = url.deletingPathExtension().lastPathComponent
        let ext = url.pathExtension
        var index = 1
        var candidate = path
        while FileManager.default.fileExists(atPath: candidate) || reserved.contains(candidate.lowercased()) {
            index += 1
            candidate = directory.appendingPathComponent("\(name)_\(index).\(ext)").path
        }
        reserved.insert(candidate.lowercased())
        return candidate
    }

    private static func makeFileInfo(result: [String: Any], path: String) -> FileInfo {
        FileInfo(
            width: result["width"] as? Int ?? 0,
            height: result["height"] as? Int ?? 0,
            duration: result["duration_secs"] as? Double ?? 0,
            codec: result["codec"] as? String ?? "unknown",
            frameRate: result["frame_rate"] as? Double ?? 0,
            bitrate: result["bitrate"] as? Int ?? 0,
            hasAudio: result["has_audio"] as? Bool ?? false,
            pixelFormat: result["pixel_format"] as? String ?? "",
            colorTransfer: result["color_transfer"] as? String ?? "",
            isHDR: result["is_hdr"] as? Bool ?? false,
            rotationDegrees: result["rotation_degrees"] as? Int ?? 0,
            path: path
        )
    }

    private func showError(_ message: String, details: String = "") {
        errorMessage = message
        errorDetails = details
        showError = true
    }

    func copyErrorDetailsToPasteboard() {
        guard !errorDetails.isEmpty else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(errorDetails, forType: .string)
    }
}

private extension Int {
    var normalizedRotation: Int { ((self % 360) + 360) % 360 }
}
