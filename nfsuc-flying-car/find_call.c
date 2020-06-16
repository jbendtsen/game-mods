#include <stdio.h>
#include <stdlib.h>
#include <string.h>

typedef unsigned int u32;
typedef unsigned char u8;

#define BRANCH_MASK 

int main(int argc, char **argv) {
	if (argc < 3) {
		printf("Invalid arguments\n"
			"Usage: %s <PPC code> <target address> [branch type = bl]\n", argv[0]);
		return 1;
	}

	char *type = argc > 3 ? argv[3] : "bl";
	u32 proto;

	if (!strcmp(type, "b"))
		proto = 0x48000000;
	else if (!strcmp(type, "bl"))
		proto = 0x48000001;
	else if (!strcmp(type, "ba"))
		proto = 0x48000002;
	else if (!strcmp(type, "bla"))
		proto = 0x48000003;
	else {
		printf("Unrecognised branch instruction \"%s\"\n", argv[3]);
		return 2;
	}

	FILE *f = fopen(argv[1], "rb");
	if (!f)
		return 2;

	fseek(f, 0, SEEK_END);
	int sz = ftell(f);
	rewind(f);

	u8 *buf = malloc(sz);
	fread(buf, 1, sz, f);
	fclose(f);

	u32 target = strtoul(argv[2], NULL, 16);
	target &= 0x1fffffc;

	u32 *p = (u32*)buf;
	for (int i = 0; i < sz; i += 4) {
		int delta = (proto & 2) ? target : target - i;
		u32 term = proto + ((u32)delta & 0x3fffffc);

		u32 ins = *p++;
		ins = (ins << 24) | ((ins & 0xff00) << 8) | ((ins & 0xff0000) >> 8) | (ins >> 24);
		if (ins == term)
			printf("%08X\n", 0x80000000 | (u32)i);
	}

	free(buf);
	return 0;
}
