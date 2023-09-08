use wasm_bindgen::prelude::*;

// Called by our JS entry point to run.
#[wasm_bindgen(start)]
fn run() -> Result<(), JsValue> {
    // Use `web_sys`'s global `window` function to get a handle on the global
    // window object.
    let window = web_sys::window().expect("no global `window` exists");
    let document = window.document().expect("should have a document on window");
    let container = document.get_element_by_id("app").expect("no app element");
    container.set_text_content(Some("Hello from Rust!!!"));

    Ok(())
}
