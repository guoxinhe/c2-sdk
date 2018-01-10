#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <pthread.h>

#ifdef MYMODULETEST //this mayrun in x86
#ifndef DEBUGVERSION
#define DEBUGVERSION 1
#endif
#endif
#ifdef DEBUGVERSION
int xatoiad(const char *nptr, int *advanced) {
    //read simple integer from string. format:
    //[0[b|B|x|X]]?[0~9|a~f|A~F]*
    //binary: 0B010101 0b010101, start with 0b,0B,follow 0.1
    //oct: 07654321, start with 0, follow 0-7
    //dec: 98765432, normal format.
    //hex: 0x0f0f0f 0X0F0F0F, start with 0x,0X,follow 0-9,a-f,A-F
    const char *old=nptr;
    int base=10;
    char ch;
    while(*nptr == ' '||*nptr == '\t') {//jump white space.
	nptr++;
    }
    if(*nptr=='0') {
	ch=*(nptr+1);
	if(ch=='\0') return 0;
	else if(ch=='x' || ch=='X') {base=16; nptr+=2;}
	else if(ch=='b' || ch=='B') {base=2; nptr+=2;}
	else {base=8; nptr+=2;}//8based.
    } else {
	//return atoi(nptr);
    }
    int val=0,v;
    while(*nptr != '\0') {
	ch=*nptr;
	if('0'<=ch&&ch<='9') v=ch-'0';
	else if('A'<=ch&&ch<='F') v=10+ch-'A';
	else if('a'<=ch&&ch<='f') v=10+ch-'a';
	else break;
	if(v>=base) break;
	val=val*base+v;
	nptr++;
    }

    *advanced=nptr-old;

    return val;
}
int xatoi(const char *nptr) {
	int len;
	return xatoiad(nptr,&len);
}
#define LIFE_OFF 0
#define LIFE_ON 1
#define LIFE_DONE 2
#define LIFE_OUTOFTIME 4
#define BUFLOOPMASK 0xFF
#define BUFLOOPSIZE (BUFLOOPMASK+1)
const char *prompt="sirun tbox # ";
static int threadStatus=LIFE_OFF;
static void* Pesh_Proc(void* arg);
static char cmdbuf[BUFLOOPMASK+1];
static char cmdhis[BUFLOOPMASK+1];//history
static int cmdpc=0;
static int exitCode=0;
extern int parseCommandBufferApp(char *buf, int len);
extern void printCustomerHelp(void);
static int peshFlag=0;
static int debugLevel=0;
void setPesh(int flag, int mask) {
    peshFlag &= ~mask;
    peshFlag |= flag & mask;
}
#define cmpn(n,str) (0==strncmp(buf,str,pos=n))
#define cmp(str) (0==strcmp(buf,str))
int parseCommandBufferPesh(char *buf, int len) {
	if(len>1&&buf[len-1]=='\n') {
		buf[len-1]='\0';//convert tail from '\n' to '\0'.
		len--;
	}

	int pos=0;
	if(cmpn(10,"pesh debug")) {
		if('0'<=buf[pos]&&buf[pos]<='9') {//else ignore this.
			debugLevel=buf[pos]-'0';
			printf("Log level: %d\n",debugLevel);
			return 0;
		}
	}

	return -1;
}
static int parseCommandBuffer(char *buf, int len) {
	if(0==parseCommandBufferPesh(buf,len))
		return 0;
	if(0==parseCommandBufferApp(buf,len))
		return 0;
        int ret = system(buf);
	printf("System return %d\n",ret);
	    return ret;
}
static void printHelp(void) {
	printf("pesh, procedure embeded shell\n");
	printf("build date: %s %s\n",__DATE__, __TIME__);
	printf("Help: use the pthread embedded shell\n"
		"\t	q : quit this\n"
		"\t	quit : quit this\n"
		"\t	exit : exit this with exit code 0\n"
		"\t	exit n : exit with exit code n=0~9\n"
		"\t	debugn : set debug level n=0~9\n"
		"\t	help : print this\n"
		);
	printCustomerHelp();
}
static void* Pesh_Proc(void* arg)
{
	threadStatus=LIFE_ON;

	#define pz(p) (((p)-3)&BUFLOOPMASK)
	#define pa(p) (((p)-2)&BUFLOOPMASK)
	#define pb(p) (((p)-1)&BUFLOOPMASK)
	#define BUFENDCHAR cmdbuf[sizeof(cmdbuf)-1]
	int nrChars;
	while(threadStatus==LIFE_ON) {
		exitCode=0;
		BUFENDCHAR='\n';//reset for readline.
		printf("%s", prompt);
		nrChars=0;
		cmdpc=0;
		while (1)
		{
			char c=getchar();
			cmdbuf[cmdpc]=c;
			cmdpc=BUFLOOPMASK & (cmdpc+1);//loop buffer.
			nrChars++;
			if(c=='\n') {//user press return.
				cmdbuf[cmdpc]='\0';//append a string end after the tail '\n'.
				break;
			}
		}
		//trim lead/tail space
		char *p, *pend;
		p=cmdbuf;pend=cmdbuf+nrChars;
		if(debugLevel>0) {//debug, print what input in hex.
		    int nr=0;
		    while(p<pend) {
			if(((nr)&7)==7) printf("0x%02X\n",*p++);//line tail
			else if(((nr)&7)==0) printf("\t[#%02X] 0x%02X ",(nr&0xF8),*p++);//line head
			else printf("0x%02X ",*p++);
			nr++;
		    }
		    if((nr&7)!=0) printf("\n");
		    p=cmdbuf;
		}
		if(p[0]==0x1B && p[1]=='['){//use the history.
		    if(p[2]=='A') //A^BvC>D<
			memcpy(cmdbuf,cmdhis,sizeof(cmdbuf));//restore history
		}
		while(p<pend && *p==' ' || *p=='\t') p++;//jump leading space.
		while(pend>=p && (*pend=='\0' || *pend=='\n' || *pend==' '|| *pend=='\t')) pend--;//trim tail space.
		if(pend!=cmdbuf) {
			pend[1]='\n';pend[2]='\0';
			nrChars=pend+2-p;
		}
		if(BUFENDCHAR!='\n') {//buffer overflow, ignore this line.
			printf("Input %d bytes, is longer than %u bytes, ignored.\n", nrChars, (unsigned int)sizeof(cmdbuf));
			continue;
		}

		if(p[0]=='q' && p[1]=='\n') {
			threadStatus=LIFE_OFF;//quit this thread only.
		} else {
			if(0==strcmp(p,"help\n")) printHelp();
			if(0==strcmp(p,"quit\n")) threadStatus=LIFE_OFF;
			if(0==strncmp(p,"quit ",5)) {threadStatus=LIFE_OFF;exitCode=p[5]-'0';}

			if(0==strcmp(p,"exit\n")) { threadStatus=LIFE_OFF;exit(exitCode);}//exit the app.
			if(0==strncmp(p,"exit ",5)) {threadStatus=LIFE_OFF;exitCode=p[5]-'0';exit(exitCode);}
			//TODO: parse your code from 0 to cmdpc.
			memcpy(cmdhis,cmdbuf,sizeof(cmdbuf));//save history
			parseCommandBuffer(p,nrChars);
		}
	}
	threadStatus=LIFE_OFF;
	return (void *)1;
}

void PeshDaemon(void* pArg) {
	if(peshFlag==0)//no pesh request, force not use it.
		return;
	Pesh_Proc(pArg);
}
#endif
#ifdef MYMODULETEST
static pthread_t thrd_uart_rcv;
int main(int argc, char* argv[])
{
	int iRet;
	int baudRate;
	char strTmp[] = "uart test, =+-_0)9(8*7&6^5%4$3#2@1!`~)\n\0";

    if (pthread_create(&thrd_uart_rcv, NULL, Pesh_Proc, NULL) != 0)
    {
        printf("Fail to create thread!\n");
    } else {
	threadStatus=LIFE_ON;
    }

	while (threadStatus!=LIFE_OFF)
	{
		usleep(3000 * 1000);
	}

	return 0;
}
#endif

