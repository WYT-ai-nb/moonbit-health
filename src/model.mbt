///|
pub enum Severity {
  Info
  Warning
  Error
} derive(Show, Eq)

///|
pub struct ProjectFile {
  path : String
  content : String
} derive(Show, Eq)

///|
pub struct ProjectSnapshot {
  files : Array[ProjectFile]
} derive(Show, Eq)

///|
pub struct Finding {
  rule_id : String
  severity : Severity
  message : String
  path : String
} derive(Show, Eq)

///|
pub struct HealthReport {
  score : Int
  findings : Array[Finding]
} derive(Show, Eq)

///|
pub fn file(path : String, content : String) -> ProjectFile {
  { path, content }
}

///|
pub fn snapshot(files : Array[ProjectFile]) -> ProjectSnapshot {
  { files }
}

///|
pub fn finding(
  rule_id : String,
  severity : Severity,
  message : String,
  path : String
) -> Finding {
  { rule_id, severity, message, path }
}

///|
pub fn count_severity(report : HealthReport, target : Severity) -> Int {
  let mut total = 0
  for item in report.findings {
    if item.severity == target {
      total = total + 1
    }
  }
  total
}
