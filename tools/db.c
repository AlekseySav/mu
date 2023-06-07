/*
 * kernel debug
 */

#include <unistd.h>
#include <fcntl.h>
#include <stdio.h>
#include <stdint.h>
#include <assert.h>
#include <stdlib.h>
#include <ctype.h>
#include <string.h>

typedef uint8_t u8;
typedef uint16_t u16;
typedef uint32_t u32;

struct symbol
{
    const char* name;
    u16 value;
} symtab[1000];
size_t n_syms;

char symbuf[10000];

struct regs
{
	u16	ax;
	u16	cx;
	u16	dx;
	u16	bx;
	u16	sp;
	u16	bp;
	u16	si;
	u16	di;
	u16	ds;
	u16	es;
	u16	fs;
	u16	gs;
    u16 ss;
	u16 ip;
	u16 cs;
    u16 flags;
} regs;

const char* names[] = {
    "ax", "cx", "dx", "bx",
    "sp", "bp", "si", "di",
    "ds", "es", "fs", "gs", "ss",
    "ip", "cs", "flags",
    NULL
};

u8 mem[1 * 1024 * 1024];

int fd;

char buf[512];

u16 at(size_t seg, size_t off)
{
    return *(u16*)(mem + seg * 16 + off);
}

struct symbol* near(u16 v)
{
    int n = 0;
    for (int i = 0; i < n_syms; i++) {
        if (isupper(symtab[i].name[0])) continue;
        if (symtab[n].value > v)
            n = i;
        else if (symtab[i].value <= v && symtab[i].value > symtab[n].value)
            n = i;
    }
    return &symtab[n];
}

void xread(void* buf, size_t n)
{
    while (n) {
        size_t q = read(fd, buf, n);
        assert(n != -1);
        buf += q;
        n -= q;
    }
}

void readmem()
{
    size_t base = 0, n = 0;
    xread(&base, 2);
    xread(&n, 2);
    xread(mem + base * 16, n * 512);
    // printf("%lx %lx %x\n", base, n, at(base, 1024));
}

void nread(char* buf)
{
    do {
        xread(buf, 1);
        if (*buf == '\b') buf -= 2;
    } while (*buf++ != '\n');
}

int eq(const char** cmd, const char* name)
{
    const char* c = *cmd;
    while (*c++ == *name++);
    if (*(c - 1) != ' ' && *(c - 1) != '\n' && *(c - 1) != '+' && *(c - 1) != '(' && *(c - 1) != ')' && *(c - 1) != ':' || *--name != '\0') return 0;
    *cmd = c - 1;
    return 1;
}

u16 skip_atoi(const char** s)
{
    u16 r = 0;
    while (isalnum(**s)) {
        if (**s == 'x') {
            (*s)++;
            continue;
        }
        r = r * 16 + **s - (isdigit(**s) ? '0' : 'a' - 10);
        (*s)++;
    }
    return r;
}

void cmd_p(const char* cmd)
{
    u32 sum;
    u16* rr;
    u16 star;
    const char* prompt;
go:
    sum = 0;
    star = 0;
    while (*cmd == ' ') cmd++;
    if (*cmd == '\n') return;
    prompt = cmd;
    while (*cmd == '*') star++, cmd++;
go2:
    // try register
    rr = (u16*)&regs;
    for (const char** name = names; *name; name++, rr++)
        if (eq(&cmd, *name)) {
            sum += *rr;
            goto end;
        }
    // try symbol
    for (struct symbol* s = symtab; s < symtab + n_syms; s++)
        if (eq(&cmd, s->name)) {
            sum += s->value;
            goto end;
        }
    // try number
    sum += skip_atoi(&cmd);
end:
    if (*cmd == '+' || *cmd == '(' || *cmd == ':') {
        sum = *cmd == ':' ? sum * 16 : sum;
        star += *cmd++ == '(';
        goto go2;
    }
    while (*cmd == ')') cmd++;

    while (star--) {
        sum = *(u16*)(mem + sum);
    }
    printf("%.*s=0x%04x (near '%s') [", (int)(cmd - prompt), prompt, sum, near(sum)->name);
    for (u32 i = 0; i < 16; i++)
        putchar(isprint(mem[sum + i]) ? mem[sum + i] : '.');
    printf("]\n");
    goto go;
}

int main()
{
    FILE* f;
    int r;

    fd = open(".bin/syms", O_RDONLY);
    size_t n = read(fd, symbuf, 10000);
    size_t i = 0;
    close(fd);
    while (i < n) {
        symtab[n_syms].value = *(u16*)(symbuf + i);
        i += 2;
        symtab[n_syms].name = symbuf + i;
        i += strlen(symtab[n_syms].name) + 1;
        n_syms++;
    }

    fd = open(".bin/rs2", O_RDONLY);

next:
    xread(&regs, sizeof(regs));
    readmem(); // kernel memory
    readmem(); // process memory

    printf("reak near '%s' (cs:ip=%04x:%04x) `%04x`\n", near(regs.ip)->name, regs.cs, regs.ip, at(regs.cs, regs.ip));

line:
    printf("i: "); fflush(stdout);
    nread(buf);
    char* cmd = buf, c;
go:
    switch (c = *cmd++) {
        case ' ': goto go;
        case '\n': goto line;
        case -1: goto next;
        case 'p': cmd_p(cmd); break;
        case 'd':
            f = fopen("1", "wb");
            fwrite(mem, 1, 1024 * 1024, f);
            fclose(f);
            break;
    }

    goto line;

    close(fd);

    return 0;
}
