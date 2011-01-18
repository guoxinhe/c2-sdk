//pthread test small program
#include <stdio.h>
#include <linux/fb.h>
#include <pthread.h>
#include <linux/watchdog.h>
#include <unistd.h>
#include <linux/limits.h>
#include <sys/ioctl.h>
#include <fcntl.h>
#include <string.h>
#include <unistd.h>
#include <sys/types.h>
#include <sys/stat.h>


#include <stdio.h>  //printf()
#include <errno.h>
#include <fcntl.h>
#include <stdarg.h>
#include <stdlib.h> //exit()
#include <string.h> //memset()
#include <unistd.h>
#include <sys/wait.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <sys/syslog.h>
#include <sys/ptrace.h>
#include <sys/syscall.h>
#include <linux/sched.h>
#include <linux/ptrace.h>

#define GETPROCESSOR_ID 1
#ifdef GETPROCESSOR_ID
#ifdef X86
long __mysyscall_syslog(int cmd, void* buf, int len)
{
    return 0;
}
#else //c2's system
#define __NR___mysyscall_syslog __NR_syslog
_syscall3(long, __mysyscall_syslog, int, cmd, void*, buf, int, len);
#endif
struct process_life{       //     --- field still not used by code. *** code used field.
   int id;                 // *** magic, always fixed as 0xC251CAFE
   int ver;                // --- sw version;
   int cfg;                // --- sw config for this version
   int req;                // *** user requested operation code
   int cpid;               // *** child pid to be traced.
   int mypid;              // --- fill caller's pid
   int ppid;               // --- cpid->parent pid
   int rpid;               // --- cpid->real parent pid
   int thissize;           // *** malloc's total size, =sizeof(this)+extend buffer size(mostly 1MB)
   int bufsize;            // *** total size of buf[...], mostly >sizeof(buf);
   int bufusize;           // *** user written size of 'buf'
   int bufksize;           // *** kernel written size of 'buf'
   int bufoffset;          // *** 'buf' offset from this. for dump to a file
   int shared[64];         // *** put some stat data here for app's auto display

   //user space only
   char *pstart, *pend;//init only once
   char *pcur;

   //shared space, here for log inside this, for binary out outside this
   char buf[1024];
};
int get_processor_id(void)
{
    struct process_life _small_plife;
    struct process_life *plife=&_small_plife;
    memset(plife,0,sizeof(*plife));
    plife->thissize=sizeof(*plife);
    if(!plife->pstart) {
        plife->bufoffset=(char *)plife->buf - (char *)plife;
        plife->bufsize=plife->thissize-sizeof(*plife)+sizeof(plife->buf);
        plife->pstart=plife->pcur=plife->buf;
        plife->pend=plife->buf+plife->bufsize-1;
    }
    plife->id=0xC251CAFE; //="plif"
    plife->req=0x300;
    plife->cpid=0;
    //this service is implemented by kernel patch plife
    __mysyscall_syslog(1, (void *)plife, plife->thissize);
    return plife->shared[0];
}
#else
int get_processor_id(void){return 0;}
#endif


int general_flags=0;
#define SETBITAB(intvar,a) do{\
    if('a'<=(a)&&(a)<='z')     intvar |=    1UL<< (((a)-'a')&31);\
    if('A'<=(a)&&(a)<='Z')     intvar &=  ~(1UL<< (((a)-'A')&31));}while(0)
#define GETBITAB(intvar,a) ({ int ret; \
    if('a'<=(a)&&(a)<='z') ret=intvar &    (1UL<< (((a)-'a')&31));\
    if('A'<=(a)&&(a)<='Z') ret=intvar &    (1UL<< (((a)-'A')&31)); ret;})

#define NR_MISSION 8
int mission_forcedexitflags=0; //parent controlls this
int mission_maxcount=50;
int mission_sleepdiv=1;
int mission_pollingdiv=1000000;
volatile int mission_idlebuf[256];
volatile int mission_idletoy=0;
struct permission_data{
    int state;
    int count;
    int oncpu;
    int pid,ppid;//runtime fill
    pthread_t create_id;
}pmsdata[NR_MISSION];
#define per_mission_var(va,mis) pmsdata[mis].va
#define MISSION_HASDONE(_idx) (per_mission_var(state,_idx) & (1<<( sizeof(per_mission_var(state,_idx))*8-1)))
#define MISSION_SETDONE(_idx) do{per_mission_var(state,_idx) |=  1<<( sizeof(per_mission_var(state,_idx))*8-1);}while(0)
#define MISSION_HASFORCEDDONE(_idx) ( ! ! (mission_forcedexitflags & (1<<(_idx))))
#define MISSION_SETFORCEDDONE(_idx) do{mission_forcedexitflags |= 1 << (_idx);}while(0)

#define MISSION_SIMPLETASK(idx) do{\
	int i; while(++i<10000000) { mission_idletoy=(mission_idletoy+7)*3+mission_idlebuf[mission_idletoy&0xFF];\
            mission_idletoy=~(mission_idletoy>>8)+(mission_idletoy<<8) +237;\
            mission_idlebuf[mission_idletoy&0xFF]+=mission_idletoy*(idx+3);}\
	}while(0)
//        system("mkdir -p tmp/" #idx);\
//        system("tar xzvf c2_update.tar -C tmp/" #idx  " >>tmp/" #idx ".log 2>&1 ");}while(0)\

#define MISSION_DECLARE(idx, us) \
    void* mission_##idx(void *) { \
    int midx= idx ; \
    while( !MISSION_HASFORCEDDONE(midx) && !MISSION_HASDONE(midx) ){ \
        per_mission_var(count,midx)++; \
        per_mission_var(oncpu,midx)=get_processor_id();\
        per_mission_var(pid,midx)=getpid();\
        per_mission_var(ppid,midx)=getppid();\
	MISSION_SIMPLETASK(idx); \
        if(mission_sleepdiv>1000) usleep(us/mission_sleepdiv); \
	} \
    MISSION_SETDONE(midx);\
    return (void*)0;}

#define MISSION_CREATE(idx,paramt) do{ if((idx) < NR_MISSION) { \
        if(pthread_create (&per_mission_var(create_id,idx), NULL, mission_##idx, paramt)) {\
            printf("Create thread %d failed\n",idx);\
        } else {\
            printf("Create thread %d id=%d\n",idx, per_mission_var(create_id,idx));}}}while(0)

MISSION_DECLARE( 0, 10000 )
MISSION_DECLARE( 1, 20000 )
MISSION_DECLARE( 2, 30000 )
MISSION_DECLARE( 3, 40000 )
MISSION_DECLARE( 4, 50000 )
MISSION_DECLARE( 5, 60000 )
MISSION_DECLARE( 6, 70000 )
MISSION_DECLARE( 7, 80000 )

int create_missions(void)
{
    mission_forcedexitflags=0; //parent controlls this
    memset(pmsdata,0,sizeof(pmsdata));

    MISSION_CREATE( 0, NULL);
    MISSION_CREATE( 1, NULL);
    MISSION_CREATE( 2, NULL);
    MISSION_CREATE( 3, NULL);
    MISSION_CREATE( 4, NULL);
    MISSION_CREATE( 5, NULL);
    MISSION_CREATE( 6, NULL);
    MISSION_CREATE( 7, NULL);
    return 0;
}

int manage_missions(void)
{
    int nr_done=0;
    int midx;
    int nr_round=0;
    int done=0;
    int pid=getpid(),ppid=getppid();
    
    printf("pid /ppid   nr cpu:pid/ppid count of each thread\n",pid,ppid,nr_round++);
    printf("main procedure");
    for(midx=0;midx<NR_MISSION;midx++)
        printf(" ---thread %d---",midx);
    printf("\n");

    //c2's system create pid for each pthread, but x86 shares pid with main()
#ifdef X86
    system("ps x | grep bees");
#else //c2's system
    system("ps   | grep bees");
#endif

    while(nr_done != NR_MISSION) {
        nr_done=0;
        printf("%d/%d %4d",pid,ppid,nr_round++);
        for(midx=0;midx<NR_MISSION;midx++) {
            done=MISSION_HASDONE(midx);
            if(done) {
                nr_done++;
                printf(" %8X",per_mission_var(state,midx));
            } else { 
                if(per_mission_var(count,midx)>mission_maxcount)
                    MISSION_SETFORCEDDONE(midx);
		printf("(");
                if(GETBITAB(general_flags,'a')) printf(" %d",  per_mission_var(oncpu,midx));
                if(GETBITAB(general_flags,'p')) printf(" %d",  per_mission_var(pid,midx));
                if(GETBITAB(general_flags,'c')) printf(" %d",  per_mission_var(ppid,midx));
                //if(GETBITAB(general_flags,'d')) 
		printf(" %2X)", per_mission_var(count,midx));
            }
        }
        printf("\n");
        usleep(mission_pollingdiv); 
    }
    printf("%d\n",mission_idletoy);
    //do not call pthread_join(), we control the pthread ourself.
    pthread_join(per_mission_var(create_id,0),NULL);
    pthread_join(per_mission_var(create_id,1),NULL);
    pthread_join(per_mission_var(create_id,2),NULL);
    pthread_join(per_mission_var(create_id,3),NULL);
    pthread_join(per_mission_var(create_id,4),NULL);
    pthread_join(per_mission_var(create_id,5),NULL);
    pthread_join(per_mission_var(create_id,6),NULL);
    pthread_join(per_mission_var(create_id,7),NULL);
    return 0;
}

int parse_args(int argc, char *argv[])
{
    char cmdline_path[256]={0,};
    char cmdline_name[256]={0,};
    int  cmdline_from=0;//system
    //argc=0,argv[0] is program name
    int cur=0;
    char *p,c,a;//token look forward and advance
    char *pnext;
    char *firste;
    #define __ARGSHIFT(n) cur+=(n)
    #define __LOOK2CH p=argv[cur]; c=*p; if(c) a=*(p+1); else a='\0';
    #define __LOOKNEXT if(cur+1<argc) pnext=argv[cur+1]; else pnext=NULL;
    #define __LOOKEQU  firste=strchr(p,'='); if(firste) firste++; else firste=NULL;
    //parse command and its path
    __LOOK2CH
    {
        char *firstp=strchr(p,'/');
        char *lastp=strrchr(p,'/');
        strcpy(cmdline_path, p);
        if(lastp) {
            strcpy(cmdline_name,lastp+1);
            cmdline_path[lastp-p]='\0';
        } else {
            strcpy(cmdline_name,p);
            cmdline_path[0]='\0';
        }
        if(c=='/') {    //  /path/cmd
            cmdline_from=1;
        } else if(c=='.' && a=='/') { //  ./cmd
            if(firstp==lastp) cmdline_from=2;
            else cmdline_from=4;
        } else {               //  cmd from system PATH or localpath/a/b/c/cmd
            if(lastp) cmdline_from=8;
        }
        //printf("cmdline_path/name=%s %s %d\n",cmdline_path, cmdline_name, cmdline_from);
    }
    __ARGSHIFT(1);

    //parse global option
    while(cur<argc) {
        __LOOK2CH  __LOOKNEXT  __LOOKEQU

        if(c=='-' && a=='-') { // --prefix=sth
            if(strcmp(p,"--help")==0) { SETBITAB(general_flags,'h');
            }
            __ARGSHIFT(1);
        } else if (c=='-') {   // -flags
            if(firste) {
                if(a=='m') { mission_maxcount=atoi(firste);
                    printf("mission_maxcount changed to %d\n",mission_maxcount);
	        } else if(a=='b') { mission_sleepdiv=atoi(firste);
	            if(mission_sleepdiv<1) mission_sleepdiv=1;
	            if(mission_sleepdiv>1000) mission_sleepdiv=1000;
                    printf("mission_sleepdiv changed to %d\n",mission_sleepdiv);
	        } else if(a=='c') { mission_pollingdiv=atoi(firste);
	            if(mission_pollingdiv<1000) mission_pollingdiv=1000;
                    printf("mission_pollingdiv changed to %d\n",mission_pollingdiv);
	        }
	    } else {
		p++;a=*p;
	        while(a) { SETBITAB(general_flags,a); a=*p++;
		}
	    }
            __ARGSHIFT(1);
        } else {               // args
            __ARGSHIFT(1);
        } 
    }

    #undef __ARGSHIFT
    return 0;
}
int main(int argc, char* argv[])
{
    parse_args(argc, argv);
    if(GETBITAB(general_flags,'d')) {
        printf("   mission_maxcount  =%d\n",mission_maxcount  );
        printf("   mission_sleepdiv  =%d\n",mission_sleepdiv  );
        printf("   mission_pollingdiv=%d\n",mission_pollingdiv);
    }
    if(GETBITAB(general_flags,'h')) {
        printf("  -m=digital how long thread should run  \n");
        printf("  -b=digital how busy thread should be   \n");
        printf("  -c=digital how idle print console logs \n");
        printf("  -h this help                           \n");
        printf("  -a print cpu index                     \n");
        printf("  -p print pid                           \n");
        printf("  -f print ppid                          \n");
        printf("  --help this help                       \n");
        printf("\nLast build info: %s %s %s\n",__FILE__, __DATE__, __TIME__);
        return 0;
    }
    create_missions();
    manage_missions();
    return 0;
}

