import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = AppViewModel()

    var body: some View {
        VStack(spacing: 20) {
            // Header
            Text("Clippi")
                .font(.largeTitle)
                .fontWeight(.bold)

            // File drop area
            DropAreaView(viewModel: viewModel)

            // File info
            if let fileInfo = viewModel.fileInfo {
                FileInfoView(fileInfo: fileInfo)
            }

            // Controls
            if viewModel.fileInfo != nil {
                OperationControlsView(viewModel: viewModel)
            }

            // Progress
            if viewModel.isProcessing {
                ProgressView(value: Double(viewModel.progress))
                    .progressViewStyle(.linear)
            }
        }
        .padding()
        .frame(minWidth: 600, minHeight: 400)
    }
}

struct DropAreaView: View {
    @ObservedObject var viewModel: AppViewModel

    var body: some View {
        RoundedRectangle(cornerRadius: 12)
            .strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [8]))
            .foregroundColor(.secondary)
            .overlay(
                VStack {
                    Image(systemName: "video.badge.plus")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    Text("拖拽视频文件到这里")
                        .font(.title3)
                        .foregroundColor(.secondary)
                }
            )
            .frame(height: 200)
            .onDrop(of: [.fileURL], isTargeted: nil) { providers in
                viewModel.handleDrop(providers: providers)
                return true
            }
    }
}

struct FileInfoView: View {
    let fileInfo: FileInfo

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("文件信息")
                .font(.headline)
            Text("分辨率: \(fileInfo.width) x \(fileInfo.height)")
            Text("时长: \(formatDuration(fileInfo.duration))")
            Text("编码: \(fileInfo.codec)")
            Text("帧率: \(String(format: "%.2f", fileInfo.frameRate)) fps")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.controlBackgroundColor))
        .cornerRadius(8)
    }

    private func formatDuration(_ seconds: Double) -> String {
        let hours = Int(seconds) / 3600
        let minutes = (Int(seconds) % 3600) / 60
        let secs = Int(seconds) % 60
        return String(format: "%02d:%02d:%02d", hours, minutes, secs)
    }
}

struct OperationControlsView: View {
    @ObservedObject var viewModel: AppViewModel

    var body: some View {
        VStack(spacing: 12) {
            Picker("操作", selection: $viewModel.selectedOperation) {
                Text("裁剪").tag("trim")
                Text("转换格式").tag("convert")
                Text("缩放").tag("scale")
                Text("提取音频").tag("extractAudio")
            }
            .pickerStyle(.segmented)

            Button("开始处理") {
                viewModel.startProcessing()
            }
            .buttonStyle(.borderedProminent)
            .disabled(viewModel.isProcessing)
        }
    }
}

class AppViewModel: ObservableObject {
    @Published var fileInfo: FileInfo?
    @Published var selectedOperation = "trim"
    @Published var isProcessing = false
    @Published var progress: Float = 0

    func handleDrop(providers: [NSItemProvider]) {
        // Handle file drop
    }

    func startProcessing() {
        // Start processing
    }
}

struct FileInfo {
    let width: Int
    let height: Int
    let duration: Double
    let codec: String
    let frameRate: Double
}
