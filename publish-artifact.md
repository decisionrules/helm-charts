# Publishing Helm Chart to Artifact Hub via GitHub Pages

This guide describes how to publish a Helm chart to **Artifact Hub** when the Helm repository is hosted using **GitHub Pages**.

Artifact Hub does not host Helm charts directly. It indexes an existing public Helm repository by reading its `index.yaml`.

---

## Prerequisites

Before publishing the chart to Artifact Hub, make sure you have:

- A valid Helm chart
- GitHub Pages enabled for the repository
- A public Helm repository URL
- Helm installed locally
- Access to push changes to the GitHub repository

Example Helm repository URL:

```text
https://<github-org>.github.io/<repository-name>
```

Example:

```text
https://decisionrules.github.io/helm-charts
```

---

## 1. Go to the Helm Chart Directory

Navigate to the folder where the Helm chart is located.

Example:

```bash
cd charts/decisionrules
```

The chart folder should contain at least:

```text
Chart.yaml
values.yaml
templates/
```

---

## 2. Validate the Helm Chart

Run Helm lint to validate the chart structure and detect common issues.

```bash
helm lint .
```

If the chart is valid, Helm should return a success message similar to:

```text
1 chart(s) linted, 0 chart(s) failed
```

If there are errors, fix them before continuing.

---

## 3. Package the Helm Chart

Go back to the Helm repository output folder, or package the chart directly into the folder served by GitHub Pages.

Example:

```bash
cd ../..
mkdir -p docs
helm package charts/decisionrules --destination docs
```

This creates a `.tgz` package, for example:

```text
docs/decisionrules-1.0.0.tgz
```

The package version is taken from the `version` field in `Chart.yaml`.

Example:

```yaml
version: 1.0.0
appVersion: "1.25.1.0"
```

---

## 4. Generate or Update the Helm Repository Index

Generate or update the `index.yaml` file.

```bash
helm repo index docs --url https://<github-org>.github.io/<repository-name>
```

Example:

```bash
helm repo index docs --url https://decisionrules.github.io/helm-charts
```

The `docs` folder should now contain:

```text
docs/
  index.yaml
  decisionrules-1.0.0.tgz
```

If there are already older chart versions in the folder, keep them there before regenerating the index.

---

## 5. Commit and Push Changes to GitHub

Commit the updated Helm chart package and `index.yaml`.

```bash
git add docs
git commit -m "Publish Helm chart version 1.0.0"
git push
```

GitHub Pages should now serve the Helm repository.

---

## 6. Verify the Helm Repository

After GitHub Pages is updated, verify that the Helm repository works.

Add the repository locally:

```bash
helm repo add decisionrules https://<github-org>.github.io/<repository-name>
```

Example:

```bash
helm repo add decisionrules https://decisionrules.github.io/helm-charts
```

Update Helm repositories:

```bash
helm repo update
```

Search for the chart:

```bash
helm search repo decisionrules
```

Optionally test rendering the chart:

```bash
helm template test-release decisionrules/decisionrules
```

Or test installation without applying resources:

```bash
helm install test-release decisionrules/decisionrules --dry-run --debug
```

---

## 7. Add the Repository to Artifact Hub

Go to Artifact Hub:

```text
https://artifacthub.io
```

Then:

1. Sign in to Artifact Hub.
2. Go to **Control Panel**.
3. Open **Repositories**.
4. Click **Add repository**.
5. Select package kind: **Helm charts**.
6. Enter the repository name.
7. Enter the Helm repository URL.

Example URL:

```text
https://decisionrules.github.io/helm-charts
```

8. Save the repository.

Artifact Hub will read the `index.yaml` file from the provided URL and index the available Helm charts.

---

## 8. Optional: Add Artifact Hub Repository Metadata

It is recommended to add an `artifacthub-repo.yml` file to the same folder as `index.yaml`.

Example:

```text
docs/
  index.yaml
  artifacthub-repo.yml
  decisionrules-1.0.0.tgz
```

Example `artifacthub-repo.yml`:

```yaml
repositoryID: <artifact-hub-repository-id>
owners:
  - name: DecisionRules
    email: support@decisionrules.io
```

The `repositoryID` is used when claiming repository ownership in Artifact Hub.

---

## 9. Optional: Improve Chart Metadata for Artifact Hub

Artifact Hub uses metadata from `Chart.yaml`.

Recommended fields:

```yaml
apiVersion: v2
name: decisionrules
description: Helm chart for deploying DecisionRules
type: application
version: 1.0.0
appVersion: "1.25.1.0"

home: https://www.decisionrules.io

sources:
  - https://github.com/decisionrules/helm-charts

maintainers:
  - name: DecisionRules
    email: support@decisionrules.io

keywords:
  - decisionrules
  - rules-engine
  - decision-engine
  - kubernetes
  - helm
```

Recommended Artifact Hub annotations:

```yaml
annotations:
  artifacthub.io/category: integration-delivery
  artifacthub.io/license: MIT
  artifacthub.io/links: |
    - name: Documentation
      url: https://docs.decisionrules.io
    - name: Website
      url: https://www.decisionrules.io
  artifacthub.io/images: |
    - name: client
      image: decisionrules/client:1.25.1.0
    - name: server
      image: decisionrules/server:1.25.1.0
    - name: business-intelligence
      image: decisionrules/business-intelligence:1.3.5.3
```

---

## 10. Publishing a New Chart Version

When publishing a new version:

1. Update the chart version in `Chart.yaml`.

```yaml
version: 1.0.1
```

2. Package the chart again.

```bash
helm package charts/decisionrules --destination docs
```

3. Regenerate the Helm repository index.

```bash
helm repo index docs --url https://<github-org>.github.io/<repository-name>
```

4. Commit and push the changes.

```bash
git add docs
git commit -m "Publish Helm chart version 1.0.1"
git push
```

5. Artifact Hub will automatically detect the new chart version after the repository is re-indexed.

---

## Full Command Example

```bash
# Go to repository root
cd helm-charts

# Validate chart
helm lint charts/decisionrules

# Package chart
mkdir -p docs
helm package charts/decisionrules --destination docs

# Generate index.yaml for GitHub Pages
helm repo index docs --url https://decisionrules.github.io/helm-charts

# Commit and push
git add docs
git commit -m "Publish DecisionRules Helm chart"
git push

# Verify repository
helm repo add decisionrules https://decisionrules.github.io/helm-charts
helm repo update
helm search repo decisionrules
helm install test-release decisionrules/decisionrules --dry-run --debug
```

---

## Final Checklist

Before adding the repository to Artifact Hub, verify that:

- [ ] `helm lint` passes
- [ ] Chart package `.tgz` exists
- [ ] `index.yaml` exists
- [ ] GitHub Pages is enabled
- [ ] `index.yaml` is publicly available
- [ ] The Helm repo can be added using `helm repo add`
- [ ] The chart appears in `helm search repo`
- [ ] The chart can be rendered using `helm template`
- [ ] The repository URL is added to Artifact Hub