package vm;

typedef Stack = {
	ptr: Int,
	kptr: Int,
	error: Int,
	data: Array<Int>
}

typedef Device = {
	uxn: Uxn,
	stack: Stack,
	address: Int,
	data: Array<Int>,
	memory: Array<Int>,
	vector: Int,
	input: (d:Device, i:Int)->Int,
	output: (d:Device, i:Int)->Void
}

typedef Memory = {
	ptr: Int,
	data: Array<Int>
}

typedef Uxn = {
	wst: Stack, // Working Stack
	rst: Stack, // Return Stack
	src: Stack,
	dst: Stack,
	memory: Memory,
	device: Array<Device>
}

class Vm {
	static inline var MODE_SHORT: Int = 0x20;
	static inline var MODE_RETURN: Int = 0x40;
	static inline var MODE_KEEP: Int = 0x80;
	
	static var push: (stack: Stack, a: Int)->Void;
	static var pop8: (stack: Stack)->Int;
	static var pop: (stack: Stack)->Int;
	static var poke: (memory: Array<Int>, a: Int, b: Int)->Void;
	static var peek: (memory: Array<Int>, a: Int)->Int;
	static var devw: (device: Device, a: Int, b: Int)->Void;
	static var devr: (device: Device, a: Int)->Int;
	static var warp: (uxn: Uxn, a: Int)->Void;
	static var pull: (uxn: Uxn)->Void;

	static var halt: (uxn: Uxn, error: Int, name: String, id: Int)->Bool;

	// Byte Mode
	public static function push8(stack: Stack, value: Int): Void {
		if (stack.ptr == 0xff) {
			stack.error = 2;
			return;
		}
		stack.data[stack.ptr++] = value;
	}

	public static function pop8k(stack: Stack): Int {
		if (stack.kptr == 0) {
			stack.error = 1;
			return 0;
		}
		return stack.data[stack.kptr--];
	}

	public static function pop8d(stack: Stack): Int {
		if (stack.ptr == 0) {
			stack.error = 1;
			return 0;
		}
		return stack.data[stack.ptr--];
	}

	public static function poke8(memory: Array<Int>, a: Int, b: Int): Void {
		memory[a] = b;
	}

	public static function peek8(memory: Array<Int>, a: Int): Int {
		return memory[a];
	}

	public static function devw8(device: Device, a: Int, b: Int): Void {
		device.data[a & 0xf] = b;
		device.output(device, a & 0x0f);
	}

	public static function devr8(device: Device, a: Int): Int {
		return device.input(device, a & 0x0f);
	}

	public static function warp8(uxn: Uxn, a: Int): Void {
		uxn.memory.ptr += a;
	}
	
	public static function pull8(uxn: Uxn): Void {
		push8(uxn.src, peek8(uxn.memory.data, uxn.memory.ptr++));
	}

	// Short Mode
	public static function push16(stack: Stack, a: Int): Void {
		push8(stack, a >> 8);
		push8(stack, a);
	}

	public static function pop16(stack: Stack): Int {
		var a: Int = pop8(stack);
		var b: Int = pop8(stack);
		return a + (b << 8);
	}

	public static function poke16(memory: Array<Int>, a: Int, b: Int): Void {
		poke8(memory, a, b >> 8);
		poke8(memory, a + 1, b);
	}

	public static function peek16(memory: Array<Int>, a: Int): Int {
		return (peek8(memory, a) << 8) + peek8(memory, a + 1);
	}

	public static function devw16(device: Device, a: Int, b: Int): Void {
		devw8(device, a, b >> 8);
		devw8(device, a + 1, b);
	}
	
	public static function devr16(device: Device, a: Int): Int {
		return (devr8(device, a) << 8) + devr8(device, a + 1);
	}
	
	public static function warp16(uxn: Uxn, a: Int): Void {
		uxn.memory.ptr = a;
	}

	public static function pull16(uxn: Uxn): Void {
		push16(uxn.src, peek16(uxn.memory.data, uxn.memory.ptr++));
		uxn.memory.ptr++;
	}

	public static function eval(uxn: Uxn, vector: Int): Bool {
		var instr: Int;
		var a: Int;
		var b: Int;
		var c: Int;

		if (uxn.device[0].data[0xf] != 0) {
			return false;
		}

		uxn.memory.ptr = vector;

		if (uxn.wst.ptr > 0xf8) {
			uxn.wst.ptr = 0xf8;
		}

		while (true) {
			instr = uxn.memory.data[uxn.memory.ptr++];
		
			// Return Mode
			if (instr != 0 && MODE_RETURN != 0) {
				uxn.src = uxn.rst;
				uxn.dst = uxn.wst;
			} else {
				uxn.src = uxn.wst;
				uxn.dst = uxn.rst;
			}
			
			// Keep Mode
			if (instr != 0 && MODE_KEEP != 0) {
				pop8 = pop8k;
				uxn.src.kptr = uxn.src.ptr;
			} else {
				pop8 = pop8d;
			}

			// Short Mode
			if (instr != 0 && MODE_SHORT != 0) {
				push = push16;
				pop = pop16;
				poke = poke16;
				peek = peek16;
				devw = devw16;
				devr = devr16;
				warp = warp16;
				pull = pull16;
			} else {
				push = push8;
				pop = pop8;
				poke = poke8;
				peek = peek8;
				devw = devw8;
				devr = devr8;
				warp = warp8;
				pull = pull8;
			}

			switch (instr & 0x1f) {
				// Stack Opcodes
				// LIT: Pushes the next value seen in the program onto the stack
				case 0x00:
					pull(uxn);
					break;
				// INC: Adds 1 to the value at the top of the stack
				case 0x01:
					a = pop(uxn.src);
					push(uxn.src, a + 1);
					break;
				// POP: Removes the value at the top of the stack
				case 0x02:
					pop(uxn.src);
					break;
				// DUP: Duplicates the value at the top of the stack
				case 0x03:
					a = pop(uxn.src);
					push(uxn.src, a);
					push(uxn.src, a);
					break;
				// NIP: Removes the second value from the stack
				case 0x04:
					a = pop(uxn.src);
					pop(uxn.src);
					push(uxn.src, a);
					break;
				// SWP: Exchanges the first and second values at the top of the stack
				case 0x05:
					a = pop(uxn.src);
					b = pop(uxn.src);
					push(uxn.src, a);
					push(uxn.src, b);
					break;
				// OVR: Duplicates the second value at the top of the stack
				case 0x06:
					a = pop(uxn.src);
					b = pop(uxn.src);
					push(uxn.src, b);
					push(uxn.src, a);
					push(uxn.src, b);
					break;
				// ROT: Rotates three values at the top of the stack, to the left, wrapping around
				case 0x07:
					a = pop(uxn.src);
					b = pop(uxn.src);
					c = pop(uxn.src);
					push(uxn.src, b);
					push(uxn.src, a);
					push(uxn.src, c);
					break;
				// Logic Opcodes
				// EQU: Pushes 01 to the stack if the two values at the top of the stack are equal, 00 otherwise
				case 0x08:
					a = pop(uxn.src);
					b = pop(uxn.src);
					push8(uxn.src, b == a ? 1 : 0);
					break;
				// NEQ: Pushes 01 to the stack if the two values at the top of the stack are not equal, 00 otherwise
				case 0x09:
					a = pop(uxn.src);
					b = pop(uxn.src);
					push8(uxn.src, b != a ? 1 : 0);
					break;
				// GTH: Pushes 01 to the stack if the second value at the top of the stack is greater than the value at the top of the stack, 00 otherwise
				case 0x0a:
					a = pop(uxn.src);
					b = pop(uxn.src);
					push8(uxn.src, b > a ? 1 : 0);
					break;
				// LTH: Pushes 01 to the stack if the second value at the top of the stack is lesser than the value at the top of the stack, 00 otherwise
				case 0x0b:
					a = pop(uxn.src);
					b = pop(uxn.src);
					push8(uxn.src, b < a ? 1 : 0);
					break;
				// JMP: Moves the program counter by a signed value equal to the byte on the top of the stack, or an absolute address in short mode
				case 0x0c:
					a = pop(uxn.src);
					warp(uxn, a);
					break;
				// JCN: If the byte preceeding the address is not 00, moves the program counter by a signed value equal to the byte on the top of the stack, or an absolute address in short mode
				case 0x0d:
					a = pop(uxn.src);
					if (pop8(uxn.src) > 0) {
						warp(uxn, a);
					}
					break;
				// JSR: Pushes the value of the program counter to the return-stack and moves the program counter by a signed value equal to the byte on the top of the stack, or an absolute address in short mode
				case 0x0e:
					a = pop(uxn.src);
					push16(uxn.dst, uxn.memory.ptr);
					warp(uxn, a);
					break;
				// STH: Moves the value at the top of the stack, to the return stack
				case 0x0f:
					a = pop(uxn.src);
					push(uxn.dst, a);
					break;
				// Memory Opcodes
				// LDZ: Pushes the value at an address within the first 256 bytes of memory, to the top of the stack
				case 0x10:
					a = pop8(uxn.src);
					push(uxn.src, peek(uxn.memory.data, a));
					break;
				// STZ: Writes a value to an address within the first 256 bytes of memory
				case 0x11:
					a = pop8(uxn.src);
					b = pop(uxn.src);
					poke(uxn.memory.data, a, b);
					break;
				// LDR: Pushes the value at a relative address, to the top of the stack. The possible relative range is -128 to +127 bytes
				case 0x12:
					a = pop8(uxn.src);
					push(uxn.src, peek(uxn.memory.data, uxn.memory.ptr + a));
					break;
				// STR: Writes a value to a relative address. The possible relative range is -128 to +127 bytes
				case 0x13:
					a = pop8(uxn.src);
					b = pop(uxn.src);
					poke(uxn.memory.data, uxn.memory.ptr + a, b);
				// LDA: Pushes the value at a absolute address, to the top of the stack
				case 0x14:
					a = pop16(uxn.src);
					push(uxn.src, peek(uxn.memory.data, a));
					break;
				// STA: Writes a value to a absolute address
				case 0x15:
					a = pop16(uxn.src);
					b = pop(uxn.src);
					poke(uxn.memory.data, a, b);
					break;
				// DEI
				case 0x16:
					a = pop8(uxn.src);
					push(uxn.src, devr(uxn.device[a >> 4], a));
					break;
				// DEO
				case 0x17:
					a = pop8(uxn.src);
					b = pop(uxn.src);
					devw(uxn.device[a >> 4], a, b);
					break;
				// Arithmetic Opcodes
				// ADD: Pushes the sum of the two values at the top of the stack
				case 0x18:
					a = pop(uxn.src);
					b = pop(uxn.src);
					push(uxn.src, Math.round(b + a));
					break;
				// SUB: Pushes the difference of the first value minus the second, to the top of the stack
				case 0x19:
					a = pop(uxn.src);
					b = pop(uxn.src);
					push(uxn.src, Math.round(b - a));
					break;
				// MUL: Pushes the product of the first and second values at the top of the stack
				case 0x1a:
					a = pop(uxn.src);
					b = pop(uxn.src);
					push(uxn.src, Math.round(b * a));
					break;
				// DIV: Pushes the quotient of the first value over the second, to the top of the stack
				case 0x1b:
					a = pop(uxn.src);
					b = pop(uxn.src);
					push(uxn.src, Math.round(b / a));
					break;
				// AND: Pushes the result of the bitwise operation AND, to the top of the stack
				case 0x1c:
					a = pop(uxn.src);
					b = pop(uxn.src);
					push(uxn.src, b & a);
					break;
				// ORA: Pushes the result of the bitwise operation OR, to the top of the stack
				case 0x1d:
					a = pop(uxn.src);
					b = pop(uxn.src);
					push(uxn.src, b | a);
					break;
				// EOR: Pushes the result of the bitwise operation XOR, to the top of the stack
				case 0x1e:
					a = pop(uxn.src);
					b = pop(uxn.src);
					push(uxn.src, b ^ a);
					break;
				// SFT (0x1d): Moves the bits of the value at the top of the stack to the left or right, depending on the control value of the second. The high nibble of the control value determines how many bits left to shift, and the low nibble how many bits right to shift. The rightward shift is done first
				default:
					a = pop(uxn.src);
					b = pop(uxn.src);
					push(uxn.src, b >> (a & 0x0f) << ((a & 0xf0) >> 4));
					break;
			}
			if (uxn.wst.error > 0) {
				return halt(uxn, uxn.wst.error, "Working-stack", instr);
			}
			if (uxn.rst.error > 0) {
				return halt(uxn, uxn.rst.error, "Return-stack", instr);
			}
		}
		return true;
	}

	public static function init(): Uxn {
		var stack: Stack = {
			ptr: 0,
			kptr: 0,
			error: 0,
			data: []
		};

		var uxn: Uxn = {
			wst: stack,
			rst: stack,
			src: stack,
			dst: stack,
			memory: {
				ptr: 0,
				data: []
			},
			device: []
		};

		return uxn;
	}

	public static function port(uxn: Uxn, id: Int, deifn: (device: Device, port: Int)->Int, deofn: (device: Device, port: Int)->Void): Device {
		var device: Device = uxn.device[id];
		device.address = id * 0x10;
		device.memory = uxn.memory.data;
		device.input = deifn;
		device.output = deofn;
		return device;
	}
}
