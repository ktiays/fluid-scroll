// Copyright (C) 2023 ktiays
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

mod constants;
pub mod rubber_band;
pub mod scroller;
mod spring_back;
mod velocity_tracker;

pub use scroller::Scroller;
pub use spring_back::SpringBack;
pub use velocity_tracker::{Strategy as VelocityTrackerStrategy, VelocityTracker};

#[cfg(feature = "ffi")]
pub mod ffi;
