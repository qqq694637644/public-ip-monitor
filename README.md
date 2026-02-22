# Public IP Monitor (Windows + PowerShell + GitHub Pages)

This project detects your public IP from **Windows** (behind an HTTP proxy) and, when it changes, **updates files under `docs/` in your GitHub repo** via the GitHub REST API.
GitHub Pages is configured to publish from **`main` branch → `/docs` folder** ("方式1"), so you can open a web URL to see the latest IP.

---

## What you get

- `scripts/ip-monitor.ps1`  
  Detects public IP (via proxy) → if changed, pushes:
  - `docs/ip.txt` (plain text)
  - `docs/ip.json` (for the web page)
- `docs/index.html`  
  A simple page that fetches `ip.json` and displays the current IP + update time.
- `scripts/install-schtask.ps1`  
  Creates a Windows Scheduled Task to run the monitor every N minutes.

---

## 1) Create a GitHub repo & add these files

1. Create a repo, e.g. `public-ip-monitor`.
2. Upload everything from this zip into the repo (or `git clone` and copy files).
3. Commit & push to `main`.

---

## 2) Enable GitHub Pages (方式1)

Repo → **Settings** → **Pages**:
- **Source**: Deploy from a branch
- **Branch**: `main`
- **Folder**: `/docs`

After it’s published, your page URL looks like:
- `https://<your-username>.github.io/<repo>/`
- `https://<your-username>.github.io/<repo>/ip.txt`

> Note: Pages updates may take a few minutes after each commit.

---

## 3) Create a GitHub token (PAT)

Create a Personal Access Token with permission to update your repo contents:
- Fine-grained: **Contents: Read and write** (and access to this repo)
- Classic: `repo`

Then set it as an environment variable on Windows:

```powershell
setx GITHUB_TOKEN "ghp_xxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
```

Open a new PowerShell window to pick up the new env var.

---

## 4) Configure `scripts/ip-monitor.ps1`

Edit these variables near the top:

- `$ProxyUrl`  (your local **HTTP** proxy, e.g. `http://127.0.0.1:10809`)
- `$GitHubOwner`, `$GitHubRepo`, `$GitHubBranch`

Then test-run:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\ip-monitor.ps1
```

If your IP changed, it will update `docs/ip.txt` and `docs/ip.json` in the repo.

---

## 5) Install Scheduled Task (optional)

Run (as Admin PowerShell) from the repo root:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\install-schtask.ps1 -IntervalMinutes 10
```

This installs a task named `PublicIpMonitor` that runs every 10 minutes.

---

## Security note

Publishing your public IP to GitHub Pages makes it publicly accessible.
If that’s not acceptable, don’t enable Pages, or push to a private location instead.

---

## File layout

```
public-ip-monitor/
  docs/
    index.html
    ip.txt
    ip.json
    .nojekyll
  scripts/
    ip-monitor.ps1
    install-schtask.ps1
  .gitignore
  README.md
```
