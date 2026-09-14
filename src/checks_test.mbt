///|
test "healthy project gets full score" {
  let project = snapshot([
    file("moon.mod.json", "{}"),
    file("src/moon.pkg.json", "{}"),
    file("README.md", "Usage\n\nmoon test\nmoon run cmd/main"),
    file("LICENSE", "Apache-2.0"),
    file("src/checks_test.mbt", "test { assert_true(true) }"),
    file("cmd/main/main.mbt", "fn main { println(\"ok\") }"),
    file("CONTRIBUTING.md", "How to contribute"),
    file("CHANGELOG.md", "0.1.0"),
    file(".github/workflows/check.yml", "moon test"),
  ])
  let report = analyze(project)
  inspect(report.score, content="100")
  inspect(report.findings.length(), content="0")
}

///|
test "missing tests and usage are reported" {
  let project = snapshot([
    file("moon.mod.json", "{}"),
    file("src/moon.pkg.json", "{}"),
    file("README.md", "MoonBit package"),
    file("LICENSE", "Apache-2.0"),
  ])
  let report = analyze(project)
  inspect(report.score, content="40")
  inspect(format_text(report), content=
    #|MoonBit Health Report
    #|Score: 40/100
    #|- [warning] MBH004 README.md: README should include usage or verification commands
    #|- [warning] MBH006 *_test.mbt: tests are expected for hackathon verification
    #|- [info] MBH007 examples/: examples or a runnable cmd package help reviewers try the project
    #|- [warning] MBH008 CONTRIBUTING.md: a maintainer guide is needed for project handoff
    #|- [warning] MBH009 CHANGELOG.md: a changelog helps reviewers understand project progress
    #|- [info] MBH010 .github/workflows/: a GitHub Actions workflow makes verification repeatable
    #|- [warning] MBH011 README.md: README should show both test and demo commands
    #|
  )
}

///|
test "missing required files lower the score" {
  let report = analyze(snapshot([]))
  inspect(report.score, content="0")
  inspect(report.findings.length(), content="11")
}

///|
test "severity counts summarize a report" {
  let report = analyze(snapshot([]))
  inspect(count_severity(report, severity_error()), content="4")
  inspect(count_severity(report, severity_warning()), content="5")
  inspect(count_severity(report, severity_info()), content="2")
}

///|
test "common license filename variants are accepted" {
  let project = snapshot([
    file("moon.mod.json", "{}"),
    file("src/moon.pkg.json", "{}"),
    file("README.md", "Usage\nmoon test"),
    file("LICENSE.txt", "Apache-2.0"),
  ])
  let report = analyze(project)
  inspect(report.findings.any(fn(item) { item.rule_id == "MBH005" }), content="false")
}

///|
test "handoff plan explains the next maintainer's actions" {
  let report = analyze(snapshot([]))
  inspect(format_handoff(report).contains("Handoff Plan"), content="true")
  inspect(format_handoff(report).contains("MBH001"), content="true")
}
