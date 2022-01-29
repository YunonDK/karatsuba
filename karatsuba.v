module karatsuba

import net
import time

pub struct Karatsuba {
mut:
	endpoints []Endpoint
pub mut:
	addr string
}

pub fn new_karatsuba(addr string) Karatsuba {
	return Karatsuba{
		addr: addr
	}
}

[inline]
pub fn (mut k Karatsuba) add_endpoint(method Method, addr string, func fn (mut ctx Context) []byte) {
	k.endpoints << Endpoint{
		path: addr
		func: func
		method: method
	}
}

[inline]
pub fn (k Karatsuba) get_endpoint(path string, method Method) ?Endpoint {
	for endpoint in k.endpoints {
		if endpoint.path == path {
			if endpoint.method != method {
				return error_with_code('Method not allowed', 408)
			}
			return endpoint
		}
	}

	return error_with_code('Not found.', 404)
}

pub fn (k &Karatsuba) run() {
	mut listener := net.listen_tcp(.ip, k.addr) or { panic(err) }

	defer {
		listener.close() or {}
	}

	println('Listening on $k.addr')

	for {
		mut conn := listener.accept() or {
			println('Unable to get connection')
			continue
		}

		// maybe make my own as this doesn't
		// read it properly 40% of the times.
		mut buf := []byte{len: 2048}
		end := conn.read(mut buf) or {
			println('Unable to read the requests body.')
			conn.close() or {}
			continue
		}

		mut sw := time.new_stopwatch()
		sw.start()

		parsed := parse_request(buf[..end]) or {
			conn.write(('HTTP/1.1 400 Bad Request\r\n' + 'content-type: text/html\r\n' +
				'content-length: ${err.msg.len + 9}\r\n\r\n' + '<h1>$err.msg</h1>').bytes()) or {}
			conn.close() or {}
			continue
		}

		handler := k.get_endpoint(parsed.path, get_method(parsed.method)) or {
			conn.write(('$parsed.version ${status_string(err.code)}\r\n' +
				'content-type: text/html\r\n' + 'content-length: ${err.msg.len + 9}\r\n\r\n' +
				'<h1>$err.msg</h1>').bytes()) or {}
			conn.close() or {}
			continue
		}

		mut ctx := &Context{
			conn: conn
			parameters: parsed.args
			unparsed: parsed.unparsed
			path: handler.path
			method: handler.method
			version: parsed.version
		}
		resp := handler.func(mut ctx)

		sw.stop()
		println('$ctx.path | $ctx.method.str().to_upper() [$sw.elapsed().microseconds()μs]')

		ctx.send(resp)
		conn.close() or {}
	}
}
