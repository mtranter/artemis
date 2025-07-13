
///|
fn main {
  println("Starting Artemis HTTP Server...")
  let handler = DefaultHttpHandler::{ id: "default_handler" }
  @server.start_basic_server(handler)
}
