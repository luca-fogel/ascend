import Foundation
import SwiftData
import AscendDomain

/// The store's shape, versioned from day one.
///
/// `VersionedSchema` costs about ten lines and is the only thing that makes a future property
/// rename expressible as a migration rather than a guess. Shipping v1 without it means the
/// first schema change has no "from" to migrate out of.
public enum AscendSchemaV1: VersionedSchema {
    // Bumped from 1.0.0 when every model's `id: UUID` was renamed to `uuid: UUID` (it collided
    // with the `id: PersistentIdentifier` that `PersistentModel` already supplies).
    //
    // That was a BREAKING store change with no migration, and it is recorded here rather than
    // glossed over: opening a 1.0.0 store with this schema logs hundreds of
    // `com.apple.coredata:error` entries while it fails to reconcile the missing column. A
    // virgin store is clean -- verified by erasing a simulator and counting zero on both first
    // and second launch.
    //
    // No migration plan is provided on purpose. Ascend has never shipped, so the only affected
    // stores are development installs, and a `SchemaMigrationPlan` for a schema no user has
    // would be dead code pretending to be diligence. The next schema change, once there are
    // real users, does need one -- and this version identifier is what it will migrate from.
    public static var versionIdentifier: Schema.Version { Schema.Version(1, 1, 0) }

    public static var models: [any PersistentModel.Type] {
        [
            UserProfile.self,
            SkillTree.self,
            Goal.self,
            Milestone.self,
            QuestTask.self,
            Habit.self,
            Boss.self,
            CompletionLog.self,
        ]
    }
}

public enum AscendStore {
    public static var schema: Schema { Schema(versionedSchema: AscendSchemaV1.self) }

    /// The app's on-disk container.
    ///
    /// No `cloudKitDatabase` argument, and no `.unique` attributes anywhere in the schema --
    /// the two are related. SwiftData rejects any container that combines unique attributes
    /// with CloudKit, so keeping `.unique` out of the models is what leaves iCloud sync
    /// available as a later decision instead of a rewrite.
    public static func container() throws -> ModelContainer {
        try ModelContainer(for: schema)
    }

    /// The container every test uses. No file, no Application Support directory, no bundle --
    /// which is why the whole engine suite runs under `swift test` in milliseconds.
    public static func inMemoryContainer() throws -> ModelContainer {
        try ModelContainer(for: schema,
                           configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    }
}
