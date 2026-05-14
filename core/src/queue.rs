use anyhow::Result;
use crate::types::{TaskConfig, QueueHandle, ProgressFn};
use crate::task::run_task;

/// Queue multiple tasks for serial execution
pub fn queue_tasks(tasks: Vec<TaskConfig>, callback: ProgressFn) -> Result<QueueHandle> {
    let mut task_ids = Vec::new();

    for task_config in tasks {
        let handle = run_task(task_config, callback.clone())?;
        task_ids.push(handle.id);
    }

    Ok(QueueHandle { task_ids })
}
