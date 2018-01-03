#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "logx.h"
#include "paramsDb.h"

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

void printTboxHelp(void) {
	printf("tbox cmd [args] [target list]\n");
	printf("\tbuild on %s %s %s\n", "Linux",  __DATE__,__TIME__);
}
void printTboxSubHelp(char *buf) {
	printf("Usage of %s: TBD\n",buf);
}
void printV2Help(void) {
	printf("v2 <message flag><aid> start a v2 flowchat. i.e: v2 004B start a keep alive request.\n"
		"support flowchat(message flag, aid, zh-cn in utf-8)\n"
		"\t0x00 0x01*注册绑定              \n"
		"\t0x00 0x02*登录                  \n"
		"\t0x00 0x03*登出[预留]            \n"
		"\t0x00 0x04*重新登录[预留]        \n"
		"\t0x00 0x0B*取消息心跳[预留]      \n"
		"\t0x00 0x05 配置读取              \n"
		"\t0x00 0x07 配置下发              \n"
		"\t0x00 0x06 版本升级              \n"
		"\t0x00 0x2B 通讯保持[预留]        \n"
		"\t0x00 0x4B*持续活跃              \n"
		"\t0x01 0xF1*车辆控制下发          \n"
		"\t0x01 0xF2 Can数据采集上报[预留] \n"
		"\t0x01 0xF3 故障状态上报          \n"
		"\t0x01 0xF4 远程诊断[预留]        \n"
		"\t0x01 0xF5*车辆状态数据上报      \n"
		"\t0x01 0xF6*E-Call服务            \n"
		"\t0x01 0xF7 高频数据上报          \n"
		"\t0x01 0xF8 Wifi网络通道控制      \n"
		"\t0x01 0xF9 流量上报[预留]        \n"
		"\t0x01 0xFA Wifi开关控制          \n"
		"\t0x04 0xE1 国标车辆登入[预留]    \n"
		"\t0x04 0xE2 国标车辆登出[预留]    \n"
		"\t0x04 0xE3 国标补发信息上报[预留]\n"
		"\t0x03 0x01 终端校时              \n"
		"\t0x01 0xFB 故障信号上报[预留]    \n"
		"\n");
}
void printV2SubHelp(char *buf) {
	printf("Usage of %s: TBD\n",buf);
}
void printCustomerHelp(void) {
	printf("\nInternal commands usage:\n"
		"\tlogadd<logfile> add xx.c to log show list\n"
		"\tlogrm<logfile> rm xx.c from log show list\n"
		"\tloglist list log show list\n"
		"\tloglevel[n] n=0~8\n"
		"\tdebugon\n"
		"\tdebugoff\n"
		"\tv2 <message flag><aid> start a v2 flowchat. i.e: v2 004B start a keep alive request.\n"
		"\tv2 help show v2's support list.\n"
		"\n");
}

extern void taskOtaV2InsertRequest(int ma, int mid);
extern void dumpConfigParams( void );
void parseV2Command(char *buf, int len) {
	int adv;
	int ma=xatoiad(buf,&adv);
	int mid=0;
	if(ma<1)
		return;
	int msgFlag=(ma>>8)&0xFF;
	int aid=(ma)&0xFF;
	while(adv<len && (buf[adv]==' '||buf[adv]=='\t'))
		adv++;
	if(buf[adv]!='\0') {
		mid=xatoi(buf+adv) & 0xFF;
	}
	printf("V2 msgFlag=%d aid=0x%02X mid=%d\n",msgFlag,aid,mid);
	taskOtaV2InsertRequest(ma,mid);	
}
#define cmpn(n,str) (0==strncmp(buf,str,pos=n))
#define cmp(str) (0==strcmp(buf,str))
int parseCommandBufferApp(char *buf, int len) {
	if(len>1&&buf[len-1]=='\n') {
		buf[len-1]='\0';//convert tail from '\n' to '\0'.
		len--;
	}

	int pos=0;
	if(cmpn(8,"loglevel") || cmpn(9,"loglevel ")) {
		if('0'<=buf[pos]&&buf[pos]<='8')//else ignore this.
			logSetTTYLevel(buf[pos]-'0');
		printf("Log level: %d\n",logGetTTYLevel());
		return 0;
	}
	if(cmpn(6,"logadd") || cmpn(7,"logadd ")) {
		if(strlen(buf+pos)>2)
			logAddModule(buf+pos);
		return 0;
	}
	if(cmpn(5,"logrm") || cmpn(6,"logrm ")) {
		if(strlen(buf+pos)>2)
			logRmModule(buf+pos);
		return 0;
	}
	if(cmp("loglist")) {
		logListModules();
		return 0;
	}
	if(cmp("debugon")) {
		logSetDebugLevel(1);
		printf("Debug mode on\n");
		return 0;
	}
	if(cmp("debugoff")) {
		logSetDebugLevel(0);
		return 0;
	}
	if(cmp("debug")) {
		pos=logSetDebugLevel(-1);
		printf("Debug mode %s\n",pos==0?"off":"on");
		return 0;
	}
	if(cmp("list")) {
		dumpConfigParams();
		return 0;
	}
	if(cmp("tbox")) {//reserved for future usage.
		printTboxHelp();
		return 0;
	}
	if(cmpn(5,"tbox ")) {//reserved for future usage.
		if(strlen(buf+pos)>=1)
			printTboxSubHelp(buf+pos);
		return 0;
	}
	if(cmpn(8,"v2 help ")) {
		if(strlen(buf+pos)>2)
			printV2SubHelp(buf+pos);
		return 0;
	}
	if(cmp("v2 help")) {
		printV2Help();
		return 0;
	}
	if(cmp("v2 report")) {
		taskOtaV2InsertRequest(0x01F5,0);
		printf("\nReport will start...\n");
		return 0;
	}
	if(cmp("v2 ecall")) {
		taskOtaV2InsertRequest(0x01F6,0);
		printf("\nEcall will start...\n");
		return 0;
	}
	if(cmp("v2 upgrade")) {
		taskOtaV2InsertRequest(0x06,0);
		printf("\nUpgrade will start...\n");
		return 0;
	}
	if(cmp("v2 time")) {
		taskOtaV2InsertRequest(0x0301,0);
		printf("\nUpdate will start...\n");
		return 0;
	}
	if(cmpn(8,"v2 heart")) {
		taskOtaV2InsertRequest(0x000B,0);
		printf("\nHeartbeat will start...\n");
		return 0;
	}
	if(cmpn(3,"v2 ")) {
		if(strlen(buf+pos)>=1)
			parseV2Command(buf+pos,len-pos);
		return 0;
	}
	if(cmp("v2")) {
		taskOtaV2InsertRequest(0,0);	
		printf("\ntype v2 help for more information\n");
		return 0;
	}

	return -1;
}
