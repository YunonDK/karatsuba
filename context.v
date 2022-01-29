module karatsuba

import net
import time

pub struct Context {
	unparsed []byte
mut:
	conn             net.TcpConn
	cached_headers   map[string]string
	resp_headers     map[string]string
	arguments        map[string]string
	cached_multipart map[string]string
pub:
	method     Method
	path       string
	parameters map[string]string
	version    string
pub mut:
	code int
}

// `get_header` finds the wanted header
// and afterwards caches it, for future use.
pub fn (mut ctx Context) get_header(name string) ?string {
	if name in ctx.cached_headers {
		return ctx.cached_headers[name]
	}

	mut pointer := 0
	mut start := 0
	buffer := ctx.unparsed
	for pointer + 4 < buffer.len && buffer[pointer..pointer + 4] != '\r\n\r\n'.bytes() {
		if pointer + 2 < buffer.len && buffer[pointer..pointer + 2] == '\r\n'.bytes() {
			pointer += 2
			start = pointer
		}

		if buffer[pointer] == `:` && buffer[start..pointer] == name.bytes() {
			pointer += 2
			start = pointer

			// find the end of the header value
			for pointer + 1 < buffer.len && buffer[pointer] != `\r` {
				pointer += 1
			}

			value := buffer[start..pointer].bytestr()
			ctx.cached_headers[name] = value

			return value
		}
		pointer++
	}

	return error('karatsuba: header not found.')
}

pub fn (mut ctx Context) get_multipart(name string) string {
	content_type := ctx.get_header('Content-Type') or { return 'none' }

	mut pointer := content_type.index_byte(`;`)
	typ := content_type[..pointer]
	if typ != 'multipart/form-data' {
		return 'none'
	}

	// pointer += content_type[pointer..].index_byte(`=`) + 1
	// boundary := content_type[pointer..]

	// pointer = ctx.unparsed.bytestr().index('\r\n\r\n') or { 0 } + 4
	// form_data := ctx.unparsed[pointer..]

	// for pointer + 1 <
	return 'text'
}

[inline]
pub fn (mut ctx Context) add_header(name string, value string) {
	ctx.resp_headers[name] = value
}

fn status_string(code int) string {
	msg := match code {
		100 { '100 Continue' }
		101 { '101 Switching Protocols' }
		200 { '200 OK' }
		201 { '201 Created' }
		202 { '202 Accepted' }
		301 { '301 Moved Permanently' }
		400 { '400 Bad Request' }
		401 { '401 Unauthorized' }
		403 { '403 Forbidden' }
		404 { '404 Not Found' }
		405 { '405 Method Not Allowed' }
		408 { '408 Request Timeout' }
		500 { '500 Internal Server Error' }
		501 { '501 Not Implemented' }
		502 { '502 Bad Gateway' }
		else { '-' }
	}
	return msg
}

pub fn (mut ctx Context) text(s string, code int) []byte {
	ctx.add_header('Content-Type', 'text/plain')
	ctx.code = code
	return s.bytes()
}

pub fn (mut ctx Context) json(s string, code int) []byte {
	ctx.add_header('Content-Type', 'application/json; charset=utf-8')
	ctx.code = code
	return s.bytes()
}

pub fn (mut ctx Context) send(content []byte) {
	mut buf := []byte{}

	buf << '$ctx.version ${status_string(200)}\r\n'.bytes()

	// add required headers
	ctx.add_header('Content-Length', content.len.str())
	ctx.add_header('X-Powered-By', 'Karatsuba/1.0')
	ctx.add_header('Date', time.now().str())
	ctx.add_header('Connection', 'keep-alive')

	for key, value in ctx.resp_headers {
		buf << '$key: $value\r\n'.bytes()
	}

	buf << '\r\n'.bytes()
	buf << content

	ctx.conn.write(buf) or {}
}
