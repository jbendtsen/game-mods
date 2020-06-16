#include <stdio.h>
#include <stdlib.h>
#include <string.h>

typedef unsigned char u8;
typedef unsigned short u16;
typedef unsigned int u32;
typedef unsigned long long u64;

void search_8(u8 *buf, int size, u8 value) {
	for (int i = 0; i < size; i++) {
		if (buf[i] == value)
			printf("%#x\n", i);
	}
}

void search_16(u8 *buf, int size, int tick, u16 value) {
	for (int i = 0; i < size; i += tick) {
		if (*(u16*)(buf+i) == value)
			printf("%#x\n", i);
	}
}

void search_32(u8 *buf, int size, int tick, u32 value) {
	for (int i = 0; i < size; i += tick) {
		if (*(u32*)(buf+i) == value)
			printf("%#x\n", i);
	}
}

void search_64(u8 *buf, int size, int tick, u64 value) {
	for (int i = 0; i < size; i += tick) {
		if (*(u64*)(buf+i) == value)
			printf("%#x\n", i);
	}
}

int main(int argc, char **argv) {
	if (argc < 3) {
		printf(
			"Usage: %s [options] <binary file> <value>\n"
			"Options:\n"
			" -align\n"
			"   Only looks for <value> on N-byte boundaries,\n"
			"    where N = size of the search value\n"
			" -size <N>\n"
			"   Specifies the size of value in bytes. Can be 1, 2, 4 or 8.\n"
			"   Default = 2 if <value> & 0xffff == <value> else 4 if ... else 8\n"
			" -big\n"
			"   Specifies that the value is in big-endian,\n"
			"   as opposed to the default little-endian\n\n",
			argv[0]
		);
		return 1;
	}

	int arch_be = 1;
	arch_be = ((char*)&arch_be)[0] != 1;

	int align = 0;
	int size = -1;
	int big = 0;

	int cur = 1;
	for (cur = 1; cur < argc - 2; cur++) {
		if (argv[cur][0] != '-')
			break;

		if (!strcmp(argv[cur], "-align"))
			align = 1;
		else if (!strcmp(argv[cur], "-big"))
			big = 1;
		else if (!strcmp(argv[cur], "-size")) {
			if (cur >= argc - 3)
				break;

			size = atoi(argv[cur+1]);
		}
	}

	u64 value = strtoull(argv[cur+1], NULL, 0);

	if (size < 0) {
		if ((value & 0xffff) == value)
			size = 2;
		else if ((value & 0xffffffff) == value)
			size = 4;
		else
			size = 8;
	}

	switch (size) {
		case 1:
			break;
		case 2:
			if (big != arch_be)
				value = ((value & 0xff00) >> 8) | ((value & 0x00ff) << 8);
			break;
		case 4:
			if (big != arch_be)
				value =
					((value & 0xff000000) >> 24) |
					((value & 0x00ff0000) >>  8) |
					((value & 0x0000ff00) <<  8) |
					((value & 0x000000ff) << 24)
				;
			break;
		case 8:
			if (big != arch_be)
				value =
					((value & 0xff00000000000000) >> 56) |
					((value & 0x00ff000000000000) >> 40) |
					((value & 0x0000ff0000000000) >> 24) |
					((value & 0x000000ff00000000) >>  8) |
					((value & 0x00000000ff000000) <<  8) |
					((value & 0x0000000000ff0000) << 24) |
					((value & 0x000000000000ff00) << 40) |
					((value & 0x00000000000000ff) << 56)
				;
			break;
		default:
			printf("Invalid size %d\n", size);
			return 2;
	}

	FILE *f = fopen(argv[cur], "rb");
	if (!f) {
		printf("Could not open %s\n", argv[1]);
		return 3;
	}

	fseek(f, 0, SEEK_END);
	int sz = ftell(f);
	rewind(f);

	u8 *buf = malloc(sz);
	fread(buf, 1, sz, f);
	fclose(f);

	int tick = align ? size : 1;
	if (size == 1)
		search_8(buf, sz, (u8)value);
	else if (size == 2)
		search_16(buf, sz, tick, (u16)value);
	else if (size == 4)
		search_32(buf, sz, tick, (u32)value);
	else if (size == 8)
		search_64(buf, sz, tick, value);

	free(buf);
	return 0;
}
