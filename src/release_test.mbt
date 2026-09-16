///|
fn complete_demo_plan() -> HandoffPlan {
  let value = plan("Demo", "owner", [
    task(
      "DOC",
      "read guide",
      "read",
      priority_p1(),
      kind_understand(),
      "README.md",
    ),
  ])
  complete_task(value, "DOC")
}

///|
fn complete_demo_report() -> HealthReport {
  analyze(
    snapshot([
      file("moon.mod.json", "{}"),
      file("src/moon.pkg.json", "{}"),
      file("README.md", "Usage moon test moon run"),
      file("LICENSE", "Apache-2.0"),
      file("src/app_test.mbt", "test { assert_true(true) }"),
      file("cmd/main/main.mbt", "fn main { println(\"ok\") }"),
      file("CONTRIBUTING.md", "guide"),
      file("CHANGELOG.md", "history"),
      file(".github/workflows/check.yml", "moon test"),
    ]),
  )
}

///|
test "healthy inputs pass the release gate" {
  let gate = build_gate(
    "Compass",
    complete_demo_report(),
    demo_git_audit(),
    complete_demo_plan(),
  )
  inspect(gate_score(gate), content="100")
  inspect(state_text(gate_state(gate)), content="pass")
  inspect(blocking_items(gate).length(), content="0")
}

///|
test "missing repository remote blocks delivery" {
  let audit = git_audit(branch("main", None, 0, 0, true), [], false, true)
  let gate = build_gate(
    "Compass",
    complete_demo_report(),
    audit,
    complete_demo_plan(),
  )
  inspect(state_text(gate_state(gate)), content="block")
  inspect(blocking_items(gate).length(), content="2")
}

///|
test "open non critical task requests review" {
  let gate = build_gate(
    "Compass",
    complete_demo_report(),
    demo_git_audit(),
    plan("Compass", "owner", [
      task(
        "DOC",
        "write guide",
        "write",
        priority_p1(),
        kind_document(),
        "CONTRIBUTING.md",
      ),
    ]),
  )
  inspect(state_text(gate_state(gate)), content="review")
  inspect(review_items(gate).length(), content="2")
}

///|
test "area labels are stable" {
  inspect(area_text(area_repository()), content="repository")
  inspect(area_text(area_documentation()), content="documentation")
  inspect(area_text(area_collaboration()), content="collaboration")
  inspect(area_text(area_delivery()), content="delivery")
}

///|
test "gate output explains next steps" {
  let gate = build_gate(
    "Compass",
    complete_demo_report(),
    demo_git_audit(),
    complete_demo_plan(),
  )
  let text = format_gate(gate)
  inspect(text.contains("Release Gate: Compass"), content="true")
  inspect(text.contains("Decision: pass"), content="true")
  inspect(text.contains("Next:"), content="true")
}
