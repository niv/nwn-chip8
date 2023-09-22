#include "chip8_util"
#include "chip8_disp"
#include "chip8_input"

const int MEM_SIZE            = 0x1000; // 4096 bytes

// 8 bit registers below this line
//
// Only these are addressable with nibbles.
const int REG_V0              = 0;
const int REG_V1              = 1;
const int REG_V2              = 2;
const int REG_V3              = 3;
const int REG_V4              = 4;
const int REG_V5              = 5;
const int REG_V6              = 6;
const int REG_V7              = 7;
const int REG_V8              = 8;
const int REG_V9              = 9;
const int REG_VA              = 10;
const int REG_VB              = 11;
const int REG_VC              = 12;
const int REG_VD              = 13;
const int REG_VE              = 14;
const int REG_VF              = 15;

// special purpose regs: only accessible through opcodes
const int REG_DELAY           = 17;
const int REG_SOUND           = 18;

// interpreter extension: stack pointer
const int REG_SP              = 16;
// interpreter extension: interpreter/sys flags (SYSEXT_FLAG_*)
const int REG_SYSEXT          = 19;

// 12 bit below this line

const int REG_I               = 20;

// interpreter extension: stack pointer
const int REG_CYCLES          = 21;
// interpreter extension: program counter
const int REG_PC              = 22;

const int REG_MAX             = REG_PC + 1;

const int STACK_SIZE          = 12;

const int SYSEXT_FLAG_ABORT   = 0x00;

int WORD(int val)
{
    return val & 0xffff;
}

int ADDR(int val)
{
    return val & 0xfff;
}

int BYTE(int val)
{
    return val & 0xff;
}

json getRegisters() { return GetLocalJson(GetModule(), "reg"); }
void setRegisters(json reg) { SetLocalJson(GetModule(), "reg", reg); }

int regRead(int reg)
{
    if (reg < 0 || reg > REG_MAX) ERROR("unknown register: " + IntToString(reg));
    int ret = JsonGetInt(JsonArrayGet(getRegisters(), reg));
    // TRACE("regRead(" + IntToString(reg) + ") = " + IntToString(ret));
    ASSERT(ret >= 0 && (reg >= REG_I ? 0xfff : 0xff), "register " + IntToString(reg) + " out of range: " + IntToString(ret));
    return ret;
}

void regWrite(int reg, int val)
{
    // val = val & reg >= REG_I ? 0xfff : 0xff;
    // TRACE("regWrite(" + IntToString(reg) + ", " + IntToString(val) + ")");
    if (reg < 0 || reg > REG_MAX)
        ERROR("unknown register: " + IntToString(reg));
    // if (val < 0 || val > (reg >= REG_I ? 0xFFF : 0xFF))
    //     ERROR("value out of range: " + IntToString(val));

    JsonArraySetInplace(getRegisters(), reg, JsonInt(reg >= REG_I ? ADDR(val) : BYTE(val)));
}

// 12 bit
int pcRead()
{
    return regRead(REG_PC);
}

void pcWrite(int pc)
{
    regWrite(REG_PC, pc);
}

json getStack() { return GetLocalJson(GetModule(), "stack"); }
void setStack(json stack) { SetLocalJson(GetModule(), "stack", stack); }

int stackPop()
{
    int sp = regRead(REG_SP);
    ASSERT(sp >= 0 && sp < STACK_SIZE, "stack over/underflow");
    int pc = JsonGetInt(JsonArrayGet(getStack(), sp));
    sp--;
    regWrite(REG_SP, sp);
    return pc;
}

void stackPush(int pc)
{
    int sp = regRead(REG_SP);
    ASSERT(sp >= -1 && sp < STACK_SIZE, "stack over/underflow");
    sp++;
    JsonArraySetInplace(getStack(), sp, JsonInt(pc));
    regWrite(REG_SP, sp);
}

// +---------------+= 0xFFF (4095) End of Chip-8 RAM
// |               |
// |               |
// |               |
// |               |
// |               |
// | 0x200 to 0xFFF|
// |     Chip-8    |
// | Program / Data|
// |     Space     |
// |               |
// |               |
// |               |
// +- - - - - - - -+= 0x600 (1536) Start of ETI 660 Chip-8 programs
// |               |
// |               |
// |               |
// +---------------+= 0x200 (512) Start of most Chip-8 programs
// | 0x000 to 0x1FF|
// | Reserved for  |
// |  interpreter  |
// +---------------+= 0x000 (0) Start of Chip-8 RAM

json getMem() { return GetLocalJson(GetModule(), "mem"); }
void setMem(json mem) { SetLocalJson(GetModule(), "mem", mem); }

int memRead(int address)
{
    ASSERT(address >= 0 && address <= MEM_SIZE, "memRead() address out of range: " + IntToHexString(address));
    return JsonGetInt(JsonArrayGet(getMem(), address));
}

void memWrite(int address, int val)
{
    ASSERT(address >= 0 && address <= MEM_SIZE, "memWrite() address out of range: " + IntToHexString(address));
    JsonArraySetInplace(getMem(), address, JsonInt(BYTE(val)));
}

// Write the given hex payload to memory starting at memoffset.
// Whitespace in hex is ignored.
void memWriteHex(int memoffset, string hex)
{
    json mem = getMem();
    int hexlen = GetStringLength(hex);

    string instr;
    int instrlen;

    int hexoffset;
    for (hexoffset = 0; hexoffset < hexlen; hexoffset++)
    {
        string c = GetSubString(hex, hexoffset, 1);
        if (c == " " || c == "\n") continue;
        instr = instr + c;
        instrlen++;

        if (instrlen == 2)
        {
            int in = HexStringToInt(instr);

            memWrite(memoffset, in);

            instrlen = 0;
            instr = "";
            memoffset++;
        }
    }
}

string memReadHex(int start, int count)
{
    json mem = getMem();
    string ret = AddrToHex(start) + ": ";
    int i;
    int printed;
    for (i = start; i < start + count; i++)
    {
        ret = ret + ByteToHex(memRead(i)) + " ";
        printed++;
        if (printed % 8 == 0)
        {
            ret += "\n" + AddrToHex(i) + ": ";
        }
    }

    return ret;
}

void cpuReset()
{
    int i;

    // Reset registers to a debug value.
    json reg = JsonArray();
    for (i = 0; i < REG_MAX; i++)
    {
        JsonArrayInsertInplace(reg, JsonInt(0x00));
    }
    setRegisters(reg);

    regWrite(REG_PC, 0x200);

    // Memory is reset to 00 as well, which is a instruction
    // that immediately aborts.
    json mem = JsonArray();
    for (i = 0; i < MEM_SIZE; i++)
    {
      JsonArrayInsertInplace(mem, JsonInt(0x0000));
    }
    setMem(mem);

    // Default pattern in framebuffer is a debug checkerboard.
    json display = JsonArray();
    for (i = 0; i < DISPLAY_SIZE; i++)
    {
        JsonArrayInsertInplace(display, JsonBool(i % 5 == 0 || i % 3 == 0));
    }
    setDisp(display);

    // Reset the stack.
    json stack = JsonArray();
    for (i = 0; i < STACK_SIZE; i++)
    {
        JsonArrayInsertInplace(stack, JsonInt(0xfff));
    }
    setStack(stack);

    keypadTrapReset();
}

// Should be called once per clock cycle. Housekeeping to run at 60hz
// with overflwo is handled int ernally
void cpuClock()
{
    regWrite(REG_CYCLES, regRead(REG_CYCLES + 1));

    int delay = regRead(REG_DELAY);

    if (delay > 0)
    {
        int last = GetLocalInt(GetModule(), "delay_timer_last");
        int now = GetTimeSecond() * 1000 + GetTimeMillisecond();

        int diff = abs(now - last);
        DEBUG("delay timer now=" + IntToString(now) + " last=" + IntToString(last) + " diff=" + IntToString(diff));

        // if (now - lastDelayTick > 10)
        {
            // regWrite(REG_DELAY, delay - 1);
            // SetLocalInt(GetModule(), "delay_timer_last", now);
        }
    }
}
