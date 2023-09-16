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

mod animate;
mod closure;
mod event_adpater;
mod lipsum;
mod list_control;
mod point;

use list_control::ListControl;
use wasm_bindgen::prelude::*;

// Called by our JS entry point to run.
#[wasm_bindgen(start)]
fn run() -> Result<(), JsValue> {
    // Use `web_sys`'s global `window` function to get a handle on the global
    // window object.
    let window = web_sys::window().expect("no global `window` exists");
    let document = window.document().expect("should have a document on window");

    let lipsum = document
        .get_element_by_id("lipsum")
        .expect("no lipsum element");
    lipsum.set_inner_html(
        &lipsum::LIPSUM_CONTENTS
            .repeat(5)
            .into_iter()
            .map(|p| format!("<p>{}</p>", p))
            .collect::<Vec<_>>()
            .join(""),
    );

    let container = document
        .get_element_by_id("container")
        .expect("no container element");
    let _ = ListControl::new(container);

    Ok(())
}
