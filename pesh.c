#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <pthread.h>

#define LIFE_OFF 0
#define LIFE_ON 1
#define LIFE_DONE 2
#define LIFE_OUTOFTIME 4
#define BUFLOOPMASK 0xFF
#define BUFLOOPSIZE (BUFLOOPMASK+1)
const char *prompt="sirun tbox # ";
static int threadStatus=LIFE_OFF;
static pthread_t thrd_uart_rcv;
static void* Pesh_Proc(void* arg);
static char cmdbuf[BUFLOOPMASK+1];
static int cmdpc=0;
static int exitCode=0;
extern int parseCommandBufferApp(char *buf, int len);
extern void printCustomerHelp(void);
void PeshDaemon(void* pArg) {
	Pesh_Proc(pArg);
}
int parseCommandBuffer(char *buf, int len) {
	if(0==parseCommandBufferApp(buf,len))
		return 0;
        int ret = system(buf);
	    return ret;
}
void printHelp(void) {
	printf("pesh, procedure embeded shell\n");
	printf("build date: %s %s\n",__DATE__, __TIME__);
	printf("Help: use the pthread embedded shell\n"
		"\t	q : quit this\n"
		"\t	quit : quit this\n"
		"\t	exit : exit this with exit code 0\n"
		"\t	exit n : exit with exit code n=0~9\n"
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
			parseCommandBuffer(p,nrChars);
		}
	}
	threadStatus=LIFE_OFF;
	return (void *)1;
}

#ifdef MYMODULETEST
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

