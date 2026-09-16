///|
fn policy_project(extra : Array[ProjectFile]) -> ProjectSnapshot {
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
  )
}

///|
test "healthy project passes release policy" {
  let decision = evaluate_project_policy(policy_project([]), release_config())
  inspect(decision.passed, content="true")
  inspect(decision.breaches.length(), content="0")
  inspect(policy_exit_code(decision), content="0")
}

///|
test "missing required evidence blocks release policy" {
  let decision = evaluate_project_policy(snapshot([]), release_config())
  inspect(decision.passed, content="false")
  inspect(decision.breaches.length(), content="6")
  inspect(policy_exit_code(decision), content="1")
}

///|
test "policy JSON and text explain failures" {
  let decision = evaluate_project_policy(snapshot([]), release_config())
  inspect(
    format_policy_text(decision).contains("Result: block"),
    content="true",
  )
  inspect(
    format_policy_json(decision).contains("\"passed\": false"),
    content="true",
  )
}

///|
test "recommended actions map findings to remedies" {
  let actions = recommend_actions(analyze(snapshot([])))
  inspect(actions.length(), content="11")
  inspect(
    actions.any(fn(item) {
      item.rule_id == "MBH001" && item.expected_gain == 20
    }),
    content="true",
  )
}

///|
test "ranked actions prefer impact per effort" {
  let ranked = rank_actions(recommend_actions(analyze(snapshot([]))))
  inspect(ranked[0].rule_id, content="MBH001")
  inspect(ranked[0].effort, content="1")
}

///|
test "action totals estimate remaining work" {
  let actions = recommend_actions(analyze(snapshot([])))
  inspect(total_expected_gain(actions), content="140")
  inspect(total_effort(actions) > 0, content="true")
  inspect(quick_win_count(actions) > 0, content="true")
}

///|
test "action queue text and JSON are renderable" {
  let actions = recommend_actions(analyze(snapshot([])))
  let text = format_actions_text(actions)
  inspect(text.contains("Recommended Action Queue"), content="true")
  inspect(text.contains("1. [immediate] MBH001"), content="true")
  inspect(
    format_actions_json(actions).contains("\"quick_wins\""),
    content="true",
  )
}
