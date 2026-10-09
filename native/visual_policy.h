/* LuaHZ native texture ownership; MIT, LuaHZ contributors. */
#ifndef LUAHZ_VISUAL_POLICY_H
#define LUAHZ_VISUAL_POLICY_H
typedef unsigned char HzByte;
typedef unsigned int HzU32;
typedef struct HzTexture {
    void *raster, *dictionary, *next, *previous;
    char name[32], mask[32];
    HzU32 filtering;
    int references;
} HzTexture;
typedef void (*HzRelease)(HzTexture *);
typedef struct HzSlot {
    HzTexture **address, *original, *replacement;
    int active;
} HzSlot;
typedef struct HzRaster {
    HzTexture *texture;
    void *original, *replacement;
    int active;
} HzRaster;
static void hz_copy(void *dst,const void *src,HzU32 n) {
    HzByte *d=dst;const HzByte *s=src;while(n--)*d++=*s++;
}
static int hz_equal(const void *a,const void *b,HzU32 n) {
    const HzByte *x=a,*y=b;while(n--)if(*x++!=*y++)return 0;return 1;
}
static int hz_peer(const char *ip,int port,int state) {
    static const char allowed[]="213.32.6.232";
    return ip && port==7777 && (state==1 || state==5 || state==6 || state==11)
        && hz_equal(ip,allowed,sizeof(allowed));
}
static void hz_slot_restore(HzSlot *binding,HzRelease release) {
    if(!binding->active)return;
    if(*binding->address==binding->replacement) {
        *binding->address=binding->original;
        release(binding->replacement);
    } else {
        /* Another owner replaced/deleted our sprite reference. Release only
           the displaced original reference that this binding held. */
        release(binding->original);
    }
    binding->active=0;
}
static int hz_slot_apply(HzSlot *binding,HzTexture **address,HzTexture *replacement,HzRelease release) {
    if(binding->active) {
        if(binding->address==address && *address==binding->replacement)return 1;
        hz_slot_restore(binding,release);
    }
    if(!address || !*address || !replacement)return 0;
    binding->address=address;binding->original=*address;binding->replacement=replacement;
    replacement->references++; /* Sprite owns an independent texture ref. */
    *address=replacement;binding->active=1;return 1;
}
static void hz_raster_restore(HzRaster *binding,HzRelease release) {
    if(!binding->active)return;
    if(binding->texture->raster==binding->replacement)binding->texture->raster=binding->original;
    release(binding->texture); /* Extra ref kept streamed texture alive. */
    binding->active=0;
}
static int hz_raster_apply(HzRaster *binding,HzTexture *texture,void *replacement,HzRelease release) {
    if(binding->active) {
        if(binding->texture==texture && texture && texture->raster==binding->replacement)return 1;
        hz_raster_restore(binding,release);
    }
    if(!texture || !replacement || !texture->raster)return 0;
    binding->texture=texture;binding->original=texture->raster;binding->replacement=replacement;
    texture->references++;texture->raster=replacement;binding->active=1;return 1;
}
#endif
