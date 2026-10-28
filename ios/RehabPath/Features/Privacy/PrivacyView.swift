import SwiftUI
import CoreTransferable
import UniformTypeIdentifiers
import RehabPathCore

struct PrivacyView: View {
    @Environment(AppModel.self) private var model
    @State private var confirmingDelete = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Label("Stored only on this iPhone", systemImage: "iphone")
                    Label("Encrypted while your iPhone is locked", systemImage: "lock")
                    Label("Not backed up to iCloud", systemImage: "icloud.slash")
                    Label("Nothing is sent to RehabPath in this prototype", systemImage: "network.slash")
                } header: {
                    Text("Your data").foregroundStyle(Color.mutedText)
                }

                Section {
                    ForEach(OptionalScope.all) { scope in
                        Toggle(isOn: Binding(
                            get: { model.allows(scope.scope) },
                            set: { model.setConsent(scope.scope, granted: $0) }
                        )) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(scope.title)
                                Text(scope.detail).font(.footnote).foregroundStyle(Color.mutedText)
                            }
                        }
                        .accessibilityIdentifier("privacy.\(scope.scope.rawValue)")
                    }
                } header: {
                    Text("Permissions").foregroundStyle(Color.mutedText)
                } footer: {
                    if let consent = model.data.consent {
                        Text("You agreed on \(consent.grantedAt.formatted(date: .long, time: .omitted)) (version \(consent.version)).")
                            .foregroundStyle(Color.mutedText)
                    }
                }

                Section {
                    if let json = model.exportJSON() {
                        ShareLink(
                            item: DataExportFile(json: json),
                            preview: SharePreview("My RehabPath data")
                        ) {
                            Label("Download a copy of my data", systemImage: "square.and.arrow.up")
                        }
                        .accessibilityIdentifier("privacy.export")
                    }
                    Button(role: .destructive) {
                        confirmingDelete = true
                    } label: {
                        Label("Delete all my data", systemImage: "trash")
                    }
                    .accessibilityIdentifier("privacy.delete")
                } header: {
                    Text("Your rights").foregroundStyle(Color.mutedText)
                } footer: {
                    Text("Deleting removes everything from this iPhone straight away and can't be undone. Questions? Email \(AppConfig.privacyEmail).")
                        .foregroundStyle(Color.mutedText)
                }

                Section {
                    Link("Privacy policy", destination: AppConfig.privacyPolicyURL)
                    Link("Support", destination: AppConfig.supportURL)
                    PrototypeNotice()
                } header: {
                    Text("About").foregroundStyle(Color.mutedText)
                }
            }
            .navigationTitle("Privacy")
            .confirmationDialog(
                "Delete all your RehabPath data?",
                isPresented: $confirmingDelete,
                titleVisibility: .visible
            ) {
                Button("Delete everything", role: .destructive) { model.deleteAllData() }
                    .accessibilityIdentifier("privacy.confirmDelete")
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Your profile, check-ins and pain scores will be permanently removed from this iPhone.")
            }
        }
    }
}

struct DataExportFile: Transferable {
    let json: Data

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .json) { $0.json }
            .suggestedFileName("RehabPath-my-data.json")
    }
}
