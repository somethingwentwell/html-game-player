import SwiftUI
import WebKit

@MainActor
final class BrowserModel: NSObject, ObservableObject, WKNavigationDelegate, WKUIDelegate, WKDownloadDelegate {
    @Published var hasPage = false
    @Published var address = ""
    @Published var title = ""
    @Published var isLoading = false
    @Published var canGoBack = false
    @Published var canGoForward = false
    @Published var currentURL: URL?
    @Published var errorMessage: String?
    @Published var isDownloading = false
    var onDownload: ((URL, String, URL?) -> Void)?
    private var observations: [NSKeyValueObservation] = []
    private var downloads: [ObjectIdentifier: (file: URL, filename: String, source: URL?)] = [:]

    lazy var webView: WKWebView = {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .default()
        let view = WKWebView(frame: .zero, configuration: config)
        view.navigationDelegate = self
        view.uiDelegate = self
        view.allowsBackForwardNavigationGestures = true
        view.isOpaque = false
        view.backgroundColor = .clear
        observations = [
            view.observe(\.isLoading, options: [.new]) { [weak self] view, _ in
                Task { @MainActor in self?.update(from: view) }
            },
            view.observe(\.url, options: [.new]) { [weak self] view, _ in
                Task { @MainActor in self?.update(from: view) }
            },
            view.observe(\.title, options: [.new]) { [weak self] view, _ in
                Task { @MainActor in self?.update(from: view) }
            }
        ]
        return view
    }()

    func load(_ text: String) {
        guard let url = WebAddress.resolve(text) else {
            errorMessage = ImportError.invalidURL.localizedDescription; return
        }
        errorMessage = nil
        hasPage = true
        webView.load(URLRequest(url: url))
    }

    func close() {
        webView.stopLoading()
        hasPage = false
        currentURL = nil
        address = ""
        errorMessage = nil
    }

    private func update(from view: WKWebView) {
        isLoading = view.isLoading
        canGoBack = view.canGoBack
        canGoForward = view.canGoForward
        currentURL = view.url
        title = view.title ?? "Web game"
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) { update(from: webView) }
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) { fail(error) }
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) { fail(error) }

    private func fail(_ error: Error) {
        isLoading = false
        if (error as NSError).code != NSURLErrorCancelled { errorMessage = error.localizedDescription }
    }

    func webView(_ webView: WKWebView, decidePolicyFor action: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        guard let scheme = action.request.url?.scheme?.lowercased(), ["https", "http", "about", "blob", "data"].contains(scheme) else {
            decisionHandler(.cancel); return
        }
        if action.shouldPerformDownload { decisionHandler(.download) }
        else { decisionHandler(.allow) }
    }

    func webView(_ webView: WKWebView, decidePolicyFor response: WKNavigationResponse, decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {
        if !response.canShowMIMEType { decisionHandler(.download) }
        else if let http = response.response as? HTTPURLResponse,
                http.value(forHTTPHeaderField: "Content-Disposition")?.lowercased().contains("attachment") == true {
            decisionHandler(.download)
        } else { decisionHandler(.allow) }
    }

    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for action: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        if action.targetFrame == nil { webView.load(action.request) }
        return nil
    }

    func webView(_ webView: WKWebView, navigationAction: WKNavigationAction, didBecome download: WKDownload) {
        download.delegate = self
    }
    func webView(_ webView: WKWebView, navigationResponse: WKNavigationResponse, didBecome download: WKDownload) {
        download.delegate = self
    }

    func download(_ download: WKDownload, decideDestinationUsing response: URLResponse, suggestedFilename: String, completionHandler: @escaping (URL?) -> Void) {
        guard ["html", "htm"].contains((suggestedFilename as NSString).pathExtension.lowercased()), !isDownloading else {
            errorMessage = "Download an HTML game (.html or .htm). ZIP files and app installers aren't supported."
            completionHandler(nil); return
        }
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let file = directory.appendingPathComponent("download.html")
            downloads[ObjectIdentifier(download)] = (file, (suggestedFilename as NSString).lastPathComponent, response.url)
            isDownloading = true
            completionHandler(file)
        } catch { errorMessage = error.localizedDescription; completionHandler(nil) }
    }

    func downloadDidFinish(_ download: WKDownload) {
        guard let item = downloads.removeValue(forKey: ObjectIdentifier(download)) else { return }
        isDownloading = false
        onDownload?(item.file, item.filename, item.source)
    }

    func download(_ download: WKDownload, didFailWithError error: Error, resumeData: Data?) {
        if let item = downloads.removeValue(forKey: ObjectIdentifier(download)) {
            try? FileManager.default.removeItem(at: item.file.deletingLastPathComponent())
        }
        isDownloading = false
        fail(error)
    }
}

struct BrowserWebView: UIViewRepresentable {
    let model: BrowserModel
    func makeUIView(context: Context) -> WKWebView { model.webView }
    func updateUIView(_ uiView: WKWebView, context: Context) {}
}
