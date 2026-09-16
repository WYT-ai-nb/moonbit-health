///|
pub enum CliFormat {
  TextOutput
  JsonOutput
  MarkdownOutput
  AllOutput
} derive(Show, Eq)

///|
pub struct CliOptions {
  root : String
  config_path : String?
  baseline_path : String?
  output_path : String?
  trend_path : String?
  profile : String?
  format : CliFormat
  fail_on_policy : Bool
  fail_on_regression : Bool
  fail_on_gate : Bool
  quiet : Bool
  help : Bool
  version : Bool
  additional_ignores : Array[String]
} derive(Show, Eq)

///|
pub suberror CliError {
  MissingValue(String)
  UnknownOption(String)
  InvalidFormat(String)
} derive(Debug)

///|
pub impl Show for CliError with fn output(error, logger) {
  match error {
    MissingValue(option) =>
      logger.write_string("missing value for option " + option)
    UnknownOption(option) => logger.write_string("unknown option " + option)
    InvalidFormat(format) =>
      logger.write_string("invalid output format " + format)
  }
}

///|
priv struct CliAudit {
  options : CliOptions
  scan : ScanResult
  report : HealthReport
  inventory : ProjectInventory
  policy : PolicyDecision
  actions : Array[RecommendedAction]
  git : GitAudit
  gate : ReleaseGate
  delta : ReportDelta?
  trend : HealthTrend?
}

///|
fn default_cli_options() -> CliOptions {
  {
    root: ".",
    config_path: None,
    baseline_path: None,
    output_path: None,
    trend_path: None,
    profile: None,
    format: TextOutput,
    fail_on_policy: false,
    fail_on_regression: false,
    fail_on_gate: false,
    quiet: false,
    help: false,
    version: false,
    additional_ignores: [],
  }
}

///|
fn parse_format(value : String) -> CliFormat raise CliError {
  match value.to_lower() {
    "text" | "txt" => TextOutput
    "json" => JsonOutput
    "markdown" | "md" => MarkdownOutput
    "all" => AllOutput
    _ => raise InvalidFormat(value)
  }
}

///|
fn option_value(
  args : Array[String],
  index : Int,
  option : String,
) -> String raise CliError {
  if index + 1 >= args.length() {
    raise MissingValue(option)
  }
  args[index + 1]
}

///|
/// Parse command-line options without depending on a third-party CLI runtime.
pub fn parse_cli_options(args : Array[String]) -> CliOptions raise CliError {
  let mut options = default_cli_options()
  let mut index = 0
  if args.length() > 0 &&
    !args[0].has_prefix("-") &&
    (args[0].has_suffix(".wasm") || args[0].has_suffix(".exe")) {
    index = 1
  }
  while index < args.length() {
    let argument = args[index]
    if argument == "--root" {
      options = { ..options, root: option_value(args, index, argument), }
      index = index + 2
    } else if argument == "--config" {
      options = {
        ..options,
        config_path: Some(option_value(args, index, argument)),
      }
      index = index + 2
    } else if argument == "--baseline" {
      options = {
        ..options,
        baseline_path: Some(option_value(args, index, argument)),
      }
      index = index + 2
    } else if argument == "--trend" {
      options = {
        ..options,
        trend_path: Some(option_value(args, index, argument)),
      }
      index = index + 2
    } else if argument == "--output" || argument == "-o" {
      options = {
        ..options,
        output_path: Some(option_value(args, index, argument)),
      }
      index = index + 2
    } else if argument == "--profile" {
      options = {
        ..options,
        profile: Some(option_value(args, index, argument)),
      }
      index = index + 2
    } else if argument == "--format" {
      options = {
        ..options,
        format: parse_format(option_value(args, index, argument)),
      }
      index = index + 2
    } else if argument == "--ignore" {
      options.additional_ignores.push(option_value(args, index, argument))
      index = index + 2
    } else if argument == "--fail-on-policy" {
      options = { ..options, fail_on_policy: true, }
      index = index + 1
    } else if argument == "--fail-on-regression" {
      options = { ..options, fail_on_regression: true, }
      index = index + 1
    } else if argument == "--fail-on-gate" {
      options = { ..options, fail_on_gate: true, }
      index = index + 1
    } else if argument == "--quiet" || argument == "-q" {
      options = { ..options, quiet: true, }
      index = index + 1
    } else if argument == "--help" || argument == "-h" {
      options = { ..options, help: true, }
      index = index + 1
    } else if argument == "--version" || argument == "-V" {
      options = { ..options, version: true, }
      index = index + 1
    } else if argument.has_prefix("-") {
      raise UnknownOption(argument)
    } else if options.root == "." {
      options = { ..options, root: argument, }
      index = index + 1
    } else {
      raise UnknownOption(argument)
    }
  }
  options
}

///|
pub fn cli_format_text(format : CliFormat) -> String {
  match format {
    TextOutput => "text"
    JsonOutput => "json"
    MarkdownOutput => "markdown"
    AllOutput => "all"
  }
}

///|
pub fn format_cli_help() -> String {
  (
    #|MoonBit Maintainer Compass
    #|
    #|Usage:
    #|  moon run cmd/main -- [ROOT] [OPTIONS]
    #|
    #|Options:
    #|  --root PATH             Project directory to scan
    #|  --config PATH           Load a line-oriented policy file
    #|  --profile NAME          community, release, or strict
    #|  --baseline PATH         Compare with a previous JSON report
    #|  --trend PATH            Append the current result to a trend file
    #|  --format NAME           text, json, markdown, or all
    #|  --output PATH, -o PATH  Write the rendered report to a file
    #|  --ignore PATH           Ignore a path during rule evaluation
    #|  --fail-on-policy        Exit with code 1 when policy fails
    #|  --fail-on-regression    Exit with code 1 when score regresses
    #|  --fail-on-gate          Exit with code 1 when the release gate blocks
    #|  --quiet, -q             Do not print the report to stdout
    #|  --help, -h              Show this help
    #|  --version, -V           Show the tool version
  )
}

///|
fn apply_cli_ignores(
  config : CompassConfig,
  options : CliOptions,
) -> CompassConfig {
  for path in options.additional_ignores {
    config.ignored_paths.push(path)
  }
  config
}

///|
fn config_path_for(options : CliOptions) -> String? {
  match options.config_path {
    Some(path) => Some(path)
    None => {
      let candidate = append_path(options.root, "moonbit-health.conf")
      let exists = @fs.path_exists(candidate)
      if exists {
        Some(candidate)
      } else {
        None
      }
    }
  }
}

///|
fn resolve_config(options : CliOptions) -> CompassConfig raise {
  let mut config = match config_path_for(options) {
    Some(path) => load_config(path)
    None => default_config()
  }
  match options.profile {
    Some(profile) => {
      let profile_config = config_named(profile)
      config = {
        ..profile_config,
        ignored_paths: config.ignored_paths,
        overrides: config.overrides,
      }
    }
    None => ()
  }
  apply_cli_ignores(config, options)
}

///|
fn render_warnings(warnings : Array[String]) -> String {
  if warnings.length() == 0 {
    ""
  } else {
    let mut out = "Scan Warnings\n"
    for warning in warnings {
      out = out + "- " + warning + "\n"
    }
    out + "\n"
  }
}

///|
fn render_text_bundle(bundle : CliAudit) -> String {
  let mut out = "MoonBit Maintainer Compass\n"
  out = out + "Root: " + bundle.options.root + "\n"
  out = out + "Format: " + cli_format_text(bundle.options.format) + "\n\n"
  out = out + render_warnings(bundle.scan.warnings)
  out = out + format_text(bundle.report) + "\n"
  out = out + format_inventory_text(bundle.inventory) + "\n"
  match bundle.delta {
    Some(value) => out = out + delta_summary(value) + "\n\n"
    None => ()
  }
  out = out + format_policy_text(bundle.policy) + "\n"
  out = out + format_git_text(bundle.git) + "\n"
  out = out + format_gate(bundle.gate) + "\n"
  match bundle.trend {
    Some(value) => out = out + format_trend_text(value) + "\n"
    None => ()
  }
  out = out + format_actions_text(bundle.actions) + "\n"
  out = out + format_handoff(bundle.report)
  out
}

///|
fn render_markdown_bundle(bundle : CliAudit) -> String {
  let mut out = "# MoonBit Maintainer Compass\n\n"
  out = out + "- Root: `" + bundle.options.root + "`\n"
  out = out + "- Score: **" + bundle.report.score.to_string() + "/100**\n"
  let policy_text = if bundle.policy.passed { "pass" } else { "block" }
  out = out + "- Policy: **" + policy_text + "**\n"
  out = out + "- Release gate: **" + state_text(bundle.gate.state) + "**\n\n"
  if bundle.scan.warnings.length() > 0 {
    out = out + "## Scan Warnings\n\n"
    for warning in bundle.scan.warnings {
      out = out + "- " + warning + "\n"
    }
    out = out + "\n"
  }
  if bundle.report.findings.length() > 0 {
    out = out + "## Findings\n\n"
    for item in bundle.report.findings {
      out = out +
        "- `" +
        item.rule_id +
        "` `" +
        item.path +
        "`: " +
        item.message +
        "\n"
    }
    out = out + "\n"
  }
  out = out + "## Inventory\n\n```text\n"
  out = out + format_inventory_text(bundle.inventory) + "```\n\n"
  match bundle.delta {
    Some(value) => {
      out = out + "## Baseline\n\n"
      out = out + delta_summary(value) + "\n\n"
    }
    None => ()
  }
  out = out + "## Policy\n\n```text\n"
  out = out + format_policy_text(bundle.policy) + "```\n\n"
  out = out + "## Git\n\n```text\n"
  out = out + format_git_text(bundle.git) + "```\n\n"
  out = out + "## Release Gate\n\n```text\n"
  out = out + format_gate(bundle.gate) + "```\n\n"
  match bundle.trend {
    Some(value) => {
      out = out + "## Trend\n\n```text\n"
      out = out + format_trend_text(value) + "```\n\n"
    }
    None => ()
  }
  out = out + "## Actions\n\n```text\n"
  out = out + format_actions_text(bundle.actions) + "```\n\n"
  out = out + format_markdown(plan_from_report(bundle.report))
  out
}

///|
fn wrap_json_field(name : String, value : String, trailing : Bool) -> String {
  let suffix = if trailing { ",\n" } else { "\n" }
  "  \"" + name + "\": " + value + suffix
}

///|
fn json_string_array(values : Array[String]) -> String {
  let mut out = "["
  for i = 0; i < values.length(); i = i + 1 {
    if i > 0 {
      out = out + ", "
    }
    out = out + json_string(values[i])
  }
  out + "]"
}

///|
fn render_json_bundle(bundle : CliAudit) -> String {
  let mut out = "{\n"
  out = out + wrap_json_field("report", format_json(bundle.report), true)
  out = out +
    wrap_json_field("inventory", format_inventory_json(bundle.inventory), true)
  out = out + wrap_json_field("policy", format_policy_json(bundle.policy), true)
  out = out +
    wrap_json_field("actions", format_actions_json(bundle.actions), true)
  out = out + wrap_json_field("git", format_git_json(bundle.git), true)
  out = out + wrap_json_field("gate", format_gate_json(bundle.gate), true)
  out = out +
    wrap_json_field(
      "handoff",
      format_plan_json(plan_from_report(bundle.report)),
      true,
    )
  out = out +
    wrap_json_field("warnings", json_string_array(bundle.scan.warnings), true)
  match bundle.delta {
    Some(value) =>
      out = out + wrap_json_field("delta", format_delta_json(value), true)
    None => out = out + wrap_json_field("delta", "null", true)
  }
  match bundle.trend {
    Some(value) =>
      out = out + wrap_json_field("trend", format_trend_json(value), false)
    None => out = out + wrap_json_field("trend", "null", false)
  }
  out + "}\n"
}

///|
fn render_bundle(bundle : CliAudit) -> String {
  match bundle.options.format {
    TextOutput => render_text_bundle(bundle)
    JsonOutput => render_json_bundle(bundle)
    MarkdownOutput => render_markdown_bundle(bundle)
    AllOutput => {
      let text = render_text_bundle(bundle)
      let markdown = render_markdown_bundle(bundle)
      text + "\n\n===== Markdown =====\n\n" + markdown
    }
  }
}

///|
fn load_baseline(path : String?) -> HealthReport? raise {
  match path {
    None => None
    Some(value) => Some(parse_report_json(@fs.read_file_to_string(value)))
  }
}

///|
fn update_trend(
  options : CliOptions,
  report : HealthReport,
) -> HealthTrend? raise {
  match options.trend_path {
    None => None
    Some(path) => {
      let exists = @fs.path_exists(path)
      let prior = if exists {
        parse_trend_text(@fs.read_file_to_string(path))
      } else {
        empty_trend()
      }
      let trend = add_trend_point(
        prior,
        trend_point(@env.now().to_string(), report),
      )
      write_text_file(path, format_trend_series(trend))
      Some(trend)
    }
  }
}

///|
fn should_fail(
  options : CliOptions,
  policy : PolicyDecision,
  gate : ReleaseGate,
  delta : ReportDelta?,
) -> Bool {
  if options.fail_on_policy && !policy.passed {
    true
  } else if options.fail_on_gate && gate.state == Block {
    true
  } else {
    match delta {
      Some(value) => options.fail_on_regression && delta_has_regressions(value)
      None => false
    }
  }
}

///|
/// Execute the CLI and return a process exit code.
pub fn run_cli(args : Array[String]) -> Int {
  let options = parse_cli_options(args) catch {
    error => {
      println("error: " + error.to_string())
      println(format_cli_help())
      return 2
    }
  }
  if options.help {
    println(format_cli_help())
    return 0
  }
  if options.version {
    println("MoonBit Maintainer Compass 0.4.0")
    return 0
  }
  let scan = scan_project_result(options.root) catch {
    error => {
      println("scan failed: " + error.to_string())
      return 2
    }
  }
  let config = resolve_config(options) catch {
    error => {
      println("configuration failed: " + error.to_string())
      return 2
    }
  }
  let report = analyze_with_config(scan.project, config)
  let inventory = inventory(scan.project)
  let policy = evaluate_policy(report, config)
  let actions = recommend_actions(report)
  let git_audit = collect_git_audit(options.root)
  let handoff = plan_from_report(report)
  let gate = build_gate(options.root, report, git_audit, handoff)
  let baseline = load_baseline(options.baseline_path) catch {
    error => {
      println("baseline failed: " + error.to_string())
      return 2
    }
  }
  let delta = match baseline {
    Some(previous) => Some(diff_reports(previous, report))
    None => None
  }
  let trend = update_trend(options, report) catch {
    error => {
      println("trend failed: " + error.to_string())
      return 2
    }
  }
  let bundle : CliAudit = {
    options,
    scan,
    report,
    inventory,
    policy,
    actions,
    git: git_audit,
    gate,
    delta,
    trend,
  }
  let rendered = render_bundle(bundle)
  match options.output_path {
    Some(path) =>
      write_text_file(path, rendered) catch {
        error => {
          println("output failed: " + error.to_string())
          return 2
        }
      }
    None => ()
  }
  if !options.quiet {
    println(rendered)
  }
  if should_fail(options, policy, gate, delta) {
    1
  } else {
    0
  }
}
