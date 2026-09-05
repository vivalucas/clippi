import SwiftUI
import AppKit
import UniformTypeIdentifiers
import AVKit

struct MainView: View {
    @StateObject private var viewModel = MainViewModel()
    @State private var workspace: Workspace = .correction

    private enum Workspace: String, CaseIterable {
        case correction
        case otherTools

        var title: String {
            switch self {
            case .correction: return L10n.string("workspace.correction")
            case .otherTools: return L10n.string("workspace.otherTools")
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(L10n.string("app.name"))
                    .font(.title2)
                    .fontWeight(.semibold)

                Picker("", selection: $workspace) {
                    ForEach(Workspace.allCases, id: \.self) { item in
                        Text(item.title).tag(item)
                    }
                }
                .labelsHidden()
                .frame(width: 150)
                .disabled(viewModel.isProcessing)

                Spacer()

                if workspace == .correction {
                    Button(L10n.string("correction.addFiles"), systemImage: "doc.badge.plus") { selectMediaFiles() }
                        .disabled(viewModel.isProcessing || viewModel.isImporting)
                    Button(L10n.string("correction.addFolder"), systemImage: "folder.badge.plus") { selectMediaFolder() }
                        .disabled(viewModel.isProcessing || viewModel.isImporting)
                    Button(L10n.string("correction.clear")) { viewModel.clearMedia() }
                        .disabled(viewModel.mediaItems.isEmpty || viewModel.isProcessing)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)

            Divider()

            if workspace == .correction {
                correctionWorkspace
            } else {
                legacyWorkspace
            }
        }
        .frame(minWidth: 820, minHeight: 620)
        .alert(L10n.string("error.title"), isPresented: $viewModel.showError) {
            if !viewModel.errorDetails.isEmpty {
                Button(L10n.string("error.copyDetails")) { viewModel.copyErrorDetailsToPasteboard() }
            }
            Button(L10n.string("ok")) {}
        } message: {
            Text(viewModel.errorMessage)
        }
    }

    private var legacyWorkspace: some View {
        VStack(spacing: 16) {
            if let gpu = viewModel.gpuInfo {
                HStack {
                    Spacer()
                    Label(gpu.encoder ?? L10n.string("encoder.software"), systemImage: "gpu")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            if let fileInfo = viewModel.fileInfo {
                FileInfoCard(fileInfo: fileInfo)
            } else {
                DropAreaView(onDrop: { url in
                    viewModel.probeFile(at: url)
                })
            }

            Picker(L10n.string("operation.label"), selection: $viewModel.selectedOperation) {
                ForEach(MainViewModel.OperationType.allCases, id: \.self) { type in
                    Text(type.title).tag(type)
                }
            }
            .pickerStyle(.segmented)
            .disabled(viewModel.isProcessing)

            operationControls
                .disabled(viewModel.isProcessing)

            HStack {
                TextField(L10n.string("output.path"), text: $viewModel.outputPath)
                    .textFieldStyle(.roundedBorder)
                    .disabled(viewModel.isProcessing)

                Button(L10n.string("choose.ellipsis")) {
                    selectOutputPath()
                }
                .disabled(viewModel.isProcessing)
            }

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
    }

    @ViewBuilder
    private var correctionWorkspace: some View {
        if viewModel.mediaItems.isEmpty {
            CorrectionDropArea(
                isImporting: viewModel.isImporting,
                onFiles: viewModel.importDropped,
                onChooseFiles: selectMediaFiles,
                onChooseFolder: selectMediaFolder
            )
            .padding(20)
        } else {
            VStack(spacing: 0) {
                HSplitView {
                    correctionList
                        .frame(minWidth: 300, idealWidth: 350, maxWidth: 430)

                    correctionEditor
                        .frame(minWidth: 460)
                }

                Divider()
                correctionFooter
            }
            .onDrop(of: [.fileURL], isTargeted: nil) { providers in
                handleCorrectionDrop(providers)
            }
        }
    }

    private var correctionList: some View {
        VStack(spacing: 0) {
            HStack {
                Button {
                    viewModel.setAllChecked(viewModel.checkedCount != viewModel.mediaItems.count)
                } label: {
                    Image(systemName: selectAllSymbol)
                }
                .buttonStyle(.plain)
                .disabled(viewModel.isProcessing)
                Text(L10n.string("correction.materials")).fontWeight(.semibold)
                Spacer()
                Text(L10n.format("correction.count", viewModel.mediaItems.count, viewModel.checkedCount))
                    .font(.caption).foregroundColor(.secondary)
            }
            .padding(12)

            Divider()

            List(selection: $viewModel.selectedMediaId) {
                ForEach(viewModel.mediaItems) { item in
                    HStack(spacing: 10) {
                        Button { viewModel.toggleChecked(id: item.id) } label: {
                            Image(systemName: item.isChecked ? "checkmark.square.fill" : "square")
                        }
                        .buttonStyle(.plain)
                        .disabled(viewModel.isProcessing)

                        Image(systemName: "film")
                            .frame(width: 46, height: 34)
                            .background(Color.secondary.opacity(0.12))
                            .cornerRadius(5)

                        VStack(alignment: .leading, spacing: 3) {
                            Text(URL(fileURLWithPath: item.info.path).lastPathComponent)
                                .lineLimit(1)
                            Text("\(item.info.width)×\(item.info.height) · \(formatDuration(item.info.duration))\(item.info.isHDR ? " · HDR" : "")")
                                .font(.caption).foregroundColor(.secondary)
                        }
                        Spacer(minLength: 4)
                        Text(correctionStatus(item))
                            .font(.caption)
                            .foregroundColor(item.needsProcessing ? .accentColor : .secondary)
                            .lineLimit(2)
                    }
                    .tag(item.id)
                    .contextMenu {
                        Button(L10n.string("correction.remove"), role: .destructive) { viewModel.removeMedia(id: item.id) }
                        if case let .failed(details) = item.status, !details.isEmpty {
                            Button(L10n.string("correction.error.details")) { viewModel.showCorrectionError(id: item.id) }
                        }
                    }
                }
            }
            .listStyle(.sidebar)
        }
    }

    @ViewBuilder
    private var correctionEditor: some View {
        if let item = viewModel.selectedMediaItem {
            VStack(spacing: 0) {
                VideoCorrectionPreview(item: item)
                    .padding(20)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                Divider()

                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text(URL(fileURLWithPath: item.info.path).lastPathComponent).fontWeight(.semibold)
                        Text(item.correction.summary).font(.caption).foregroundColor(.accentColor)
                        Spacer()
                    }

                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 118), spacing: 8)], alignment: .leading, spacing: 8) {
                        Button(L10n.string("correction.rotate.left"), systemImage: "rotate.left") { viewModel.rotateCurrent(by: -90) }
                        Button(L10n.string("correction.rotate.right"), systemImage: "rotate.right") { viewModel.rotateCurrent(by: 90) }
                        Button(L10n.string("correction.rotate.180")) { viewModel.rotateCurrent(by: 180) }
                        Button(L10n.string("correction.flip.horizontal"), systemImage: "arrow.left.and.right.righttriangle.left.righttriangle.right") { viewModel.flipCurrent(horizontal: true) }
                        Button(L10n.string("correction.flip.vertical"), systemImage: "arrow.up.and.down.righttriangle.up.righttriangle.down") { viewModel.flipCurrent(horizontal: false) }
                        Button(L10n.string("correction.reset")) { viewModel.resetCurrentCorrection() }
                            .buttonStyle(.plain)
                    }
                    .disabled(viewModel.isProcessing)

                    HStack {
                        Picker(L10n.string("correction.applyTo"), selection: $viewModel.correctionScope) {
                            ForEach(MainViewModel.CorrectionScope.allCases, id: \.self) { scope in
                                Text(scope.title).tag(scope)
                            }
                        }
                        .frame(width: 230)
                        Button(L10n.string("correction.apply")) { viewModel.applyCurrentCorrection() }
                            .disabled(viewModel.isProcessing)
                        Spacer()
                    }
                }
                .padding(14)
            }
        } else {
            Text(L10n.string("correction.selectMaterial")).foregroundColor(.secondary)
        }
    }

    private var correctionFooter: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(L10n.string("correction.outputTo")).fontWeight(.semibold)
                Text(viewModel.correctionOutputDirectory?.path ?? L10n.string("correction.outputDefault"))
                    .font(.caption).foregroundColor(.secondary).lineLimit(1)
            }
            Button(L10n.string("correction.change")) { selectCorrectionOutputFolder() }
                .disabled(viewModel.isProcessing)
            Spacer()
            if viewModel.isProcessing {
                ProgressView(value: viewModel.overallProgress, total: 100).frame(width: 180)
                Button(L10n.string("correction.stopAll"), role: .destructive) { viewModel.cancelCorrectionQueue() }
            } else {
                Text(L10n.format("correction.pending", viewModel.pendingCorrectionCount))
                    .font(.caption).foregroundColor(.secondary)
                Button(L10n.string("correction.start"), systemImage: "play.fill") { viewModel.startCorrectionQueue() }
                    .buttonStyle(.borderedProminent)
                    .disabled(viewModel.pendingCorrectionCount == 0)
            }
        }
        .padding(14)
    }

    private func correctionStatus(_ item: MainViewModel.MediaItem) -> String {
        switch item.status {
        case .ready:
            if item.correction.isIdentity, item.info.rotationDegrees != 0 {
                return L10n.format("correction.metadata", item.info.rotationDegrees)
            }
            return item.correction.summary
        case .queued: return L10n.string("correction.status.queued")
        case .processing: return "\(Int(item.progress))%"
        case .completed: return L10n.string("correction.status.completed")
        case .failed: return L10n.string("correction.status.failed")
        case .cancelled: return L10n.string("correction.status.cancelled")
        }
    }

    private var selectAllSymbol: String {
        if viewModel.checkedCount == viewModel.mediaItems.count { return "checkmark.square.fill" }
        if viewModel.checkedCount > 0 { return "minus.square.fill" }
        return "square"
    }

    private func selectMediaFiles() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.movie, .video]
        panel.allowsMultipleSelection = true
        if panel.runModal() == .OK { viewModel.importMedia(urls: panel.urls) }
    }

    private func handleCorrectionDrop(_ providers: [NSItemProvider]) -> Bool {
        let group = DispatchGroup()
        let lock = NSLock()
        var urls: [URL] = []
        for provider in providers {
            group.enter()
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier) { item, _ in
                defer { group.leave() }
                guard let data = item as? Data,
                      let url = URL(dataRepresentation: data, relativeTo: nil) else { return }
                lock.lock(); urls.append(url); lock.unlock()
            }
        }
        group.notify(queue: .main) { viewModel.importDropped(urls: urls) }
        return true
    }

    private func selectMediaFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        if panel.runModal() == .OK, let url = panel.url { viewModel.importFolder(url) }
    }

    private func selectCorrectionOutputFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        if panel.runModal() == .OK { viewModel.correctionOutputDirectory = panel.url }
    }

    private func formatDuration(_ seconds: Double) -> String {
        String(format: "%02d:%02d", Int(seconds) / 60, Int(seconds) % 60)
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

struct CorrectionDropArea: View {
    let isImporting: Bool
    let onFiles: ([URL]) -> Void
    let onChooseFiles: () -> Void
    let onChooseFolder: () -> Void
    @State private var isTargeted = false

    var body: some View {
        RoundedRectangle(cornerRadius: 12)
            .strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [8]))
            .foregroundColor(isTargeted ? .accentColor : .secondary)
            .background(RoundedRectangle(cornerRadius: 12).fill(Color.secondary.opacity(0.04)))
            .overlay {
                VStack(spacing: 14) {
                    Image(systemName: "film.stack").font(.system(size: 46)).foregroundColor(.secondary)
                    Text(L10n.string("correction.empty.title")).font(.title3)
                    Text(L10n.string("correction.empty.subtitle")).foregroundColor(.secondary)
                    HStack {
                        Button(L10n.string("correction.addFiles"), action: onChooseFiles)
                            .buttonStyle(.borderedProminent)
                        Button(L10n.string("correction.addFolder"), action: onChooseFolder)
                    }
                    if isImporting { ProgressView() }
                }
            }
            .onDrop(of: [.fileURL], isTargeted: $isTargeted) { providers in
                let group = DispatchGroup()
                let lock = NSLock()
                var urls: [URL] = []
                for provider in providers {
                    group.enter()
                    provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier) { item, _ in
                        defer { group.leave() }
                        guard let data = item as? Data,
                              let url = URL(dataRepresentation: data, relativeTo: nil) else { return }
                        lock.lock(); urls.append(url); lock.unlock()
                    }
                }
                group.notify(queue: .main) { onFiles(urls) }
                return true
            }
    }
}

struct VideoCorrectionPreview: View {
    let item: MainViewModel.MediaItem
    @State private var player = AVPlayer()
    @State private var previewUnavailable = false
    @State private var fallbackImage: NSImage?
    @State private var fallbackPath: String?

    var body: some View {
        ZStack {
            if let fallbackImage {
                Image(nsImage: fallbackImage)
                    .resizable()
                    .scaledToFit()
                    .rotationEffect(.degrees(Double(item.correction.rotationDegrees)))
                    .scaleEffect(x: item.correction.flipHorizontal ? -1 : 1,
                                 y: item.correction.flipVertical ? -1 : 1)
                    .animation(.easeInOut(duration: 0.16), value: item.correction)
            } else {
                VideoPlayer(player: player)
                    .rotationEffect(.degrees(Double(item.correction.rotationDegrees)))
                    .scaleEffect(x: item.correction.flipHorizontal ? -1 : 1,
                                 y: item.correction.flipVertical ? -1 : 1)
                    .animation(.easeInOut(duration: 0.16), value: item.correction)
            }
            if previewUnavailable {
                Label(L10n.string("correction.preview.unavailable"), systemImage: "exclamationmark.triangle")
                    .foregroundColor(.white)
                    .padding(12)
                    .background(.black.opacity(0.72), in: RoundedRectangle(cornerRadius: 8))
            }
        }
        .background(Color.black)
        .aspectRatio(previewAspectRatio, contentMode: .fit)
        .task(id: item.id) {
            player.pause()
            fallbackImage = nil
            if let fallbackPath { try? FileManager.default.removeItem(atPath: fallbackPath) }
            fallbackPath = nil
            let asset = AVURLAsset(url: URL(fileURLWithPath: item.info.path))
            let playable = (try? await asset.load(.isPlayable)) ?? false
            if playable {
                previewUnavailable = false
                player.replaceCurrentItem(with: AVPlayerItem(asset: asset))
            } else {
                player.replaceCurrentItem(with: nil)
                let path = FileManager.default.temporaryDirectory
                    .appendingPathComponent("clippi-preview-\(item.id.uuidString).jpg").path
                let generated = await Task.detached {
                    ClippiFFI.generatePreviewImage(inputPath: item.info.path, outputPath: path)
                }.value
                guard !Task.isCancelled else { return }
                fallbackPath = generated ? path : nil
                fallbackImage = generated ? NSImage(contentsOfFile: path) : nil
                previewUnavailable = fallbackImage == nil
            }
        }
        .onDisappear {
            player.pause()
            if let fallbackPath { try? FileManager.default.removeItem(atPath: fallbackPath) }
        }
    }

    private var previewAspectRatio: CGFloat {
        let width = max(item.info.width, 1)
        let height = max(item.info.height, 1)
        let displayedRotation = (item.info.rotationDegrees + item.correction.rotationDegrees).normalizedRotation
        let swapsSides = displayedRotation == 90 || displayedRotation == 270
        return swapsSides ? CGFloat(height) / CGFloat(width) : CGFloat(width) / CGFloat(height)
    }
}

private extension Int {
    var normalizedRotation: Int { ((self % 360) + 360) % 360 }
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
        panel.allowedContentTypes = [.movie, .video, .audio]
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
