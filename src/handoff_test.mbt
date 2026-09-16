///|
fn sample_plan() -> HandoffPlan {
  plan("Compass demo", "maintainer", [
    task(
      "DOC",
      "read the contributor guide",
      "Understand the workflow",
      priority_p0(),
      kind_understand(),
      "CONTRIBUTING.md",
    ),
    task(
      "TEST",
      "run the verification commands",
      "Check reproducibility",
      priority_p1(),
      kind_verify(),
      "README.md",
    ),
    task(
      "LOG",
      "review recent changes",
      "Understand project history",
      priority_p2(),
      kind_document(),
      "CHANGELOG.md",
    ),
  ])
}

///|
test "new plan has pending tasks" {
  let value = sample_plan()
  inspect(task_count(value), content="3")
  inspect(pending_count(value), content="3")
  inspect(p0_count(value), content="1")
  inspect(handoff_score(value), content="0")
}

///|
test "complete task updates progress" {
  let value = complete_task(sample_plan(), "DOC")
  inspect(pending_count(value), content="2")
  inspect(p0_count(value), content="0")
  inspect(handoff_score(value), content="33")
}

///|
test "unknown task leaves plan unchanged" {
  let value = complete_task(sample_plan(), "UNKNOWN")
  inspect(pending_count(value), content="3")
  inspect(handoff_score(value), content="0")
}

///|
test "repeating completion is harmless" {
  let value = complete_task(complete_task(sample_plan(), "DOC"), "DOC")
  inspect(pending_count(value), content="2")
  inspect(handoff_score(value), content="33")
}

///|
test "all tasks complete means full progress" {
  let value = sample_plan()
  let value = complete_task(value, "DOC")
  let value = complete_task(value, "TEST")
  let value = complete_task(value, "LOG")
  inspect(pending_count(value), content="0")
  inspect(handoff_score(value), content="100")
}

///|
test "empty plan is ready" {
  let value = plan("Empty", "owner", [])
  inspect(task_count(value), content="0")
  inspect(pending_count(value), content="0")
  inspect(handoff_score(value), content="100")
}

///|
test "notes are included in markdown" {
  let value = add_note(
    sample_plan(),
    "Ask the community for a second reviewer.",
  )
  let text = format_markdown(value)
  inspect(text.contains("Ask the community"), content="true")
  inspect(text.contains("# Maintainer Handoff Plan"), content="true")
}

///|
test "markdown includes task metadata" {
  let text = format_markdown(sample_plan())
  inspect(text.contains("P0 DOC"), content="true")
  inspect(text.contains("understand"), content="true")
  inspect(text.contains("CONTRIBUTING.md"), content="true")
  inspect(text.contains("Progress: 0%"), content="true")
}

///|
test "json includes project and progress" {
  let text = format_plan_json(sample_plan())
  inspect(text.contains("\"project\": \"Compass demo\""), content="true")
  inspect(text.contains("\"progress\": 0"), content="true")
  inspect(text.contains("\"id\":\"DOC\""), content="true")
}

///|
test "priority labels are stable" {
  inspect(priority_text(priority_p0()), content="P0")
  inspect(priority_text(priority_p1()), content="P1")
  inspect(priority_text(priority_p2()), content="P2")
}

///|
test "kind labels are stable" {
  inspect(kind_text(kind_understand()), content="understand")
  inspect(kind_text(kind_verify()), content="verify")
  inspect(kind_text(kind_document()), content="document")
  inspect(kind_text(kind_publish()), content="publish")
}

///|
test "report findings become p0 tasks" {
  let report = analyze(snapshot([]))
  let value = plan_from_report(report)
  inspect(task_count(value), content="11")
  inspect(p0_count(value), content="4")
  inspect(pending_count(value), content="11")
}

///|
test "report findings become a readable plan" {
  let report = analyze(snapshot([]))
  let text = format_markdown(plan_from_report(report))
  inspect(text.contains("MBH001"), content="true")
  inspect(text.contains("moon.mod.json"), content="true")
  inspect(text.contains("Before handoff"), content="false")
}

///|
test "completed task is marked in markdown" {
  let value = complete_task(sample_plan(), "DOC")
  let text = format_markdown(value)
  inspect(text.contains("[x] P0 DOC"), content="true")
}

///|
test "json records false for pending tasks" {
  let text = format_plan_json(sample_plan())
  inspect(text.contains("\"done\":false"), content="true")
}

///|
test "json records true for completed tasks" {
  let text = format_plan_json(complete_task(sample_plan(), "DOC"))
  inspect(text.contains("\"done\":true"), content="true")
}
