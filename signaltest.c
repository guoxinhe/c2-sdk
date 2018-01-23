#include <stdlib.h>
#include <stdio.h>  
#include <signal.h>
#include <string.h>
 
static const char *killList={
   /*0--------------F0--------------F0--------------F0--------------F0--------------F*/
    " 1) SIGHUP       2) SIGINT       3) SIGQUIT      4) SIGILL       5) SIGTRAP     "
    " 6) SIGABRT      7) SIGBUS       8) SIGFPE       9) SIGKILL     10) SIGUSR1     "
    "11) SIGSEGV     12) SIGUSR2     13) SIGPIPE     14) SIGALRM     15) SIGTERM     "
    "16) SIGSTKFLT   17) SIGCHLD     18) SIGCONT     19) SIGSTOP     20) SIGTSTP     "
    "21) SIGTTIN     22) SIGTTOU     23) SIGURG      24) SIGXCPU     25) SIGXFSZ     "
    "26) SIGVTALRM   27) SIGPROF     28) SIGWINCH    29) SIGIO       30) SIGPWR      "
    "31) SIGSYS      32) --------    33) --------    34) SIGRTMIN    35) SIGRTMIN+1  "
    "36) SIGRTMIN+2  37) SIGRTMIN+3  38) SIGRTMIN+4  39) SIGRTMIN+5  40) SIGRTMIN+6  "
    "41) SIGRTMIN+7  42) SIGRTMIN+8  43) SIGRTMIN+9  44) SIGRTMIN+10 45) SIGRTMIN+11 "
    "46) SIGRTMIN+12 47) SIGRTMIN+13 48) SIGRTMIN+14 49) SIGRTMIN+15 50) SIGRTMAX-14 "
    "51) SIGRTMAX-13 52) SIGRTMAX-12 53) SIGRTMAX-11 54) SIGRTMAX-10 55) SIGRTMAX-9  "
    "56) SIGRTMAX-8  57) SIGRTMAX-7  58) SIGRTMAX-6  59) SIGRTMAX-5  60) SIGRTMAX-4  "
    "61) SIGRTMAX-3  62) SIGRTMAX-2  63) SIGRTMAX-1  64) SIGRTMAX                    "
};
int nrTry=0; 
struct sigaction act = {0};  
struct sigaction actusr = {0};  

char sigDesc[256];
void fillSigDesc(int s) {
    if(s<1||s>64) {
	sprintf(sigDesc,"%2d) Unknown",s);
	return;
    }
    s--;
    strncpy(sigDesc,killList+s*16,15);
    sigDesc[sizeof(sigDesc)-1]='\0';
    //printf("Signal %s\n",sigDesc);
}

void handusr(int s){
    fillSigDesc(s);
        printf("#%d User signal handler #%d on signal %s\n",getpid(), nrTry, sigDesc);
	nrTry++;
}  
  
void hand(int s){  
    fillSigDesc(s);
    if(s == 2)  {
        printf("#%d Common signal handler #%d on signal %s\n",getpid(), nrTry, sigDesc);
	nrTry++;
	if(nrTry>6) {
        	printf("Common signal handler exit\n");
		exit(0);
	}
    }
}  
  
void hander(int s,siginfo_t* info,void* buff){
    fillSigDesc(s);
    if(s == 2){  
        printf("#%d Advanced signal handler #%d on signal %s\n",getpid(), nrTry, sigDesc);
        printf("pid:%d,uid:%d\n",info->si_pid,info->si_uid);  
        printf("int:%x\n",info->si_int);  
        printf("ptr:%s\n",(char*)info->si_ptr);  
        printf("addr:%p\n",info->si_addr);  
        printf("buff:%d\n",*( (int*)buff ) ); 
	nrTry++;
	if(nrTry>3) {
		act.sa_handler = hand; 
		act.sa_flags = 0;
        	printf("Advanced signal handler switch to common signal handler\n");  
    		sigaction(2,&act,NULL);  
	}
    }  
}  
  
int main(){  
  
    act.sa_handler = hand;  
    act.sa_sigaction = hander;  
    act.sa_flags = SA_SIGINFO;  
    sigaction(2,&act,NULL);  
  
    actusr.sa_handler = handusr;
    int i;
    for(i=1;i<=64;i++) {
        if(i!=2)
	        sigaction(i,&actusr,NULL);
        //sigaction(SIGUSR1,&actusr,NULL);
        //sigaction(SIGTERM,&actusr,NULL);
        //sigaction(SIGKILL,&actusr,NULL);
    }

    int pid=getpid();
    printf("My pid is %d\n",pid);  
    while(1) {
	//pause();
	sleep(1);
	//printf("kill send to pid=%d signal SIGUSR1(%d)\n",pid,SIGUSR1);
	//kill(pid,SIGUSR1);
	
    }
    return 0;  
}  
