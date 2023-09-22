#include "chip8_nui"
#include "chip8_util"
#include "chip8_clk"
#include "chip8_cpu"
#include "chip8_sprite"

int isRunning()
{
    // TODO: detect aborts by last tick timestamp?
    return GetLocalInt(GetModule(), "running");
}

void stopRunning()
{
    SetLocalInt(GetModule(), "running", FALSE);
}

int _step()
{
    int ret = clockStep();
    nuiRefresh();
    if (ret == CLOCK_STEP_RESULT_ABORT)
        AbortRunningScript("ABORT");
    return ret;
}

// Execute one step and update all panels.
int stepOnce()
{
    ASSERT(!isRunning(), "must not be not running");
    return _step();
}

void _loop()
{
    if (!isRunning())
    {
        DEBUG("Exiting runloop");
        return;
    }

    int ret = _step();

    // if (ret == CLOCK_STEP_RESULT_SUSPEND)
    // {
    //     DEBUG("TODO: handle suspend correctly here");
    //     return;
    // }

    DelayCommand(CLK_RATE / 1000000.0, _loop());
}

// Start running and do mainloop.
void startRunning()
{
    ASSERT(!isRunning(), "not running");
    SetLocalInt(GetModule(), "running", TRUE);
    _loop();
}

void loadProgram(string prog)
{
    stopRunning();
    memWriteHex(0x200, prog);
    nuiRefresh(1);
}

void resetAll()
{
    stopRunning();

    cpuReset();
    nuiRefresh(1);

    object obj = GetModule();
    int i;

    memWriteHex(SRPITE_OFFSET, SPRITE_FONT);

    SetLocalInt(GetModule(), "delay_timer_last", 0);

    json keypad = JsonArray();
    for (i = 0; i < BUTTON_MAX; i++)
    {
        JsonArrayInsertInplace(keypad, JsonBool(0));
    }
    setKeypad(keypad);

    int sel = JsonGetInt(NuiGetBind(GetFirstPC(), GetLocalInt(GetModule(), "token"), "selected_program"));
    string r = GetLocalString(GetModule(), "program_" + IntToString(sel));
    if (r != "")
    {
        DEBUG("Selected program: " + r);
        loadProgram(ResManGetFileContents(r, RESTYPE_RES, RESMAN_FILE_CONTENTS_FORMAT_HEX));
    }
}
