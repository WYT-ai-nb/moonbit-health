///|
/// A release gate combines independent checks into one explainable decision.
pub enum GateState {
  Pass
  Review
  Block
} derive(Show, Eq)

///|
pub enum GateArea {
  Repository
  Documentation
  Collaboration
  Delivery
} derive(Show, Eq)

///|
pub struct GateItem {
  id : String
  area : GateArea
  state : GateState
  summary : String
  next_step : String
} derive(Show, Eq)

///|
pub struct ReleaseGate {
  project_name : String
  items : Array[GateItem]
  score : Int
  state : GateState
} derive(Show, Eq)

///|
pub fn gate_pass() -> GateState {
  Pass
}

///|
pub fn gate_review() -> GateState {
  Review
}

///|
pub fn gate_block() -> GateState {
  Block
}

///|
pub fn area_repository() -> GateArea {
  Repository
}

///|
pub fn area_documentation() -> GateArea {
  Documentation
}

///|
pub fn area_collaboration() -> GateArea {
  Collaboration
}

///|
pub fn area_delivery() -> GateArea {
  Delivery
}

///|
fn gate_item(
  id : String,
  area : GateArea,
  state : GateState,
  summary : String,
  next_step : String,
) -> GateItem {
  { id, area, state, summary, next_step, }
}

///|
fn state_weight(state : GateState) -> Int {
  match state {
    Pass => 100
    Review => 60
    Block => 0
  }
}

///|
fn strongest(a : GateState, b : GateState) -> GateState {
  if state_weight(a) <= state_weight(b) {
    a
  } else {
    b
  }
}

///|
fn report_state(report : HealthReport) -> GateState {
  if report.score < 60 {
    Block
  } else if report.score < 100 {
    Review
  } else {
    Pass
  }
}

///|
fn git_state(audit : GitAudit) -> GateState {
  if !audit.available ||
    !audit.branch.clean_known ||
    !audit.branch.sync_known ||
    !audit.history_known {
    Review
  } else if !audit.branch.clean || audit.branch.behind > 0 || !audit.has_remote {
    Block
  } else if !audit.has_tags || risky_commit_count(audit) > 0 {
    Review
  } else {
    Pass
  }
}

///|
fn handoff_state(plan : HandoffPlan) -> GateState {
  if p0_count(plan) > 0 {
    Block
  } else if pending_count(plan) > 0 {
    Review
  } else {
    Pass
  }
}

///|
pub fn area_text(area : GateArea) -> String {
  match area {
    Repository => "repository"
    Documentation => "documentation"
    Collaboration => "collaboration"
    Delivery => "delivery"
  }
}

///|
pub fn state_text(state : GateState) -> String {
  match state {
    Pass => "pass"
    Review => "review"
    Block => "block"
  }
}

///|
pub fn build_gate(
  project_name : String,
  report : HealthReport,
  audit : GitAudit,
  handoff : HandoffPlan,
) -> ReleaseGate {
  let report_result = report_state(report)
  let git_result = git_state(audit)
  let handoff_result = handoff_state(handoff)
  let overall = strongest(strongest(report_result, git_result), handoff_result)
  let items = [
    gate_item(
      "HEALTH",
      Documentation,
      report_result,
      "Project structure and reproducibility rules",
      "Resolve health findings",
    ),
    gate_item(
      "GIT",
      Repository,
      git_result,
      "Branch, remote, tags, and commit reviewability",
      branch_status(audit),
    ),
    gate_item(
      "HANDOFF",
      Collaboration,
      handoff_result,
      "Next-maintainer tasks and ownership transfer",
      "Complete the open handoff tasks",
    ),
    gate_item(
      "DELIVERY",
      Delivery,
      overall,
      "Combined release recommendation",
      "Review every block or review item",
    ),
  ]
  let mut total = 0
  for item in items {
    total = total + state_weight(item.state)
  }
  { project_name, items, score: total / items.length(), state: overall, }
}

///|
pub fn gate_score(gate : ReleaseGate) -> Int {
  gate.score
}

///|
pub fn gate_state(gate : ReleaseGate) -> GateState {
  gate.state
}

///|
pub fn gate_items(gate : ReleaseGate) -> Array[GateItem] {
  gate.items
}

///|
pub fn blocking_items(gate : ReleaseGate) -> Array[GateItem] {
  gate.items.filter(fn(item) { item.state == Block })
}

///|
pub fn review_items(gate : ReleaseGate) -> Array[GateItem] {
  gate.items.filter(fn(item) { item.state == Review })
}

///|
pub fn format_gate(gate : ReleaseGate) -> String {
  let mut out = "Release Gate: " + gate.project_name + "\n"
  out = out + "Decision: " + state_text(gate.state) + "\n"
  out = out + "Gate score: " + gate.score.to_string() + "/100\n"
  for item in gate.items {
    out = out +
      "- [" +
      state_text(item.state) +
      "] " +
      item.id +
      " (" +
      area_text(item.area) +
      "): " +
      item.summary +
      "\n"
    out = out + "  Next: " + item.next_step + "\n"
  }
  out
}

///|
pub fn format_gate_json(gate : ReleaseGate) -> String {
  let mut out = "{\n"
  out = out + "  \"project\": " + json_string(gate.project_name) + ",\n"
  out = out + "  \"state\": " + json_string(state_text(gate.state)) + ",\n"
  out = out + "  \"score\": " + gate.score.to_string() + ",\n"
  out = out + "  \"items\": ["
  for i = 0; i < gate.items.length(); i = i + 1 {
    let item = gate.items[i]
    if i > 0 {
      out = out + ","
    }
    out = out +
      "\n    {\"id\":" +
      json_string(item.id) +
      ",\"area\":" +
      json_string(area_text(item.area)) +
      ",\"state\":" +
      json_string(state_text(item.state)) +
      ",\"summary\":" +
      json_string(item.summary) +
      ",\"next_step\":" +
      json_string(item.next_step) +
      "}"
  }
  if gate.items.length() > 0 {
    out + "\n  ]\n}\n"
  } else {
    out + "]\n}\n"
  }
}
