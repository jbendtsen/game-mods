self.write_file_to_mem(0x80002d00, "NFSUC/fly.bin")
time.sleep(0.5)
self.set_bpx(0x80002d00)
time.sleep(0.1)
self.poke(0x8030fca8, 0x4bcf3058)