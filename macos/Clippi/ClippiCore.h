// ClippiCore.h
// Swift bridge header for Rust core library

#ifndef ClippiCore_h
#define ClippiCore_h

#include <stdint.h>

// Probe file metadata - returns JSON string (must be freed with clippi_free_string)
char* clippi_probe_file(const char* path);

// Detect GPU capability - returns JSON string (must be freed with clippi_free_string)
char* clippi_detect_gpu(void);

// Run a task - returns task ID or 0 on error
// config_json: JSON string of TaskConfig
// callback: function pointer for progress reporting (receives JSON string)
uint64_t clippi_run_task(const char* config_json, void (*callback)(const char*));

// Cancel a running task - returns 1 on success, 0 on failure
int32_t clippi_cancel_task(uint64_t task_id);

// Run tasks in queue - returns JSON array of task IDs (must be freed with clippi_free_string)
char* clippi_queue_tasks(const char* tasks_json, void (*callback)(const char*));

// Free a string allocated by this library
void clippi_free_string(char* s);

#endif
