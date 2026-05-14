using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using System;
using System.Threading.Tasks;

namespace Clippi
{
    public sealed partial class MainWindow : Window
    {
        public MainWindow()
        {
            this.InitializeComponent();
        }

        private async void StartProcessing_Click(object sender, RoutedEventArgs e)
        {
            // TODO: Implement processing
            var dialog = new ContentDialog
            {
                Title = "处理中",
                Content = "正在处理视频...",
                CloseButtonText = "确定"
            };
            dialog.XamlRoot = this.Content.XamlRoot;
            await dialog.ShowAsync();
        }
    }
}
