#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>
#include <windows.h>

typedef unsigned char u8;
typedef unsigned int u32;

const int pl_x_addr = 0x49e654;
const int pl_y_addr = 0x49e658;

const int base = 0x4a6220;
const int max_objs = 0x200;
const int obj_size = 0xac;

int get_distance(int x1, int y1, int x2, int y2) {
	double x_delta = x1 > x2 ? x1 - x2 : x2 - x1;
	double y_delta = y1 > y2 ? y1 - y2 : y2 - y1;

	double a2b2 = (x_delta * x_delta) + (y_delta * y_delta);
	return (int)sqrt(a2b2);
}

int main(int argc, char **argv) {
	if (argc < 2) {
		printf("Cave Story Nearest Object Finder\n\n"
				"Usage: %s <PID of Doukutsu.exe>\n", argv[0]);
		return 1;
	}
	int pid = 0;
	if (!memcmp(argv[1], "0x", 2)) pid = strtol(argv[1], NULL, 16);
	else pid = atoi(argv[1]);

	HANDLE proc = OpenProcess(PROCESS_ALL_ACCESS, 0, pid);
	if (!proc) {
		printf("Could not open process %d\n", pid);
		return 2;
	}

	u8 *buf = calloc(max_objs * obj_size, 1);
	if (!ReadProcessMemory(proc, (void*)base, buf, max_objs * obj_size, NULL)) {
		printf("Could not read memory\n");
		free(buf);
		return 3;
	}

	int pl_x = 0, pl_y = 0;
	ReadProcessMemory(proc, (void*)pl_x_addr, &pl_x, 4, NULL);
	ReadProcessMemory(proc, (void*)pl_y_addr, &pl_y, 4, NULL);

	int i, nearest = 0, nearest_dist = -1;
	for (i = 0; i < max_objs; i++) {
		if (!(buf[i*obj_size] & 0x80)) continue;

		int x = 0, y = 0;
		memcpy(&x, buf + (i*obj_size + 8), 4);
		memcpy(&y, buf + (i*obj_size + 12), 4);

		int distance = get_distance(pl_x, pl_y, x, y);
		if (nearest_dist < 0 || distance < nearest_dist) {
			nearest = i;
			nearest_dist = distance;
		}
	}
	printf("%d\n", nearest);

	free(buf);
	CloseHandle(proc);
	return 0;
}