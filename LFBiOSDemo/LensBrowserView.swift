import SwiftUI
import WebKit

struct LensBrowserView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> LensBrowserController {
        LensBrowserController(url: url)
    }

    func updateUIViewController(_ controller: LensBrowserController, context: Context) {}
}

final class LensBrowserController: UIViewController, WKUIDelegate, WKScriptMessageHandler {
    private let url: URL
    private var webView: WKWebView?

    init(url: URL) {
        self.url = url
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black

        let content = WKUserContentController()
        content.add(self, name: "log")
        content.addUserScript(WKUserScript(
            source: Self.consoleBridge,
            injectionTime: .atDocumentStart,
            forMainFrameOnly: false
        ))

        let configuration = WKWebViewConfiguration()
        configuration.userContentController = content
        configuration.allowsInlineMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = []

        let webView = WKWebView(frame: view.bounds, configuration: configuration)
        webView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        webView.uiDelegate = self
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        webView.isOpaque = false
        webView.backgroundColor = .black
        if #available(iOS 16.4, *) {
            webView.isInspectable = true
        }
        view.addSubview(webView)
        self.webView = webView
        webView.load(URLRequest(url: url))
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard message.name == "log" else { return }
        print("[lens] \(message.body)")
    }

    func webView(
        _ webView: WKWebView,
        requestMediaCapturePermissionFor origin: WKSecurityOrigin,
        initiatedByFrame frame: WKFrameInfo,
        type: WKMediaCaptureType,
        decisionHandler: @escaping (WKPermissionDecision) -> Void
    ) {
        print("[lens] media capture permission requested for \(origin.host) type \(type.rawValue)")
        decisionHandler(.grant)
    }

    private static let consoleBridge = """
    (function () {
      function send(level, args) {
        try {
          var msg = Array.prototype.map.call(args, function (value) {
            if (typeof value === 'string') return value;
            if (value instanceof Error) return value.message + (value.stack ? '\\n' + value.stack : '');
            try { return JSON.stringify(value); } catch (e) { return String(value); }
          }).join(' ');
          window.webkit.messageHandlers.log.postMessage(level + ' ' + msg);
        } catch (e) {}
      }
      ['log', 'info', 'warn', 'error'].forEach(function (level) {
        var original = console[level];
        console[level] = function () {
          original.apply(console, arguments);
          send(level, arguments);
        };
      });
      window.addEventListener('error', function (event) {
        send('error', [event.message + ' @ ' + event.filename + ':' + event.lineno]);
      });
      window.addEventListener('unhandledrejection', function (event) {
        send('error', ['unhandledrejection ' + String(event.reason)]);
      });
    })();
    """
}
