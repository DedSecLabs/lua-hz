#include <assert.h>
#include <stdio.h>
#include "../native/visual_policy.h"
static int releases;
static void release(HzTexture *t){assert(t->references>0);t->references--;releases++;}
int main(void) {
    assert(hz_peer("213.32.6.232",7777,5));assert(hz_peer("213.32.6.232",7777,6));
    assert(!hz_peer("213.32.6.233",7777,5));assert(!hz_peer("213.32.6.232",7778,5));
    assert(!hz_peer("213.32.6.232.fake",7777,5));assert(!hz_peer("Horizon Roleplay",7777,5));
    assert(!hz_peer("213.32.6.232",7777,2));assert(!hz_peer(0,7777,5));
    HzTexture a={0},b={0},other={0};HzTexture *slot=&a;HzSlot binding={0};
    a.references=2;b.references=1;other.references=2;
    assert(hz_slot_apply(&binding,&slot,&b,release));assert(slot==&b && b.references==2 && a.references==2);
    assert(hz_slot_apply(&binding,&slot,&b,release));assert(b.references==2);
    hz_slot_restore(&binding,release);assert(slot==&a && b.references==1 && a.references==2);
    hz_slot_restore(&binding,release);assert(b.references==1);
    hz_slot_apply(&binding,&slot,&b,release);
    release(slot);slot=&other; /* Another owner replaces our sprite. */
    hz_slot_restore(&binding,release);assert(slot==&other && a.references==1 && b.references==1);
    int rasterA,rasterB,rasterOther;
    HzRaster raster={0};a.raster=&rasterA;a.references=1;
    assert(hz_raster_apply(&raster,&a,&rasterB,release));assert(a.references==2 && a.raster==&rasterB);
    hz_raster_apply(&raster,&a,&rasterB,release);assert(a.references==2);
    release(&a); /* Stream-out drops the dictionary reference. Helper keeps it alive. */
    assert(a.references==1);
    hz_raster_restore(&raster,release);assert(a.references==0 && a.raster==&rasterA);
    a.references=1;hz_raster_apply(&raster,&a,&rasterB,release);a.raster=&rasterOther;
    hz_raster_restore(&raster,release);assert(a.raster==&rasterOther && a.references==1);
    a.raster=&rasterA;hz_raster_apply(&raster,&a,&rasterB,release);
    other.raster=&rasterOther;hz_raster_apply(&raster,&other,&rasterB,release);
    assert(a.raster==&rasterA && a.references==1 && other.references==3);
    hz_raster_restore(&raster,release);assert(other.raster==&rasterOther && other.references==2);
    unsigned char saved[420],fresh[420];for(int i=0;i<420;i++)saved[i]=(unsigned char)i;
    hz_copy(fresh,saved,420);assert(hz_equal(saved,fresh,420));fresh[419]^=1;assert(!hz_equal(saved,fresh,420));
    puts("PASS native endpoint policy, sprite references, streamed raster lifetime and ownership restoration");return 0;
}
