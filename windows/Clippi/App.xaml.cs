using Microsoft.UI.Xaml;
using System;
using System.IO;

namespace Clippi
{
    public partial class App : Application
    {
        private Window? m_window;

        private static readonly string LogPath =
            Path.Combine(Path.GetTempPath(), "clippi-startup.log");

        private static void Log(string message)
        {
            try { File.AppendAllText(LogPath, $"{DateTime.Now:O} {message}\n"); }
            catch { /* diagnostics must never take the app down */ }
        }

        public App()
        {
            Log("App ctor start");
            try
            {
                this.InitializeComponent();
            }
            catch (Exception ex)
            {
                Log($"App InitializeComponent failed: {ex}");
                throw;
            }
            UnhandledException += (_, e) => Log($"Unhandled XAML exception: {e.Exception}");
            AppDomain.CurrentDomain.UnhandledException += (_, e) =>
                Log($"AppDomain unhandled exception: {e.ExceptionObject}");
            Log("App ctor done");
        }

        protected override void OnLaunched(LaunchActivatedEventArgs args)
        {
            Log("OnLaunched start");
            try
            {
                m_window = new MainWindow();
                m_window.Activate();
                Log("OnLaunched done");
            }
            catch (Exception ex)
            {
                Log($"OnLaunched failed: {ex}");
                throw;
            }
        }
    }
}
