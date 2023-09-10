use std::{rc::Rc, rc::Weak};

use web_sys::{MouseEvent, Touch, TouchEvent};

use crate::{animate::device_pixel_ratio, point::Point};

trait ToClientPosition {
    fn client_position(&self) -> Point<f64>;
}

impl ToClientPosition for Touch {
    fn client_position(&self) -> Point<f64> {
        Point::new(self.client_x() as f64, self.client_y() as f64) / device_pixel_ratio()
    }
}

impl ToClientPosition for MouseEvent {
    fn client_position(&self) -> Point<f64> {
        Point::new(self.client_x() as f64, self.client_y() as f64) / device_pixel_ratio()
    }
}

#[derive(Debug, Clone, Copy)]
pub enum TouchState {
    Began,
    Changed,
    Ended,
    Cancelled,
}

#[readonly::make]
#[derive(Debug, Clone, Copy)]
pub struct EventSender {
    pub state: TouchState,
    pub position: Point<f64>,
    pub translation: Point<f64>,
}

pub trait EventAdapterDelegate {
    fn handle_touch_event(self: Rc<Self>, sender: EventSender);
}

const MOUSE_EVENT_ID: i32 = i32::MIN;

#[derive(Debug, Default)]
pub struct EventAdapter {
    active_touch_id: Option<i32>,
    began_position: Option<Point<f64>>,
    delegate: Option<Weak<dyn EventAdapterDelegate>>,
}

impl EventAdapter {
    pub fn new() -> Self {
        Self::default()
    }

    pub fn set_delegate<T>(&mut self, delegate: &Rc<T>)
    where
        T: EventAdapterDelegate + 'static,
    {
        self.delegate = Some(Rc::downgrade(delegate) as Weak<_>);
    }
}

impl EventAdapter {
    pub fn send_mouse_down(&mut self, event: MouseEvent) {
        if self.active_touch_id.is_some() {
            return;
        }
        self.active_touch_id = Some(MOUSE_EVENT_ID);
        self.began_position = Some(event.client_position());
        self.notify_delegate(event, TouchState::Began);
    }

    pub fn send_mouse_move(&self, event: MouseEvent) {
        let Some(active_touch_id) = self.active_touch_id else {
            return;
        };
        if active_touch_id != MOUSE_EVENT_ID {
            return;
        }
        self.notify_delegate(event, TouchState::Changed);
    }

    pub fn send_mouse_up(&mut self, event: MouseEvent) {
        self.send_mouse_up_or_cancel(event, true)
    }

    pub fn send_mouse_leave(&mut self, event: MouseEvent) {
        self.send_mouse_up_or_cancel(event, false)
    }

    fn send_mouse_up_or_cancel(&mut self, event: MouseEvent, is_up: bool) {
        let Some(active_touch_id) = self.active_touch_id else {
            return;
        };
        if active_touch_id != MOUSE_EVENT_ID {
            return;
        }
        self.notify_delegate(
            event,
            if is_up {
                TouchState::Ended
            } else {
                TouchState::Cancelled
            },
        );
        self.active_touch_id = None;
        self.began_position = None;
    }
}

impl EventAdapter {
    pub fn send_touch_start(&mut self, event: TouchEvent) {
        if self.active_touch_id.is_some() {
            return;
        }
        let Some(touch) = self.get_touch(event) else {
            return;
        };
        self.active_touch_id = Some(touch.identifier());
        self.began_position = Some(touch.client_position());
        self.notify_delegate(touch, TouchState::Began);
    }

    pub fn send_touch_move(&self, event: TouchEvent) {
        let Some(active_touch_id) = self.active_touch_id else {
            return;
        };
        let Some(touch) = self.get_touch(event) else {
            return;
        };
        if touch.identifier() != active_touch_id {
            return;
        }
        self.notify_delegate(touch, TouchState::Changed);
    }

    pub fn send_touch_end(&mut self, event: TouchEvent) {
        self.send_touch_end_or_cancel(event, true)
    }

    pub fn send_touch_cancel(&mut self, event: TouchEvent) {
        self.send_touch_end_or_cancel(event, false)
    }

    fn send_touch_end_or_cancel(&mut self, event: TouchEvent, is_end: bool) {
        let Some(active_touch_id) = self.active_touch_id else {
            return;
        };
        let Some(touch) = self.get_touch(event) else {
            return;
        };
        if touch.identifier() != active_touch_id {
            return;
        }
        self.notify_delegate(
            touch,
            if is_end {
                TouchState::Ended
            } else {
                TouchState::Cancelled
            },
        );
        self.active_touch_id = None;
        self.began_position = None;
    }

    fn get_touch(&self, event: TouchEvent) -> Option<Touch> {
        let touch_list = event.changed_touches();
        if touch_list.length() == 0 {
            return None;
        }
        touch_list.get(0)
    }
}

impl EventAdapter {
    fn notify_delegate<T>(&self, object: T, state: TouchState)
    where
        T: ToClientPosition,
    {
        if let Some(delegate) = &self.delegate {
            if let Some(delegate) = delegate.upgrade() {
                let Some(began_position) = self.began_position else {
                    return;
                };
                let position = object.client_position();
                delegate.handle_touch_event(EventSender {
                    state,
                    position,
                    translation: position - began_position,
                });
            }
        }
    }
}
