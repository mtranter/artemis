// MoonBit HTTP Server using libevent/evhttp
// This delegates most functionality to the C library for performance

// External types for libevent structures

///|
#external
priv type EventBase

///|
#external
priv type EvHttpPtr

///|
#external
priv type EvHttpRequest

// External types for C basic types

///|
#external
priv type CString

///|
#external
priv type EvKeyValQ

// FFI bindings for libevent functions

// Event base management

///|
extern "C" fn event_base_new() -> EventBase = "event_base_new"

///|
extern "C" fn event_base_dispatch(base : EventBase) -> Int = "event_base_dispatch"

///|
extern "C" fn event_base_free(base : EventBase) = "event_base_free"

// HTTP server functions

///|
extern "C" fn evhttp_new(base : EventBase) -> EvHttpPtr = "evhttp_new"

///|
extern "C" fn evhttp_free(http : EvHttpPtr) = "evhttp_free"

///|
extern "C" fn evhttp_request_get_output_headers(
  req : EvHttpRequest
) -> EvKeyValQ = "evhttp_request_get_output_headers"

///|
extern "C" fn evhttp_add_header(
  headers : EvKeyValQ,
  key : String,
  value : String
) = "evhttp_add_header_wrapper"

///|
#borrow(address)
extern "C" fn evhttp_bind_socket(
  http : EvHttpPtr,
  address : String,
  port : Int
) -> Int = "evhttp_bind_socket_wrapper"

// Request handling

///|
extern "C" fn evhttp_set_gencb(
  http : EvHttpPtr,
  cb : FuncRef[(EvHttpRequest, CString) -> Unit],
  arg : CString
) = "evhttp_set_gencb_wrapper"

// Request/Response functions

///|
extern "C" fn evhttp_request_get_uri(req : EvHttpRequest) -> String = "evhttp_request_get_uri_wrapper"

///|
extern "C" fn evhttp_request_get_command(req : EvHttpRequest) -> Int = "evhttp_request_get_command"

///|
extern "C" fn evhttp_get_request_headers(req : EvHttpRequest) -> String = "evhttp_get_request_headers"

///|
extern "C" fn evhttp_send_reply(
  req : EvHttpRequest,
  code : Int,
  databuf : Bytes
) = "evhttp_send_reply_wrapper"

// Helper to convert string to C string

///|
extern "C" fn make_c_string(s : Bytes) -> CString = "make_c_string"

// Simple request handler that returns a basic response

///|
fn http_method_from_evhttp(as_int : Int) -> @core.HttpMethod {
  match as_int {
    1 => @core.HttpMethod::GET
    2 => @core.HttpMethod::POST
    4 => @core.HttpMethod::HEAD
    8 => @core.HttpMethod::PUT
    16 => @core.HttpMethod::DELETE
    32 => @core.HttpMethod::OPTIONS
    64 => @core.HttpMethod::TRACE
    128 => @core.HttpMethod::CONNECT
    256 => @core.HttpMethod::PATCH
    _ => @core.HttpMethod::GET // Default to GET if unknown
  }
}

///|
fn default_handler(_ : @core.HttpRequest) -> @core.HttpResponse {
  @core.HttpResponse::new(500, "Internal Server Error")
}

///|
let global_handler : Ref[(@core.HttpRequest) -> @core.HttpResponse] = {
  val: default_handler,
}

// C callback wrapper - this is called from C

///|
fn handle_request_callback(req : EvHttpRequest, _arg : CString) -> Unit {
  let uri = evhttp_request_get_uri(req)
  let http_method_code = evhttp_request_get_command(req)
  let http_method = http_method_from_evhttp(http_method_code)
  let headers_str = evhttp_get_request_headers(req)
  let request = @core.HttpRequest::{
    uri,
    http_method,
    headers: deserialize_headers(headers_str),
  } // Headers can be populated if needed

  // Call the MoonBit handler
  let response = (global_handler.val)(request)

  response.headers.each(
    fn(key, value) {
      evhttp_add_header(evhttp_request_get_output_headers(req), key, value)
    }
  )
  // Send the response
  evhttp_send_reply(req, 200, response.body)
}

///|
fn deserialize_headers(headers_str : String) -> Map[String, String] {
  let headers = headers_str.split("\r\n")
  let map : Map[String, String] = Map::new()
  for header in headers {
    let parts = header.split(": ").to_array()
    if parts.length() == 2 {
      let key = parts[0].trim_space().to_string()
      let value = parts[1].trim_space().to_string()
      map.set(key, value)
    }
  }
  map
}

// WebServer struct

///|
struct WebServer {
  base : EventBase
  http : EvHttpPtr
  port : Int
  address : String
}

// Create a new web server

///|
pub fn new_webserver(address : String, port : Int) -> WebServer? {
  let base = event_base_new()
  let http = evhttp_new(base)
  let bind_result = evhttp_bind_socket(http, address, port)
  if bind_result == -1 {
    evhttp_free(http)
    event_base_free(base)
    None
  } else {
    Some({ base, http, port, address })
  }
}

// Set the request handler for the server

///|
pub fn[H : @core.HttpHandler] set_handler(
  server : WebServer,
  handler : H
) -> Unit {
  global_handler.val = fn(req) -> @core.HttpResponse {
    handler.handle_request(req)
  }
  let null_arg = make_c_string(b"")
  evhttp_set_gencb(
    server.http,
    fn(req, arg) -> Unit { handle_request_callback(req, arg) },
    null_arg,
  )
}

// Start the server and run the event loop

///|
pub fn start_server(server : WebServer) -> Int {
  println("Starting HTTP server on \{server.address}:\{server.port}")
  let result = event_base_dispatch(server.base)
  println("Server stopped")
  result
}

// Clean up server resources

///|
pub fn free_server(server : WebServer) -> Unit {
  println("Freeing server resources")
  evhttp_free(server.http)
  println("Freeing event base")
  event_base_free(server.base)
  println("Server resources freed")
}

// Main function to start a basic server on port 8080

///|
pub fn[H : @core.HttpHandler] start_basic_server(handler : H) -> Unit {
  match new_webserver("127.0.0.1", 8081) {
    Some(server) => {
      set_handler(server, handler)
      let _result = start_server(server)
      free_server(server)
    }
    None => println("Failed to create server")
  }
}
