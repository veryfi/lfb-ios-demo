import SwiftUI

struct ContentView: View {
    @StateObject private var session = LensSession()

    var body: some View {
        Group {
            if let url = session.pageURL {
                LensBrowserView(url: url)
                    .ignoresSafeArea()
            } else if let message = session.errorMessage {
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black)
        .onAppear {
            session.start()
        }
    }
}

final class LensSession: ObservableObject {
    @Published var errorMessage: String?
    @Published var pageURL: URL?

    private var server: LocalWebServer?

    func start() {
        guard server == nil else { return }
        errorMessage = nil
        do {
            let root = try bundledWebRoot()
            let server = LocalWebServer(root: root)
            let port = try server.start()
            self.server = server
            pageURL = URL(string: "http://127.0.0.1:\(port)/")
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func bundledWebRoot() throws -> URL {
        guard let root = Bundle.main.url(forResource: "index", withExtension: "html", subdirectory: "web")?
            .deletingLastPathComponent()
        else {
            throw LensSessionError.missingBundle
        }
        return root
    }
}

enum LensSessionError: LocalizedError {
    case missingBundle

    var errorDescription: String? {
        switch self {
        case .missingBundle:
            return "Built lens page is missing. Run npm install && npm run build, then rebuild the app."
        }
    }
}
