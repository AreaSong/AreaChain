import Foundation

extension CommandCatalogBuilder {
    static var content: [CommandDescriptor] {
        [
            entry("diary.create", "/diaries/add", .modification, "J1:create J1:classify",
                  [p(.body, .longText), day, tags.optional()])
                .ordinary(),
            entry("diary.body", "/diaries/body", .modification, "J1:body",
                  [body])
                .targets([.diary], batch: .explicitMultiple).ordinary().requiring([.authentication, .independentConfirmation]),
            entry("diary.save", "/diaries/save", .interaction, "J1:save")
                .targets([.diary]).requiring([.authentication]),
            entry("diary.reload", "/diaries/reload", .interaction, "J1:reload")
                .targets([.diary]).requiring([.unsavedChangesConfirmation]),
            entry("diary.discard", "/diaries/discard", .interaction, "J1:discard")
                .targets([.diary]).requiring([.unsavedChangesConfirmation]),
            entry("diary.tags", "/diaries/tags", .modification, "J1:tags J2:tags",
                  [tags])
                .targets([.diary], batch: .explicitMultiple).requiring([.authentication]).unresolved("privateTagTransition"),
            entry("diary.pinned", "/diaries/pinned", .modification, "J2:pin J2:unpin",
                  [p(.enabled, .boolean)])
                .targets([.diary], batch: .explicitMultiple).ordinary(),
            entry("diary.move", "/diaries/move", .modification, "J2:move",
                  [day])
                .targets([.diary], batch: .explicitMultiple).ordinary(),
            entry("diary.reveal", "/diaries/reveal", .interaction, "J2:reveal")
                .targets([.diary]).requiring([.authentication]),
            entry("diary.mask", "/diaries/mask", .interaction, "J2:mask")
                .targets([.diary]),
            entry("diary.privateMark", "/diaries/private-mark", .systemAction, "J2:privateMark",
                  [p(.enabled, .boolean)])
                .targets([.diary]).requiring([.authentication, .independentConfirmation]),
            entry("diary.copy", "/diaries/copy", .systemAction, "J3:copyRecord J3:copyTitle J3:copyNotes",
                  [choice(.section, "record title notes").defaulting(to: .choice("record"))])
                .targets([.diary]).requiring([.authentication]).risk([.externalEffect]),
            entry("diary.toTodo", "/diaries/to-task", .modification, "J3:toTodo")
                .targets([.diary]).ordinary().requiring([.independentConfirmation]),
            entry("diary.trash", "/diaries/trash", .modification, "J3:trash")
                .targets([.diary]).ordinary().requiring([.authentication, .independentConfirmation]),
            entry("tag.create", "/tags/add", .modification, "G1:create",
                  [p(.name, .shortText)])
                .ordinary(),
            entry("tag.cancel", "/tags/cancel", .interaction, "G1:cancel"),
            entry("tag.rename", "/tags/rename", .modification, "G1:rename",
                  [p(.name, .shortText)])
                .targets([.tag]).ordinary(),
            entry("tag.color", "/tags/color", .modification, "G1:color",
                  [p(.color, .choice(TagColorToken.allCases.map { CommandChoice(value: $0.rawValue) }))])
                .targets([.tag], batch: .explicitMultiple).ordinary(),
            entry("tag.order", "/tags/order", .modification, "G1:order")
                .targets([.tag], batch: .explicitMultiple).ordinary(),
            entry("tag.search", "/tags/search", .query, "G1:search",
                  [p(.query, .shortText)]),
            entry("tag.view", "/tags/view", .query, "G1:all G1:frequent G1:recent G1:unused",
                  [choice(.kind, "all frequent recent unused")]),
            entry("tag.deleted", "/trash/tags", .query, "G1:deleted")
                .scope(.trash),
            entry("tag.merge", "/tags/merge", .modification, "G2:merge",
                  [p(.destination, .object([.tag]))])
                .targets([.tag], batch: .explicitMultiple).unresolved("privateTagMerge"),
            entry("tag.unlinkObject", "/tags/unlink-object", .modification, "G2:unlinkObject",
                  [p(.tags, .tags)])
                .targets([.todo, .routine, .subtask, .diary], batch: .explicitMultiple).ordinary(),
            entry("tag.unlinkGlobal", "/tags/unlink-global", .modification, "G2:unlinkGlobal")
                .targets([.tag]).unavailable("globalUnlink"),
            entry("tag.trash", "/tags/trash", .modification, "G2:trash")
                .targets([.tag]).ordinary().requiring([.independentConfirmation]),
            entry("tag.restore", "/tags/restore", .systemAction, "G2:restore")
                .targets([.tag]).requiring([.independentConfirmation]),
            entry("tag.delete", "/tags/delete", .systemAction, "G2:delete")
                .targets([.tag]).risk([.permanentDeletion]),
            entry("tag.cleanup", "/tags/cleanup", .modification, "G2:cleanup")
                .targets([.tag], batch: .explicitMultiple).unresolved("presetCleanup"),
            entry("image.pick", "/images/add", .systemAction, "A1:pick",
                  [p(.file, .nativeFile(.image))])
                .targets([.todo, .routine, .diary]).requiring([.nativeFilePanel, .authentication]),
            entry("image.paste", "/images/paste", .systemAction, "A1:paste")
                .targets([.todo, .routine, .diary]).requiring([.authentication]),
            entry("image.capture", "/images/capture", .systemAction, "A1:capture")
                .targets([.todo, .routine]).requiring([.systemPermission]),
            entry("image.preview", "/images/preview", .systemAction, "A1:preview")
                .targets([.image]).requiring([.authentication]),
            entry("image.browse", "/images/browse", .query, "A1:browse",
                  [choice(.kind, "all todo routine diary").defaulting(to: .choice("all"))])
                .scope(.images),
            entry("image.trash", "/images/trash", .modification, "A1:trash")
                .targets([.image]).ordinary().requiring([.independentConfirmation, .authentication]),
        ]
    }
}
