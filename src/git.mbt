/// A small, deterministic model of the Git information a maintainer needs.
pub struct CommitInfo {
  hash : String
  subject : String
  author : String
  changed_files : Int
} derive(Show, Eq)

pub struct BranchInfo {
  name : String
  upstream : String?
  ahead : Int
  behind : Int
  clean : Bool
} derive(Show, Eq)

pub struct GitAudit {
  branch : BranchInfo
  commits : Array[CommitInfo]
  has_remote : Bool
  has_tags : Bool
} derive(Show, Eq)

pub enum CommitRisk {
  Healthy
  MissingSubject
  TooLarge
  Unattributed
} derive(Show, Eq)

pub struct CommitFinding {
  hash : String
  risk : CommitRisk
  message : String
} derive(Show, Eq)

pub fn commit(hash : String, subject : String, author : String, changed_files : Int) -> CommitInfo {
  { hash, subject, author, changed_files }
}

pub fn branch(
  name : String,
  upstream : String?,
  ahead : Int,
  behind : Int,
  clean : Bool
) -> BranchInfo {
  { name, upstream, ahead, behind, clean }
}

pub fn git_audit(
  branch : BranchInfo,
  commits : Array[CommitInfo],
  has_remote : Bool,
  has_tags : Bool
) -> GitAudit {
  { branch, commits, has_remote, has_tags }
}

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

fn risk_message(risk : CommitRisk) -> String {
  match risk {
    Healthy => "commit has a subject, author, and reviewable size"
    MissingSubject => "commit subject is empty"
    TooLarge => "commit changes too many files for a focused handoff"
    Unattributed => "commit author is missing"
  }
}

pub fn inspect_commits(audit : GitAudit) -> Array[CommitFinding] {
  let mut result : Array[CommitFinding] = []
  for item in audit.commits {
    let risk = commit_risk(item)
    if risk != Healthy {
      result = result + [{
        hash: item.hash,
        risk,
        message: risk_message(risk),
      }]
    }
  }
  result
}

pub fn commit_count(audit : GitAudit) -> Int {
  audit.commits.length()
}

pub fn risky_commit_count(audit : GitAudit) -> Int {
  inspect_commits(audit).length()
}

pub fn is_branch_ready(audit : GitAudit) -> Bool {
  audit.branch.clean && audit.branch.behind == 0 && audit.has_remote
}

pub fn branch_status(audit : GitAudit) -> String {
  if !audit.branch.clean {
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

pub fn git_score(audit : GitAudit) -> Int {
  let mut value = 100
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
  if value < 0 { 0 } else { value }
}

pub fn format_git_text(audit : GitAudit) -> String {
  let mut out = "Git Maintenance Audit\n"
  out = out + "Branch: " + audit.branch.name + "\n"
  out = out + "Status: " + branch_status(audit) + "\n"
  out = out + "Commits: " + commit_count(audit).to_string() + "\n"
  out = out + "Git score: " + git_score(audit).to_string() + "/100\n"
  let findings = inspect_commits(audit)
  if findings.length() == 0 {
    out + "No commit risks.\n"
  } else {
    for item in findings {
      out = out + "- " + item.hash + ": " + item.message + "\n"
    }
    out
  }
}

///| Test data used by the command demo and documentation examples.
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
