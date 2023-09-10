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
