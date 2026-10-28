import SwiftUI
import RehabPathCore

/// Three short steps, mirroring the web onboarding: about you → pain baseline → consent.
/// Collects only what the behavioural engine uses (no phone number, email or ACC claim number).
struct OnboardingFlow: View {
    enum Step: Int, CaseIterable {
        case aboutYou, pain, consent
    }

    @Environment(AppModel.self) private var model
    @State private var step: Step = .aboutYou
    @State private var name = ""
    @State private var goal = ""
    @State private var pain = 5
    @State private var coreConsent = false
    @State private var optionalScopes = ConsentScope.defaultOptionalScopes

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Text("Step \(step.rawValue + 1) of \(Step.allCases.count)")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.accentColor)
                    switch step {
                    case .aboutYou: aboutYou
                    case .pain: painStep
                    case .consent: consentStep
                    }
                }
                .padding()
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Color(.systemGroupedBackground))
            .navigationTitle(title)
            .toolbar {
                if step != .aboutYou {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Back") { go(to: step.rawValue - 1) }
                            .accessibilityIdentifier("onboarding.back")
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                primaryAction
                    .padding()
                    .background(.bar)
            }
        }
    }

    private var title: String {
        switch step {
        case .aboutYou: "Welcome"
        case .pain: "Your recovery"
        case .consent: "Your data"
        }
    }

    // MARK: Steps

    private var aboutYou: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("This takes about two minutes. Your answers help RehabPath support you at the right moments.")
                .foregroundStyle(Color.mutedText)

            VStack(alignment: .leading, spacing: 8) {
                Text("What should we call you?").font(.headline)
                TextField("First name", text: $name)
                    .textContentType(.givenName)
                    .textFieldStyle(.roundedBorder)
                    .accessibilityIdentifier("onboarding.name")
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("What do you most want to get back to?").font(.headline)
                TextField("For example, walking the dog", text: $goal)
                    .textFieldStyle(.roundedBorder)
                    .accessibilityIdentifier("onboarding.goal")
                Text("We'll remind you of this when motivation dips.")
                    .font(.footnote)
                    .foregroundStyle(Color.mutedText)
            }
        }
    }

    private var painStep: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("How would you rate your pain right now?").font(.headline)
            PainScalePicker(value: $pain)
                .accessibilityIdentifier("onboarding.pain")
            Text("This gives us a starting point. Pain usually eases before healing is complete — we'll help you keep going through that stage.")
                .foregroundStyle(Color.mutedText)
        }
    }

    private var consentStep: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("We believe you should know exactly how your information is used.")
                .foregroundStyle(Color.mutedText)

            Card {
                ConsentFact(symbol: "iphone", title: "What we store",
                            detail: "Your first name, recovery goal, pain scores and which exercises you complete.")
                ConsentFact(symbol: "lock", title: "Where it's kept",
                            detail: "Only on this iPhone, encrypted while it's locked. It isn't sent to RehabPath or backed up to iCloud in this prototype.")
                ConsentFact(symbol: "hand.raised", title: "Your rights",
                            detail: "Download or delete everything at any time from the Privacy tab.")
            }

            Toggle(isOn: $coreConsent) {
                Text("I agree to RehabPath storing this information on my iPhone to run my programme.")
            }
            .accessibilityIdentifier("consent.core")

            VStack(alignment: .leading, spacing: 12) {
                Text("Optional — change any time").font(.headline)
                ForEach(OptionalScope.all) { scope in
                    Toggle(isOn: binding(for: scope.scope)) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(scope.title)
                            Text(scope.detail).font(.footnote).foregroundStyle(Color.mutedText)
                        }
                    }
                    .accessibilityIdentifier("consent.\(scope.scope.rawValue)")
                }
            }

            Link("Read the full privacy policy", destination: AppConfig.privacyPolicyURL)
            PrototypeNotice()
        }
    }

    // MARK: Actions

    @ViewBuilder
    private var primaryAction: some View {
        switch step {
        case .aboutYou:
            Button("Continue") { go(to: Step.pain.rawValue) }
                .buttonStyle(.primary)
                .disabled(name.trimmed.isEmpty || goal.trimmed.isEmpty)
                .accessibilityIdentifier("onboarding.continue")
        case .pain:
            Button("Continue") { go(to: Step.consent.rawValue) }
                .buttonStyle(.primary)
                .accessibilityIdentifier("onboarding.continue")
        case .consent:
            Button("I agree — start my programme") {
                model.completeOnboarding(name: name, goal: goal, baselinePain: pain, optionalScopes: optionalScopes)
            }
            .buttonStyle(.primary)
            .disabled(!coreConsent)
            .accessibilityIdentifier("onboarding.agree")
        }
    }

    private func go(to rawValue: Int) {
        guard let next = Step(rawValue: rawValue) else { return }
        withAnimation { step = next }
    }

    private func binding(for scope: ConsentScope) -> Binding<Bool> {
        Binding(
            get: { optionalScopes.contains(scope) },
            set: { isOn in
                if isOn { optionalScopes.insert(scope) } else { optionalScopes.remove(scope) }
            }
        )
    }
}

/// Patient-facing wording for each optional consent scope. Shared with the Privacy tab.
struct OptionalScope: Identifiable {
    let scope: ConsentScope
    let title: String
    let detail: String

    var id: ConsentScope { scope }

    static let all: [OptionalScope] = [
        OptionalScope(scope: .reminders, title: "Daily reminder",
                      detail: "One notification a day. It never shows health details on your lock screen."),
        OptionalScope(scope: .shareWithCareTeam, title: "Share progress with my care team",
                      detail: "You choose each person. Prototype: nothing is sent yet."),
        OptionalScope(scope: .aggregateResearch, title: "Help improve rehab research",
                      detail: "Anonymous, combined data only. Prototype: nothing is sent yet.")
    ]
}

private struct ConsentFact: View {
    let symbol: String
    let title: String
    let detail: String

    var body: some View {
        Label {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline.weight(.semibold))
                Text(detail).font(.subheadline).foregroundStyle(Color.mutedText)
            }
        } icon: {
            Image(systemName: symbol).foregroundStyle(Color.accentColor)
        }
        .accessibilityElement(children: .combine)
    }
}

extension String {
    var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
}
