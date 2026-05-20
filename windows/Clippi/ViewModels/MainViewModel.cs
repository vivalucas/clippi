using System;
using System.ComponentModel;
using System.IO;
using System.Runtime.CompilerServices;
using System.Text.Json;
using System.Threading.Tasks;
using Microsoft.UI.Dispatching;

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
        private string _gpuEncoder = "软件编码";

        private ulong _currentTaskId;
        private readonly DispatcherQueue? _dispatcherQueue;

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

        public string GpuEncoder
        {
            get => _gpuEncoder;
            set { _gpuEncoder = value; OnPropertyChanged(); }
        }

        public bool HasFile => !string.IsNullOrEmpty(FilePath);
        public bool HasNoFile => !HasFile;

        public MainViewModel()
        {
            _dispatcherQueue = DispatcherQueue.GetForCurrentThread();
            DetectGpu();
        }

        private void DetectGpu()
        {
            try
            {
                var json = ClippiCore.DetectGpu();
                using var doc = JsonDocument.Parse(json);
                var root = doc.RootElement;

                if (root.TryGetProperty("video_encoder", out var encoder) && encoder.ValueKind == JsonValueKind.String)
                {
                    GpuEncoder = encoder.GetString() ?? "软件编码";
                }
            }
            catch
            {
                GpuEncoder = "软件编码";
            }
        }

        public void ProbeFile(string path)
        {
            try
            {
                var json = ClippiCore.ProbeFile(path);
                if (json == null) return;

                using var doc = JsonDocument.Parse(json);
                var root = doc.RootElement;

                FilePath = path;
                FileName = Path.GetFileName(path);
                Width = root.GetProperty("width").GetInt32();
                Height = root.GetProperty("height").GetInt32();
                Duration = root.GetProperty("duration_secs").GetDouble();
                Codec = root.GetProperty("codec").GetString() ?? "";
                FrameRate = root.GetProperty("frame_rate").GetDouble();
                Bitrate = root.GetProperty("bitrate").TryGetInt64(out long bitrate)
                    ? (int)Math.Min(bitrate, int.MaxValue)
                    : 0;

                EndTime = Duration;
                OutputPath = GenerateOutputPath(path);
            }
            catch (Exception ex)
            {
                StatusMessage = $"读取文件失败: {ex.Message}";
            }
        }

        public async Task ProbeFileAsync(string path)
        {
            await Task.Run(() => ProbeFile(path));
        }

        public void StartProcessing()
        {
            if (string.IsNullOrEmpty(FilePath)) return;

            IsProcessing = true;
            Progress = 0;
            StatusMessage = "处理中...";

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
                StatusMessage = "启动任务失败";
            }
        }

        public void CancelProcessing()
        {
            if (_currentTaskId > 0)
            {
                ClippiCore.CancelTask(_currentTaskId);
                _currentTaskId = 0;
                IsProcessing = false;
                StatusMessage = "已取消";
            }
        }

        private string BuildTaskConfig()
        {
            var config = new
            {
                input_path = FilePath,
                output_path = OutputPath,
                operation = GetOperation(),
                video_codec = GpuEncoder != "软件编码" ? GpuEncoder : "libx264",
                audio_codec = "aac",
                hw_accel = GpuEncoder != "软件编码" ? GetHwAccel() : null
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

        private string? GetHwAccel()
        {
            if (GpuEncoder.Contains("nvenc")) return "cuda";
            if (GpuEncoder.Contains("qsv")) return "qsv";
            return null;
        }

        private string GenerateOutputPath(string inputPath)
        {
            var dir = Path.GetDirectoryName(inputPath) ?? "";
            var name = Path.GetFileNameWithoutExtension(inputPath);
            return Path.Combine(dir, $"{name}_output.{GetOutputExtension()}");
        }

        public string GetOutputExtension()
        {
            return SelectedOperation == "extractAudio" ? AudioFormat : OutputFormat;
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
                            : "任务处理失败";

                        IsProcessing = false;
                        _currentTaskId = 0;
                        StatusMessage = message ?? "任务处理失败";
                        ClippiCore.ClearProgressCallback();
                        return;
                    }
                }

                if (root.TryGetProperty("speed", out var speed) && speed.ValueKind == JsonValueKind.String)
                {
                    var speedText = speed.GetString();
                    if (!string.IsNullOrWhiteSpace(speedText))
                        StatusMessage = $"处理中... 速度: {speedText}";
                }

                if (Progress >= 100)
                {
                    IsProcessing = false;
                    _currentTaskId = 0;
                    StatusMessage = "处理完成";
                    ClippiCore.ClearProgressCallback();
                }
            }
            catch (Exception ex)
            {
                StatusMessage = $"进度解析失败: {ex.Message}";
            }
        }

        protected void OnPropertyChanged([CallerMemberName] string? propertyName = null)
        {
            PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(propertyName));
        }
    }
}
