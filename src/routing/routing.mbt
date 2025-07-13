///|
pub trait FromRequest {
  from_request(@core.HttpRequest) -> Self
}

///|
pub trait ToResponse {
  to_response(Self) -> @core.HttpResponse
}

///|
pub trait HttpHandler {
  handle_request(Self, req : @core.HttpRequest) -> @core.HttpResponse
}

///|
pub type CanHandle (@core.HttpRequest) -> Bool

///|
pub struct Route {
  can_handle : CanHandle
  handler : (@core.HttpRequest) -> @core.HttpResponse
}

///|
pub trait CanRoute {
  can_handle(Self, @core.HttpRequest) -> Bool
}

///|
pub impl CanRoute for CanHandle with can_handle(self, req : @core.HttpRequest) -> Bool {
  self(req)
}

///|
fn[Req : FromRequest, Resp : ToResponse, C : CanRoute] to_route(
  predicate : C,
  handler : (Req) -> Resp
) -> Route {
  Route::{
    can_handle: fn(req) { predicate.can_handle(req) },
    handler: fn(req : @core.HttpRequest) -> @core.HttpResponse {
      let request = FromRequest::from_request(req)
      let response = handler(request)
      response.to_response()
    },
  }
}

///|
pub let default_handler : Route = Route::{
  can_handle: fn(_ : @core.HttpRequest) -> Bool { true },
  handler: fn(_ : @core.HttpRequest) -> @core.HttpResponse {
    @core.HttpResponse::new(404, "Not Found")
  },
}

///|
typealias @list.T as List

///|
pub struct HttpRouter {
  mut routes : List[Route]
}

///|
pub fn HttpRouter::new() -> HttpRouter {
  HttpRouter::{ routes: List::default() }
}

///|
fn HttpRouter::with_route(self : HttpRouter, route : Route) -> HttpRouter {
  let new_routes = self.routes.add(route)
  self.routes = new_routes
  self
}

///|
pub impl @core.HttpHandler for HttpRouter with handle_request(
  self,
  req : @core.HttpRequest
) -> @core.HttpResponse {
  let matching_routes = self.routes.filter(fn(route : Route) -> Bool {
    (route.can_handle)(req)
  })
  if matching_routes.is_empty() {
    (default_handler.handler)(req)
  } else {
    (default_handler.handler)(req)
  }
}
