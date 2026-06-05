import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct MainView: View {
    @StateObject private var viewModel = MainViewModel()

    var body: some View {
        VStack(spacing: 16) {
            // Header with GPU status
            HStack {
                Text(L10n.string("app.name"))
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Spacer()

                if let gpu = viewModel.gpuInfo {
                    Label(gpu.encoder ?? L10n.string("encoder.software"), systemImage: "gpu")
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
            Picker(L10n.string("operation.label"), selection: $viewModel.selectedOperation) {
                ForEach(MainViewModel.OperationType.allCases, id: \.self) { type in
                    Text(type.title).tag(type)
                }
            }
            .pickerStyle(.segmented)
            .disabled(viewModel.isProcessing)

            // Operation-specific controls
            operationControls
                .disabled(viewModel.isProcessing)

            // Output path
            HStack {
                TextField(L10n.string("output.path"), text: $viewModel.outputPath)
                    .textFieldStyle(.roundedBorder)
                    .disabled(viewModel.isProcessing)

                Button(L10n.string("choose.ellipsis")) {
                    selectOutputPath()
                }
                .disabled(viewModel.isProcessing)
            }

            // Progress and actions
            if viewModel.isProcessing {
                VStack {
                    ProgressView(value: viewModel.progress / 100) {
                        Text(viewModel.statusMessage)
                    }
                    .progressViewStyle(.linear)

                    Button(L10n.string("cancel")) {
                        viewModel.cancelProcessing()
                    }
                    .foregroundColor(.red)
                }
            } else {
                Button(L10n.string("start.processing")) {
                    viewModel.startProcessing()
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.fileInfo == nil)
            }
        }
        .padding()
        .frame(minWidth: 600, minHeight: 500)
        .alert(L10n.string("error.title"), isPresented: $viewModel.showError) {
            if !viewModel.errorDetails.isEmpty {
                Button(L10n.string("error.copyDetails")) {
                    viewModel.copyErrorDetailsToPasteboard()
                }
            }
            Button(L10n.string("ok")) {}
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
            Text(L10n.string("removeAudio.description"))
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    private func selectOutputPath() {
        let panel = NSSavePanel()
        panel.canCreateDirectories = true
        panel.nameFieldStringValue = URL(fileURLWithPath: viewModel.outputPath).lastPathComponent
        let ext = URL(fileURLWithPath: viewModel.outputPath).pathExtension
        if let contentType = UTType(filenameExtension: ext) {
            panel.allowedContentTypes = [contentType]
        }

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

                    Text(L10n.string("drop.primary"))
                        .font(.title3)
                        .foregroundColor(.secondary)

                    Text(L10n.string("drop.secondary"))
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
                    Label(L10n.string("file.resolution"), systemImage: "aspectratio")
                    Text("\(fileInfo.width) x \(fileInfo.height)")
                }
                GridRow {
                    Label(L10n.string("file.duration"), systemImage: "clock")
                    Text(formatDuration(fileInfo.duration))
                }
                GridRow {
                    Label(L10n.string("file.codec"), systemImage: "film")
                    Text(fileInfo.codec)
                }
                GridRow {
                    Label(L10n.string("file.frameRate"), systemImage: "speedometer")
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
                Text(L10n.string("trim.startTime"))
                TextField(L10n.string("trim.seconds.placeholder"), value: $startTime, format: .number)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 80)
                Text(L10n.string("trim.seconds.unit"))

                Spacer()

                Text(L10n.string("trim.endTime"))
                TextField(L10n.string("trim.seconds.placeholder"), value: $endTime, format: .number)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 80)
                Text(L10n.string("trim.seconds.unit"))
            }

            Toggle(L10n.string("trim.fastMode"), isOn: $fastMode)
        }
    }
}

struct FormatControlsView: View {
    @Binding var outputFormat: MainViewModel.OutputFormat

    var body: some View {
        Picker(L10n.string("format.output"), selection: $outputFormat) {
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
        Picker(L10n.string("scale.resolution"), selection: $resolution) {
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
        Picker(L10n.string("audio.format"), selection: $audioFormat) {
            ForEach(MainViewModel.AudioFormat.allCases, id: \.self) { format in
                Text(format.rawValue).tag(format)
            }
        }
        .pickerStyle(.segmented)
    }
}
