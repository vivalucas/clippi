using System;
using System.ComponentModel;
using System.IO;
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
            int Bitrate);

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
            set { _selectedOperation = value; OnPropertyChanged(); }
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
            set { _isProcessing = value; OnPropertyChanged(); }
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

        public MainViewModel()
        {
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
                        : 0);
            }
            catch
            {
                return null;
            }
        }

        public async Task ProbeFileAsync(string path)
        {
            if (!IsSupportedVideo(path))
            {
                DispatchToUi(() =>
                {
                    ErrorDetails = "";
                    StatusMessage = L10n.Get("ErrorUnsupportedVideo");
                });
                return;
            }

            var generation = Interlocked.Increment(ref _probeGeneration);
            var result = await Task.Run(() => ParseProbeResult(path));
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

            EndTime = Duration;
            OutputPath = GenerateOutputPath(result.Path);
        }

        public void StartProcessing()
        {
            if (!ValidateBeforeStart()) return;

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
            }
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
                audio_codec = "aac"
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
            var dir = Path.GetDirectoryName(inputPath) ?? "";
            var name = Path.GetFileNameWithoutExtension(inputPath);
            return UniqueOutputPath(Path.Combine(dir, $"{name}_output.{GetOutputExtension()}"));
        }

        private static bool IsSupportedVideo(string path)
        {
            var ext = Path.GetExtension(path).ToLowerInvariant();
            return ext is ".mp4" or ".mkv" or ".mov" or ".webm" or ".avi" or ".m4v";
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
                OutputPath = GenerateOutputPath(FilePath);
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
                if (StartTime < 0 || EndTime <= StartTime)
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
                        ClippiCore.ClearProgressCallback();
                        return;
                    }

                    if (stateText == "completed")
                    {
                        IsProcessing = false;
                        _currentTaskId = 0;
                        StatusMessage = L10n.Get("StatusCompleted");
                        ClippiCore.ClearProgressCallback();
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

        protected void OnPropertyChanged([CallerMemberName] string? propertyName = null)
        {
            PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(propertyName));
        }

        private string GetInputExtensionOrDefault()
        {
            var ext = Path.GetExtension(FilePath).TrimStart('.').ToLowerInvariant();
            return string.IsNullOrWhiteSpace(ext) ? "mp4" : ext;
        }

        public void CopyErrorDetailsToClipboard()
        {
            if (string.IsNullOrWhiteSpace(ErrorDetails))
                return;

            var package = new DataPackage();
            package.SetText(ErrorDetails);
            Clipboard.SetContent(package);
        }
    }
}
