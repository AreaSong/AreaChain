import Foundation

struct AttachmentSyntaxToken: Equatable, Sendable {
    let name: String
    let range: NSRange
}

struct UnlinkedAttachmentEntry: Codable, Identifiable, Equatable, Hashable, Sendable {
    var id: UUID
    var filename: String
    var createdAt: Date

    var reference: AttachmentRef {
        AttachmentRef(id: id, filename: filename, storageID: id)
    }
}

struct AttachmentReferenceTag: Identifiable, Equatable, Hashable, Sendable {
    let id: UUID
    let name: String
    let colorToken: TagColorToken
}

struct AttachmentReferenceItem: Identifiable, Equatable, Hashable, Sendable {
    var id: String { "\(kind.rawValue)-\(ownerID.uuidString)" }
    let attachmentID: UUID
    let kind: AttachmentOwner
    let ownerID: UUID
    let title: String
    let dayKey: String?
    let tags: [AttachmentReferenceTag]
    let isImportant: Bool
    let isUrgent: Bool
    let remindMinutes: Int?
    let isDone: Bool
    let sourceBundleID: String
    let createdAt: Date

    init(
        attachmentID: UUID,
        kind: AttachmentOwner,
        ownerID: UUID,
        title: String,
        dayKey: String?,
        tags: [AttachmentReferenceTag],
        isImportant: Bool = false,
        isUrgent: Bool = false,
        remindMinutes: Int? = nil,
        isDone: Bool = false,
        sourceBundleID: String = "",
        createdAt: Date
    ) {
        self.attachmentID = attachmentID
        self.kind = kind
        self.ownerID = ownerID
        self.title = title
        self.dayKey = dayKey
        self.tags = tags
        self.isImportant = isImportant
        self.isUrgent = isUrgent
        self.remindMinutes = remindMinutes
        self.isDone = isDone
        self.sourceBundleID = sourceBundleID
        self.createdAt = createdAt
    }
}

struct AttachmentLibraryItem: Identifiable, Equatable, Hashable, Sendable {
    let storageID: UUID
    var allStorageIDs: [UUID]
    let primaryReference: AttachmentRef
    var filename: String
    let createdAt: Date
    let attachmentItemIDs: [UUID]
    let isInUnlinkedPool: Bool
    let references: [AttachmentReferenceItem]

    init(
        storageID: UUID,
        allStorageIDs: [UUID]? = nil,
        primaryReference: AttachmentRef,
        filename: String,
        createdAt: Date,
        attachmentItemIDs: [UUID],
        isInUnlinkedPool: Bool,
        references: [AttachmentReferenceItem]
    ) {
        self.storageID = storageID
        self.allStorageIDs = allStorageIDs ?? [storageID]
        self.primaryReference = primaryReference
        self.filename = filename
        self.createdAt = createdAt
        self.attachmentItemIDs = attachmentItemIDs
        self.isInUnlinkedPool = isInUnlinkedPool
        self.references = references
    }

    var id: UUID { primaryReference.id }
    var isUnlinked: Bool { references.isEmpty }
    var referenceCount: Int { references.count }
}

enum AttachmentFilterKind: String, CaseIterable, Identifiable, Sendable {
    case all
    case todo
    case routine
    case diary
    case unlinked

    var id: String { rawValue }
}

enum AttachmentSortOrder: String, CaseIterable, Identifiable, Sendable {
    case newest
    case oldest
    case name
    case referenceCount

    var id: String { rawValue }
}

enum AttachmentViewMode: String, CaseIterable, Identifiable, Sendable {
    case grid
    case list
    case columns
    case gallery

    var id: String { rawValue }

    var iconName: String {
        switch self {
        case .grid: "square.grid.2x2"
        case .list: "list.bullet"
        case .columns: "rectangle.split.3x1"
        case .gallery: "squares.below.rectangle"
        }
    }

    var titleKey: String {
        switch self {
        case .grid: "attachments.viewMode.grid"
        case .list: "attachments.viewMode.list"
        case .columns: "attachments.viewMode.columns"
        case .gallery: "attachments.viewMode.gallery"
        }
    }
}

/// 附件 `@` 引用语法、防重名默认命名与以附件为主体的聚合筛选排序投影。
enum AttachmentSyntax {
    private static let tokenPattern =
        #"(?<![^\s(\[（【])[@＠]"#
        + ##"(?:"((?:\\.|[^"\\\r\n])+)"|([\p{L}\p{M}\p{N}_\-]+(?:\.[\p{L}\p{M}\p{N}_\-]+)*))"##
        + #"(?=$|[\s,，.。;；:：!！?？)）\]】])"#
    private static let expression = CompiledRegularExpression.make(tokenPattern)
    private static let timePresetWords: Set<String> = [
        "早上", "上午", "中午", "下午", "傍晚", "晚上",
        "morning", "noon", "afternoon", "evening", "night"
    ]

    static func normalizedName(_ name: String) -> String {
        TagSyntax.normalizedName(name)
    }

    static func tokens(in text: String) -> [AttachmentSyntaxToken] {
        let source = text as NSString
        let protected = TagSyntax.protectedRanges(in: text)
        return expression.matches(in: text, range: NSRange(location: 0, length: source.length)).compactMap { match in
            guard !protected.contains(where: { NSIntersectionRange($0, match.range).length > 0 }) else { return nil }
            let raw = source.substring(with: match.range)
            let name = TagSyntax.decodedName(String(raw.dropFirst())).trimmingCharacters(in: .whitespacesAndNewlines)
            guard isValidAttachmentTokenName(name) else { return nil }
            return AttachmentSyntaxToken(name: name, range: match.range)
        }
    }

    static func names(in text: String) -> [String] {
        TagSyntax.uniqueNames(tokens(in: text).map(\.name))
    }

    static func spelling(for filename: String) -> String {
        let trimmed = filename.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.range(of: #"^[\p{L}\p{M}\p{N}_\-]+(?:\.[\p{L}\p{M}\p{N}_\-]+)*$"#, options: .regularExpression) != nil {
            return "@" + trimmed
        }
        let quoted = (try? JSONEncoder().encode(trimmed)).flatMap { String(data: $0, encoding: .utf8) } ?? "\"\""
        return "@" + quoted
    }

    static func uniqueFilename(base: String, existing: [String]) -> String {
        let trimmed = base.trimmingCharacters(in: .whitespacesAndNewlines)
        let fallback = trimmed.isEmpty ? "paste.png" : trimmed
        let normalizedExisting = Set(existing.map(normalizedName))
        if !normalizedExisting.contains(normalizedName(fallback)) {
            return fallback
        }
        let (stem, ext) = splitExtension(fallback)
        var index = 2
        while true {
            let candidate = ext.isEmpty ? "\(stem)-\(index)" : "\(stem)-\(index).\(ext)"
            if !normalizedExisting.contains(normalizedName(candidate)) {
                return candidate
            }
            index += 1
        }
    }

    static func sanitizedFilename(_ candidate: String, fallback: String) -> String {
        let cleaned = candidate
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: "\\", with: "-")
            .replacingOccurrences(of: ":", with: "-")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return fallback }
        let (_, candidateExt) = splitExtension(cleaned)
        let (_, fallbackExt) = splitExtension(fallback)
        if candidateExt.isEmpty, !fallbackExt.isEmpty {
            return "\(cleaned).\(fallbackExt)"
        }
        return cleaned
    }

    private static func isValidAttachmentTokenName(_ name: String) -> Bool {
        guard !name.isEmpty else { return false }
        if NaturalLanguageParser.timeMinutes("@" + name) != nil { return false }
        let lowered = name.lowercased()
        if timePresetWords.contains(lowered) { return false }
        if name.allSatisfy(\.isNumber) { return false }
        return true
    }

    private static func splitExtension(_ filename: String) -> (stem: String, ext: String) {
        guard let dot = filename.lastIndex(of: "."), dot > filename.startIndex else {
            return (filename, "")
        }
        let stem = String(filename[..<dot])
        let ext = String(filename[filename.index(after: dot)...])
        return (stem, ext)
    }
}
