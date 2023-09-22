#include "chip8_util"

const int BUTTON_0   = 0;
const int BUTTON_1   = 1;
const int BUTTON_2   = 2;
const int BUTTON_3   = 3;
const int BUTTON_4   = 4;
const int BUTTON_5   = 5;
const int BUTTON_6   = 6;
const int BUTTON_7   = 7;
const int BUTTON_8   = 8;
const int BUTTON_9   = 9;
const int BUTTON_A   = 10;
const int BUTTON_B   = 11;
const int BUTTON_C   = 12;
const int BUTTON_D   = 13;
const int BUTTON_E   = 14;
const int BUTTON_F   = 15;
const int BUTTON_MAX = BUTTON_F + 1;

json getKeypad() { return GetLocalJson(GetModule(), "keypad"); }
void setKeypad(json keypad) { SetLocalJson(GetModule(), "keypad", keypad); }

int keypadRead(int button)
{
    ASSERT(button >= 0 && button < BUTTON_MAX, "button out of range");
    return JsonGetInt(JsonArrayGet(getKeypad(), button));
}

void keypadSet(int button, int state)
{
    ASSERT(button >= 0 && button < BUTTON_MAX, "button out of range");
    DEBUG("keypad down: " + ByteToHex(button) + " state " + IntToString(state));
    JsonArraySetInplace(getKeypad(), button, JsonBool(state));

    if (state && GetLocalInt(GetModule(), "keypad_trap_enabled") == 1)
    {
        SetLocalInt(GetModule(), "keypad_trap_enabled", 2);
        // SetLocalInt(GetModule(), "keypad_trap_reg", 0);
        SetLocalInt(GetModule(), "keypad_trap_button", button);

    }
}

// There's a instruction to wait for a keypad key to be pressed down

// Configure input event to trap for any key; then put that key into reg.
void keypadTrapKey(int reg)
{
    DEBUG("trap key on reg " + ByteToHex(reg));
    SetLocalInt(GetModule(), "keypad_trap_enabled", 1);
    SetLocalInt(GetModule(), "keypad_trap_reg", reg);
}

int keypadIsTrapped()
{
    return GetLocalInt(GetModule(), "keypad_trap_enabled") > 0;
}

void keypadTrapReset()
{
    SetLocalInt(GetModule(), "keypad_trap_enabled", 0);
}

// Returns TRUE if the keypad trap has been sprung; a button has been pressed.
// This resets the trap.
int keypadTrapSprung()
{
    if (GetLocalInt(GetModule(), "keypad_trap_enabled") == 2)
    {
        SetLocalInt(GetModule(), "keypad_trap_enabled", 0);
        return TRUE;
    }

    return FALSE;
}

int keypadTrapGetButton()
{
    return GetLocalInt(GetModule(), "keypad_trap_button");
}

int keypadTrapGetReg()
{
    return GetLocalInt(GetModule(), "keypad_trap_reg");
}
