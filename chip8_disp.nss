const int DISPLAY_COLS        = 64;
const int DISPLAY_ROWS        = 32;
const int DISPLAY_SIZE        = DISPLAY_COLS * DISPLAY_ROWS;

int dispCoordToAddr(int x, int y) { return x + y * DISPLAY_COLS; }

json getDisp() { return GetLocalJson(GetModule(), "display"); }
void setDisp(json display) { SetLocalJson(GetModule(), "display", display); }

int dispCheckDirtyAndReset()
{
    int d = GetLocalInt(GetModule(), "display_dirty");
    SetLocalInt(GetModule(), "display_dirty", 0);
    return d;
}

int dispRead(int address)
{
    return JsonGetInt(JsonArrayGet(getDisp(), address));
}

void dispWrite(int address, int flag)
{
    json disp = getDisp();
    JsonArraySetInplace(disp, address, JsonBool(flag));
    SetLocalInt(GetModule(), "display_dirty", 1);
}
