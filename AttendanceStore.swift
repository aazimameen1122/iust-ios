import Foundation
import SwiftUI

/// Port of Android's AttendanceStore. Shared with the widget via App Group.
struct AttendanceSubject: Codable, Identifiable {
    var id: String { name }
    let name: String
    let pct: Double
}

enum AttendanceStore {
    /// IUST rule: below 75% you're ineligible for exams.
    static let dangerLine = 75.0
    /// Warning zone.
    static let warnLine = 85.0

    private static let suiteName = "group.com.mussey.iustapp"
    private static let keySubjects = "subjects"
    private static let keyUpdated = "updated_at"

    private static var defaults: UserDefaults {
        UserDefaults(suiteName: suiteName) ?? .standard
    }

    static func color(for pct: Double) -> Color {
        if pct < dangerLine { return .red }
        if pct < warnLine { return .orange }
        return .green
    }

    static func save(_ subjects: [AttendanceSubject]) {
        if let data = try? JSONEncoder().encode(subjects) {
            defaults.set(data, forKey: keySubjects)
            defaults.set(Date().timeIntervalSince1970, forKey: keyUpdated)
        }
        // Also mirror to standard defaults so the app UI reads fast.
        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: "iust_last_sync")
    }

    static func load() -> (subjects: [AttendanceSubject], updated: Date?) {
        guard let data = defaults.data(forKey: keySubjects),
              let subjects = try? JSONDecoder().decode([AttendanceSubject].self, from: data)
        else { return ([], nil) }
        let ts = defaults.double(forKey: keyUpdated)
        return (subjects, ts > 0 ? Date(timeIntervalSince1970: ts) : nil)
    }

    static var lastSync: Date? {
        let ts = UserDefaults.standard.double(forKey: "iust_last_sync")
        return ts > 0 ? Date(timeIntervalSince1970: ts) : nil
    }

    static func overallPct(_ subjects: [AttendanceSubject]) -> Double? {
        guard !subjects.isEmpty else { return nil }
        return subjects.map(\.pct).reduce(0, +) / Double(subjects.count)
    }
}
