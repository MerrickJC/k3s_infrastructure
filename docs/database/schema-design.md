# Database Entity Design Notes

This document captures the reasoning behind the core entities in the Postgres
schema. The authoritative, up-to-date schema itself is exported as
`DatabaseSchema_2026-07-22T07_06_44.029Z.dbml` /
`DatabaseSchemaContinued_2026-07-22T07_47_17.852Z.json` in this folder — this
file explains *why* the entities are shaped the way they are.

## Entities

Entities break down into system entities and data storage entities:

**Data storage entities:**
- File stored in object storage
- Job run output
- Job run requests
- Analysis scripts stored in git

**System entities:**
- Object storage
- Git repository
- Git issues integration

A guiding principle across all of these: everything should be easy to
substitute. Changing which git repository a script is stored in, or where a
bag is stored, should never be a convoluted operation.

## Entity Breakdown

### Files

Tracks the central metadata for an object stored in the platform. The term
"files" is used instead of "bags" even though ROS bags (`.mcap`) are the
initial use case, so the system stays extensible to other file types.

| Field Name | Description |
| --- | --- |
| datetime | The date and time the file was created |
| testing session (relation) | The testing session the file was created during |
| type | The type of the file |
| additional metadata | A JSON-structured field holding whatever semi-structured data MMS wants to attach |

### Testing Session

Files recorded during the same session are logically grouped together.
Testing sessions can carry additional context: location, personnel,
environmental conditions, etc.

| Field Name | Description |
| --- | --- |
| date | The date the testing session occurred on |
| location (relation) | The location the testing session occurred at |
| personnel | The people present, typically those responsible for the session |
