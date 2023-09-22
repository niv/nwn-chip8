#include "nw_inc_nui"
#include "chip8_util"
#include "chip8_cpu"
#include "chip8_disp"

const float PIXEL_SIZE          = 7.0;
const float TEXT_HEIGHT_FF      = 35.0;
const float TEXT_WIDTH_FFF      = 50.0;
const float TEXT_WIDTH_FF       = 35.0;
const float REGVIEW_LINE_HEIGHT = 12.0;

// We try to ship as much state as possible in array binds, to cut down the
// number of network packets/bind updates.

void nuiRefresh(int fullRefresh = 0)
{
    int token = GetLocalInt(GetModule(), "token");
    ASSERT(token > 0, "no nui token");
    object pc = GetFirstPC();

    if (dispCheckDirtyAndReset() || fullRefresh)
    {
        NuiSetBind(pc, token, "disp", getDisp());
    }

    NuiSetBind(pc, token, "reg",    getRegisters());
    NuiSetBind(pc, token, "stack",  getStack());
}

int nuiCreate()
{
    object pc = GetFirstPC();

    int i;
    json rootCol = JsonArray();

    // display and keypad
    {
        json row = JsonArray();

        json drawList = JsonArray();

        int x, y;
        for (y = 0; y < DISPLAY_ROWS; y++)
        {
            for (x = 0; x < DISPLAY_COLS; x++)
            {
                JsonArrayInsertInplace(drawList, NuiDrawListRect(
                    NuiBind("disp"),
                    NuiColor(254, 195, 10),
                    JSON_TRUE, // fill
                    JsonFloat(0.0), // line width
                    NuiRect(PIXEL_SIZE * x, PIXEL_SIZE * y, PIXEL_SIZE, PIXEL_SIZE),
                    NUI_DRAW_LIST_ITEM_ORDER_AFTER, NUI_DRAW_LIST_ITEM_RENDER_ALWAYS, TRUE
                ));
            }
        }

        json display = NuiId(NuiSpacer(), "disp");
        display = NuiHeight(display, DISPLAY_ROWS * PIXEL_SIZE + 5);
        display = NuiWidth(display,  DISPLAY_COLS * PIXEL_SIZE + 5);
        display = NuiDrawList(
            display,
            JSON_TRUE, // scissor
            drawList
        );
        JsonArrayInsertInplace(row, display);

        JsonArrayInsertInplace(row, NuiSpacer());

        json keypad = JsonArray();
        json keypadRow = JsonArray();
        for (i = 0; i <= 0xf; i++)
        {
            json btn = NuiButton(JsonString(NibbleToHex(i)));
            btn = NuiHeight(btn, TEXT_HEIGHT_FF);
            btn = NuiWidth(btn, TEXT_WIDTH_FF);
            btn = NuiId(btn, "btn_keypad_" + IntToString(i));
            JsonArrayInsertInplace(keypadRow, btn);
            if (i % 4 == 3)
            {
                JsonArrayInsertInplace(keypad, NuiRow(keypadRow));
                keypadRow = JsonArray();
            }
        }

        JsonArrayInsertInplace(row, NuiCol(keypad));

        JsonArrayInsertInplace(rootCol, NuiRow(row));
    }

    // registers, pc, cycles, and stack
    {
        json row = JsonArray();

        // reg labels
        {
            json dl = JsonArray();
            int reg; for (reg = 0; reg < REG_MAX; reg++)
            {
                JsonArrayInsertInplace(dl, NuiDrawListText(
                    JSON_TRUE,
                    NuiColor(255, 0, 255),
                    NuiRect(0.0, REGVIEW_LINE_HEIGHT * reg, 15.0, REGVIEW_LINE_HEIGHT + REGVIEW_LINE_HEIGHT * reg),
                    NuiBind("label_reg"),
                    NUI_DRAW_LIST_ITEM_ORDER_AFTER, NUI_DRAW_LIST_ITEM_RENDER_ALWAYS, TRUE
                ));
            }
            json regLabels = NuiWidth(NuiSpacer(), 10.0);
            regLabels = NuiDrawList(regLabels, JSON_TRUE, dl);
            regLabels = NuiHeight(regLabels, 10.0 + REGVIEW_LINE_HEIGHT * REG_MAX);
            JsonArrayInsertInplace(row, regLabels);
        }

        // regs
        {
            json dl = JsonArray();
            int reg; for (reg = 0; reg < REG_MAX; reg++)
            {
                JsonArrayInsertInplace(dl, NuiDrawListText(
                    JSON_TRUE,
                    NuiColor(255, 255, 0),
                    NuiRect(25.0, REGVIEW_LINE_HEIGHT * reg, 600.0, REGVIEW_LINE_HEIGHT + REGVIEW_LINE_HEIGHT * reg),
                    NuiBind("reg", NUI_NUMBER_FLAG_HEX, reg >= REG_I ? 3 : 2, 2),
                    NUI_DRAW_LIST_ITEM_ORDER_AFTER, NUI_DRAW_LIST_ITEM_RENDER_ALWAYS, TRUE
                ));
            }

            json regs = NuiSpacer();
            regs = NuiWidth(regs, 20.0);
            regs = NuiHeight(regs, 10.0 + REGVIEW_LINE_HEIGHT * REG_MAX);
            regs = NuiDrawList(regs, JSON_TRUE, dl);
            JsonArrayInsertInplace(row, regs);
        }

        // stack view
        {
            json dl = JsonArray();
            int sp; for (sp = 0; sp < STACK_SIZE; sp++)
            {
                JsonArrayInsertInplace(dl, NuiDrawListText(
                    JSON_TRUE,
                    NuiColor(128, 255, 255), // TODO: color change on value change
                    NuiRect(60.0, REGVIEW_LINE_HEIGHT * (sp+4), 100.0, REGVIEW_LINE_HEIGHT + REGVIEW_LINE_HEIGHT * (sp+4)),
                    NuiBind("stack"),
                    NUI_DRAW_LIST_ITEM_ORDER_AFTER, NUI_DRAW_LIST_ITEM_RENDER_ALWAYS, TRUE
                ));
            }

            // we also render the PC and cycle counter here, outside of the stack array
            // JsonArrayInsertInplace(dl, NuiDrawListText(
            //     JSON_TRUE,
            //     NuiColor(255, 0, 0),
            //     NuiRect(60.0, 0.0, 100.0, REGVIEW_LINE_HEIGHT + REGVIEW_LINE_HEIGHT),
            //     NuiBind("pc")
            // ));

            // JsonArrayInsertInplace(dl, NuiDrawListText(
            //     JSON_TRUE,
            //     NuiColor(128, 128, 255),
            //     NuiRect(60.0, REGVIEW_LINE_HEIGHT + REGVIEW_LINE_HEIGHT, 100.0, REGVIEW_LINE_HEIGHT + REGVIEW_LINE_HEIGHT),
            //     NuiBind("cycles")
            // ));

            json stack = NuiSpacer();
            stack = NuiWidth(stack, 60.0);
            stack = NuiHeight(stack, 10.0 + REGVIEW_LINE_HEIGHT * STACK_SIZE);
            stack = NuiDrawList(stack, JSON_TRUE, dl);
            JsonArrayInsertInplace(row, stack);
        }

        // json mem = NuiSpacer();
        // {
        //     json dl = JsonArray();
        //     // TODO: rendermode hex
        //     int addr; for (addr = 0; addr < 10; addr++)
        //     {
        //         JsonArrayInsertInplace(dl, NuiDrawListText(
        //             JSON_TRUE,
        //             NuiColor(200, 200, 200),
        //             NuiRect(60.0, REGVIEW_LINE_HEIGHT * (addr+2), 100.0, REGVIEW_LINE_HEIGHT + REGVIEW_LINE_HEIGHT * (addr+2)),
        //             NuiBind("memview")
        //         ));
        //     }

        //     mem = NuiDrawList(mem, JSON_TRUE, dl);
        // }
        // JsonArrayInsertInplace(row, mem);

        // Remaining spacer takes up all width
        JsonArrayInsertInplace(row, NuiSpacer());

        JsonArrayInsertInplace(rootCol, NuiRow(row));
    }

    JsonArrayInsertInplace(rootCol, NuiSpacer());

    float btnWidth = 150.0;
    float btnHeight = 35.0;

    {
        json row = JsonArray();
        json elems = JsonArray();

        int n = 1;
        while (1)
        {
            string r = ResManFindPrefix("8_", RESTYPE_RES, n++);
            if (r == "") break;
            JsonArrayInsertInplace(elems, NuiComboEntry(GetSubString(r, 2, 16), n));
            SetLocalString(GetModule(), "program_" + IntToString(n), r);
        }
        JsonArrayInsertInplace(row, NuiWidth(NuiCombo(elems, NuiBind("selected_program")), btnWidth));
        JsonArrayInsertInplace(row, NuiSpacer());
        JsonArrayInsertInplace(rootCol, NuiRow(row));
    }

    // action buttons
    {
        json row = JsonArray();
        JsonArrayInsertInplace(row, NuiId(NuiHeight(NuiButton(JsonString("Reset")), btnHeight), "btn_reset"));
        JsonArrayInsertInplace(row, NuiId(NuiHeight(NuiButton(JsonString("Halt")), btnHeight), "btn_halt"));
        JsonArrayInsertInplace(row, NuiId(NuiHeight(NuiButton(JsonString("Step")), btnHeight), "btn_step"));
        JsonArrayInsertInplace(row, NuiId(NuiHeight(NuiButton(JsonString("Run")), btnHeight), "btn_run"));
        JsonArrayInsertInplace(row, NuiSpacer());
        JsonArrayInsertInplace(rootCol, NuiRow(row));
    }

    json nui = NuiWindow(
        NuiCol(rootCol),
        JsonString("Title"),
        NuiRect(5.0, 5.0, 700.0, 700.0),
        JSON_FALSE,  // Resizable
        JSON_FALSE,  // Collapsed
        JSON_TRUE,   // Closable
        JSON_FALSE,  // Transparent
        JSON_TRUE    // Border
    );


    int token = NuiCreate(pc, nui, "chip8", "chip8_evt");
    ASSERT(token > 0, "no nui token after window creation");

    json regLabels = JsonArray();
    JsonArrayInsertInplace(regLabels, JsonString("V0"));
    JsonArrayInsertInplace(regLabels, JsonString("V1"));
    JsonArrayInsertInplace(regLabels, JsonString("V2"));
    JsonArrayInsertInplace(regLabels, JsonString("V3"));
    JsonArrayInsertInplace(regLabels, JsonString("V4"));
    JsonArrayInsertInplace(regLabels, JsonString("V5"));
    JsonArrayInsertInplace(regLabels, JsonString("V6"));
    JsonArrayInsertInplace(regLabels, JsonString("V7"));
    JsonArrayInsertInplace(regLabels, JsonString("V8"));
    JsonArrayInsertInplace(regLabels, JsonString("V9"));
    JsonArrayInsertInplace(regLabels, JsonString("VA"));
    JsonArrayInsertInplace(regLabels, JsonString("VB"));
    JsonArrayInsertInplace(regLabels, JsonString("VC"));
    JsonArrayInsertInplace(regLabels, JsonString("VD"));
    JsonArrayInsertInplace(regLabels, JsonString("VE"));
    JsonArrayInsertInplace(regLabels, JsonString("VF"));
    JsonArrayInsertInplace(regLabels, JsonString("SP"));
    JsonArrayInsertInplace(regLabels, JsonString("D"));
    JsonArrayInsertInplace(regLabels, JsonString("S"));
    JsonArrayInsertInplace(regLabels, JsonString("XT"));
    JsonArrayInsertInplace(regLabels, JsonString("I"));
    JsonArrayInsertInplace(regLabels, JsonString("CY"));
    JsonArrayInsertInplace(regLabels, JsonString("PC"));
    NuiSetBind(pc, token, "label_reg", regLabels);

    // json memview = JsonArray();
    // for (i = 0; i < 10; i++)
    //     JsonArrayInsertInplace(memview, JsonInt(i*1000));
    // NuiSetBind(pc, token, "memview", getMem());
    return token;
}

