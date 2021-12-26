package cli;

import vm.Vm;

class Cli {
	static var devSystem: Device;
	static var devConsole: Device;

	static function error(message: String, error: String): Bool {
		Sys.stderr().writeString('Error $message: $error\n');
		return false;
	}

	static function inspect(stack: Stack, name: String): Void {
		var x: Int = 0;
		var y: Int = 0;
		Sys.stderr().writeString('\n$name\n');
		
		while (y < 0x04) {
			while (x < 0x08) {
				var p = y * 0x08 + x;
				Sys.stderr().writeString('${stack.data[p]}');
				x++;
			}
			Sys.stderr().writeString("\n");
			y++;
		}
	}

	static function nullDeviceInput(device: Device, port: Int): Int {
		return device.data[port];
	}

	static function nullDeviceOutput(device: Device, port: Int): Void {
		if (port == 0x1) {
			device.vector = Vm.peek16(device.data, 0x0);
		}
	}

	static function systemDeviceInput(device: Device, port: Int): Int {
		switch (port) {
			case 0x2:
				return device.uxn.wst.ptr;
			case 0x3:
				return device.uxn.rst.ptr;
			default:
				return device.data[port];
		}
	}

	static function systemDeviceOutput(device: Device, port: Int): Void {
		switch (port) {
			case 0x2:
				device.uxn.wst.ptr = device.data[port];
			case 0x3:
				device.uxn.rst.ptr = device.data[port];
			case 0xe:
				inspect(device.uxn.wst, "Working-stack");
				inspect(device.uxn.rst, "Return-stack");
		}
	}

	static function consoleDeviceOutput(device: Device, port: Int): Void {
		switch (port) {
			case 0x1:
				device.vector = Vm.peek16(device.data, 0x0);
			case 0x7:
				Sys.stdout().writeString(Std.string(device.data[0x7]));
			case 0x8:
				Sys.stderr().writeString(Std.string(device.data[0x8]));
		}
	}

	static function main() {
		var uxn: Uxn = Vm.init();
		var i: Int = 0;
		var loaded: Int = 0;
	
		// System
		var devSystem = Vm.port(uxn, 0x0, systemDeviceInput, systemDeviceOutput);
		// Console
		var devconsole = Vm.port(uxn, 0x1, nullDeviceInput, consoleDeviceOutput);
		// Empty 
		Vm.port(uxn, 0x2, nullDeviceInput, nullDeviceOutput);
		Vm.port(uxn, 0x3, nullDeviceInput, nullDeviceOutput);
		Vm.port(uxn, 0x4, nullDeviceInput, nullDeviceOutput);
		Vm.port(uxn, 0x5, nullDeviceInput, nullDeviceOutput);
		Vm.port(uxn, 0x6, nullDeviceInput, nullDeviceOutput);
		Vm.port(uxn, 0x7, nullDeviceInput, nullDeviceOutput);
		Vm.port(uxn, 0x8, nullDeviceInput, nullDeviceOutput);
		Vm.port(uxn, 0x9, nullDeviceInput, nullDeviceOutput);
		// File
		Vm.port(uxn, 0xa, nullDeviceInput, nullDeviceOutput);
		// Date Time
		Vm.port(uxn, 0xb, nullDeviceInput, nullDeviceOutput);
		// Empty
		Vm.port(uxn, 0xc, nullDeviceInput, nullDeviceOutput);
		Vm.port(uxn, 0xd, nullDeviceInput, nullDeviceOutput);
		Vm.port(uxn, 0xe, nullDeviceInput, nullDeviceOutput);
		Vm.port(uxn, 0xf, nullDeviceInput, nullDeviceOutput);
	}
}
