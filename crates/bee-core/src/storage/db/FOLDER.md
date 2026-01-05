# storage/db

- attachments.rs: CRUD for task attachments and attachment data.
- blocking.rs: Dependency/blocking logic and task ID resequencing.
- connection.rs: Database connection helpers.
- external_links.rs: CRUD and sync status for external links.
- filter_sql.rs: Filter-to-SQL translation helpers.
- mod.rs: DbStore implementation and module exports.
- sync_relations.rs: Sync logic for annotations, history, links, tags, email links.
- tables/: SeaORM entity/table definitions for DB models.
- task_read.rs: Task loading and query helpers.
- task_write.rs: Task persistence and write pipeline.
- undo.rs: Undo log storage.
- user_reports.rs: User report persistence.
