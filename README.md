At Ink & Switch, one of the things we're researching is a new kind of [dynamic notebook](https://www.inkandswitch.com/inkbase) — something like a pad of paper with a pen, but programmable. As part of this research we build a lot of little prototypes, using the web platform as a substrate for rapid iteration. We run these prototypes on iPad because the form factor (tablet + stylus) is very close to what we have in mind for our dynamic notebook.

On iPad, however, you can't get simultaneous input from fingers and Apple Pencil in the browser. It just doesn't work. But this is exactly what we need for our prototypes: fluid, gestural input from both hands and the pen.

Here's our workaround.

This repo contains the Xcode project for a very simple iPad app. It opens a URL of your choice in a fullscreen Webkit view, captures all incoming touch and pencil events on the native/Swift side, then forwards them to your JS code. Your JS code then uses these events instead of the PointerEvents dispatched by the browser.

This project exists to support rapid experimental prototyping. It's deliberately "batteries not included". You should rip it apart, [kitbashing](https://en.wikipedia.org/wiki/Kitbashing) whatever you need to quickly test your ideas.

## Setup

### 1. Build the iPad app

1. Clone this repo to your Mac, and open `Wrapper.xcodeproj` in Xcode.

2. In [`Wrapper.swift`](/Wrapper/Wrapper.swift), at the top, set the URL of your web app. Typically, you'll use the local IP / mDNS of a live-reloading dev server on your Mac (eg: [vite](https://vite.dev)).

3. Set a [run destination](https://developer.apple.com/documentation/xcode/building-and-running-an-app) (ie: tell Xcode to run your app on your iPad).

You *might* also need to do the following.

4. In Signing & Capabilities, set a [Team and Bundle Identifier](https://developer.apple.com/documentation/xcode/preparing-your-app-for-distribution). The latter should be globally unique.

Finally, do a `Build & Run` and if everything goes well, the app should launch on your iPad, and you'll see whatever is being served at the URL you entered.

### 2. Receive the pencil & touch events in your web app

The iPad Pro emits finger events at 120 Hz and pencil events at 240 Hz. The app will batch-up all the input events that occur within a short window of time (say, 1 frame at 120 Hz), then call the function `window.wrapperEvents(...)` with each batch of events. Here's how you'd receive them in your web app:

```javascript
window.wrapperEvents = (events) => {
  for (const event of events) {
    // Do something with this event
  }
}
```

For a more detailed example with a few quality-of-life features, see [`example.ts`](/example.ts)

### 3. Submit to TestFlight

After you've built something, you might want to share it with other folks so they can test it. Here are the steps for setting up a private TestFlight.

Prerequisites:
* A paid Apple developer team account that you are willing to share with your testers.
* You must have the Admin or App Manager role on this Apple developer team.
* The email address for the Apple IDs for each of your testers, so you can add them to your team.

Steps:
1. Put a build of your web app somewhere on the internet — Surge, Netlify, Vercel, S3, doesn't matter.
2. In Xcode, change [`Wrapper.swift`](/Wrapper/Wrapper.swift) to load this URL.
3. Choose `Product > Archive`. This will build your project, then open the Organizer window.
4. Click "Validate App". Xcode may prompt you to fill in some basic info for the App Store.
5. If Validation fails, go fix whatever issues it surfaces.
  * The most common issue is that your bundle identifier isn't unique. Change it to something unique. (Note that you actually have to click somewhere outside the bundle identifier field for it to save the new value.) Then go back to step 3.
6. Once Validation succeeds, click "Distribute App". The default method ("App Store Connect") is fine.
7. When the upload finishes, click the link to open your app in App Store Connect. At the top, click the big TestFlight link.
8. You should see a list of versions and a single build, and it should say "Missing Compliance". Click "Manage", and choose "None of the above".
9. Open [Users and Access](https://appstoreconnect.apple.com/access/users) in a new tab, and create a New User for each of your testers. Give them the Developer role.
10. Go back to your app in TestFlight. In the left sidebar look for "Internal Testing", then click the blue (+) icon to create a group of users to test the app. Give your group a name.
11. You'll be presented with a list of users on your team. Select your testers.

That should be all it takes. As soon as people are added to the group, they'll get an invite email.

In our experience, this process is cumbersome and error-prone. Just give it your best shot. If something doesn't work, wait a few days and try again.

## Usage Notes

### Tips
* Once you have the app installed on your iPad, you don't need to run Xcode again. Just make sure your dev server is running (ie: run `vite` or whatever), then launch the app. If something goes wrong, force quit the app (swipe it upward on the app switcher) and try again.
* The events array passed to `window.wrapperEvents(...)` will interleave pencil and touch events, and (with one exception) all events arrive in the order they occur.
  * The exception is that some events are extrapolated *predictions* of where the pencil might go in the near future. These events will have `event.predicted === true`. In the following batch of events, you will get the real position that the pencil ended up going.
* The events come in *fast*. It's a good idea to merge events together, and only act on the most current data for each touch.
* You can use the Safari developer tools on your Mac to remotely debug your web app as it runs in the Wrapper. This tends to work well for seeing logs, inspecting elements, etc. It doesn't work very well for inspecting JS perf via the timeline. It can also be a bit finicky to get connected — using a cable is not strictly necessary, but it often helps.

### Limitations
* You can't use stuff like `alert()` / `prompt()`, the clipboard, the `download` attr, etc… unless you implement support for that in Swift.
* The iPad Pro screen refreshes at 120 Hz. As of iOS 18, you can enable a feature flag to run `requestAnimationFrame` at 120 Hz in Safari. But this feature flag doesn't apply to the Webkit view we use, so it's capped at 60 Hz. We don't know of any way to run at 120 Hz in WKWebView — if you figure this out, PLEASE tell us!
* Pencil input is imperfect. While rare, we've sometimes struggled with dropped or sticky inputs, possibly due to false positives/negatives from palm rejection. (If you spot a way to improve this, PLEASE tell us!)
* In our informal measurements, we typically see 3–4 frames (50ms–70ms) of motion-to-photon latency when using the Wrapper. This is about on par with PointerEvents generated by the browser, maybe slightly worse. Your mileage may vary.

### "Help!!"

We don't offer any warranty or support for this project. But, feel free to ping [Ivan](http://mastodon.social/@spiralganglion) on Mastodon if you have quick questions, or want to share something cool you've made.

Issues and PRs are also welcome, but are likely to be ignored or closed if they add complexity.
