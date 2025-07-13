pub(all) struct HttpRequest {
  uri: String
  http_method: HttpMethod
  headers: Map[String, String]
};

pub struct HttpResponse {
  code: Int
  body: Bytes
  headers: Map[String, String]
};

pub fn [R: ToResponseBody] HttpResponse::new(code: Int, body: R) -> HttpResponse {
  let { payload, content_type } = body.to_response_body();
  HttpResponse::{
    code,
    body: payload.to_bytes(),
    headers: Map::new(),
  }.with_header("Content-Type", content_type)
}

pub fn HttpResponse::with_header(self: HttpResponse, key: String, value: String) -> HttpResponse {
  self.headers.set(key, value);
  self;
}

pub fn HttpResponse::with_headers(self: HttpResponse, headers: Map[String, String]) -> HttpResponse {
  for key, value in headers {
    self.headers.set(key, value);
  }
  self;
}

pub(open) trait HttpHandler {
  handle_request(Self, req: HttpRequest) -> HttpResponse;
}

pub(all) enum HttpMethod {
  GET
  POST
  HEAD
  PUT
  DELETE
  OPTIONS
  TRACE
  CONNECT
  PATCH
} derive(Eq, Compare, Show)

pub(all) enum HttpResponseCode {
  Ok = 200
  Created = 201
  Accepted = 202
  NoContent = 204
  MovedPermanently = 301
  Found = 302
  SeeOther = 303
  NotModified = 304
  UseProxy = 305
  TemporaryRedirect = 307
  PermanentRedirect = 308
  BadRequest = 400
  Unauthorized = 401
  Forbidden = 403
  NotFound = 404
  MethodNotAllowed = 405
  InternalServerError = 500
  NotImplemented = 501
  BadGateway = 502
  ServiceUnavailable = 503
  GatewayTimeout = 504
}
