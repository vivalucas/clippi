using System;
using System.Runtime.InteropServices;
using System.Text.Json;

namespace Clippi
{
    public static class ClippiCore
    {
        private const string DllName = "clippi_core";
        private static readonly object _callbackLock = new object();
        private static readonly System.Collections.Generic.Dictionary<ulong, Action<string>> _callbacks = new();
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
            if (result == IntPtr.Zero)
                return "{}";

            string json = Marshal.PtrToStringUTF8(result) ?? "{}";
            clippi_free_string(result);
            return json;
        }

        /// <summary>
        /// Run a task
        /// </summary>
        public static ulong RunTask(string configJson, Action<string> callback)
        {
            IntPtr configPtr = Marshal.StringToCoTaskMemUTF8(configJson);
            try
            {
                lock (_callbackLock)
                {
                    ulong taskId = clippi_run_task(configPtr, _nativeProgressCallback);
                    if (taskId > 0)
                        _callbacks[taskId] = callback;
                    return taskId;
                }
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
            {
                lock (_callbackLock)
                {
                    _callbacks.Remove(taskId);
                }
            }
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
        }

        private static void OnProgress(IntPtr progressJson)
        {
            if (progressJson == IntPtr.Zero)
                return;

            string json = Marshal.PtrToStringUTF8(progressJson) ?? "";
            ulong? taskId = null;
            try
            {
                using var doc = JsonDocument.Parse(json);
                if (doc.RootElement.TryGetProperty("task_id", out var taskIdElement) && taskIdElement.ValueKind == JsonValueKind.Number)
                {
                    taskId = taskIdElement.GetUInt64();
                }
            }
            catch { }

            Action<string>? callback = null;
            if (taskId.HasValue)
            {
                lock (_callbackLock)
                {
                    if (_callbacks.TryGetValue(taskId.Value, out var cb))
                    {
                        callback = cb;
                        if (json.Contains("\"state\":\"completed\"") || json.Contains("\"state\":\"failed\"") || json.Contains("\"state\":\"cancelled\""))
                        {
                            _callbacks.Remove(taskId.Value);
                        }
                    }
                }
            }

            callback?.Invoke(json);
        }
    }
}
