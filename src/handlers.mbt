///|
struct DefaultHttpHandler {
  id : String
}

///|
struct RequestDescriptionResponse {
  request_method : String
  request_uri : String
  headers : String
} derive(Show, ToJson)

///|
typealias @core.HttpResponse

///|
impl @core.HttpHandler for DefaultHttpHandler with handle_request(
  _ : DefaultHttpHandler,
  req : @core.HttpRequest
) -> HttpResponse {
  let request_headers = req.headers
    .iter()
    .map(p => { return p.0 + ": " + p.1 })
    .join("\n")
  let response = RequestDescriptionResponse::{
    request_method: req.http_method.to_string(),
    request_uri: req.uri,
    headers: request_headers,
  }
  HttpResponse::new(200, response.to_json())
}
