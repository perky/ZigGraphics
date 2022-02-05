#include <stdio.h>
#include "imconfig.h"

int main()
{
    printf("hello\n");
    char buf[1024];
    ImFormatString(buf, 1024, "testing %d", 22);
    printf("%s", buf);
    return 0;
}