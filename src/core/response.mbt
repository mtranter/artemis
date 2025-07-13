///|
pub enum ResponseBodyPayload {
  Bytes(Bytes)
}

///|
fn ResponseBodyPayload::to_bytes(self : ResponseBodyPayload) -> Bytes {
  match self {
    Bytes(bytes) => bytes
  }
}

///|
typealias String as ContentType

///|
pub struct ResponseBody {
  payload : ResponseBodyPayload
  content_type : ContentType
}

///|
pub fn ResponseBody::new(
  payload : Bytes,
  content_type : ContentType
) -> ResponseBody {
  ResponseBody::{ payload: Bytes(payload), content_type }
}

///|
trait ToResponseBody {
  to_response_body(Self) -> ResponseBody
}

///|
pub impl ToResponseBody for Bytes with to_response_body(self : Bytes) -> ResponseBody {
  {
    payload: ResponseBodyPayload::Bytes(self),
    content_type: "application/octet-stream".to_string(),
  }
}

///|
pub impl ToResponseBody for String with to_response_body(self : String) -> ResponseBody {

  let utf8String = @encoding.encode(@encoding.UTF8, self)
  {
    payload: ResponseBodyPayload::Bytes(utf8String),
    content_type: "text/plain; charset=UTF-8",
  }
}

///|
pub impl ToResponseBody for Json with to_response_body(self) -> ResponseBody {
  let utf8Json = @encoding.encode(@encoding.UTF8, self.stringify())
  {
    payload: ResponseBodyPayload::Bytes(utf8Json),
    content_type: "application/json; charset=UTF-8",
  }
}

///|





///|
pub(all) type Pair[T] (Int, T)

///|
pub fn[R : ToResponseBody] to_response(self : Pair[R]) -> HttpResponse {
  let (code, body) = (self.0, self.1)
  HttpResponse::new(code, body)
}

///|
pub fn[B : ToResponseBody] HttpResponse::ok(body : B) -> HttpResponse {
  HttpResponse::new(200, body)
}

///|
pub fn[B : ToResponseBody] HttpResponse::created(body : B) -> HttpResponse {
  HttpResponse::new(201, body)
}
