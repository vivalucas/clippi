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
        private int _activeWorkspaceIndex;
        private bool _restoringWorkspace;
        private int _previewGeneration;
        private string? _fallbackPreviewPath;

        public MainWindow()
        {
            this.InitializeComponent();
            ViewModel.PropertyChanged += OnViewModelPropertyChanged;
            CorrectionPlayer.MediaPlayer.MediaFailed += OnCorrectionPreviewFailed;
            AppWindow.Resize(new SizeInt32(1100, 720));
            AppWindow.Changed += OnAppWindowChanged;
            Closed += (_, _) => CleanupFallbackPreview();
        }

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

        private void OnWorkspaceSelectionChanged(object sender, SelectionChangedEventArgs e)
        {
            if (_restoringWorkspace) return;
            if (ViewModel.IsProcessing && WorkspaceTabs.SelectedIndex != _activeWorkspaceIndex)
            {
                _restoringWorkspace = true;
                WorkspaceTabs.SelectedIndex = _activeWorkspaceIndex;
                _restoringWorkspace = false;
                return;
            }
            _activeWorkspaceIndex = WorkspaceTabs.SelectedIndex;
        }

        private void OnAppWindowChanged(AppWindow sender, AppWindowChangedEventArgs args)
        {
            if (!args.DidSizeChange) return;
            var width = Math.Max(sender.Size.Width, 900);
            var height = Math.Max(sender.Size.Height, 620);
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

        private async void OnSelectFileTapped(object sender, TappedRoutedEventArgs e)
        {
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
                var picker = new FolderPicker();
                picker.SuggestedStartLocation = PickerLocationId.VideosLibrary;

                var hwnd = WinRT.Interop.WindowNative.GetWindowHandle(this);
                WinRT.Interop.InitializeWithWindow.Initialize(picker, hwnd);

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
        }

        private void OnViewModelPropertyChanged(object? sender, PropertyChangedEventArgs e)
        {
            if (e.PropertyName == nameof(MainViewModel.IsProcessing))
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

            var controlsEnabled = !ViewModel.IsProcessing;
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
