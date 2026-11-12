# Nuke image loading migration

- [x] Replace SDWebImage CocoaPod with pinned Nuke/NukeExtensions Swift packages.
- [x] Share memory/disk caching across artwork views, operations and library export.
- [x] Preserve local-image loading, cancellation and background download grace.
- [x] Invalidate replaced covers/backdrops even when their URL stays the same.
- [x] Remove obsolete SDK imports, linker flags and attribution.
- [x] Verify image loading/cache behavior and the Delta Simulator build.

Nuke 12.8.0 supports the existing iOS 14 deployment target. Remote cache entries will repopulate under Nuke; original local artwork/save-state files remain authoritative.


Validation: Delta Debug arm64 generic iOS Simulator build passed. Sixteen focused checks run the production cache/request helper through an AppKit image adapter against the exact Nuke revision: local and HTTP PNGs, missing/invalid files, HTTP errors, same-URL replacement, shared memory/disk lookup for export, cancellation, and disk hits avoiding another HTTP request. No booted Simulator was available, so visual scrolling/reuse verification remains unperformed.

Run after resolving Swift packages:

```sh
python3 Tests/NukeMigration/run.py /path/to/SourcePackages/checkouts/Nuke
```

Remote image cache entries repopulate under Nuke. The old cache is expendable; downloaded originals and imported artwork/save-state files are not deleted. The pipeline uses a 150 MB disk-cache limit and Nuke's automatic memory-cache sizing. Covers, backdrops and exports share the same pipeline. Request generations isolate in-flight reads during artwork replacement. Save-state/file operations retain their synchronous ImageIO path; remote operations use Nuke with cancellation and background grace.

CocoaPods support files were regenerated with the remaining pod versions unchanged. Nuke and NukeExtensions are pinned to 12.8.0 through Swift Package Manager. Credits now name Nuke's author.
