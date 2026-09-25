import WidgetKit
import SwiftUI

// WidgetKit extension for the IUST app.
// Reads the latest attendance snapshot written by the main app via the
// shared App Group (group.com.mussey.iustapp). Add this file to a Widget
// Extension target in Xcode; the main app target intentionally excludes it.

struct AttendanceEntry: TimelineEntry {
    let date: Date
    let overall: Double?
    let dangerCount: Int
    let warningCount: Int
    let updated: String
}

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> AttendanceEntry {
        AttendanceEntry(date: Date(), overall: 82.5, dangerCount: 1, warningCount: 2, updated: "just now")
    }

    func getSnapshot(in context: Context, completion: @escaping (AttendanceEntry) -> Void) {
        completion(load())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<AttendanceEntry>) -> Void) {
        let entry = load()
        let next = Calendar.current.date(byAdding: .minute, value: 30, to: Date()) ?? Date()
        completion(Timeline(entries: [entry], policy: .after(next)))
    }

    private func load() -> AttendanceEntry {
        let defaults = UserDefaults(suiteName: "group.com.mussey.iustapp")
        let overall = defaults?.double(forKey: "widgetOverall") ?? -1
        let danger = defaults?.integer(forKey: "widgetDanger") ?? 0
        let warning = defaults?.integer(forKey: "widgetWarning") ?? 0
        let updated = defaults?.string(forKey: "widgetUpdated") ?? "never"
        return AttendanceEntry(
            date: Date(),
            overall: overall < 0 ? nil : overall,
            dangerCount: danger,
            warningCount: warning,
            updated: updated
        )
    }
}

struct WidgetEntryView: View {
    var entry: AttendanceEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("IUST Attendance")
                .font(.headline)
                .foregroundStyle(Color(red: 0.05, green: 0.10, blue: 0.28))
            if let overall = entry.overall {
                Text(String(format: "%.1f%%", overall))
                    .font(.system(size: 34, weight: .bold))
                    .foregroundStyle(overall < 75 ? .red : (overall < 85 ? .orange : .green))
                Text(alertLine)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text("Open the app to sync")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text("Updated \(entry.updated)")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding()
    }

    private var alertLine: String {
        var parts: [String] = []
        if entry.dangerCount > 0 { parts.append("\(entry.dangerCount) below 75%") }
        if entry.warningCount > 0 { parts.append("\(entry.warningCount) below 85%") }
        return parts.isEmpty ? "All subjects healthy" : parts.joined(separator: " · ")
    }
}

@main
struct IUSTWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "com.mussey.iustapp.widget", provider: Provider()) { entry in
            WidgetEntryView(entry: entry)
        }
        .configurationDisplayName("IUST Attendance")
        .description("Your overall attendance at a glance.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
