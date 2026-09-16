///|
pub enum Severity {
  Info
  Warning
  Error
} derive(Show, Eq)

///|
/// Return the error level for callers that need to summarize a report.
pub fn severity_error() -> Severity {
  Error
}

///|
/// Return the warning level for callers that need to summarize a report.
pub fn severity_warning() -> Severity {
  Warning
}

///|
/// Return the informational level for callers that need to summarize a report.
pub fn severity_info() -> Severity {
  Info
}

///|
pub struct ProjectFile {
  path : String
  content : String
  size : Int64
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
  { path, content, size: content.length().to_int64(), }
}

///|
pub fn file_with_size(
  path : String,
  content : String,
  size : Int64,
) -> ProjectFile {
  { path, content, size, }
}

///|
pub fn snapshot(files : Array[ProjectFile]) -> ProjectSnapshot {
  { files, }
}

///|
pub fn finding(
  rule_id : String,
  severity : Severity,
  message : String,
  path : String,
) -> Finding {
  { rule_id, severity, message, path, }
}

///|
/// Construct a report for callers that already have a finding list.
pub fn health_report(score : Int, findings : Array[Finding]) -> HealthReport {
  { score, findings, }
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
