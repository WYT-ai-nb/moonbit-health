///|
fn has_file(project : ProjectSnapshot, path : String) -> Bool {
  project.files.any(fn(f) { f.path == path })
}

///|
fn has_prefix(project : ProjectSnapshot, prefix : String) -> Bool {
  project.files.any(fn(f) { f.path.starts_with(prefix) })
}

///|
fn has_suffix(project : ProjectSnapshot, suffix : String) -> Bool {
  project.files.any(fn(f) { f.path.ends_with(suffix) })
}

///|
fn content_of(project : ProjectSnapshot, path : String) -> String? {
  for f in project.files {
    if f.path == path {
      return Some(f.content)
    }
  }
  None
}

///|
fn has_any_license(project : ProjectSnapshot) -> Bool {
  has_file(project, "LICENSE") || has_file(project, "LICENSE.md") ||
  has_file(project, "LICENSE.txt") || has_file(project, "COPYING") ||
  has_file(project, "COPYING.md")
}

///|
fn has_moon_package(project : ProjectSnapshot) -> Bool {
  has_suffix(project, "moon.pkg.json")
}

///|
fn has_tests(project : ProjectSnapshot) -> Bool {
  project.files.any(fn(f) {
    f.path.ends_with("_test.mbt") || f.content.contains("test \"") ||
    f.content.contains("test {")
  })
}

///|
fn has_examples(project : ProjectSnapshot) -> Bool {
  has_prefix(project, "examples/") || has_prefix(project, "example/") ||
  has_prefix(project, "cmd/")
}

///|
fn readme_mentions_usage(project : ProjectSnapshot) -> Bool {
  match content_of(project, "README.md") {
    Some(text) => text.contains("Usage") || text.contains("使用") ||
      text.contains("moon run") || text.contains("moon test")
    None => false
  }
}

///|
fn push_if_missing(
  findings : Array[Finding],
  ok : Bool,
  rule_id : String,
  severity : Severity,
  message : String,
  path : String
) -> Array[Finding] {
  if ok {
    findings
  } else {
    findings.push(finding(rule_id, severity, message, path))
  }
}

///|
pub fn analyze(project : ProjectSnapshot) -> HealthReport {
  let mut findings : Array[Finding] = []
  findings = push_if_missing(
    findings,
    has_file(project, "moon.mod.json"),
    "MBH001",
    Error,
    "moon.mod.json is required at the project root",
    "moon.mod.json",
  )
  findings = push_if_missing(
    findings,
    has_moon_package(project),
    "MBH002",
    Error,
    "at least one moon.pkg.json package file is required",
    "moon.pkg.json",
  )
  findings = push_if_missing(
    findings,
    has_file(project, "README.md"),
    "MBH003",
    Error,
    "README.md is required",
    "README.md",
  )
  findings = push_if_missing(
    findings,
    readme_mentions_usage(project),
    "MBH004",
    Warning,
    "README should include usage or verification commands",
    "README.md",
  )
  findings = push_if_missing(
    findings,
    has_any_license(project),
    "MBH005",
    Error,
    "an OSI-approved license file should be present",
    "LICENSE",
  )
  findings = push_if_missing(
    findings,
    has_tests(project),
    "MBH006",
    Warning,
    "tests are expected for hackathon verification",
    "*_test.mbt",
  )
  findings = push_if_missing(
    findings,
    has_examples(project),
    "MBH007",
    Info,
    "examples or a runnable cmd package help reviewers try the project",
    "examples/",
  )
  { score: score(findings), findings }
}

///|
pub fn score(findings : Array[Finding]) -> Int {
  let mut value = 100
  for item in findings {
    match item.severity {
      Error => value = value - 20
      Warning => value = value - 10
      Info => value = value - 5
    }
  }
  if value < 0 {
    0
  } else {
    value
  }
}
