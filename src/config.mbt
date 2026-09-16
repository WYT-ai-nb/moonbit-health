///|
/// Built-in policy levels for common MoonBit project workflows.
pub enum CompassProfile {
  Community
  Release
  Strict
} derive(Show, Eq)

///|
/// A rule can be disabled or forced to a specific severity.
pub enum RuleState {
  Enabled
  Disabled
  ForceInfo
  ForceWarning
  ForceError
} derive(Show, Eq)

///|
pub struct RuleOverride {
  rule_id : String
  state : RuleState
} derive(Show, Eq)

///|
/// Deterministic configuration for rule filtering and release policy.
pub struct CompassConfig {
  profile : CompassProfile
  minimum_score : Int
  maximum_errors : Int
  maximum_warnings : Int
  maximum_infos : Int
  require_ci : Bool
  require_tests : Bool
  require_changelog : Bool
  ignored_paths : Array[String]
  overrides : Array[RuleOverride]
} derive(Show, Eq)

///|
pub suberror ConfigError {
  InvalidLine(String)
  InvalidValue(String)
  InvalidSeverity(String)
  UnknownProfile(String)
  UnknownRule(String)
  DuplicateRule(String)
} derive(Show, Eq)

///|
pub fn default_config() -> CompassConfig {
  {
    profile: Community,
    minimum_score: 70,
    maximum_errors: 0,
    maximum_warnings: 4,
    maximum_infos: 4,
    require_ci: false,
    require_tests: true,
    require_changelog: false,
    ignored_paths: [],
    overrides: [],
  }
}

///|
pub fn community_config() -> CompassConfig {
  default_config()
}

///|
pub fn release_config() -> CompassConfig {
  {
    profile: Release,
    minimum_score: 90,
    maximum_errors: 0,
    maximum_warnings: 1,
    maximum_infos: 2,
    require_ci: true,
    require_tests: true,
    require_changelog: true,
    ignored_paths: [],
    overrides: [],
  }
}

///|
pub fn strict_config() -> CompassConfig {
  {
    profile: Strict,
    minimum_score: 100,
    maximum_errors: 0,
    maximum_warnings: 0,
    maximum_infos: 0,
    require_ci: true,
    require_tests: true,
    require_changelog: true,
    ignored_paths: [],
    overrides: [],
  }
}

///|
pub fn config_for_profile(profile : CompassProfile) -> CompassConfig {
  match profile {
    Community => community_config()
    Release => release_config()
    Strict => strict_config()
  }
}

///|
pub fn config_named(profile : String) -> CompassConfig raise ConfigError {
  config_for_profile(parse_profile(profile))
}

///|
fn profile_text(profile : CompassProfile) -> String {
  match profile {
    Community => "community"
    Release => "release"
    Strict => "strict"
  }
}

///|
fn rule_state_text(state : RuleState) -> String {
  match state {
    Enabled => "enabled"
    Disabled => "off"
    ForceInfo => "info"
    ForceWarning => "warning"
    ForceError => "error"
  }
}

///|
fn parse_profile(value : String) -> CompassProfile raise ConfigError {
  match value.to_lower() {
    "community" => Community
    "release" => Release
    "strict" => Strict
    _ => raise UnknownProfile(value)
  }
}

///|
fn parse_rule_state(value : String) -> RuleState raise ConfigError {
  match value.to_lower() {
    "on" | "enabled" => Enabled
    "off" | "disabled" => Disabled
    "info" => ForceInfo
    "warning" | "warn" => ForceWarning
    "error" => ForceError
    _ => raise InvalidSeverity(value)
  }
}

///|
fn parse_non_negative(value : String) -> Int raise ConfigError {
  try @string.parse_int(value) catch {
    _ => raise InvalidValue(value)
  } noraise {
    number => if number < 0 { raise InvalidValue(value) } else { number }
  }
}

///|
fn parse_bool(value : String) -> Bool raise ConfigError {
  match value.to_lower() {
    "true" | "yes" | "on" | "1" => true
    "false" | "no" | "off" | "0" => false
    _ => raise InvalidValue(value)
  }
}

///|
pub fn known_rule_id(rule_id : String) -> Bool {
  rule_id == "MBH001" ||
  rule_id == "MBH002" ||
  rule_id == "MBH003" ||
  rule_id == "MBH004" ||
  rule_id == "MBH005" ||
  rule_id == "MBH006" ||
  rule_id == "MBH007" ||
  rule_id == "MBH008" ||
  rule_id == "MBH009" ||
  rule_id == "MBH010" ||
  rule_id == "MBH011"
}

///|
fn with_override(
  config : CompassConfig,
  rule_id : String,
  state : RuleState,
) -> CompassConfig {
  config.overrides.push({ rule_id, state, })
  config
}

///|
/// Parse a small line-oriented configuration format.
///
/// Supported keys:
/// - `profile = community|release|strict`
/// - `minimum_score = 0..100`
/// - `maximum_errors`, `maximum_warnings`, `maximum_infos`
/// - `require_ci`, `require_tests`, `require_changelog`
/// - `ignore = path`
/// - `rule.MBH001 = off|info|warning|error`
pub fn parse_config(text : String) -> CompassConfig raise ConfigError {
  let mut config = default_config()
  for raw_line in text.split("\n") {
    let line = raw_line.trim()
    if line == "" || line.has_prefix("#") {
      continue
    }
    match line.split_once("=") {
      None => raise InvalidLine(line.to_owned())
      Some((raw_key, raw_value)) => {
        let key = raw_key.trim().to_owned()
        let value = raw_value.trim().to_owned()
        if key == "profile" {
          config = config_for_profile(parse_profile(value))
        } else if key == "minimum_score" {
          let number = parse_non_negative(value)
          if number > 100 {
            raise InvalidValue(value)
          }
          config = { ..config, minimum_score: number, }
        } else if key == "maximum_errors" {
          config = { ..config, maximum_errors: parse_non_negative(value), }
        } else if key == "maximum_warnings" {
          config = { ..config, maximum_warnings: parse_non_negative(value), }
        } else if key == "maximum_infos" {
          config = { ..config, maximum_infos: parse_non_negative(value), }
        } else if key == "require_ci" {
          config = { ..config, require_ci: parse_bool(value), }
        } else if key == "require_tests" {
          config = { ..config, require_tests: parse_bool(value), }
        } else if key == "require_changelog" {
          config = { ..config, require_changelog: parse_bool(value), }
        } else if key == "ignore" {
          if value == "" {
            raise InvalidValue(value)
          }
          config.ignored_paths.push(value)
        } else if key.has_prefix("rule.") {
          let rule_id = key[5:].to_owned()
          if rule_id == "" {
            raise InvalidLine(key)
          }
          if !known_rule_id(rule_id) {
            raise UnknownRule(rule_id)
          }
          if config.overrides.any(fn(item) { item.rule_id == rule_id }) {
            raise DuplicateRule(rule_id)
          }
          config = with_override(config, rule_id, parse_rule_state(value))
        } else {
          raise InvalidLine(key)
        }
      }
    }
  }
  config
}

///|
fn override_for(config : CompassConfig, rule_id : String) -> RuleState {
  let mut state = Enabled
  for item in config.overrides {
    if item.rule_id == rule_id {
      state = item.state
    }
  }
  state
}

///|
fn severity_for_state(state : RuleState, fallback : Severity) -> Severity {
  match state {
    Enabled => fallback
    Disabled => fallback
    ForceInfo => Info
    ForceWarning => Warning
    ForceError => Error
  }
}

///|
/// Return true when a finding path is covered by an ignored path rule.
pub fn is_ignored_path(config : CompassConfig, path : String) -> Bool {
  let normalized = normalize_path(path)
  for pattern in config.ignored_paths {
    let value = normalize_path(pattern)
    if normalized == value || normalized.has_prefix(value + "/") {
      return true
    }
  }
  false
}

///|
/// Apply rule overrides and path ignores to a health report.
pub fn apply_config(
  report : HealthReport,
  config : CompassConfig,
) -> HealthReport {
  let findings : Array[Finding] = []
  for item in report.findings {
    let state = override_for(config, item.rule_id)
    if state != Disabled && !is_ignored_path(config, item.path) {
      findings.push({
        ..item,
        severity: severity_for_state(state, item.severity),
      })
    }
  }
  { score: score(findings), findings, }
}

///|
pub fn analyze_with_config(
  project : ProjectSnapshot,
  config : CompassConfig,
) -> HealthReport {
  apply_config(analyze(project), config)
}

///|
/// Count findings at a severity after configuration has been applied.
pub fn severity_budget_left(
  report : HealthReport,
  severity : Severity,
  maximum : Int,
) -> Int {
  let used = count_severity(report, severity)
  if used >= maximum {
    0
  } else {
    maximum - used
  }
}

///|
pub fn format_config_text(config : CompassConfig) -> String {
  let mut out = "Compass Configuration\n"
  out = out + "Profile: " + profile_text(config.profile) + "\n"
  out = out + "Minimum score: " + config.minimum_score.to_string() + "\n"
  out = out + "Maximum errors: " + config.maximum_errors.to_string() + "\n"
  out = out + "Maximum warnings: " + config.maximum_warnings.to_string() + "\n"
  out = out + "Maximum infos: " + config.maximum_infos.to_string() + "\n"
  out = out + "Require CI: " + config.require_ci.to_string() + "\n"
  out = out + "Require tests: " + config.require_tests.to_string() + "\n"
  out = out +
    "Require changelog: " +
    config.require_changelog.to_string() +
    "\n"
  out = out +
    "Ignored paths: " +
    config.ignored_paths.length().to_string() +
    "\n"
  if config.overrides.length() == 0 {
    out + "Rule overrides: none\n"
  } else {
    out = out + "Rule overrides:\n"
    for item in config.overrides {
      out = out +
        "- " +
        item.rule_id +
        ": " +
        rule_state_text(item.state) +
        "\n"
    }
    out
  }
}

///|
pub fn format_config_json(config : CompassConfig) -> String {
  let mut out = "{\n"
  out = out +
    "  \"profile\": " +
    json_string(profile_text(config.profile)) +
    ",\n"
  out = out + "  \"minimum_score\": " + config.minimum_score.to_string() + ",\n"
  out = out +
    "  \"maximum_errors\": " +
    config.maximum_errors.to_string() +
    ",\n"
  out = out +
    "  \"maximum_warnings\": " +
    config.maximum_warnings.to_string() +
    ",\n"
  out = out + "  \"maximum_infos\": " + config.maximum_infos.to_string() + ",\n"
  out = out + "  \"require_ci\": " + config.require_ci.to_string() + ",\n"
  out = out + "  \"require_tests\": " + config.require_tests.to_string() + ",\n"
  out = out +
    "  \"require_changelog\": " +
    config.require_changelog.to_string() +
    ",\n"
  out = out + "  \"ignored_paths\": ["
  for i = 0; i < config.ignored_paths.length(); i = i + 1 {
    if i > 0 {
      out = out + ", "
    }
    out = out + json_string(config.ignored_paths[i])
  }
  out = out + "],\n  \"overrides\": ["
  for i = 0; i < config.overrides.length(); i = i + 1 {
    let item = config.overrides[i]
    if i > 0 {
      out = out + ","
    }
    out = out +
      "\n    {\"rule_id\":" +
      json_string(item.rule_id) +
      ",\"state\":" +
      json_string(rule_state_text(item.state)) +
      "}"
  }
  if config.overrides.length() > 0 {
    out + "\n  ]\n}\n"
  } else {
    out + "]\n}\n"
  }
}
