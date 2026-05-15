#include "types.h"

void FileInit(void);
void FileOpen(u16 cluster, u32 len);
int FileGetChar(void);
void DirOpen(u16 cluster);
char *DirRead(void);
