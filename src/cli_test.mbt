///|
test "CLI parser accepts root and output options" {
  let options = parse_cli_options([
    "--root", "fixtures/good_project", "--format", "json", "--output", "_build/report.json",
    "--trend", "_build/trend.txt", "--fail-on-policy", "--fail-on-gate",
  ])
  inspect(options.root, content="fixtures/good_project")
  inspect(cli_format_text(options.format), content="json")
  match options.output_path {
    Some(path) => inspect(path, content="_build/report.json")
    None => fail("expected an output path")
  }
  match options.trend_path {
    Some(path) => inspect(path, content="_build/trend.txt")
    None => fail("expected a trend path")
  }
  inspect(options.fail_on_policy, content="true")
  inspect(options.fail_on_gate, content="true")
}

///|
test "CLI parser accepts a positional root" {
  let options = parse_cli_options(["fixtures/good_project", "--quiet"])
  inspect(options.root, content="fixtures/good_project")
  inspect(options.quiet, content="true")
}

///|
test "CLI parser rejects unknown formats" {
  let result = try parse_cli_options(["--format", "xml"]) catch {
    InvalidFormat(value) => value
    MissingValue(_) => "missing"
    UnknownOption(_) => "unknown"
  } noraise {
    _ => "unexpected success"
  }
  inspect(result, content="xml")
}

///|
test "CLI writes a parseable JSON audit bundle" {
  let output = "_build/cli_audit.json"
  let code = run_cli([
    "--root", "fixtures/good_project", "--format", "json", "--output", output, "--quiet",
  ])
  inspect(code, content="0")
  let report = parse_report_json(@fs.read_file_to_string(output))
  inspect(report.score, content="30")
  @fs.remove_file(output)
}

///|
test "CLI writes and extends a trend file" {
  let output = "_build/cli_trend_audit.json"
  let trend = "_build/cli_trend.txt"
  if @fs.path_exists(trend) {
    @fs.remove_file(trend)
  }
  let first = run_cli([
    "--root", "fixtures/good_project", "--format", "json", "--output", output, "--trend",
    trend, "--quiet",
  ])
  let second = run_cli([
    "--root", "fixtures/good_project", "--format", "json", "--output", output, "--trend",
    trend, "--quiet",
  ])
  inspect(first, content="0")
  inspect(second, content="0")
  let parsed = parse_trend_text(@fs.read_file_to_string(trend))
  inspect(parsed.points.length(), content="2")
  @fs.remove_file(output)
  @fs.remove_file(trend)
}
