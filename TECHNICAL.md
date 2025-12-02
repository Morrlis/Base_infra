# E2E Base Image — Technical Documentation

## Overview

This repository provides a **base Docker image** for E2E (end-to-end) testing of web applications. The image includes Playwright with pre-installed browsers (Chromium, Firefox, WebKit) and all system dependencies required for browser automation in containerized environments.

**Purpose:** Centralize browser installation to avoid redundant downloads and disk usage across multiple projects.

**Target audience:** Python web applications using Playwright for E2E testing.

---

## Architecture

### Design Pattern: Docker Base Image Inheritance

```
┌──────────────────────────────────────┐
│ mcr.microsoft.com/playwright/python  │  ← Upstream (Microsoft)
│         (Ubuntu Noble, Python 3.12)  │
└──────────────┬───────────────────────┘
               │ FROM
               ▼
┌──────────────────────────────────────┐
│   ghcr.io/morli/e2e-base:v1.51.0    │  ← This repository
│   + curl, git, vim                   │
│   + pip 24.0, setuptools, wheel      │
└──────────────┬───────────────────────┘
               │ FROM (in project repos)
               ▼
┌──────────────────────────────────────┐
│   Project: Harbor                    │
│   + FastAPI app dependencies         │
│   + Application code                 │
└──────────────────────────────────────┘
```

### Benefits

1. **Layer Caching:** Browser binaries (~1.2 GB) are shared across all projects via Docker layer caching
2. **Build Speed:** Projects inherit pre-installed browsers → build time reduced from ~10 min to ~2 min
3. **Isolation:** Each project has its own container with isolated dependencies (no conflicts)
4. **Version Control:** Projects pin specific base image versions for reproducibility

---

## Technical Specifications

### Base Image

- **Upstream:** `mcr.microsoft.com/playwright/python:v1.51.0-noble`
- **OS:** Ubuntu 24.04 LTS (Noble Numbat)
- **Python:** 3.12
- **Playwright:** 1.51.0
- **Browsers:**
  - Chromium 130.0.6723.31 (bundled with Playwright)
  - Firefox 131.0
  - WebKit 18.2

### Pre-installed Tools

```dockerfile
# System packages
- curl 8.5.0
- wget 1.21.4
- git 2.43.0
- vim 9.1

# Python packages
- pip 24.0
- setuptools 69.0.3
- wheel 0.42.0
```

### Image Size

- **Compressed:** ~650 MB (published to GHCR)
- **Uncompressed:** ~1.5 GB (on disk after pull)
- **Delta per project:** ~200-400 MB (application code + dependencies)

### Disk Usage Example

```
Without base image (3 projects):
  Project 1: 1.7 GB
  Project 2: 1.7 GB
  Project 3: 1.7 GB
  Total: 5.1 GB

With base image (3 projects):
  Base layer (shared): 1.5 GB
  Project 1 delta: 0.2 GB
  Project 2 delta: 0.3 GB
  Project 3 delta: 0.15 GB
  Total: 2.15 GB (58% savings)
```

---

## CI/CD Pipeline

### Workflow: `.github/workflows/build-and-push.yml`

**Trigger conditions:**
1. Git tag push matching `v*` pattern (e.g., `v1.51.0`)
2. Manual workflow dispatch via GitHub Actions UI

**Steps:**
1. Checkout repository
2. Setup Docker Buildx (for efficient multi-stage builds)
3. Authenticate to GitHub Container Registry (GHCR)
4. Build image with caching (uses GitHub Actions cache)
5. Push to GHCR with two tags:
   - Versioned tag: `ghcr.io/morli/e2e-base:v1.51.0`
   - Latest tag: `ghcr.io/morli/e2e-base:latest`

**Build time:** ~10 minutes (first build), ~5 minutes (with cache)

**Cache strategy:** GitHub Actions cache (`type=gha`) caches Docker layers between builds

---

## Usage in Projects

### Example: Integrating with Harbor Project

**Before (Harbor/infra/Dockerfile):**
```dockerfile
FROM python:3.12-slim

# Install Playwright
RUN pip install playwright==1.51.0

# Download browsers (~10 minutes, 1.2 GB)
RUN playwright install --with-deps chromium

# Application code...
COPY requirements.txt .
RUN pip install -r requirements.txt
COPY . .
```

**After (Harbor/infra/Dockerfile):**
```dockerfile
# Use pre-built base image with browsers
FROM ghcr.io/morli/e2e-base:v1.51.0

# Application code...
COPY requirements.txt .
RUN pip install -r requirements.txt
COPY . .
```

**Result:**
- Build time: 10 min → 2 min
- No browser downloads (inherited from base)
- Disk usage: 1.7 GB → 1.5 GB (shared) + 0.2 GB (delta)

### Playwright Test Configuration

**tests/e2e/conftest.py (simplified):**
```python
import pytest
from playwright.async_api import async_playwright

@pytest.fixture(scope="function")
async def browser():
    """Browser fixture - works out of the box with base image."""
    async with async_playwright() as p:
        # No need for executable_path or custom args!
        browser = await p.chromium.launch(headless=True)
        yield browser
        await browser.close()
```

**Before (with system Chromium workaround):**
```python
browser = await p.chromium.launch(
    headless=True,
    executable_path="/usr/bin/chromium",  # ← Not needed!
    args=["--no-sandbox", "--disable-gpu", ...]  # ← Not needed!
)
```

---

## Version Management

### Semantic Versioning

Tags follow Playwright version: `v{playwright_version}`

- `v1.51.0` → Playwright 1.51.0
- `v1.52.0` → Playwright 1.52.0

### Update Workflow

1. **Check new Playwright release:**
   ```bash
   curl -s https://api.github.com/repos/microsoft/playwright-python/releases/latest | jq -r .tag_name
   ```

2. **Update Dockerfile:**
   ```dockerfile
   FROM mcr.microsoft.com/playwright/python:v1.52.0-noble
   ```

3. **Tag and push:**
   ```bash
   git add Dockerfile
   git commit -m "chore: upgrade to Playwright 1.52.0"
   git tag v1.52.0
   git push origin main --tags
   ```

4. **Wait for CI/CD:** GitHub Actions builds and pushes new image (~10 min)

5. **Update projects:**
   ```bash
   # In each project (Harbor, etc.)
   sed -i 's/e2e-base:v1.51.0/e2e-base:v1.52.0/' infra/Dockerfile
   git commit -am "chore: upgrade E2E base image to v1.52.0"
   ```

### Version Pinning Strategy

**Production projects:** Pin to specific version
```dockerfile
FROM ghcr.io/morli/e2e-base:v1.51.0  # ← Reproducible builds
```

**Development projects:** Use `latest` for bleeding edge
```dockerfile
FROM ghcr.io/morli/e2e-base:latest  # ← Auto-updates
```

---

## Troubleshooting

### Issue: Image pull fails with authentication error

**Error:**
```
Error response from daemon: Head "https://ghcr.io/v2/morli/e2e-base/manifests/v1.51.0":
unauthorized: authentication required
```

**Solution:**
```bash
# Authenticate to GHCR
echo $GITHUB_TOKEN | docker login ghcr.io -u morli --password-stdin

# Or use GitHub CLI
gh auth login
```

### Issue: CI/CD workflow fails with permission error

**Error:**
```
Error: buildx failed with: ERROR: failed to solve: failed to push:
insufficient_scope: authorization failed
```

**Solution:**
1. Go to repository Settings → Actions → General
2. Under "Workflow permissions" select "Read and write permissions"
3. Re-run workflow

### Issue: Browser version mismatch warning

**Warning:**
```
playwright._impl._api_types.Error: Chromium version 130.0.6723.31 is not supported
```

**Cause:** Project uses different Playwright version than base image

**Solution:** Align versions
```bash
# Check base image Playwright version
docker run ghcr.io/morli/e2e-base:v1.51.0 playwright --version
# Output: Version 1.51.0

# Update project requirements.txt
playwright==1.51.0  # ← Match base image version
```

---

## Performance Benchmarks

### Build Time Comparison

| Scenario | Time | Details |
|----------|------|---------|
| Without base image (cold) | ~12 min | Download browsers + install deps + build app |
| Without base image (warm) | ~10 min | Docker cache helps, but still downloads browsers |
| With base image (first pull) | ~8 min | Pull base image (1.5 GB) + install deps + build app |
| With base image (cached) | ~2 min | Base layer cached, only app code changes |

### Disk Usage Comparison

| Configuration | Disk Usage | Savings |
|---------------|------------|---------|
| 1 project without base | 1.7 GB | - |
| 3 projects without base | 5.1 GB | - |
| 1 project with base | 1.7 GB (1.5 + 0.2) | 0% |
| 3 projects with base | 2.15 GB (1.5 + 0.65) | **58%** |

---

## Security Considerations

### Image Provenance

- **Upstream:** Microsoft Playwright official images (trusted source)
- **Registry:** GitHub Container Registry (GHCR) with package signing
- **Visibility:** Public images (can be pulled anonymously)

### Vulnerability Scanning

```bash
# Scan base image for CVEs
docker scout cves ghcr.io/morli/e2e-base:v1.51.0

# Or use Trivy
trivy image ghcr.io/morli/e2e-base:v1.51.0
```

### Best Practices

1. **Pin versions:** Use specific tags (`v1.51.0`) instead of `latest` in production
2. **Regular updates:** Update base image monthly to get security patches
3. **Minimal surface:** Base image only includes essential tools (no unnecessary packages)
4. **No secrets:** Never bake credentials into base image

---

## Alternative Architectures (Not Implemented)

### 1. Shared Executor Container

**Concept:** One long-running container executes tests for all projects

**Rejected because:**
- Dependency conflicts between projects
- No isolation (one project can break another)
- Complex volume mounting
- Not scalable

### 2. Browser Provider (Remote Execution)

**Concept:** Browsers run in separate container, accessed via Playwright Remote API

**Rejected because:**
- Playwright doesn't officially support remote execution
- Requires third-party tools (Selenium Grid, Browserless.io)
- Network latency overhead
- Overkill for local development

### 3. Volume-mounted Browser Cache

**Concept:** Mount `/ms-playwright` as a volume shared across projects

**Rejected because:**
- Permissions issues across containers
- Race conditions (concurrent access)
- No version isolation (one project updates, breaks others)
- Harder to clean up

---

## References

- [Playwright Python Docs](https://playwright.dev/python/)
- [Microsoft Playwright Docker Images](https://mcr.microsoft.com/en-us/artifact/mar/playwright/python/tags)
- [Docker Multi-stage Builds](https://docs.docker.com/build/building/multi-stage/)
- [GHCR Documentation](https://docs.github.com/en/packages/working-with-a-github-packages-registry/working-with-the-container-registry)
- [Docker Layer Caching](https://docs.docker.com/build/cache/)

---

## Maintenance Schedule

- **Monthly:** Check for new Playwright releases
- **Quarterly:** Scan for vulnerabilities and update dependencies
- **Annually:** Review architecture and consider upstream changes

---

## Changelog

### v1.51.0 (2025-12-02)
- Initial release
- Playwright 1.51.0
- Python 3.12
- Ubuntu Noble base

---

**Document version:** 1.0.0
**Last updated:** 2025-12-02
**Maintainer:** morli
