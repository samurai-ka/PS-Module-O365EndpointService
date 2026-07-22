# CLAUDE.md

Guidance for working in this repository.

## What this is
`O365EndpointFunctions` is a PowerShell **module** that wraps the Microsoft 365 IP
Address and URL web service (https://endpoints.office.com). It turns the service's
nested "endpoint set" JSON into flat, strongly-typed `EndpointSet` objects and can
export them as a proxy PAC file or a Ghostery policy, and merge them with custom
endpoints.

Target runtime: **PowerShell 7+ (Core only)** — the manifest declares
`PowerShellVersion = '7.0'` and `CompatiblePSEditions = @('Core')`.

## Layout
```
O365EndpointFunctions/            # the shippable module (this whole folder is published)
  O365EndpointFunctions.psd1      # manifest (UTF-16!) — see gotcha below
  O365EndpointFunctions.psm1      # loader + the EndpointSet class
  Public/*.ps1                    # one exported cmdlet per file
  Private/*.ps1                   # internal, non-exported helpers
Tests/*.Tests.ps1                 # Pester v5 tests (offline)
Examples/                         # copy-paste cookbook + demo JSON
PSScriptAnalyzerSettings.psd1     # analyzer config (repo root, not shipped)
.github/workflows/                # development.yml (CI + version bump), release.yml
```

## Architecture rules
- **The `EndpointSet` class lives in `O365EndpointFunctions.psm1`, not in a
  dot-sourced file.** PowerShell classes have parse-order/type-resolution pitfalls
  when dot-sourced; keeping the class in the root module avoids them. The `.psm1`
  dot-sources `Public/` and `Private/` `.ps1` files, whose bodies reference
  `[EndpointSet]` only at run time.
- **Collections use `[System.Collections.Generic.List[object]]`, not
  `List[EndpointSet]`.** After a module re-import the class gets a new type identity,
  and a list bound to the old type rejects new instances ("Cannot find an overload
  for Add"). `List[object]` sidesteps this. Do not "tidy" it back to `List[EndpointSet]`.
- **`[OutputType()]` for the class uses the string form** `[OutputType('EndpointSet')]`
  (the `[type]` form reflects empty for module classes). `[OutputType([string])]` is
  fine for the string-returning cmdlets.
- Ports are `[Nullable[uint16]]`, `id` is `[Nullable[int]]` — unset stays `$null`
  (the constructor skips empty values rather than assigning them).

## The manifest is UTF-16 — handle with care
`O365EndpointFunctions.psd1` is **UTF-16 LE with BOM**.
- Never edit it in a way that changes the encoding. When scripting an edit, read raw
  and write with `[System.IO.File]::WriteAllText($path, $text,
  [System.Text.UnicodeEncoding]::new($false, $true))`.
- `.gitattributes` marks `*.psd1` as `binary` so Git never text-merges it — a text
  merge previously truncated it to 0 bytes. Keep that rule.

## Testing & quality
- Run the suite: `Invoke-Pester -Path ./Tests` (Pester v5). Tests are **offline** —
  `Invoke-RestMethod` and the cache file are mocked with `-ModuleName`.
- Static analysis: `Invoke-ScriptAnalyzer -Path ./O365EndpointFunctions -Recurse
  -Settings ./PSScriptAnalyzerSettings.psd1`. Ship with **0 errors and 0 warnings**
  (the Gallery blocks on errors). A couple of `PSUseOutputTypeCorrectly` *Information*
  hints on Invoke/Merge are known/accepted.
- After changing the module, verify: `Test-ModuleManifest`, import, and the full
  Pester suite all pass.

## Versioning & CI/CD
- Version format is `Major.Minor.YearMonth.Counter` (`YearMonth = yyMM`).
- `development.yml` runs on every push: Pester tests, then — only on `master` and only
  if tests pass — bumps the `ModuleVersion` counter and pushes a `[skip ci]` commit.
- `release.yml` is **manual only** (`workflow_dispatch`): publishes to the PowerShell
  Gallery via the `production` environment, gated on a successful `development.yml` run.
  Needs the `PSGALLERY_API_KEY` secret on the `production` environment.

## Working conventions
- **Git**: don't commit or push unless asked. Branch off `master` first. End commit
  messages with the project's `Co-Authored-By` trailer.
- **Pushing**: the remote is SSH and Git for Windows uses a bundled `ssh` that can't
  see the Windows OpenSSH agent. Push with
  `$env:GIT_SSH_COMMAND = '"C:\Windows\System32\OpenSSH\ssh.exe"'` first.
- All four cmdlets ship comment-based help; keep it in sync when changing parameters.
