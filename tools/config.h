#pragma once

#define tests 1

#define STACK_SIZE      4096
#define N_PROC          10
#define N_OPEN          10
#define N_FSP           20
#define N_INODES        1024
#define N_ZONES         512*8
#define TTY_SIZE        128

#include <stdint.h>

typedef uint8_t u1;
typedef uint16_t u2;
typedef uint32_t u4;

#define I_X 1
#define I_W 2
#define I_R 4
#define I_D 8
#define I_IMAGE 16

struct inode
{
    u1 flags;
    u1 links;
    u2 size;
    u4 ctime;
    u4 mtime;
    u2 zones[10];
};
#define inode_log 5

#define UNMAPPED_ZONES 3
struct disk
{
    u1 boot[506];
    u2 meta_zones;
    u2 image;
    u2 magic;
    u1 pad[UNMAPPED_ZONES*512-512];
    u1 zone_map[N_ZONES/8];
    u1 inode_map[N_INODES/8];
    struct inode inodes[N_INODES];
};

#define KERNEL_OFFSET   disk_size

struct dir
{
    u2 number;
    u1 name[14];
};

struct fp
{
    u1 mode;
    u1 links;
    u2 inode;
    u2 pos;
    u2 buf;
};
#define fp_log 3

struct proc
{
   u2 id;
   u2 parent;
   u2 seg;
   u2 ax;
   u2 brk;
   u2 root;
   u2 pwd;
   u2 sp;
   u2 fd[N_OPEN];
};
