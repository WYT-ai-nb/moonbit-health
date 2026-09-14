///|
fn severity_text(severity : Severity) -> String {
  match severity {
    Info => "info"
    Warning => "warning"
    Error => "error"
  }
}

///|
pub fn format_text(report : HealthReport) -> String {
  let mut out = "MoonBit Health Report\n"
  out = out + "Score: " + report.score.to_string() + "/100\n"
  if report.findings.length() == 0 {
    out + "No findings.\n"
  } else {
    for item in report.findings {
      out = out + "- [" + severity_text(item.severity) + "] " +
        item.rule_id + " " + item.path + ": " + item.message + "\n"
    }
    out
  }
}

///|
pub fn format_json(report : HealthReport) -> String {
  let mut out = "{\n  \"score\": " + report.score.to_string() +
    ",\n  \"findings\": ["
  for i = 0; i < report.findings.length(); i = i + 1 {
    let item = report.findings[i]
    if i > 0 {
      out = out + ","
    }
    out = out + "\n    {\"rule_id\":\"" + item.rule_id +
      "\",\"severity\":\"" + severity_text(item.severity) +
      "\",\"path\":\"" + item.path +
      "\",\"message\":\"" + item.message + "\"}"
  }
  if report.findings.length() > 0 {
    out = out + "\n  ]\n}"
    out
  } else {
    out = out + "]\n}"
    out
  }
}
