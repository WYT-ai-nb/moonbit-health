///|
/// Reason a configured release policy rejected a project.
pub enum PolicyBreachKind {
  ScoreBelowMinimum
  TooManyErrors
  TooManyWarnings
  TooManyInfos
  RequiredCiMissing
  RequiredTestsMissing
  RequiredChangelogMissing
} derive(Show, Eq)

///|
pub struct PolicyBreach {
  kind : PolicyBreachKind
  detail : String
  next_step : String
} derive(Show, Eq)

///|
pub struct PolicyDecision {
  profile : CompassProfile
  passed : Bool
  score : Int
  breaches : Array[PolicyBreach]
} derive(Show, Eq)

///|
/// Relative urgency used by the action queue.
pub enum ActionBand {
  Immediate
  Planned
  Optional
} derive(Show, Eq)

///|
pub struct RecommendedAction {
  rule_id : String
  title : String
  rationale : String
  target : String
  band : ActionBand
  expected_gain : Int
  effort : Int
} derive(Show, Eq)

///|
fn has_rule(report : HealthReport, rule_id : String) -> Bool {
  report.findings.any(fn(item) { item.rule_id == rule_id })
}

///|
fn add_breach(
  breaches : Array[PolicyBreach],
  kind : PolicyBreachKind,
  detail : String,
  next_step : String,
) -> Unit {
  breaches.push({ kind, detail, next_step, })
}

///|
/// Evaluate score and severity budgets from a configured report.
pub fn evaluate_policy(
  report : HealthReport,
  config : CompassConfig,
) -> PolicyDecision {
  let breaches : Array[PolicyBreach] = []
  if report.score < config.minimum_score {
    add_breach(
      breaches,
      ScoreBelowMinimum,
      "score " +
      report.score.to_string() +
      " is below minimum " +
      config.minimum_score.to_string(),
      "Resolve the highest-impact findings first.",
    )
  }
  let errors = count_severity(report, Error)
  let warnings = count_severity(report, Warning)
  let infos = count_severity(report, Info)
  if errors > config.maximum_errors {
    add_breach(
      breaches,
      TooManyErrors,
      errors.to_string() +
      " errors exceed budget " +
      config.maximum_errors.to_string(),
      "Fix every error before requesting a handoff.",
    )
  }
  if warnings > config.maximum_warnings {
    add_breach(
      breaches,
      TooManyWarnings,
      warnings.to_string() +
      " warnings exceed budget " +
      config.maximum_warnings.to_string(),
      "Reduce warnings or choose an explicitly documented exception.",
    )
  }
  if infos > config.maximum_infos {
    add_breach(
      breaches,
      TooManyInfos,
      infos.to_string() +
      " infos exceed budget " +
      config.maximum_infos.to_string(),
      "Turn the remaining review notes into tracked follow-up work.",
    )
  }
  if config.require_ci && has_rule(report, "MBH010") {
    add_breach(
      breaches,
      RequiredCiMissing,
      "CI is required by the current profile",
      "Add a workflow under .github/workflows/.",
    )
  }
  if config.require_tests && has_rule(report, "MBH006") {
    add_breach(
      breaches,
      RequiredTestsMissing,
      "tests are required by the current profile",
      "Add tests that exercise the public behavior.",
    )
  }
  if config.require_changelog && has_rule(report, "MBH009") {
    add_breach(
      breaches,
      RequiredChangelogMissing,
      "a changelog is required by the current profile",
      "Record the current release and notable changes.",
    )
  }
  {
    profile: config.profile,
    passed: breaches.length() == 0,
    score: report.score,
    breaches,
  }
}

///|
/// Analyze a project with configuration and evaluate its policy in one step.
pub fn evaluate_project_policy(
  project : ProjectSnapshot,
  config : CompassConfig,
) -> PolicyDecision {
  evaluate_policy(analyze_with_config(project, config), config)
}

///|
pub fn policy_exit_code(decision : PolicyDecision) -> Int {
  if decision.passed {
    0
  } else {
    1
  }
}

///|
fn breach_text(kind : PolicyBreachKind) -> String {
  match kind {
    ScoreBelowMinimum => "score"
    TooManyErrors => "errors"
    TooManyWarnings => "warnings"
    TooManyInfos => "infos"
    RequiredCiMissing => "ci"
    RequiredTestsMissing => "tests"
    RequiredChangelogMissing => "changelog"
  }
}

///|
pub fn format_policy_text(decision : PolicyDecision) -> String {
  let mut out = "Policy Decision\n"
  out = out + "Profile: " + profile_text(decision.profile) + "\n"
  let result = if decision.passed { "pass" } else { "block" }
  out = out + "Result: " + result + "\n"
  out = out + "Score: " + decision.score.to_string() + "/100\n"
  if decision.breaches.length() == 0 {
    out + "No policy breaches.\n"
  } else {
    out = out + "Breaches:\n"
    for item in decision.breaches {
      out = out +
        "- " +
        breach_text(item.kind) +
        ": " +
        item.detail +
        " Next: " +
        item.next_step +
        "\n"
    }
    out
  }
}

///|
pub fn format_policy_json(decision : PolicyDecision) -> String {
  let mut out = "{\n"
  out = out +
    "  \"profile\": " +
    json_string(profile_text(decision.profile)) +
    ",\n"
  out = out + "  \"passed\": " + decision.passed.to_string() + ",\n"
  out = out + "  \"score\": " + decision.score.to_string() + ",\n"
  out = out + "  \"breaches\": ["
  for i = 0; i < decision.breaches.length(); i = i + 1 {
    let item = decision.breaches[i]
    if i > 0 {
      out = out + ","
    }
    out = out +
      "\n    {\"kind\":" +
      json_string(breach_text(item.kind)) +
      ",\"detail\":" +
      json_string(item.detail) +
      "}"
  }
  if decision.breaches.length() > 0 {
    out + "\n  ]\n}\n"
  } else {
    out + "]\n}\n"
  }
}

///|
fn action_band(severity : Severity) -> ActionBand {
  match severity {
    Error => Immediate
    Warning => Planned
    Info => Optional
  }
}

///|
fn action_title(rule_id : String) -> String {
  match rule_id {
    "MBH001" => "Add the module manifest"
    "MBH002" => "Add MoonBit package metadata"
    "MBH003" => "Write the project README"
    "MBH004" => "Document usage and verification"
    "MBH005" => "Add an open-source license"
    "MBH006" => "Add automated tests"
    "MBH007" => "Add a runnable example or command"
    "MBH008" => "Write contributor handoff guidance"
    "MBH009" => "Record project history"
    "MBH010" => "Add repeatable CI"
    "MBH011" => "Show test and demo commands together"
    _ => "Resolve " + rule_id
  }
}

///|
fn action_effort(rule_id : String) -> Int {
  match rule_id {
    "MBH001" | "MBH005" | "MBH010" => 1
    "MBH003" | "MBH004" | "MBH007" | "MBH008" | "MBH009" | "MBH011" => 2
    "MBH002" | "MBH006" => 3
    _ => 2
  }
}

///|
fn expected_gain(severity : Severity) -> Int {
  match severity {
    Error => 20
    Warning => 10
    Info => 5
  }
}

///|
/// Convert findings into an action queue with explicit impact and effort.
pub fn recommend_actions(report : HealthReport) -> Array[RecommendedAction] {
  let actions : Array[RecommendedAction] = []
  for item in report.findings {
    actions.push({
      rule_id: item.rule_id,
      title: action_title(item.rule_id),
      rationale: item.message,
      target: item.path,
      band: action_band(item.severity),
      expected_gain: expected_gain(item.severity),
      effort: action_effort(item.rule_id),
    })
  }
  actions
}

///|
fn action_value(item : RecommendedAction) -> Int {
  item.expected_gain * 10 / item.effort
}

///|
fn should_precede(left : RecommendedAction, right : RecommendedAction) -> Bool {
  let left_value = action_value(left)
  let right_value = action_value(right)
  if left_value == right_value {
    left.rule_id < right.rule_id
  } else {
    left_value > right_value
  }
}

///|
/// Return a new action list sorted by impact per unit of effort.
pub fn rank_actions(
  actions : Array[RecommendedAction],
) -> Array[RecommendedAction] {
  let ranked : Array[RecommendedAction] = []
  for item in actions {
    let mut index = ranked.length()
    for i = 0; i < ranked.length(); i = i + 1 {
      if should_precede(item, ranked[i]) {
        index = i
        break
      }
    }
    ranked.insert(index, item)
  }
  ranked
}

///|
pub fn total_expected_gain(actions : Array[RecommendedAction]) -> Int {
  let mut total = 0
  for item in actions {
    total = total + item.expected_gain
  }
  total
}

///|
pub fn total_effort(actions : Array[RecommendedAction]) -> Int {
  let mut total = 0
  for item in actions {
    total = total + item.effort
  }
  total
}

///|
pub fn quick_win_count(actions : Array[RecommendedAction]) -> Int {
  actions
  .filter(fn(item) { item.effort == 1 && item.expected_gain >= 10 })
  .length()
}

///|
pub fn action_band_text(band : ActionBand) -> String {
  match band {
    Immediate => "immediate"
    Planned => "planned"
    Optional => "optional"
  }
}

///|
/// Render the ranked queue that a maintainer should execute next.
pub fn format_actions_text(actions : Array[RecommendedAction]) -> String {
  let ranked = rank_actions(actions)
  let mut out = "Recommended Action Queue\n"
  out = out +
    "Potential score gain: " +
    total_expected_gain(ranked).to_string() +
    "\n"
  out = out +
    "Estimated effort points: " +
    total_effort(ranked).to_string() +
    "\n"
  out = out + "Quick wins: " + quick_win_count(ranked).to_string() + "\n"
  if ranked.length() == 0 {
    out + "No actions required.\n"
  } else {
    for i = 0; i < ranked.length(); i = i + 1 {
      let item = ranked[i]
      out = out +
        (i + 1).to_string() +
        ". [" +
        action_band_text(item.band) +
        "] " +
        item.rule_id +
        " " +
        item.title +
        " (+" +
        item.expected_gain.to_string() +
        ", effort " +
        item.effort.to_string() +
        ")\n"
      out = out + "   Target: " + item.target + "\n"
      out = out + "   Why: " + item.rationale + "\n"
    }
    out
  }
}

///|
pub fn format_actions_json(actions : Array[RecommendedAction]) -> String {
  let ranked = rank_actions(actions)
  let mut out = "{\n"
  out = out +
    "  \"potential_score_gain\": " +
    total_expected_gain(ranked).to_string() +
    ",\n"
  out = out +
    "  \"estimated_effort\": " +
    total_effort(ranked).to_string() +
    ",\n"
  out = out + "  \"quick_wins\": " + quick_win_count(ranked).to_string() + ",\n"
  out = out + "  \"actions\": ["
  for i = 0; i < ranked.length(); i = i + 1 {
    let item = ranked[i]
    if i > 0 {
      out = out + ","
    }
    out = out +
      "\n    {\"rule_id\":" +
      json_string(item.rule_id) +
      ",\"band\":" +
      json_string(action_band_text(item.band)) +
      ",\"expected_gain\":" +
      item.expected_gain.to_string() +
      ",\"effort\":" +
      item.effort.to_string() +
      "}"
  }
  if ranked.length() > 0 {
    out + "\n  ]\n}\n"
  } else {
    out + "]\n}\n"
  }
}
