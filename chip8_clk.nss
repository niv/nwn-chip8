#include "chip8_cpu"
#include "chip8_exc"

const int CLK_RATE                      = 16000; // usec

const int CLOCK_STEP_RESULT_AGAIN       = 0;
const int CLOCK_STEP_RESULT_ABORT       = 1;
const int CLOCK_STEP_RESULT_SUSPEND     = 2;

int clockStep()
{
    if (regRead(REG_SYSEXT) & SYSEXT_FLAG_ABORT)
        return CLOCK_STEP_RESULT_ABORT;

    // TODO: calculate timing drift for each clock cycle

    // int now = GetMicrosecondCounter();
    // int drift = (now - last) - CLK_RATE;
    // if (drift > 0)
    //     DEBUG("clock slow: " + IntToString(drift));
    // last = now;

    cpuClock();

    // If suspended?
    if (keypadIsTrapped())
    {
        if (!keypadTrapSprung())
        {
            return CLOCK_STEP_RESULT_AGAIN;
        }

        // Trap was sprung
        int reg = keypadTrapGetReg();
        int btn = keypadTrapGetButton();
        regWrite(reg, btn);
    }

    json mem = getMem();

    // Decode and execute one instruction per clock cycle.
    int pc = pcRead();
    int pcorg = pc;
    int instrA = JsonGetInt(JsonArrayGet(mem, pc));
    int instrB = JsonGetInt(JsonArrayGet(mem, pc+1));
    int instr = (instrA << 8) | instrB;

    int exc = cpuExecuteInstr(instr);
    if (exc == EXEC_RESULT_FAIL)
    {
        ERROR("Failed to decode instruction: " + WordToHex(instr));
    }
    else if (exc == EXEC_RESULT_JMP)
    {
        // Someone else changed PC
    }
    // else if (exc == EXEC_RESULT_SUSPEND)
    // {
    //     pcWrite(pc + exc);
    //     DEBUG("Suspending operation");
    //     SetLocalInt(GetModule(), "cpu_suspended", 1);
    //     return CLOCK_STEP_RESULT_SUSPEND;
    // }
    else if (exc > 0)
    {
        pcWrite(pc + exc);
    }

    return CLOCK_STEP_RESULT_AGAIN;
}
