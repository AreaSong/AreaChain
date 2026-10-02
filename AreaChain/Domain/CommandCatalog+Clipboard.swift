import Foundation

extension CommandCatalogBuilder {
    static var clipboard: [CommandDescriptor] {
        [
            entry("clipboard.browse", "/clipboard/browse", .query, "C1:browse")
                .scope(.clipboard),
            entry("clipboard.search", "/clipboard/search", .query, "C1:search",
                  [p(.query, .shortText).optional(), choice(.mode, "mixed exact regex")])
                .scope(.clipboard),
            entry("clipboard.copy", "/clipboard/copy", .systemAction, "C2:copy")
                .targets([.clipboardEntry]).risk([.externalEffect]),
            entry("clipboard.paste", "/clipboard/paste", .systemAction, "C2:paste")
                .targets([.clipboardEntry]).requiring([.systemPermission, .externalApplication]).risk([.externalEffect]),
            entry("clipboard.pastePlain", "/clipboard/paste-plain", .systemAction, "C2:pastePlain")
                .targets([.clipboardEntry]).requiring([.systemPermission, .externalApplication]).risk([.externalEffect]),
            entry("clipboard.pinned", "/clipboard/pinned", .modification, "C3:pin C3:unpin",
                  [p(.enabled, .boolean)])
                .targets([.clipboardEntry]).ordinary(),
            entry("clipboard.copyLetter", "/clipboard/copy-letter", .systemAction, "C3:copyLetter",
                  [choice(.letter, "a b c d e f g h i j k l m n o p q r s t u v w x y z")])
                .risk([.externalEffect]),
            entry("clipboard.delete", "/clipboard/delete", .systemAction, "C3:delete")
                .targets([.clipboardEntry]).risk([.permanentDeletion]),
        ]
    }
}

extension CommandCatalogBuilder {
    static var clipboardOptions: [CommandDescriptor] {
        [
            entry("clipboard.prune", "/clipboard/prune", .systemAction, "C3:clearUnpinned")
                .targets([.clipboardEntry], batch: .explicitMultiple).risk([.permanentDeletion]),
            entry("clipboard.empty", "/clipboard/empty", .systemAction, "C3:clearAll")
                .targets([.clipboardEntry], batch: .explicitMultiple).risk([.permanentDeletion]),
            entry("clipboard.recording", "/clipboard/recording", .systemAction, "C4:pause C4:resume",
                  [p(.enabled, .boolean)]),
            entry("clipboard.skipNext", "/clipboard/skip-next", .systemAction, "C4:skipNext"),
            entry("clipboard.ignoreApp", "/clipboard/ignore-app", .systemAction, "C4:ignoreApp",
                  [p(.bundleID, .shortText)]),
            entry("clipboard.ignoreUniversal", "/setting/clipboard/ignore-universal", .modification, "C5:ignoreUniversal",
                  [p(.enabled, .boolean)])
                .ordinary(),
            entry("clipboard.limit", "/setting/clipboard/limit", .modification, "C5:limit",
                  [p(.value, .number(20...999, integer: true))])
                .ordinary(),
            entry("clipboard.interval", "/setting/clipboard/interval", .modification, "C5:interval",
                  [p(.value, .number(0.1...2, integer: false))])
                .ordinary(),
            entry("clipboard.searchMode", "/setting/clipboard/search-mode", .modification, "C5:searchMode",
                  [choice(.mode, "mixed exact regex")])
                .ordinary(),
            entry("clipboard.position", "/setting/clipboard/position", .modification, "C5:position",
                  [choice(.position, "cursor center")])
                .ordinary(),
            entry("clipboard.clickAction", "/setting/clipboard/click-action", .modification, "C5:clickAction",
                  [choice(.value, "copy paste")])
                .ordinary(),
            entry("clipboard.plainText", "/setting/clipboard/plain-text", .modification, "C5:plainText",
                  [p(.enabled, .boolean)])
                .ordinary(),
            entry("clipboard.sound", "/setting/clipboard/sound", .modification, "C5:sound",
                  [p(.enabled, .boolean)])
                .ordinary(),
            entry("clipboard.unignoreApp", "/setting/clipboard/unignore-app", .systemAction, "C5:unignoreApp",
                  [p(.bundleID, .shortText)]),
            entry("clipboard.addPattern", "/setting/clipboard/add-pattern", .systemAction, "C5:addPattern",
                  [p(.pattern, .shortText)]),
            entry("clipboard.removePattern", "/setting/clipboard/remove-pattern", .systemAction, "C5:removePattern",
                  [p(.pattern, .shortText)]),
            entry("clipboard.addType", "/setting/clipboard/add-type", .systemAction, "C5:addType",
                  [p(.pasteboardType, .shortText)]),
            entry("clipboard.removeType", "/setting/clipboard/remove-type", .systemAction, "C5:removeType",
                  [p(.pasteboardType, .shortText)]),
            entry("clipboard.openWindow", "/window/clipboard/open", .navigation, "C6:open"),
            entry("clipboard.closeWindow", "/window/clipboard/close", .navigation, "C6:close"),
            entry("clipboard.pinWindow", "/window/clipboard/pinned", .systemAction, "C6:pin C6:unpin",
                  [p(.enabled, .boolean)]),
            entry("clipboard.workspace", "/window/clipboard/workspace", .navigation, "C6:workspace"),
        ]
    }
}
