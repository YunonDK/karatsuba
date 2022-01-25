module karatsuba

struct Parsed {
mut:
	version string
	path    string
	method  string

	unparsed []byte
	args     map[string]string
	body     []byte
}

/*
* `is_special` checks whether or not a byte is a special character
 *
 * Output: `true` | `false`
 * Arguments:
 *  `c`: byte
*/
[inline]
fn is_special(c byte) bool {
	return !c.is_space() && (c.is_alnum()
		|| c in [`!`, `"`, `#`, `$`, `%`, `&`, `'`, `(`, `)`, `*`, `+`, `,`, `-`, `.`, `/`, `:`, `;`, `<`, `=`, `>`, `?`, `@`, `[`, `\\`, `]`, `^`, `_`, `\``, `{`, `|`, `}`, `~`])
}

/*
* `parse_request` parses a buffer.
 *
 * Output: `Parsed`
 * Arguments:
 *  `req`: []byte
*/
fn parse_request(buffer []byte) ?&Parsed {
	mut p := Parsed{}
	mut pointer := 0

	if !is_special(buffer[pointer]) {
		return error('karatsuba: the request is invalid.')
	}

	mut start := pointer

	for pointer + 1 < buffer.len && buffer[pointer].is_capital() {
		pointer++
	}

	p.method = buffer[start..pointer].bytestr()

	if p.method !in ['GET', 'POST', 'PUT', 'DELETE', 'HEAD', 'OPTIONS', 'PATCH'] {
		return error('karatsuba: invalid method (method: $p.method)')
	}

	// skip space
	pointer++

	mut path := []byte{}

	if buffer[pointer] == `/` {
		// loop will end when the pointer points at `?` or a space.
		for pointer + 1 < buffer.len && buffer[pointer] != `?` {
			if buffer[pointer].is_space() {
				break
			}
			path << buffer[pointer]
			pointer++
		}

		if buffer[pointer] == `?` {
			pointer++
			mut left := []byte{}
			mut right := []byte{}

			mut shift := 'left'

			// loop ends at the nearest space
			for pointer + 1 < buffer.len && !buffer[pointer].is_space() {
				if buffer[pointer] == `&` {
					p.args[left.bytestr()] = right.bytestr()

					left.clear()
					right.clear()
					shift = 'left'
					pointer++
				}

				if buffer[pointer] == `=` {
					shift = 'right'
					pointer++
				}

				if shift == 'left' {
					left << buffer[pointer]
				} else {
					right << buffer[pointer]
				}

				pointer++
			}
			pointer++
			// add the remaining argument
			p.args[left.bytestr()] = right.bytestr()
		} else {
			pointer++
		}
		p.path = path.bytestr()
	} else {
		return error('karatsuba: the requested path does not begin with `/`')
	}

	if pointer + 4 < buffer.len && buffer[pointer..pointer + 4] == 'HTTP'.bytes() {
		start = pointer
		pointer += 4
		for pointer + 1 < buffer.len && !buffer[pointer].is_space() {
			pointer++
		}

		p.version = buffer[start..pointer].bytestr()
		pointer++
	} else {
		return error('karatsuba: the requesters HTTP version is invalid.')
	}

	if p.version !in ['HTTP/0.9', 'HTTP/1.0', 'HTTP/1.1', 'HTTP/2'] {
		return error("karatsuba: the requesters HTTP version doesn't exist (version: $p.version).")
	}

	pointer++
	start = pointer

	// read backwards to get the body
	mut pointer_bw := 0

	// the loop is a bit messy, but how it works
	// is it loops through the buffer backwards to
	// get the body, and it'll end when the 4 back bytes
	// are either `\r\n\r\n` or `--\r\n`
	for pointer_bw + 1 < buffer.len
		&& buffer[buffer.len - pointer_bw - 4..buffer.len - pointer_bw] in ['\r\n\r\n'.bytes(), '--\r\n'.bytes()] {
		pointer_bw++
	}

	p.body = buffer[buffer.len - pointer_bw..]
	p.unparsed = buffer[start..buffer.len - pointer_bw]

	return &p
}
