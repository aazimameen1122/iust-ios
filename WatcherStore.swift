import Foundation

/// Port of Android's WatcherStore — page-change watchers.
/// iOS note: true background polling like Android's WorkManager isn't possible.
/// Watchers snapshot a content hash when you visit; iOS checks them on each
/// foreground launch and notifies on change.
struct PageWatcher: Codable, Identifiable {
    var id: String { url }
    let label: String
    let url: String
    var lastHash: String?
    var lastChecked: Date?
}

enum WatcherStore {
    private static let key = "iust_watchers"

    static func all() -> [PageWatcher] {
        guard let data = UserDefaults.standard.data(forKey: key),
              let list = try? JSONDecoder().decode([PageWatcher].self, from: data)
        else { return [] }
        return list
    }

    static func save(_ list: [PageWatcher]) {
        if let data = try? JSONEncoder().encode(list) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    static func addOrUpdate(label: String, url: String) {
        var list = all()
        if let i = list.firstIndex(where: { $0.url == url }) {
            list[i] = PageWatcher(label: label, url: url,
                                  lastHash: list[i].lastHash,
                                  lastChecked: list[i].lastChecked)
        } else {
            list.append(PageWatcher(label: label, url: url))
        }
        save(list)
    }

    static func remove(url: String) {
        save(all().filter { $0.url != url })
    }

    static func updateHash(url: String, hash: String) {
        var list = all()
        if let i = list.firstIndex(where: { $0.url == url }) {
            list[i].lastHash = hash
            list[i].lastChecked = Date()
            save(list)
        }
    }

    /// Cheap content hash: strip tags, hash the text length + prefix.
    static let hashJS = """
    (function(){
      var t=(document.body?document.body.innerText:'').replace(/\\s+/g,' ').trim();
      var h=0;for(var i=0;i<t.length;i++){h=((h<<5)-h+t.charCodeAt(i))|0;}
      return JSON.stringify({h:h,len:t.length,head:t.slice(0,200)});
    })();
    """
}
