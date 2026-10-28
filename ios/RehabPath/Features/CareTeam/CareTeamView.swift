import SwiftUI
import RehabPathCore

struct CareTeamView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    ForEach(model.data.careTeam) { member in
                        Toggle(isOn: Binding(
                            get: { member.isSharing },
                            set: { model.setSharing(member.id, enabled: $0) }
                        )) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(member.name)
                                Text("\(member.role) · \(member.organisation)")
                                    .font(.footnote)
                                    .foregroundStyle(Color.mutedText)
                            }
                        }
                        .disabled(!sharingAllowed)
                        .accessibilityIdentifier("careTeam.\(member.name)")
                    }
                } header: {
                    Text("Who can see your progress").foregroundStyle(Color.mutedText)
                } footer: {
                    Group {
                        if sharingAllowed {
                            Text("You choose who sees your progress. Prototype: nothing is sent yet.")
                        } else {
                            Text("Sharing is off. You can allow it in the Privacy tab.")
                        }
                    }
                    .font(.footnote)
                    .foregroundStyle(Color.mutedText)
                }
            }
            .navigationTitle("Care team")
        }
    }

    private var sharingAllowed: Bool { model.allows(.shareWithCareTeam) }
}
