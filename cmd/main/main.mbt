///|
fn main {
  let sample = @health.snapshot([
    @health.file("moon.mod.json", "{}"),
    @health.file("src/moon.pkg.json", "{}"),
    @health.file("README.md", "Usage\nmoon test\nmoon run cmd/main"),
    @health.file("LICENSE", "Apache-2.0"),
    @health.file("src/checks_test.mbt", "test { assert_true(true) }"),
    @health.file("cmd/main/main.mbt", "fn main { println(\"ok\") }"),
    @health.file("CONTRIBUTING.md", "How to contribute"),
    @health.file("CHANGELOG.md", "0.1.0"),
    @health.file(".github/workflows/check.yml", "moon test\nmoon run cmd/main"),
  ])
  let report = @health.analyze(sample)
  println(@health.format_text(report))
  println(@health.format_handoff(report))
  println(@health.format_json(report))
  let handoff = @health.plan_from_report(report)
  println(@health.format_markdown(handoff))
  println(@health.format_plan_json(handoff))
  println(@health.format_git_text(@health.demo_git_audit()))
  println(@health.format_gate(@health.build_gate(
    "MoonBit Maintainer Compass",
    report,
    @health.demo_git_audit(),
    handoff,
  )))
}
