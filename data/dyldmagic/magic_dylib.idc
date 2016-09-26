#include <idc.idc>

static CreateDword(address, name) {
  MakeDword(address);
  MakeName(address, name);
}

static CreateFunc(address, name) {
  MakeCode(address);
  MakeName(address, name);
}

static CreateEnum(address, name) {
}

static processParamsSysCall(address) {
  LoadTil("arm/macosx.til");
  Til2Idb(-1, "MACRO_SYS");
  auto enumID = GetEnum("MACRO_SYS");
  auto addr = DfirstB(address);
  while (addr != BADADDR) {
    Message("%x\n", addr - 6*4);
    OpEnumEx(addr - 6*4, 0, enumID, 0);
    addr = DnextB(address, addr);
  }
}

static main() {
  CreateFunc(0x5001DFB0, "_open");
  CreateFunc(0x5001DF58, "___mmap");
  CreateFunc(0x5001E320, "___syscall");
  processParamsSysCall(0x5001E320);
  CreateFunc(0x50017D94, "_bcopy");
  CreateFunc(0x5001B8E0, "_bzero");
  //
  CreateFunc(0x500030A6, "pop_r4r7pc");
  CreateFunc(0x5000D8AA, "add_r0r2_pop_r4r5r7pc");
  CreateFunc(0x50009B6E, "str_r0_r4_8_pop_r4r7pc");
  CreateFunc(0x5000BCAC, "pop_r2pc");
  CreateFunc(0x50016030, "pop_r0r1r2r3r5r7pc");
  CreateFunc(0x50016038, "pop_r0r1r3r5r7pc");
  CreateFunc(0x500015DC, "pop_r7pc");
  CreateFunc(0x5001A458, "mov_sp_r4_pop_r4r7pc");
  CreateFunc(0x500133A8, "mov_r0_r0_lsr2_pop_r4r5r7pc");
  CreateFunc(0x5000DCDA, "ldr_r0_r0_8_pop_r7_pc");
  CreateFunc(0x50008862, "pop_r4r7lr_bx_r1");
  CreateFunc(0x50001228, "pop_r8r10r11r4r5r6r7pc");
  CreateFunc(0x500015DA, "mov_r0_lr_pop_r7pc");

  auto off = 0;
  CreateDword(0x52001C48 + off, "m_m_scratch");
  /*
  auto off = - 4 * 4;
  CreateDword(0x52006554 + off, "m_m_stratch");
  CreateDword(0x52001804 + off, "pipe_1_minus_8");
  CreateDword(0x52001808 + off, "dyl_minus8_and_pipe");
  CreateDword(0x52001810 + off, "dyl");
  CreateDword(0x52001814 + off, "__loop");
  CreateDword(0x52001818 + off, "__end_of_loop0");
  CreateDword(0x5200181C + off, "__nextAddress");
  CreateDword(0x52001820 + off, "__end_of_loop");
  CreateDword(0x52001824 + off, "writeResult0_and_loopI");
  CreateDword(0x52001828 + off, "writeResult");
  CreateDword(0x5200182C + off, "loopI");
  //
  MakeName(Dword(0x52001814 + off), "__loop_start");
  MakeName(Dword(0x5200181C + off), "__next_address");
  MakeName(Dword(0x52001820 + off), "__loop_end");
  */
}

