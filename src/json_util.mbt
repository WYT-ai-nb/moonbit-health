///|
/// Escape a string for inclusion between JSON quotes.
pub fn json_escape_string(value : String) -> String {
  let mut out = ""
  for ch in value {
    if ch == '\\' {
      out = out + "\\\\"
    } else if ch == '"' {
      out = out + "\\\""
    } else if ch == '\n' {
      out = out + "\\n"
    } else if ch == '\r' {
      out = out + "\\r"
    } else if ch == '\t' {
      out = out + "\\t"
    } else {
      out = out + ch.to_string()
    }
  }
  out
}

///|
/// Encode a complete JSON string literal.
pub fn json_string(value : String) -> String {
  "\"" + json_escape_string(value) + "\""
}
