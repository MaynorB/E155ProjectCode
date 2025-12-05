#include "ff.h"
#include <stdint.h>

/* --------------------------------------------------------------------
 * FatFS user-supplied time function.
 * Returns a packed DWORD timestamp for file creation/modification.
 * 
 * Bit layout:
 * [31:25] Year since 1980 (0..127)
 * [24:21] Month (1..12)
 * [20:16] Day (1..31)
 * [15:11] Hour (0..23)
 * [10:5]  Minute (0..59)
 * [4:0]   Second / 2 (0..29)
 * -------------------------------------------------------------------- */
DWORD get_fattime(void)
{
    DWORD year = 2025 - 1980;  // Example: year 2025
    DWORD month = 11;          // November
    DWORD day = 12;            // 12th
    DWORD hour = 12;           // Noon
    DWORD min = 0;
    DWORD sec = 0;

    return (year << 25)
         | (month << 21)
         | (day << 16)
         | (hour << 11)
         | (min << 5)
         | (sec >> 1);
}
