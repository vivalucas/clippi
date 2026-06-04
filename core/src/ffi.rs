//! C FFI interface for Swift/C# to call Rust core library

use std::ffi::{CStr, CString};
use std::os::raw::c_char;
use std::ptr;
use std::collections::HashMap;
use std::sync::{Arc, LazyLock, Mutex};
use serde_json;

use crate::types::*;
use crate::probe::probe_file;
use crate::gpu::detect_gpu;
use crate::task;
use crate::queue;

struct TaskState {
    cancel_tx: Option<tokio::sync::oneshot::Sender<()>>,
}

#[derive(Default)]
struct TaskRegistry {
    handles: HashMap<u64, TaskState>,
}

static TASK_REGISTRY: LazyLock<Mutex<TaskRegistry>> =
    LazyLock::new(|| Mutex::new(TaskRegistry::default()));

/// Probe file metadata - returns JSON string
/// Caller must free the returned string with `clippi_free_string`
#[no_mangle]
pub extern "C" fn clippi_probe_file(path: *const c_char) -> *mut c_char {
    if path.is_null() {
        return ptr::null_mut();
    }

    let path_str = unsafe { CStr::from_ptr(path) };
    let path_rust = match path_str.to_str() {
        Ok(s) => s,
        Err(_) => return ptr::null_mut(),
    };

    match probe_file(path_rust) {
        Ok(info) => {
            let json = serde_json::to_string(&info).unwrap_or_default();
            CString::new(json).unwrap_or_default().into_raw()
        }
        Err(e) => {
            let error = serde_json::json!({"error": e.to_string()});
            CString::new(error.to_string()).unwrap_or_default().into_raw()
        }
    }
}

/// Detect GPU capability - returns JSON string
/// Caller must free the returned string with `clippi_free_string`
#[no_mangle]
pub extern "C" fn clippi_detect_gpu() -> *mut c_char {
    let capability = detect_gpu();
    let json = serde_json::to_string(&capability).unwrap_or_default();
    CString::new(json).unwrap_or_default().into_raw()
}

/// Run a task - returns task ID or 0 on error
/// config_json: JSON string of TaskConfig
/// callback: function pointer for progress reporting
#[no_mangle]
pub extern "C" fn clippi_run_task(
    config_json: *const c_char,
    callback: extern "C" fn(*const c_char),
) -> u64 {
    if config_json.is_null() {
        return 0;
    }

    let config_str = unsafe { CStr::from_ptr(config_json) };
    let config_rust = match config_str.to_str() {
        Ok(s) => s,
        Err(_) => return 0,
    };

    let config: TaskConfig = match serde_json::from_str(config_rust) {
        Ok(c) => c,
        Err(_) => return 0,
    };

    let id = task::next_task_id();
    let (cancel_tx, cancel_rx) = tokio::sync::oneshot::channel::<()>();

    if let Ok(mut registry) = TASK_REGISTRY.lock() {
        registry.handles.insert(id, TaskState {
            cancel_tx: Some(cancel_tx),
        });
    } else {
        return 0;
    }

    let callback_box: ProgressFn = Arc::new(move |progress| {
        if matches!(progress.state.as_str(), "completed" | "failed" | "cancelled") {
            if let Some(task_id) = progress.task_id {
                if let Ok(mut registry) = TASK_REGISTRY.lock() {
                    registry.handles.remove(&task_id);
                }
            }
        }
        let json = serde_json::to_string(&progress).unwrap_or_default();
        let c_str = CString::new(json).unwrap_or_default();
        callback(c_str.as_ptr());
    });

    match std::thread::Builder::new().spawn(move || {
        match task::prepare_task(&config) {
            Ok((args, duration)) => {
                let _ = task::execute_task_blocking(id, args, duration, cancel_rx, callback_box);
            }
            Err(error) => {
                callback_box(Progress {
                    task_id: Some(id),
                    percent: 0.0,
                    speed: String::new(),
                    eta_secs: None,
                    state: "failed".to_string(),
                    message: Some(error.to_string()),
                });
            }
        }
    }) {
        Ok(_) => id,
        Err(_) => {
            if let Ok(mut registry) = TASK_REGISTRY.lock() {
                registry.handles.remove(&id);
            }
            0
        }
    }
}

/// Cancel a running task
/// Returns 1 on success, 0 on failure
#[no_mangle]
pub extern "C" fn clippi_cancel_task(task_id: u64) -> i32 {
    if let Ok(mut registry) = TASK_REGISTRY.lock() {
        if let Some(mut state) = registry.handles.remove(&task_id) {
            if let Some(cancel_tx) = state.cancel_tx.take() {
                let _ = cancel_tx.send(());
                return 1;
            }
        }
    }
    0
}

/// Run tasks in queue - returns JSON array of task IDs
/// Caller must free the returned string with `clippi_free_string`
#[no_mangle]
pub extern "C" fn clippi_queue_tasks(
    tasks_json: *const c_char,
    callback: extern "C" fn(*const c_char),
) -> *mut c_char {
    if tasks_json.is_null() {
        return ptr::null_mut();
    }

    let tasks_str = unsafe { CStr::from_ptr(tasks_json) };
    let tasks_rust = match tasks_str.to_str() {
        Ok(s) => s,
        Err(_) => return ptr::null_mut(),
    };

    let tasks: Vec<TaskConfig> = match serde_json::from_str(tasks_rust) {
        Ok(t) => t,
        Err(_) => return ptr::null_mut(),
    };

    let callback_box: ProgressFn = Arc::new(move |progress| {
        let json = serde_json::to_string(&progress).unwrap_or_default();
        let c_str = CString::new(json).unwrap_or_default();
        callback(c_str.as_ptr());
    });

    match queue::queue_tasks(tasks, callback_box) {
        Ok(handle) => {
            let json = serde_json::to_string(&handle.task_ids).unwrap_or_default();
            CString::new(json).unwrap_or_default().into_raw()
        }
        Err(_) => ptr::null_mut(),
    }
}

/// Free a string allocated by this library
#[no_mangle]
pub extern "C" fn clippi_free_string(s: *mut c_char) {
    if !s.is_null() {
        unsafe {
            let _ = CString::from_raw(s);
        }
    }
}
