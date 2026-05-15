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
        private static extern IntPtr clippi_probe_file(IntPtr path);

        [DllImport(DllName, CallingConvention = CallingConvention.Cdecl)]
        private static extern IntPtr clippi_detect_gpu();

        [DllImport(DllName, CallingConvention = CallingConvention.Cdecl)]
        private static extern ulong clippi_run_task(IntPtr config_json, ProgressCallback callback);

        [DllImport(DllName, CallingConvention = CallingConvention.Cdecl)]
        private static extern int clippi_cancel_task(ulong task_id);

        [DllImport(DllName, CallingConvention = CallingConvention.Cdecl)]
        private static extern IntPtr clippi_queue_tasks(IntPtr tasks_json, ProgressCallback callback);

        [DllImport(DllName, CallingConvention = CallingConvention.Cdecl)]
        private static extern void clippi_free_string(IntPtr s);

        /// <summary>
        /// Probe file metadata
        /// </summary>
        public static string? ProbeFile(string path)
        {
            IntPtr pathPtr = Marshal.StringToCoTaskMemUTF8(path);
            IntPtr result = IntPtr.Zero;

            try
            {
                result = clippi_probe_file(pathPtr);
                if (result == IntPtr.Zero)
                    return null;

                return Marshal.PtrToStringUTF8(result) ?? "";
            }
            finally
            {
                Marshal.FreeCoTaskMem(pathPtr);
                if (result != IntPtr.Zero)
                    clippi_free_string(result);
            }
        }

        /// <summary>
        /// Detect GPU capability
        /// </summary>
        public static string DetectGpu()
        {
            IntPtr result = clippi_detect_gpu();
            string json = Marshal.PtrToStringUTF8(result) ?? "";
            clippi_free_string(result);
            return json;
        }

        /// <summary>
        /// Run a task
        /// </summary>
        public static ulong RunTask(string configJson, Action<string> callback)
        {
            IntPtr configPtr = Marshal.StringToCoTaskMemUTF8(configJson);
            _managedProgressCallback = callback;
            try
            {
                ulong taskId = clippi_run_task(configPtr, _nativeProgressCallback);
                if (taskId == 0)
                    _managedProgressCallback = null;
                return taskId;
            }
            finally
            {
                Marshal.FreeCoTaskMem(configPtr);
            }
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

            string json = Marshal.PtrToStringUTF8(progressJson) ?? "";
            _managedProgressCallback?.Invoke(json);
        }
    }
}
