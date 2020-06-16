# For use with the USB Gecko (by Nuke)
# Based on the Gecko OS code handler (by Y.S.)

def poke_of_type(self, type, addr, value) :
	data = bytearray([3])
	data[1:5] = struct.pack(">I", addr)
	data[5:9] = struct.pack(type, value)
	self.write(data)

def poke(self, addr, value) :
	self.poke_of_type(">I", addr, value)
def poke_f(self, addr, value) :
	self.poke_of_type(">f", addr, value)

def poke_list_of_type(self, type, addrs, val_list=None) :
	if not isinstance(addrs, list):
		return

	n_addrs = len(addrs)
	if n_addrs < 1:
		return

	if isinstance(val_list, list) :
		n_vals = len(val_list)
	else:
		n_vals = 0
		val_list = []

	n_vals = n_addrs if n_vals > n_addrs else n_vals

	values = [0] * n_addrs
	values[0:n_vals] = val_list[0:n_vals]

	data = bytearray([])
	idx = 0
	for a in addrs:
		data.append(3)
		data.extend(struct.pack(">I", a))
		data.extend(struct.pack(type, values[idx]))
		idx += 1

	self.write(data)

def poke_list(self, addrs, values=None) :
	self.poke_list_of_type(">I", addrs, values)
def poke_list_f(self, addrs, values=None) :
	self.poke_list_of_type(">f", addrs, values)

def poke_array_of_type(self, type, base, values) :
	if not isinstance(values, list) :
		return

	data = bytearray([])
	addr = base
	for v in values:
		data.append(3)
		data.extend(struct.pack(">I", addr))
		data.extend(struct.pack(type, v))
		addr += 4

	self.write(data)

def poke_array(self, addr, values) :
	self.poke_array_of_type(">I", addr, values)
def poke_array_f(self, addr, values) :
	self.poke_array_of_type(">f", addr, values)

def read_mem(self, base, size) :
	self.write_bytes(4)
	ack = self.read(1, 1)
	params = bytearray([])
	params[0:4] = struct.pack(">I", base)
	params[4:8] = struct.pack(">I", base+size)
	self.write(params)

	data = bytearray(size)
	chk_sz = 0xf80
	left = size
	off = 0
	while left > 0:
		rsz = left if left < chk_sz else chk_sz
		chunk = self.read(rsz, 3)
		if chunk is None:
			return data

		data[off:off+rsz] = chunk

		self.tab.clear_data() # optional
		#print("{0:8x}".format(base+off))

		self.write_bytes(0xaa)
		off += rsz
		left -= rsz

	return data

def set_bp(self, addr, type) :
	data = bytearray([9])
	bp = (addr & ~7) | type
	data[1:5] = struct.pack(">I", bp)
	self.write(data)

def set_bpr(self, addr) :
	self.set_bp(addr, 5)
def set_bpw(self, addr) :
	self.set_bp(addr, 6)
def set_bpa(self, addr) :
	self.set_bp(addr, 7)

def set_bpx(self, addr) :
	data = bytearray([0x10])
	bp = (addr & ~3) | 3
	data[1:5] = struct.pack(">I", bp)
	self.write(data)

def get_registers_raw(self) :
	self.write_bytes(0x30)
	return self.read(0x120, 2)

def get_registers(self) :
	data = self.get_registers_raw()
	return Macro.PPC_Regs(*Macro._reg_fmt.unpack(data))._asdict()

def set_registers_raw(self, data) :
	if not (isinstance(data, bytes) or isinstance(data, bytearray)) :
		return
	if len(data) < 0xa0:
		return

	self.write_bytes(0x2f)
	ack = self.read(1, 1)
	if ack == None:
		return

	self.write(data[0:0xa0])

def set_registers(self, regs) :
	data = Macro._reg_fmt.pack(*regs.values())
	self.set_registers_raw(data)

def write_mem(self, base, data) :
	if not (isinstance(data, bytes) or isinstance(data, bytearray)) :
		return

	size = len(data)
	if size < 1:
		return

	self.write_bytes(0x41)
	self.read(1, 1)

	buf = bytearray(struct.pack(">II", base, size))
	left = size
	off = 0
	first = True

	while left > 0:
		txsz = min(left, 0xf80)
		if first:
			buf.extend(data[off:off+txsz])
			first = False
		else:
			buf = data[off:off+txsz]

		self.write(buf)
		off += txsz
		left -= txsz

		if left > 0:
			ack = self.read(1, 5)
			if ack is None or ack[0] != 0xaa:
				break

def write_file_to_mem(self, base, fname) :
	f = open(fname, "rb")
	data = f.read()
	f.close()
	self.write_mem(base, data)

Macro.poke_of_type = poke_of_type
Macro.poke = poke
Macro.poke_f = poke_f

Macro.poke_list_of_type = poke_list_of_type
Macro.poke_list = poke_list
Macro.poke_list_f = poke_list_f

Macro.poke_array_of_type = poke_array_of_type
Macro.poke_array = poke_array
Macro.poke_array_f = poke_array_f

Macro.read_mem = read_mem

Macro.set_bp = set_bp
Macro.set_bpx = set_bpx
Macro.set_bpr = set_bpr
Macro.set_bpw = set_bpw
Macro.set_bpa = set_bpa

Macro.get_registers = get_registers
Macro.set_registers = set_registers

Macro.get_registers_raw = get_registers_raw
Macro.set_registers_raw = set_registers_raw

Macro.write_mem = write_mem
Macro.write_file_to_mem = write_file_to_mem

Macro._reg_names = (
	"cr xer ctr dsis dar srr0 srr1 "
	"r0 r1 r2 r3 r4 r5 r6 r7 "
	"r8 r9 r10 r11 r12 r13 r14 r15 "
	"r16 r17 r18 r19 r20 r21 r22 r23 "
	"r24 r25 r26 r27 r28 r29 r30 r31 "
	"lr "
	"f0 f1 f2 f3 f4 f5 f6 f7 "
	"f8 f9 f10 f11 f12 f13 f14 f15 "
	"f16 f17 f18 f19 f20 f21 f22 f23 "
	"f24 f25 f26 f27 f28 f29 f30 f31"
)

Macro._reg_fmt = struct.Struct(">" + ("I" * 40) + ("f" * 32))

import collections
Macro.PPC_Regs = collections.namedtuple("PPC_Regs", Macro._reg_names)
