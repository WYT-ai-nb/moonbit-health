///|
test "normalizes Windows and repeated separators" {
  inspect(normalize_path(".\\src\\\\checks.mbt"), content="src/checks.mbt")
}

///|
test "extracts basename directory and extension" {
  inspect(basename("src/checks_test.mbt"), content="checks_test.mbt")
  inspect(dirname("src/nested/checks.mbt"), content="src/nested")
  inspect(file_extension("src/CHECKS.MBT"), content="mbt")
}

///|
test "classifies MoonBit source and tests" {
  inspect(classify_path("src/checks.mbt"), content="Source")
  inspect(classify_path("src/checks_test.mbt"), content="Test")
}

///|
test "classifies documentation automation and configuration" {
  inspect(classify_path("README.md"), content="Documentation")
  inspect(classify_path(".github/workflows/check.yml"), content="Automation")
  inspect(classify_path("moon.mod.json"), content="Configuration")
}

///|
test "generated directories are excluded from source" {
  inspect(is_generated_path("target/release/app"), content="true")
  inspect(classify_path("_build/source.mbt"), content="Generated")
}

///|
test "inventory summarizes project content" {
  let project = snapshot([
    file("moon.mod.json", "{}"),
    file("src/checks.mbt", "source"),
    file("src/checks_test.mbt", "tests"),
    file("README.md", "docs"),
    file(".github/workflows/check.yml", "moon test"),
    file("target/generated.mbt", "generated"),
  ])
  let value = inventory(project)
  inspect(value.entries.length(), content="6")
  inspect(value.source_files, content="1")
  inspect(value.test_files, content="1")
  inspect(value.documentation_files, content="1")
  inspect(value.automation_files, content="1")
  inspect(value.generated_files, content="1")
  inspect(value.total_bytes, content="35")
}

///|
test "inventory count helpers filter by kind and extension" {
  let value = inventory(
    snapshot([
      file("src/a.mbt", "a"),
      file("src/b.mbt", "b"),
      file("fixtures/demo/src/a.mbt", "a"),
    ]),
  )
  inspect(inventory_count(value, inventory_source()), content="3")
  inspect(count_extension(value, "MBT"), content="3")
  inspect(count_under(value, "fixtures"), content="1")
}

///|
test "largest file and test ratio are deterministic" {
  let value = inventory(
    snapshot([file("src/a.mbt", "1234567890"), file("src/a_test.mbt", "12345")]),
  )
  inspect(test_to_source_percent(value), content="50")
  match largest_entry(value) {
    Some(item) => inspect(item.path, content="src/a.mbt")
    None => fail("expected a largest file")
  }
}

///|
test "inventory text and JSON expose aggregate counts" {
  let value = inventory(snapshot([file("src/a.mbt", "a")]))
  inspect(
    format_inventory_text(value).contains("Source files: 1"),
    content="true",
  )
  inspect(
    format_inventory_json(value).contains("\"source_files\": 1"),
    content="true",
  )
}
