import Foundation
import Network

final class LocalWebServer {
    private let root: URL
    private let queue = DispatchQueue(label: "lfb.local-web")
    private var listener: NWListener?

    init(root: URL) {
        self.root = root
    }

    func start() throws -> UInt16 {
        let parameters = NWParameters.tcp
        parameters.allowLocalEndpointReuse = true
        let listener = try NWListener(using: parameters, on: .any)
        listener.newConnectionHandler = { [weak self] connection in
            self?.handle(connection)
        }
        let ready = DispatchSemaphore(value: 0)
        var startError: NWError?
        listener.stateUpdateHandler = { state in
            switch state {
            case .ready:
                ready.signal()
            case .failed(let error):
                startError = error
                ready.signal()
            default:
                break
            }
        }
        listener.start(queue: queue)
        ready.wait()
        if let startError {
            throw startError
        }
        guard let port = listener.port else {
            throw URLError(.cannotConnectToHost)
        }
        self.listener = listener
        return port.rawValue
    }

    func stop() {
        listener?.cancel()
        listener = nil
    }

    private func handle(_ connection: NWConnection) {
        connection.start(queue: queue)
        receive(connection, buffer: Data())
    }

    private func receive(_ connection: NWConnection, buffer: Data) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 64 * 1024) { [weak self] data, _, isComplete, error in
            guard let self else { return }
            var next = buffer
            if let data {
                next.append(data)
            }
            if let headerEnd = next.range(of: Data("\r\n\r\n".utf8)) {
                let header = String(data: next[..<headerEnd.lowerBound], encoding: .utf8) ?? ""
                self.respond(connection, header: header)
                return
            }
            if error != nil || isComplete {
                connection.cancel()
                return
            }
            self.receive(connection, buffer: next)
        }
    }

    private func respond(_ connection: NWConnection, header: String) {
        let requestLine = header.split(separator: "\r\n", maxSplits: 1).first ?? ""
        let parts = requestLine.split(separator: " ")
        let rawPath = parts.count >= 2 ? String(parts[1]) : "/"
        let path = rawPath.split(separator: "?", maxSplits: 1).first.map(String.init) ?? "/"
        let relative = path == "/" ? "index.html" : String(path.dropFirst())
        let fileURL = root.appendingPathComponent(relative)
        let rootPath = root.standardizedFileURL.path.hasSuffix("/")
            ? root.standardizedFileURL.path
            : root.standardizedFileURL.path + "/"
        let filePath = fileURL.standardizedFileURL.path
        guard filePath.hasPrefix(rootPath),
              let body = try? Data(contentsOf: fileURL)
        else {
            send(connection, status: "404 Not Found", type: "text/plain", body: Data("not found".utf8))
            return
        }
        send(connection, status: "200 OK", type: mimeType(for: fileURL), body: body)
    }

    private func send(_ connection: NWConnection, status: String, type: String, body: Data) {
        var header = "HTTP/1.1 \(status)\r\n"
        header += "Content-Type: \(type)\r\n"
        header += "Content-Length: \(body.count)\r\n"
        header += "Connection: close\r\n\r\n"
        var response = Data(header.utf8)
        response.append(body)
        connection.send(content: response, completion: .contentProcessed { _ in
            connection.cancel()
        })
    }

    private func mimeType(for url: URL) -> String {
        switch url.pathExtension.lowercased() {
        case "html": return "text/html; charset=utf-8"
        case "js", "mjs": return "text/javascript; charset=utf-8"
        case "css": return "text/css; charset=utf-8"
        case "wasm": return "application/wasm"
        case "json": return "application/json"
        case "svg": return "image/svg+xml"
        case "png": return "image/png"
        default: return "application/octet-stream"
        }
    }
}
