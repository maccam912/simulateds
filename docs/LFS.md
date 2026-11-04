# Binary assets and Git LFS

Install [Git LFS](https://git-lfs.com/) before cloning or updating this project:

```sh
git lfs install
git clone https://github.com/maccam912/simulateds.git
cd simulateds
git lfs pull
python3 tools/check_assets.py
python3 tools/setup.py
```

`.gitattributes` tracks binary images, model/source files, audio, fonts, videos,
archives, and binary Godot resources with LFS. Scripts, SVG, JSON/glTF, `.tscn`,
`.tres`, import settings, licenses, and provenance remain ordinary text in Git.
Use lowercase asset extensions. Generated engine imports and build outputs stay
ignored. CI hydrates LFS objects before validation or Godot import.

When adding assets, add their source/provenance and regenerated output together.
Use `git add` normally: the index stores the pointer, and the working copy retains
the complete file. Run `python3 tools/check_assets.py` after staging and before
committing. For an unstaged asset/attribute review, add `--worktree-only`. The
checker rejects binary files without LFS coverage, raw binary contents in the
index, and unresolved pointers in the working tree. Run `git lfs fsck` to check
the local object store and `git lfs ls-files` to inspect tracked assets.

For a new binary format, add its extension with `git lfs track '*.extension'`,
stage `.gitattributes`, and stage the asset. If already staged before its LFS
rule, run `git add --renormalize path/to/asset`. Do not add engine caches, native
build libraries, credentials, or packaged releases merely because LFS can store
them. The pre-push hook installed by `git lfs install` uploads referenced objects.

## Existing clones after the history migration

The migration changes commit IDs. Keep any local work in a separate backup,
then make a fresh clone with Git LFS installed. Reapply intentional source changes
to that new clone; do not merge the old main history into the rewritten branch.
Keep the old clone until local work and downloaded assets have been checked.
An ordinary pull does not replace the obsolete history. GitHub's source ZIP is
not a substitute for a verified LFS clone.

## November 4, 2026 migration

The conversion rewrote 71 commits, including the first 3D conversion commit.
The [audit](lfs-migration/audit.json) verified all 33 historical raw binary
versions against their LFS objects, verified 75 total historical LFS objects,
and checked that file bytes, modes, commit metadata and parent correspondence
were preserved. Only `.gitattributes` changed beyond replacing binaries with
pointers. The [commit map](lfs-migration/commit-map.csv) records old/new IDs.

The original remote main was `a1e8fba57e5a68d6f7ba8772ee10410acf82d0b8`.
The 3D source commit maps from `1f8a6bb6a733d2a8cd669e22fc1dece70c331d28`
to `81a5465` (see the map for the full hash). Later documentation commits do not
require another rewrite. Recovery bundles and LFS bytes were retained outside
the checkout; see the local backup location in `HANDOFF.md`.

## Migration maintenance

A history rewrite is a coordinated repository-maintenance operation. Preserve a
complete bundle and a remote-ref snapshot outside the checkout first, commit all
intended work, and verify the worktree is clean. Migrate every reachable branch
and tag with `git lfs migrate import --everything`, using an explicit binary
extension include list and `--object-map=/outside/repo/commit-map.csv`. The map
retains old/new commit correspondence; do not prune old objects before auditing.
`--everything` considers all refs, but only local refs are updated;
remote-tracking refs remain at their old values until the remote is updated.
Local tool checkpoint refs can also retain old history and are not publication
targets. Keep the recovery bundle and audit records outside the normal repo.

Run `python3 tools/audit_lfs_migration.py /outside/repo/commit-map.csv --output
/outside/repo/audit.json` (one line). It verifies every mapped tree, asset bytes,
local LFS contents, commit messages/authors, and remapped parents; only the root
`.gitattributes` is allowed to differ. Then run `git lfs fsck`, the asset checker,
and game validation. Upload with `git lfs push --all origin main` before publishing
rewritten refs. Check that remote refs still match the saved snapshot, then use
an atomic push with explicit per-ref `--force-with-lease` expected old hashes.
Verify remote parity and hydrate a fresh clone before considering publication
complete. Never force-push a remote change that was not in the saved snapshot.

The underlying behavior is documented by
[Git LFS migrate](https://github.com/git-lfs/git-lfs/blob/main/docs/man/git-lfs-migrate.adoc)
and [Actions checkout](https://github.com/actions/checkout#usage).
