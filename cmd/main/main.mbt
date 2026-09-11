///|
fn main {
  let sample = @health.snapshot([
    @health.file("moon.mod.json", "{}"),
    @health.file("src/moon.pkg.json", "{}"),
    @health.file("README.md", "Usage\nmoon test"),
    @health.file("LICENSE", "Apache-2.0"),
    @health.file("src/checks_test.mbt", "test { assert_true(true) }"),
    @health.file("cmd/main/main.mbt", "fn main { println(\"ok\") }"),
  ])
  println(@health.format_text(@health.analyze(sample)))
}
