use std::ffi::{c_char, c_void};

use crate::scroller::*;
use crate::spring_back::*;

#[no_mangle]
pub extern "C" fn fl_scroller_init(scroller_ptr: *mut c_void, deceleration_rate: f32) {
    let scroller = Scroller::new(DecelerationRate(deceleration_rate));
    unsafe {
        std::ptr::write(scroller_ptr as *mut Scroller, scroller);
    }
}

#[no_mangle]
pub extern "C" fn fl_scroller_init_default(scroller_ptr: *mut c_void) {
    fl_scroller_init(scroller_ptr, *DecelerationRate::NORMAL);
}

#[no_mangle]
pub extern "C" fn fl_scroller_set_deceleration_rate(
    scroller_ptr: *mut c_void,
    deceleration_rate: f32,
) {
    let scroller = unsafe { &mut *(scroller_ptr as *mut Scroller) };
    scroller.set_deceleration_rate(DecelerationRate(deceleration_rate));
}

#[no_mangle]
pub extern "C" fn fl_scroller_fling(scroller_ptr: *mut c_void, velocity: f32) {
    let scroller = unsafe { &mut *(scroller_ptr as *mut Scroller) };
    scroller.fling(velocity);
}

#[no_mangle]
pub extern "C" fn fl_scroller_value(
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
pub extern "C" fn fl_scroller_reset(scroller_ptr: *mut c_void) {
    let scroller = unsafe { &mut *(scroller_ptr as *mut Scroller) };
    scroller.reset();
}

#[no_mangle]
pub extern "C" fn fl_spring_back_init(spring_back_ptr: *mut c_void) {
    let spring_back = SpringBack::new();
    unsafe {
        std::ptr::write(spring_back_ptr as *mut SpringBack, spring_back);
    }
}

#[no_mangle]
pub extern "C" fn fl_spring_back_absorb(
    spring_back_ptr: *mut c_void,
    velocity: f32,
    distance: f32,
) {
    let spring_back = unsafe { &mut *(spring_back_ptr as *mut SpringBack) };
    spring_back.absorb(velocity, distance);
}

#[no_mangle]
pub extern "C" fn fl_spring_back_absorb_with_response(
    spring_back_ptr: *mut c_void,
    velocity: f32,
    distance: f32,
    response: f32,
) {
    let spring_back = unsafe { &mut *(spring_back_ptr as *mut SpringBack) };
    spring_back.absorb_with_response(velocity, distance, response);
}

#[no_mangle]
pub extern "C" fn fl_spring_back_value(
    spring_back_ptr: *mut c_void,
    time: f32,
    out_stop: *mut c_char,
) -> f32 {
    let spring_back = unsafe { &mut *(spring_back_ptr as *mut SpringBack) };
    let Some(value) = spring_back.value(time) else {
        unsafe {
            *out_stop = 1;
        }
        return 0.0;
    };
    unsafe {
        *out_stop = 0;
    }
    return value;
}

#[no_mangle]
pub extern "C" fn fl_spring_back_reset(spring_back_ptr: *mut c_void) {
    let spring_back = unsafe { &mut *(spring_back_ptr as *mut SpringBack) };
    spring_back.reset();
}

#[no_mangle]
pub extern "C" fn fl_calculate_rubber_band_offset(offset: f32, range: f32) -> f32 {
    SpringBack::calculate_rubber_band_offset(offset, range)
}
