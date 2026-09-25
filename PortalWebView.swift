import SwiftUI
import WebKit
import UIKit

/// Shared holder so ContentView menu actions can drive the WKWebView.
final class WebViewHolder: ObservableObject {
    weak var coordinator: PortalWebView.Coordinator?
    var currentURL: URL = PortalLogin.loginURL
}

/// WKWebView wrapper with progress bar, pull-to-refresh, loading/error states,
/// cookie persistence and PDF download interception — port of Android's
/// BrowserActivity WebView setup.
struct PortalWebView: UIViewRepresentable {
    @ObservedObject var holder: WebViewHolder
    @Binding var isLoading: Bool
    @Binding var progress: Double
    @Binding var canGoBack: Bool
    @Binding var pageTitle: String
    @Binding var loadFailed: Bool
    var onPDF: (URL) -> Void
    var onExternalURL: (URL) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .default()
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = true

        let refresh = UIRefreshControl()
        refresh.addTarget(context.coordinator, action: #selector(Coordinator.didRefresh(_:)), for: .valueChanged)
        webView.scrollView.refreshControl = refresh
        context.coordinator.refreshControl = refresh

        webView.addObserver(context.coordinator, forKeyPath: #keyPath(WKWebView.estimatedProgress),
                            options: .new, context: nil)
        webView.addObserver(context.coordinator, forKeyPath: #keyPath(WKWebView.title),
                            options: .new, context: nil)

        context.coordinator.webView = webView
        holder.coordinator = context.coordinator

        webView.load(URLRequest(url: holder.currentURL))
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        context.coordinator.parent = self
        holder.coordinator = context.coordinator
    }

    static func dismantleUIView(_ webView: WKWebView, coordinator: Coordinator) {
        webView.removeObserver(coordinator, forKeyPath: #keyPath(WKWebView.estimatedProgress))
        webView.removeObserver(coordinator, forKeyPath: #keyPath(WKWebView.title))
    }

    class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate {
        var parent: PortalWebView
        weak var refreshControl: UIRefreshControl?
        weak var webView: WKWebView?

        init(_ parent: PortalWebView) { self.parent = parent }

        @objc func didRefresh(_ sender: UIRefreshControl) {
            webView?.reload()
        }

        override func observeValue(forKeyPath keyPath: String?, of object: Any?,
                                   change: [NSKeyValueChangeKey: Any]?, context: UnsafeMutableRawPointer?) {
            guard let webView = object as? WKWebView else { return }
            if keyPath == "estimatedProgress" {
                DispatchQueue.main.async {
                    self.parent.progress = webView.estimatedProgress
                    self.parent.isLoading = webView.estimatedProgress < 1.0
                    if webView.estimatedProgress >= 1.0 { self.parent.loadFailed = false }
                }
            } else if keyPath == "title" {
                DispatchQueue.main.async {
                    self.parent.pageTitle = webView.title ?? ""
                    self.parent.canGoBack = webView.canGoBack
                    if let u = webView.url { self.parent.holder.currentURL = u }
                }
            }
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            DispatchQueue.main.async {
                self.parent.isLoading = false
                self.parent.loadFailed = false
                self.refreshControl?.endRefreshing()
                self.parent.canGoBack = webView.canGoBack
                if let u = webView.url { self.parent.holder.currentURL = u }
                webView.configuration.websiteDataStore.httpCookieStore.getAllCookies { _ in }
            }
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            DispatchQueue.main.async {
                self.parent.isLoading = false
                self.refreshControl?.endRefreshing()
            }
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            DispatchQueue.main.async {
                self.parent.isLoading = false
                self.refreshControl?.endRefreshing()
                // Only show the error screen for real failures, not cancellations
                if (error as NSError).code != NSURLErrorCancelled {
                    self.parent.loadFailed = true
                }
            }
        }

        func webView(_ webView: WKWebView,
                     decidePolicyFor navigationAction: WKNavigationAction,
                     decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            guard let url = navigationAction.request.url else {
                decisionHandler(.allow); return
            }
            if url.pathExtension.lowercased() == "pdf" {
                decisionHandler(.cancel)
                DispatchQueue.main.async { self.parent.onPDF(url) }
                return
            }
            if let host = url.host, host == "iust.ac.in" || host.hasSuffix(".iust.ac.in") {
                decisionHandler(.allow)
            } else if navigationAction.navigationType == .linkActivated {
                decisionHandler(.cancel)
                DispatchQueue.main.async { self.parent.onExternalURL(url) }
            } else {
                decisionHandler(.allow)
            }
        }

        func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration,
                     for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
            if let url = navigationAction.request.url {
                webView.load(URLRequest(url: url))
            }
            return nil
        }

        func evaluate(js: String, completion: @escaping (Any?) -> Void) {
            webView?.evaluateJavaScript(js, completionHandler: { result, _ in completion(result) })
        }

        func load(_ url: URL) {
            parent.holder.currentURL = url
            webView?.load(URLRequest(url: url))
        }

        func reload() { webView?.reload() }
        func goBack() { webView?.goBack() }
    }
}
