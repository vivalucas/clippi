use crate::ffi::{TaskState, TASK_REGISTRY};
use crate::task::{execute_task_blocking, next_task_id, prepare_task, validate_config};
use crate::types::{Progress, ProgressFn, QueueHandle, TaskConfig};
use anyhow::Result;

/// Queue multiple tasks for serial execution
pub fn queue_tasks(tasks: Vec<TaskConfig>, callback: ProgressFn) -> Result<QueueHandle> {
    for config in &tasks {
        validate_config(config)?;
    }

    let mut task_ids = Vec::new();
    let mut exec_info = Vec::new();

    {
        let mut registry = TASK_REGISTRY
            .lock()
            .map_err(|_| anyhow::anyhow!("task registry unavailable"))?;
        for config in tasks {
            let id = next_task_id();
            task_ids.push(id);

            let (cancel_tx, cancel_rx) = tokio::sync::oneshot::channel::<()>();
            registry.handles.insert(
                id,
                TaskState {
                    cancel_tx: Some(cancel_tx),
                },
            );
            exec_info.push((id, config, cancel_rx));
        }
    }

    let spawned = std::thread::Builder::new()
        .name("clippi-queue".to_string())
        .spawn(move || {
            for (id, config, mut cancel_rx) in exec_info {
                if cancel_rx.try_recv().is_ok() {
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

                match prepare_task(&config) {
                    Ok((args, duration)) => {
                        if cancel_rx.try_recv().is_ok() {
                            callback(Progress {
                                task_id: Some(id),
                                percent: 0.0,
                                speed: String::new(),
                                eta_secs: None,
                                state: "cancelled".to_string(),
                                message: Some("Task cancelled while preparing".to_string()),
                            });
                            continue;
                        }
                        let _ =
                            execute_task_blocking(id, args, duration, cancel_rx, callback.clone());
                    }
                    Err(error) => callback(Progress {
                        task_id: Some(id),
                        percent: 0.0,
                        speed: String::new(),
                        eta_secs: None,
                        state: "failed".to_string(),
                        message: Some(error.to_string()),
                    }),
                }
            }
        });

    if let Err(error) = spawned {
        if let Ok(mut registry) = TASK_REGISTRY.lock() {
            for id in &task_ids {
                registry.handles.remove(id);
            }
        }
        return Err(error.into());
    }

    Ok(QueueHandle { task_ids })
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::types::Operation;
    use std::sync::Arc;

    #[test]
    fn rejects_invalid_queue_before_registering_tasks() {
        let task = TaskConfig {
            input_path: String::new(),
            output_path: "output.mp4".to_string(),
            operation: Operation::Transform {
                rotation_degrees: 90,
                flip_horizontal: false,
                flip_vertical: false,
            },
            video_codec: Some("libx264".to_string()),
            audio_codec: Some("aac".to_string()),
            hw_accel: None,
        };
        let callback: ProgressFn = Arc::new(|_| {});

        assert!(queue_tasks(vec![task], callback).is_err());
    }
}
