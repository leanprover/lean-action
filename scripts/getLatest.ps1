# get all release tags from leanprover/lean4
$versions = gh release list `
  --repo leanprover/lean4 `
  --json tagName | `
  ConvertFrom-Json | `
  ForEach-Object { $_.tagName } | `
  ForEach-Object { $_ -replace '^v' }

# parse the version tags as semver
$semvers = $versions | ForEach-Object { [System.Management.Automation.SemanticVersion]::new($_) }

# sort the versions and get the latest one
$latest = $semvers | Sort-Object | Select-Object -Last 1
Write-Host "Latest Lean release is: $latest"

# update `lean-toolchain` file
$leanStyleVersion = "leanprover/lean4:v$latest"
$leanStyleVersion | Set-Content -Path lean-toolchain