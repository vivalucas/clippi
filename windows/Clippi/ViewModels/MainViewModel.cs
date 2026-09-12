using System;
using System.ComponentModel;
using System.Collections.Generic;
using System.Collections.ObjectModel;
using System.IO;
using System.Linq;
using System.Runtime.CompilerServices;
using System.Text.Json;
using System.Threading;
using System.Threading.Tasks;
using Clippi;
using Microsoft.UI.Dispatching;
using Windows.ApplicationModel.DataTransfer;

namespace Clippi.ViewModels
{
    public class MainViewModel : INotifyPropertyChanged
    {
        private string _filePath = "";
        private string _fileName = "";
        private int _width;
        private int _height;
        private double _duration;
        private string _codec = "";
        private double _frameRate;
        private int _bitrate;

        private string _selectedOperation = "trim";
        private double _startTime;
        private double _endTime;
        private bool _fastMode = true;
        private string _targetResolution = "1080p";
        private string _audioFormat = "mp3";
        private string _outputFormat = "mp4";
        private string _outputPath = "";

        private bool _isProcessing;
        private double _progress;
        private string _statusMessage = "";
        private string _errorDetails = "";
        private string _gpuEncoder = L10n.Get("EncoderSoftware");

        private ulong _currentTaskId;
        private int _probeGeneration;
        private readonly DispatcherQueue? _dispatcherQueue;
        private sealed record ProbeResult(
            string Path,
            int Width,
            int Height,
            double Duration,
            string Codec,
            double FrameRate,
            int Bitrate,
            bool HasAudio,
            string PixelFormat,
            string ColorTransfer,
            bool IsHdr,
            int RotationDegrees);

        public ObservableCollection<CorrectionMediaItem> MediaItems { get; } = new();
        private CorrectionMediaItem? _selectedMediaItem;
        private string? _correctionOutputDirectory;
        private double _overallProgress;
        private bool _isImportingCorrection;
        private int _correctionQueueGeneration;
        private readonly List<ulong> _correctionTaskIds = new();
        private readonly Dictionary<ulong, string> _pendingCorrectionProgress = new();

        public CorrectionMediaItem? SelectedMediaItem
        {
            get => _selectedMediaItem;
            set { _selectedMediaItem = value; OnPropertyChanged(); OnPropertyChanged(nameof(CanEditCorrection)); }
        }

        public string? CorrectionOutputDirectory
        {
            get => _correctionOutputDirectory;
            set { _correctionOutputDirectory = value; OnPropertyChanged(); OnPropertyChanged(nameof(CorrectionOutputDisplay)); }
        }

        public string CorrectionOutputDisplay => string.IsNullOrWhiteSpace(CorrectionOutputDirectory)
            ? (string.IsNullOrWhiteSpace(_defaultOutputDirectory) ? L10n.Get("CorrectionOutputDefault") : _defaultOutputDirectory)
            : CorrectionOutputDirectory;
        public double OverallProgress { get => _overallProgress; private set { _overallProgress = value; OnPropertyChanged(); } }
        public bool IsImportingCorrection
        {
            get => _isImportingCorrection;
            private set
            {
                _isImportingCorrection = value;
                OnPropertyChanged();
                OnPropertyChanged(nameof(IsNotProcessing));
                OnPropertyChanged(nameof(CanImportCorrection));
                OnPropertyChanged(nameof(CanClearCorrection));
                OnPropertyChanged(nameof(CanStartCorrection));
            }
        }
        public bool CanImportCorrection => !IsProcessing && !IsImportingCorrection && !IsProbing;
        public bool CanEditCorrection => !IsProcessing && SelectedMediaItem != null;
        public bool CanClearCorrection => HasCorrectionMedia && CanImportCorrection;
        public int CheckedCount => MediaItems.Count(item => item.IsChecked);
        public bool? AllCorrectionItemsChecked => MediaItems.Count == 0
            ? false
            : CheckedCount == MediaItems.Count ? true : CheckedCount == 0 ? false : null;
        public int PendingCorrectionCount => MediaItems.Count(item => item.IsChecked && item.IsPending);
        public string PendingCorrectionSummary => L10n.Format("CorrectionPendingSummary", PendingCorrectionCount);
        public bool CanStartCorrection => PendingCorrectionCount > 0 && CanImportCorrection;
        public bool HasCorrectionMedia => MediaItems.Count > 0;

        public event PropertyChangedEventHandler? PropertyChanged;

        public string FilePath
        {
            get => _filePath;
            set
            {
                _filePath = value;
                OnPropertyChanged();
                OnPropertyChanged(nameof(HasFile));
                OnPropertyChanged(nameof(HasNoFile));
            }
        }

        public string FileName
        {
            get => _fileName;
            set { _fileName = value; OnPropertyChanged(); }
        }

        public int Width
        {
            get => _width;
            set { _width = value; OnPropertyChanged(); }
        }

        public int Height
        {
            get => _height;
            set { _height = value; OnPropertyChanged(); }
        }

        public double Duration
        {
            get => _duration;
            set { _duration = value; OnPropertyChanged(); }
        }

        public string Codec
        {
            get => _codec;
            set { _codec = value; OnPropertyChanged(); }
        }

        public double FrameRate
        {
            get => _frameRate;
            set { _frameRate = value; OnPropertyChanged(); }
        }

        public int Bitrate
        {
            get => _bitrate;
            set { _bitrate = value; OnPropertyChanged(); }
        }

        public string SelectedOperation
        {
            get => _selectedOperation;
            set { _selectedOperation = value; OnPropertyChanged(); OnPropertyChanged(nameof(OperationUnavailableReason)); }
        }

        public double StartTime
        {
            get => _startTime;
            set { _startTime = value; OnPropertyChanged(); }
        }

        public double EndTime
        {
            get => _endTime;
            set { _endTime = value; OnPropertyChanged(); }
        }

        public bool FastMode
        {
            get => _fastMode;
            set { _fastMode = value; OnPropertyChanged(); }
        }

        public string TargetResolution
        {
            get => _targetResolution;
            set { _targetResolution = value; OnPropertyChanged(); }
        }

        public string AudioFormat
        {
            get => _audioFormat;
            set { _audioFormat = value; OnPropertyChanged(); }
        }

        public string OutputFormat
        {
            get => _outputFormat;
            set { _outputFormat = value; OnPropertyChanged(); }
        }

        public string OutputPath
        {
            get => _outputPath;
            set { _outputPath = value; OnPropertyChanged(); }
        }

        public bool IsProcessing
        {
            get => _isProcessing;
            set
            {
                _isProcessing = value;
                OnPropertyChanged();
                OnPropertyChanged(nameof(CanStartCorrection));
                OnPropertyChanged(nameof(IsNotProcessing));
                OnPropertyChanged(nameof(CanImportCorrection));
                OnPropertyChanged(nameof(CanEditCorrection));
                OnPropertyChanged(nameof(CanClearCorrection));
            }
        }

        public double Progress
        {
            get => _progress;
            set { _progress = value; OnPropertyChanged(); }
        }

        public string StatusMessage
        {
            get => _statusMessage;
            set { _statusMessage = value; OnPropertyChanged(); }
        }

        public string ErrorDetails
        {
            get => _errorDetails;
            set
            {
                _errorDetails = value;
                OnPropertyChanged();
                OnPropertyChanged(nameof(HasErrorDetails));
            }
        }

        public string GpuEncoder
        {
            get => _gpuEncoder;
            set { _gpuEncoder = value; OnPropertyChanged(); }
        }

        public bool HasFile => !string.IsNullOrEmpty(FilePath);
        public bool HasNoFile => !HasFile;
        public bool HasErrorDetails => !string.IsNullOrWhiteSpace(ErrorDetails);

        private static string DefaultOutputPreferencePath => Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "Clippi", "default-output.txt");
        private string _defaultOutputDirectory = "";
        public string DefaultOutputDisplay => string.IsNullOrWhiteSpace(_defaultOutputDirectory) ? L10n.Get("SettingsSourceFolder") : _defaultOutputDirectory;

        public void SetDefaultOutputDirectory(string path)
        {
            Directory.CreateDirectory(Path.GetDirectoryName(DefaultOutputPreferencePath)!);
            File.WriteAllText(DefaultOutputPreferencePath, path);
            _defaultOutputDirectory = path;
            OnPropertyChanged(nameof(DefaultOutputDisplay));
            OnPropertyChanged(nameof(CorrectionOutputDisplay));
        }

        public MainViewModel()
        {
            try { if (File.Exists(DefaultOutputPreferencePath)) _defaultOutputDirectory = File.ReadAllText(DefaultOutputPreferencePath).Trim(); }
            catch (Exception ex) when (ex is IOException || ex is UnauthorizedAccessException) { }
            _dispatcherQueue = DispatcherQueue.GetForCurrentThread();
            _ = Task.Run(() =>
            {
                try
                {
                    var json = ClippiCore.DetectGpu();
                    DispatchToUi(() => ApplyGpuDetection(json));
                }
                catch
                {
                    DispatchToUi(() => GpuEncoder = L10n.Get("EncoderSoftware"));
                }
            });
        }

        private void DispatchToUi(Action action)
        {
            if (_dispatcherQueue != null && !_dispatcherQueue.HasThreadAccess)
            {
                _dispatcherQueue.TryEnqueue(() => action());
                return;
            }

            action();
        }

        private void ApplyGpuDetection(string json)
        {
            try
            {
                using var doc = JsonDocument.Parse(json);
                var root = doc.RootElement;

                if (root.TryGetProperty("video_encoder", out var encoder) && encoder.ValueKind == JsonValueKind.String)
                {
                    GpuEncoder = encoder.GetString() ?? L10n.Get("EncoderSoftware");
                }
            }
            catch
            {
                GpuEncoder = L10n.Get("EncoderSoftware");
            }
        }

        private ProbeResult? ParseProbeResult(string path)
        {
            try
            {
                var json = ClippiCore.ProbeFile(path);
                if (json == null) return null;

                using var doc = JsonDocument.Parse(json);
                var root = doc.RootElement;

                return new ProbeResult(
                    path,
                    root.GetProperty("width").GetInt32(),
                    root.GetProperty("height").GetInt32(),
                    root.GetProperty("duration_secs").GetDouble(),
                    root.GetProperty("codec").GetString() ?? "",
                    root.GetProperty("frame_rate").GetDouble(),
                    root.GetProperty("bitrate").TryGetInt64(out long bitrate)
                        ? (int)Math.Min(bitrate, int.MaxValue)
                        : 0,
                    root.TryGetProperty("has_audio", out var hasAudio) && hasAudio.ValueKind == JsonValueKind.True,
                    root.TryGetProperty("pixel_format", out var pixelFormat) ? pixelFormat.GetString() ?? "" : "",
                    root.TryGetProperty("color_transfer", out var colorTransfer) ? colorTransfer.GetString() ?? "" : "",
                    root.TryGetProperty("is_hdr", out var isHdr) && isHdr.ValueKind == JsonValueKind.True,
                    root.TryGetProperty("rotation_degrees", out var rotation) ? rotation.GetInt32() : 0);
            }
            catch
            {
                return null;
            }
        }

        public async Task ProbeFileAsync(string path)
        {
            if (!IsNotProcessing) return;
            if (!IsSupportedMedia(path))
            {
                DispatchToUi(() =>
                {
                    ErrorDetails = "";
                    StatusMessage = L10n.Get("ErrorUnsupportedVideo");
                });
                return;
            }

            IsProbing = true;
            StatusMessage = L10n.Get("StatusReading");
            ProbeResult? result;
            var generation = Interlocked.Increment(ref _probeGeneration);
            try { result = await Task.Run(() => ParseProbeResult(path)); }
            finally { IsProbing = false; }
            if (generation != _probeGeneration)
                return;

            if (result == null)
            {
                DispatchToUi(() =>
                {
                    ErrorDetails = "";
                    StatusMessage = L10n.Get("ErrorReadFileFailed");
                });
                return;
            }

            DispatchToUi(() => ApplyProbeResult(result));
        }

        private void ApplyProbeResult(ProbeResult result)
        {
            FilePath = result.Path;
            FileName = Path.GetFileName(result.Path);
            Width = result.Width;
            Height = result.Height;
            Duration = result.Duration;
            Codec = result.Codec;
            FrameRate = result.FrameRate;
            Bitrate = result.Bitrate;
            HasAudio = result.HasAudio;

            StartTime = 0;
            Progress = 0;
            StatusMessage = "";
            EndTime = Duration;
            OutputPath = GenerateOutputPath(result.Path);
            OnPropertyChanged(nameof(OperationUnavailableReason));
        }

        private bool _isProbing;
        public bool IsProbing
        {
            get => _isProbing;
            private set { _isProbing = value; OnPropertyChanged(); OnPropertyChanged(nameof(IsNotProcessing)); OnPropertyChanged(nameof(CanImportCorrection)); OnPropertyChanged(nameof(CanStartCorrection)); }
        }
        public string OperationUnavailableReason => !HasFile ? "" :
            ((SelectedOperation == "extractAudio" || SelectedOperation == "removeAudio") && !HasAudio) ? L10n.Get("ErrorNoAudioTrack") :
            ((SelectedOperation == "scale" || SelectedOperation == "removeAudio") && Width == 0) ? L10n.Get("ErrorNoVideoTrack") : "";

        public bool IsNotProcessing => !IsProcessing && !IsProbing && !IsImportingCorrection;

        public bool StartProcessing()
        {
            if (!IsNotProcessing || !ValidateBeforeStart()) return false;

            IsProcessing = true;
            Progress = 0;
            ErrorDetails = "";
            StatusMessage = L10n.Get("StatusProcessing");

            var config = BuildTaskConfig();

            _currentTaskId = ClippiCore.RunTask(config, progressJson =>
            {
                if (_dispatcherQueue != null)
                {
                    _dispatcherQueue.TryEnqueue(() => UpdateProgress(progressJson));
                }
                else
                {
                    UpdateProgress(progressJson);
                }
            });

            if (_currentTaskId == 0)
            {
                IsProcessing = false;
                StatusMessage = L10n.Get("ErrorStartTaskFailed");
                return false;
            }

            return true;
        }

        public void CancelProcessing()
        {
            if (_currentTaskId > 0)
            {
                ClippiCore.CancelTask(_currentTaskId);
                _currentTaskId = 0;
                IsProcessing = false;
                StatusMessage = L10n.Get("StatusCancelled");
            }
        }

        private string BuildTaskConfig()
        {
            var config = new
            {
                input_path = FilePath,
                output_path = OutputPath,
                operation = GetOperation(),
                video_codec = GpuEncoder != L10n.Get("EncoderSoftware") ? GpuEncoder : "libx264",
                audio_codec = SelectedOperation == "convert" ? "aac" : "copy"
            };

            return JsonSerializer.Serialize(config);
        }

        private object GetOperation()
        {
            return SelectedOperation switch
            {
                "trim" => new { Trim = new { start = StartTime, end = EndTime, fast_mode = FastMode } },
                "convert" => new { Convert = new { format = OutputFormat } },
                "scale" => new { Scale = new { width = GetResolutionWidth(), height = GetResolutionHeight() } },
                "extractAudio" => new { ExtractAudio = new { format = AudioFormat } },
                "removeAudio" => "RemoveAudio",
                _ => new { }
            };
        }

        private int GetResolutionWidth()
        {
            return TargetResolution switch
            {
                "4K" => 3840,
                "1080p" => 1920,
                "720p" => 1280,
                "480p" => 854,
                _ => 1920
            };
        }

        private int GetResolutionHeight()
        {
            return TargetResolution switch
            {
                "4K" => 2160,
                "1080p" => 1080,
                "720p" => 720,
                "480p" => 480,
                _ => 1080
            };
        }

        private string GenerateOutputPath(string inputPath)
        {
            var dir = string.IsNullOrWhiteSpace(_defaultOutputDirectory) ? Path.GetDirectoryName(inputPath) ?? "" : _defaultOutputDirectory;
            var name = Path.GetFileNameWithoutExtension(inputPath);
            return UniqueOutputPath(Path.Combine(dir, $"{name}_output.{GetOutputExtension()}"));
        }

        public string GenerateOutputPathInDirectory(string directory)
        {
            var fileName = string.IsNullOrWhiteSpace(FileName)
                ? "output"
                : Path.GetFileNameWithoutExtension(FileName);
            return UniqueOutputPath(Path.Combine(directory, $"{fileName}_output.{GetOutputExtension()}"));
        }

        private static bool IsSupportedMedia(string path)
        {
            var ext = Path.GetExtension(path).ToLowerInvariant();
            return ext is ".mp4" or ".mkv" or ".mov" or ".webm" or ".avi" or ".m4v" or ".mp3" or ".wav" or ".aac" or ".m4a" or ".flac";
        }

        public string GetOutputExtension()
        {
            return SelectedOperation switch
            {
                "extractAudio" => AudioFormat,
                "convert" => OutputFormat,
                _ => GetInputExtensionOrDefault()
            };
        }

        public void RefreshOutputPath()
        {
            if (!string.IsNullOrEmpty(FilePath))
            {
                OutputPath = string.IsNullOrWhiteSpace(OutputPath)
                    ? GenerateOutputPath(FilePath)
                    : UniqueOutputPath(Path.ChangeExtension(OutputPath, GetOutputExtension()));
            }
        }

        private bool ValidateBeforeStart()
        {
            ErrorDetails = "";

            if (string.IsNullOrWhiteSpace(FilePath))
                return false;

            if (string.IsNullOrWhiteSpace(OutputPath))
            {
                StatusMessage = L10n.Get("ErrorOutputPathRequired");
                return false;
            }

            var outputDir = Path.GetDirectoryName(OutputPath);
            if (string.IsNullOrWhiteSpace(outputDir) || !Directory.Exists(outputDir))
            {
                StatusMessage = L10n.Get("ErrorOutputDirMissing");
                return false;
            }

            try
            {
                var probePath = Path.Combine(outputDir, $".clippi-write-test-{Guid.NewGuid():N}.tmp");
                File.WriteAllText(probePath, "");
                File.Delete(probePath);
            }
            catch
            {
                StatusMessage = L10n.Get("ErrorOutputDirNotWritable");
                return false;
            }

            if (File.Exists(OutputPath))
            {
                StatusMessage = L10n.Get("ErrorOutputExists");
                return false;
            }

            if (SelectedOperation == "trim")
            {
                if (!double.IsFinite(StartTime) || !double.IsFinite(EndTime) || StartTime < 0 || EndTime <= StartTime)
                {
                    StatusMessage = L10n.Get("ErrorTrimEndAfterStart");
                    return false;
                }

                if (Duration > 0 && StartTime >= Duration)
                {
                    StatusMessage = L10n.Get("ErrorTrimStartBeforeDuration");
                    return false;
                }

                if (Duration > 0 && EndTime > Duration)
                {
                    EndTime = Duration;
                }
            }

            if (SelectedOperation == "extractAudio" && !HasAudio)
            {
                StatusMessage = L10n.Get("ErrorNoAudioTrack");
                return false;
            }

            if ((SelectedOperation == "scale" || SelectedOperation == "removeAudio") && Width == 0)
            {
                StatusMessage = L10n.Get("ErrorNoVideoTrack");
                return false;
            }

            OutputPath = Path.GetFullPath(OutputPath);
            return true;
        }

        private string UniqueOutputPath(string path)
        {
            if (!File.Exists(path))
                return path;

            var dir = Path.GetDirectoryName(path) ?? "";
            var name = Path.GetFileNameWithoutExtension(path);
            var ext = Path.GetExtension(path);

            for (int index = 2; index <= 999; index++)
            {
                var candidate = Path.Combine(dir, $"{name} {index}{ext}");
                if (!File.Exists(candidate))
                    return candidate;
            }

            return path;
        }

        private void UpdateProgress(string progressJson)
        {
            try
            {
                using var doc = JsonDocument.Parse(progressJson);
                var root = doc.RootElement;
                if (!IsProcessing || !root.TryGetProperty("task_id", out var taskId) || taskId.GetUInt64() != _currentTaskId) return;

                if (root.TryGetProperty("percent", out var percent))
                {
                    Progress = percent.GetDouble();
                }

                if (root.TryGetProperty("state", out var state) && state.ValueKind == JsonValueKind.String)
                {
                    var stateText = state.GetString();
                    if (stateText == "failed" || stateText == "cancelled")
                    {
                        var message = root.TryGetProperty("message", out var messageElement) && messageElement.ValueKind == JsonValueKind.String
                            ? messageElement.GetString()
                            : L10n.Get("ErrorTaskFailed");

                        IsProcessing = false;
                        _currentTaskId = 0;
                        ErrorDetails = message ?? "";
                        StatusMessage = stateText == "cancelled" ? L10n.Get("StatusCancelled") : L10n.Get("ErrorTaskFailed");
                        return;
                    }

                    if (stateText == "completed")
                    {
                        IsProcessing = false;
                        _currentTaskId = 0;
                        StatusMessage = L10n.Get("StatusCompleted");
                        return;
                    }
                }

                var progressMessage = L10n.Get("StatusProcessing");
                if (root.TryGetProperty("speed", out var speed) && speed.ValueKind == JsonValueKind.String)
                {
                    var speedText = speed.GetString();
                    if (!string.IsNullOrWhiteSpace(speedText))
                        progressMessage += L10n.Format("StatusProcessingSpeed", speedText);
                }

                if (root.TryGetProperty("eta_secs", out var eta) && eta.ValueKind == JsonValueKind.Number && eta.TryGetInt64(out long etaSecs))
                {
                    progressMessage += L10n.Format("StatusProcessingEta", etaSecs);
                }

                StatusMessage = progressMessage;
            }
            catch (Exception ex)
            {
                StatusMessage = L10n.Format("ErrorProgressParseFailed", ex.Message);
            }
        }

        public async Task ImportCorrectionFilesAsync(IEnumerable<string> paths)
        {
            if (!CanImportCorrection) return;
            IsImportingCorrection = true;
            ErrorDetails = "";
            var failed = new List<string>();
            try
            {
                var existing = MediaItems.Select(item => item.Path).ToHashSet(StringComparer.OrdinalIgnoreCase);
                foreach (var path in paths.Where(IsSupportedVideo).Distinct(StringComparer.OrdinalIgnoreCase))
                {
                    if (existing.Contains(path)) continue;
                    var result = await Task.Run(() => ParseProbeResult(path));
                    if (result == null || result.Width <= 0)
                    {
                        failed.Add(Path.GetFileName(path));
                        continue;
                    }

                    if (MediaItems.Any(item => string.Equals(item.Path, path, StringComparison.OrdinalIgnoreCase))) continue;
                    var item = new CorrectionMediaItem(
                        result.Path, result.Width, result.Height, result.Duration,
                        result.Codec, result.FrameRate, result.PixelFormat,
                        result.ColorTransfer, result.IsHdr, result.RotationDegrees);
                    MediaItems.Add(item);
                    existing.Add(path);
                    SelectedMediaItem ??= item;
                }
            }
            finally
            {
                IsImportingCorrection = false;
            }
            if (failed.Count > 0)
            {
                StatusMessage = L10n.Format("CorrectionImportFailed", failed.Count);
                ErrorDetails = string.Join(Environment.NewLine, failed);
            }
            NotifyCorrectionCounts();
        }

        public async Task ImportCorrectionFolderAsync(string folder)
        {
            var paths = Directory.EnumerateFiles(folder, "*", SearchOption.TopDirectoryOnly)
                .Where(IsSupportedVideo)
                .OrderBy(Path.GetFileName, StringComparer.CurrentCultureIgnoreCase);
            await ImportCorrectionFilesAsync(paths);
        }

        public void ClearCorrectionMedia()
        {
            if (IsProcessing) return;
            MediaItems.Clear();
            SelectedMediaItem = null;
            OverallProgress = 0;
            NotifyCorrectionCounts();
        }

        public void ToggleAllChecked()
        {
            if (IsProcessing) return;
            bool value = CheckedCount != MediaItems.Count;
            foreach (var item in MediaItems) item.IsChecked = value;
            NotifyCorrectionCounts();
        }

        public void RotateSelected(int degrees)
        {
            if (IsProcessing || SelectedMediaItem == null) return;
            SelectedMediaItem.RotationDegrees = ((SelectedMediaItem.RotationDegrees + degrees) % 360 + 360) % 360;
            SelectedMediaItem.Status = CorrectionMediaStatus.Ready;
            NotifyCorrectionCounts();
        }

        public void FlipSelected(bool horizontal)
        {
            if (IsProcessing || SelectedMediaItem == null) return;
            if (horizontal) SelectedMediaItem.FlipHorizontal = !SelectedMediaItem.FlipHorizontal;
            else SelectedMediaItem.FlipVertical = !SelectedMediaItem.FlipVertical;
            SelectedMediaItem.Status = CorrectionMediaStatus.Ready;
            NotifyCorrectionCounts();
        }

        public void ResetSelectedCorrection()
        {
            if (IsProcessing || SelectedMediaItem == null) return;
            SelectedMediaItem.RotationDegrees = 0;
            SelectedMediaItem.FlipHorizontal = false;
            SelectedMediaItem.FlipVertical = false;
            SelectedMediaItem.Status = CorrectionMediaStatus.Ready;
            NotifyCorrectionCounts();
        }

        public void ApplySelectedCorrection(string scope)
        {
            if (IsProcessing || SelectedMediaItem == null) return;
            IEnumerable<CorrectionMediaItem> targets = scope switch
            {
                "checked" => MediaItems.Where(item => item.IsChecked),
                "all" => MediaItems,
                _ => new[] { SelectedMediaItem }
            };
            foreach (var item in targets)
            {
                item.RotationDegrees = SelectedMediaItem.RotationDegrees;
                item.FlipHorizontal = SelectedMediaItem.FlipHorizontal;
                item.FlipVertical = SelectedMediaItem.FlipVertical;
                item.Status = CorrectionMediaStatus.Ready;
            }
            NotifyCorrectionCounts();
        }

        public async Task<bool> StartCorrectionQueueAsync()
        {
            if (IsProcessing) return false;
            var targets = MediaItems.Where(item => item.IsChecked && item.IsPending).ToList();
            if (targets.Count == 0)
            {
                StatusMessage = L10n.Get("CorrectionNothingToProcess");
                return false;
            }

            var configs = new List<object>();
            var configuredTargets = new List<CorrectionMediaItem>();
            var reservedOutputs = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
            foreach (var item in targets)
            {
                try
                {
                    var output = CorrectionOutputPath(item);
                    Directory.CreateDirectory(Path.GetDirectoryName(output)!);
                    output = UniqueBatchOutputPath(output, reservedOutputs);
                    configs.Add(new
                    {
                        input_path = item.Path,
                        output_path = output,
                        operation = new
                        {
                            Transform = new
                            {
                                rotation_degrees = item.RotationDegrees,
                                flip_horizontal = item.FlipHorizontal,
                                flip_vertical = item.FlipVertical
                            }
                        },
                        video_codec = CorrectionVideoCodec(item),
                        audio_codec = "aac"
                    });
                    item.Status = CorrectionMediaStatus.Queued;
                    item.Progress = 0;
                    configuredTargets.Add(item);
                }
                catch (Exception ex)
                {
                    item.ErrorDetails = ex.Message;
                    item.Status = CorrectionMediaStatus.Failed;
                }
            }
            if (configs.Count == 0) return false;

            IsProcessing = true;
            var generation = ++_correctionQueueGeneration;
            OverallProgress = 0;
            _pendingCorrectionProgress.Clear();
            foreach (var item in MediaItems) item.TaskId = null;
            var json = JsonSerializer.Serialize(configs);
            var ids = await Task.Run(() => ClippiCore.QueueTasks(json, progressJson =>
                DispatchToUi(() => { if (generation == _correctionQueueGeneration) UpdateCorrectionProgress(progressJson); })));
            if (generation != _correctionQueueGeneration || !IsProcessing)
            {
                foreach (var id in ids) ClippiCore.CancelTask(id);
                _pendingCorrectionProgress.Clear();
                return false;
            }
            if (ids.Length != configuredTargets.Count)
            {
                ++_correctionQueueGeneration;
                foreach (var id in ids) ClippiCore.CancelTask(id);
                _pendingCorrectionProgress.Clear();
                foreach (var item in configuredTargets)
                {
                    item.Status = CorrectionMediaStatus.Failed;
                    item.ErrorDetails = L10n.Get("ErrorStartTaskFailed");
                }
                IsProcessing = false;
                StatusMessage = L10n.Get("ErrorStartTaskFailed");
                return false;
            }
            _correctionTaskIds.Clear();
            _correctionTaskIds.AddRange(ids);
            for (int index = 0; index < ids.Length; index++)
            {
                configuredTargets[index].TaskId = ids[index];

            }
            foreach (var id in ids)
                if (_pendingCorrectionProgress.Remove(id, out var pending)) UpdateCorrectionProgress(pending);
            return true;
        }

        public void CancelCorrectionQueue()
        {
            _correctionQueueGeneration++;
            foreach (var id in _correctionTaskIds) ClippiCore.CancelTask(id);
            _correctionTaskIds.Clear();
            _pendingCorrectionProgress.Clear();
            foreach (var item in MediaItems.Where(item => item.Status is CorrectionMediaStatus.Queued or CorrectionMediaStatus.Processing))
                item.Status = CorrectionMediaStatus.Cancelled;
            IsProcessing = false;
        }

        private void UpdateCorrectionProgress(string progressJson)
        {
            try
            {
                using var doc = JsonDocument.Parse(progressJson);
                var root = doc.RootElement;
                if (!root.TryGetProperty("task_id", out var idElement)) return;
                var taskId = idElement.GetUInt64();
                var item = MediaItems.FirstOrDefault(candidate => candidate.TaskId == taskId);
                if (item == null)
                {
                    _pendingCorrectionProgress[taskId] = progressJson;
                    return;
                }
                if (root.TryGetProperty("percent", out var percent)) item.Progress = percent.GetDouble();
                if (root.TryGetProperty("state", out var state))
                {
                    item.Status = state.GetString() switch
                    {
                        "running" => CorrectionMediaStatus.Processing,
                        "completed" => CorrectionMediaStatus.Completed,
                        "failed" => CorrectionMediaStatus.Failed,
                        "cancelled" => CorrectionMediaStatus.Cancelled,
                        _ => item.Status
                    };
                    if (item.Status == CorrectionMediaStatus.Failed && root.TryGetProperty("message", out var message))
                        item.ErrorDetails = message.GetString() ?? "";
                }

                var active = MediaItems.Where(candidate => candidate.TaskId.HasValue).ToList();
                OverallProgress = active.Count == 0 ? 0 : active.Average(candidate => candidate.Progress);
                NotifyCorrectionCounts();
                if (active.Count > 0 && active.All(candidate => candidate.Status is CorrectionMediaStatus.Completed or CorrectionMediaStatus.Failed or CorrectionMediaStatus.Cancelled))
                {
                    IsProcessing = false;
                    _correctionTaskIds.Clear();
                    _pendingCorrectionProgress.Clear();
                }
            }
            catch { }
        }

        private string CorrectionOutputPath(CorrectionMediaItem item)
        {
            var directory = string.IsNullOrWhiteSpace(CorrectionOutputDirectory)
                ? (string.IsNullOrWhiteSpace(_defaultOutputDirectory) ? Path.Combine(Path.GetDirectoryName(item.Path)!, "Clippi-output") : _defaultOutputDirectory)
                : CorrectionOutputDirectory!;
            return Path.Combine(directory, $"{Path.GetFileNameWithoutExtension(item.Path)}.mp4");
        }

        private string CorrectionVideoCodec(CorrectionMediaItem item)
        {
            if (item.IsHdr) return "libx265";
            return GpuEncoder != L10n.Get("EncoderSoftware") ? GpuEncoder : "libx264";
        }

        private static string UniqueBatchOutputPath(string path, HashSet<string> reserved)
        {
            var directory = Path.GetDirectoryName(path)!;
            var name = Path.GetFileNameWithoutExtension(path);
            var extension = Path.GetExtension(path);
            var candidate = path;
            var index = 1;
            while (File.Exists(candidate) || reserved.Contains(candidate))
            {
                index++;
                candidate = Path.Combine(directory, $"{name}_{index}{extension}");
            }
            reserved.Add(candidate);
            return candidate;
        }

        private void NotifyCorrectionCounts()
        {
            OnPropertyChanged(nameof(CheckedCount));
            OnPropertyChanged(nameof(AllCorrectionItemsChecked));
            OnPropertyChanged(nameof(PendingCorrectionCount));
            OnPropertyChanged(nameof(PendingCorrectionSummary));
            OnPropertyChanged(nameof(CanStartCorrection));
            OnPropertyChanged(nameof(HasCorrectionMedia));
            OnPropertyChanged(nameof(CanClearCorrection));
        }

        public void RefreshCorrectionCounts() => NotifyCorrectionCounts();

        private static bool IsSupportedVideo(string path)
        {
            var ext = Path.GetExtension(path).ToLowerInvariant();
            return ext is ".mp4" or ".mkv" or ".mov" or ".webm" or ".avi" or ".m4v"
                or ".mts" or ".m2ts" or ".ts" or ".mpg" or ".mpeg" or ".wmv" or ".flv" or ".3gp";
        }

        protected void OnPropertyChanged([CallerMemberName] string? propertyName = null)
        {
            PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(propertyName));
        }

        private string GetInputExtensionOrDefault()
        {
            var ext = Path.GetExtension(FilePath).TrimStart('.').ToLowerInvariant();
            return string.IsNullOrWhiteSpace(ext) ? "mp4" : ext;
        }

        private bool HasAudio { get; set; }

        public void CopyErrorDetailsToClipboard()
        {
            if (string.IsNullOrWhiteSpace(ErrorDetails))
                return;

            var package = new DataPackage();
            package.SetText(ErrorDetails);
            Clipboard.SetContent(package);
        }
    }

    public enum CorrectionMediaStatus { Ready, Queued, Processing, Completed, Failed, Cancelled }

    public sealed class CorrectionMediaItem : INotifyPropertyChanged
    {
        private bool _isChecked = true;
        private int _rotationDegrees;
        private bool _flipHorizontal;
        private bool _flipVertical;
        private CorrectionMediaStatus _status = CorrectionMediaStatus.Ready;
        private double _progress;
        private string _errorDetails = "";

        public CorrectionMediaItem(
            string path, int width, int height, double duration, string codec, double frameRate,
            string pixelFormat, string colorTransfer, bool isHdr, int sourceRotationDegrees)
        {
            Path = path; Width = width; Height = height; Duration = duration; Codec = codec;
            FrameRate = frameRate; PixelFormat = pixelFormat; ColorTransfer = colorTransfer;
            IsHdr = isHdr; SourceRotationDegrees = sourceRotationDegrees;
        }

        public string Path { get; }
        public string FileName => System.IO.Path.GetFileName(Path);
        public int Width { get; }
        public int Height { get; }
        public double Duration { get; }
        public string Codec { get; }
        public double FrameRate { get; }
        public string PixelFormat { get; }
        public string ColorTransfer { get; }
        public bool IsHdr { get; }
        public int SourceRotationDegrees { get; }
        public ulong? TaskId { get; set; }
        public string ErrorDetails { get => _errorDetails; set { _errorDetails = value; Changed(); } }
        public bool IsChecked { get => _isChecked; set { _isChecked = value; Changed(); } }
        public int RotationDegrees { get => _rotationDegrees; set { _rotationDegrees = value; Changed(); Changed(nameof(TransformSummary)); Changed(nameof(NeedsProcessing)); Changed(nameof(IsPending)); } }
        public bool FlipHorizontal { get => _flipHorizontal; set { _flipHorizontal = value; Changed(); Changed(nameof(TransformSummary)); Changed(nameof(NeedsProcessing)); Changed(nameof(IsPending)); } }
        public bool FlipVertical { get => _flipVertical; set { _flipVertical = value; Changed(); Changed(nameof(TransformSummary)); Changed(nameof(NeedsProcessing)); Changed(nameof(IsPending)); } }
        public CorrectionMediaStatus Status { get => _status; set { _status = value; Changed(); Changed(nameof(StatusText)); Changed(nameof(IsPending)); } }
        public double Progress { get => _progress; set { _progress = value; Changed(); Changed(nameof(StatusText)); } }
        public bool NeedsProcessing => RotationDegrees != 0 || FlipHorizontal || FlipVertical || SourceRotationDegrees != 0;
        public bool IsPending => NeedsProcessing && Status is CorrectionMediaStatus.Ready or CorrectionMediaStatus.Failed or CorrectionMediaStatus.Cancelled;
        public string Details => $"{Width}×{Height} · {TimeSpan.FromSeconds(Duration):mm\\:ss}{(IsHdr ? " · HDR" : "")}";
        public string TransformSummary
        {
            get
            {
                var parts = new List<string>();
                if (RotationDegrees == 90) parts.Add(L10n.Get("CorrectionRotateRight"));
                else if (RotationDegrees == 180) parts.Add(L10n.Get("CorrectionRotate180"));
                else if (RotationDegrees == 270) parts.Add(L10n.Get("CorrectionRotateLeft"));
                if (FlipHorizontal) parts.Add(L10n.Get("CorrectionFlipHorizontal"));
                if (FlipVertical) parts.Add(L10n.Get("CorrectionFlipVertical"));
                if (parts.Count == 0 && SourceRotationDegrees != 0) return L10n.Format("CorrectionMetadata", SourceRotationDegrees);
                return parts.Count == 0 ? L10n.Get("CorrectionNone") : string.Join(" + ", parts);
            }
        }
        public string StatusText => Status switch
        {
            CorrectionMediaStatus.Queued => L10n.Get("CorrectionStatusQueued"),
            CorrectionMediaStatus.Processing => $"{Progress:0}%",
            CorrectionMediaStatus.Completed => L10n.Get("CorrectionStatusCompleted"),
            CorrectionMediaStatus.Failed => L10n.Get("CorrectionStatusFailed"),
            CorrectionMediaStatus.Cancelled => L10n.Get("CorrectionStatusCancelled"),
            _ => TransformSummary
        };

        public event PropertyChangedEventHandler? PropertyChanged;
        private void Changed([CallerMemberName] string? name = null) => PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(name));
    }
}
