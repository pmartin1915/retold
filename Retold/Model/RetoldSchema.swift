import Foundation
import SwiftData

/// Versioned from day one so R2+ schema changes get a migration stage, not a store wipe.
enum RetoldSchemaV1: VersionedSchema {
    static let versionIdentifier = Schema.Version(1, 0, 0)

    static var models: [any PersistentModel.Type] {
        [Period.self, Episode.self, Detail.self, Person.self, Place.self, Capture.self, Question.self]
    }
}

enum RetoldMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] { [RetoldSchemaV1.self] }
    static var stages: [MigrationStage] { [] }
}

enum RetoldSchema {
    static func makeInMemoryContainer() throws -> ModelContainer {
        try ModelContainer(
            for: Period.self, Episode.self, Detail.self, Person.self, Place.self, Capture.self, Question.self,
            migrationPlan: RetoldMigrationPlan.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }

    /// Creates `url`'s parent directory (withIntermediateDirectories: true) if missing, then
    /// opens the store there with the versioned migration plan.
    static func makeContainer(url: URL) throws -> ModelContainer {
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        return try ModelContainer(
            for: Period.self, Episode.self, Detail.self, Person.self, Place.self, Capture.self, Question.self,
            migrationPlan: RetoldMigrationPlan.self,
            configurations: ModelConfiguration(url: url)
        )
    }
}
