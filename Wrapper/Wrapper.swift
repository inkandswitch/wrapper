import SwiftUI
import WebKit

// Put your mDNS, IP address, or web URL here.
// (Note: You can use a local web server with a self-signed cert, and https as the protocol, to (eg) get more accuracy from performance.now())
let url = URL(string: "http://my-mDNS-name.local:5173")!

@main
struct WrapperApp: App {
  var body: some Scene {
    WindowGroup {
      AppView()
    }
  }
}

struct AppView: View {
  @State private var error: Error?
  @State private var loading = true
  
  var body: some View {
    VStack {
      if let error = error {
        // In the event of an error, show the error message and a handy quit button (so you don't have to force-quit)
        Text(error.localizedDescription)
          .foregroundColor(.pink)
          .font(.headline)
        Button("Quit") { exit(EXIT_FAILURE) }
          .buttonStyle(.bordered)
          .foregroundColor(.primary)
      } else {
        // Load the WebView, and show a spinner while it's loading
        ZStack {
          WrapperWebView(error: $error, loading: $loading)
            .opacity(loading ? 0 : 1) // The WebView is opaque white while loading, which sucks in dark mode
          if loading {
            VStack(spacing: 20) {
              Text("Attempting to load \(url)")
                .foregroundColor(.gray)
                .font(.headline)
              ProgressView()
            }
          }
        }
      }
    }
    .ignoresSafeArea() // Allow views to stretch right to the edges
    .statusBarHidden() // Hide the status bar at the top
    .persistentSystemOverlays(.hidden) // Hide the home indicator at the bottom
    .defersSystemGestures(on:.all) // Block the first swipe from the top (todo: doesn't seem to block the bottom)
                                   // We also have fullScreenRequired set in the Project settings, so we're opted-out from multitasking
  }
}

// This struct wraps WKWebView so that we can use it in SwiftUI.
// Hopefully it won't be long before this can all be removed.
struct WrapperWebView: UIViewRepresentable {
  let webView = WKWebView()
  @Binding var error: Error?
  @Binding var loading: Bool
  
  func makeUIView(context: Context) -> WKWebView {
    webView.isInspectable = true
    webView.navigationDelegate = context.coordinator
    webView.addGestureRecognizer(TouchesToJS(webView))
    loadRequest(webView: webView, cachePolicy: .reloadIgnoringLocalAndRemoteCacheData)
    return webView
  }
  
  private func loadRequest(webView: WKWebView, cachePolicy: URLRequest.CachePolicy) {
    webView.load(URLRequest(url: url, cachePolicy: cachePolicy))
  }
  
  func orient(_ orientation:Int) {
    webView.evaluateJavaScript("if ('orient' in window) orient(\(orientation))", completionHandler: nil)
  }
  
  // Required by UIViewRepresentable
  func updateUIView(_ uiView: WKWebView, context: Context) {}
  
  // To make use of various WKWebView delegates, we need a real class
  func makeCoordinator() -> WebViewCoordinator { WebViewCoordinator(self) }
  class WebViewCoordinator: NSObject, WKNavigationDelegate {
    let parent: WrapperWebView
    var triedOffline = false
    init(_ webView: WrapperWebView) { self.parent = webView }
    func webView(_ wv: WKWebView, didFinish nav: WKNavigation) { parent.loading = false; }
    func webView(_ wv: WKWebView, didFail nav: WKNavigation, withError error: Error) { parent.error = error }
    func webView(_ wv: WKWebView, didFailProvisionalNavigation nav: WKNavigation, withError error: Error) {
      if !triedOffline {
        // The first time provisional navigation fails, try loading from the browser cache.
        // This is useful if you're loading an app from a web server and want that to work even when the iPad is offline.
        triedOffline = true
        parent.loadRequest(webView: wv, cachePolicy: .returnCacheDataDontLoad)
      } else {
        parent.error = error
      }
    }
    // This makes the webview ignore certificate errors, so you can use a self-signed cert for https, so that the browser context is trusted, which enables additional APIs
    func webView(_ wv: WKWebView, respondTo challenge: URLAuthenticationChallenge) async -> (URLSession.AuthChallengeDisposition, URLCredential?) {
      (.useCredential, URLCredential(trust: challenge.protectionSpace.serverTrust!))
    }
  }
}

// This class captures all the touch events triggered on a given WKWebView, and re-triggeres them inside the JS context.
// This allows JS to receive pencil and touch simultaneously.
class TouchesToJS: UIGestureRecognizer {
  let webView: WKWebView
  
  init(_ webView: WKWebView) {
    self.webView = webView
    super.init(target:nil, action:nil)
    requiresExclusiveTouchType = false // Allow simultaneous pen and touch events
  }
  
  typealias TouchJSON = [String: AnyHashable]
  
  private func makeTouchJSON(id: Int, phase: String, touch: UITouch) -> TouchJSON {
    let location = touch.preciseLocation(in: view)
    return [
      "id": id,
      "type": touch.type == .pencil ? "pencil" : "finger",
      "phase": phase,
      "position": [
        "x": location.x,
        "y": location.y,
      ],
      "pressure": touch.force,
      "altitude": touch.altitudeAngle,
      "azimuth": touch.azimuthAngle(in: view),
      "rollAngle": touch.rollAngle,
      "radius": touch.majorRadius,
      "timestamp": touch.timestamp
    ]
  }
  
  func sendTouches(_ phase: String, _ touches: Set<UITouch>, _ event: UIEvent) {
    for touch in touches {
      let id = touch.hashValue // These ids *should be* stable until the touch ends (ie: finger or pencil is lifted)
      let jsonArr = event.coalescedTouches(for: touch)!.map({ makeTouchJSON(id: id, phase: phase, touch: $0) })
      if let json = try? JSONSerialization.data(withJSONObject: jsonArr),
         let jsonString = String(data: json, encoding: .utf8) {
        webView.evaluateJavaScript("if ('wrapperEvents' in window) wrapperEvents(\(jsonString))")
      }
    }
  }
  
  override func touchesBegan    (_ touches: Set<UITouch>, with event: UIEvent) { sendTouches("began", touches, event) }
  override func touchesMoved    (_ touches: Set<UITouch>, with event: UIEvent) { sendTouches("moved", touches, event) }
  override func touchesEnded    (_ touches: Set<UITouch>, with event: UIEvent) { sendTouches("ended", touches, event) }
  override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent) { sendTouches("ended", touches, event) } // "ended" because we don't differentiate between ended and cancelled in the web app
}
