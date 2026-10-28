import SwiftUI
import CoreTransferable
import UniformTypeIdentifiers
import RehabPathCore

struct PrivacyView: View {
    @Environment(AppModel.self) private var model
    @State private var confirmingDelete = false

    // Cards in a ScrollView, like Today and Progress: a long grouped Form drew Dynamic Type and
    // clipping findings from Apple's accessibility audit that the card layout does not.
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    dataCard
                    permissionsCard
                    rightsCard
                    aboutCard
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
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

    private var dataCard: some View {
        Card {
            CardTitle("Your data")
            Label("Stored only on this iPhone", systemImage: "iphone")
            Label("Encrypted while your iPhone is locked", systemImage: "lock")
            Label("Not backed up to iCloud", systemImage: "icloud.slash")
            Label("Nothing is sent anywhere yet", systemImage: "network.slash")
        }
    }

    private var permissionsCard: some View {
        Card {
            CardTitle("Permissions")
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
                .frame(minHeight: 44)
                .accessibilityIdentifier("privacy.\(scope.scope.rawValue)")
                if scope.id != OptionalScope.all.last?.id {
                    Divider()
                }
            }
            if let consent = model.data.consent {
                Text("You agreed on \(consent.grantedAt.formatted(date: .long, time: .omitted)) (version \(consent.version)).")
                    .font(.footnote)
                    .foregroundStyle(Color.mutedText)
            }
        }
    }

    private var rightsCard: some View {
        Card {
            CardTitle("Your rights")
            if let json = model.exportJSON() {
                ShareLink(
                    item: DataExportFile(json: json),
                    preview: SharePreview("My RehabPath data")
                ) {
                    Label("Download a copy of my data", systemImage: "square.and.arrow.up")
                        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                        .contentShape(Rectangle())
                }
                .accessibilityIdentifier("privacy.export")
                Divider()
            }
            Button(role: .destructive) {
                confirmingDelete = true
            } label: {
                Label("Delete all my data", systemImage: "trash")
                    .foregroundStyle(Color.destructiveText)
                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                    .contentShape(Rectangle())
            }
            .accessibilityIdentifier("privacy.delete")
            Text("Deleting removes everything from this iPhone straight away and can't be undone. Questions? Email \(AppConfig.privacyEmail).")
                .font(.footnote)
                .foregroundStyle(Color.mutedText)
        }
    }

    private var aboutCard: some View {
        Card {
            CardTitle("About")
            Link("Privacy policy", destination: AppConfig.privacyPolicyURL)
                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            Link("Support", destination: AppConfig.supportURL)
                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            PrototypeNotice()
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
