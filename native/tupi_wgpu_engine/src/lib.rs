pub mod culling;
pub mod pipeline;
pub mod river;
pub mod schema;
pub mod y_sorting;

use std::ffi::CStr;
use std::os::raw::c_char;
use pipeline::TupiIsometricEngine;
use schema::{EpochId, WorldMapDefinition};

/// C-ABI Bridge for Flutter FFI binding.

#[no_mangle]
pub extern "C" fn tupi_engine_create(width: u32, height: u32) -> *mut TupiIsometricEngine {
    let engine = Box::new(TupiIsometricEngine::new(width, height));
    Box::into_raw(engine)
}

#[no_mangle]
pub extern "C" fn tupi_engine_load_map_json(
    engine_ptr: *mut TupiIsometricEngine,
    json_str: *const c_char,
) -> i32 {
    if engine_ptr.is_null() || json_str.is_null() {
        return -1;
    }

    let c_str = unsafe { CStr::from_ptr(json_str) };
    let json_slice = match c_str.to_str() {
        Ok(s) => s,
        Err(_) => return -2,
    };

    let map_def: WorldMapDefinition = match serde_json::from_str(json_slice) {
        Ok(m) => m,
        Err(_) => return -3,
    };

    let engine = unsafe { &mut *engine_ptr };
    engine.set_map_definition(map_def);
    0
}

#[no_mangle]
pub extern "C" fn tupi_engine_set_epoch(
    engine_ptr: *mut TupiIsometricEngine,
    epoch_code: u32,
) -> i32 {
    if engine_ptr.is_null() {
        return -1;
    }

    let epoch = match epoch_code {
        0 => EpochId::Pre1500,
        1 => EpochId::Epoch1532,
        2 => EpochId::Epoch1554,
        3 => EpochId::Epoch1555,
        4 => EpochId::Epoch1567,
        _ => EpochId::Atual,
    };

    let engine = unsafe { &mut *engine_ptr };
    engine.set_epoch(epoch);
    0
}

#[no_mangle]
pub extern "C" fn tupi_engine_resize(
    engine_ptr: *mut TupiIsometricEngine,
    width: u32,
    height: u32,
) -> i32 {
    if engine_ptr.is_null() {
        return -1;
    }
    let engine = unsafe { &mut *engine_ptr };
    engine.resize(width, height);
    0
}

#[no_mangle]
pub extern "C" fn tupi_engine_render_frame(
    engine_ptr: *mut TupiIsometricEngine,
    cam_x: f32,
    cam_y: f32,
    zoom: f32,
) -> i32 {
    if engine_ptr.is_null() {
        return -1;
    }
    let engine = unsafe { &mut *engine_ptr };
    match engine.prepare_frame(cam_x, cam_y, zoom) {
        Some(_) => 0,
        None => -2,
    }
}

#[no_mangle]
pub extern "C" fn tupi_engine_get_texture_id(engine_ptr: *mut TupiIsometricEngine) -> i64 {
    if engine_ptr.is_null() {
        return -1;
    }
    let engine = unsafe { &*engine_ptr };
    engine.texture_id
}

#[no_mangle]
pub extern "C" fn tupi_engine_destroy(engine_ptr: *mut TupiIsometricEngine) {
    if !engine_ptr.is_null() {
        unsafe {
            drop(Box::from_raw(engine_ptr));
        }
    }
}
