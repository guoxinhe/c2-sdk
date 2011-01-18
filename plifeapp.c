
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


//uClibc can not support the 'syslog' well.
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

struct process_life _small_plife;
struct process_life *plife=&_small_plife;

int debug=0;
int nr_errors=0;
int cmd_req=0x200;
pid_t traced_pid=0;

char cmd_byarg[128]={0,};//empty cmd_byarg for default cmd_byarg
char saveas_name[256];//save_name will point this if filled.
char *save_name="out.bin";

// 4 global / command based bit-flags.
unsigned long glFlags=0;//global flags form lower case
unsigned long guFlags=0;//global flags for upper case
unsigned long clFlags=0;//command flags form lower case
unsigned long cuFlags=0;//command flags form upper case

int gFlag(int c) { unsigned long ret=0;
    if('a'<=(c) && (c)<='z') ret=glFlags & ( 1UL<<((c)-'a') );
    if('A'<=(c) && (c)<='Z') ret=guFlags & ( 1UL<<((c)-'A') );
    return ret;
}
int cFlag(int c) { unsigned long ret=0;
    if('a'<=(c) && (c)<='z') ret=clFlags & ( 1UL<<((c)-'a') );
    if('A'<=(c) && (c)<='Z') ret=cuFlags & ( 1UL<<((c)-'A') );
    return ret;
}

int help(void)
{
    printf("process life, for debug process low level.\n");
    printf("plife [ global options ] plife_command [ command options ] [ command args ]\n");
    printf("example: plife <pid to be traced>\n");
    printf("Global options:\n");
    printf("    -H print head of kernel output\n");
    printf("    -S print shared data from kernel TBD\n");
    printf("    -L print log data from kernel TBD\n");
    printf("    -T print basic trace message\n");
    printf("Commands:\n");
    printf("    help           Basic info of a process TBD\n");
    printf("    tr         task_struct reference\n");
    printf("    ti pid     task info list\n");
    printf("    to pid     task info save to output file\n");
    printf("    tc pid     task call stack print to dmesg\n");
    printf("    ks         kernel execute script\n");
    printf("Command options:\n");
    printf("    -o output file\n");

    return 0;
}
int help_tr(void)
{
        printf("task_struct reference list\n");
	printf("  TASK_RUNNING         0  \n");
	printf("  TASK_INTERRUPTIBLE   1  \n");
	printf("  TASK_UNINTERRUPTIBLE 2  \n");
	printf("  TASK_STOPPED         4  \n");
	printf("  TASK_TRACED          8  \n");
	printf("  EXIT_ZOMBIE          16 \n");
	printf("  EXIT_DEAD            32 \n");
	printf("  TASK_NONINTERACTIVE  64 \n");
	printf("  TASK_DEAD            128\n");
    return 0;
}
int save_binary(char *name, char *buf, int len)
{
    int fd;
#ifndef O_BINARY
#define O_BINARY 0
#endif
    fd = open(name, O_RDWR | O_CREAT | O_BINARY);
    if (fd < 0)
    {
        printf("Can not open file %s for save\n",name);
        return -1;
    }

    write(fd,buf,len);

    close(fd);
    return 0;
}
int load_default(void)
{
    nr_errors=0;
    strcpy(cmd_byarg,"help");
    return 0;
}
int parse_args(int argc, char *argv[])
{
    int cur=1;
    char *p,c;
    int i;

    //parse global option
    while(cur<argc) {
        p=argv[cur];
        if(*p != '-') 
            break;

        //parse
        p++;
        while(*p) {
            c=*p++;
            if('a'<=c && c<='z') glFlags |= 1UL<< (c-'a');
            if('A'<=c && c<='Z') guFlags |= 1UL<< (c-'A');
        }
        cur++;
    }

    //parse command
    if(cur<argc) {
        p=argv[cur];
        //parse
	strncpy(cmd_byarg,p,sizeof(cmd_byarg)-1);
        if(plife->pcur<plife->pend)
	    plife->pcur += sprintf(plife->pcur,"%s ",p);
        cur++;
    } else {
        nr_errors++;
        return 0;
    }
    
    //parse command options
    while(cur<argc) {
        p=argv[cur];
        if(*p != '-') 
            break;
        //parse
        if(plife->pcur<plife->pend) 
	    plife->pcur += sprintf(plife->pcur,"%s ",p);
        p++;
        while(*p) {
            c=*p++;
            if('a'<=c && c<='z') clFlags |= 1UL<< (c-'a');
            if('A'<=c && c<='Z') cuFlags |= 1UL<< (c-'A');
        }
        cur++;
    }

    //parse command parameters
    while(cur<argc) {
        p=argv[cur];
        //parse
        if(plife->pcur<plife->pend) 
	    plife->pcur += sprintf(plife->pcur,"%s ",p);
        i= atoi(p);
        if(i != 0 && traced_pid<=1)
            traced_pid = i;

        cur++;
    }

    plife->bufusize += plife->pcur-plife->pstart;
    return 0;
}
int free_plife(void)
{
    if(plife !=&_small_plife) {
        free(plife);
        plife=&_small_plife;
    }
    return 0;
}
int init_plife(void)
{
    #define PLIFE_TOTALSIZE  (sizeof(*plife) + 1024*1024+ 16)
    if(plife == &_small_plife) {
        char *pobj=malloc(PLIFE_TOTALSIZE);
        if(pobj) {
	    memset(pobj,0,PLIFE_TOTALSIZE);
            plife=(struct process_life *)pobj;
            plife->thissize=PLIFE_TOTALSIZE;
	} else {
	    printf("No big memory for a big plife\n");
	    memset(plife,0,sizeof(*plife));
            plife->thissize=sizeof(*plife);
	}
    }
    if(!plife->pstart) {
        plife->bufoffset=(char *)plife->buf - (char *)plife;
        plife->bufsize=plife->thissize-sizeof(*plife)+sizeof(plife->buf);
        plife->pstart=plife->pcur=plife->buf;
        plife->pend=plife->buf+plife->bufsize-1;
    }
    if(plife != &_small_plife) {
	//save info back
        memcpy((void *)&_small_plife,(void *) plife,sizeof(*plife));
    }

    return 0;
}
int check_userrequest(void)
{
    if(nr_errors)
        printf("%d errors in command lines\n", nr_errors);
    return 0;
}
int syslog_request(int req)
{
    int sizelife=0,filllife=0;

    sizelife=__mysyscall_syslog( 10, (void *)plife->pstart, plife->bufsize);
    filllife=__mysyscall_syslog(  9, (void *)plife->pstart, plife->bufsize);
    //printf("Kernel syslog(printk) buf size =%d bytes, filled %d bytes\n",sizelife, filllife);
    if(gFlag('T')) //trace info
        printf("Traced process pid=%d\n", traced_pid);

    plife->id=0xC251CAFE; //="plif"
    plife->req=req;
    plife->cpid=traced_pid;

    //this service is implemented by kernel patch plife
    __mysyscall_syslog(1, (void *)plife, plife->thissize);

    //parse return result

    if(gFlag('H')) { //head
        printf("Kernel output shared data, text len=%d\n", plife->bufksize);
    }

    if(gFlag('S')) {   //shared data
        int i;
        for(i=0;i<64;i++){
            if((i&7)==0) printf("%4d ",i);
            printf("%8X ",plife->shared[i]);
            if((i&7)==7) printf("\n");
        }
    }

    if(gFlag('L')) {   //log data
        printf("%s\n",(char *) plife->pstart);
    }

    if(plife->bufksize > sizeof(*plife)) { //bin file attached.
        save_binary(save_name, (char *)(plife+1), plife->bufksize - sizeof(*plife));
    }
    return 0;
}
int main(int argc, char *argv[])
{   
    init_plife(); // so that data can goes here

    load_default(); 

    parse_args(argc, argv); //load customed

    check_userrequest();

    if(nr_errors>0){
        help();
        free_plife();
        exit(nr_errors);
    }

    if(cmd_byarg[0]==0) { //default
    } else if(0==strcmp(cmd_byarg, "help" )) { help();
    } else if(0==strcmp(cmd_byarg, "tr" )) { help_tr();
    } else if(0==strcmp(cmd_byarg, "ti" )) { syslog_request(0x200);
    } else if(0==strcmp(cmd_byarg, "to" )) { syslog_request(0x201);
    } else if(0==strcmp(cmd_byarg, "tc" )) { syslog_request(0x202);
    } else if(0==strcmp(cmd_byarg, "ks" )) { syslog_request(0x500);
    } else                                 { syslog_request(0x500);
    }

    free_plife();

    return 0;
}
