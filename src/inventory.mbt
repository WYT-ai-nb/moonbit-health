///|
/// A stable classification used by inventory summaries and policy checks.
pub enum InventoryKind {
  Source
  Test
  Documentation
  Configuration
  Automation
  Fixture
  Generated
  Other
} derive(Show, Eq)

///|
/// One normalized file record derived from a ProjectFile.
pub struct InventoryEntry {
  path : String
  directory : String
  basename : String
  extension : String
  kind : InventoryKind
  bytes : Int64
} derive(Show, Eq)

///|
/// Aggregate view of a project snapshot.
pub struct ProjectInventory {
  entries : Array[InventoryEntry]
  source_files : Int
  test_files : Int
  documentation_files : Int
  configuration_files : Int
  automation_files : Int
  fixture_files : Int
  generated_files : Int
  other_files : Int
  total_bytes : Int64
  directories : Array[String]
} derive(Show, Eq)

///|
pub fn inventory_source() -> InventoryKind {
  Source
}

///|
pub fn inventory_test() -> InventoryKind {
  Test
}

///|
pub fn inventory_documentation() -> InventoryKind {
  Documentation
}

///|
pub fn inventory_configuration() -> InventoryKind {
  Configuration
}

///|
pub fn inventory_automation() -> InventoryKind {
  Automation
}

///|
pub fn inventory_fixture() -> InventoryKind {
  Fixture
}

///|
pub fn inventory_generated() -> InventoryKind {
  Generated
}

///|
pub fn inventory_other() -> InventoryKind {
  Other
}

///|
/// Normalize path separators and remove a leading "./" prefix.
pub fn normalize_path(path : String) -> String {
  let mut expanded = ""
  for ch in path {
    if ch == '\\' {
      expanded = expanded + "/"
    } else {
      expanded = expanded + ch.to_string()
    }
  }
  while expanded.has_prefix("./") {
    expanded = expanded.substring(start=2)
  }
  let mut compact = ""
  let mut previous_slash = false
  for ch in expanded {
    if ch == '/' {
      if !previous_slash {
        compact = compact + "/"
      }
      previous_slash = true
    } else {
      compact = compact + ch.to_string()
      previous_slash = false
    }
  }
  compact
}

///|
/// Return the final path segment, or "." when the path is empty.
pub fn basename(path : String) -> String {
  let value = normalize_path(path)
  match value.rev_split_once("/") {
    Some((_, name)) => if name == "" { "." } else { name.to_string() }
    None => if value == "" { "." } else { value }
  }
}

///|
/// Return the directory portion of a normalized path.
pub fn dirname(path : String) -> String {
  let value = normalize_path(path)
  match value.rev_split_once("/") {
    Some((parent, _)) => if parent == "" { "." } else { parent.to_string() }
    None => "."
  }
}

///|
/// Return a lowercase extension without the leading dot.
pub fn file_extension(path : String) -> String {
  let name = basename(path)
  match name.rev_split_once(".") {
    Some((stem, extension)) =>
      if stem == "" {
        ""
      } else {
        extension.to_lower().to_owned()
      }
    None => ""
  }
}

///|
/// Return true when a path points inside a generated or dependency directory.
pub fn is_generated_path(path : String) -> Bool {
  let value = normalize_path(path)
  value.has_prefix("_build/") ||
  value.has_prefix("target/") ||
  value.has_prefix("node_modules/") ||
  value.has_prefix(".git/") ||
  value.has_prefix("dist/") ||
  value.contains("/_build/") ||
  value.contains("/target/") ||
  value.contains("/node_modules/") ||
  value.contains("/.git/")
}

///|
/// Classify one file using deterministic path conventions.
pub fn classify_path(path : String) -> InventoryKind {
  let value = normalize_path(path)
  let extension = file_extension(value)
  if is_generated_path(value) {
    Generated
  } else if value.has_suffix("_test.mbt") || value.has_suffix("_test.mbti") {
    Test
  } else if extension == "mbt" || extension == "mbti" {
    Source
  } else if value.has_prefix("fixtures/") || value.contains("/fixtures/") {
    Fixture
  } else if value.has_prefix(".github/workflows/") {
    Automation
  } else if extension == "md" ||
    extension == "mdx" ||
    value == "LICENSE" ||
    value.has_prefix("LICENSE.") {
    Documentation
  } else if extension == "json" ||
    extension == "toml" ||
    extension == "yaml" ||
    extension == "yml" ||
    extension == "mod" ||
    extension == "pkg" ||
    extension == "conf" ||
    extension == "cfg" {
    Configuration
  } else {
    Other
  }
}

///|
fn inventory_entry(file : ProjectFile) -> InventoryEntry {
  let path = normalize_path(file.path)
  {
    path,
    directory: dirname(path),
    basename: basename(path),
    extension: file_extension(path),
    kind: classify_path(path),
    bytes: file.size,
  }
}

///|
fn add_unique(values : Array[String], value : String) -> Unit {
  if !values.contains(value) {
    values.push(value)
  }
}

///|
/// Build a complete inventory without mutating the input snapshot.
pub fn inventory(project : ProjectSnapshot) -> ProjectInventory {
  let entries : Array[InventoryEntry] = []
  let directories : Array[String] = []
  let mut source_files = 0
  let mut test_files = 0
  let mut documentation_files = 0
  let mut configuration_files = 0
  let mut automation_files = 0
  let mut fixture_files = 0
  let mut generated_files = 0
  let mut other_files = 0
  let mut total_bytes : Int64 = 0L
  for file in project.files {
    let item = inventory_entry(file)
    entries.push(item)
    add_unique(directories, item.directory)
    total_bytes = total_bytes + item.bytes
    match item.kind {
      Source => source_files = source_files + 1
      Test => test_files = test_files + 1
      Documentation => documentation_files = documentation_files + 1
      Configuration => configuration_files = configuration_files + 1
      Automation => automation_files = automation_files + 1
      Fixture => fixture_files = fixture_files + 1
      Generated => generated_files = generated_files + 1
      Other => other_files = other_files + 1
    }
  }
  {
    entries,
    source_files,
    test_files,
    documentation_files,
    configuration_files,
    automation_files,
    fixture_files,
    generated_files,
    other_files,
    total_bytes,
    directories,
  }
}

///|
/// Count inventory files of one kind.
pub fn inventory_count(
  inventory : ProjectInventory,
  kind : InventoryKind,
) -> Int {
  match kind {
    Source => inventory.source_files
    Test => inventory.test_files
    Documentation => inventory.documentation_files
    Configuration => inventory.configuration_files
    Automation => inventory.automation_files
    Fixture => inventory.fixture_files
    Generated => inventory.generated_files
    Other => inventory.other_files
  }
}

///|
/// Count entries whose extension equals the supplied value.
pub fn count_extension(inventory : ProjectInventory, extension : String) -> Int {
  let target = extension.to_lower()
  inventory.entries.filter(fn(item) { item.extension == target }).length()
}

///|
/// Count entries below a directory prefix.
pub fn count_under(inventory : ProjectInventory, directory : String) -> Int {
  let prefix = normalize_path(directory)
  let needle = if prefix == "" { "" } else { prefix + "/" }
  inventory.entries
  .filter(fn(item) {
    if needle == "" {
      true
    } else {
      item.path.has_prefix(needle)
    }
  })
  .length()
}

///|
/// Return the largest inventory entry, or None for an empty project.
pub fn largest_entry(inventory : ProjectInventory) -> InventoryEntry? {
  let mut best : InventoryEntry? = None
  for item in inventory.entries {
    match best {
      None => best = Some(item)
      Some(current) => if item.bytes > current.bytes { best = Some(item) }
    }
  }
  best
}

///|
/// Estimate source density while avoiding division by zero.
pub fn test_to_source_percent(inventory : ProjectInventory) -> Int {
  let real_source = inventory.source_files + inventory.test_files
  if real_source == 0 {
    0
  } else {
    100 * inventory.test_files / real_source
  }
}

///|
fn inventory_kind_text(kind : InventoryKind) -> String {
  match kind {
    Source => "source"
    Test => "test"
    Documentation => "documentation"
    Configuration => "configuration"
    Automation => "automation"
    Fixture => "fixture"
    Generated => "generated"
    Other => "other"
  }
}

///|
/// Render a compact human-readable inventory.
pub fn format_inventory_text(inventory : ProjectInventory) -> String {
  let mut out = "Project Inventory\n"
  out = out + "Files: " + inventory.entries.length().to_string() + "\n"
  out = out +
    "Directories: " +
    inventory.directories.length().to_string() +
    "\n"
  out = out + "Source files: " + inventory.source_files.to_string() + "\n"
  out = out + "Test files: " + inventory.test_files.to_string() + "\n"
  out = out +
    "Documentation files: " +
    inventory.documentation_files.to_string() +
    "\n"
  out = out +
    "Configuration files: " +
    inventory.configuration_files.to_string() +
    "\n"
  out = out +
    "Automation files: " +
    inventory.automation_files.to_string() +
    "\n"
  out = out + "Generated files: " + inventory.generated_files.to_string() + "\n"
  out = out + "Total content bytes: " + inventory.total_bytes.to_string() + "\n"
  out = out +
    "Test/source ratio: " +
    test_to_source_percent(inventory).to_string() +
    "%\n"
  match largest_entry(inventory) {
    Some(item) =>
      out +
      "Largest file: " +
      item.path +
      " (" +
      item.bytes.to_string() +
      " bytes)\n"
    None => out + "Largest file: none\n"
  }
}

///|
/// Render an inventory as valid JSON.
pub fn format_inventory_json(inventory : ProjectInventory) -> String {
  let mut out = "{\n"
  out = out + "  \"files\": " + inventory.entries.length().to_string() + ",\n"
  out = out +
    "  \"directories\": " +
    inventory.directories.length().to_string() +
    ",\n"
  out = out +
    "  \"source_files\": " +
    inventory.source_files.to_string() +
    ",\n"
  out = out + "  \"test_files\": " + inventory.test_files.to_string() + ",\n"
  out = out +
    "  \"documentation_files\": " +
    inventory.documentation_files.to_string() +
    ",\n"
  out = out +
    "  \"configuration_files\": " +
    inventory.configuration_files.to_string() +
    ",\n"
  out = out +
    "  \"automation_files\": " +
    inventory.automation_files.to_string() +
    ",\n"
  out = out +
    "  \"generated_files\": " +
    inventory.generated_files.to_string() +
    ",\n"
  out = out + "  \"total_bytes\": " + inventory.total_bytes.to_string() + ",\n"
  out = out + "  \"entries\": ["
  for i = 0; i < inventory.entries.length(); i = i + 1 {
    let item = inventory.entries[i]
    if i > 0 {
      out = out + ","
    }
    out = out +
      "\n    {\"path\":" +
      json_string(item.path) +
      ",\"kind\":" +
      json_string(inventory_kind_text(item.kind)) +
      ",\"extension\":" +
      json_string(item.extension) +
      ",\"bytes\":" +
      item.bytes.to_string() +
      "}"
  }
  if inventory.entries.length() > 0 {
    out + "\n  ]\n}\n"
  } else {
    out + "]\n}\n"
  }
}
