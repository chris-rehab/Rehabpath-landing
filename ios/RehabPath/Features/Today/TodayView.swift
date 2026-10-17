import SwiftUI
import RehabPathCore

struct TodayView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    NudgeCard(nudge: model.nudge)
                    programmeCard
                    PainCheckInCard()
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(greeting)
            .sensoryFeedback(.success, trigger: model.completedTodayCount) { old, new in
                new > old && new == model.exercises.count
            }
        }
    }

    private var greeting: String {
        "Kia ora, \(model.data.profile?.preferredName ?? "there")"
    }

    private var programmeCard: some View {
        Card {
            HStack(alignment: .firstTextBaseline) {
                Text("Today's programme").font(.title3.weight(.semibold))
                Spacer()
                Text("\(model.completedTodayCount) of \(model.exercises.count) done")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("today.progress")
            }
            ProgressView(value: Double(model.completedTodayCount), total: Double(max(model.exercises.count, 1)))
                .accessibilityHidden(true)

            ForEach(model.exercises) { exercise in
                ExerciseRow(exercise: exercise, isDone: model.isCompletedToday(exercise)) {
                    model.toggle(exercise)
                }
                if exercise.id != model.exercises.last?.id {
                    Divider()
                }
            }
        }
    }
}

private struct NudgeCard: View {
    let nudge: Nudge

    var body: some View {
        Card {
            Label {
                VStack(alignment: .leading, spacing: 4) {
                    Text(nudge.title).font(.headline)
                    Text(nudge.message).foregroundStyle(.secondary)
                }
            } icon: {
                Image(systemName: symbol).foregroundStyle(Color.accentColor)
            }
            if nudge.kind == .highPain {
                // Safety first: an obvious route to real help, above everything else.
                Link(destination: URL(string: "tel:0800611116")!) {
                    Label("Call Healthline (0800 611 116)", systemImage: "phone")
                }
                .font(.subheadline.weight(.semibold))
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("today.nudge")
    }

    private var symbol: String {
        switch nudge.kind {
        case .highPain: "cross.case"
        case .habitReversion: "figure.walk"
        case .restartSmall: "arrow.counterclockwise"
        case .oneIsEnough: "1.circle"
        case .streakMilestone: "flame"
        case .keepGoing: "sun.max"
        }
    }
}

private struct ExerciseRow: View {
    let exercise: Exercise
    let isDone: Bool
    let toggle: () -> Void

    var body: some View {
        Button(action: toggle) {
            HStack(spacing: 12) {
                Image(systemName: isDone ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(isDone ? Color.accentColor : Color.secondary)
                VStack(alignment: .leading, spacing: 2) {
                    Text(exercise.name)
                        .font(.body.weight(.medium))
                        .foregroundStyle(isDone ? .secondary : .primary)
                    Text(exercise.focus)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 8)
                Text(exercise.prescription)
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(exercise.name), \(exercise.sets) sets of \(exercise.reps)")
        .accessibilityValue(isDone ? "Done" : "Not done")
        .accessibilityHint(isDone ? "Double-tap to mark as not done" : "Double-tap to mark as done")
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier("exercise.\(exercise.id)")
    }
}

private struct PainCheckInCard: View {
    @Environment(AppModel.self) private var model
    @State private var pain = 3

    var body: some View {
        Card {
            Text("How's your pain today?").font(.title3.weight(.semibold))
            PainScalePicker(value: $pain)
            Button(model.today?.painScore == nil ? "Save today's pain score" : "Update today's pain score") {
                model.recordPain(pain)
            }
            .buttonStyle(.primary)
            .accessibilityIdentifier("today.savePain")
            if let saved = model.today?.painScore {
                Label("Saved: \(saved) out of 10", systemImage: "checkmark")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .onAppear {
            if let saved = model.today?.painScore { pain = saved }
        }
    }
}
