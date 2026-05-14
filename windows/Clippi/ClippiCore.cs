using System;
using System.Runtime.InteropServices;
using System.Text.Json;

namespace Clippi
{
    public static class ClippiCore
    {
        private const string DllName = "clippi_core";
        private static Action<string>? _managedProgressCallback;
        private static readonly ProgressCallback _nativeProgressCallback = OnProgress;

        [UnmanagedFunctionPointer(CallingConvention.Cdecl)]
        private delegate void ProgressCallback(IntPtr progressJson);

        [DllImport(DllName, CallingConvention = CallingConvention.Cdecl)]
        private static extern IntPtr clippi_probe_file(string path);

        [DllImport(DllName, CallingConvention = CallingConvention.Cdecl)]
        private static extern IntPtr clippi_detect_gpu();

        [DllImport(DllName, CallingConvention = CallingConvention.Cdecl)]
        private static extern ulong clippi_run_task(string config_json, ProgressCallback callback);

        [DllImport(DllName, CallingConvention = CallingConvention.Cdecl)]
        private static extern int clippi_cancel_task(ulong task_id);

        [DllImport(DllName, CallingConvention = CallingConvention.Cdecl)]
        private static extern IntPtr clippi_queue_tasks(string tasks_json, ProgressCallback callback);

        [DllImport(DllName, CallingConvention = CallingConvention.Cdecl)]
        private static extern void clippi_free_string(IntPtr s);

        /// <summary>
        /// Probe file metadata
        /// </summary>
        public static string? ProbeFile(string path)
        {
            IntPtr result = clippi_probe_file(path);
            if (result == IntPtr.Zero)
                return null;

            string json = Marshal.PtrToStringAnsi(result) ?? "";
            clippi_free_string(result);
            return json;
        }

        /// <summary>
        /// Detect GPU capability
        /// </summary>
        public static string DetectGpu()
        {
            IntPtr result = clippi_detect_gpu();
            string json = Marshal.PtrToStringAnsi(result) ?? "";
            clippi_free_string(result);
            return json;
        }

        /// <summary>
        /// Run a task
        /// </summary>
        public static ulong RunTask(string configJson, Action<string> callback)
        {
            _managedProgressCallback = callback;
            ulong taskId = clippi_run_task(configJson, _nativeProgressCallback);
            if (taskId == 0)
                _managedProgressCallback = null;
            return taskId;
        }

        /// <summary>
        /// Cancel a task
        /// </summary>
        public static bool CancelTask(ulong taskId)
        {
            bool cancelled = clippi_cancel_task(taskId) == 1;
            if (cancelled)
                _managedProgressCallback = null;
            return cancelled;
        }

        /// <summary>
        /// Free unmanaged string
        /// </summary>
        public static void FreeString(IntPtr ptr)
        {
            if (ptr != IntPtr.Zero)
                clippi_free_string(ptr);
        }

        public static void ClearProgressCallback()
        {
            _managedProgressCallback = null;
        }

        private static void OnProgress(IntPtr progressJson)
        {
            if (progressJson == IntPtr.Zero)
                return;

            string json = Marshal.PtrToStringAnsi(progressJson) ?? "";
            _managedProgressCallback?.Invoke(json);
        }
    }
}
