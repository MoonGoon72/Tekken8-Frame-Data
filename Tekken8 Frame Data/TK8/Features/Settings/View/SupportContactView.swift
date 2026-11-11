import MessageUI
import SwiftUI

struct SupportContactView: View {
    let supportURL: URL

    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @FocusState private var isEditingMessage: Bool
    @State private var message = ""
    @State private var mailDraft: SupportMailDraft?
    @State private var mailResult: MFMailComposeResult?
    @State private var mailIssue: MailIssue?

    private var trimmedMessage: String {
        message.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(
                        "Feedback message".localized(),
                        text: $message,
                        prompt: Text("Tell us what happened or what could be improved.".localized()),
                        axis: .vertical
                    )
                    .lineLimit(5...12)
                    .focused($isEditingMessage)
                } header: {
                    Text("Feedback message".localized())
                }

                Button("Continue to email".localized(), action: prepareMail)
                    .disabled(trimmedMessage.isEmpty)
            }
            .navigationTitle("Contact developer".localized())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close".localized()) { dismiss() }
                }
            }
        }
        .sheet(item: $mailDraft, onDismiss: finishMail) { draft in
            SupportMailComposer(draft: draft) { result in
                mailResult = result
                mailDraft = nil
            }
        }
        .alert(item: $mailIssue) { issue in
            Alert(
                title: Text("Email unavailable".localized()),
                message: Text(issue.message),
                primaryButton: .default(Text("Open support page".localized())) { openURL(supportURL) },
                secondaryButton: .cancel(Text("Cancel".localized()))
            )
        }
    }

    private func prepareMail() {
        let message = trimmedMessage
        guard !message.isEmpty else { return }
        isEditingMessage = false

        guard MFMailComposeViewController.canSendMail() else {
            mailIssue = .notConfigured
            return
        }

        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"
        let context = String(
            format: "App version: %@\niOS version: %@".localized(),
            version,
            UIDevice.current.systemVersion
        )
        mailDraft = SupportMailDraft(body: message + "\n\n" + context)
    }

    private func finishMail() {
        defer { mailResult = nil }
        switch mailResult {
        case .sent:
            dismiss()
        case .failed:
            mailIssue = .failed
        default:
            break
        }
    }

    private enum MailIssue: Identifiable {
        case notConfigured
        case failed

        var id: Self { self }

        var message: String {
            switch self {
            case .notConfigured:
                "Set up an account in Apple Mail or visit the support page for contact options.".localized()
            case .failed:
                "The email could not be sent. Your message is still here.".localized()
            }
        }
    }
}

private struct SupportMailDraft: Identifiable {
    let id = UUID()
    let body: String
}

private struct SupportMailComposer: UIViewControllerRepresentable {
    let draft: SupportMailDraft
    let onFinish: (MFMailComposeResult) -> Void

    func makeUIViewController(context: Context) -> MFMailComposeViewController {
        let controller = MFMailComposeViewController()
        controller.mailComposeDelegate = context.coordinator
        controller.setToRecipients(["moongoon.cnu@gmail.com"])
        controller.setSubject("[TK8] App feedback".localized())
        controller.setMessageBody(draft.body, isHTML: false)
        return controller
    }

    func updateUIViewController(_ controller: MFMailComposeViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onFinish: onFinish)
    }

    final class Coordinator: NSObject, MFMailComposeViewControllerDelegate {
        let onFinish: (MFMailComposeResult) -> Void

        init(onFinish: @escaping (MFMailComposeResult) -> Void) {
            self.onFinish = onFinish
        }

        func mailComposeController(
            _ controller: MFMailComposeViewController,
            didFinishWith result: MFMailComposeResult,
            error: Error?
        ) {
            onFinish(result)
        }
    }
}
