#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <event2/event.h>
#include <event2/http.h>
#include <event2/buffer.h>
#include <event2/keyvalq_struct.h>
#include <sys/queue.h>
#include "moonbit.h"

// C wrapper for the MoonBit callback
static void (*moonbit_callback)(void*, void*) = NULL;

moonbit_string_t c_str_to_moonbit_str(const void *ptr) {
  char *cptr = (char *)ptr;
  int32_t len = strlen(cptr);
  moonbit_string_t ms = moonbit_make_string(len, 0);
  for (int i = 0; i < len; i++) {
    ms[i] = (uint16_t)cptr[i];
  }
  // free(ptr);
  return ms;
}

// Generic callback wrapper that calls the MoonBit function
static void generic_handler(struct evhttp_request *req, void *arg) {
    if (moonbit_callback != NULL) {
        moonbit_callback(req, arg);
    }
}

// Set the generic callback function - called from MoonBit
void evhttp_set_gencb_wrapper(struct evhttp *http, void (*cb)(void*, void*), void *arg) {
    moonbit_callback = cb;
    evhttp_set_gencb(http, generic_handler, arg);
}


const char* http_reason_phrase(int code) {
    switch (code) {
        case 100: return "Continue";
        case 101: return "Switching Protocols";
        case 102: return "Processing";
        case 200: return "OK";
        case 201: return "Created";
        case 202: return "Accepted";
        case 204: return "No Content";
        case 301: return "Moved Permanently";
        case 302: return "Found";
        case 304: return "Not Modified";
        case 400: return "Bad Request";
        case 401: return "Unauthorized";
        case 403: return "Forbidden";
        case 404: return "Not Found";
        case 405: return "Method Not Allowed";
        case 409: return "Conflict";
        case 413: return "Payload Too Large";
        case 429: return "Too Many Requests";
        case 500: return "Internal Server Error";
        case 501: return "Not Implemented";
        case 502: return "Bad Gateway";
        case 503: return "Service Unavailable";
        default:  return "";  // Empty fallback for unknown codes
    }
}


// Wrapper for evhttp_send_reply that handles buffer creation
void evhttp_send_reply_wrapper(struct evhttp_request *req, int code, 
                              moonbit_bytes_t data) {
    struct evbuffer *evb = evbuffer_new();

    const char* reason = http_reason_phrase(code);
    
    // Add the response data to the buffer
    evbuffer_add(evb, data, strlen((char*)data));
    
    // Send the reply
    evhttp_send_reply(req, code, (const char*)reason, evb);
    
    // Clean up
    evbuffer_free(evb);
    
    // Decrease reference count for MoonBit managed data
    moonbit_decref(data);
}

moonbit_string_t evhttp_get_request_headers(struct evhttp_request *req) {
    struct evkeyvalq *headers = evhttp_request_get_input_headers(req);
    if (!headers) {
        // Return empty string instead of NULL
        return c_str_to_moonbit_str("");
    }

    struct evkeyval *header;
    char *result = malloc(1024); // Allocate a buffer for the headers
    result[0] = '\0'; // Initialize as empty string

    // Iterate through the headers and concatenate them
    TAILQ_FOREACH(header, headers, next) {
        strcat(result, header->key);
        strcat(result, ": ");
        strcat(result, header->value);
        strcat(result, "\r\n");
    }

    moonbit_string_t mb_result = c_str_to_moonbit_str(result);
    free(result);  // Free the allocated C string
    return mb_result;
}

// Helper function to create C strings from MoonBit bytes
char* make_c_string(moonbit_bytes_t bytes) {
    int len = strlen((char*)bytes);
    char* result = malloc(len + 1);
    strcpy(result, (char*)bytes);
    moonbit_decref(bytes);
    return result;
}

// Helper function to free C strings
void free_c_string(char* str) {
    free(str);
}

// Wrapper for getting URI that returns the original libevent URI pointer
// We'll use #borrow on the MoonBit side to avoid copying
moonbit_string_t evhttp_request_get_uri_wrapper(struct evhttp_request *req) {
    const char* uri = evhttp_request_get_uri(req);
    return c_str_to_moonbit_str(uri);
}

char* moonbit_str_to_c_str(moonbit_string_t mb_str) {
    if (mb_str == NULL) {
        return NULL;
    }

    // Get the length from MoonBit's header
    int32_t len = Moonbit_array_length(mb_str);

    // Allocate a new char* buffer (UTF-8) + 1 for null terminator
    char* cstr = (char*) malloc(len + 1);
    if (!cstr) return NULL;

    for (int i = 0; i < len; ++i) {
        uint16_t ch = mb_str[i];
        if (ch > 127) {
            // For now, only handle ASCII (1-byte)
            free(cstr);
            return NULL;  // or return "???" or error code
        }
        cstr[i] = (char)ch;
    }

    cstr[len] = '\0';
    return cstr;
}

void evhttp_add_header_wrapper(struct evkeyvalq *headers, 
                                moonbit_string_t key, 
                                moonbit_string_t value) {
    // Convert MoonBit strings to C strings
    char* c_key = moonbit_str_to_c_str(key);
    char* c_value = moonbit_str_to_c_str(value);

    if (c_key && c_value) {
        // Add the header using libevent's API
        evhttp_add_header(headers, c_key, c_value);
    } else {
        fprintf(stderr, "Failed to convert MoonBit strings to C strings\n");
    }

    // Free the C strings after use
    free(c_key);
    free(c_value);
}

// Wrapper for evhttp_bind_socket that properly handles MoonBit bytes
int evhttp_bind_socket_wrapper(struct evhttp *http, moonbit_string_t address, int port) {
    // Since we use #borrow, address is borrowed and we shouldn't decref it
    char* c_address = moonbit_str_to_c_str(address);
    
    // Call the actual evhttp_bind_socket function directly with the borrowed address
    int result = evhttp_bind_socket(http, c_address, port);
    free(c_address);  // Free the C string after use
    if (result != 0) {
        perror("evhttp_bind_socket failed");
    }
    
    return result;
}