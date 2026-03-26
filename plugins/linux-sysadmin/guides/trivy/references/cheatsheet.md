# Trivy Cheatsheet

## Image Scanning

```bash
trivy image nginx:latest                     # scan image for vulns + secrets
trivy image alpine:3.20                      # scan specific tag
trivy image --input image.tar                # scan from tar archive
trivy image --platform linux/amd64 nginx     # scan specific platform
trivy image --image-src remote nginx         # pull directly (no local daemon)

# Filter by severity
trivy image --severity HIGH,CRITICAL nginx:latest
trivy image --severity CRITICAL --ignore-unfixed nginx:latest

# Select scanners
trivy image --scanners vuln nginx:latest                 # vulnerabilities only
trivy image --scanners vuln,secret nginx:latest          # vulns + secrets (default)
trivy image --scanners vuln,misconfig,secret nginx:latest # all scanners

# Output formats
trivy image --format json --output results.json nginx:latest
trivy image --format sarif --output results.sarif nginx:latest
trivy image --format table nginx:latest                   # default
trivy image --format template --template "@html.tpl" nginx:latest

# CI mode (exit code 1 on findings)
trivy image --exit-code 1 --severity HIGH,CRITICAL nginx:latest
trivy image --exit-code 1 --ignore-unfixed nginx:latest

# Skip specific CVEs
trivy image --skip-cves CVE-2024-1234,CVE-2024-5678 nginx:latest
```

## Filesystem Scanning

```bash
trivy fs .                                   # scan current directory
trivy fs /path/to/project                    # scan specific path
trivy fs --scanners vuln .                   # vulnerabilities only
trivy fs --scanners vuln,secret .            # vulns + secrets
trivy fs --scanners vuln,misconfig,secret .  # everything
trivy fs --severity HIGH,CRITICAL .
trivy fs --skip-dirs node_modules,vendor,.git .
trivy fs --skip-files package-lock.json .
trivy fs --format json --output results.json .
```

## Configuration / IaC Scanning

```bash
trivy config .                               # scan all IaC in current dir
trivy config /path/to/terraform              # scan Terraform files
trivy config /path/to/k8s                    # scan Kubernetes manifests

# Filter by IaC type
trivy config --misconfig-scanners terraform .
trivy config --misconfig-scanners dockerfile .
trivy config --misconfig-scanners kubernetes .
trivy config --misconfig-scanners cloudformation .
trivy config --misconfig-scanners helm .

# Severity filtering
trivy config --severity HIGH,CRITICAL .

# Custom policy checks
trivy config --config-check /path/to/policies .

# Output
trivy config --format json --output misconfig.json .
trivy config --exit-code 1 .                 # fail CI on findings
```

## Repository Scanning

```bash
trivy repo https://github.com/example/myapp         # scan remote repo
trivy repo --branch develop https://github.com/example/myapp
trivy repo --commit abc1234 https://github.com/example/myapp
trivy repo --tag v1.0.0 https://github.com/example/myapp
```

## Kubernetes Cluster Scanning

```bash
trivy kubernetes --report summary                    # summary of all findings
trivy kubernetes --report all                        # detailed findings
trivy kubernetes --namespace production              # scan specific namespace
trivy kubernetes --kubeconfig ~/.kube/config          # specify kubeconfig
trivy kubernetes --scanners vuln,misconfig,secret    # all scanners
trivy kubernetes --severity HIGH,CRITICAL            # filter severity
trivy kubernetes --format json --output k8s-scan.json
```

## SBOM Generation

```bash
# Generate CycloneDX SBOM from image
trivy image --format cyclonedx --output sbom.cdx.json nginx:latest

# Generate SPDX SBOM from image
trivy image --format spdx-json --output sbom.spdx.json nginx:latest

# Generate SBOM from filesystem
trivy fs --format cyclonedx --output sbom.cdx.json /path/to/project

# Scan an existing SBOM for vulnerabilities
trivy sbom sbom.cdx.json
trivy sbom --severity HIGH,CRITICAL sbom.cdx.json
trivy sbom --format json --output vuln-results.json sbom.cdx.json
```

## Database Management

```bash
# Download/update vulnerability DB only (no scan)
trivy image --download-db-only

# Clear all cached data (DB, Java index, etc.)
trivy clean --all

# Clear just the vulnerability DB
trivy clean --vuln-db

# Use custom DB mirror
trivy image --db-repository mirror.example.com/trivy-db nginx:latest

# Skip DB update (use cached only)
trivy image --skip-db-update nginx:latest

# Offline mode (requires pre-downloaded DB)
trivy image --skip-db-update --offline-scan nginx:latest
```

## .trivyignore File

One entry per line. Place at project root.

```
# .trivyignore — CVEs to suppress
CVE-2024-1234
CVE-2024-5678

# Misconfiguration check IDs
AVD-DS-0002
AVD-KSV-0001
```

For time-boxed ignores, use `.trivyignore.yaml`:

```yaml
# .trivyignore.yaml
vulnerabilities:
  - id: CVE-2024-1234
    expired_at: 2026-06-01
    reason: "Mitigated by WAF rule; vendor fix ETA Q2 2026"
  - id: CVE-2024-5678
    expired_at: 2026-04-15
    reason: "False positive for our usage"

misconfigurations:
  - id: AVD-DS-0002
    reason: "Root required for this specific container"
```

## CI/CD Integration Examples

### GitHub Actions

```yaml
- name: Trivy vulnerability scan
  uses: aquasecurity/trivy-action@master
  with:
    image-ref: 'myapp:${{ github.sha }}'
    format: 'sarif'
    output: 'trivy-results.sarif'
    severity: 'HIGH,CRITICAL'
    exit-code: '1'

- name: Upload Trivy scan results
  uses: github/codeql-action/upload-sarif@v3
  with:
    sarif_file: 'trivy-results.sarif'
```

### GitLab CI

```yaml
trivy-scan:
  image: aquasec/trivy:latest
  script:
    - trivy image --exit-code 1 --severity HIGH,CRITICAL
        --format json --output trivy-report.json
        $CI_REGISTRY_IMAGE:$CI_COMMIT_SHA
  artifacts:
    reports:
      container_scanning: trivy-report.json
```

### Generic CI Pipeline

```bash
# Pull DB once, cache it
trivy image --download-db-only --cache-dir /ci-cache/trivy

# Scan with cached DB
trivy image \
  --cache-dir /ci-cache/trivy \
  --skip-db-update \
  --exit-code 1 \
  --severity HIGH,CRITICAL \
  --ignore-unfixed \
  --format json \
  --output scan-results.json \
  myapp:latest
```

## Configuration File (trivy.yaml)

```yaml
# trivy.yaml — project-level defaults
severity:
  - HIGH
  - CRITICAL
exit-code: 1
ignore-unfixed: true
scanners:
  - vuln
  - secret
skip-dirs:
  - node_modules
  - vendor
  - .git
format: table
```

```bash
# Use config file explicitly
trivy image --config trivy.yaml nginx:latest

# Config is auto-detected from trivy.yaml in current directory
```

## Useful Flag Combinations

```bash
# Production image audit (comprehensive)
trivy image --scanners vuln,misconfig,secret,license \
  --severity HIGH,CRITICAL \
  --ignore-unfixed \
  --format json \
  --output audit.json \
  myapp:latest

# Quick dev check (fast, table output)
trivy image --severity CRITICAL --ignore-unfixed myapp:latest

# Pre-commit IaC check
trivy config --exit-code 1 --severity HIGH,CRITICAL .

# Full project scan (deps + secrets + IaC)
trivy fs --scanners vuln,misconfig,secret \
  --severity HIGH,CRITICAL \
  --exit-code 1 \
  --skip-dirs node_modules,.git \
  .
```
