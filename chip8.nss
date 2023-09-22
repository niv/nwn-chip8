
#include "chip8_util"
#include "chip8_disp"
#include "chip8_exc"
#include "chip8_cpu"
#include "chip8_nui"
#include "chip8_clk"
#include "chip8_run"

void main()
{
    int i;

    DEBUG("== CHIP8 Bootup ==");

    int token = nuiCreate();
    SetLocalInt(GetModule(), "token", token);

    NuiSetBind(GetFirstPC(), token, "stopped", JsonBool(TRUE));
    NuiSetBind(GetFirstPC(), token, "selected_program", JsonInt(1));

    NuiSetBindWatch(GetFirstPC(), token, "btn_run", TRUE);

    NuiSetBindWatch(GetFirstPC(), token, "btn_abort", TRUE);
    NuiSetBindWatch(GetFirstPC(), token, "btn_step", TRUE);
    NuiSetBindWatch(GetFirstPC(), token, "btn_run", TRUE);

    for (i = 0; i < 0xf; i++)
        NuiSetBindWatch(GetFirstPC(), token, "btn_keypad_" + IntToString(i), TRUE);

    resetAll();
}
