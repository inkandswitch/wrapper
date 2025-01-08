We build rapid prototypes using the web platform — typically TypeScript + <canvas>.

But on iPad, in the browser, you can't get simultaneous input from fingers and Apple Pencil. It just doesn't work. But this is exactly what we want for our prototypes: fluid, gestural input from both hands and the pen.

Here's our workaround.

This repo contains the Xcode project for a very simple iPad app. It opens a Webkit view to a URL of your choice, captures all incoming touch and pencil events on the native/Swift side, then forwards them to the JS code running in the Webkit view. Your JS code then uses these events instead of the PointerEvents dispatched by the browser.

The iPad app is minimal. Easy to get up and running for a new prototype. Easy to modify as the needs of the prototype change.

## Setup

#### 1. Build the iPad app

1. Clone this repo to your Mac, and open `Wrapper.xcodeproj` in Xcode.

2. In `Wrapper.swift`, at the top, set the URL of your web app. Typically, you'll use the local IP / mDNS of a live-reloading dev server on your Mac (eg: [vite](https://vite.dev)).

3. Set a [run destination](https://developer.apple.com/documentation/xcode/building-and-running-an-app) (ie: tell Xcode to run your app on your iPad).

You *might* also need to do the following.

4. In Signing & Capabilities, set a [Team and Bundle Identifier](https://developer.apple.com/documentation/xcode/preparing-your-app-for-distribution). The latter should be globally unique.

#### 2. Receive the events in your web app

The iPad app will collect all the input events that occur within a short window of time (say, 1 frame at 120 Hz), then call the function `window.wrapperEvents(...)` with those events. Here's how you'd receive them in your web app:

```javascript
window.wrapperEvents = (events) => {
  for (const event of events) {
    // Do something with this event
  }
}
```

For a more detailed example with a few quality-of-life features, see `example.ts`

## Tips, Issues, Limitations

* The events array passed to `window.wrapperEvents(...)` will interleave pencil and touch events, and (with one exception) all events arrive in the order they occur. The exception is that some events are extrapolated *predictions* of where the pencil might go in the near future. These events will have `event.predicted === true`. In the following batch of events, you will get the real position that the pencil ended up going.
* Once you have the app installed on your iPad, you don't need to run Xcode again. Just make sure your dev server is running (ie: run `vite` or whatever), then launch the app. If something goes wrong, force quit the app (swipe it upward on the app switcher) and try again.
* You can use the Safari developer tools to remotely debug your app while it runs in the browser. This tends to work well for seeing logs, inspecting elements, etc. It does not work very well at all for inspecting JS perf via the timeline. It can also be a bit finicky to get connected — using a cable is not strictly necessary, but it often helps.
* In our informal measurements, we typically see 3–4 frames of motion-to-photon latency using the Wrapper with WebGL. Your mileage may vary.

* The Webkit view is "batteries not included". You can't use stuff like `alert()` / `prompt()`, the clipboard, the `download` attr, etc… unless you implement support for that in Swift.

#### Known Issues
* The iPad Pro refreshes at 120 Hz. As of iOS 18, you can enable a feature flag to allow Safari to run at 120 Hz. But this feature flag doesn't apply to the Webkit view we use — you're stuck at 60 Hz. We don't know of any way to run at 120 Hz in this Wrapper. (If you figure this out, PLEASE tell us!)
* Pencil input is imperfect. While rare, we've sometimes struggled with dropped or sticky inputs, possibly due to false positives/negatives from palm rejection. (If you spot a way to improve this, PLEASE tell us!)

## "Help!!"

We don't offer any warranty or support for this project. But, feel free to ping [Ivan](http://mastodon.social/@spiralganglion) on Mastodon if you have quick questions, or want to share something cool you've made.

Issues and PRs are also welcome, but are likely to be ignored or closed if they add complexity.
