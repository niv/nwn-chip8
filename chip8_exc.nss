#include "chip8_cpu"
#include "chip8_input"
#include "chip8_sprite"

// const int EXEC_RESULT_SUSPEND      = 0xFFE;
const int EXEC_RESULT_FAIL         = 0xFFF;
const int EXEC_RESULT_JMP          = 0; // Do not auto-advance PC
const int EXEC_RESULT_OK           = 2;
const int EXEC_RESULT_SKIP1        = 4;

// Returns the amount of advancement on PC. Return 0 to not change PC.
// The default of 2 refers to the two bytes each instruction takes.
int cpuExecuteInstr(int instr)
{
    TRACE("Exec instruction: " + WordToHex(instr));
    int i;

    if (instr == 0x0000)
    {
        ABORT("0x0000: no code");
        return EXEC_RESULT_FAIL;
    }

    if (instr == 0x00e0)
    {
        json disp = getDisp();
        for (i = 0; i < DISPLAY_SIZE; i++)
            JsonArraySetInplace(disp, i, JsonBool(FALSE));
        return EXEC_RESULT_OK;
    }

    if (instr == 0x00ee)
    {
        // 00EE - RET
        // Return from a subroutine.
        // The interpreter sets the program counter to the address at the top of the stack,
        // then subtracts 1 from the stack pointer.
        pcWrite(stackPop());
        return EXEC_RESULT_JMP;
    }

    switch ((instr & 0xf000) >> 12)
    {
        case 0x0:
        {
            DEBUG("Native instructions not implemented: " + WordToHex(instr));
            return EXEC_RESULT_OK;
        }
        case 0x1:
        {
            // 1nnn - JP addr
            // Jump to location nnn.
            // The interpreter sets the program counter to nnn.
            int nnn = instr & 0xfff;
            if (nnn == pcRead())
            {
                AbortRunningScript("infinite loop: deliberate program abort");
            }
            pcWrite(nnn);
            return EXEC_RESULT_JMP;
        }
        case 0x2:
        {
            // 2nnn - CALL addr
            // Call subroutine at nnn.
            // The interpreter increments the stack pointer, then puts the current PC on the top
            // of the stack. The PC is then set to nnn.
            int nnn = instr & 0xfff;
            stackPush(pcRead() + 2);
            pcWrite(nnn);
            return EXEC_RESULT_JMP;
        }
        case 0x3:
        {
            // 3xkk - SE Vx, byte
            // Skip next instruction if Vx = kk.
            // The interpreter compares register Vx to kk, and if they are equal, increments the
            // program counter by 2.
            int x  = (instr & 0xf00) >> 8;
            int kk = (instr & 0xff);
            if (regRead(x) == kk)
                return EXEC_RESULT_SKIP1;
            return EXEC_RESULT_OK;
        }
        case 0x4:
        {
            // 4xkk - SNE Vx, byte
            // Skip next instruction if Vx != kk.
            // The interpreter compares register Vx to kk, and if they are not equal, increments
            // the program counter by 2.
            int x  = (instr & 0xf00) >> 8;
            int kk = (instr & 0xff);
            if (regRead(x) != kk)
                return EXEC_RESULT_SKIP1;

            return EXEC_RESULT_OK;
        }
        case 0x5:
        {
            switch (instr & 0xf)
            {
                case 0x0:
                {
                    // 5xy0 - SE Vx, Vy
                    // Skip next instruction if Vx = Vy.
                    // The interpreter compares register Vx to register Vy, and if they are equal,
                    // increments the program counter by 2.
                    int x = (instr & 0xf00) >> 8;
                    int y = (instr & 0xf0) >> 4;
                    if (regRead(x) == regRead(y))
                        return EXEC_RESULT_SKIP1;
                    return EXEC_RESULT_OK;
                }
            }
            break;
        }
        case 0x6:
        {
            // 6xkk - LD Vx, byte
            // Set Vx = kk.
            // The interpreter puts the value kk into register Vx.
            int x  = (instr & 0xf00) >> 8;
            int kk = (instr & 0xff);
            regWrite(x, kk);
            return EXEC_RESULT_OK;
        }
        case 0x7:
        {
            // 7xkk - ADD Vx, byte
            // Set Vx = Vx + kk.
            // Adds the value kk to the value of register Vx, then stores the result in Vx.
            int x  = (instr & 0xf00) >> 8;
            int kk = (instr & 0xff);
            regWrite(x, regRead(x) + kk);
            return EXEC_RESULT_OK;
        }
        case 0x8:
        {
            int x = (instr & 0xf00) >> 8;
            int y = (instr & 0xf0) >> 4;
            switch (instr & 0xf)
            {
                case 0x0:
                {
                    // 8xy0 - LD Vx, Vy
                    // Set Vx = Vy.
                    // Stores the value of register Vy in register Vx.
                    regWrite(x, regRead(y));
                    return EXEC_RESULT_OK;
                }
                case 0x1:
                {
                    // 8xy1 - OR Vx, Vy
                    // Set Vx = Vx OR Vy.
                    // Performs a bitwise OR on the values of Vx and Vy, then stores the result in Vx.
                    // A bitwise OR compares the corrseponding bits from two values, and if either
                    // bit is 1, then the same bit in the result is also 1. Otherwise, it is 0.
                    regWrite(x, regRead(x) | regRead(y));
                    return EXEC_RESULT_OK;
                }
                case 0x2:
                {
                    // 8xy2 - AND Vx, Vy
                    // Set Vx = Vx AND Vy.
                    // Performs a bitwise AND on the values of Vx and Vy, then stores the result in Vx.
                    // A bitwise AND compares the corrseponding bits from two values, and if both
                    // bits are 1, then the same bit in the result is also 1. Otherwise, it is 0.
                    regWrite(x, regRead(x) & regRead(y));
                    return EXEC_RESULT_OK;
                }
                case 0x3:
                {
                    // 8xy3 - XOR Vx, Vy
                    // Set Vx = Vx XOR Vy.
                    // Performs a bitwise exclusive OR on the values of Vx and Vy, then stores the
                    // result in Vx. An exclusive OR compares the corrseponding bits from two values,
                    // and if the bits are not both the same, then the corresponding bit in the
                    // result is set to 1. Otherwise, it is 0.
                    regWrite(x, regRead(x) ^ regRead(y));
                    return EXEC_RESULT_OK;
                }
                case 0x4:
                {
                    // 8xy4 - ADD Vx, Vy
                    // Set Vx = Vx + Vy, set VF = carry.
                    // The values of Vx and Vy are added together. If the result is greater than
                    // 8 bits (i.e., > 255,) VF is set to 1, otherwise 0. Only the lowest 8 bits
                    // of the result are kept, and stored in Vx.
                    int val = regRead(x) + regRead(y);
                    regWrite(x, val);
                    regWrite(REG_VF, val > 255);
                    return EXEC_RESULT_OK;
                }
                case 0x5:
                {
                    // 8xy5 - SUB Vx, Vy
                    // Set Vx = Vx - Vy, set VF = NOT borrow.
                    // If Vx > Vy, then VF is set to 1, otherwise 0. Then Vy is subtracted from Vx,
                    // and the results stored in Vx.
                    int vx = regRead(x);
                    int vy = regRead(y);
                    regWrite(x, vx - vy);
                    regWrite(REG_VF, vx > vy);
                    return EXEC_RESULT_OK;
                }
                case 0x6:
                {
                    // 8xy6 - SHR Vx {, Vy}
                    // Set Vx = Vx SHR 1.
                    // If the least-significant bit of Vx is 1, then VF is set to 1, otherwise 0.
                    // Then Vx is divided by 2.
                    // TODO: why does it say Vy?
                    int val = regRead(x);
                    val = BYTE(val) >> 1;
                    val = BYTE(val) / 2;
                    regWrite(x, val);
                    regWrite(REG_VF, val & 0x1);
                    // regWrite(x, regRead(x) >> 1);
                    // regWrite(x, regRead(x) / 2);
                    return EXEC_RESULT_OK;
                }
                case 0x7:
                {
                    // 8xy7 - SUBN Vx, Vy
                    // Set Vx = Vy - Vx, set VF = NOT borrow.
                    // If Vy > Vx, then VF is set to 1, otherwise 0. Then Vx is subtracted from Vy,
                    // and the results stored in Vx.
                    // TODO: overflow handling
                    int val = regRead(y) - regRead(x);
                    regWrite(x, val);
                    regWrite(REG_VF, val < 0 || val > 255 ? 1 : 0);
                    return EXEC_RESULT_OK;
                }
                case 0xe:
                {
                    // 8xyE - SHL Vx {, Vy}
                    // Set Vx = Vx SHL 1.
                    // If the most-significant bit of Vx is 1, then VF is set to 1, otherwise to 0.
                    // Then Vx is multiplied by 2.
                    // TODO: why does it say Vy?
                    regWrite(x, regRead(x) << 1);
                    regWrite(x, regRead(x) * 2);
                    return EXEC_RESULT_OK;
                }
            }
            break;
        }
        case 0x9:
        {
            switch (instr & 0xf)
            {
                case 0x0:
                {
                    // 9xy0 - SNE Vx, Vy
                    // Skip next instruction if Vx != Vy.
                    // The values of Vx and Vy are compared, and if they are not equal, the
                    // program counter is increased by 2.
                    int x = (instr & 0xf00) >> 8;
                    int y = (instr & 0xf0) >> 4;
                    if (regRead(x) != regRead(y))
                        return EXEC_RESULT_SKIP1;
                    return EXEC_RESULT_OK;
                }
            }
            break;
        }
        case 0xa:
        {
            // Annn - LD I, addr
            // Set I = nnn.
            // The value of register I is set to nnn.
            int nnn = (instr & 0xfff);
            regWrite(REG_I, nnn);
            return EXEC_RESULT_OK;
        }
        case 0xb:
        {
            // Bnnn - JP V0, addr
            // Jump to location nnn + V0.
            // The program counter is set to nnn plus the value of V0.
            int nnn = (instr & 0xfff);
            pcWrite(nnn + regRead(REG_V0));
            return EXEC_RESULT_JMP;
        }
        case 0xd:
        {
            // Dxyn - DRW Vx, Vy, nibble
            // Display n-byte sprite starting at memory location I at (Vx, Vy), set VF = collision.
            // The interpreter reads n bytes from memory, starting at the address stored in I.
            // These bytes are then displayed as sprites on screen at coordinates (Vx, Vy).
            // Sprites are XORed onto the existing screen. If this causes any pixels to be erased,
            // VF is set to 1, otherwise it is set to 0. If the sprite is positioned so part of it
            // is outside the coordinates of the display, it wraps around to the opposite side of
            // the screen. See instruction 8xy3 for more information on XOR, and section 2.4,
            // Display, for more information on the Chip-8 screen and sprites.
            int x    = regRead((instr & 0xf00) >> 8);
            int y    = regRead((instr & 0xf0) >> 4);
            int n    = (instr & 0xf);
            int i    = regRead(REG_I);

            // TODO:
            // x = x mod DISPLAY_COLS;
            // y = y mod DISLROWS;

            regWrite(REG_VF, 0);

            int row, col;
            for (row = 0; row < n; row++)
            {
                int byte = memRead(i + row);
                // DEBUG("byte: " + ByteToHex(byte));
                for (col = 0; col < 8; col++)
                {
                    int bit = (byte & (0x80 >> col));
                    if (bit)
                    {
                        int addr = dispCoordToAddr(x + col, y + row);
                        int pixel = dispRead(addr);
                        if (pixel)
                            regWrite(REG_VF, 1);
                        pixel ^= 1;
                        dispWrite(addr, pixel);
                    }

                    if (x + col >= DISPLAY_COLS) { break; }
                }
                if (y + row >= DISPLAY_ROWS) { break; }
            }

            return EXEC_RESULT_OK;
        }
        case 0xe:
        {
            int x = (instr & 0xf00) >> 8;
            switch (instr & 0xff)
            {
                case 0x9e:
                    // Ex9E - SKP Vx
                    // Skip next instruction if key with the value of Vx is pressed.
                    // Checks the keyboard, and if the key corresponding to the value of Vx is
                    // currently in the down position, PC is increased by 2.
                    if (keypadRead(regRead(x)))
                        return EXEC_RESULT_SKIP1;
                    return EXEC_RESULT_OK;
                case 0xa1:
                    // ExA1 - SKNP Vx
                    // Skip next instruction if key with the value of Vx is not pressed.
                    // Checks the keyboard, and if the key corresponding to the value of Vx is
                    // currently in the up position, PC is increased by 2.
                    if (!keypadRead(regRead(x)))
                        return EXEC_RESULT_SKIP1;
                    return EXEC_RESULT_OK;
            }
            break;
        }
        case 0xf:
        {
            int x = (instr & 0xf00) >> 8;
            int i = regRead(i);
            switch (instr & 0xff)
            {
                case 0x07:
                {
                    // Fx07 - LD Vx, DT
                    // Set Vx = delay timer value.
                    // The value of DT is placed into Vx.
                    regWrite(x, regRead(REG_DELAY));
                    return EXEC_RESULT_OK;
                }
                case 0x0a:
                {
                    // Fx0A - LD Vx, K
                    // Wait for a key press, store the value of the key in Vx.
                    // All execution stops until a key is pressed, then the value of that key is stored in Vx.

                    // Tell the keypad to lock execution. The clock will still run
                    // but further instruction execution will not happen until the key "interrupt"
                    // is flagged.
                    keypadTrapKey(x);
                    return EXEC_RESULT_OK;
                }
                case 0x15:
                {
                    // Fx15 - LD DT, Vx
                    // Set delay timer = Vx.
                    // DT is set equal to the value of Vx.
                    regWrite(REG_DELAY, regRead(x));
                    return EXEC_RESULT_OK;
                }
                case 0x29:
                {
                    // Fx29 - LD F, Vx
                    // Set I = location of sprite for digit Vx.
                    // The value of I is set to the location for the hexadecimal sprite corresponding
                    // to the value of Vx. See section 2.4, Display, for more information on the
                    // Chip-8 hexadecimal font.
                    regWrite(REG_I, SRPITE_OFFSET + x * 5);
                    return EXEC_RESULT_OK;
                }
                case 0x1e:
                {
                    // Fx1E - ADD I, Vx
                    // Set I = I + Vx.
                    // The values of I and Vx are added, and the results are stored in I.
                    regWrite(REG_I, i + regRead(x));
                    return EXEC_RESULT_OK;
                }
                case 0x33:
                {
                    // Fx33 - LD B, Vx
                    // Store BCD representation of Vx in memory locations I, I+1, and I+2.
                    // The interpreter takes the decimal value of Vx, and places
                    // the hundreds digit in memory at location in I,
                    // the tens digit at location I+1,
                    // and the ones digit at location I+2.
                    x = regRead(x);
                    memWrite(i    , x / 100);
                    memWrite(i + 1, x / 10 % 10);
                    memWrite(i + 2, x % 100 % 10);
                    return EXEC_RESULT_OK;
                }
                case 0x55:
                {
                    // Fx55 - LD [I], Vx
                    // Store registers V0 through Vx in memory starting at location I.
                    // The interpreter copies the values of registers V0 through Vx into memory,
                    // starting at the address in I.
                    int reg; for (reg = 0; reg <= x; reg++)
                    {
                        memWrite(i + reg, regRead(reg));
                    }
                    return EXEC_RESULT_OK;
                }
                case 0x65:
                {
                    // Fx65 - LD Vx, [I]
                    // Read registers V0 through Vx from memory starting at location I.
                    // The interpreter reads values from memory starting at location I into
                    // registers V0 through Vx.
                    int reg; for (reg = 0; reg <= x; reg++)
                    {
                        regWrite(reg, memRead(i + reg));
                    }
                    return EXEC_RESULT_OK;
                }
            }
            break;
        }
    }

    return EXEC_RESULT_FAIL;
}
