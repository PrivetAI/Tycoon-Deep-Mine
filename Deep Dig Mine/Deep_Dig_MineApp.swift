import SwiftUI

@main
struct DeepDigMineApp: App {
    @State private var deepDigLinkReady: Bool? = nil
    @StateObject private var store = DDMStore()

    private let deepDigSourceLink = "https://example.com"
    private let deepDigCheckDomain = "example"

    var body: some Scene {
        WindowGroup {
            Group {
                if let ready = deepDigLinkReady {
                    if ready {
                        DeepDigWebPanel(deepDigURLString: deepDigSourceLink)
                            .edgesIgnoringSafeArea(.all)
                    } else {
                        ContentView()
                            .environmentObject(store)
                    }
                } else {
                    DeepDigLoadingScreen()
                        .onAppear { deepDigCheckLink() }
                }
            }
            .preferredColorScheme(.light)
        }
    }

    private func deepDigCheckLink() {
        guard let url = URL(string: deepDigSourceLink) else {
            deepDigLinkReady = false
            return
        }
        var request = URLRequest(url: url)
        request.timeoutInterval = 5
        let tracker = DeepDigRedirectTracker(checkDomain: deepDigCheckDomain)
        let session = URLSession(configuration: .default, delegate: tracker, delegateQueue: nil)
        session.dataTask(with: request) { _, response, error in
            DispatchQueue.main.async {
                if tracker.foundCheckDomain {
                    deepDigLinkReady = false; return
                }
                if let finalURL = tracker.resolvedURL?.absoluteString,
                   finalURL.contains(deepDigCheckDomain) {
                    deepDigLinkReady = false; return
                }
                if let httpResp = response as? HTTPURLResponse,
                   let respURL = httpResp.url?.absoluteString,
                   respURL.contains(deepDigCheckDomain) {
                    deepDigLinkReady = false; return
                }
                if error != nil {
                    deepDigLinkReady = false; return
                }
                deepDigLinkReady = true
            }
        }.resume()
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
            if deepDigLinkReady == nil { deepDigLinkReady = false }
        }
    }
}

final class DeepDigRedirectTracker: NSObject, URLSessionTaskDelegate {
    var resolvedURL: URL?
    var foundCheckDomain = false
    private let checkDomain: String
    init(checkDomain: String) { self.checkDomain = checkDomain }
    func urlSession(_ session: URLSession, task: URLSessionTask,
                    willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest,
                    completionHandler: @escaping (URLRequest?) -> Void) {
        if let url = request.url?.absoluteString, url.contains(checkDomain) {
            foundCheckDomain = true
        }
        resolvedURL = request.url
        completionHandler(request) // never stop the chain
    }
}
