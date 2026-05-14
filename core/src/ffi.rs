//! C FFI interface for Swift/C# to call Rust core library

use std::ffi::{CStr, CString};
use std::os::raw::c_char;
use std::ptr;
use serde_json;

use crate::types::*;
use crate::probe::probe_file;
use crate::gpu::detect_gpu;

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
            CString::new(json).unwrap().into_raw()
        }
        Err(_) => ptr::null_mut(),
    }
}

/// Detect GPU capability - returns JSON string
/// Caller must free the returned string with `clippi_free_string`
#[no_mangle]
pub extern "C" fn clippi_detect_gpu() -> *mut c_char {
    let capability = detect_gpu();
    let json = serde_json::to_string(&capability).unwrap_or_default();
    CString::new(json).unwrap().into_raw()
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
