module karatsuba

struct Endpoint {
	path   string
	method Method
	func   fn (mut ctx Context) []byte
}
