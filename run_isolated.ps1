# Run lab.runner in Docker with everything the agent must not see masked.
# One container per task: only that task's folder is visible; other tasks, docs, results of
# other conditions, report/, .git, .env and (unless skills-auto) skills/ are hidden.
# ponytail: the agent's shell still runs as the same user as the grader, so it can read its own
# task's check.py; a separate unprivileged user for the shell would close that.
# Usage: ./run_isolated.ps1 -Condition baseline -Tasks learn [-RecursionLimit 60] [-Results results] [-Model openai:gpt-4o]
param(
    [Parameter(Mandatory)][ValidateSet("baseline", "subagents", "skills-auto")][string]$Condition,
    [string[]]$Tasks = @("all"),
    [int]$RecursionLimit = 60,
    [string]$Results = "results",   # extension runs go to their own folder
    [string]$Model = ""             # overrides LAB_MODEL from .env when set
)
$ErrorActionPreference = "Stop"
$repo = $PSScriptRoot
$all = @("code-learn", "data-learn", "logs-learn", "code-eval", "data-eval", "logs-eval")
$ids = switch ($Tasks[0]) {
    "all"   { $all }
    "learn" { $all | Where-Object { $_ -like "*-learn" } }
    "eval"  { $all | Where-Object { $_ -like "*-eval" } }
    default { $Tasks }
}
$empty = Join-Path $repo ".isolate/empty"
$hiddenFiles = Get-ChildItem $repo -File -Filter *.md | ForEach-Object { $_.Name }
$hiddenFiles += ".env", ".env.example"
New-Item -ItemType Directory -Force (Join-Path $repo "$Results/$Condition") | Out-Null

foreach ($id in $ids) {
    $mounts = @("-v", "${repo}:/lab", "-v", "${repo}/${Results}/${Condition}:/out/${Condition}",
                "-v", "/lab/results", "-v", "/lab/report", "-v", "/lab/guides", "-v", "/lab/.git", "-v", "/lab/.isolate")
    if ($Results -ne "results") { $mounts += "-v", "/lab/$Results" }
    foreach ($f in $hiddenFiles) { $mounts += "-v", "${empty}:/lab/${f}:ro" }
    foreach ($t in $all | Where-Object { $_ -ne $id }) { $mounts += "-v", "/lab/tasks/$t" }
    if ($Condition -ne "skills-auto") { $mounts += "-v", "/lab/skills" }
    $envArgs = @("--env-file", (Join-Path $repo ".env"))
    if ($Model) { $envArgs += "-e", "LAB_MODEL=$Model" }
    docker run --rm @envArgs @mounts lab-deepagents bash -c `
        "pip install -q -e . 2>/dev/null; python -m lab.runner --condition $Condition --tasks $id --results /out --recursion-limit $RecursionLimit"
    if ($LASTEXITCODE -ne 0) { throw "run failed: $Condition $id" }
}
