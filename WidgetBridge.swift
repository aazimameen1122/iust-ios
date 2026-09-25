import WidgetKit

/// Called after attendance saves so the WidgetKit timeline reloads.
/// Direct WidgetCenter calls from the foreground app don't consume the
/// background reload budget.
enum WidgetBridge {
    static func reload() {
        WidgetCenter.shared.reloadAllTimelines()
    }
}
