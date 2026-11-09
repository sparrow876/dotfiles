// Turns mouse-wheel / touchpad scrolling into whole steps: one step per 120
// units (= one wheel notch). Touchpads send many small events; counting each
// one as a step made a short swipe jump the volume 50-100%. Horizontal
// scrolling gives no steps.
//   WheelSteps { id: wheel }
//   onWheel: event => { const n = wheel.steps(event); if (n) doSomething(n) }   // n > 0 = up
import QtQuick

QtObject {
    property real acc: 0
    function steps(event) {
        acc += event.angleDelta.y
        const n = Math.trunc(acc / 120)
        acc -= n * 120
        return n
    }
}
