///|
pub enum TaskPriority {
  P0
  P1
  P2
} derive(Show, Eq)

///|
pub enum TaskKind {
  Understand
  Verify
  Document
  Publish
} derive(Show, Eq)

///|
pub fn priority_p0() -> TaskPriority {
  P0
}

///|
pub fn priority_p1() -> TaskPriority {
  P1
}

///|
pub fn priority_p2() -> TaskPriority {
  P2
}

///|
pub fn kind_understand() -> TaskKind {
  Understand
}

///|
pub fn kind_verify() -> TaskKind {
  Verify
}

///|
pub fn kind_document() -> TaskKind {
  Document
}

///|
pub fn kind_publish() -> TaskKind {
  Publish
}

///|
pub struct HandoffTask {
  id : String
  title : String
  detail : String
  priority : TaskPriority
  kind : TaskKind
  target : String
  done : Bool
} derive(Show, Eq)

///|
pub struct HandoffPlan {
  project_name : String
  owner : String
  tasks : Array[HandoffTask]
  notes : Array[String]
} derive(Show, Eq)

///|
pub fn task(
  id : String,
  title : String,
  detail : String,
  priority : TaskPriority,
  kind : TaskKind,
  target : String,
) -> HandoffTask {
  { id, title, detail, priority, kind, target, done: false, }
}

///|
pub fn plan(
  project_name : String,
  owner : String,
  tasks : Array[HandoffTask],
) -> HandoffPlan {
  { project_name, owner, tasks, notes: [], }
}

///|
pub fn add_note(plan : HandoffPlan, note : String) -> HandoffPlan {
  plan.notes.push(note)
  plan
}

///|
pub fn priority_text(priority : TaskPriority) -> String {
  match priority {
    P0 => "P0"
    P1 => "P1"
    P2 => "P2"
  }
}

///|
pub fn kind_text(kind : TaskKind) -> String {
  match kind {
    Understand => "understand"
    Verify => "verify"
    Document => "document"
    Publish => "publish"
  }
}

///|
pub fn pending_tasks(plan : HandoffPlan) -> Array[HandoffTask] {
  plan.tasks.filter(fn(item) { !item.done })
}

///|
pub fn task_count(plan : HandoffPlan) -> Int {
  plan.tasks.length()
}

///|
pub fn pending_count(plan : HandoffPlan) -> Int {
  pending_tasks(plan).length()
}

///|
pub fn p0_count(plan : HandoffPlan) -> Int {
  plan.tasks.filter(fn(item) { item.priority == P0 && !item.done }).length()
}

///|
pub fn complete_task(plan : HandoffPlan, id : String) -> HandoffPlan {
  let mut updated : Array[HandoffTask] = []
  for item in plan.tasks {
    if item.id == id {
      updated = updated + [{ ..item, done: true, }]
    } else {
      updated = updated + [item]
    }
  }
  { ..plan, tasks: updated, }
}

///|
pub fn handoff_score(plan : HandoffPlan) -> Int {
  if plan.tasks.length() == 0 {
    100
  } else {
    100 * (plan.tasks.length() - pending_count(plan)) / plan.tasks.length()
  }
}

///|
fn task_line(item : HandoffTask) -> String {
  let mark = if item.done { "x" } else { " " }
  "- [" +
  mark +
  "] " +
  priority_text(item.priority) +
  " " +
  item.id +
  " " +
  item.title +
  " (" +
  kind_text(item.kind) +
  ") -> " +
  item.target +
  "\n  " +
  item.detail +
  "\n"
}

///|
pub fn format_markdown(plan : HandoffPlan) -> String {
  let mut out = "# Maintainer Handoff Plan\n\n"
  out = out + "- Project: " + plan.project_name + "\n"
  out = out + "- Current owner: " + plan.owner + "\n"
  out = out + "- Progress: " + handoff_score(plan).to_string() + "%\n\n"
  out = out + "## Tasks\n\n"
  for item in plan.tasks {
    out = out + task_line(item)
  }
  if plan.notes.length() > 0 {
    out = out + "\n## Notes\n\n"
    for note in plan.notes {
      out = out + "- " + note + "\n"
    }
  }
  out
}

///|
pub fn format_plan_json(plan : HandoffPlan) -> String {
  let mut out = "{\n  \"project\": " +
    json_string(plan.project_name) +
    ",\n  \"owner\": " +
    json_string(plan.owner) +
    ",\n  \"progress\": " +
    handoff_score(plan).to_string() +
    ",\n  \"tasks\": ["
  for i = 0; i < plan.tasks.length(); i = i + 1 {
    let item = plan.tasks[i]
    if i > 0 {
      out = out + ","
    }
    out = out +
      "\n    {\"id\":" +
      json_string(item.id) +
      ",\"priority\":" +
      json_string(priority_text(item.priority)) +
      ",\"kind\":" +
      json_string(kind_text(item.kind)) +
      ",\"done\":" +
      item.done.to_string() +
      "}"
  }
  if plan.tasks.length() > 0 {
    out = out + "\n  ]\n}"
  } else {
    out = out + "]\n}"
  }
  out
}

///|
pub fn plan_from_report(report : HealthReport) -> HandoffPlan {
  let mut tasks : Array[HandoffTask] = []
  for item in report.findings {
    let priority = match item.severity {
      Error => P0
      Warning => P1
      Info => P2
    }
    let kind = if item.rule_id == "MBH010" {
      Publish
    } else if item.rule_id == "MBH004" || item.rule_id == "MBH011" {
      Verify
    } else {
      Document
    }
    tasks = tasks +
      [
        task(
          item.rule_id,
          item.message,
          "Resolve this finding before handing the repository to another maintainer.",
          priority,
          kind,
          item.path,
        ),
      ]
  }
  plan("MoonBit project", "project owner", tasks)
}
