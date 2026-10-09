/* Pure startup destination policy; MIT, LuaHZ contributors. */
#ifndef LUAHZ_LOADING_POLICY_H
#define LUAHZ_LOADING_POLICY_H
static int hzl_text_equal(const char *a,const char *b) {
    while(*a && *a==*b){a++;b++;}return *a==*b;
}
static int hzl_token(const char **cursor,char *out,unsigned cap) {
    const char *p=*cursor;unsigned n=0;int quoted=0;
    while(*p==' ' || *p=='\t')p++;
    if(!*p){*cursor=p;return 0;}
    while(*p && (quoted || (*p!=' ' && *p!='\t'))) {
        if(*p=='"'){quoted=!quoted;p++;continue;}
        if(*p=='\\') {
            unsigned slash=0;while(p[slash]=='\\')slash++;
            if(p[slash]=='"') {
                unsigned emit=slash/2;
                while(emit--){if(n+1>=cap)return -1;out[n++]='\\';}
                p+=slash;
                if(slash&1){if(n+1>=cap)return -1;out[n++]='"';p++;}
                else {quoted=!quoted;p++;}
                continue;
            }
        }
        if(n+1>=cap)return -1;
        out[n++]=*p++;
    }
    if(quoted)return -1;
    out[n]=0;*cursor=p;return 1;
}
static int hzl_destination(const char *command) {
    char token[512],host[512]={0},port[512]={0};int haveHost=0,havePort=0,result;
    if(!command)return 0;
    while((result=hzl_token(&command,token,sizeof(token)))>0) {
        if(hzl_text_equal(token,"-h") || hzl_text_equal(token,"/h")) {
            if(haveHost++ || hzl_token(&command,host,sizeof(host))!=1)return 0;
        } else if(hzl_text_equal(token,"-p") || hzl_text_equal(token,"/p")) {
            if(havePort++ || hzl_token(&command,port,sizeof(port))!=1)return 0;
        }
    }
    if(result<0 || haveHost!=1 || havePort!=1 || !hzl_text_equal(port,"7777"))return 0;
    return hzl_text_equal(host,"213.32.6.232") || hzl_text_equal(host,"samp.hzgaming.net");
}
#endif
