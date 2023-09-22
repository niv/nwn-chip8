#include "chip8_clk"
#include "chip8_nui"
#include "chip8_input"
#include "chip8_run"

void main()
{
    object pc     = NuiGetEventPlayer();
    int    token  = NuiGetEventWindow();
    string evt    = NuiGetEventType();
    string elem   = NuiGetEventElement();
    int    idx    = NuiGetEventArrayIndex();
    string wndid  = NuiGetWindowId(pc, token);
    json payload  = NuiGetEventPayload();

    // string msg = "Nui Event: " + evt +
    //     " token=" + IntToString(token) +
    //     " windowId=" + wndid +
    //     " elemId=" + elem +
    //     (idx > -1 ? ("[" + IntToString(idx) + "]") : "") +
    //     " payload=" + JsonDump(payload);
    // if (evt == "watch")
    //     msg = msg + " watchval=" + JsonDump(NuiGetBind(pc, token, elem));
    // SendMessageToPC(pc, msg);

    if ((evt == "mousedown" || evt == "mouseup") && GetSubString(elem, 0, 11) == "btn_keypad_")
    {
        string btn = GetSubString(elem, 11, 2);
        keypadSet(StringToInt(btn), evt == "mousedown");
    }

    if (evt == "click")
    {
        if (elem == "btn_reset")
            resetAll();
        else if (elem == "btn_halt")
            stopRunning();
        else if (elem == "btn_run")
            startRunning();
        else if (elem == "btn_step")
            stepOnce();
    }
}
