use anyhow::Result;
use crate::types::{TaskConfig, QueueHandle, ProgressFn};
use crate::task::{execute_task_blocking, next_task_id, prepare_task};

/// Queue multiple tasks for serial execution
pub fn queue_tasks(tasks: Vec<TaskConfig>, callback: ProgressFn) -> Result<QueueHandle> {
    let mut prepared_tasks = Vec::new();

    for config in tasks {
        let id = next_task_id();
        let (args, duration) = prepare_task(&config)?;
        prepared_tasks.push((id, args, duration));
    }

    let task_ids = prepared_tasks.iter().map(|(id, _, _)| *id).collect();

    std::thread::spawn(move || {
        for (id, args, duration) in prepared_tasks {
            let (_cancel_tx, cancel_rx) = tokio::sync::oneshot::channel::<()>();
            if execute_task_blocking(id, args, duration, cancel_rx, callback.clone()).is_err() {
                continue;
            }
        }
    });

    Ok(QueueHandle { task_ids })
}
