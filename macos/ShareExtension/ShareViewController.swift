import AppKit
import UniformTypeIdentifiers

/// Finder "Share" menu entry. The extension has no UI of its own: it passes
/// the shared files to the main app, which shows the device picker.
final class ShareViewController: NSViewController {
    override var nibName: NSNib.Name? { nil }

    override func loadView() {
        view = NSView(frame: .zero)
        preferredContentSize = .zero
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        // Finder may describe folders only as directories, not as file URLs
        let types = [UTType.fileURL.identifier, UTType.directory.identifier]
        let attachments = (extensionContext?.inputItems as? [NSExtensionItem] ?? [])
            .flatMap { $0.attachments ?? [] }
        let providers = attachments.compactMap { provider -> (NSItemProvider, String)? in
            guard let type = types.first(where: { provider.hasItemConformingToTypeIdentifier($0) }) else {
                return nil
            }
            return (provider, type)
        }

        let group = DispatchGroup()
        let lock = NSLock()
        var paths: [String] = []

        for (provider, type) in providers {
            group.enter()
            provider.loadItem(forTypeIdentifier: type) { item, _ in
                defer { group.leave() }
                var url = item as? URL
                if url == nil, let data = item as? Data {
                    url = URL(dataRepresentation: data, relativeTo: nil)
                }
                if let url, url.isFileURL {
                    lock.lock()
                    paths.append(url.path)
                    lock.unlock()
                }
            }
        }

        group.notify(queue: .main) { [weak self] in
            var components = URLComponents()
            components.scheme = "nitroshare"
            components.host = "share"
            components.queryItems = paths.map { URLQueryItem(name: "path", value: $0) }
            if !paths.isEmpty, let url = components.url {
                NSWorkspace.shared.open(url)
            }
            self?.extensionContext?.completeRequest(returningItems: nil)
        }
    }
}
