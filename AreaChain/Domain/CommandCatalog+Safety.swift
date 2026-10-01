import Foundation

extension CommandCatalogBuilder {
    static var safety: [CommandDescriptor] {
        [
            entry("privacy.create", "/privacy/create", .systemAction, "P1:create")
                .requiring([.secureInput, .freshAuthentication, .verifiedBackup]).risk([.privacyConversion]),
            entry("privacy.setupMethod", "/privacy/setup-method", .systemAction, "P1:method",
                  [choice(.method, "systemUnlock masterPassword both")])
                .requiring([.secureInput, .freshAuthentication]),
            entry("privacy.setupTags", "/privacy/setup-tags", .systemAction, "P1:tags",
                  [p(.tags, .tags)])
                .requiring([.freshAuthentication, .verifiedBackup]).risk([.privacyConversion]),
            entry("privacy.protectExisting", "/privacy/protect-existing", .systemAction, "P1:protectExisting")
                .targets([.diary], batch: .explicitMultiple).requiring([.freshAuthentication, .verifiedBackup]).risk([.privacyConversion]),
            entry("privacy.lock", "/privacy/lock", .systemAction, "P2:lock"),
            entry("privacy.unlock", "/privacy/unlock", .systemAction, "P2:unlock")
                .requiring([.authentication, .secureInput]),
            entry("privacy.systemUnlock", "/privacy/system-unlock", .systemAction, "P2:enableSystem P2:disableSystem",
                  [p(.enabled, .boolean)])
                .requiring([.freshAuthentication, .secureInput]),
            entry("privacy.setPassword", "/privacy/set-password", .systemAction, "P2:setPassword")
                .requiring([.secureInput, .freshAuthentication]),
            entry("privacy.changePassword", "/privacy/change-password", .systemAction, "P2:changePassword")
                .requiring([.secureInput, .freshAuthentication]),
            entry("privacy.removePassword", "/privacy/remove-password", .systemAction, "P2:removePassword")
                .requiring([.freshAuthentication, .independentConfirmation]),
            entry("privacy.idle", "/privacy/idle", .systemAction, "P2:idle",
                  [choice(.duration, "oneMinute fiveMinutes fifteenMinutes")]),
            entry("privacy.tags", "/privacy/tags", .systemAction, "P2:tags",
                  [tags])
                .requiring([.freshAuthentication, .verifiedBackup]).risk([.privacyConversion]),
            entry("privacy.unprotect", "/privacy/unprotect", .systemAction, "P3:unprotect")
                .targets([.diary]).requiring([.freshAuthentication, .verifiedBackup]).risk([.privacyConversion]),
            entry("privacy.retryImages", "/privacy/maintenance/images", .systemAction, "P4:retryImages")
                .requiring([.freshAuthentication, .independentConfirmation]),
            entry("privacy.retryKeys", "/privacy/maintenance/keys", .systemAction, "P4:retryKeys")
                .requiring([.freshAuthentication, .independentConfirmation]),
            entry("privacy.quitForCleanup", "/privacy/maintenance/quit", .systemAction, "P4:quitForCleanup")
                .requiring([.unsavedChangesConfirmation]).risk([.lifecycle]),
            entry("trash.browse", "/trash/browse", .query, "D1:browse",
                  [choice(.kind, "all todo routine diary image tag").defaulting(to: .choice("all"))])
                .scope(.trash),
            entry("trash.restore", "/trash/restore", .systemAction, "D1:restore")
                .targets([.todo, .routine, .diary, .image, .tag]).requiring([.authentication, .independentConfirmation]),
            entry("trash.delete", "/trash/delete", .systemAction, "D1:delete")
                .targets([.todo, .routine, .diary, .image, .tag]).requiring([.authentication]).risk([.permanentDeletion]),
            entry("trash.empty", "/trash/empty", .systemAction, "D1:empty")
                .targets([.todo, .routine, .diary, .image, .tag], batch: .explicitMultiple)
                .requiring([.authentication]).risk([.permanentDeletion]),
            entry("data.export", "/data/export", .systemAction, "D2:export",
                  [p(.file, .nativeFile(.jsonSnapshot))])
                .requiring([.nativeFilePanel]).risk([.externalEffect]),
            entry("data.selectImport", "/data/import/select", .systemAction, "D2:select",
                  [p(.file, .nativeFile(.jsonSnapshot))])
                .requiring([.nativeFilePanel]),
            entry("data.validateImport", "/data/import/validate", .systemAction, "D2:validate",
                  [p(.file, .nativeFile(.jsonSnapshot))])
                .requiring([.nativeFilePanel]),
            entry("data.previewImport", "/data/import/preview", .systemAction, "D2:preview",
                  [p(.file, .nativeFile(.jsonSnapshot))])
                .requiring([.nativeFilePanel]),
            entry("data.applyImport", "/data/import/apply", .systemAction, "D2:apply",
                  [p(.file, .nativeFile(.jsonSnapshot))])
                .requiring([.nativeFilePanel, .unsavedChangesConfirmation]).risk([.dataImport]),
            entry("backup.export", "/backup/export", .systemAction, "D3:export",
                  [p(.file, .nativeFile(.encryptedBackup))])
                .requiring([.nativeFilePanel, .secureInput, .freshAuthentication]).unresolved("backupWithoutLock"),
            entry("backup.inspect", "/backup/inspect", .systemAction, "D3:inspect",
                  [p(.file, .nativeFile(.encryptedBackup))])
                .requiring([.nativeFilePanel, .secureInput]),
            entry("backup.preview", "/backup/preview", .systemAction, "D3:preview",
                  [p(.file, .nativeFile(.encryptedBackup))])
                .requiring([.nativeFilePanel, .secureInput, .freshAuthentication]),
            entry("backup.restore", "/backup/restore", .systemAction, "D3:restore",
                  [p(.file, .nativeFile(.encryptedBackup))])
                .requiring([.nativeFilePanel, .secureInput, .freshAuthentication]).risk([.backupRestore]),
            entry("recovery.status", "/recovery/status", .query, "D4:status"),
            entry("recovery.resetQuit", "/recovery/reset-quit", .systemAction, "D4:resetQuit")
                .risk([.permanentDeletion, .lifecycle]).unavailable("recoveryDesign"),
        ]
    }
}
