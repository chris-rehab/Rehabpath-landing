import SwiftUI
import RehabPathCore

struct CareTeamView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        NavigationStack {
            List {
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
                    Text(sharingAllowed
                         ? "You're in control. Turn sharing on only for people who support your recovery. Prototype: nothing is sent yet — this shows how sharing will work."
                         : "Sharing is off. You can allow it in the Privacy tab.")
                    .foregroundStyle(Color.mutedText)
                }
            }
            .navigationTitle("Care team")
        }
    }

    private var sharingAllowed: Bool { model.allows(.shareWithCareTeam) }
}
