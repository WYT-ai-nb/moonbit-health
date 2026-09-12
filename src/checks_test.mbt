///|
test "healthy project gets full score" {
  let project = snapshot([
    file("moon.mod.json", "{}"),
    file("src/moon.pkg.json", "{}"),
    file("README.md", "Usage\n\nmoon test"),
    file("LICENSE", "Apache-2.0"),
    file("src/checks_test.mbt", "test { assert_true(true) }"),
    file("cmd/main/main.mbt", "fn main { println(\"ok\") }"),
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
  inspect(report.score, content="85")
  inspect(format_text(report), content=
    #|MoonBit Health Report
    #|Score: 85/100
    #|- [warning] MBH004 README.md: README should include usage or verification commands
    #|- [warning] MBH006 *_test.mbt: tests are expected for hackathon verification
    #|- [info] MBH007 examples/: examples or a runnable cmd package help reviewers try the project
    #|
  )
}

///|
test "missing required files lower the score" {
  let report = analyze(snapshot([]))
  inspect(report.score, content="25")
  inspect(report.findings.length(), content="7")
}

///|
test "severity counts summarize a report" {
  let report = analyze(snapshot([]))
  inspect(count_severity(report, Error), content="4")
  inspect(count_severity(report, Warning), content="2")
  inspect(count_severity(report, Info), content="1")
}
