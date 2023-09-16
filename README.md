# fluid-scroll

## Introduction

The library provides iOS-like scrolling animation algorithm, including scroll inertia and edge bounce.

## Motivation

Scrolling is an extremely important part of touch-based interaction, and almost all of our interactions rely on scrolling. We believe that the scrolling effect of iOS is the best among widely used mobile platforms at present. It is smooth, responsive, and has a good sense of inertia. We hope to bring the scrolling effect of iOS to other platforms.

This library aims to replicate the scrolling effect of `UIScrollView` on iOS as much as possible. It is suitable for implementing scrolling effects in games and other scenarios.

## Preview

https://github.com/ktiays/fluid-scroll/assets/44366293/e92f66aa-15fc-47d8-9a72-b450bfd2a0df

You can find the iOS project used in the screen recording in the `example` directory of the repository. You can also find an example of web implementation by WebAssembly.

## Usage

> [!Note]
> All time units in this library are measured in milliseconds, and speed units are measured in points per millisecond.

### Scroll Inertia

Create a `Scroller` object with the deceleration rate you want.

```rust
use fluid_scroll::Scroller;

let mut scroller = Scroller::new(DecelerationRate::NORMAL);
```

You can modify the deceleration rate at any time through the `set_deceleration_rate` method.

Call the `fling` method when starting to scroll, and provide the initial velocity of the scrolling.

```rust
scroller.fling(3.0);
```

At this point, you are ready to scroll.

You just need to retrieve the distance of movement for each moment from the `scroller` at the frequency you desire.

```rust
// After 16 milliseconds, the expected offset and velocity at this moment.
let scroller_value = scroller.value(16.0);
let offset = scroller_value.offset;
let velocity = scroller_value.velocity;
```

### Edge Bounce

`SpringBack` provides an animation that starts from any position and velocity, and returns to the 0 position.

It can be used to achieve the edge bouncing effect of lists, as well as scrolling animations from the current position to any target position.

```rust
use fluid_scroll::SpringBack;

let mut spring_back = SpringBack::new();
// Starts the animation from position 50 with a velocity of 1 pixel per millisecond.
spring_back.absorb(1.0, 50.0);
```

You can also a custom response value to start the animation.

```rust
spring_back.absorb_with_response(1.0, 50.0, 0.4);
```

You can get the offset of any time through the `SpringBack` object after the animation starts.

```rust
let offset = spring_back.value(16.0);
```

### Rubber Band Offset

A simple function used to map an offset like a rubber band.

It can be used to simulate the damping effect when continuing to pull while reaching the edge of a list.

```rust
use fluid_scroll::rubber_band;

let offset = rubber_band::calculate_offset(200.0, 600.0);
```

### Velocity Tracker

A helper for tracking the velocity of motion events, for implementing flinging and other such gestures.

We have provided two strategies for velocity calculation:

- `Strategy::Lsq2` is the strategy currently being used by Android, and its implementation comes from the Android Open Source Project.

- `Strategy::Recurrence` is a strategy we provide that has an effect more similar to `UIScrollView` in iOS. This is also the default strategy used by our library.

```rust
use fluid_scroll::VelocityTracker;

// Create a velocity tracker object using the default strategy.
let mut velocity_tracker = VelocityTracker::new();
```

You can specify other strategies by the `with_strategy` method.

```rust
let mut velocity_tracker = VelocityTracker::with_strategy(VelocityTrackerStrategy::Lsq2);
```

> [!Note]
> The velocity tracker processes the velocity of one direction. If you need to calculate the 2D velocity that includes both X and Y coordinates, you have to use two instances of velocity tracker.

Then provide the velocity tracker with each sampled point you obtained and its corresponding time.

```rust
velocity_tracker.add_data_point(1.53283_f32, 0_f32);
velocity_tracker.add_data_point(3.27537_f32, 376_f32);

// Obtains the final velocity.
let velocity = velocity_tracker.calculate();
```

## Related Projects

- [FluidRecyclerView](https://github.com/Helixform/FluidRecyclerView): An Android port of this library.

## License

Copyright (c) 2023 ktiays.

Source code and its algorithm are available under the terms of Apache License.
