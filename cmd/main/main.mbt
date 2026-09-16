///|
fn main {
  let code = @health.run_cli(@env.args())
  @sys.exit(code)
}
