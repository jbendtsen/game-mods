/******************************
 *  Cave Story Object Editor  *
 ******************************
 * 
 * This program lets you edit any currently loaded object in the game Cave Story at any time.
 * It is essentially a specialised RAM editor for any object, 0 - 1023.
 * Enemies, NPCs, props, doors, chests, etc are all considered as objects, so anything of the sort
 * that is in RAM can be modified in several different ways.
 * 
 * An object has a list of attributes attached to it. These attributes are what this tool allows you to edit.
 * 
 * This program runs from a Windows command line only. It does not work under Wine.
*/ 

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <windows.h>

typedef unsigned char u8;
typedef unsigned short u16;
typedef unsigned int u32;
typedef unsigned long long int u64;

const int base = 0x4a6220;
const int size = 0xac;

const int n_vars = 44;
const int n_lines = 15;

typedef struct {
	char *name;
	int off;
	int sz;
} variable;

const variable vars[] = {
	{"State", 0, 4}, {"", 4, 2}, {"", 6, 2}, {"X Pos", 8, 4}, {"Y Pos", 12, 4},
	{"X Vel", 16, 4}, {"Y Vel", 20, 4}, {"Var 1", 24, 4}, {"Var 2", 28, 4},
	{"Var 3", 32, 4}, {"Var 4", 36, 4}, {"Sprite", 40, 4}, {"Use Sound", 44, 4},
	{"Use Func", 48, 4}, {"Tileset", 52, 4}, {"", 56, 4}, {"Hit Sound", 60, 4},
	{"Health", 64, 4}, {"", 68, 4}, {"Type?", 72, 4}, {"Face Dir", 76, 4},
	{"Obj Flags", 80, 4}, {"", 84, 4}, {"", 88, 4}, {"", 92, 4},
	{"", 96, 4}, {"", 100, 4}, {"", 104, 4}, {"", 108, 4},
	{"", 112, 4}, {"", 116, 4}, {"", 120, 4}, {"Hitbox 1", 124, 4},
	{"Hitbox 2", 128, 4}, {"Hitbox 3", 132, 4}, {"Hitbox 4", 136, 4}, {"Hitbox 5", 140, 4},
	{"Hitbox 6", 144, 4}, {"Hitbox 7", 148, 4}, {"Hitbox 8", 152, 4}, {"Timer", 156, 4},
	{"Hit Amount", 160, 4}, {"Damage", 164, 4}, {"", 168, 4}
};

int obj_idx = 0;
int cur = 0;
int hlm = 1;
int edit = 0;
int edit_cur = 0;
char edit_val[16] = {0};

u8 *buf = NULL;
HANDLE proc = NULL;
HANDLE console = NULL;
HANDLE input = NULL;
INPUT_RECORD ir[10];

void update(int obj) {
	if (!proc) return;
	if (!buf) buf = calloc(size, 1);
	u32 addr = base + (obj * size);
	unsigned long s = 0;
	int r = ReadProcessMemory(proc, (void*)addr, buf, size, &s);
	if (!r || (int)s != size) memset(buf, 0, size);
}

void printyx(int y, int x, char *str) {
	if (!console) {
		console = CreateConsoleScreenBuffer(GENERIC_READ | GENERIC_WRITE, 0, NULL, CONSOLE_TEXTMODE_BUFFER, NULL);
		SetConsoleActiveScreenBuffer(console);
	}
	COORD pos = {x, y};
	WriteConsoleOutputCharacter(console, str, strlen(str), pos, NULL);
}

void printvar(int y, int x, int sp, int n) {
	char *str = calloc(sp+1, 1);
	memset(str, ' ', sp);
	printyx(y, x, str);
	sprintf(str, "%d", n);
	printyx(y, x, str);
	free(str);
}

// 0 = black, 11 = cyan, 15 = white
void colour(int c, int y, int x, int len) {
	COORD pos = {x, y};
	FillConsoleOutputAttribute(console, c, len, pos, NULL);
}

int setcolours(int pos, int y, int x, int name_len) {
	int fg = 15, bg = 0;
	int hl = ((pos == cur && !hlm) || (pos < 0 && hlm));

	if (hl) {
		fg = 0;
		bg = edit > 0 ? 11 : 15;
	}

	colour(fg | (bg << 4), y, x, name_len + 12);

	if (hl && edit > 0) {
		bg = 10;
		colour(fg | (bg << 4), y, x + name_len + edit_cur, 1);
	}
}

int get(int idx) {
	if (!buf) return 0;
	int x = 0;
	memcpy(&x, buf + vars[idx].off, vars[idx].sz);
	return x;
}

int readnum(char *str) {
	return memcmp(str, "0x", 2) ? atoi(str) : strtol(str, NULL, 16);
}

void display(void) {
	update(obj_idx);

	printyx(1, 30, "Object: ");
	printvar(1, 38, 12, (hlm && edit) ? readnum(edit_val) : obj_idx);
	setcolours(-1, 1, 30, 8);

	int i, j;
	for (i = 0; i < n_lines; i++) {
		int p = 4;
		for (j = i; j < n_vars; j += n_lines, p += 24) {
			char *name = strlen(vars[j].name) ? vars[j].name : "??";
			printyx(i+2, p, name);

			int n = (!hlm && edit && j == cur) ? readnum(edit_val) : get(j);
			printvar(i+2, p+12, 12, n);
			setcolours(j, i+2, p, 12);
		}
	}
}

void write_var(int idx, char *str) {
	int value = readnum(str);

	if (idx >= 0) {
		u32 addr = base + (obj_idx * size) + vars[idx].off;
		WriteProcessMemory(proc, (void*)addr, &value, vars[idx].sz, NULL);
	}
	else {
		if (value < 0) value = 0;
		if (value >= 1024) value = 1023;
		obj_idx = value;
	}

	update(obj_idx);
}

void add_char(char c) {
	if (edit_cur < 0) edit_cur = 0;
	if (edit_cur > strlen(edit_val)) edit_cur = strlen(edit_val);
	if (edit_cur >= 12) return;

	int i;
	for (i = 11; i > edit_cur; i--) edit_val[i] = edit_val[i-1];

	edit_val[edit_cur++] = c;
}

int quit = 0;

void handle_event(INPUT_RECORD *event) {
	if (event->EventType != 1) return;

	KEY_EVENT_RECORD *ev = (KEY_EVENT_RECORD*)&event->Event;
	if (!ev->bKeyDown) return;

	int key = ev->wVirtualKeyCode;

	if (key == 'Q' &&
	   (ev->dwControlKeyState == LEFT_CTRL_PRESSED ||
	    ev->dwControlKeyState == RIGHT_CTRL_PRESSED)) {

		quit = 1;
		return;
	}

	char c = 0;
	if (key >= '0' && key <= '9') c = key;
	if (key >= 'A' && key <= 'Z') c = key | 0x20;
	if (key == 0xbd) c = '-';

	if (c) {
		if (!edit) {
			memset(edit_val, 0, 16);
			edit = 1;
		}
		add_char(c);
	}

	if (key == VK_RETURN) {
		if (edit == 0) {
			edit = 1;
			edit_cur = strlen(edit_val);
		}
		else edit = -1;
	}

	if (key == VK_ESCAPE && edit > 0) edit = 0;

	if (key == VK_BACK) {
		if (edit == 0) {
			edit = 1;
			edit_cur = strlen(edit_val);
		}

		int i;
		if (edit_cur > 0) {
			for (i = edit_cur-1; i < 11; i++) edit_val[i] = edit_val[i+1];
			edit_cur--;
		}
	}

	int old_cur = cur;
	int old_hlm = hlm;
	if (key == VK_UP) {
		if (cur % n_lines == 0) hlm = 1;
		else cur--;
		if (edit) edit = -1;
	}
	if (key == VK_DOWN) {
		if (hlm) hlm = 0;
		else cur++;
		if (edit) edit = -1;
	}
	if (key == VK_LEFT) {
		if (edit) {
			if (edit_cur <= 0) edit = -1;
			else edit_cur--;
		}
		else if (!hlm) cur -= n_lines;
	}
	if (key == VK_RIGHT) {
		if (edit) {
			if (edit_cur >= strlen(edit_val)) edit = -1;
			else edit_cur++;
		}
		else if (!hlm) cur += n_lines;
	}
	if (cur < 0) cur = 0;
	if (cur > n_vars-1) cur = n_vars-1;

	if (edit < 0) {
		write_var(old_hlm ? -1 : old_cur, edit_val);
		edit = 0;
	}

	if (edit == 0) sprintf(edit_val, "%d", hlm ? obj_idx : get(cur));
}

int main(int argc, char **argv) {
	if (argc < 2) {
		printf("Cave Story Object Editor\n\n"
			"Usage: %s <PID of Doukutsu.exe>\n", argv[0]);
		return 1;
	}
	int pid = 0;
	if (!memcmp(argv[1], "0x", 2)) pid = strtol(argv[1], NULL, 16);
	else pid = atoi(argv[1]);

	proc = OpenProcess(PROCESS_ALL_ACCESS, 0, pid);
	if (!proc) {
		printf("Could not open process %d\n", pid);
		return 2;
	}

	input = GetStdHandle(STD_INPUT_HANDLE);
	while (1) {
		unsigned long n_events;
		PeekConsoleInput(input, &ir[0], 10, &n_events);
		if (n_events > 0) FlushConsoleInputBuffer(input);

		int i;
		for (i = 0; i < n_events; i++) handle_event(&ir[i]);
		if (quit) break;

		display();
		Sleep(100);
	}
	
	if (console) CloseHandle(console);
	CloseHandle(proc);
	free(buf);
	return 0;
}
