#include <assert.h>
#include <stdio.h>
#include "../native/loading_policy.h"
int main(void) {
    assert(hzl_destination("-c -h 213.32.6.232 -p 7777 -n Player_Name"));
    assert(hzl_destination("\"C:\\Program Files\\gta_sa.exe\" -c -p 7777 -h 213.32.6.232 -n Player_Name"));
    assert(hzl_destination("gta_sa.exe -h \"samp.hzgaming.net\" -p \"7777\""));
    assert(hzl_destination("gta_sa.exe\t/h\t213.32.6.232\t/p\t7777"));
    const char *bad[]={"", "gta_sa.exe", "-h 213.32.6.232", "-p 7777", "-h 213.32.6.232 -p 7778",
        "-h 192.0.2.1 -p 7777", "-h samp.hzgaming.net.fake -p 7777", "-h 213.32.6.232.fake -p 7777",
        "-h 213.32.6.232 -p 7777 -h 192.0.2.1", "-h 192.0.2.1 -h 213.32.6.232 -p 7777",
        "-h 213.32.6.232 -p 7777 -p 9999", "-h 213.32.6.232 -p 07777", "-h 213.32.6.232 -p 7777junk",
        "-h \"213.32.6.232 -p 7777", "-h213.32.6.232 -p7777", "-n \"-h 213.32.6.232 -p 7777\""};
    for(unsigned i=0;i<sizeof(bad)/sizeof(*bad);i++)assert(!hzl_destination(bad[i]));
    assert(!hzl_destination(0));
    char huge[600];for(unsigned i=0;i<599;i++)huge[i]='a';huge[599]=0;
    assert(!hzl_destination(huge));
    puts("PASS startup IP/host/port selection, quotes, duplicates, unknown destinations and malformed arguments");return 0;
}
