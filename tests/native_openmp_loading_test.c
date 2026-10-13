/* Standalone Windows fixture. No GTA process, injection or server connection. */
#include <assert.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
typedef unsigned int U32;
static void *qa_open(int,int,void *);
static int qa_find(void *,U32,void *,void *);
static void *qa_read(void *);
static int qa_close(void *,void *);
static void __attribute__((thiscall)) qa_draw(void *,const void *,const void *);
static void qa_init(void);
static void qa_stock_bar(void *);
static void qa_omp_bar(void *);
#define HZL_QA_TEST 1
static U32 qa_fingerprint;
#define EXPECTED_SPLASH_FNV qa_fingerprint
#define HZL_RW_OPEN qa_open
#define HZL_RW_FIND qa_find
#define HZL_RW_READ qa_read
#define HZL_RW_CLOSE qa_close
#define HZL_SPRITE_DRAW qa_draw
#define HZL_SPRITE_INIT qa_init
#define HZL_SAVED_BAR_CALL(pointer) qa_stock_bar(pointer)
#define HZL_OMP_BAR_CALL(pointer) qa_omp_bar(pointer)
#define GetModuleHandleA qa_module
#define GetModuleHandleExA qa_pin
#include "../native/loading.c"
extern void *WIN VirtualAlloc(void *,U32,U32,U32);
static Byte *fakeOmp,*fakeSamp,*fakeNet;
static int pins,reads,draws,fallbacks,inits;
static Byte camera[0x84],engine[0x1c];
static int centeredBars,originalBars;
static Byte savedBar[16];
static Byte dictionary[16],texture[88],raster[52];
/* Keep the fixture's unused BSS at GTA's addresses, preventing the Windows
   heap from occupying them. Its own code remains below these test pages. */
static volatile Byte qa_padding[0x1000000];
void *WIN qa_module(const char *name) {
    if(name && !strcmp(name,"omp-client.dll"))return fakeOmp;
    if(name && !strcmp(name,"samp.dll"))return fakeSamp;
    return 0;
}
int WIN qa_pin(U32 flags,const char *address,void **out) {
    assert(flags==5 && address==(const char *)fakeOmp+0x427a0);
    *out=fakeOmp;pins++;return 1;
}
static void qa_fallback(void){fallbacks++;}
static void put32(void *p,U32 v){memcpy(p,&v,4);}
static void jump(Byte *p,void *target){p[0]=0xe9;put32(p+1,(U32)target-(U32)(p+5));}
static void *qa_open(int type,int access,void *data) {
    struct {void *data;U32 size;} *memory=data;
    assert(type==3 && access==1 && memory->size==8388776);
    assert(value32(memory->data)==22);return dictionary;
}
static int qa_find(void *s,U32 type,void *a,void *b){assert(s==dictionary && type==22 && !a && !b);return 1;}
static void *qa_read(void *s){assert(s==dictionary);reads++;return dictionary;}
static int qa_close(void *s,void *unused){assert(s==dictionary && !unused);return 1;}
static void __attribute__((thiscall)) qa_draw(void *sprite,const void *rect,const void *color) {
    const float *r=rect;
    assert(*(void **)sprite==texture && value32(color)==0xffffffff);
    assert(r[0]==0 && r[1]==1080 && r[2]==1920 && r[3]==0);
    assert(value32(texture+84)==1 && inits==draws+1);
    assert(value32((void *)0xc80464)==0x40000000);draws++;
}
static void qa_init(void) {
    inits++;put32((void *)0xc80460,0x3a800000);put32((void *)0xc80464,0x40000000);
}
static void qa_stock_bar(void *p) {
    assert(p==savedBar && *(unsigned short *)0x5903ca==0x8f80 && *(unsigned short *)0x5903e8==0x8fe8);centeredBars++;
}
static void qa_omp_bar(void *p) {
    assert(p==fakeOmp+0x42620 && *(unsigned short *)0x5903ca==0x8b40 && *(unsigned short *)0x5903e8==0x8a10);originalBars++;
}
static void reset_texture(void) {
    memset(dictionary,0,sizeof(dictionary));memset(texture,0,sizeof(texture));memset(raster,0,sizeof(raster));
    put32(dictionary+8,(U32)texture+8);put32(texture,(U32)raster);
    put32(texture+4,(U32)dictionary);put32(texture+84,1);
    put32(raster+12,2048);put32(raster+16,1024);
    ompAttempted=0;ompTexture=0;
}
int main(int argc,char **argv) {
    setbuf(stdout,0);puts("fixture: setup");
    assert(argc==1);(void)argv;
    qa_padding[0]=1;assert((U32)&main>=0x400000 && (U32)&main<0x500000);
    U32 pages[]={0x580000,0x590000,0x720000,0x7e0000,0xc10000,0xc80000,0xc90000},old;
    for(int i=0;i<7;i++)assert(VirtualProtect((void *)pages[i],0x10000,0x40,&old));
    puts("fixture: pages mapped");
    fakeOmp=VirtualAlloc(0,0x219000,0x3000,0x40);assert(fakeOmp);
    printf("fixture: omp=%p\n",fakeOmp);
    put32(fakeOmp+0x3c,0x80);put32(fakeOmp+0x88,0x69430243);
    put32(fakeOmp+0xa8,0xb23e4);put32(fakeOmp+0xd0,0x219000);
    const Byte entry[]={0x53,0x8b,0xdc,0x83,0xec,0x08,0x83,0xe4,0xf0,0x83,0xc4,0x04};
    memcpy(fakeOmp+0x427a0,entry,12);
    puts("fixture: OMP metadata copied");
    const Byte draw[]={0x8b,0x44,0x24,0x08,0x56,0x50,0x50,0x50};
    const Byte open[]={0xa1,0x24,0x7b,0xc9,0x00,0x8b,0x0d,0x2c};
    memcpy((void *)0x728350,draw,8);memcpy((void *)0x7ecef0,open,8);
    const Byte init[]={0x33,0xc0,0xa3,0x5c,0x04,0xc8,0x00,0xa3,0x58,0x04,0xc8,0x00};
    memcpy((void *)0x727350,init,sizeof(init));
    put32((void *)0xc1703c,(U32)camera);put32((void *)0xc97b24,(U32)engine);
    put32(camera+0x80,0x3f000000);put32(engine+0x18,0x3a800000);
    puts("fixture: game signatures copied");
    sfModule=VirtualAlloc(0,0x1d4000,0x3000,4);assert(sfModule);
    sfModule[0x1b816]=0x39;sfModule[0x1b817]=0x0d;
    put32(sfModule+0x1b818,(U32)(sfModule+0x1295a8));
    put32(sfModule+0x1b994,(U32)(sfModule+0x1295a8));
    put32(sfModule+0x1b9fc,(U32)(sfModule+0x1295a8));
    puts("fixture: SF mapped");
    jump((Byte *)0x58ff60,qa_fallback);U32 foreign=value32((void *)0x58ff61);
    try_omp_adapter();assert(!ompHooked && value32((void *)0x58ff61)==foreign);
    puts("fixture: foreign hook retained");
    jump((Byte *)0x58ff60,fakeOmp+0x427a0);
    fakeOmp[0x427a0]=0x90;try_omp_adapter();assert(!ompHooked);fakeOmp[0x427a0]=0x53;
    put32(fakeOmp+0x88,1);try_omp_adapter();assert(!ompHooked);put32(fakeOmp+0x88,0x69430243);
    *(Byte *)0x728350=0x90;try_omp_adapter();assert(!ompHooked);*(Byte *)0x728350=0x8b;
    puts("fixture: install owned hook");
    try_omp_adapter();assert(ompHooked && ompModule==fakeOmp && pins==1);
    assert(value32(sfModule+0x1b818)==(U32)&ompStockSprite);
    assert(value32(sfModule+0x1b994)==(U32)&ompStockSprite);
    assert(value32(sfModule+0x1b9fc)==(U32)&ompStockSprite && ompStockSprite==0);
    assert(value32((void *)0x58ff61)==(U32)&omp_render-0x58ff65);
    try_omp_adapter();assert(pins==1);
    puts("fixture: artwork and rendering");jump(fakeOmp+0x427a0,qa_fallback);
    /* Synthetic header/pixels only: no game, artwork or account is required. */
    encodedLength=8388776;encoded=malloc(encodedLength);assert(encoded);
    Byte *plain=calloc(encodedLength,1);assert(plain);
    put32(plain,22);put32(plain+4,8388764);put32(plain+52,9);put32(plain+128,21);
    plain[133]=8;plain[135]=4;plain[136]=32;plain[137]=1;plain[139]=1;put32(plain+140,8388608);
    for(U32 i=0;i<encodedLength;i++)encoded[encodedLength-1-i]=plain[i]^key[31-i%32]^(i%32)^(i&255);
    free(plain);qa_fingerprint=2166136261u;
    for(U32 i=0;i<encodedLength;i++)qa_fingerprint=(qa_fingerprint^encoded[i])*16777619u;
    assert(blob_valid(encoded,encodedLength));encoded[100]^=1;assert(!blob_valid(encoded,encodedLength));encoded[100]^=1;
    put32((void *)0xc17044,1920);put32((void *)0xc17048,1080);
    reset_texture();drawCustom=0;omp_render();assert(reads==0 && draws==0 && fallbacks==1);
    fakeSamp=VirtualAlloc(0,0x27e000,0x3000,4);fakeNet=VirtualAlloc(0,4096,0x3000,4);assert(fakeSamp && fakeNet);
    put32(fakeSamp+0x3c,0x80);put32(fakeSamp+0x88,0x6372c39e);
    put32(fakeSamp+0xa8,0xcbc90);put32(fakeSamp+0xd0,0x27e000);put32(fakeSamp+0x26eb94,(U32)fakeNet);
    strcpy((char *)fakeNet+48,"192.0.2.1");put32(fakeNet+565,7777);
    drawCustom=1;omp_render();assert(reads==0 && draws==0 && fallbacks==2);
    strcpy((char *)fakeNet+48,"213.32.6.232");put32(fakeNet+973,5);
    omp_render();assert(reads==1 && draws==1 && seenConnection);
    omp_render();assert(reads==1 && draws==2 && value32(texture+84)==1);
    strcpy((char *)fakeNet+48,"192.0.2.1");omp_render();assert(draws==2 && fallbacks==3);
    fakeNet[48]=0;omp_render();assert(draws==2 && fallbacks==4);
    strcpy((char *)fakeNet+48,"213.32.6.232");put32(fakeNet+973,0);omp_render();assert(draws==2);
    put32(fakeNet+973,5);omp_render();assert(draws==3);
    reset_texture();put32(texture+84,0);omp_render();assert(draws==3 && !ompTexture);
    reset_texture();put32(raster+12,1);omp_render();assert(draws==3 && !ompTexture);
    reset_texture();put32(texture+4,0);omp_render();assert(draws==3 && !ompTexture);
    reset_texture();put32(dictionary+8,(U32)dictionary+8);omp_render();assert(draws==3 && !ompTexture);
    reset_texture();omp_render();assert(draws==4);
    put32(camera+0x80,0);omp_render();assert(draws==4 && inits==4);
    put32(camera+0x80,0x7f800000);omp_render();assert(draws==4 && inits==4);
    put32(camera+0x80,0x3f000000);
    const Byte barCode[]={0x55,0x8b,0xec,0xa1};memcpy(fakeOmp+0x42620,barCode,4);
    put32(fakeOmp+0x42624,(U32)(fakeOmp+0x1bc4a4));
    const Byte barPrologue[]={0x83,0xec,0x10,0x56,0x57};memcpy(savedBar,barPrologue,5);
    jump(savedBar+5,(void *)0x590375);put32(fakeOmp+0x1d16f8,(U32)savedBar);
    const Byte barX[]={0xd9,0x05,0x40,0x8b,0x85,0};const Byte barY[]={0xd8,0x0d,0x10,0x8a,0x85,0};
    memcpy((void *)0x5903c8,barX,6);memcpy((void *)0x5903e6,barY,6);
    jump((Byte *)0x590370,qa_fallback);U32 otherBar=value32((void *)0x590371);
    try_omp_bar_adapter();assert(!ompBarHooked && value32((void *)0x590371)==otherBar);
    jump((Byte *)0x590370,fakeOmp+0x42620);savedBar[0]=0x90;
    try_omp_bar_adapter();assert(!ompBarHooked);savedBar[0]=0x83;
    try_omp_bar_adapter();assert(ompBarHooked && ompBarOriginal==savedBar);
    assert(value32((void *)0x590371)==(U32)&omp_render_bar-0x590375);
    omp_render_bar();assert(centeredBars==1 && originalBars==0);
    strcpy((char *)fakeNet+48,"192.0.2.1");omp_render_bar();assert(centeredBars==1 && originalBars==1);
    fakeNet[48]=0;omp_render_bar();assert(centeredBars==1 && originalBars==2);
    strcpy((char *)fakeNet+48,"213.32.6.232");omp_render_bar();assert(centeredBars==2);
    *(unsigned short *)0x5903ca=0x1234;assert(!omp_bar_position(1) && *(unsigned short *)0x5903ca==0x1234);
    puts("fixture: restore and stale ownership");omp_sf_passthrough(0);assert(value32(sfModule+0x1b994)==(U32)(sfModule+0x1295a8));
    put32(sfModule+0x1b9fc,1234);assert(!omp_sf_passthrough(1));
    assert(value32(sfModule+0x1b818)==(U32)(sfModule+0x1295a8));
    puts("PASS exact hook ownership/version/signatures, render ABI, decoded texture ownership, corruption, foreign/unknown/disconnected fallback and HZ reactivation");
    return 0;
}
