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

///| Turn findings into a short handoff plan for the next maintainer.
pub fn format_handoff(report : HealthReport) -> String {
  let mut out = "MoonBit Maintainer Compass - Handoff Plan\n"
  out = out + "Readiness: " + report.score.to_string() + "/100\n"
  if report.findings.length() == 0 {
    out + "Next maintainer can build, test, and review this project.\n"
  } else {
    out = out + "Before handoff:\n"
    for item in report.findings {
      out = out + "- " + item.rule_id + ": " + item.message +
        " (target: " + item.path + ")\n"
    }
    out
  }
}
