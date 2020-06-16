#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define MODE_TEXT 0
#define MODE_BIN  1

typedef unsigned int u32;

inline u32 be32(u32 x, int le) {
	return !le ? x :
		((x & 0xff000000) >> 24) |
		((x & 0x00ff0000) >> 8) |
		((x & 0x0000ff00) << 8) |
		((x & 0x000000ff) << 24)
	;
}

int main(int argc, char **argv) {
	if (argc < 4) {
		printf(
			"Gecko ASM Code Creator\n"
			"Usage: %s <mode> <address> <input binary file> [output code file]\n"
			"Modes:\n"
			" -t\n"
			"   Outputs a text file\n"
			" -b\n"
			"   Outputs a binary file\n\n",
			argv[0]
		);
		return 0;
	}

	int mode = -1;
	switch (argv[1][1]) {
		case 't':
			mode = MODE_TEXT;
			break;
		case 'b':
			mode = MODE_BIN;
			break;
		default:
			printf("Invalid mode \"%s\"\n", argv[1]);
			return 1;
	}

	u32 addr = strtoul(argv[2], NULL, 16) & 0x01ffffff;

	FILE *f = fopen(argv[3], "rb");
	if (!f) {
		printf("Could not open \"%s\"\n", argv[3]);
		return 2;
	}

	fseek(f, 0, SEEK_END);
	int sz = ftell(f);
	rewind(f);

	int le = 1;
	le = ((char*)&le)[0] == 1;

	int asm_sz = ((sz + 3) & ~3);
	int code_len = ((32 + asm_sz) & ~7) / sizeof(int);
	int n_asm_lines = (code_len - 6) / 2;
	u32 *code = calloc(code_len, sizeof(int));

	code[0] = be32(0x00D0C0DE, le);
	code[1] = code[0];
	code[2] = be32(0xC2000000 | addr, le);
	code[3] = be32(n_asm_lines, le);

	code[code_len-4] = be32(0x60000000, le);
	code[code_len-2] = be32(0xF0000000, le);

	fread(&code[4], 1, sz, f);
	fclose(f);

	if (mode == MODE_TEXT) {
		char *text = calloc(code_len * 10, 1);
		char *p = text;
		for (int i = 0; i < code_len / 2; i++)
			p += sprintf(p, "%08X %08X\n", be32(code[i*2], le), be32(code[i*2+1], le));

		if (argc > 4) {
			f = fopen(argv[4], "w");
			fwrite(text, 1, p - text, f);
			fclose(f);
		}
		else
			fwrite(text, 1, p - text, stdout);

		free(text);
	}
	else if (mode == MODE_BIN) {
		if (argc > 4) {
			f = fopen(argv[4], "wb");
			fwrite(code, sizeof(int), code_len, f);
			fclose(f);
		}
		else
			fwrite(code, sizeof(int), code_len, stdout);
	}

	free(code);
	return 0;
}
