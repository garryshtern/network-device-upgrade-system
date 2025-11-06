# Storage Cleanup Guide

**Last Updated**: November 4, 2025

Automated cleanup workflows for managing GitHub Container Registry images and workflow artifacts.

## Container Package Cleanup

### Current Container Build Reality
- **CI Builds**: Containers built on every push to main (via `ansible-tests.yml`)
- **Manual Builds**: Available via workflow dispatch
- **Release Builds**: Automatic builds triggered on GitHub releases
- **Result**: Frequent image creation requiring active cleanup

### Cleanup Strategy

**Automatic Schedule**: Weekly on Sundays at 2:00 AM UTC

**What Gets Deleted:**
- SHA-tagged images (`main-abc1234`) older than retention period
- Development/test builds
- Untagged architecture variants
- Obsolete multi-platform build artifacts

**What Gets Preserved:**
- ✅ **Semantic version releases** (`v1.4.0`, `v1.3.0`)
- ✅ **Important tags** (`latest`, `main`, `stable`)
- ✅ **Recent builds** (configurable retention period)

### Enhanced Cleanup Options

| Parameter | Default | Description |
|-----------|---------|-------------|
| `keep_latest` | `true` | Preserve latest and main tagged versions |
| `days_to_keep` | `7` | Keep versions newer than X days (0 = ignore age) |
| `max_deletions` | `50` | Safety limit on versions deleted per run |
| `aggressive_sha_cleanup` | `false` | Target SHA-only images older than 1 day |
| `dry_run` | `false` | Preview deletions without removing packages |

### Quick Usage Examples

**Preview cleanup (recommended first):**
```bash
# GitHub Actions → "Cleanup Container Packages" → Run workflow
confirm_deletion: DELETE
dry_run: true
```

**Standard cleanup:**
```bash
confirm_deletion: DELETE
days_to_keep: 3
max_deletions: 100
```

**Aggressive cleanup (for large backlogs):**
```bash
confirm_deletion: DELETE
aggressive_sha_cleanup: true
days_to_keep: 0
max_deletions: 150
```

## Workflow Artifacts Cleanup

**Purpose**: Removes GitHub Actions artifacts (test reports, SBOM files, build logs)
**Schedule**: Monthly on 1st day at 3:00 AM UTC
**Strategy**: Complete cleanup (no selective retention)

**Configuration:**
- `max_artifacts`: `50` (scheduled) / `100` (manual)
- `confirm_deletion`: Required for manual runs

**Manual Usage:**
```bash
# GitHub Actions → "Cleanup Artifacts" → Run workflow
confirm_deletion: DELETE
max_artifacts: 200
```

## When to Run Manual Cleanup

### Container Packages
- **High storage cost scenario**: Clean up large container image backlogs
- **Pre-release cleanup**: Remove development builds before major releases
- **Storage limit approaching**: Proactive cleanup when approaching quotas

### Workflow Artifacts
- **2GB limit approaching**: GitHub's artifact storage limit
- **Quarterly maintenance**: Regular cleanup schedule

## Best Practices

1. **Always dry-run first** for container cleanup
2. **Use aggressive SHA cleanup** for large image backlogs
3. **Monitor GitHub billing** for storage usage trends
4. **Never delete release versions** (automatically protected)

---
*For implementation details: `.github/workflows/cleanup-packages.yml` and `cleanup-artifacts.yml`*