///|
test "healthy branch is ready" {
  let audit = git_audit(
    branch("main", Some("origin/main"), 0, 0, true),
    [],
    true,
    true,
  )
  inspect(is_branch_ready(audit), content="true")
  inspect(branch_status(audit), content="branch is synchronized")
  inspect(git_score(audit), content="100")
}

///|
test "ahead branch is ready to publish" {
  let audit = git_audit(
    branch("main", Some("origin/main"), 3, 0, true),
    [],
    true,
    true,
  )
  inspect(is_branch_ready(audit), content="true")
  inspect(branch_status(audit), content="local commits are ready to publish")
}

///|
test "dirty branch is blocked" {
  let audit = git_audit(
    branch("feature", Some("origin/feature"), 1, 0, false),
    [],
    true,
    true,
  )
  inspect(is_branch_ready(audit), content="false")
  inspect(branch_status(audit), content="working tree has uncommitted changes")
  inspect(git_score(audit), content="80")
}

///|
test "behind branch needs synchronization" {
  let audit = git_audit(
    branch("main", Some("origin/main"), 0, 2, true),
    [],
    true,
    true,
  )
  inspect(is_branch_ready(audit), content="false")
  inspect(branch_status(audit), content="branch is behind its upstream")
  inspect(git_score(audit), content="90")
}

///|
test "remote is required for publishing" {
  let audit = git_audit(branch("main", None, 0, 0, true), [], false, true)
  inspect(is_branch_ready(audit), content="false")
  inspect(branch_status(audit), content="repository has no remote")
  inspect(git_score(audit), content="80")
}

///|
test "missing tag lowers score but does not block" {
  let audit = git_audit(
    branch("main", Some("origin/main"), 0, 0, true),
    [],
    true,
    false,
  )
  inspect(is_branch_ready(audit), content="true")
  inspect(git_score(audit), content="95")
}

///|
test "empty subject is a commit risk" {
  let audit = git_audit(
    branch("main", Some("origin/main"), 0, 0, true),
    [commit("abc", "", "owner", 1)],
    true,
    true,
  )
  let findings = inspect_commits(audit)
  inspect(findings.length(), content="1")
  inspect(findings[0].risk, content="MissingSubject")
  inspect(findings[0].message, content="commit subject is empty")
}

///|
test "large commit is a risk" {
  let audit = git_audit(
    branch("main", Some("origin/main"), 0, 0, true),
    [commit("abc", "large change", "owner", 31)],
    true,
    true,
  )
  inspect(risky_commit_count(audit), content="1")
  inspect(inspect_commits(audit)[0].risk, content="TooLarge")
  inspect(git_score(audit), content="90")
}

///|
test "missing author is a risk" {
  let audit = git_audit(
    branch("main", Some("origin/main"), 0, 0, true),
    [commit("abc", "document plan", "", 2)],
    true,
    true,
  )
  inspect(inspect_commits(audit)[0].risk, content="Unattributed")
}

///|
test "multiple commit risks are counted" {
  let audit = git_audit(
    branch("main", Some("origin/main"), 0, 0, true),
    [
      commit("a", "", "owner", 1),
      commit("b", "wide refactor", "owner", 40),
      commit("c", "", "", 50),
      commit("d", "small fix", "owner", 1),
    ],
    true,
    true,
  )
  inspect(commit_count(audit), content="4")
  inspect(risky_commit_count(audit), content="3")
  inspect(git_score(audit), content="70")
}

///|
test "demo audit has publishable commits" {
  let audit = demo_git_audit()
  inspect(commit_count(audit), content="3")
  inspect(risky_commit_count(audit), content="0")
  inspect(
    format_git_text(audit).contains("local commits are ready to publish"),
    content="true",
  )
}

///|
test "git report includes score and branch" {
  let audit = git_audit(
    branch("release", Some("origin/release"), 0, 0, true),
    [],
    true,
    true,
  )
  let text = format_git_text(audit)
  inspect(text.contains("Branch: release"), content="true")
  inspect(text.contains("Git score: 100/100"), content="true")
}

///|
test "exactly thirty changed files is reviewable" {
  let item = commit("abc", "reviewable", "owner", 30)
  inspect(commit_risk(item), content="Healthy")
}

///|
test "thirty one changed files is too large" {
  let item = commit("abc", "reviewable", "owner", 31)
  inspect(commit_risk(item), content="TooLarge")
}

///|
test "ahead and behind status prefers behind" {
  let audit = git_audit(
    branch("main", Some("origin/main"), 2, 1, true),
    [],
    true,
    true,
  )
  inspect(branch_status(audit), content="branch is behind its upstream")
}

///|
test "dirty status has priority over synchronization" {
  let audit = git_audit(
    branch("main", Some("origin/main"), 0, 3, false),
    [],
    true,
    true,
  )
  inspect(branch_status(audit), content="working tree has uncommitted changes")
}

///|
test "real git metadata is read from a repository fixture" {
  let root = "_build/git_metadata_fixture"
  if @fs.path_exists(root) {
    remove_test_tree(root)
  }
  write_text_file(root + "/.git/HEAD", "ref: refs/heads/main")
  write_text_file(
    root + "/.git/config",
    (
      #|[remote "origin"]
      #|  url = https://example.com/demo.git
      #|[branch "main"]
      #|  remote = origin
      #|  merge = refs/heads/main
    ),
  )
  write_text_file(root + "/.git/refs/tags/v0.1.0", "deadbeef")
  let audit = collect_git_audit(root)
  inspect(audit.available, content="true")
  inspect(audit.branch.name, content="main")
  inspect(audit.branch.upstream, content="Some(origin/main)")
  inspect(audit.has_remote, content="true")
  inspect(audit.has_tags, content="true")
  inspect(audit.branch.clean_known, content="false")
  inspect(audit.history_known, content="false")
  remove_test_tree(root)
}

///|
test "missing git metadata is reported without fabricated status" {
  let audit = collect_git_audit("_build/no_git_repository")
  inspect(audit.available, content="false")
  inspect(
    branch_status(audit),
    content="git repository metadata is unavailable",
  )
}
