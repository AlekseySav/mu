#include "config.h"
#include <stdio.h>
#include <libgen.h>
#include <stdlib.h>
#include <string.h>
#include <stdbool.h>

#define trace(fmt, ...) fprintf(stderr, fmt "\n" __VA_OPT__(,) __VA_ARGS__)

#define META_ZONES ((sizeof(struct disk) + 511) / 512)

struct {
    struct disk d;
    u1 pad[META_ZONES * 512 - sizeof(struct disk)];
    u1 zones[N_ZONES - META_ZONES][512];
} disk;

#define d_zone(n) (disk.zones[(n) - META_ZONES])

int n_zones = META_ZONES;
int n_inodes = 1;

int new_inode()
{
    int i = n_inodes++;
    disk.d.inode_map[i / 8] |= 1 << (i % 8);
    return i;
}

int new_zone()
{
    int z = n_zones++;
    disk.d.zone_map[z / 8] |= 1 << (z % 8);
    return z;
}

int pathcmp(const char* a, const char* b)
{
    while (*a == *b) a++, b++;
    if ((*a == '/' || *a == '\0') && (*b == '/' || *b == '\0'))
        return 1;
    return 0;
}

void entry(int owner, int inode, const char* name, int len)
{
    if (len == 0) len = strlen(name);
    struct inode* i = &disk.d.inodes[owner];
    struct dir* dir = (struct dir*)&d_zone(i->zones[0]);
    dir[i->size / 16].number = inode;
    strncpy(dir[i->size / 16].name, name, len);
    i->size += 16;
}

int mkdir(int parent)
{
    int inode = new_inode();
    struct inode* i = &disk.d.inodes[inode];
    i->flags = 6 | I_D;
    i->links = 1;
    i->zones[0] = new_zone();
    struct dir* dir = (struct dir*)&d_zone(i->zones[0]);
    entry(inode, parent, "..", 2);
    entry(inode, inode, ".", 1);
    return inode;
}

int mkdir_p(int inode, char* path)
{
    if (*path == '/') path++;
    if (strchr(path, '/') == NULL) return inode;
    int len = strchr(path, '/') - path;
    struct inode* i = &disk.d.inodes[inode];
    struct dir* dir = (struct dir*)&d_zone(i->zones[0]);
    for (int j = 0; j < i->size / 16; j++)
        if (pathcmp(dir[j].name, path))
            return mkdir_p(dir[j].number, path + len);
    int number = mkdir(inode);
    entry(inode, number, path, len);
    return number;
}

void boot(int inode, const char* path)
{
    FILE* f = fopen(path, "rb");
    if (fread(disk.d.boot, 1, 507, f) > 506)
    {
        trace("boot size exceeded");
        exit(1);
    }
    disk.d.magic = 0xaa55;
    disk.d.meta_zones = META_ZONES;
    fclose(f);
    struct inode* i = &disk.d.inodes[inode];
    i->size = 506;
    i->links = 1;
    i->flags = 0004;
}

void copy(int inode, const char* path)
{
    bool small = true;
    u1 buf[512];
    FILE* f = fopen(path, "rb");
    size_t n;
    struct inode* i = &disk.d.inodes[inode];
    i->flags = 0006;
    i->links = 1;
    int zone = 0;
    u2* zones = i->zones;
    while (n = fread(buf, 1, 512, f))
    {
        i->size += n;
        zones[zone] = new_zone();
        memcpy(d_zone(zones[zone]), buf, n);
        if (++zone == 9 && small)
        {
            small = false;
            zone = 0;
            zones[9] = new_zone();
            zones = (u2*)(d_zone(zones[9]));
        }
    }
    fclose(f);
}

void change_flags(struct inode* inode, const char* flags)
{
    for (;;)
    {
        switch (*flags++)
        {
            case 'r': inode->flags |= I_R; break;
            case 'w': inode->flags |= I_W; break;
            case 'x': inode->flags |= I_X; break;
            case 'i': inode->flags |= I_IMAGE; break;
            case '\0': return;
            default:
                trace("unknown inode flags");
                exit(1);
                break;
        }
    }
}

int main(int argc, char** argv)
{
    for (int i = 0; i < (n_zones + 7) / 8; i++) disk.d.zone_map[i] = 0xff;
    disk.d.inode_map[0] = 1;
    mkdir(1);
    trace("fs metadata size: %d bytes (%d zones)", n_zones * 512, n_zones);
    trace("disk size: %d bytes (%d zones)", N_ZONES * 512, N_ZONES);
    struct inode* prev_inode;
    for (int i = 1; i < argc; i++)
    {
        if (argv[i][0] == '+')
        {
            change_flags(prev_inode, argv[i] + 1);
            continue;
        }
        char* dst = argv[i];
        char* src = strchr(argv[i], '=');
        *src++ = '\0';
        int parent = mkdir_p(1, dst);
        int inode = new_inode();
        prev_inode = disk.d.inodes + inode;
        trace("%s...", dst);
        entry(parent, inode, basename(dst), 0);
        if (!strcmp(dst, "/etc/boot"))
        {
            boot(inode, src);
            continue;
        }
        copy(inode, src);
        if (!strcmp(dst, "/etc/mu"))
        {
            disk.d.image = inode;
            trace("kernel size: %d bytes (%d zones)", prev_inode->size, (prev_inode->size + 511) / 512);
        }
    }
    fwrite(&disk, 1, sizeof(disk), stdout);
    trace("installed image uses %d/%d zones (%d%% of disk space)", n_zones, N_ZONES, (n_zones * 100) / N_ZONES);
    trace("installed image uses %d/%d inodes (%d%% of files)", n_inodes, N_INODES, (n_inodes * 100) / N_INODES);
    return 0;
}
