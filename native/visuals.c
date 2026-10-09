/* Native GTA 1.0 US / SA-MP 0.3.7 R5 texture adapter.
   Loaded by LuaJIT only after the HZ gate; never an auto-loaded ASI.
   Original implementation, MIT, LuaHZ contributors. Addresses/layout facts:
   plugin-sdk RenderWare.cpp, gta-reversed Font.h/Radar.h/TxdStore.h,
   SAMP-API.lua v037r5/CNetGame.lua. See docs/NATIVE_VISUAL_ISOLATION_PLAN.md. */
#include "visual_policy.h"
#define WIN __attribute__((stdcall))
extern void *WIN GetModuleHandleA(const char *) __asm__("\"_GetModuleHandleA@4\"");
extern HzU32 WIN VirtualQuery(const void *,void *,HzU32) __asm__("\"_VirtualQuery@12\"");
extern void *WIN CreateFileA(const char *,HzU32,HzU32,void *,HzU32,HzU32,void *) __asm__("\"_CreateFileA@28\"");
extern HzU32 WIN GetFileSize(void *,void *) __asm__("\"_GetFileSize@8\"");
extern int WIN ReadFile(void *,void *,HzU32,HzU32 *,void *) __asm__("\"_ReadFile@20\"");
extern int WIN CloseHandle(void *) __asm__("\"_CloseHandle@4\"");
extern void *WIN GetProcessHeap(void) __asm__("\"_GetProcessHeap@0\"");
extern void *WIN HeapAlloc(void *,HzU32,HzU32) __asm__("\"_HeapAlloc@12\"");
extern int WIN HeapFree(void *,HzU32,void *) __asm__("\"_HeapFree@12\"");
typedef struct {void *base,*allocation;HzU32 allocationProtect,bytes,state,protect,type;} MemoryInfo;
typedef struct {void *data;HzU32 bytes;} StreamMemory;
typedef struct {void *dict;unsigned short refs;short parent;HzU32 hash;} TxdDef;
typedef struct {TxdDef *objects;HzByte *flags;int count;} TxdPool;
_Static_assert(sizeof(HzTexture)==88,"32-bit RenderWare texture layout required");
_Static_assert(sizeof(TxdDef)==12,"TXD pool layout required");
static void *fontDict,*iconDict,*overviewDict,*tileDict[144];
static HzSlot fonts[2],icons[64];
static HzRaster tiles[144],overview;
static HzByte originalWidths[420],replacementWidths[420];
static int widthsActive,initialized,requested,step,errorCode,loadedTiles;
static char assetRoot[260];

static int readable(const void *p,HzU32 n) {
    MemoryInfo info;
    if(!p || !n || (HzU32)p+n<(HzU32)p)return 0;
    if(VirtualQuery(p,&info,sizeof(info))!=sizeof(info))return 0;
    return info.state==0x1000 && !(info.protect&0x101)
        && (HzU32)p+n<=(HzU32)info.base+info.bytes;
}
static HzU32 value32(const void *p) {HzU32 v=0;hz_copy(&v,p,4);return v;}
static int supported_game(void) {
    static const HzByte findSignature[]={0x8b,0x44,0x24,0x04,0x53,0x83,0xc0,0x08};
    static const HzByte readSignature[]={0x83,0xec,0x18,0x8d,0x44,0x24,0x08};
    return GetModuleHandleA(0)==(void *)0x400000
        && readable((void *)0x7f39f0,8) && hz_equal((void *)0x7f39f0,findSignature,8)
        && readable((void *)0x804c30,7) && hz_equal((void *)0x804c30,readSignature,7)
        && readable((void *)0xc71ad0,8) && readable((void *)0xc718b0,420);
}
static int native_peer(void) {
    HzByte *module=GetModuleHandleA("samp.dll"),*net;
    HzU32 pe;
    if(!readable(module,0x100))return 0;
    pe=value32(module+0x3c);
    if(pe>0x1000 || !readable(module+pe,0x80))return 0;
    /* Exact tested R5 image metadata, plus native CNetGame layout check. */
    if(value32(module+pe+8)!=0x6372c39e || value32(module+pe+24+16)!=0xcbc90
       || value32(module+pe+24+56)!=0x27e000)return 0;
    if(!readable(module+0x26eb94,4))return 0;
    net=*(HzByte **)(module+0x26eb94);
    if(!readable(net,0x3e2))return 0;
    return hz_peer((char *)(net+48),(int)value32(net+565),(int)value32(net+973));
}
static HzTexture *texture(void *dict,const char *name) {
    if(!dict)return 0;
    return ((HzTexture *(*)(void *,const char *))0x7f39f0)(dict,name);
}
static void release(HzTexture *tex) {if(tex)((int (*)(HzTexture *))0x7f3820)(tex);}
static int texture_valid(HzTexture *tex) {
    return readable(tex,sizeof(*tex)) && tex->raster && tex->references>0 && tex->references<100000;
}
static int path(char *out,const char *relative) {
    HzU32 i=0,j=0;
    while(assetRoot[i] && i<240){out[i]=assetRoot[i];i++;}
    if(i>=240)return 0;
    out[i++]='\\';
    while(relative[j] && i<259)out[i++]=relative[j++];
    out[i]=0;return relative[j]==0;
}
static HzByte *read_file(const char *relative,HzU32 *size) {
    char filename[260];void *file;HzByte *data;HzU32 got;
    if(!path(filename,relative))return 0;
    file=CreateFileA(filename,0x80000000,1,0,3,0x80,0);
    if(file==(void *)-1)return 0;
    *size=GetFileSize(file,0);
    if(*size<1 || *size>64*1024*1024){CloseHandle(file);return 0;}
    data=HeapAlloc(GetProcessHeap(),0,*size);
    if(!data){CloseHandle(file);return 0;}
    if(!ReadFile(file,data,*size,&got,0) || got!=*size){HeapFree(GetProcessHeap(),0,data);data=0;}
    CloseHandle(file);return data;
}
static int txd_valid(const HzByte *data,HzU32 length) {
    HzU32 pos=12,count=0,declared=0;
    if(length<40 || value32(data)!=22 || value32(data+4)!=length-12)return 0;
    while(pos<length) {
        HzU32 kind,size,end;
        if(length-pos<12)return 0;
        kind=value32(data+pos);size=value32(data+pos+4);
        if(size>length-pos-12)return 0;
        end=pos+12+size;
        if(kind==1 && pos==12) {
            if(size!=4)return 0;
            declared=data[pos+12]+256u*data[pos+13];if(!declared || declared>64)return 0;
        } else if(kind==21) {
            HzU32 nativeSize,cursor,nativeEnd,w,h,levels,format,level;
            const HzByte *native;
            if(size<112 || value32(data+pos+12)!=1)return 0;
            nativeSize=value32(data+pos+16);native=data+pos+24;
            if(nativeSize<92 || nativeSize>size-12 || value32(native)!=9)return 0;
            nativeEnd=pos+24+nativeSize;cursor=pos+24+88;
            w=native[80]+256u*native[81];h=native[82]+256u*native[83];levels=native[85];format=value32(native+76);
            if(!w || !h || w>8192 || h>8192 || !levels || levels>14)return 0;
            if(format!=21 && format!=0x31545844)return 0;
            if((w&(w-1)) || (h&(h-1)))return 0;
            if(format==21 && (native[84]!=32 || native[87]!=1))return 0;
            if(format==0x31545844 && (native[84]!=16 || native[87]!=8))return 0;
            for(level=0;level<levels;level++) {
                HzU32 bytes,expected;
                if(nativeEnd-cursor<4)return 0;
                bytes=value32(data+cursor);cursor+=4;
                expected=format==21?w*h*4:((w+3)/4)*((h+3)/4)*8;
                if(bytes!=expected || bytes>nativeEnd-cursor)return 0;
                cursor+=bytes;w=w>1?w/2:1;h=h>1?h/2:1;
            }
            if(cursor!=nativeEnd)return 0;
            count++;
        } else if(kind!=3)return 0;
        pos=end;
    }
    return pos==length && count==declared;
}
/* Pure validation export also exercised by the standalone Wine ABI probe. */
int HZV_ValidateTxd(const HzByte *data,HzU32 length) {return readable(data,length) && txd_valid(data,length);}
static void *load_dict(const char *relative) {
    HzU32 n;HzByte *data=read_file(relative,&n);void *stream,*dict=0;
    StreamMemory memory;
    if(!data)return 0;
    if(!txd_valid(data,n)){HeapFree(GetProcessHeap(),0,data);return 0;}
    memory.data=data;memory.bytes=n;
    stream=((void *(*)(int,int,void *))0x7ecef0)(3,1,&memory);
    if(stream) {
        if(((int (*)(void *,HzU32,void *,void *))0x7ed2d0)(stream,22,0,0))
            dict=((void *(*)(void *))0x804c30)(stream);
        ((int (*)(void *,void *))0x7ece20)(stream,0);
    }
    HeapFree(GetProcessHeap(),0,data);return dict;
}
static void *get_dict(int index) {
    TxdPool *pool;
    if(!readable((void *)0xc8800c,4))return 0;
    pool=*(TxdPool **)0xc8800c;
    if(!readable(pool,sizeof(*pool)) || index<0 || index>=pool->count || index>5000)return 0;
    if(!readable(pool->flags+index,1) || pool->flags[index]&0x80
       || !readable(pool->objects+index,sizeof(TxdDef)))return 0;
    return pool->objects[index].dict;
}
static void restore_all(void) {
    int i;
    for(i=0;i<2;i++)hz_slot_restore(&fonts[i],release);
    for(i=0;i<64;i++)hz_slot_restore(&icons[i],release);
    for(i=0;i<144;i++)hz_raster_restore(&tiles[i],release);
    hz_raster_restore(&overview,release);
    if(widthsActive && hz_equal((void *)0xc718b0,replacementWidths,420))
        hz_copy((void *)0xc718b0,originalWidths,420);
    widthsActive=0;
}
int HZV_Init(const char *root) {
    HzU32 n=0;
    if(!supported_game() || !native_peer())return -1;
    if(initialized)return 1;
    if(!root)return -2;
    while(root[n] && n<239){assetRoot[n]=root[n];n++;}
    if(n>=239)return -2;
    assetRoot[n]=0;initialized=1;return 1;
}
void HZV_Deactivate(void) {requested=0;if(initialized)restore_all();}
int HZV_Update(int enable) {
    int i;char name[20];HzTexture *tex,*replacement;
    requested=enable!=0;
    if(!initialized)return -1;
    if(!requested || !native_peer()){restore_all();return 0;}
    if(errorCode)return errorCode;
    /* One dictionary per presentation call avoids a bulk startup upload. */
    if(step==0) {
        HzU32 n;HzByte *widths=read_file("font-widths.bin",&n);
        if(!widths || n!=420){if(widths)HeapFree(GetProcessHeap(),0,widths);return errorCode=-2;}
        hz_copy(replacementWidths,widths,420);HeapFree(GetProcessHeap(),0,widths);
        fontDict=load_dict("fonts.txd");if(!fontDict)return errorCode=-3;
        if(!texture_valid(texture(fontDict,"font2")) || !texture_valid(texture(fontDict,"font1")))return errorCode=-3;
        step++;
    } else if(step==1) {iconDict=load_dict("icons.txd");if(!iconDict)return errorCode=-4;step++;}
    else if(step==2) {overviewDict=load_dict("overview.txd");if(!overviewDict)return errorCode=-5;step++;}
    else if(step<147) {
        i=step-3;
        hz_copy(name,"radar000.txd",13);name[5]='0'+i/100;name[6]='0'+(i/10)%10;name[7]='0'+i%10;
        tileDict[i]=load_dict(name);if(!tileDict[i])return errorCode=-6;
        loadedTiles++;step++;
    }
    if(fontDict) {
        HzTexture **slots=(HzTexture **)0xc71ad0;
        for(i=0;i<2;i++) {
            replacement=texture(fontDict,i==0?"font2":"font1");
            if(texture_valid(slots[i]))hz_slot_apply(&fonts[i],slots+i,replacement,release);
        }
        if(fonts[0].active && fonts[1].active && !widthsActive) {
            hz_copy(originalWidths,(void *)0xc718b0,420);hz_copy((void *)0xc718b0,replacementWidths,420);widthsActive=1;
        }
    }
    if(iconDict) {
        HzTexture **slots=(HzTexture **)0xbaa250;
        for(i=2;i<64;i++)if(texture_valid(slots[i])) {
            replacement=texture(iconDict,slots[i]->name);
            if(texture_valid(replacement))hz_slot_apply(&icons[i],slots+i,replacement,release);
        }
    }
    for(i=0;i<144;i++)if(tileDict[i]) {
        void *dict=get_dict(((int *)0xba8478)[i]);
        hz_copy(name,"radar00",8);name[5]='0'+i/10;name[6]='0'+i%10;
        if(i>=100){name[5]='0'+i/100;name[6]='0'+(i/10)%10;name[7]='0'+i%10;name[8]=0;}
        tex=texture(dict,name);replacement=texture(tileDict[i],name);
        if(!texture_valid(tex)){hz_raster_restore(&tiles[i],release);continue;}
        if(texture_valid(replacement))hz_raster_apply(&tiles[i],tex,replacement->raster,release);
    }
    if(overviewDict) {
        int index=((int (*)(const char *))0x731850)("fronten2");
        tex=texture(get_dict(index),"map");replacement=texture(overviewDict,"map");
        if(texture_valid(tex) && texture_valid(replacement))hz_raster_apply(&overview,tex,replacement->raster,release);
        else hz_raster_restore(&overview,release);
    }
    return (widthsActive?1:0)|(iconDict?2:0)|(loadedTiles==144?4:0)|(overview.active?8:0);
}
int HZV_Status(void) {return errorCode?errorCode:(widthsActive?1:0)|(iconDict?2:0)|(loadedTiles==144?4:0)|(overview.active?8:0);}
void HZV_Shutdown(void) {
    int i;requested=0;
    if(!initialized)return;
    restore_all();
    if(fontDict)((int (*)(void *))0x7f36a0)(fontDict);
    if(iconDict)((int (*)(void *))0x7f36a0)(iconDict);
    if(overviewDict)((int (*)(void *))0x7f36a0)(overviewDict);
    fontDict=iconDict=overviewDict=0;
    for(i=0;i<144;i++){if(tileDict[i])((int (*)(void *))0x7f36a0)(tileDict[i]);tileDict[i]=0;}
    initialized=step=errorCode=loadedTiles=0;
}
int WIN DllMain(void *module,HzU32 reason,void *reserved) __asm__("\"_DllMain@12\"");
int WIN DllMain(void *module,HzU32 reason,void *reserved) {(void)module;(void)reason;(void)reserved;return 1;}
