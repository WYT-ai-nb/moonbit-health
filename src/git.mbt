///|
/// A small, deterministic model of the Git information a maintainer needs.
pub struct CommitInfo {
  hash : String
  subject : String
  author : String
  changed_files : Int
} derive(Show, Eq)

///|
pub struct BranchInfo {
  name : String
  upstream : String?
  ahead : Int
  behind : Int
  clean : Bool
  clean_known : Bool
  sync_known : Bool
} derive(Show, Eq)

///|
pub struct GitAudit {
  available : Bool
  branch : BranchInfo
  commits : Array[CommitInfo]
  has_remote : Bool
  has_tags : Bool
  history_known : Bool
} derive(Show, Eq)

///|
pub enum CommitRisk {
  Healthy
  MissingSubject
  TooLarge
  Unattributed
} derive(Show, Eq)

///|
pub struct CommitFinding {
  hash : String
  risk : CommitRisk
  message : String
} derive(Show, Eq)

///|
pub fn commit(
  hash : String,
  subject : String,
  author : String,
  changed_files : Int,
) -> CommitInfo {
  { hash, subject, author, changed_files, }
}

///|
pub fn branch(
  name : String,
  upstream : String?,
  ahead : Int,
  behind : Int,
  clean : Bool,
) -> BranchInfo {
  { name, upstream, ahead, behind, clean, clean_known: true, sync_known: true, }
}

///|
pub fn git_audit(
  branch : BranchInfo,
  commits : Array[CommitInfo],
  has_remote : Bool,
  has_tags : Bool,
) -> GitAudit {
  {
    available: true,
    branch,
    commits,
    has_remote,
    has_tags,
    history_known: true,
  }
}

///|
fn metadata_git_audit(
  branch_name : String,
  upstream : String?,
  has_remote : Bool,
  has_tags : Bool,
) -> GitAudit {
  {
    available: true,
    branch: {
      name: branch_name,
      upstream,
      ahead: 0,
      behind: 0,
      clean: false,
      clean_known: false,
      sync_known: if upstream is Some(_) {
        false
      } else {
        true
      },
    },
    commits: [],
    has_remote,
    has_tags,
    history_known: false,
  }
}

///|
pub fn unavailable_git_audit() -> GitAudit {
  {
    available: false,
    branch: branch("unavailable", None, 0, 0, false),
    commits: [],
    has_remote: false,
    has_tags: false,
    history_known: false,
  }
}

///|
pub fn commit_risk(item : CommitInfo) -> CommitRisk {
  if item.subject.trim() == "" {
    MissingSubject
  } else if item.changed_files > 30 {
    TooLarge
  } else if item.author.trim() == "" {
    Unattributed
  } else {
    Healthy
  }
}

///|
fn risk_message(risk : CommitRisk) -> String {
  match risk {
    Healthy => "commit has a subject, author, and reviewable size"
    MissingSubject => "commit subject is empty"
    TooLarge => "commit changes too many files for a focused handoff"
    Unattributed => "commit author is missing"
  }
}

///|
pub fn inspect_commits(audit : GitAudit) -> Array[CommitFinding] {
  let mut result : Array[CommitFinding] = []
  for item in audit.commits {
    let risk = commit_risk(item)
    if risk != Healthy {
      result = result +
        [{ hash: item.hash, risk, message: risk_message(risk), }]
    }
  }
  result
}

///|
pub fn commit_count(audit : GitAudit) -> Int {
  audit.commits.length()
}

///|
pub fn risky_commit_count(audit : GitAudit) -> Int {
  inspect_commits(audit).length()
}

///|
pub fn is_branch_ready(audit : GitAudit) -> Bool {
  audit.available &&
  audit.branch.clean_known &&
  audit.branch.sync_known &&
  audit.branch.clean &&
  audit.branch.behind == 0 &&
  audit.has_remote
}

///|
pub fn branch_status(audit : GitAudit) -> String {
  if !audit.available {
    "git repository metadata is unavailable"
  } else if !audit.branch.clean_known {
    "working tree cleanliness is unavailable in metadata-only mode"
  } else if !audit.branch.sync_known {
    "branch synchronization is unavailable in metadata-only mode"
  } else if !audit.branch.clean {
    "working tree has uncommitted changes"
  } else if audit.branch.behind > 0 {
    "branch is behind its upstream"
  } else if !audit.has_remote {
    "repository has no remote"
  } else if audit.branch.ahead > 0 {
    "local commits are ready to publish"
  } else {
    "branch is synchronized"
  }
}

///|
pub fn git_score(audit : GitAudit) -> Int {
  if !audit.available {
    return 0
  }
  let mut value = 100
  if !audit.branch.clean_known {
    value = value - 10
  }
  if !audit.branch.sync_known {
    value = value - 10
  }
  if !audit.history_known {
    value = value - 10
  }
  if !audit.has_remote {
    value = value - 20
  }
  if !audit.has_tags {
    value = value - 5
  }
  if !audit.branch.clean {
    value = value - 20
  }
  if audit.branch.behind > 0 {
    value = value - 10
  }
  value = value - risky_commit_count(audit) * 10
  if value < 0 {
    0
  } else {
    value
  }
}

///|
fn read_optional_text(path : String) -> String? {
  if !@fs.path_exists(path) {
    return None
  }
  try @fs.read_file_to_string(path) catch {
    _ => None
  } noraise {
    value => Some(value)
  }
}

///|
fn git_directory(root : String) -> String? {
  let dot_git = append_path(root, ".git")
  if !@fs.path_exists(dot_git) {
    return None
  }
  let is_directory = try @fs.is_dir(dot_git) catch {
    _ => false
  } noraise {
    value => value
  }
  if is_directory {
    return Some(dot_git)
  }
  match read_optional_text(dot_git) {
    Some(text) => {
      let mut result : String? = None
      for raw_line in text.split("\n") {
        let line = raw_line.trim()
        if line.has_prefix("gitdir:") {
          let target = line[7:].trim().to_owned()
          result = Some(
            if target.has_prefix("/") ||
              (target.length() > 1 && target[1] == ':') {
              normalize_path(target)
            } else {
              append_path(root, target)
            },
          )
          break
        }
      }
      result
    }
    None => None
  }
}

///|
fn git_text(git_dir : String, relative : String) -> String? {
  read_optional_text(append_path(git_dir, relative))
}

///|
fn branch_from_head(head : String) -> String {
  let value = head.trim()
  if value.has_prefix("ref: refs/heads/") {
    value[16:].to_owned()
  } else if value.length() >= 7 {
    "detached@" + value[:7].to_owned()
  } else {
    "unknown"
  }
}

///|
fn upstream_from_config(config : String, branch_name : String) -> String? {
  let mut in_branch = false
  let mut remote = ""
  let mut merge = ""
  for raw_line in config.split("\n") {
    let line = raw_line.trim()
    if line.has_prefix("[branch \"") && line.has_suffix("\"]") {
      in_branch = line[9:line.length() - 2] == branch_name
    } else if line.has_prefix("[") {
      in_branch = false
    } else if in_branch && line.has_prefix("remote =") {
      remote = line[8:].trim().to_owned()
    } else if in_branch && line.has_prefix("merge =") {
      merge = line[7:].trim().to_owned()
    }
  }
  if remote == "" || merge == "" {
    None
  } else {
    let short_merge = if merge.has_prefix("refs/heads/") {
      merge[11:].to_owned()
    } else {
      merge
    }
    Some(remote + "/" + short_merge)
  }
}

///|
fn has_refs(git_dir : String, prefix : String) -> Bool {
  let refs_root = append_path(git_dir, prefix)
  let is_directory = try @fs.is_dir(refs_root) catch {
    _ => false
  } noraise {
    value => value
  }
  if @fs.path_exists(refs_root) && is_directory {
    let children = try @fs.read_dir(refs_root) catch {
      _ => []
    } noraise {
      value => value.to_owned()
    }
    if children.length() > 0 {
      return true
    }
  }
  match git_text(git_dir, "packed-refs") {
    Some(value) => value.contains(prefix + "/")
    None => false
  }
}

///|
/// Collect Git metadata directly from the repository without invoking Git.
///
/// Branch, upstream, remote, and tag information are read from `.git`.
/// Working-tree cleanliness, synchronization counts, and commit history require
/// a Git process adapter and are explicitly marked as unknown.
pub fn collect_git_audit(root : String) -> GitAudit {
  let git_dir = match git_directory(root) {
    Some(value) => value
    None => return unavailable_git_audit()
  }
  let head = match git_text(git_dir, "HEAD") {
    Some(value) => value
    None => return unavailable_git_audit()
  }
  let branch_name = branch_from_head(head)
  let config = match git_text(git_dir, "config") {
    Some(value) => value
    None => ""
  }
  let upstream = upstream_from_config(config, branch_name)
  metadata_git_audit(
    branch_name,
    upstream,
    config.contains("[remote \""),
    has_refs(git_dir, "refs/tags"),
  )
}

///|
pub fn format_git_text(audit : GitAudit) -> String {
  let mut out = "Git Maintenance Audit\n"
  out = out + "Branch: " + audit.branch.name + "\n"
  out = out + "Status: " + branch_status(audit) + "\n"
  let commits_text = if audit.history_known {
    commit_count(audit).to_string()
  } else {
    "unavailable"
  }
  out = out + "Commits: " + commits_text + "\n"
  out = out + "Git score: " + git_score(audit).to_string() + "/100\n"
  let findings = inspect_commits(audit)
  if !audit.history_known {
    out +
    "Commit history: metadata-only mode; install a Git process adapter for commit risks.\n"
  } else if findings.length() == 0 {
    out + "No commit risks.\n"
  } else {
    for item in findings {
      out = out + "- " + item.hash + ": " + item.message + "\n"
    }
    out
  }
}

///|
pub fn format_git_json(audit : GitAudit) -> String {
  let mut out = "{\n"
  out = out + "  \"available\": " + audit.available.to_string() + ",\n"
  out = out + "  \"branch\": " + json_string(audit.branch.name) + ",\n"
  out = out + "  \"upstream\": "
  match audit.branch.upstream {
    Some(value) => out = out + json_string(value)
    None => out = out + "null"
  }
  out = out + ",\n  \"ahead\": " + audit.branch.ahead.to_string() + ",\n"
  out = out + "  \"behind\": " + audit.branch.behind.to_string() + ",\n"
  out = out + "  \"clean\": " + audit.branch.clean.to_string() + ",\n"
  out = out +
    "  \"clean_known\": " +
    audit.branch.clean_known.to_string() +
    ",\n"
  out = out + "  \"sync_known\": " + audit.branch.sync_known.to_string() + ",\n"
  out = out + "  \"has_remote\": " + audit.has_remote.to_string() + ",\n"
  out = out + "  \"has_tags\": " + audit.has_tags.to_string() + ",\n"
  out = out + "  \"history_known\": " + audit.history_known.to_string() + ",\n"
  out = out + "  \"score\": " + git_score(audit).to_string() + ",\n"
  out = out + "  \"commits\": ["
  for i = 0; i < audit.commits.length(); i = i + 1 {
    let item = audit.commits[i]
    if i > 0 {
      out = out + ","
    }
    out = out +
      "\n    {\"hash\":" +
      json_string(item.hash) +
      ",\"subject\":" +
      json_string(item.subject) +
      ",\"author\":" +
      json_string(item.author) +
      ",\"changed_files\":" +
      item.changed_files.to_string() +
      "}"
  }
  if audit.commits.length() > 0 {
    out + "\n  ]\n}\n"
  } else {
    out + "]\n}\n"
  }
}

///|
/// Test data used by the command demo and documentation examples.
pub fn demo_git_audit() -> GitAudit {
  git_audit(
    branch("main", Some("origin/main"), 2, 0, true),
    [
      commit("a1b2c3d", "add handoff report", "WYT-ai-nb", 5),
      commit("d4e5f6g", "add deterministic rules", "WYT-ai-nb", 8),
      commit("h7i8j9k", "document verification", "WYT-ai-nb", 3),
    ],
    true,
    true,
  )
}
