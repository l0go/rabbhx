package vm;

typedef Stack = {
	ptr: Int,
	kptr: Int,
	error: Int,
	data: Array<Int>
}

typedef Device = {
	stack: Stack,
	address: Int,
	data: Array<Int>,
	memory: Int,
	vector: Int,
	input: (d:Device, i:Int)->Int,
	output: (d:Device, i:Int)->Int
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
	static function push8(stack: Stack, value: Int): Void {
		if (stack.ptr == 0xff) {
			stack.error = 2;
			return;
		}
		stack.data[stack.ptr++] = value;
	}

	// Removes the last value 
	static function pop8k(stack: Stack): Int {
		if (stack.kptr == 0) {
			stack.error = 1;
			return 0;
		}
		return stack.data[stack.kptr--];
	}

	static function pop8d(stack: Stack): Int {
		if (stack.ptr == 0) {
			stack.error = 1;
			return 0;
		}
		return stack.data[stack.ptr--];
	}

	static function poke8(memory: Array<Int>, a: Int, b: Int): Void {
		memory[a] = b;
	}

	static function peek8(memory: Array<Int>, a: Int): Int {
		return memory[a];
	}

	static function devw8(device: Device, a: Int, b: Int): Void {
		device.data[a & 0xf] = b;
		device.output(device, a & 0x0f);
	}

	static function devr8(device: Device, a: Int): Int {
		return device.output(device, a & 0x0f);
	}

	static function warp8(uxn: Uxn, a: Int): Void {
		uxn.memory.ptr += a;
	}
	
	static function pull8(uxn: Uxn): Void {
		push8(uxn.src, peek8(uxn.memory.data, uxn.memory.ptr++));
	}

	// Short Mode
	static function push16(stack: Stack, a: Int): Void {
		push8(stack, a >> 8);
		push8(stack, a);
	}

	static function pop16(stack: Stack): Int {
		var a: Int = pop8(stack);
		var b: Int = pop8(stack);
		return a + (b << 8);
	}

	static function poke16(memory: Array<Int>, a: Int, b: Int): Void {
		poke8(memory, a, b >> 8);
		poke8(memory, a + 1, b);
	}

	static function peek16(memory: Array<Int>, a: Int): Int {
		return (peek8(memory, a) << 8) + peek8(memory, a + 1);
	}

	static function devw16(device: Device, a: Int, b: Int): Void {
		devw8(device, a, b >> 8);
		devw8(device, a + 1, b);
	}

	static function devr16(device: Device, a: Int): Int {
		return (devr8(device, a) << 8) + devr8(device, a + 1);
	}
	
	static function warp16(uxn: Uxn, a: Int): Void {
		uxn.memory.ptr = a;
	}

	static function pull16(uxn: Uxn): Void {
		push16(uxn.src, peek16(uxn.memory.data, uxn.memory.ptr++));
		uxn.memory.ptr++;
	}

	static public function eval(uxn: Uxn, vector: Int): Bool {
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
				// LIT
				case 0x00:
					pull(uxn);
					break;
				// INC
				case 0x01:
					a = pop(uxn.src);
					push(uxn.src, a + 1);
					break;
				// POP
				case 0x02:
					pop(uxn.src);
					break;
				// DUP
				case 0x03:
					a = pop(uxn.src);
					push(uxn.src, a);
					push(uxn.src, a);
					break;
				// NIP
				case 0x04:
					a = pop(uxn.src);
					pop(uxn.src);
					push(uxn.src, a);
					break;
				// SWP
				case 0x05:
					a = pop(uxn.src);
					b = pop(uxn.src);
					push(uxn.src, a);
					push(uxn.src, b);
					break;
				// OVR
				case 0x06:
					a = pop(uxn.src);
					b = pop(uxn.src);
					push(uxn.src, b);
					push(uxn.src, a);
					push(uxn.src, b);
					break;
				// ROT
				case 0x07:
					a = pop(uxn.src);
					b = pop(uxn.src);
					c = pop(uxn.src);
					push(uxn.src, b);
					push(uxn.src, a);
					push(uxn.src, c);
					break;
				// Logic Opcodes
				// EQU
				case 0x08:
					a = pop(uxn.src);
					b = pop(uxn.src);
					push8(uxn.src, b == a ? 1 : 0);
					break;
				// NEQ
				case 0x09:
					a = pop(uxn.src);
					b = pop(uxn.src);
					push8(uxn.src, b != a ? 1 : 0);
					break;
				// GTH
				case 0x0a:
					a = pop(uxn.src);
					b = pop(uxn.src);
					push8(uxn.src, b > a ? 1 : 0);
					break;
				// LTH
				case 0x0b:
					a = pop(uxn.src);
					b = pop(uxn.src);
					push8(uxn.src, b < a ? 1 : 0);
					break;
				// JMP
				case 0x0c:
					a = pop(uxn.src);
					warp(uxn, a);
					break;
				// JCN
				case 0x0d:
					a = pop(uxn.src);
					if (pop8(uxn.src) > 0) {
						warp(uxn, a);
					}
					break;
				// JSR
				case 0x0e:
					a = pop(uxn.src);
					push16(uxn.dst, uxn.memory.ptr);
					warp(uxn, a);
					break;
				// STH
				case 0x0f:
					a = pop(uxn.src);
					push(uxn.dst, a);
					break;
				// Memory Opcodes
				// LDZ
				case 0x10:
					a = pop8(uxn.src);
					push(uxn.src, peek(uxn.memory.data, a));
					break;
				// STZ
				case 0x11:
					a = pop8(uxn.src);
					b = pop(uxn.src);
					poke(uxn.memory.data, a, b);
					break;
				// LDR
				case 0x12:
					a = pop8(uxn.src);
					push(uxn.src, peek(uxn.memory.data, uxn.memory.ptr + a));
					break;
				// STR
				case 0x13:
					a = pop8(uxn.src);
					b = pop(uxn.src);
					poke(uxn.memory.data, uxn.memory.ptr + a, b);
				// LDA
				case 0x14:
					a = pop16(uxn.src);
					push(uxn.src, peek(uxn.memory.data, a));
					break;
				// STA
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
				// ADD
				case 0x18:
					a = pop(uxn.src);
					b = pop(uxn.src);
					push(uxn.src, Math.round(b + a));
					break;
				// SUB
				case 0x19:
					a = pop(uxn.src);
					b = pop(uxn.src);
					push(uxn.src, Math.round(b - a));
					break;
				// MUL
				case 0x1a:
					a = pop(uxn.src);
					b = pop(uxn.src);
					push(uxn.src, Math.round(b * a));
					break;
				// DIV
				case 0x1b:
					a = pop(uxn.src);
					b = pop(uxn.src);
					push(uxn.src, Math.round(b / a));
					break;
				// AND
				case 0x1c:
					a = pop(uxn.src);
					b = pop(uxn.src);
					push(uxn.src, b & a);
					break;
				// ORA
				case 0x1d:
					a = pop(uxn.src);
					b = pop(uxn.src);
					push(uxn.src, b | a);
					break;
				// EOR
				case 0x1e:
					a = pop(uxn.src);
					b = pop(uxn.src);
					push(uxn.src, b ^ a);
					break;
				// SFT
				case 0x1d:
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

	/*
	static function boot(uxn: Uxn): Bool {
		var i: Int = 0;
		for (ul in uxn.length) {
			i++;
			uxn[ul] = 0x00;
		}
		return true;
	}
	*/
	
	static function main() {
		trace("Hello World!");
	}
}
