using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using Microsoft.UI.Xaml.Input;
using System;
using System.ComponentModel;
using System.Threading.Tasks;
using Windows.ApplicationModel.DataTransfer;
using Windows.Graphics;
using Windows.Storage;
using Windows.Storage.Pickers;
using Clippi.ViewModels;

namespace Clippi
{
    public sealed partial class MainWindow : Window
    {
        public MainViewModel ViewModel { get; } = new();

        public MainWindow()
        {
            this.InitializeComponent();
            ViewModel.PropertyChanged += OnViewModelPropertyChanged;
            AppWindow.Resize(new SizeInt32(700, 600));
        }

        private Visibility ConvertBoolToVisibility(bool value)
        {
            return value ? Visibility.Visible : Visibility.Collapsed;
        }

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
