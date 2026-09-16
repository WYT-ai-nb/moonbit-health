///|
fn diff_project(extra : Array[ProjectFile]) -> HealthReport {
  analyze(
    snapshot(
      [
        file("moon.mod.json", "{}"),
        file("src/moon.pkg.json", "{}"),
        file("README.md", "Usage\nmoon test\nmoon run cmd/main"),
        file("LICENSE", "Apache-2.0"),
        file("src/checks_test.mbt", "test { assert_true(true) }"),
        file("cmd/main/main.mbt", "fn main { println(\"ok\") }"),
        file("CONTRIBUTING.md", "guide"),
        file("CHANGELOG.md", "history"),
        file(".github/workflows/check.yml", "moon test"),
      ] +
      extra,
    ),
  )
}

///|
test "identical reports have a stable diff" {
  let report = diff_project([])
  let value = diff_reports(report, report)
  inspect(value.direction, content="Stable")
  inspect(value.score_delta, content="0")
  inspect(value.changes.length(), content="0")
}

///|
test "resolved findings improve the diff" {
  let baseline = analyze(snapshot([]))
  let current = diff_project([])
  let value = diff_reports(baseline, current)
  inspect(value.direction, content="Improved")
  inspect(value.score_delta, content="100")
  inspect(value.resolved, content="11")
  inspect(delta_has_improvements(value), content="true")
}

///|
test "introduced findings regress the diff" {
  let baseline = diff_project([])
  let current = analyze(snapshot([]))
  let value = diff_reports(baseline, current)
  inspect(value.direction, content="Regressed")
  inspect(value.introduced, content="11")
  inspect(delta_has_regressions(value), content="true")
}

///|
test "severity movement is classified" {
  let baseline = health_report(90, [
    finding("MBH001", severity_info(), "old", "moon.mod.json"),
  ])
  let current = health_report(70, [
    finding("MBH001", severity_error(), "new", "moon.mod.json"),
  ])
  let value = diff_reports(baseline, current)
  inspect(value.escalated, content="1")
  inspect(value.changes[0].kind, content="Escalated")
}

///|
test "diff summary and JSON are readable" {
  let value = diff_reports(analyze(snapshot([])), diff_project([]))
  inspect(delta_summary(value).contains("0 -> 100"), content="true")
  inspect(format_delta_json(value).contains("\"resolved\": 11"), content="true")
}

///|
test "trend tracks latest best and worst points" {
  let trend = empty_trend()
  let trend = add_trend_point(
    trend,
    trend_point("draft", analyze(snapshot([]))),
  )
  let trend = add_trend_point(trend, trend_point("tests", diff_project([])))
  inspect(latest_trend_point(trend) is Some({ score: 100, .. }), content="true")
  inspect(best_trend_point(trend) is Some({ score: 100, .. }), content="true")
  inspect(worst_trend_point(trend) is Some({ score: 0, .. }), content="true")
  inspect(trend_direction(trend), content="Improved")
  inspect(trend_net_change(trend), content="100")
}

///|
test "trend text includes points and direction" {
  let trend = empty_trend()
  let trend = add_trend_point(
    trend,
    trend_point("before", analyze(snapshot([]))),
  )
  let trend = add_trend_point(trend, trend_point("after", diff_project([])))
  let text = format_trend_text(trend)
  inspect(text.contains("Direction: improved"), content="true")
  inspect(text.contains("- after: 100/100"), content="true")
}

///|
test "JSON reports round-trip through the baseline parser" {
  let report = diff_project([])
  let parsed = parse_report_json(format_json(report))
  inspect(parsed.score, content="100")
  inspect(parsed.findings.length(), content="0")
}

///|
test "audit bundle JSON can be used as a baseline" {
  let report = analyze(snapshot([]))
  let bundle = "{\n  \"report\": " +
    format_json(report) +
    ",\n  \"inventory\": {}\n}\n"
  let parsed = parse_report_json(bundle)
  inspect(parsed.score, content="0")
  inspect(parsed.findings.length(), content="11")
}

///|
test "JSON serialization escapes paths and messages" {
  let report = health_report(70, [
    finding(
      "MBH999",
      severity_error(),
      "quote \" and newline\nnext",
      "src/odd\\path.mbt",
    ),
  ])
  let parsed = parse_report_json(format_json(report))
  inspect(parsed.findings[0].message.contains("\n"), content="true")
  inspect(parsed.findings[0].path, content="src/odd\\path.mbt")
}
