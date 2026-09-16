///|
/// Direction of score movement between two reports.
pub enum DeltaDirection {
  Improved
  Stable
  Regressed
} derive(Show, Eq)

///|
/// One finding-level change between two reports.
pub enum FindingChangeKind {
  Introduced
  Resolved
  Escalated
  Reduced
  Unchanged
} derive(Show, Eq)

///|
pub struct FindingChange {
  key : String
  rule_id : String
  path : String
  kind : FindingChangeKind
  before_severity : Severity?
  after_severity : Severity?
} derive(Show, Eq)

///|
/// Complete diff between a baseline and the current report.
pub struct ReportDelta {
  baseline_score : Int
  current_score : Int
  score_delta : Int
  direction : DeltaDirection
  changes : Array[FindingChange]
  introduced : Int
  resolved : Int
  escalated : Int
  reduced : Int
  unchanged : Int
} derive(Show, Eq)

///|
pub struct TrendPoint {
  label : String
  score : Int
  errors : Int
  warnings : Int
  infos : Int
} derive(Show, Eq)

///|
pub struct HealthTrend {
  points : Array[TrendPoint]
} derive(Show, Eq)

///|
/// Stable identity for matching the same finding across snapshots.
pub fn finding_key(item : Finding) -> String {
  item.rule_id + "|" + normalize_path(item.path)
}

///|
fn severity_rank(severity : Severity) -> Int {
  match severity {
    Info => 1
    Warning => 2
    Error => 3
  }
}

///|
fn movement(before : Severity, after : Severity) -> FindingChangeKind {
  let old_rank = severity_rank(before)
  let new_rank = severity_rank(after)
  if new_rank > old_rank {
    Escalated
  } else if new_rank < old_rank {
    Reduced
  } else {
    Unchanged
  }
}

///|
fn matching_finding(findings : Array[Finding], key : String) -> Finding? {
  for item in findings {
    if finding_key(item) == key {
      return Some(item)
    }
  }
  None
}

///|
fn has_key(findings : Array[Finding], key : String) -> Bool {
  match matching_finding(findings, key) {
    Some(_) => true
    None => false
  }
}

///|
fn delta_direction(score_delta : Int) -> DeltaDirection {
  if score_delta > 0 {
    Improved
  } else if score_delta < 0 {
    Regressed
  } else {
    Stable
  }
}

///|
/// Compare two reports by rule id and path rather than list position.
pub fn diff_reports(
  baseline : HealthReport,
  current : HealthReport,
) -> ReportDelta {
  let changes : Array[FindingChange] = []
  let mut introduced = 0
  let mut resolved = 0
  let mut escalated = 0
  let mut reduced = 0
  let mut unchanged = 0
  for item in current.findings {
    let key = finding_key(item)
    match matching_finding(baseline.findings, key) {
      Some(before) => {
        let kind = movement(before.severity, item.severity)
        match kind {
          Escalated => escalated = escalated + 1
          Reduced => reduced = reduced + 1
          Unchanged => unchanged = unchanged + 1
          Introduced | Resolved => ()
        }
        changes.push({
          key,
          rule_id: item.rule_id,
          path: item.path,
          kind,
          before_severity: Some(before.severity),
          after_severity: Some(item.severity),
        })
      }
      None => {
        introduced = introduced + 1
        changes.push({
          key,
          rule_id: item.rule_id,
          path: item.path,
          kind: Introduced,
          before_severity: None,
          after_severity: Some(item.severity),
        })
      }
    }
  }
  for item in baseline.findings {
    let key = finding_key(item)
    if !has_key(current.findings, key) {
      resolved = resolved + 1
      changes.push({
        key,
        rule_id: item.rule_id,
        path: item.path,
        kind: Resolved,
        before_severity: Some(item.severity),
        after_severity: None,
      })
    }
  }
  let score_delta = current.score - baseline.score
  {
    baseline_score: baseline.score,
    current_score: current.score,
    score_delta,
    direction: delta_direction(score_delta),
    changes,
    introduced,
    resolved,
    escalated,
    reduced,
    unchanged,
  }
}

///|
pub fn delta_direction_text(direction : DeltaDirection) -> String {
  match direction {
    Improved => "improved"
    Stable => "stable"
    Regressed => "regressed"
  }
}

///|
fn change_text(kind : FindingChangeKind) -> String {
  match kind {
    Introduced => "introduced"
    Resolved => "resolved"
    Escalated => "escalated"
    Reduced => "reduced"
    Unchanged => "unchanged"
  }
}

///|
fn signed_value(value : Int) -> String {
  if value > 0 {
    "+" + value.to_string()
  } else {
    value.to_string()
  }
}

///|
/// Return true when a diff introduces work or raises an existing severity.
pub fn delta_has_regressions(delta : ReportDelta) -> Bool {
  delta.introduced > 0 || delta.escalated > 0 || delta.score_delta < 0
}

///|
/// Return true when the diff resolves work or lowers an existing severity.
pub fn delta_has_improvements(delta : ReportDelta) -> Bool {
  delta.resolved > 0 || delta.reduced > 0 || delta.score_delta > 0
}

///|
/// Summary line suitable for CI logs.
pub fn delta_summary(delta : ReportDelta) -> String {
  "Health " +
  delta_direction_text(delta.direction) +
  ": " +
  delta.baseline_score.to_string() +
  " -> " +
  delta.current_score.to_string() +
  " (" +
  signed_value(delta.score_delta) +
  "), " +
  delta.introduced.to_string() +
  " introduced, " +
  delta.resolved.to_string() +
  " resolved"
}

///|
pub fn format_delta_text(delta : ReportDelta) -> String {
  let mut out = "Health Report Diff\n"
  out = out + delta_summary(delta) + "\n"
  out = out + "Escalated: " + delta.escalated.to_string() + "\n"
  out = out + "Reduced: " + delta.reduced.to_string() + "\n"
  out = out + "Unchanged: " + delta.unchanged.to_string() + "\n"
  if delta.changes.length() > 0 {
    out = out + "Changes:\n"
    for item in delta.changes {
      out = out +
        "- [" +
        change_text(item.kind) +
        "] " +
        item.rule_id +
        " " +
        item.path +
        "\n"
    }
  }
  out
}

///|
pub fn format_delta_json(delta : ReportDelta) -> String {
  let mut out = "{\n"
  out = out +
    "  \"baseline_score\": " +
    delta.baseline_score.to_string() +
    ",\n"
  out = out + "  \"current_score\": " + delta.current_score.to_string() + ",\n"
  out = out + "  \"score_delta\": " + delta.score_delta.to_string() + ",\n"
  out = out +
    "  \"direction\": \"" +
    delta_direction_text(delta.direction) +
    "\",\n"
  out = out + "  \"introduced\": " + delta.introduced.to_string() + ",\n"
  out = out + "  \"resolved\": " + delta.resolved.to_string() + ",\n"
  out = out + "  \"escalated\": " + delta.escalated.to_string() + ",\n"
  out = out + "  \"reduced\": " + delta.reduced.to_string() + ",\n"
  out = out + "  \"unchanged\": " + delta.unchanged.to_string() + ",\n"
  out = out + "  \"changes\": ["
  for i = 0; i < delta.changes.length(); i = i + 1 {
    let item = delta.changes[i]
    if i > 0 {
      out = out + ","
    }
    out = out +
      "\n    {\"kind\":" +
      json_string(change_text(item.kind)) +
      ",\"rule_id\":" +
      json_string(item.rule_id) +
      ",\"path\":" +
      json_string(item.path) +
      "}"
  }
  if delta.changes.length() > 0 {
    out + "\n  ]\n}\n"
  } else {
    out + "]\n}\n"
  }
}

///|
fn required_json_string(
  object : Map[String, Json],
  key : String,
) -> String raise {
  match object.get(key) {
    Some(String(value)) => value
    _ => raise Failure("missing or invalid report field: " + key)
  }
}

///|
fn severity_from_text(value : String) -> Severity raise {
  match value {
    "info" => Info
    "warning" => Warning
    "error" => Error
    _ => raise Failure("unknown report severity: " + value)
  }
}

///|
fn finding_from_json(value : Json) -> Finding raise {
  match value {
    Object(object) => {
      let rule_id = required_json_string(object, "rule_id")
      let severity = severity_from_text(
        required_json_string(object, "severity"),
      )
      let path = required_json_string(object, "path")
      let message = required_json_string(object, "message")
      finding(rule_id, severity, message, path)
    }
    _ => raise Failure("report finding must be a JSON object")
  }
}

///|
/// Parse the JSON report emitted by `format_json`.
fn report_from_json(root : Json) -> HealthReport raise {
  match root {
    Object(object) => {
      let score = match object.get("score") {
        Some(Number(value, ..)) => value.to_int()
        _ => raise Failure("report score must be a number")
      }
      let findings = match object.get("findings") {
        Some(Array(values)) => values.map(finding_from_json)
        _ => raise Failure("report findings must be an array")
      }
      health_report(score, findings)
    }
    _ => raise Failure("report root must be a JSON object")
  }
}

///|
/// Parse either a standalone report or an audit bundle containing `report`.
pub fn parse_report_json(text : String) -> HealthReport raise {
  let root = @json.parse(text)
  match root {
    Object(object) =>
      match object.get("report") {
        Some(report) => report_from_json(report)
        None => report_from_json(root)
      }
    _ => raise Failure("report root must be a JSON object")
  }
}

///|
/// Create a trend point from a report and a human-readable revision label.
pub fn trend_point(label : String, report : HealthReport) -> TrendPoint {
  {
    label,
    score: report.score,
    errors: count_severity(report, Error),
    warnings: count_severity(report, Warning),
    infos: count_severity(report, Info),
  }
}

///|
pub fn empty_trend() -> HealthTrend {
  { points: [], }
}

///|
/// Append a point without changing the previous trend value.
pub fn add_trend_point(trend : HealthTrend, point : TrendPoint) -> HealthTrend {
  trend.points.push(point)
  trend
}

///|
pub fn latest_trend_point(trend : HealthTrend) -> TrendPoint? {
  if trend.points.length() == 0 {
    None
  } else {
    Some(trend.points[trend.points.length() - 1])
  }
}

///|
pub fn best_trend_point(trend : HealthTrend) -> TrendPoint? {
  let mut best : TrendPoint? = None
  for item in trend.points {
    match best {
      None => best = Some(item)
      Some(current) => if item.score > current.score { best = Some(item) }
    }
  }
  best
}

///|
pub fn worst_trend_point(trend : HealthTrend) -> TrendPoint? {
  let mut worst : TrendPoint? = None
  for item in trend.points {
    match worst {
      None => worst = Some(item)
      Some(current) => if item.score < current.score { worst = Some(item) }
    }
  }
  worst
}

///|
/// Compare the latest point with the preceding point.
pub fn trend_direction(trend : HealthTrend) -> DeltaDirection {
  if trend.points.length() < 2 {
    Stable
  } else {
    let previous = trend.points[trend.points.length() - 2]
    let latest = trend.points[trend.points.length() - 1]
    delta_direction(latest.score - previous.score)
  }
}

///|
/// Calculate the net score movement from first to latest point.
pub fn trend_net_change(trend : HealthTrend) -> Int {
  if trend.points.length() < 2 {
    0
  } else {
    trend.points[trend.points.length() - 1].score - trend.points[0].score
  }
}

///|
pub fn format_trend_text(trend : HealthTrend) -> String {
  let mut out = "Maintainer Readiness Trend\n"
  out = out + "Points: " + trend.points.length().to_string() + "\n"
  out = out +
    "Direction: " +
    delta_direction_text(trend_direction(trend)) +
    "\n"
  out = out + "Net change: " + signed_value(trend_net_change(trend)) + "\n"
  for item in trend.points {
    out = out +
      "- " +
      item.label +
      ": " +
      item.score.to_string() +
      "/100 (errors " +
      item.errors.to_string() +
      ", warnings " +
      item.warnings.to_string() +
      ", infos " +
      item.infos.to_string() +
      ")\n"
  }
  out
}

///|
fn parse_trend_int(value : StringView) -> Int raise {
  @string.parse_int(value)
}

///|
/// Parse the line-oriented trend file used by the CLI.
pub fn parse_trend_text(text : String) -> HealthTrend raise {
  let trend = empty_trend()
  for raw_line in text.split("\n") {
    let line = raw_line.trim()
    if line == "" {
      continue
    }
    let fields = line.split("\t").to_array()
    if fields.length() != 5 {
      raise Failure("invalid trend line: " + line.to_owned())
    }
    trend.points.push({
      label: fields[0].to_owned(),
      score: parse_trend_int(fields[1]),
      errors: parse_trend_int(fields[2]),
      warnings: parse_trend_int(fields[3]),
      infos: parse_trend_int(fields[4]),
    })
  }
  trend
}

///|
fn trend_point_line(point : TrendPoint) -> String {
  point.label +
  "\t" +
  point.score.to_string() +
  "\t" +
  point.errors.to_string() +
  "\t" +
  point.warnings.to_string() +
  "\t" +
  point.infos.to_string() +
  "\n"
}

///|
/// Serialize all trend points as one tab-separated record per revision.
pub fn format_trend_series(trend : HealthTrend) -> String {
  let mut out = ""
  for point in trend.points {
    out = out + trend_point_line(point)
  }
  out
}

///|
pub fn format_trend_json(trend : HealthTrend) -> String {
  let mut out = "{\n  \"net_change\": " +
    trend_net_change(trend).to_string() +
    ",\n  \"direction\": " +
    json_string(delta_direction_text(trend_direction(trend))) +
    ",\n  \"points\": ["
  for i = 0; i < trend.points.length(); i = i + 1 {
    let point = trend.points[i]
    if i > 0 {
      out = out + ","
    }
    out = out +
      "\n    {\"label\":" +
      json_string(point.label) +
      ",\"score\":" +
      point.score.to_string() +
      ",\"errors\":" +
      point.errors.to_string() +
      ",\"warnings\":" +
      point.warnings.to_string() +
      ",\"infos\":" +
      point.infos.to_string() +
      "}"
  }
  if trend.points.length() > 0 {
    out + "\n  ]\n}\n"
  } else {
    out + "]\n}\n"
  }
}
