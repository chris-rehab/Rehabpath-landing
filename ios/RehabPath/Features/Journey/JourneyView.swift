import SwiftUI
import Charts
import RehabPathCore

struct JourneyView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let summary = model.summary
        let week = model.engine.recentDays(7, in: model.data, asOf: model.now)

        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    HStack(spacing: 16) {
                        Stat(value: "\(summary.streak)", label: summary.streak == 1 ? "day in a row" : "days in a row")
                        Stat(value: "\(summary.programmeDay)", label: "of \(model.data.programme.lengthInDays) days")
                    }

                    Card {
                        Text("Last 7 days").font(.title3.weight(.semibold))
                        Chart(week) { day in
                            BarMark(
                                x: .value("Day", day.day, unit: .day),
                                y: .value("Exercises done", day.completed)
                            )
                            .foregroundStyle(Color.accentColor)
                            .accessibilityLabel(day.day.formatted(.dateTime.weekday(.wide)))
                            .accessibilityValue("\(day.completed) of \(day.total) exercises")
                        }
                        .chartYScale(domain: 0...max(model.exercises.count, 1))
                        .chartXAxis {
                            AxisMarks(values: .stride(by: .day)) { _ in
                                AxisValueLabel(format: .dateTime.weekday(.narrow))
                            }
                        }
                        .frame(height: 180)
                    }

                    Card {
                        Label("Why keep going when it feels better?", systemImage: "lightbulb")
                            .font(.headline)
                        Text("Pain often eases weeks before your body has finished rebuilding strength. That's when most people stop — and when sticking with it matters most. New habits can take around two months to feel automatic.")
                            .foregroundStyle(Color.mutedText)
                        Text("Source: Lally et al. (2010), European Journal of Social Psychology.")
                            .font(.footnote)
                            .foregroundStyle(Color.mutedText)
                    }
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Progress")
        }
    }
}

private struct Stat: View {
    let value: String
    let label: String

    var body: some View {
        Card {
            Text(value)
                .font(.system(.largeTitle, design: .rounded, weight: .bold))
                .monospacedDigit()
            Text(label)
                .font(.subheadline)
                .foregroundStyle(Color.mutedText)
        }
        .accessibilityElement(children: .combine)
    }
}
