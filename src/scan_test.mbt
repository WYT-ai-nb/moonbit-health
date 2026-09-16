///|
test "scan_project reads an existing fixture from disk" {
  let result = scan_project_result("fixtures/good_project")
  let paths = result.project.files.map(fn(item) { item.path })
  inspect(paths.contains("README.md"), content="true")
  inspect(paths.contains("moon.mod.json"), content="true")
  inspect(paths.contains("src/moon.pkg.json"), content="true")
}

///|
test "scan_project skips generated directories" {
  let root = "_build/scan_fixture"
  if @fs.path_exists(root) {
    remove_test_tree(root)
  }
  @fs.create_dir(root)
  @fs.create_dir(root + "/target")
  write_text_file(root + "/README.md", "Usage\nmoon test\nmoon run cmd/main")
  write_text_file(
    root + "/target/generated.mbt",
    "fn generated() -> Unit { () }",
  )
  let result = scan_project_result(root)
  let paths = result.project.files.map(fn(item) { item.path })
  inspect(paths.contains("README.md"), content="true")
  inspect(paths.contains("target/generated.mbt"), content="false")
  remove_test_tree(root)
}

///|
test "scan and config helpers round-trip real files" {
  let path = "_build/scan_fixture.conf"
  write_text_file(
    path,
    (
      #|profile = release
      #|maximum_warnings = 7
    ),
  )
  let config = load_config(path)
  inspect(config.profile, content="Release")
  inspect(config.maximum_warnings, content="7")
  @fs.remove_file(path)
}

///|
test "readable_text_file filters binary-like extensions" {
  inspect(readable_text_file("src/main.mbt"), content="true")
  inspect(readable_text_file("README.md"), content="true")
  inspect(readable_text_file("assets/image.png"), content="false")
}

///|
test "binary file sizes are preserved in scanned snapshots" {
  let root = "_build/scan_size_fixture"
  if @fs.path_exists(root) {
    remove_test_tree(root)
  }
  @fs.create_dir(root)
  @fs.write_bytes_to_file(root + "/image.bin", b"\x00\x01\x02")
  let project = scan_project(root)
  let image = project.files.filter(fn(item) { item.path == "image.bin" })[0]
  inspect(image.size, content="3")
  remove_test_tree(root)
}

///|
fn remove_test_tree(root : String) -> Unit raise {
  if @fs.is_dir(root) {
    for name in @fs.read_dir(root).to_owned() {
      let child = root + "/" + name
      if @fs.is_dir(child) {
        remove_test_tree(child)
      } else {
        @fs.remove_file(child)
      }
    }
    @fs.remove_dir(root)
  }
}
