// 👋 Ahoy traveller — the entry point for this code is at the bottom of the file.
// Start reading from there if you want to see what the code does,
// or read from the top down if you want to see what the code is.

// This file contains all the code needed to integrate your web app with the Wrapper iPad app,
// by receiving batches of WrapperEvent objects and forwarding them to your system.
// It also does an automatic fallback to PointerEvents so your web app can run outside the Wrapper, too.
// When running outside the Wrapper, the mouse/stylus is treated as a pencil.
// If you hold down the spacebar the mouse will be treated as a finger.

// A "touch" is a series of events from a single finger or the pencil.
// You use this ID to figure out which finger/pencil an event corresponds to.
// Every time you begin a new touch, it is assigned a new ID.
export type TouchId = number

export type WrapperEventType = "pencil" | "finger"
export type WrapperEventPhase = "hover" | "began" | "moved" | "ended"
export type Position = { x: number,  y: number }

export type WrapperEvent = {
  id: TouchId
  type: WrapperEventType
  phase: WrapperEventPhase
  predicted: boolean
  position: Position
  hoverHeight: number
  pressure: number
  altitude: number
  azimuth: number
  rollAngle: number
  radius: number
  timestamp: number
}

// iOS will synthesize extra events that anticipate where the Pencil will be in the near future.
// Using these predicted events can reduce perceptual latency by ~1 frame, which is fantastic.
// But, when the "real" event(s) arrive in the next batch, it's up to you to clean up any inconsistencies
// introduced by the predictions. That's often complex, and not worthwhile for a quick prototype.
const usePredictedEvents = false

// This state helps us turn PointerEvents into the right sequence of WrapperEvents
let pointerDown = false
let spaceBarDown = false

// Convert a single PointerEvent into a single WrapperEvent
function pointerEvent(e: PointerEvent, phase: WrapperEventPhase) {
  if (phase === "began") pointerDown = true
  if (phase === "ended") pointerDown = false

  if (phase === "moved" && !pointerDown) phase = "hover"

  const type = e.pointerType == "touch" || spaceBarDown ? "finger" : "pencil"

  // Adjust as needed.
  // (The typical range of pressure values for the Apple Pencil is something like 0.5 to 3.5)
  const pressure = e.pointerType == "mouse" ? 1 : e.pressure * 5

  handleWrapperEvents([{
    id: e.pointerId,
    type,
    phase,
    predicted: false,
    position: { x: e.clientX, y: e.clientY },
    hoverHeight: .5,
    pressure,
    altitude: 0,
    azimuth: 0,
    rollAngle: 0,
    radius: 0,
    timestamp: performance.now()
  }])
}

const preventDefault = (e: TouchEvent) => e.preventDefault()

function setupFallbackEventListeners() {
  // Block the "swipe to go back/forward" gesture in Safari
  window.addEventListener("touchstart", preventDefault, { passive: false })

  window.onpointerdown = (e: PointerEvent) => pointerEvent(e, "began")
  window.onpointermove = (e: PointerEvent) => pointerEvent(e, "moved")
  window.onpointerup = (e: PointerEvent) => pointerEvent(e, "ended")

  window.onkeydown = (e: KeyboardEvent) => { if (e.key === " ") spaceBarDown = true }
  window.onkeyup = (e: KeyboardEvent) => { if (e.key === " ") spaceBarDown = false }
}

function clearFallbackEventListeners() {
  window.onpointerdown = null
  window.onpointermove = null
  window.onpointerup = null
  window.removeEventListener("touchstart", preventDefault)
  window.onkeydown = null
  window.onkeyup = null
}

// The first time we receive a call from the Wrapper, we can remove the fallback listeners, since they're redundant.
function handleFirstWrapperEvents(events: WrapperEvent[]) {
  // From now on, the Wrapper should call the function named handleWrapperEvents
  ;(window as any).wrapperEvents = handleWrapperEvents
  clearFallbackEventListeners()
  handleWrapperEvents(events)
}

function handleWrapperEvents(events: WrapperEvent[]) {
  for (const event of events) {
    if (event.predicted && !usePredictedEvents) continue

    // NOW IT'S YOUR TURN!
    // Do something with the event here.
    console.log(event)
  }
}

// 👋 Ahoy traveller — here's where the action begins.

// We add some fallback listeners by default (to support running outside the Wrapper)
// and remove them as soon as we have proof that we are, in fact, inside the Wrapper.
setupFallbackEventListeners()

// The Wrapper calls `window.wrapperEvents(...)`
;(window as any).wrapperEvents = handleFirstWrapperEvents
