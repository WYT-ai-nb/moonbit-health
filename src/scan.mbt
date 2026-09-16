///|
/// Result of a directory scan, including non-fatal traversal warnings.
pub struct ScanResult {
  project : ProjectSnapshot
  warnings : Array[String]
} derive(Show, Eq)

///|
/// Directory names that never contribute maintainer evidence.
fn ignored_directory(name : String) -> Bool {
  name == ".git" ||
  name == ".mooncakes" ||
  name == "_build" ||
  name == "target" ||
  name == "node_modules" ||
  name == "dist" ||
  name == "coverage"
}

///|
/// Return true when a file is small and textual enough to load into memory.
pub fn readable_text_file(path : String) -> Bool {
  let name = basename(path)
  let extension = file_extension(path)
  name == "LICENSE" ||
  name == "COPYING" ||
  name == "NOTICE" ||
  name == "Makefile" ||
  name == ".gitignore" ||
  name == ".editorconfig" ||
  extension == "mbt" ||
  extension == "mbti" ||
  extension == "md" ||
  extension == "mdx" ||
  extension == "json" ||
  extension == "toml" ||
  extension == "pkg" ||
  extension == "mod" ||
  extension == "yaml" ||
  extension == "yml" ||
  extension == "txt" ||
  extension == "conf" ||
  extension == "cfg" ||
  extension == "sh" ||
  extension == "ps1"
}

///|
fn append_path(parent : String, child : String) -> String {
  let base = normalize_path(parent)
  if child == "" {
    if base == "" {
      "."
    } else {
      base
    }
  } else if base == "" || base == "." {
    child
  } else if base.has_suffix("/") {
    base + child
  } else {
    base + "/" + child
  }
}

///|
fn read_text_or_empty(path : String, warnings : Array[String]) -> String {
  try @fs.read_file_to_string(path) catch {
    _ => {
      warnings.push("could not read text file: " + path)
      ""
    }
  } noraise {
    value => value
  }
}

///|
fn file_size_or_zero(path : String, warnings : Array[String]) -> Int64 {
  try @fs.read_file_to_bytes(path) catch {
    _ => {
      warnings.push("could not read file size: " + path)
      0L
    }
  } noraise {
    bytes => bytes.length().to_int64()
  }
}

///|
fn scan_directory(
  root : String,
  relative : String,
  depth : Int,
  files : Array[ProjectFile],
  warnings : Array[String],
) -> Unit raise {
  if depth > 64 {
    warnings.push("maximum scan depth exceeded: " + relative)
    return
  }
  let current = append_path(root, relative)
  let children = try @fs.read_dir(current) catch {
    _ => {
      warnings.push("could not read directory: " + current)
      return
    }
  } noraise {
    names => names.to_owned()
  }
  children.sort_by((left, right) => left.lexical_compare(right))
  for name in children {
    if ignored_directory(name) {
      continue
    }
    let child_relative = append_path(relative, name)
    let child_absolute = append_path(root, child_relative)
    let is_directory = try @fs.is_dir(child_absolute) catch {
      _ => {
        warnings.push("could not inspect path: " + child_absolute)
        false
      }
    } noraise {
      value => value
    }
    if is_directory {
      scan_directory(root, child_relative, depth + 1, files, warnings)
    } else {
      let size = file_size_or_zero(child_absolute, warnings)
      let content = if readable_text_file(child_relative) {
        read_text_or_empty(child_absolute, warnings)
      } else {
        ""
      }
      files.push(file_with_size(normalize_path(child_relative), content, size))
    }
  }
}

///|
/// Read a real directory tree into the deterministic snapshot model.
///
/// Generated and dependency directories are skipped, child names are sorted,
/// and non-fatal traversal failures are returned as warnings.
pub fn scan_project_result(root : String) -> ScanResult raise {
  let normalized_root = normalize_path(root)
  if !@fs.path_exists(normalized_root) {
    raise Failure("project root does not exist: " + normalized_root)
  }
  if !@fs.is_dir(normalized_root) {
    raise Failure("project root is not a directory: " + normalized_root)
  }
  let files : Array[ProjectFile] = []
  let warnings : Array[String] = []
  scan_directory(normalized_root, "", 0, files, warnings)
  { project: snapshot(files), warnings, }
}

///|
pub fn scan_project(root : String) -> ProjectSnapshot raise {
  let result = scan_project_result(root)
  result.project
}

///|
/// Load line-oriented policy configuration from a real file.
pub fn load_config(path : String) -> CompassConfig raise {
  parse_config(@fs.read_file_to_string(path))
}

///|
fn ensure_directory(path : String) -> Unit {
  if path == "" || path == "." || path == "/" {
    return
  }
  if @fs.path_exists(path) {
    return
  }
  ensure_directory(dirname(path))
  try @fs.create_dir(path) catch {
    _ => ()
  } noraise {
    _ => ()
  }
}

///|
/// Write a UTF-8 text file, creating missing parent directories.
pub fn write_text_file(path : String, content : String) -> Unit raise {
  ensure_directory(dirname(path))
  @fs.write_string_to_file(path, content)
}

///|
/// Generate a default output path for a requested format.
pub fn default_output_path(format : String) -> String {
  if format == "json" {
    "moonbit-health-report.json"
  } else if format == "markdown" || format == "md" {
    "moonbit-health-report.md"
  } else {
    "moonbit-health-report.txt"
  }
}
