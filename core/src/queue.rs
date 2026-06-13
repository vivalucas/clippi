use crate::ffi::{TaskState, TASK_REGISTRY};
use crate::task::{execute_task_blocking, next_task_id, prepare_task};
use crate::types::{Progress, ProgressFn, QueueHandle, TaskConfig};
use anyhow::Result;

/// Queue multiple tasks for serial execution
pub fn queue_tasks(tasks: Vec<TaskConfig>, callback: ProgressFn) -> Result<QueueHandle> {
    let mut task_ids = Vec::new();
    let mut exec_info = Vec::new();

    for config in tasks {
        let id = next_task_id();
        let (args, duration) = prepare_task(&config)?;
        task_ids.push(id);
        
        let (cancel_tx, cancel_rx) = tokio::sync::oneshot::channel::<()>();
        if let Ok(mut registry) = TASK_REGISTRY.lock() {
            registry.handles.insert(id, TaskState { cancel_tx: Some(cancel_tx) });
        }
        exec_info.push((id, args, duration, cancel_rx));
    }

    std::thread::spawn(move || {
        for (id, args, duration, mut cancel_rx) in exec_info {
            if cancel_rx.try_recv().is_ok() {
                if let Ok(mut registry) = TASK_REGISTRY.lock() {
                    registry.handles.remove(&id);
                }
                callback(Progress {
                    task_id: Some(id),
                    percent: 0.0,
                    speed: String::new(),
                    eta_secs: None,
                    state: "cancelled".to_string(),
                    message: Some("Task cancelled in queue".to_string()),
                });
                continue;
            }

            let _ = execute_task_blocking(id, args, duration, cancel_rx, callback.clone());
        }
    });

    Ok(QueueHandle { task_ids })
}
