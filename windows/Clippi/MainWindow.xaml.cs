using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using Microsoft.UI.Xaml.Input;
using Microsoft.UI.Windowing;
using Microsoft.UI.Xaml.Media.Imaging;
using System;
using System.ComponentModel;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Threading.Tasks;
using Windows.ApplicationModel.DataTransfer;
using Windows.Graphics;
using Windows.Storage;
using Windows.Storage.Pickers;
using Windows.Media.Core;
using Windows.Media.Playback;
using Clippi.ViewModels;

namespace Clippi
{
    public sealed partial class MainWindow : Window
    {
        public MainViewModel ViewModel { get; } = new();
        private readonly DispatcherTimer _previewClock = new() { Interval = TimeSpan.FromMilliseconds(250) };
        private bool _updatingPreviewPosition;
        private int _previewGeneration;
        private string? _sourcePreviewPath;
        private int _previousToolIndex;
        private bool _loadingAppearance;
        private string? _fallbackPreviewPath;

        public MainWindow()
        {
            this.InitializeComponent();
            ViewModel.PropertyChanged += OnViewModelPropertyChanged;
            LoadAppearance();
            var appIcon = Path.Combine(AppContext.BaseDirectory, "Assets", "Clippi.ico");
            if (File.Exists(appIcon)) AppWindow.SetIcon(appIcon);
            // MediaPlayerElement only creates its MediaPlayer lazily, so attach our
            // own up front to keep the failure handler wired before any source loads.
            var player = CorrectionPlayer.MediaPlayer ?? new MediaPlayer();
            if (CorrectionPlayer.MediaPlayer is null) CorrectionPlayer.SetMediaPlayer(player);
            player.MediaFailed += OnCorrectionPreviewFailed;
            _previewClock.Tick += (_, _) => {
                _updatingPreviewPosition = true;
                CorrectionSeek.Value = Math.Clamp(player.PlaybackSession.Position.TotalSeconds, 0, CorrectionSeek.Maximum);
                _updatingPreviewPosition = false;
            };
            _previewClock.Start();
            AppWindow.Resize(new SizeInt32(1200, 820));
            AppWindow.Changed += OnAppWindowChanged;
            Closed += (_, _) => { _previewClock.Stop(); player.Dispose(); SourcePlayer.MediaPlayer?.Dispose(); CleanupFallbackPreview(); };
        }

        public string PlaybackPositionLabel => L10n.Get("PreviewPosition");

        private Visibility ConvertBoolToVisibility(bool value)
        {
            return value ? Visibility.Visible : Visibility.Collapsed;
        }

        private Visibility ConvertInverseBoolToVisibility(bool value)
        {
            return value ? Visibility.Collapsed : Visibility.Visible;
        }

        private FileOpenPicker CreateVideoPicker()
        {
            var picker = new FileOpenPicker { SuggestedStartLocation = PickerLocationId.VideosLibrary };
            foreach (var extension in new[] { ".mp4", ".mkv", ".mov", ".webm", ".avi", ".m4v", ".mts", ".m2ts", ".ts", ".mpg", ".mpeg", ".wmv", ".flv", ".3gp" })
                picker.FileTypeFilter.Add(extension);
            var hwnd = WinRT.Interop.WindowNative.GetWindowHandle(this);
            WinRT.Interop.InitializeWithWindow.Initialize(picker, hwnd);
            return picker;
        }

        private FolderPicker CreateFolderPicker()
        {
            var picker = new FolderPicker { SuggestedStartLocation = PickerLocationId.VideosLibrary };
            picker.FileTypeFilter.Add("*");
            var hwnd = WinRT.Interop.WindowNative.GetWindowHandle(this);
            WinRT.Interop.InitializeWithWindow.Initialize(picker, hwnd);
            return picker;
        }

        private async void OnAddCorrectionFiles(object sender, RoutedEventArgs e)
        {
            try
            {
                var files = await CreateVideoPicker().PickMultipleFilesAsync();
                await ViewModel.ImportCorrectionFilesAsync(files.Select(file => file.Path));
                await ShowImportErrorsIfAny();
            }
            catch (Exception ex) { await ShowDetailsDialog(L10n.Get("CorrectionImportErrorTitle"), ex.Message); }
        }

        private async void OnAddCorrectionFolder(object sender, RoutedEventArgs e)
        {
            try
            {
                var folder = await CreateFolderPicker().PickSingleFolderAsync();
                if (folder != null)
                {
                    await ViewModel.ImportCorrectionFolderAsync(folder.Path);
                    await ShowImportErrorsIfAny();
                }
            }
            catch (Exception ex) { await ShowDetailsDialog(L10n.Get("CorrectionImportErrorTitle"), ex.Message); }
        }

        private async void OnCorrectionDrop(object sender, DragEventArgs e)
        {
            if (!e.DataView.Contains(StandardDataFormats.StorageItems)) return;
            try
            {
                var items = await e.DataView.GetStorageItemsAsync();
                var paths = new List<string>();
                foreach (var item in items)
                {
                    if (item is StorageFile file) paths.Add(file.Path);
                    else if (item is StorageFolder folder)
                    {
                        var files = await folder.GetFilesAsync();
                        paths.AddRange(files.Select(candidate => candidate.Path));
                    }
                }
                await ViewModel.ImportCorrectionFilesAsync(paths);
                await ShowImportErrorsIfAny();
            }
            catch (Exception ex) { await ShowDetailsDialog(L10n.Get("CorrectionImportErrorTitle"), ex.Message); }
        }

        private void OnClearCorrectionMedia(object sender, RoutedEventArgs e) => ViewModel.ClearCorrectionMedia();
        private void OnToggleAllCorrectionItems(object sender, RoutedEventArgs e) => ViewModel.ToggleAllChecked();
        private void OnCorrectionCheckChanged(object sender, RoutedEventArgs e) => ViewModel.RefreshCorrectionCounts();

        private void OnCorrectionSelectionChanged(object sender, SelectionChangedEventArgs e)
        {
            _previewGeneration++;
            CorrectionPlayButton.IsEnabled = ViewModel.SelectedMediaItem != null;
            CorrectionSeek.IsEnabled = ViewModel.SelectedMediaItem != null;
            _updatingPreviewPosition = true;
            CorrectionSeek.Value = 0;
            CorrectionSeek.Maximum = Math.Max(0.01, ViewModel.SelectedMediaItem?.Duration ?? 0);
            _updatingPreviewPosition = false;
            CorrectionPreviewImage.Visibility = Visibility.Collapsed;
            CorrectionPreviewImage.Source = null;
            CorrectionPlayer.Visibility = Visibility.Visible;
            CleanupFallbackPreview();
            if (ViewModel.SelectedMediaItem == null)
            {
                CorrectionPlayer.Source = null;
                return;
            }
            CorrectionPlayer.Source = MediaSource.CreateFromUri(new Uri(ViewModel.SelectedMediaItem.Path));
            UpdateCorrectionPreviewTransform();
        }

        private void OnCorrectionPreviewFailed(MediaPlayer sender, MediaPlayerFailedEventArgs args)
        {
            var item = ViewModel.SelectedMediaItem;
            if (item == null) return;
            if (!string.IsNullOrWhiteSpace(_fallbackPreviewPath)) return;
            var generation = _previewGeneration;
            var path = Path.Combine(Path.GetTempPath(), $"clippi-preview-{Guid.NewGuid():N}.jpg");
            _fallbackPreviewPath = path;
            _ = Task.Run(() => ClippiCore.GeneratePreviewImage(item.Path, path)).ContinueWith(task =>
            {
                DispatcherQueue.TryEnqueue(() =>
                {
                    if (generation != _previewGeneration)
                    {
                        if (File.Exists(path)) File.Delete(path);
                        return;
                    }
                    if (task.Status == TaskStatus.RanToCompletion && task.Result)
                    {
                        _fallbackPreviewPath = path;
                        CorrectionPreviewImage.Source = new BitmapImage(new Uri(path));
                        CorrectionPlayButton.IsEnabled = false;
                        CorrectionSeek.IsEnabled = false;
                        CorrectionPreviewImage.Visibility = Visibility.Visible;
                        CorrectionPlayer.Visibility = Visibility.Collapsed;
                        ResizeCorrectionPlayer();
                    }
                    else
                    {
                        _fallbackPreviewPath = null;
                        ViewModel.StatusMessage = L10n.Get("CorrectionPreviewUnavailable");
                        ViewModel.ErrorDetails = args.ErrorMessage;
                    }
                });
            });
        }

        private void CleanupFallbackPreview()
        {
            if (string.IsNullOrWhiteSpace(_fallbackPreviewPath)) return;
            try { if (File.Exists(_fallbackPreviewPath)) File.Delete(_fallbackPreviewPath); } catch { }
            _fallbackPreviewPath = null;
        }

        private async void OnCorrectionItemDoubleTapped(object sender, DoubleTappedRoutedEventArgs e)
        {
            var item = ViewModel.SelectedMediaItem;
            if (item?.Status != CorrectionMediaStatus.Failed || string.IsNullOrWhiteSpace(item.ErrorDetails)) return;
            await ShowDetailsDialog(L10n.Get("CorrectionStatusFailed"), item.ErrorDetails);
        }

        private async Task ShowImportErrorsIfAny()
        {
            if (!string.IsNullOrWhiteSpace(ViewModel.ErrorDetails))
                await ShowDetailsDialog(L10n.Get("CorrectionImportErrorTitle"), ViewModel.ErrorDetails);
        }

        private async Task ShowDetailsDialog(string title, string details)
        {
            var dialog = new ContentDialog
            {
                XamlRoot = Content.XamlRoot,
                Title = title,
                Content = new ScrollViewer
                {
                    MaxHeight = 360,
                    Content = new TextBlock { Text = details, TextWrapping = TextWrapping.Wrap, IsTextSelectionEnabled = true }
                },
                CloseButtonText = L10n.Get("DialogClose")
            };
            await dialog.ShowAsync();
        }

        private void OnCorrectionPlayPause(object sender, RoutedEventArgs e)
        {
            var player = CorrectionPlayer.MediaPlayer;
            if (player == null || ViewModel.SelectedMediaItem == null) return;
            if (player.PlaybackSession.PlaybackState == MediaPlaybackState.Playing) player.Pause();
            else {
                if (player.PlaybackSession.Position.TotalSeconds >= CorrectionSeek.Maximum - 0.05) player.PlaybackSession.Position = TimeSpan.Zero;
                player.Play();
            }
        }

        private void OnCorrectionSeekChanged(object sender, Microsoft.UI.Xaml.Controls.Primitives.RangeBaseValueChangedEventArgs e)
        {
            if (!_updatingPreviewPosition && CorrectionPlayer?.MediaPlayer is { } player)
                player.PlaybackSession.Position = TimeSpan.FromSeconds(e.NewValue);
        }

        private void OnRotateLeft(object sender, RoutedEventArgs e) { ViewModel.RotateSelected(-90); UpdateCorrectionPreviewTransform(); }
        private void OnRotateRight(object sender, RoutedEventArgs e) { ViewModel.RotateSelected(90); UpdateCorrectionPreviewTransform(); }
        private void OnRotate180(object sender, RoutedEventArgs e) { ViewModel.RotateSelected(180); UpdateCorrectionPreviewTransform(); }
        private void OnFlipHorizontal(object sender, RoutedEventArgs e) { ViewModel.FlipSelected(true); UpdateCorrectionPreviewTransform(); }
        private void OnFlipVertical(object sender, RoutedEventArgs e) { ViewModel.FlipSelected(false); UpdateCorrectionPreviewTransform(); }
        private void OnResetCorrection(object sender, RoutedEventArgs e) { ViewModel.ResetSelectedCorrection(); UpdateCorrectionPreviewTransform(); }

        private void UpdateCorrectionPreviewTransform()
        {
            var item = ViewModel.SelectedMediaItem;
            CorrectionPreviewRotationTransform.Angle = item?.RotationDegrees ?? 0;
            CorrectionPreviewImageRotationTransform.Angle = item?.RotationDegrees ?? 0;
            CorrectionPreviewFlipTransform.ScaleX = item?.FlipHorizontal == true ? -1 : 1;
            CorrectionPreviewFlipTransform.ScaleY = item?.FlipVertical == true ? -1 : 1;
            ResizeCorrectionPlayer();
        }

        private void OnCorrectionPreviewSizeChanged(object sender, SizeChangedEventArgs e) => ResizeCorrectionPlayer();

        private void ResizeCorrectionPlayer()
        {
            var quarterTurn = Math.Abs(CorrectionPreviewRotationTransform.Angle) % 180 == 90;
            if (quarterTurn)
            {
                CorrectionPlayer.Width = CorrectionPreviewHost.ActualHeight;
                CorrectionPlayer.Height = CorrectionPreviewHost.ActualWidth;
                CorrectionPreviewImage.Width = CorrectionPreviewHost.ActualHeight;
                CorrectionPreviewImage.Height = CorrectionPreviewHost.ActualWidth;
            }
            else
            {
                CorrectionPlayer.ClearValue(FrameworkElement.WidthProperty);
                CorrectionPlayer.ClearValue(FrameworkElement.HeightProperty);
                CorrectionPreviewImage.ClearValue(FrameworkElement.WidthProperty);
                CorrectionPreviewImage.ClearValue(FrameworkElement.HeightProperty);
            }
        }

        private void OnSettingsClick(object sender, RoutedEventArgs e)
        {
            if (SettingsButton.IsChecked == true)
            {
                CorrectionPlayer.MediaPlayer?.Pause();
                SourcePlayer.MediaPlayer?.Pause();
                ToolNavigation.SelectedIndex = -1;
                ToolsWorkspace.Visibility = Visibility.Collapsed;
                CorrectionWorkspace.Visibility = Visibility.Collapsed;
                SettingsWorkspace.Visibility = Visibility.Visible;
            }
            else { ToolNavigation.SelectedIndex = _previousToolIndex; }
        }

        private async void OnChooseDefaultOutput(object sender, RoutedEventArgs e)
        {
            try
            {
                var folder = await CreateFolderPicker().PickSingleFolderAsync();
                if (folder != null) { ViewModel.SetDefaultOutputDirectory(folder.Path); SettingsMessage.Text = ""; }
            }
            catch (Exception ex) { SettingsMessage.Text = ex.Message; }
        }

        private void OnRestoreDefaultOutput(object sender, RoutedEventArgs e)
        {
            try { ViewModel.SetDefaultOutputDirectory(""); SettingsMessage.Text = ""; }
            catch (Exception ex) { SettingsMessage.Text = ex.Message; }
        }

        private static string AppearancePath => Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "Clippi", "appearance.txt");

        private void LoadAppearance()
        {
            _loadingAppearance = true;
            string value = "system";
            try { if (File.Exists(AppearancePath)) value = File.ReadAllText(AppearancePath).Trim(); } catch (Exception ex) when (ex is IOException || ex is UnauthorizedAccessException) { }
            AppearancePicker.SelectedIndex = value == "light" ? 1 : value == "dark" ? 2 : 0;
            _loadingAppearance = false;
        }

        private void OnAppearanceChanged(object sender, SelectionChangedEventArgs e)
        {
            if (RootLayout == null || AppearancePicker.SelectedItem is not ComboBoxItem item) return;
            var value = item.Tag?.ToString() ?? "system";
            RootLayout.RequestedTheme = value == "light" ? ElementTheme.Light : value == "dark" ? ElementTheme.Dark : ElementTheme.Default;
            if (_loadingAppearance) return;
            try
            {
                Directory.CreateDirectory(Path.GetDirectoryName(AppearancePath)!);
                File.WriteAllText(AppearancePath, value);
            }
            catch (Exception ex) when (ex is IOException || ex is UnauthorizedAccessException)
            { SettingsMessage.Text = L10n.Get("AppearanceSaveFailed"); }
        }

        private async void OnToolNavigationChanged(object sender, SelectionChangedEventArgs e)
        {
            if (ToolsWorkspace == null || CorrectionWorkspace == null || OperationSelector == null || AudioActionSelector == null) return;
            var index = ToolNavigation.SelectedIndex;
            if (index < 0) return;
            SettingsWorkspace.Visibility = Visibility.Collapsed;
            SettingsButton.IsChecked = false;
            var previous = _previousToolIndex;
            _previousToolIndex = index;
            ToolsWorkspace.Visibility = index == 3 ? Visibility.Collapsed : Visibility.Visible;
            CorrectionWorkspace.Visibility = index == 3 ? Visibility.Visible : Visibility.Collapsed;
            CorrectionPlayer.MediaPlayer?.Pause();
            SourcePlayer.MediaPlayer?.Pause();
            AudioActionSelector.Visibility = index == 4 ? Visibility.Visible : Visibility.Collapsed;
            if (index != 3 && index >= 0)
            {
                var operation = index == 4 ? 3 + AudioActionSelector.SelectedIndex : index;
                if (OperationSelector.SelectedIndex != operation) OperationSelector.SelectedIndex = operation;
                ToolTitle.Text = (ToolNavigation.SelectedItem as ListBoxItem)?.Content?.ToString() ?? "Clippi";
                if (previous == 3 && ViewModel.SelectedMediaItem is { } selected && selected.Path != ViewModel.FilePath)
                {
                    await ViewModel.ProbeFileAsync(selected.Path);
                    UpdateUI();
                }
            }
            else if (index == 3 && previous != 3 && ViewModel.HasFile && ViewModel.Width > 0)
            {
                await ViewModel.ImportCorrectionFilesAsync(new[] { ViewModel.FilePath });
                ViewModel.SelectedMediaItem = ViewModel.MediaItems.FirstOrDefault(item => item.Path == ViewModel.FilePath);
            }
        }

        private void OnAudioActionChanged(object sender, SelectionChangedEventArgs e)
        {
            if (OperationSelector == null || AudioActionSelector == null || ToolNavigation?.SelectedIndex != 4) return;
            OperationSelector.SelectedIndex = 3 + AudioActionSelector.SelectedIndex;
        }

        private async void OnChooseMediaClick(object sender, RoutedEventArgs e) => await ChooseMediaAsync();

        private void OnAppWindowChanged(AppWindow sender, AppWindowChangedEventArgs args)
        {
            if (!args.DidSizeChange) return;
            var width = Math.Max(sender.Size.Width, 1140);
            var height = Math.Max(sender.Size.Height, 740);
            if (width != sender.Size.Width || height != sender.Size.Height)
                sender.Resize(new SizeInt32(width, height));
        }

        private void OnApplyCorrection(object sender, RoutedEventArgs e)
        {
            var scope = (CorrectionScopeBox.SelectedItem as ComboBoxItem)?.Tag?.ToString() ?? "current";
            ViewModel.ApplySelectedCorrection(scope);
        }

        private async void OnChooseCorrectionOutput(object sender, RoutedEventArgs e)
        {
            var folder = await CreateFolderPicker().PickSingleFolderAsync();
            if (folder != null) ViewModel.CorrectionOutputDirectory = folder.Path;
        }

        private async void OnStartCorrection(object sender, RoutedEventArgs e) => await ViewModel.StartCorrectionQueueAsync();
        private void OnStopCorrection(object sender, RoutedEventArgs e) => ViewModel.CancelCorrectionQueue();

        private string FormatResolution(int width, int height)
        {
            return $"{width} x {height}";
        }

        private string FormatDuration(double seconds)
        {
            var ts = TimeSpan.FromSeconds(seconds);
            return $"{ts.Hours:D2}:{ts.Minutes:D2}:{ts.Seconds:D2}";
        }

        private string FormatFrameRate(double fps)
        {
            return $"{fps:F2} fps";
        }

        private async void OnFileDrop(object sender, DragEventArgs e)
        {
            if (ViewModel.IsProcessing) return;
            try
            {
                if (e.DataView.Contains(StandardDataFormats.StorageItems))
                {
                    var items = await e.DataView.GetStorageItemsAsync();
                    if (items.Count > 0 && items[0] is StorageFile file)
                    {
                        await ViewModel.ProbeFileAsync(file.Path);
                        UpdateUI();
                    }
                }
            }
            catch (Exception ex)
            {
                ViewModel.StatusMessage = L10n.Format("ErrorReadFileFailedWithMessage", ex.Message);
            }
        }

        private void OnDragOver(object sender, DragEventArgs e)
        {
            e.AcceptedOperation = DataPackageOperation.Copy;
            e.DragUIOverride.Caption = L10n.Get("DragCaption");
        }

        private async void OnSelectFileTapped(object sender, TappedRoutedEventArgs e) => await ChooseMediaAsync();

        private async Task ChooseMediaAsync()
        {
            if (!ViewModel.IsNotProcessing) return;
            try
            {
                var picker = new FileOpenPicker();
                picker.SuggestedStartLocation = PickerLocationId.VideosLibrary;
                picker.FileTypeFilter.Add(".mp4");
                picker.FileTypeFilter.Add(".mkv");
                picker.FileTypeFilter.Add(".mov");
                picker.FileTypeFilter.Add(".webm");
                picker.FileTypeFilter.Add(".avi");
                picker.FileTypeFilter.Add(".m4v");
                picker.FileTypeFilter.Add(".mp3");
                picker.FileTypeFilter.Add(".wav");
                picker.FileTypeFilter.Add(".aac");
                picker.FileTypeFilter.Add(".m4a");
                picker.FileTypeFilter.Add(".flac");

                // WinUI 3 requires HWND
                var hwnd = WinRT.Interop.WindowNative.GetWindowHandle(this);
                WinRT.Interop.InitializeWithWindow.Initialize(picker, hwnd);

                var file = await picker.PickSingleFileAsync();
                if (file != null)
                {
                    await ViewModel.ProbeFileAsync(file.Path);
                    UpdateUI();
                }
            }
            catch (Exception ex)
            {
                ViewModel.StatusMessage = L10n.Format("ErrorSelectFileFailed", ex.Message);
            }
        }

        private void OnOperationChanged(object sender, SelectionChangedEventArgs e)
        {
            var index = (sender as RadioButtons)?.SelectedIndex ?? 0;
            if (TrimPanel == null || FormatPanel == null || ScalePanel == null || AudioPanel == null || RemoveAudioText == null) return;

            TrimPanel.Visibility = index == 0 ? Visibility.Visible : Visibility.Collapsed;
            FormatPanel.Visibility = index == 1 ? Visibility.Visible : Visibility.Collapsed;
            ScalePanel.Visibility = index == 2 ? Visibility.Visible : Visibility.Collapsed;
            AudioPanel.Visibility = index == 3 ? Visibility.Visible : Visibility.Collapsed;
            RemoveAudioText.Visibility = index == 4 ? Visibility.Visible : Visibility.Collapsed;

            ViewModel.SelectedOperation = index switch
            {
                0 => "trim",
                1 => "convert",
                2 => "scale",
                3 => "extractAudio",
                4 => "removeAudio",
                _ => "trim"
            };
            UpdateOutputPath();
        }

        private void OnFormatChanged(object sender, SelectionChangedEventArgs e)
        {
            var index = (sender as RadioButtons)?.SelectedIndex ?? 0;
            ViewModel.OutputFormat = index switch
            {
                0 => "mp4",
                1 => "mkv",
                2 => "mov",
                3 => "webm",
                _ => "mp4"
            };
            UpdateOutputPath();
        }

        private void OnResolutionChanged(object sender, SelectionChangedEventArgs e)
        {
            var index = (sender as RadioButtons)?.SelectedIndex ?? 1;
            ViewModel.TargetResolution = index switch
            {
                0 => "4K",
                1 => "1080p",
                2 => "720p",
                3 => "480p",
                _ => "1080p"
            };
        }

        private void OnAudioFormatChanged(object sender, SelectionChangedEventArgs e)
        {
            var index = (sender as RadioButtons)?.SelectedIndex ?? 0;
            ViewModel.AudioFormat = index switch
            {
                0 => "mp3",
                1 => "aac",
                2 => "wav",
                _ => "mp3"
            };
            UpdateOutputPath();
        }

        private async void OnSelectOutputPath(object sender, RoutedEventArgs e)
        {
            try
            {
                var picker = CreateFolderPicker();
                var folder = await picker.PickSingleFolderAsync();
                if (folder != null)
                {
                    ViewModel.OutputPath = ViewModel.GenerateOutputPathInDirectory(folder.Path);
                }
            }
            catch (Exception ex)
            {
                ViewModel.StatusMessage = L10n.Format("ErrorSelectPathFailed", ex.Message);
            }
        }

        private void OnStartClick(object sender, RoutedEventArgs e)
        {
            if (ViewModel.StartProcessing())
            {
                UpdateProcessingUI();
            }
        }

        private void OnCancelClick(object sender, RoutedEventArgs e)
        {
            ViewModel.CancelProcessing();
        }

        private void UpdateUI()
        {
            StartButton.Visibility = ViewModel.HasFile ? Visibility.Visible : Visibility.Collapsed;
            StartButton.IsEnabled = ViewModel.IsNotProcessing && string.IsNullOrEmpty(ViewModel.OperationUnavailableReason);
            if (ViewModel.HasFile && _sourcePreviewPath != ViewModel.FilePath)
            {
                _sourcePreviewPath = ViewModel.FilePath;
                SourcePlayer.Source = MediaSource.CreateFromUri(new Uri(ViewModel.FilePath));
            }
        }

        private void OnViewModelPropertyChanged(object? sender, PropertyChangedEventArgs e)
        {
            if (e.PropertyName == nameof(MainViewModel.OperationUnavailableReason))
                StartButton.IsEnabled = ViewModel.IsNotProcessing && ViewModel.HasFile && string.IsNullOrEmpty(ViewModel.OperationUnavailableReason);
            if (e.PropertyName == nameof(MainViewModel.IsProcessing) || e.PropertyName == nameof(MainViewModel.IsProbing))
            {
                UpdateProcessingUI();
                CorrectionStartButton.Visibility = ViewModel.IsProcessing ? Visibility.Collapsed : Visibility.Visible;
                CorrectionStopButton.Visibility = ViewModel.IsProcessing ? Visibility.Visible : Visibility.Collapsed;
            }
        }

        private void UpdateProcessingUI()
        {
            ProgressPanel.Visibility = ViewModel.IsProcessing ? Visibility.Visible : Visibility.Collapsed;
            StartButton.Visibility = !ViewModel.IsProcessing && ViewModel.HasFile
                ? Visibility.Visible
                : Visibility.Collapsed;

            var controlsEnabled = ViewModel.IsNotProcessing;
            StartButton.IsEnabled = controlsEnabled && ViewModel.HasFile && string.IsNullOrEmpty(ViewModel.OperationUnavailableReason);
            AudioActionSelector.IsEnabled = controlsEnabled;
            OperationSelector.IsEnabled = controlsEnabled;
            SetPanelEnabled(TrimPanel, controlsEnabled);
            SetPanelEnabled(FormatPanel, controlsEnabled);
            SetPanelEnabled(ScalePanel, controlsEnabled);
            SetPanelEnabled(AudioPanel, controlsEnabled);
            OutputPathBox.IsEnabled = controlsEnabled;
            ChooseOutputButton.IsEnabled = controlsEnabled;
        }

        private static void SetPanelEnabled(FrameworkElement element, bool enabled)
        {
            element.IsHitTestVisible = enabled;
            element.Opacity = enabled ? 1.0 : 0.55;
        }

        private void UpdateOutputPath()
        {
            ViewModel.RefreshOutputPath();
        }

        private void OnCopyErrorDetailsClick(object sender, RoutedEventArgs e)
        {
            ViewModel.CopyErrorDetailsToClipboard();
        }
    }
}
