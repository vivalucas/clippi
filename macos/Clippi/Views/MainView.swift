import SwiftUI
import AppKit

struct MainView: View {
    @StateObject private var viewModel = MainViewModel()

    var body: some View {
        VStack(spacing: 16) {
            // Header with GPU status
            HStack {
                Text("Clippi")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Spacer()

                if let gpu = viewModel.gpuInfo {
                    Label(gpu.encoder ?? "软件编码", systemImage: "gpu")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            // Drop area or file info
            if let fileInfo = viewModel.fileInfo {
                FileInfoCard(fileInfo: fileInfo)
            } else {
                DropAreaView(onDrop: { url in
                    viewModel.probeFile(at: url)
                })
            }

            // Operation selector
            Picker("操作", selection: $viewModel.selectedOperation) {
                ForEach(MainViewModel.OperationType.allCases, id: \.self) { type in
                    Text(type.rawValue).tag(type)
                }
            }
            .pickerStyle(.segmented)

            // Operation-specific controls
            operationControls

            // Output path
            HStack {
                TextField("输出路径", text: $viewModel.outputPath)
                    .textFieldStyle(.roundedBorder)

                Button("选择...") {
                    selectOutputPath()
                }
            }

            // Progress and actions
            if viewModel.isProcessing {
                VStack {
                    ProgressView(value: viewModel.progress / 100) {
                        Text(viewModel.statusMessage)
                    }
                    .progressViewStyle(.linear)

                    Button("取消") {
                        viewModel.cancelProcessing()
                    }
                    .foregroundColor(.red)
                }
            } else {
                Button("开始处理") {
                    viewModel.startProcessing()
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.fileInfo == nil)
            }
        }
        .padding()
        .frame(minWidth: 600, minHeight: 500)
        .alert("错误", isPresented: $viewModel.showError) {
            Button("确定") {}
        } message: {
            Text(viewModel.errorMessage)
        }
    }

    @ViewBuilder
    private var operationControls: some View {
        switch viewModel.selectedOperation {
        case .trim:
            TrimControlsView(
                startTime: $viewModel.startTime,
                endTime: $viewModel.endTime,
                fastMode: $viewModel.fastMode,
                duration: viewModel.fileInfo?.duration ?? 0
            )
        case .convert:
            FormatControlsView(outputFormat: $viewModel.outputFormat)
        case .scale:
            ScaleControlsView(resolution: $viewModel.targetResolution)
        case .extractAudio:
            AudioFormatControlsView(audioFormat: $viewModel.audioFormat)
        case .removeAudio:
            Text("将移除视频中的所有音频轨道")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    private func selectOutputPath() {
        let panel = NSSavePanel()
        panel.canCreateDirectories = true
        panel.nameFieldStringValue = URL(fileURLWithPath: viewModel.outputPath).lastPathComponent

        if panel.runModal() == .OK, let url = panel.url {
            viewModel.outputPath = url.path
        }
    }
}

struct DropAreaView: View {
    let onDrop: (URL) -> Void
    @State private var isDragOver = false

    var body: some View {
        RoundedRectangle(cornerRadius: 12)
            .strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [8]))
            .foregroundColor(isDragOver ? .accentColor : .secondary)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isDragOver ? Color.accentColor.opacity(0.1) : Color.clear)
            )
            .overlay(
                VStack(spacing: 12) {
                    Image(systemName: "video.badge.plus")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)

                    Text("拖拽视频文件到这里")
                        .font(.title3)
                        .foregroundColor(.secondary)

                    Text("或点击选择文件")
                        .font(.caption)
                        .foregroundColor(.accentColor)
                }
            )
            .frame(height: 200)
            .onDrop(of: [.fileURL], isTargeted: $isDragOver) { providers in
                handleDrop(providers: providers)
                return true
            }
            .onTapGesture {
                selectFile()
            }
    }

    private func handleDrop(providers: [NSItemProvider]) {
        guard let provider = providers.first else { return }
        provider.loadItem(forTypeIdentifier: "public.file-url") { item, error in
            guard let data = item as? Data,
                  let url = URL(dataRepresentation: data, relativeTo: nil) else { return }
            DispatchQueue.main.async {
                onDrop(url)
            }
        }
    }

    private func selectFile() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.movie, .video]
        panel.allowsMultipleSelection = false

        if panel.runModal() == .OK, let url = panel.url {
            onDrop(url)
        }
    }
}

struct FileInfoCard: View {
    let fileInfo: MainViewModel.FileInfo

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "video")
                    .font(.title2)
                Text(URL(fileURLWithPath: fileInfo.path).lastPathComponent)
                    .font(.headline)
            }

            Divider()

            Grid(alignment: .leading, horizontalSpacing: 20, verticalSpacing: 4) {
                GridRow {
                    Label("分辨率", systemImage: "aspectratio")
                    Text("\(fileInfo.width) x \(fileInfo.height)")
                }
                GridRow {
                    Label("时长", systemImage: "clock")
                    Text(formatDuration(fileInfo.duration))
                }
                GridRow {
                    Label("编码", systemImage: "film")
                    Text(fileInfo.codec)
                }
                GridRow {
                    Label("帧率", systemImage: "speedometer")
                    Text(String(format: "%.2f fps", fileInfo.frameRate))
                }
            }
            .font(.system(.body, design: .monospaced))
        }
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

struct TrimControlsView: View {
    @Binding var startTime: Double
    @Binding var endTime: Double
    @Binding var fastMode: Bool
    let duration: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("开始时间:")
                TextField("秒", value: $startTime, format: .number)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 80)
                Text("秒")

                Spacer()

                Text("结束时间:")
                TextField("秒", value: $endTime, format: .number)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 80)
                Text("秒")
            }

            Toggle("快速模式（不重编码，可能不精确）", isOn: $fastMode)
        }
    }
}

struct FormatControlsView: View {
    @Binding var outputFormat: MainViewModel.OutputFormat

    var body: some View {
        Picker("输出格式", selection: $outputFormat) {
            ForEach(MainViewModel.OutputFormat.allCases, id: \.self) { format in
                Text(format.rawValue).tag(format)
            }
        }
        .pickerStyle(.segmented)
    }
}

struct ScaleControlsView: View {
    @Binding var resolution: MainViewModel.Resolution

    var body: some View {
        Picker("目标分辨率", selection: $resolution) {
            ForEach(MainViewModel.Resolution.allCases, id: \.self) { res in
                Text(res.rawValue).tag(res)
            }
        }
        .pickerStyle(.segmented)
    }
}

struct AudioFormatControlsView: View {
    @Binding var audioFormat: MainViewModel.AudioFormat

    var body: some View {
        Picker("音频格式", selection: $audioFormat) {
            ForEach(MainViewModel.AudioFormat.allCases, id: \.self) { format in
                Text(format.rawValue).tag(format)
            }
        }
        .pickerStyle(.segmented)
    }
}
