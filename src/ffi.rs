use std::ffi::{c_char, c_void};

use crate::scroller::*;

#[no_mangle]
pub extern "C" fn sp_scroller_init(scroller_ptr: *mut c_void, deceleration_rate: f32) {
    let scroller = Scroller::new(DecelerationRate(deceleration_rate));
    unsafe {
        std::ptr::write(scroller_ptr as *mut Scroller, scroller);
    }
}

#[no_mangle]
pub extern "C" fn sp_scroller_init_default(scroller_ptr: *mut c_void) {
    sp_scroller_init(scroller_ptr, *DecelerationRate::NORMAL);
}

#[no_mangle]
pub extern "C" fn sp_scroller_set_deceleration_rate(
    scroller_ptr: *mut c_void,
    deceleration_rate: f32,
) {
    let scroller = unsafe { &mut *(scroller_ptr as *mut Scroller) };
    scroller.set_deceleration_rate(DecelerationRate(deceleration_rate));
}

#[no_mangle]
pub extern "C" fn sp_scroller_fling(scroller_ptr: *mut c_void, velocity: f32) {
    let scroller = unsafe { &mut *(scroller_ptr as *mut Scroller) };
    scroller.fling(velocity);
}

#[no_mangle]
pub extern "C" fn sp_scroller_value(
    scroller_ptr: *mut c_void,
    time: f32,
    out_stop: *mut c_char,
) -> ScrollerValue {
    let scroller = unsafe { &mut *(scroller_ptr as *mut Scroller) };
    let Some(value) = scroller.value(time) else {
        unsafe {
            *out_stop = 1;
        }
        return ScrollerValue {
            offset: 0.0,
            velocity: 0.0,
        };
    };
    unsafe {
        *out_stop = 0;
    }
    return value;
}

#[no_mangle]
pub extern "C" fn sp_scroller_reset(scroller_ptr: *mut c_void) {
    let scroller = unsafe { &mut *(scroller_ptr as *mut Scroller) };
    scroller.reset();
}
