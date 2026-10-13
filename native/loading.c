/* Early HZ-only splash adapter. Existing ASI loader loads this minimal gate;
   other/unknown launches do not start its worker, read artwork or patch code.
   Original implementation, MIT, LuaHZ contributors. No plugin code copied. */
#include "loading_policy.h"
typedef unsigned char Byte;
typedef unsigned int U32;
#define WIN __attribute__((stdcall))
/* Host GCC emits ELF assembly for the freestanding MinGW pipeline. Windows
   clang uses natural stdcall names; its no-CRT link needs these two roots. */
#if defined(HZL_QA_TEST) || (defined(__clang__) && defined(_WIN32))
#define WIN_LINK(name)
#if !defined(HZL_QA_TEST)
unsigned _tls_index; int _fltused;
#endif
#else
#define WIN_LINK(name) __asm__(name)
#endif
extern char *WIN GetCommandLineA(void) WIN_LINK("\"_GetCommandLineA@0\"");
extern void *WIN GetModuleHandleA(const char *) WIN_LINK("\"_GetModuleHandleA@4\"");
extern int WIN GetModuleHandleExA(U32,const char *,void **) WIN_LINK("\"_GetModuleHandleExA@12\"");
extern U32 WIN GetModuleFileNameA(void *,char *,U32) WIN_LINK("\"_GetModuleFileNameA@12\"");
extern U32 WIN VirtualQuery(const void *,void *,U32) WIN_LINK("\"_VirtualQuery@12\"");
extern int WIN VirtualProtect(void *,U32,U32,U32 *) WIN_LINK("\"_VirtualProtect@16\"");
extern void *WIN GetCurrentProcess(void) WIN_LINK("\"_GetCurrentProcess@0\"");
extern int WIN FlushInstructionCache(void *,const void *,U32) WIN_LINK("\"_FlushInstructionCache@12\"");
extern void *WIN CreateThread(void *,U32,U32 (WIN *)(void *),void *,U32,U32 *) WIN_LINK("\"_CreateThread@24\"");
extern void WIN Sleep(U32) WIN_LINK("\"_Sleep@4\"");
extern U32 WIN GetTickCount(void) WIN_LINK("\"_GetTickCount@0\"");
extern void *WIN CreateFileA(const char *,U32,U32,void *,U32,U32,void *) WIN_LINK("\"_CreateFileA@28\"");
extern U32 WIN GetFileSize(void *,void *) WIN_LINK("\"_GetFileSize@8\"");
extern int WIN ReadFile(void *,void *,U32,U32 *,void *) WIN_LINK("\"_ReadFile@20\"");
extern int WIN WriteFile(void *,const void *,U32,U32 *,void *) WIN_LINK("\"_WriteFile@20\"");
extern int WIN CloseHandle(void *) WIN_LINK("\"_CloseHandle@4\"");
extern void *WIN GetProcessHeap(void) WIN_LINK("\"_GetProcessHeap@0\"");
extern void *WIN HeapAlloc(void *,U32,U32) WIN_LINK("\"_HeapAlloc@12\"");
extern int WIN HeapFree(void *,U32,void *) WIN_LINK("\"_HeapFree@12\"");
typedef struct {void *base,*allocation;U32 allocationProtect,bytes,state,protect,type;} MemoryInfo;
static const Byte key[32]={0xd1,0x33,0x48,0x4a,0xb6,0x89,0x7c,0x55,0xe0,0x68,0x04,0x83,0x3f,0xd1,0x78,0x60,0x3d,0x57,0xa8,0xcb,0x4e,0x6b,0xd2,0x58,0xc9,0xdd,0x18,0xf2,0xf6,0xa0,0x30,0xc5};
static void *ownModule,*logFile;
static Byte *sfModule,*encoded;
static U32 encodedLength;
static volatile int drawCustom,squareOverride=1,hooked,getterSeen,seenConnection,geometryReady;
static char directory[260];
static volatile int ompHooked;
#ifndef EXPECTED_SPLASH_FNV
#error Build with the verified encoded artwork fingerprint
#endif
static U32 value32(const void *p){U32 v=0;const Byte *s=p;Byte *d=(Byte *)&v;for(int i=0;i<4;i++)d[i]=s[i];return v;}
static int same(const void *a,const void *b,U32 n){const Byte *x=a,*y=b;while(n--)if(*x++!=*y++)return 0;return 1;}
static int readable(const void *p,U32 n) {
    MemoryInfo info;
    return p && n && (U32)p+n>=(U32)p && VirtualQuery(p,&info,sizeof(info))==sizeof(info)
        && info.state==0x1000 && !(info.protect&0x101) && (U32)p+n<=(U32)info.base+info.bytes;
}
static int filename(char *out,const char *suffix) {
    U32 i=0,j=0;while(directory[i] && i<259){out[i]=directory[i];i++;}
    while(suffix[j] && i<259)out[i++]=suffix[j++];
    out[i]=0;return suffix[j]==0;
}
static void log_text(const char *text) {
    U32 n=0,w;
    if(!logFile || logFile==(void *)-1)return;
    while(text[n])n++;
    WriteFile(logFile,text,n,&w,0);
}
static int supported_sf(Byte *module) {
    U32 pe;
    static const Byte call[]={0xe8,0x85,0x83,0x01,0x00};
    if(!readable(module,0x100))return 0;
    pe=value32(module+0x3c);
    return pe<0x1000 && readable(module+pe,0x80)
        && value32(module+pe+8)==0x67239d39 && value32(module+pe+24+16)==0x92ff0
        && value32(module+pe+24+56)==0x1d4000
        && readable(module+0x1b82f,5) && same(module+0x1b82f,call,5)
        && readable(module+0xddeac,32) && same(module+0xddeac,key,32)
        && readable(module+0x1b992,7) && module[0x1b992]==0x83 && module[0x1b993]==0x3d
        && value32(module+0x1b994)==(U32)(module+0x1295a8) && module[0x1b998]==0
        && module[0x1b99c]==0x74 && module[0x1b99d]==0x55
        && readable(module+0x1b9fa,7) && module[0x1b9fa]==0x83 && module[0x1b9fb]==0x3d
        && value32(module+0x1b9fc)==(U32)(module+0x1295a8) && module[0x1ba00]==0;
}
static int supported_game(void) {
    static const Byte x[]={0xd9,0x05,0x40,0x8b,0x85,0x00},y[]={0xd8,0x0d,0x10,0x8a,0x85,0x00};
    return GetModuleHandleA(0)==(void *)0x400000 && readable((void *)0x5903c8,6)
        && same((void *)0x5903c8,x,6) && readable((void *)0x5903e6,6) && same((void *)0x5903e6,y,6)
        && readable((void *)0x858f80,4) && value32((void *)0x858f80)==0x43660000
        && readable((void *)0x858fe8,4) && value32((void *)0x858fe8)==0x41c80000;
}
static int supported_samp(Byte *module) {
    U32 pe;
    if(!readable(module,0x100))return -1;
    pe=value32(module+0x3c);
    if(pe>0x1000 || !readable(module+pe,0x80)
       || value32(module+pe+8)!=0x6372c39e || value32(module+pe+24+16)!=0xcbc90
       || value32(module+pe+24+56)!=0x27e000)return 0;
    return 1;
}
static int native_destination(void) {
    Byte *module=GetModuleHandleA("samp.dll"),*net;U32 state;
    if(supported_samp(module)!=1 || !readable(module+0x26eb94,4))return -1;
    net=*(Byte **)(module+0x26eb94);if(!readable(net,0x3e2))return -1;
    if(!net[48] || !value32(net+565))return -1;
    if(!same(net+48,"213.32.6.232",13) || value32(net+565)!=7777)return 0;
    state=value32(net+973);if(state==5)seenConnection=1;
    return !seenConnection || state==1 || state==5 || state==6 || state==11;
}
static int blob_valid(const Byte *data,U32 length) {
    U32 hash=2166136261u;Byte header[144];
    if(length!=8388776)return 0;
    for(U32 i=0;i<length;i++)hash=(hash^data[i])*16777619u;
    if(hash!=EXPECTED_SPLASH_FNV)return 0;
    for(U32 i=0;i<144;i++)header[i]=data[length-1-i]^key[31-i%32]^(i%32)^(i&255);
    return value32(header)==22 && value32(header+4)==8388764 && value32(header+52)==9
        && value32(header+128)==21 && header[132]==0 && header[133]==8 && header[134]==0 && header[135]==4
        && header[136]==32 && header[137]==1 && header[139]==1 && value32(header+140)==8388608;
}
static int load_artwork(void) {
    char path[260];void *file;U32 got;
    if(!filename(path,"\\moonloader\\resource\\horizonbase\\loading-v0233\\loading.enc"))return 0;
    file=CreateFileA(path,0x80000000,1,0,3,0x80,0);if(file==(void *)-1)return 0;
    encodedLength=GetFileSize(file,0);
    if(encodedLength!=8388776){CloseHandle(file);return 0;}
    encoded=HeapAlloc(GetProcessHeap(),0,encodedLength);if(!encoded){CloseHandle(file);return 0;}
    if(!ReadFile(file,encoded,encodedLength,&got,0) || got!=encodedLength){CloseHandle(file);return 0;}
    CloseHandle(file);
    return blob_valid(encoded,encodedLength);
}
static int patch32(void *address,U32 expected,U32 replacement) {
    U32 oldProtect,ignored;
    if(!readable(address,4) || value32(address)!=expected || !VirtualProtect(address,4,0x40,&oldProtect))return 0;
    *(volatile U32 *)address=replacement;
    FlushInstructionCache(GetCurrentProcess(),address,4);VirtualProtect(address,4,oldProtect,&ignored);return 1;
}
static void bar_position(int custom) {
    U32 oldProtect,ignored;
    unsigned short x=custom?0x8f80:0x8b40,y=custom?0x8fe8:0x8a10;
    if(VirtualProtect((void *)0x5903ca,2,0x40,&oldProtect)) {
        *(volatile unsigned short *)0x5903ca=x;
        FlushInstructionCache(GetCurrentProcess(),(void *)0x5903ca,2);VirtualProtect((void *)0x5903ca,2,oldProtect,&ignored);
    }
    if(VirtualProtect((void *)0x5903e8,2,0x40,&oldProtect)) {
        *(volatile unsigned short *)0x5903e8=y;
        FlushInstructionCache(GetCurrentProcess(),(void *)0x5903e8,2);VirtualProtect((void *)0x5903e8,2,oldProtect,&ignored);
    }
}
static int fallback(Byte **out,U32 *size) {
    int result;void *getter=sfModule+0x33bb9;
    __asm__ volatile("pushl %[size]\n\tmovl %[out], %%edx\n\tcall *%[getter]\n\taddl $4, %%esp"
        : "=&a"(result):[getter]"r"(getter),[out]"r"(out),[size]"r"(size):"ecx","edx","memory","cc");
    return result;
}
/* Called through the exact SF EDX + one caller-cleaned stack-argument ABI. */
int hzl_getter(Byte **out,U32 *size) {
    if(!sfModule || !encoded){*out=0;*size=0;return 0;}
    if(ompHooked)return fallback(out,size);
    int destination=native_destination();
    if(destination==0 || (destination<0 && seenConnection)){drawCustom=0;squareOverride=1;return fallback(out,size);}
    /* Apply the two draw decisions on the rendering thread, before this first
       resource is decoded/cached. Redirecting the getter first avoids racing
       a stock resource into SF's one-time splash cache. */
    if(!geometryReady) {
        if(!patch32(sfModule+0x1b994,(U32)(sfModule+0x1295a8),(U32)&squareOverride))return fallback(out,size);
        if(!patch32(sfModule+0x1b9fc,(U32)(sfModule+0x1295a8),(U32)&drawCustom)) {
            patch32(sfModule+0x1b994,(U32)&squareOverride,(U32)(sfModule+0x1295a8));return fallback(out,size);
        }
        geometryReady=1;
    }
    bar_position(1);
    if(!getterSeen){getterSeen=1;log_text("Approved uncompressed HZ splash supplied to native loader.\r\n");}
    *out=encoded;*size=encodedLength;return (int)encoded;
}
__attribute__((naked)) void hzl_bridge(void) {
    __asm__ volatile("pushl 4(%esp)\n\tpushl %edx\n\tcall _hzl_getter\n\taddl $8, %esp\n\tret");
}

/* Local QA candidate: exact open.mp build 6 splash renderer; classic path unchanged. */
static Byte *ompModule;
static void *ompDictionary,*ompTexture;
static Byte *ompBarOriginal;
static int ompBarHooked,ompBarCustom,ompBarProbe;
static int ompAttempted,ompDrawn,ompStockSprite=0;
static void omp_log_value(const char *label,U32 value) {
    static const char digits[]="0123456789abcdef";char number[11];
    for(int i=0;i<8;i++)number[i]=digits[(value>>(28-4*i))&15];
    number[8]='\r';number[9]='\n';number[10]=0;log_text(label);log_text(number);
}
static int omp_sf_passthrough(int install) {
    U32 offsets[]={0x1b818,0x1b994,0x1b9fc};U32 original=(U32)(sfModule+0x1295a8),replacement=(U32)&ompStockSprite;
    if(!sfModule)return 0;
    if(install) {
        if(!readable(sfModule+0x1b816,6) || sfModule[0x1b816]!=0x39 || sfModule[0x1b817]!=0x0d)return 0;
        for(int i=0;i<3;i++)if(!readable(sfModule+offsets[i],4) || value32(sfModule+offsets[i])!=original)return 0;
        for(int i=0;i<3;i++)if(!patch32(sfModule+offsets[i],original,replacement)) {
            while(i--)patch32(sfModule+offsets[i],replacement,original);return 0;
        }
        log_text("SAMPFUNCS splash substitutions bypassed for the verified open.mp renderer.\r\n");return 1;
    }
    for(int i=0;i<3;i++)patch32(sfModule+offsets[i],replacement,original);
    return 1;
}
/* RenderWare entry points verified against the installed 1.0 US executable. */
#ifndef HZL_RW_OPEN
#define HZL_RW_OPEN ((void *(*)(int,int,void *))0x7ecef0)
#define HZL_RW_FIND ((int (*)(void *,U32,void *,void *))0x7ed2d0)
#define HZL_RW_READ ((void *(*)(void *))0x804c30)
#define HZL_RW_CLOSE ((int (*)(void *,void *))0x7ece20)
#define HZL_SPRITE_DRAW ((void (__attribute__((thiscall)) *)(void *,const void *,const void *))0x728350)
#define HZL_SPRITE_INIT ((void (*)(void))0x727350)
#endif
static int omp_functions_valid(void) {
    static const Byte draw[]={0x8b,0x44,0x24,0x08,0x56,0x50,0x50,0x50};
    static const Byte open[]={0xa1,0x24,0x7b,0xc9,0x00,0x8b,0x0d,0x2c};
    static const Byte init[]={0x33,0xc0,0xa3,0x5c,0x04,0xc8,0x00,0xa3,0x58,0x04,0xc8,0x00};
    return readable((void *)0x728350,8) && same((void *)0x728350,draw,8)
        && readable((void *)0x7ecef0,8) && same((void *)0x7ecef0,open,8)
        && readable((void *)0x727350,sizeof(init)) && same((void *)0x727350,init,sizeof(init));
}
static int omp_camera_ready(void) {
    Byte *camera,*engine;U32 clip;
    if(!readable((void *)0xc1703c,4) || !readable((void *)0xc97b24,4))return 0;
    camera=*(Byte **)0xc1703c;engine=*(Byte **)0xc97b24;
    if(!readable(camera,0x84) || !readable(engine,0x1c))return 0;
    clip=value32(camera+0x80);
    return clip>=0x00800000 && clip<0x7f800000 && value32(engine+0x18)<0x7f800000;
}
static int supported_omp(Byte *module) {
    static const Byte entry[]={0x53,0x8b,0xdc,0x83,0xec,0x08,0x83,0xe4,0xf0,0x83,0xc4,0x04};
    U32 pe;
    if(!readable(module,0x100))return 0;
    pe=value32(module+0x3c);
    return pe<0x1000 && readable(module+pe,0x80)
        && value32(module+pe+8)==0x69430243 && value32(module+pe+24+16)==0xb23e4
        && value32(module+pe+24+56)==0x219000 && readable(module+0x427a0,sizeof(entry))
        && same(module+0x427a0,entry,sizeof(entry));
}
static int omp_bar_position(int custom) {
    unsigned short x,y;
    if(!readable((void *)0x5903c8,6) || !readable((void *)0x5903e6,6)
       || *(Byte *)0x5903c8!=0xd9 || *(Byte *)0x5903c9!=5
       || *(Byte *)0x5903e6!=0xd8 || *(Byte *)0x5903e7!=0x0d)return 0;
    x=*(unsigned short *)0x5903ca;y=*(unsigned short *)0x5903e8;
    if((x!=0x8b40 && x!=0x8f80) || (y!=0x8a10 && y!=0x8fe8)
       || *(unsigned short *)0x5903cc!=0x85 || *(unsigned short *)0x5903ea!=0x85)return 0;
    bar_position(custom);ompBarCustom=custom;return 1;
}
#ifndef HZL_SAVED_BAR_CALL
#define HZL_SAVED_BAR_CALL(pointer) ((void (*)(void))(pointer))()
#define HZL_OMP_BAR_CALL(pointer) ((void (*)(void))(pointer))()
#endif
static void omp_render_bar(void) {
    int destination=native_destination();
    int custom=drawCustom && (destination>0 || (destination<0 && !seenConnection));
    if(custom && ompBarOriginal && omp_bar_position(1)) {
        HZL_SAVED_BAR_CALL(ompBarOriginal);return;
    }
    if(ompBarCustom)omp_bar_position(0);
    if(ompModule)HZL_OMP_BAR_CALL(ompModule+0x42620);
}
static int omp_patch_jump(void *address,U32 expected,U32 replacement) {
    U32 old,ignored,observed=expected;
    if(!readable(address,4) || value32(address)!=expected || !VirtualProtect(address,4,0x40,&old))return 0;
    __asm__ volatile("lock cmpxchgl %2,(%1)" : "+a"(observed)
        : "r"(address),"r"(replacement) : "memory","cc");
    FlushInstructionCache(GetCurrentProcess(),address,4);VirtualProtect(address,4,old,&ignored);
    return observed==expected;
}
static void try_omp_bar_adapter(void) {
    Byte *original;U32 expected;
    static const Byte prologue[]={0x83,0xec,0x10,0x56,0x57};
    if(!ompHooked || ompBarHooked || !ompModule || !readable(ompModule+0x42620,8)
       || ompModule[0x42620]!=0x55 || ompModule[0x42621]!=0x8b || ompModule[0x42622]!=0xec
       || ompModule[0x42623]!=0xa1 || value32(ompModule+0x42624)!=(U32)(ompModule+0x1bc4a4)
       || !readable((void *)0x590370,5) || *(Byte *)0x590370!=0xe9
       || !readable(ompModule+0x1d16f8,4))return;
    expected=(U32)(ompModule+0x42620)-0x590375;
    if(value32((void *)0x590371)!=expected)return;
    original=*(Byte **)(ompModule+0x1d16f8);
    if(!ompBarProbe && readable(original,12)) {
        ompBarProbe=1;
        omp_log_value("Saved loading-bar route first bytes=",value32(original));
        omp_log_value("Saved loading-bar route next bytes=",value32(original+4));
        omp_log_value("Saved loading-bar route final bytes=",value32(original+8));
    }
    if(!readable(original,10) || !same(original,prologue,5) || original[5]!=0xe9
       || (U32)(original+10)+value32(original+6)!=0x590375)return;
    ompBarOriginal=original;
    if(omp_patch_jump((void *)0x590371,expected,(U32)&omp_render_bar-0x590375)) {
        ompBarHooked=1;log_text("Verified centered LuaHZ loading bar installed for HZ; open.mp bar retained for other endpoints.\r\n");
    } else ompBarOriginal=0;
}
static int omp_load_texture(void) {
    Byte *plain,*texture,*raster;void *stream,*link;U32 i,refs;
    struct {void *data;U32 bytes;} memory;
    if(ompAttempted)return ompTexture!=0;
    ompAttempted=1;
    if(!encoded || !blob_valid(encoded,encodedLength))return 0;
    plain=HeapAlloc(GetProcessHeap(),0,encodedLength);if(!plain)return 0;
    for(i=0;i<encodedLength;i++)plain[i]=encoded[encodedLength-1-i]^key[31-i%32]^(i%32)^(i&255);
    memory.data=plain;memory.bytes=encodedLength;
    stream=HZL_RW_OPEN(3,1,&memory);
    if(stream) {
        if(HZL_RW_FIND(stream,22,0,0))ompDictionary=HZL_RW_READ(stream);
        HZL_RW_CLOSE(stream,0);
    }
    HeapFree(GetProcessHeap(),0,plain);
    if(!readable(ompDictionary,16))return 0;
    link=*(void **)((Byte *)ompDictionary+8);
    if((U32)link<8 || link==(Byte *)ompDictionary+8 || !readable((Byte *)link-8,88))return 0;
    texture=(Byte *)link-8;raster=*(Byte **)texture;refs=value32(texture+84);
    if(!readable(raster,52) || refs==0 || refs>=100000
       || *(void **)(texture+4)!=ompDictionary
       || value32(raster+12)!=2048 || value32(raster+16)!=1024)return 0;
    /* The private dictionary owns its texture for process lifetime. Draw only
       borrows it; no stock/open.mp sprite or texture reference is replaced. */
    ompTexture=texture;
    log_text("Approved HZ artwork decoded for the open.mp renderer.\r\n");return 1;
}
static void omp_render(void) {
    int destination=native_destination();U32 width,height;
    if(ompModule && drawCustom && (destination>0 || (destination<0 && !seenConnection))
       && readable((void *)0xc17044,8) && omp_camera_ready() && omp_load_texture()) {
        width=value32((void *)0xc17044);height=value32((void *)0xc17048);
        if(width>=320 && width<=16384 && height>=200 && height<=16384) {
            struct {float left,bottom,right,top;} rect={0,(float)height,(float)width,0};
            U32 color=0xffffffff;struct {void *texture;} sprite={ompTexture};
            /* Match the first call in GTA's original RenderSplash. It sets
               the screen-space depth and reciprocal near clip for vertices. */
            if(!ompDrawn) {
                omp_log_value("Sprite depth before initialization=",value32((void *)0xc80460));
                omp_log_value("Sprite reciprocal clip before initialization=",value32((void *)0xc80464));
            }
            HZL_SPRITE_INIT();
            HZL_SPRITE_DRAW(&sprite,&rect,&color);
            if(!ompDrawn) {
                ompDrawn=1;
                omp_log_value("Sprite depth after initialization=",value32((void *)0xc80460));
                omp_log_value("Sprite reciprocal clip after initialization=",value32((void *)0xc80464));
                log_text("LuaHZ splash draw submitted after GTA sprite initialization.\r\n");
            }
            return;
        }
    }
    if(ompModule)((void (*)(void))(ompModule+0x427a0))();
}
static void try_omp_adapter(void) {
    Byte *module=GetModuleHandleA("omp-client.dll");U32 expected,oldProtect,ignored,observed;void *pin=0;
    if(ompHooked || !supported_omp(module) || !omp_functions_valid() || !readable((void *)0x58ff60,5)
       || *(Byte *)0x58ff60!=0xe9)return;
    expected=(U32)(module+0x427a0)-0x58ff65;
    if(value32((void *)0x58ff61)!=expected)return;
    if(!GetModuleHandleExA(5,(const char *)(module+0x427a0),&pin)
       || !VirtualProtect((void *)0x58ff61,4,0x40,&oldProtect))return;
    if(!omp_sf_passthrough(1)) {
        VirtualProtect((void *)0x58ff61,4,oldProtect,&ignored);return;
    }
    ompModule=module;
    /* This four-byte operand lies within one cache line. A locked compare /
       exchange publishes the complete displacement and verifies ownership. */
    observed=expected;
    __asm__ volatile("lock cmpxchgl %2,(%1)" : "+a"(observed)
        : "r"((void *)0x58ff61),"r"((U32)&omp_render-0x58ff65) : "memory","cc");
    FlushInstructionCache(GetCurrentProcess(),(void *)0x58ff61,4);
    VirtualProtect((void *)0x58ff61,4,oldProtect,&ignored);
    if(observed==expected) {
        ompHooked=1;log_text("Verified open.mp HZ splash adapter installed; original renderer retained for other endpoints.\r\n");
    } else {ompModule=0;omp_sf_passthrough(0);}
}

static U32 WIN worker(void *unused) {
    U32 start=GetTickCount();Byte *module;void *pin=0;char path[260];(void)unused;
    GetModuleHandleExA(5,(const char *)&worker,&pin); /* Pin callback code for process lifetime. */
    if(filename(path,"\\moonloader\\config\\luahz-loading.log"))logFile=CreateFileA(path,0x40000000,3,0,2,0x80,0);
    if(!load_artwork()){log_text("HZ artwork validation failed; original splash retained.\r\n");return 0;}
    for(;;) {
        module=GetModuleHandleA("SAMPFUNCS.asi");
        if(supported_sf(module) && supported_game() && supported_samp(GetModuleHandleA("samp.dll"))==1)break;
        if(GetTickCount()-start>15000){log_text("Supported native loading hooks not ready; original splash retained.\r\n");return 0;}
        Sleep(2);
    }
    sfModule=module;drawCustom=1;squareOverride=0;
    if(!patch32(module+0x1b830,0x18385,(U32)&hzl_bridge-(U32)(module+0x1b834))) {
        log_text("Native resource call changed; original splash retained.\r\n");return 0;
    }
    hooked=1;log_text("HZ-only startup splash hook installed; original binaries remain on disk.\r\n");
    for(;;) {
        try_omp_adapter();
        try_omp_bar_adapter();
        int destination=native_destination();
        int allowed=destination<0?!seenConnection:destination;
        if(drawCustom!=allowed){drawCustom=allowed;squareOverride=!allowed;if(geometryReady)bar_position(allowed);}
        Sleep(20);
    }
    return 0;
}
/* Pure exports are exercised by the standalone Wine policy/ABI probe. */
int HZL_Destination(const char *command){return hzl_destination(command);}
int HZL_Status(void){return hooked?(drawCustom?2:1):0;}
int HZL_ValidateEncoded(const Byte *data,U32 length){return readable(data,length) && blob_valid(data,length);}
int WIN DllMain(void *module,U32 reason,void *reserved) WIN_LINK("\"_DllMain@12\"");
int WIN DllMain(void *module,U32 reason,void *reserved) {
    U32 n,i;void *thread;(void)reserved;
    if(reason!=1 || !hzl_destination(GetCommandLineA()))return 1;
    ownModule=module;n=GetModuleFileNameA(ownModule,directory,sizeof(directory));
    if(!n || n>=sizeof(directory))return 1;
    for(i=n;i>0;i--)if(directory[i-1]=='\\' || directory[i-1]=='/'){directory[i-1]=0;break;}
    if(!i)return 1;
    thread=CreateThread(0,0,worker,0,0,0);if(thread)CloseHandle(thread);return 1;
}
