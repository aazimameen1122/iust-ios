import SwiftUI
import WebKit
import UIKit

/// Main screen — port of Android's BrowserActivity (v2.22).
/// Opens the IUST Student Login portal directly, navy/gold theme, gold progress
/// bar, pull-to-refresh, biometric saved login, page watchers, attendance
/// tracking + widget data, dark mode, in-app PDF viewer.
struct ContentView: View {
    @AppStorage("darkMode") private var darkMode = false
    @StateObject private var holder = WebViewHolder()

    @State private var isLoading = true
    @State private var progress: Double = 0
    @State private var canGoBack = false
    @State private var pageTitle = ""
    @State private var loadFailed = false

    @State private var pdfURL: URL?
    @State private var showSaveLogin = false
    @State private var showAttendance = false
    @State private var showWatchers = false
    @State private var showIntervalPicker = false
    @State private var toast: String?
    @State private var diagnosis: String?

    @State private var savedUsername = ""
    @State private var savedPassword = ""

    var body: some View {
        NavigationStack {
            ZStack {
                PortalWebView(
                    holder: holder,
                    isLoading: $isLoading,
                    progress: $progress,
                    canGoBack: $canGoBack,
                    pageTitle: $pageTitle,
                    loadFailed: $loadFailed,
                    onPDF: { pdfURL = $0 },
                    onExternalURL: { UIApplication.shared.open($0) }
                )

                if isLoading && progress == 0 && !loadFailed {
                    loadingView
                }
                if loadFailed {
                    errorView
                }
            }
            .navigationTitle(pageTitle.isEmpty ? "IUST" : pageTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color(red: 0.07, green: 0.16, blue: 0.32), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: goBackOrHome) {
                        Image(systemName: canGoBack ? "chevron.left" : "house")
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button("Refresh", systemImage: "arrow.clockwise") {
                            holder.coordinator?.reload()
                        }
                        if CredentialStore.hasCredentials {
                            Button("Fill saved login", systemImage: "key.fill") { fillSavedLogin() }
                        }
                        Button("Open in Safari", systemImage: "safari") {
                            UIApplication.shared.open(holder.currentURL)
                        }
                        Button("Watch this page", systemImage: "eye") { watchCurrentPage() }
                        Button("Manage watchers", systemImage: "eye.circle") { showWatchers = true }
                        Button(CredentialStore.hasCredentials ? "Update saved login…" : "Save login…",
                               systemImage: "key") { showSaveLogin = true }
                        Button("Track attendance", systemImage: "chart.bar") { trackAttendance() }
                        Button(autoUpdateLabel(), systemImage: "clock.arrow.circlepath") {
                            showIntervalPicker = true
                        }
                        Button("Diagnose page", systemImage: "stethoscope") { diagnosePage() }
                        Toggle("Dark mode", systemImage: "moon", isOn: $darkMode)
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .overlay(alignment: .top) {
                if isLoading && progress > 0 {
                    ProgressView(value: progress)
                        .tint(Color(red: 0.83, green: 0.69, blue: 0.22))
                        .frame(height: 3)
                }
            }
            .sheet(isPresented: Binding(
                get: { pdfURL != nil },
                set: { if !$0 { pdfURL = nil } }
            )) {
                if let pdfURL { PDFSheet(url: pdfURL) }
            }
            .sheet(isPresented: $showSaveLogin) { saveLoginSheet }
            .sheet(isPresented: $showAttendance) { attendanceSheet }
            .sheet(isPresented: $showWatchers) { watchersSheet }
            .sheet(isPresented: $showIntervalPicker) { intervalSheet }
            .alert("Page structure", isPresented: Binding(
                get: { diagnosis != nil },
                set: { if !$0 { diagnosis = nil } }
            )) {
                Button("Copy") {
                    UIPasteboard.general.string = diagnosis
                    toast = "Copied — paste it in chat."
                    diagnosis = nil
                }
                Button("Close", role: .cancel) { diagnosis = nil }
            } message: {
                Text(diagnosis ?? "")
            }
            .overlay(alignment: .bottom) {
                if let toast {
                    Text(toast)
                        .padding(.horizontal, 16).padding(.vertical, 10)
                        .background(.ultraThinMaterial, in: Capsule())
                        .padding(.bottom, 24)
                        .onAppear {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                                self.toast = nil
                            }
                        }
                }
            }
        }
    }

    // MARK: - Views

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView().scaleEffect(1.4)
            Text("Opening IUST Student Services…").foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }

    private var errorView: some View {
        VStack(spacing: 16) {
            Image(systemName: "wifi.exclamationmark")
                .font(.system(size: 48)).foregroundStyle(.secondary)
            Text("Couldn't load the page").font(.headline)
            Text("Check your connection and try again.").foregroundStyle(.secondary)
            Button("Retry") {
                loadFailed = false
                holder.coordinator?.reload()
            }
            .buttonStyle(.borderedProminent)
            Button("Open in Safari") { UIApplication.shared.open(holder.currentURL) }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }

    private var saveLoginSheet: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Student ID / registration no.", text: $savedUsername)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    SecureField("Password", text: $savedPassword)
                } header: {
                    Text("Stored encrypted in the device Keychain. You'll unlock it with Face ID / Touch ID each time.")
                }
            }
            .navigationTitle("Save portal login")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showSaveLogin = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { saveLogin() }
                        .disabled(savedUsername.trimmingCharacters(in: .whitespaces).isEmpty || savedPassword.isEmpty)
                }
            }
        }
        .onAppear {
            if let (u, _) = CredentialStore.load() { savedUsername = u }
        }
    }

    private var attendanceSheet: some View {
        NavigationStack {
            AttendanceView()
                .navigationTitle("Attendance")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Done") { showAttendance = false }
                    }
                }
        }
    }

    private var watchersSheet: some View {
        NavigationStack {
            List {
                ForEach(WatcherStore.all()) { w in
                    VStack(alignment: .leading) {
                        Text(w.label).font(.headline)
                        Text(w.url).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                        if let c = w.lastChecked {
                            Text("Checked \(c.formatted(date: .abbreviated, time: .shortened))")
                                .font(.caption2).foregroundStyle(.secondary)
                        }
                    }
                }
                .onDelete { idx in
                    var list = WatcherStore.all()
                    for i in idx.sorted(by: >) {
                        WatcherStore.remove(url: list[i].url)
                    }
                }
            }
            .navigationTitle("Watched pages")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { showWatchers = false }
                }
            }
            .overlay {
                if WatcherStore.all().isEmpty {
                    ContentUnavailableView("No watched pages",
                        systemImage: "eye",
                        description: Text("Use the menu → Watch this page on results, notices or attendance pages."))
                }
            }
        }
    }

    private var intervalSheet: some View {
        NavigationStack {
            List {
                ForEach(AttendanceIntervals.presets, id: \.minutes) { p in
                    Button {
                        setInterval(minutes: p.minutes)
                    } label: {
                        HStack {
                            Text(p.label)
                            Spacer()
                            if AttendanceIntervals.currentMinutes == p.minutes {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
                Section {
                    Text("iOS decides the real refresh times — Background App Refresh is opportunistic, not exact. The widget refreshes on its own budget (roughly every 15–60 min when visible).")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Auto-update attendance")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { showIntervalPicker = false }
                }
            }
        }
    }

    // MARK: - Actions

    private func goBackOrHome() {
        if canGoBack { holder.coordinator?.goBack() }
        else { holder.coordinator?.load(PortalLogin.loginURL) }
    }

    private func saveLogin() {
        guard BiometricHelper.isAvailable() else {
            toast = "Face ID / Touch ID isn't set up, so logins can't be locked safely."
            return
        }
        BiometricHelper.authenticate(reason: "Save your IUST portal login securely") { ok, err in
            if ok {
                do {
                    try CredentialStore.save(username: savedUsername.trimmingCharacters(in: .whitespaces),
                                             password: savedPassword)
                    toast = "Login saved — use the key icon to fill it."
                    showSaveLogin = false
                } catch {
                    toast = "Couldn't save securely on this device."
                }
            } else {
                toast = err ?? "Authentication failed."
            }
        }
    }

    private func fillSavedLogin() {
        guard let (u, p) = CredentialStore.load() else {
            toast = "No saved login yet — use \"Save login\" first."
            return
        }
        BiometricHelper.authenticate(reason: "Fill your IUST portal login") { ok, err in
            guard ok else { toast = err ?? "Authentication failed."; return }
            holder.coordinator?.evaluate(js: PortalLogin.autofillJS(username: u, password: p)) { result in
                let s = (result as? String) ?? ""
                if s.contains("captcha") {
                    toast = "Login filled — type the code shown and tap Log in."
                } else if s.contains("submitted") {
                    toast = "Logging you in…"
                } else if s.contains("filled") {
                    toast = "Login filled — tap the login button."
                } else {
                    toast = "Couldn't find the login fields on this page."
                }
            }
        }
    }

    private func watchCurrentPage() {
        let u = holder.currentURL
        WatcherStore.addOrUpdate(label: pageTitle.isEmpty ? "Portal page" : pageTitle,
                                 url: u.absoluteString)
        holder.coordinator?.evaluate(js: WatcherStore.hashJS) { result in
            if let s = result as? String {
                WatcherStore.updateHash(url: u.absoluteString, hash: s)
            }
        }
        toast = "Watching this page — baseline saved."
    }

    private func trackAttendance() {
        holder.coordinator?.evaluate(js: PortalLogin.attendanceScrapeJS) { result in
            guard let json = result as? String,
                  let data = json.data(using: .utf8),
                  let arr = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
                toast = "Open the View Attendance page first, then track again."
                return
            }
            let subjects = arr.compactMap { d -> AttendanceSubject? in
                guard let n = d["n"] as? String,
                      let p = d["p"] as? Double else { return nil }
                return AttendanceSubject(name: n, pct: p)
            }
            guard !subjects.isEmpty else {
                toast = "Open the View Attendance page first, then track again."
                return
            }
            AttendanceStore.save(subjects)
            WidgetBridge.reload()
            showAttendance = true
            let low = subjects.filter { $0.pct < AttendanceStore.dangerLine }
            if !low.isEmpty {
                toast = "⚠️ \(low.count) subject\(low.count == 1 ? "" : "s") below 75%!"
            } else {
                toast = "Attendance saved — \(subjects.count) subjects."
            }
        }
    }

    private func diagnosePage() {
        let js = """
        (function(){
          function txt(s){return (s||'').replace(/\\s+/g,' ').trim();}
          var lines=['URL: '+location.href,'TITLE: '+txt(document.title).slice(0,80),'','=== FIELDS ==='];
          document.querySelectorAll('input,select,textarea').forEach(function(el){
            lines.push('- '+el.tagName.toLowerCase()
              +' type='+(el.type||'')
              +' id='+(el.id||'')
              +' name='+(el.name||''));
          });
          lines.push('','=== BUTTONS ===');
          document.querySelectorAll('button,input[type=button],input[type=submit]').forEach(function(b){
            lines.push('- '+txt(b.innerText||b.value).slice(0,60));
          });
          return lines.join('\\n');
        })();
        """
        holder.coordinator?.evaluate(js: js) { result in
            diagnosis = (result as? String) ?? "Couldn't read the page."
        }
    }

    private func autoUpdateLabel() -> String {
        let mins = AttendanceIntervals.currentMinutes
        if mins == 0 { return "Auto-update attendance…" }
        var label = "Auto-update: \(AttendanceIntervals.shortLabel(mins: mins))"
        if let last = AttendanceStore.lastSync {
            label += " • synced \(RelativeTime.string(since: last))"
        }
        return label
    }

    private func setInterval(minutes: Int) {
        if minutes > 0 && !CredentialStore.hasCredentials {
            toast = "Save your portal login first — auto-update needs it."
            showIntervalPicker = false
            return
        }
        AttendanceIntervals.currentMinutes = minutes
        showIntervalPicker = false
        toast = minutes == 0 ? "Auto-update off."
            : "Attendance will update about \(AttendanceIntervals.describe(mins: minutes))."
    }
}

// MARK: - Attendance list

struct AttendanceView: View {
    @State private var subjects: [AttendanceSubject] = []
    @State private var updated: Date?

    var body: some View {
        Group {
            if subjects.isEmpty {
                ContentUnavailableView("No attendance yet",
                    systemImage: "chart.bar",
                    description: Text("Open the View Attendance page in the portal, then use menu → Track attendance."))
            } else {
                List {
                    if let overall = AttendanceStore.overallPct(subjects) {
                        Section {
                            HStack {
                                Text("Overall")
                                Spacer()
                                Text(String(format: "%.1f%%", overall))
                                    .bold()
                                    .foregroundStyle(AttendanceStore.color(for: overall))
                            }
                        }
                    }
                    Section {
                        ForEach(subjects) { s in
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(s.name).font(.subheadline)
                                    if s.pct < AttendanceStore.dangerLine {
                                        Text("Below 75% — exam line").font(.caption2).foregroundStyle(.red)
                                    } else if s.pct < AttendanceStore.warnLine {
                                        Text("Warning zone").font(.caption2).foregroundStyle(.orange)
                                    }
                                }
                                Spacer()
                                Text(String(format: "%.1f%%", s.pct))
                                    .bold()
                                    .foregroundStyle(AttendanceStore.color(for: s.pct))
                            }
                        }
                    } header: {
                        if let updated {
                            Text("Updated \(updated.formatted(date: .abbreviated, time: .shortened))")
                        }
                    }
                }
            }
        }
        .onAppear {
            let loaded = AttendanceStore.load()
            subjects = loaded.subjects
            updated = loaded.updated
        }
    }
}

// MARK: - Intervals (port of AttendanceSyncScheduler presets)

enum AttendanceIntervals {
    struct Preset { let minutes: Int; let label: String }
    static let presets: [Preset] = [
        .init(minutes: 0, label: "Off"),
        .init(minutes: 15, label: "Every 15 min"),
        .init(minutes: 30, label: "Every 30 min"),
        .init(minutes: 60, label: "Every hour"),
        .init(minutes: 360, label: "Every 6 hours"),
        .init(minutes: 720, label: "Every 12 hours"),
        .init(minutes: 1440, label: "Daily"),
    ]
    private static let key = "iust_attendance_interval"
    static var currentMinutes: Int {
        get { UserDefaults.standard.integer(forKey: key) }
        set { UserDefaults.standard.set(newValue, forKey: key) }
    }
    static func shortLabel(mins: Int) -> String {
        presets.first(where: { $0.minutes == mins })?.label ?? "\(mins)m"
    }
    static func describe(mins: Int) -> String {
        shortLabel(mins: mins).lowercased()
    }
}

enum RelativeTime {
    static func string(since date: Date) -> String {
        let mins = max(0, Int(Date().timeIntervalSince(date) / 60))
        if mins < 1 { return "just now" }
        if mins < 60 { return "\(mins)m ago" }
        let h = mins / 60
        if h < 24 { return "\(h)h ago" }
        return "\(h / 24)d ago"
    }
}
