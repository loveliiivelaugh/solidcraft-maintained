# ZIP extraction advisory applicability

Reviewed on 2026-10-22 against SolidCraft 6f5d0038abffbd3e1fc26069b1b96ca89984058f and the Cargo.lock checksum-verified registry sources. This is a scoped source assessment, not a claim that ZIP handling is free of defects.

## Affected component and conditions

ZIP 8.6.0 is used by cadmpeg-container, cadmpeg-codec-step and cadmpeg-codec-freecad 0.6.1. RUSTSEC-2026-0367, RUSTSEC-2026-0368 and RUSTSEC-2026-0369 affect filesystem extraction: archived SUID/SGID modes, archive symlink escapes, and following symlinks while applying permissions. ZIP >=9.0.0 is the published fixed range.

## Reviewed call paths

- `crates/io/src/native_cad.rs` passes document bytes to cadmpeg's bounded decoding context.
- `cadmpeg-container/src/archive.rs` uses `ZipArchive::new`, `name_for_index`, `central_directory_start` and `len` for namespace admission. `ArchiveSnapshot::open` returns borrowed or budgeted decompressed memory views. It does not materialize archive paths, links or permissions on disk.
- cadmpeg-codec-step's production ZIP use creates an in-memory `ZipWriter`. cadmpeg-codec-freecad's builders/writers create output archives; reading flows through the bounded container. The registry sources contain no calls to `ZipArchive::extract` or `ZipStreamReader::extract`.
- The workspace's direct ZIP consumers already use ZIP 9.0.4. `crates/ui-egui/src/update/install.rs::unzip_one` reads one selected entry, enforces size limits and copies to an explicit destination. The caller applies a fixed mode separately. Other first-party ZIP consumers read entries rather than bulk-extracting them.

Conclusion for these three advisories: **affected extraction code not in the reviewed application call paths**. The vulnerable component remains present, but the necessary filesystem-extraction operation was not found. Reassess on any dependency, feature or ZIP call-path change; this result is not a blanket acceptance of malicious CAD documents.

## Resolution

Keep the bounded in-memory APIs and the existing narrowly documented advisory exceptions. Update the three pinned cadmpeg consumers to a supported ZIP 9.x dependency when their compatible release is available. Do not change `zip = "8"` to a major version or vendor three codec crates solely to make an advisory scan green. If filesystem extraction is introduced, require ZIP >=9, private destination directories and explicit traversal/link/mode regression coverage before accepting that path.

The associated cgmath unsoundness is a separate dependency defect with a separate patch. Build/test results for the combined security candidate are tracked by Maintained; source inspection alone is not runtime validation.
