///|
test "default config uses community profile" {
  let value = default_config()
  inspect(value.profile, content="Community")
  inspect(value.minimum_score, content="70")
  inspect(value.require_tests, content="true")
}

///|
test "release and strict profiles have stronger requirements" {
  inspect(release_config().require_ci, content="true")
  inspect(strict_config().minimum_score, content="100")
  inspect(strict_config().maximum_warnings, content="0")
}

///|
test "parses profile limits and booleans" {
  let text =
    #|profile = release
    #|minimum_score = 95
    #|maximum_warnings = 2
    #|require_changelog = true
  let value = parse_config(text) catch { _ => panic() }
  inspect(value.profile, content="Release")
  inspect(value.minimum_score, content="95")
  inspect(value.maximum_warnings, content="2")
  inspect(value.require_changelog, content="true")
}

///|
test "parses rule overrides and ignored paths" {
  let text =
    #|rule.MBH007 = error
    #|rule.MBH010 = off
    #|ignore = fixtures/generated
  let value = parse_config(text) catch { _ => panic() }
  inspect(value.overrides.length(), content="2")
  inspect(
    is_ignored_path(value, "fixtures/generated/output.json"),
    content="true",
  )
}

///|
test "disabled rules are removed from a report" {
  let config = parse_config("rule.MBH007 = off") catch { _ => panic() }
  let report = apply_config(analyze(snapshot([])), config)
  inspect(report.findings.length(), content="10")
  inspect(
    report.findings.any(fn(item) { item.rule_id == "MBH007" }),
    content="false",
  )
}

///|
test "severity overrides change score" {
  let config = parse_config("rule.MBH007 = error") catch { _ => panic() }
  let report = apply_config(analyze(snapshot([])), config)
  let item = report.findings.filter(fn(value) { value.rule_id == "MBH007" })[0]
  inspect(item.severity, content="Error")
  inspect(report.score, content="0")
}

///|
test "severity budget reports remaining allowance" {
  let report = analyze(snapshot([]))
  inspect(severity_budget_left(report, severity_error(), 5), content="1")
  inspect(severity_budget_left(report, severity_warning(), 3), content="0")
}

///|
test "config text and JSON describe parsed values" {
  let value = parse_config("profile = strict\nignore = target") catch {
    _ => panic()
  }
  inspect(format_config_text(value).contains("Profile: strict"), content="true")
  inspect(
    format_config_json(value).contains("\"profile\": \"strict\""),
    content="true",
  )
}

///|
test "unknown rule ids are rejected" {
  let result = try parse_config("rule.MBH999 = off") catch {
    UnknownRule(value) => value
    _ => "unexpected"
  } noraise {
    _ => "unexpected success"
  }
  inspect(result, content="MBH999")
}

///|
test "duplicate rule overrides are rejected" {
  let result = try
    parse_config(
      (
        #|rule.MBH001 = warning
        #|rule.MBH001 = error
      ),
    )
  catch {
    DuplicateRule(value) => value
    _ => "unexpected"
  } noraise {
    _ => "unexpected success"
  }
  inspect(result, content="MBH001")
}
