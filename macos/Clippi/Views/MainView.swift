import SwiftUI
import AppKit
import UniformTypeIdentifiers
import AVKit

struct MainView: View {
    @StateObject private var viewModel = MainViewModel()
    @State private var showingSettings = false
    @State private var workspace: Workspace = .tools
    @AppStorage("appearance") private var appearance = "system"

    private enum Workspace { case tools, correction, audio }

    private var pageTitle: String {
        showingSettings ? L10n.string("settings.page") : workspace == .correction ? L10n.string("workspace.correction") : workspace == .audio ? L10n.string("nav.audio") : viewModel.selectedOperation.title
    }

    private var unavailableReason: String? {
        guard workspace != .correction, let info = viewModel.fileInfo else { return nil }
        if (viewModel.selectedOperation == .extractAudio || viewModel.selectedOperation == .removeAudio) && !info.hasAudio {
            return L10n.string("error.noAudioTrack")
        }
        if (viewModel.selectedOperation == .scale || viewModel.selectedOperation == .removeAudio) && info.width == 0 {
            return L10n.string("error.noVideoTrack")
        }
        return nil
    }

    private func symbol(_ operation: MainViewModel.OperationType) -> String {
        switch operation {
        case .trim: return "scissors"
        case .convert: return "arrow.triangle.2.circlepath"
        case .scale: return "arrow.up.left.and.arrow.down.right"
        case .extractAudio: return "waveform"
        case .removeAudio: return "speaker.slash"
        }
    }

    var body: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 24) {
                HStack(spacing: 10) {
                    Image("BrandMark")
                        .resizable().interpolation(.high).scaledToFit()
                        .frame(width: 38, height: 38).accessibilityHidden(true)
                    Text("Clippi").font(.system(size: 21, weight: .semibold))
                }.padding(.horizontal, 10).padding(.top, 12)
                VStack(alignment: .leading, spacing: 5) {
                    Text(L10n.string("nav.tools")).font(.caption).foregroundStyle(.secondary)
                        .padding(.horizontal, 12).padding(.bottom, 6)
                    ForEach([MainViewModel.OperationType.trim, .convert, .scale], id: \.self) { operation in
                        navigationRow(operation.title, icon: symbol(operation), selected: !showingSettings && workspace == .tools && viewModel.selectedOperation == operation) {
                            if workspace == .correction { viewModel.useSelectedMedia() }
                            showingSettings = false
                            workspace = .tools
                            if viewModel.selectedOperation != operation { viewModel.selectedOperation = operation }
                        }
                    }
                    navigationRow(L10n.string("workspace.correction"), icon: "rotate.right", selected: !showingSettings && workspace == .correction) {
                        if workspace != .correction { viewModel.useSourceForCorrection() }
                        showingSettings = false
                        workspace = .correction
                    }
                    navigationRow(L10n.string("nav.audio"), icon: "waveform", selected: !showingSettings && workspace == .audio) {
                        if workspace == .correction { viewModel.useSelectedMedia() }
                        showingSettings = false
                        workspace = .audio
                        if viewModel.selectedOperation != .extractAudio && viewModel.selectedOperation != .removeAudio {
                            viewModel.selectedOperation = .extractAudio
                        }
                    }
                }.disabled(viewModel.isProcessing || viewModel.isImporting)
                Spacer()
                Button {
                    showingSettings = true
                } label: {
                    Label(L10n.string("settings.page"), systemImage: "gearshape")
                        .frame(maxWidth: .infinity, alignment: .leading).padding(12)
                        .foregroundStyle(showingSettings ? Color.accentColor : Color.primary)
                        .background(showingSettings ? Color.accentColor.opacity(0.10) : Color.clear, in: RoundedRectangle(cornerRadius: 9))
                }.buttonStyle(.plain).keyboardShortcut(",", modifiers: .command)
                    .disabled(viewModel.isProcessing || viewModel.isImporting)
            }
            .padding(14).frame(width: 190)
            .background(Color("BrandSidebar"))
            Divider()
            VStack(spacing: 0) {
                HStack {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(pageTitle)
                            .font(.system(size: 22, weight: .semibold))
                        Text(L10n.string(showingSettings ? "settings.subtitle" : workspace == .correction ? "workspace.correctionHint" : "workspace.toolHint"))
                            .font(.callout).foregroundStyle(.secondary)
                    }
                    Spacer()
                    if !showingSettings {
                    if workspace == .correction {
                        Menu {
                            Button(L10n.string("correction.addFiles"), action: selectMediaFiles)
                            Button(L10n.string("correction.addFolder"), action: selectMediaFolder)
                            Divider()
                            Button(L10n.string("correction.clear"), role: .destructive) { viewModel.clearMedia() }
                        } label: { Label(L10n.string("correction.addFiles"), systemImage: "plus") }
                    } else {
                        Button(action: selectSourceFile) {
                            Label(L10n.string(viewModel.fileInfo == nil ? "correction.addFiles" : "source.replace"), systemImage: "plus")
                        }.keyboardShortcut("o")
                    }
                    }
                }
                .disabled(viewModel.isProcessing || viewModel.isImporting)
                .padding(24)
                Divider()
                if showingSettings { settingsPage } else if workspace == .correction { correctionWorkspace } else { toolWorkspace }
            }.frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color("BrandCanvas"))
        }
        .accentColor(Color("BrandAccent"))
        .preferredColorScheme(appearance == "light" ? .light : appearance == "dark" ? .dark : nil)
        .frame(minWidth: 1060, minHeight: 700)
        .alert(L10n.string("error.title"), isPresented: $viewModel.showError) {
            if !viewModel.errorDetails.isEmpty {
                Button(L10n.string("error.copyDetails")) { viewModel.copyErrorDetailsToPasteboard() }
            }
            Button(L10n.string("ok")) {}
        } message: { Text(viewModel.errorMessage) }
    }

    private var settingsPage: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 16) {
                    Label(L10n.string("appearance.title"), systemImage: "circle.lefthalf.filled").font(.headline)
                    Picker(L10n.string("appearance.title"), selection: $appearance) {
                        Text(L10n.string("appearance.system")).tag("system")
                        Text(L10n.string("appearance.light")).tag("light")
                        Text(L10n.string("appearance.dark")).tag("dark")
                    }.labelsHidden().pickerStyle(.segmented)
                }.frame(maxWidth: .infinity, alignment: .leading).padding(24).background(Color("BrandSurface"), in: RoundedRectangle(cornerRadius: 14))
                VStack(alignment: .leading, spacing: 16) {
                    Label(L10n.string("settings.export"), systemImage: "folder").font(.headline)
                    Text(viewModel.defaultOutputDirectory.isEmpty ? L10n.string("settings.sourceFolder") : viewModel.defaultOutputDirectory)
                        .lineLimit(2).truncationMode(.middle).textSelection(.enabled)
                    Text(L10n.string("settings.exportHint")).font(.callout).foregroundStyle(.secondary)
                    HStack {
                        Button(L10n.string("correction.change")) {
                            let panel = NSOpenPanel()
                            panel.canChooseFiles = false
                            panel.canChooseDirectories = true
                            panel.canCreateDirectories = true
                            if panel.runModal() == .OK, let url = panel.url { viewModel.defaultOutputDirectory = url.path }
                        }
                        if !viewModel.defaultOutputDirectory.isEmpty {
                            Button(L10n.string("settings.restore")) { viewModel.defaultOutputDirectory = "" }
                        }
                    }
                }.frame(maxWidth: .infinity, alignment: .leading).padding(24).background(Color("BrandSurface"), in: RoundedRectangle(cornerRadius: 14))
                VStack(alignment: .leading, spacing: 10) {
                    Text("Clippi").font(.headline)
                    Label(L10n.string("nav.local"), systemImage: "lock.shield")
                    Text(L10n.string("settings.localHint"))
                }.font(.callout).foregroundStyle(.secondary).padding(.horizontal, 4)
            }.frame(maxWidth: 680, alignment: .leading).padding(28)
                .frame(maxWidth: .infinity, alignment: .topLeading)
        }
    }

    private func navigationRow(_ title: String, icon: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .font(.system(size: 13, weight: selected ? .semibold : .regular))
                .frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 12).padding(.vertical, 11)
                .foregroundStyle(selected ? Color.accentColor : Color.primary)
                .background(selected ? Color.accentColor.opacity(0.10) : Color.clear, in: RoundedRectangle(cornerRadius: 9))
                .contentShape(Rectangle())
        }.buttonStyle(.plain)
    }

    private var toolWorkspace: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if let info = viewModel.fileInfo {
                        if info.width > 0 {
                            VideoCorrectionPreview(item: MainViewModel.MediaItem(info: info))
                                .id(info.path).frame(height: 260).frame(maxWidth: .infinity)
                                .background(.black, in: RoundedRectangle(cornerRadius: 14))
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                        FileInfoCard(fileInfo: info)
                    } else {
                        DropAreaView(onDrop: viewModel.probeFile)
                            .disabled(viewModel.isImporting || viewModel.isProcessing)
                    }
                    if viewModel.isImporting { ProgressView().frame(maxWidth: .infinity) }
                    if viewModel.fileInfo != nil {
                    VStack(alignment: .leading, spacing: 16) {
                        if workspace == .audio {
                            Picker(L10n.string("nav.audio"), selection: $viewModel.selectedOperation) {
                                Text(L10n.string("operation.extractAudio")).tag(MainViewModel.OperationType.extractAudio)
                                Text(L10n.string("operation.removeAudio")).tag(MainViewModel.OperationType.removeAudio)
                            }.pickerStyle(.segmented)
                        }
                        Text(L10n.string("settings.title")).font(.headline)
                        operationControls
                        if let reason = unavailableReason {
                            Label(reason, systemImage: "info.circle").font(.callout).foregroundStyle(.secondary)
                        }
                    }
                    .padding(20).frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color("BrandSurface"), in: RoundedRectangle(cornerRadius: 14))
                    .disabled(viewModel.isProcessing || viewModel.isImporting)
                    }
                }.padding(24)
            }
            .onDrop(of: [.fileURL], isTargeted: nil) { providers in
                guard !viewModel.isProcessing, !viewModel.isImporting, let provider = providers.first else { return false }
                provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier) { item, _ in
                    guard let data = item as? Data, let url = URL(dataRepresentation: data, relativeTo: nil) else { return }
                    DispatchQueue.main.async { viewModel.probeFile(at: url) }
                }
                return true
            }
            Divider()
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    Image(systemName: "folder").foregroundStyle(.secondary)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(L10n.string("correction.outputTo")).font(.caption).foregroundStyle(.secondary)
                        Text(viewModel.outputPath.isEmpty ? (viewModel.defaultOutputDirectory.isEmpty ? L10n.string("output.automatic") : viewModel.defaultOutputDirectory) : viewModel.outputPath)
                            .lineLimit(1).truncationMode(.middle).help(viewModel.outputPath)
                    }
                    Button(L10n.string("correction.change"), action: selectOutputPath)
                        .disabled(viewModel.fileInfo == nil || viewModel.isProcessing)
                    Spacer(minLength: 16)
                    if viewModel.isProcessing {
                        Button(L10n.string("cancel")) { viewModel.cancelProcessing() }
                    } else {
                        Button(L10n.string("export.start")) { viewModel.startProcessing() }
                            .buttonStyle(.borderedProminent).controlSize(.large)
                            .disabled(viewModel.fileInfo == nil || viewModel.isImporting || unavailableReason != nil)
                    }
                }
                if viewModel.isProcessing { ProgressView(value: viewModel.progress, total: 100) }
                if !viewModel.statusMessage.isEmpty {
                    HStack {
                        Text(viewModel.statusMessage).font(.caption).foregroundStyle(.secondary)
                        Spacer()
                        if let completedPath = viewModel.completedOutputPath, !viewModel.isProcessing {
                            Button(L10n.string("export.reveal")) {
                                NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: completedPath)])
                            }.font(.caption)
                        }
                    }
                }
            }.padding(20).background(Color("BrandSurface"))
        }
    }

    private func selectSourceFile() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.movie, .video, .audio]
        if panel.runModal() == .OK, let url = panel.url { viewModel.probeFile(at: url) }
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
            .padding(24)
        } else {
            VStack(spacing: 0) {
                HSplitView {
                    correctionList
                        .frame(minWidth: 240, idealWidth: 260, maxWidth: 330)

                    correctionEditor
                        .frame(minWidth: 430)
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
                            .frame(width: 32, height: 30)
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
            .scrollContentBackground(.hidden)
            .background(Color("BrandCanvas"))
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
                .padding(20)
            }
        } else {
            Text(L10n.string("correction.selectMaterial")).foregroundColor(.secondary)
        }
    }

    private var correctionFooter: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(L10n.string("correction.outputTo")).fontWeight(.semibold)
                Text(viewModel.correctionOutputDirectory?.path ?? (viewModel.defaultOutputDirectory.isEmpty ? L10n.string("correction.outputDefault") : viewModel.defaultOutputDirectory))
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
                Button(L10n.string("export.start")) { viewModel.startCorrectionQueue() }
                    .buttonStyle(.borderedProminent).controlSize(.large)
                    .disabled(viewModel.pendingCorrectionCount == 0 || viewModel.isImporting)
            }
        }
        .padding(20).background(Color("BrandSurface"))
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
            Text(L10n.string("scale.hint")).font(.caption).foregroundStyle(.secondary)
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
            .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [5]))
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
    @State private var position: Double = 0
    @State private var isPlaying = false
    @State private var isSeeking = false
    private let playbackClock = Timer.publish(every: 0.25, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(spacing: 0) {
            GeometryReader { geometry in
                let quarterTurn = item.correction.rotationDegrees % 180 != 0
                ZStack {
                    Group {
                        if let fallbackImage {
                            Image(nsImage: fallbackImage).resizable().scaledToFit()
                        } else {
                            PlaybackSurface(player: player)
                        }
                    }
                    .frame(width: quarterTurn ? geometry.size.height : geometry.size.width,
                           height: quarterTurn ? geometry.size.width : geometry.size.height)
                    .rotationEffect(.degrees(Double(item.correction.rotationDegrees)))
                    .scaleEffect(x: item.correction.flipHorizontal ? -1 : 1,
                                 y: item.correction.flipVertical ? -1 : 1)
                    if previewUnavailable {
                        Text(L10n.string("correction.preview.unavailable"))
                            .font(.caption).foregroundStyle(.white).padding(12)
                    }
                }.frame(width: geometry.size.width, height: geometry.size.height).clipped()
            }
            .aspectRatio(previewAspectRatio, contentMode: .fit)
            .background(.black)
            if fallbackImage == nil && !previewUnavailable {
                HStack(spacing: 10) {
                    Button {
                        if isPlaying { player.pause() }
                        else {
                            if position >= item.info.duration - 0.05 { player.seek(to: .zero) }
                            player.play()
                        }
                        isPlaying.toggle()
                    } label: {
                        Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                    }.buttonStyle(.plain)
                        .accessibilityLabel(L10n.string(isPlaying ? "preview.pause" : "preview.play"))
                    Slider(value: $position, in: 0...max(item.info.duration, 0.01), onEditingChanged: { editing in
                        isSeeking = editing
                        if !editing { player.seek(to: CMTime(seconds: position, preferredTimescale: 600)) }
                    }) { Text(L10n.string("preview.position")) }.labelsHidden()
                    Text(String(format: "%02d:%02d", Int(position) / 60, Int(position) % 60))
                        .font(.caption.monospacedDigit())
                }.padding(10).background(Color("BrandSurface"))
            }
        }
        .onReceive(playbackClock) { _ in
            let seconds = player.currentTime().seconds
            if !isSeeking && seconds.isFinite { position = min(max(seconds, 0), max(item.info.duration, 0)) }
            isPlaying = player.rate > 0
        }
        .task(id: item.info.path) {
            player.pause()
            position = 0
            isPlaying = false
            fallbackImage = nil
            if let fallbackPath { try? FileManager.default.removeItem(atPath: fallbackPath) }
            fallbackPath = nil
            let asset = AVURLAsset(url: URL(fileURLWithPath: item.info.path))
            let playable = (try? await asset.load(.isPlayable)) ?? false
            guard !Task.isCancelled else { return }
            if playable {
                previewUnavailable = false
                player.replaceCurrentItem(with: AVPlayerItem(asset: asset))
            } else {
                player.replaceCurrentItem(with: nil)
                let path = FileManager.default.temporaryDirectory
                    .appendingPathComponent("clippi-preview-\(UUID().uuidString).jpg").path
                let generated = await Task.detached {
                    ClippiFFI.generatePreviewImage(inputPath: item.info.path, outputPath: path)
                }.value
                guard !Task.isCancelled else {
                    try? FileManager.default.removeItem(atPath: path)
                    return
                }
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

private struct PlaybackSurface: NSViewRepresentable {
    let player: AVPlayer
    func makeNSView(context: Context) -> PlaybackLayerView {
        let view = PlaybackLayerView()
        view.videoLayer.player = player
        return view
    }
    func updateNSView(_ view: PlaybackLayerView, context: Context) { view.videoLayer.player = player }
    static func dismantleNSView(_ view: PlaybackLayerView, coordinator: ()) { view.videoLayer.player = nil }
}

private final class PlaybackLayerView: NSView {
    let videoLayer = AVPlayerLayer()
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        videoLayer.videoGravity = .resizeAspect
        layer = videoLayer
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }
    override func layout() {
        super.layout()
        videoLayer.frame = bounds
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
            .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [5]))
            .foregroundColor(isDragOver ? .accentColor : Color.secondary.opacity(0.3))
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

                    Button(L10n.string("source.choose"), action: selectFile)
                        .buttonStyle(.borderedProminent)
                }
            )
            .frame(height: 200)
            .onDrop(of: [.fileURL], isTargeted: $isDragOver) { providers in
                handleDrop(providers: providers)
                return true
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
        VStack(alignment: .leading, spacing: 10) {
            Label(URL(fileURLWithPath: fileInfo.path).lastPathComponent, systemImage: fileInfo.width > 0 ? "film" : "waveform")
                .font(.headline).lineLimit(1).truncationMode(.middle).help(fileInfo.path)
            HStack(spacing: 20) {
                if fileInfo.width > 0 {
                    Label("\(fileInfo.width) × \(fileInfo.height)", systemImage: "aspectratio")
                }
                Label(formatDuration(fileInfo.duration), systemImage: "clock")
                Text(fileInfo.codec.uppercased())
                if fileInfo.frameRate > 0 { Text(String(format: "%.2f fps", fileInfo.frameRate)) }
            }.font(.caption).foregroundStyle(.secondary)
        }
        .padding(16).frame(maxWidth: .infinity, alignment: .leading)
        .background(Color("BrandSurface"), in: RoundedRectangle(cornerRadius: 14))
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

            if duration > 0 {
                Slider(value: $startTime, in: 0...duration) { Text(L10n.string("trim.startTime")) }
                    .onChange(of: startTime) { value in if value >= endTime { endTime = min(duration, value + 0.1) } }
                Slider(value: $endTime, in: 0...duration) { Text(L10n.string("trim.endTime")) }
                    .onChange(of: endTime) { value in if value <= startTime { startTime = max(0, value - 0.1) } }
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
