import SwiftUI
import PDFKit

/// In-app PDF viewer (port of Android's PdfViewerActivity).
struct PDFViewer: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> PDFView {
        let view = PDFView()
        view.autoScales = true
        if let doc = PDFDocument(url: url) {
            view.document = doc
        } else {
            URLSession.shared.downloadTask(with: url) { tmp, _, _ in
                guard let tmp = tmp, let doc = PDFDocument(url: tmp) else { return }
                DispatchQueue.main.async { view.document = doc }
            }.resume()
        }
        return view
    }

    func updateUIView(_ uiView: PDFView, context: Context) {}
}

struct PDFSheet: View {
    let url: URL
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            PDFViewer(url: url)
                .navigationTitle(url.lastPathComponent)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Done") { dismiss() }
                    }
                    ToolbarItem(placement: .primaryAction) {
                        ShareLink(item: url)
                    }
                }
        }
    }
}
