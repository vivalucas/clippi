import Foundation

/// Swift wrapper for Rust FFI functions
enum ClippiFFI {
    private static var callbacks: [UInt64: (String) -> Void] = [:]
    private static var pendingQueueCallback: ((String) -> Void)?
    private static let callbackLock = NSLock()
    private static let progressThunk: @convention(c) (UnsafePointer<CChar>?) -> Void = { cString in
        guard let cString = cString else { return }
        let jsonString = String(cString: cString)
        
        guard let dict = parseJson(jsonString),
              let taskId = (dict["task_id"] as? NSNumber)?.uint64Value else { return }
        
        callbackLock.lock()
        let cb = callbacks[taskId] ?? pendingQueueCallback
        if let state = dict["state"] as? String, ["completed", "failed", "cancelled"].contains(state) {
            callbacks.removeValue(forKey: taskId)
        }
        callbackLock.unlock()
        
        cb?(jsonString)
    }

    /// Probe file metadata
    static func probeFile(path: String) -> [String: Any]? {
        guard let cPath = path.cString(using: .utf8) else { return nil }

        let resultPtr = clippi_probe_file(cPath)
        guard let resultPtr = resultPtr else { return nil }

        defer { clippi_free_string(resultPtr) }

        let jsonString = String(cString: resultPtr)
        return parseJson(jsonString)
    }

    /// Detect GPU capability
    static func detectGpu() -> [String: Any]? {
        let resultPtr = clippi_detect_gpu()
        guard let resultPtr = resultPtr else { return nil }

        defer { clippi_free_string(resultPtr) }

        let jsonString = String(cString: resultPtr)
        return parseJson(jsonString)
    }

    /// Run a task
    static func runTask(config: [String: Any], callback: @escaping (String) -> Void) -> UInt64 {
        guard let configJson = toJson(config) else { return 0 }

        callbackLock.lock()
        let taskId = clippi_run_task(configJson, progressThunk)
        if taskId > 0 {
            callbacks[taskId] = callback
        }
        callbackLock.unlock()
        return taskId
    }

    /// Cancel a task
    static func cancelTask(id: UInt64) -> Bool {
        let cancelled = clippi_cancel_task(id) == 1
        if cancelled {
            callbackLock.lock()
            callbacks.removeValue(forKey: id)
            callbackLock.unlock()
        }
        return cancelled
    }

    /// Generate a JPEG fallback for containers AVKit cannot play directly.
    static func generatePreviewImage(inputPath: String, outputPath: String) -> Bool {
        guard let input = inputPath.cString(using: .utf8),
              let output = outputPath.cString(using: .utf8),
              let resultPtr = clippi_generate_preview_image(input, output) else { return false }
        defer { clippi_free_string(resultPtr) }
        let result = String(cString: resultPtr)
        return parseJson(result)?["ok"] as? Bool == true
    }

    /// Run multiple tasks serially in the shared Rust queue.
    static func queueTasks(configs: [[String: Any]], callback: @escaping (String) -> Void) -> [UInt64] {
        guard JSONSerialization.isValidJSONObject(configs),
              let data = try? JSONSerialization.data(withJSONObject: configs),
              let json = String(data: data, encoding: .utf8) else { return [] }

        callbackLock.lock()
        pendingQueueCallback = callback
        guard let resultPtr = clippi_queue_tasks(json, progressThunk) else {
            pendingQueueCallback = nil
            callbackLock.unlock()
            return []
        }
        defer { clippi_free_string(resultPtr) }

        let result = String(cString: resultPtr)
        let ids = (try? JSONSerialization.jsonObject(with: Data(result.utf8)) as? [NSNumber])?
            .map { $0.uint64Value } ?? []
        for id in ids { callbacks[id] = callback }
        pendingQueueCallback = nil
        callbackLock.unlock()
        return ids
    }

    // MARK: - Helpers

    private static func parseJson(_ jsonString: String) -> [String: Any]? {
        guard let data = jsonString.data(using: .utf8) else { return nil }
        return try? JSONSerialization.jsonObject(with: data) as? [String: Any]
    }

    private static func toJson(_ dict: [String: Any]) -> String? {
        guard let data = try? JSONSerialization.data(withJSONObject: dict) else { return nil }
        return String(data: data, encoding: .utf8)
    }
}
