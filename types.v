module karatsuba

pub enum Method {
	get
	post
	unsupported
}

pub fn get_method(s string) Method {
	match s {
		'GET' { return .get }
		'POST' { return .post }
		else { return .unsupported }
	}
}

interface ReturnType {}
