void ABORT(string msg) { AbortRunningScript("ABORT: " + msg); }
void TRACE(string msg) { SendMessageToPC(GetFirstPC(), msg); }
void DEBUG(string msg) { SendMessageToPC(GetFirstPC(), msg); }
void ERROR(string msg) { ABORT(msg); }
void ASSERT(int cond, string msg) { if (!cond) ERROR("ASSERT failed: " + msg); }
void SANITY(int cond, string msg) { if (!cond) ERROR("Sanity check failed failed: " + msg); }

// Converts a encoded 0x00000000 hex number to an integer for bitwise operations
// Very useful if used on a 2da field
// * sString - String to convert
int HexStringToInt(string sString)
{
    sString = GetStringLowerCase(sString);
    int nResult = 0;
    int nLength = GetStringLength(sString);
    int i;
    for (i = nLength - 1; i >= 0; i--) {
        int n = FindSubString("0123456789abcdef", GetSubString(sString, i, 1));
        if (n == -1)
            return nResult;
        nResult |= n << ((nLength - i -1) * 4);
    }
    return nResult;
}

string NibbleToHex(int i)
{
    return GetSubString(IntToHexString(i), 9, 1);
}

string ByteToHex(int i)
{
    return GetSubString(IntToHexString(i), 8, 2);
}

string AddrToHex(int i)
{
    return GetSubString(IntToHexString(i), 7, 3);
}

string WordToHex(int i)
{
    return GetSubString(IntToHexString(i), 6, 4);
}
