/*
============================================================================
Name        : 2048.c
Author      : Maurits van der Schee
Description : Console version of the game "2048" for GNU/Linux
============================================================================
*
Note by Zhengmingpei,China
Time:2014.10.13
Contact:http://Zhengmingpei.github.com
Email:yueyawanbian@gmail.com
*/
 
#define _XOPEN_SOURCE 500
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <termios.h>
#include <stdbool.h>
#include <stdint.h>
#include <time.h>
#include <signal.h>
 
#define SIZE 4
uint32_t score=0;
uint8_t scheme=0;

/**
printf's notice  <esc>=="\033[" :ASCII转义字符 27(1Bh)
none         = "\033[0m"
black        = "\033[0;30m"
dark_gray    = "\033[1;30m"
blue         = "\033[0;34m"
light_blue   = "\033[1;34m"
green        = "\033[0;32m"
light_green -= "\033[1;32m"
cyan         = "\033[0;36m"
light_cyan   = "\033[1;36m"
red          = "\033[0;31m"
light_red    = "\033[1;31m"
purple       = "\033[0;35m"
light_purple = "\033[1;35m"
brown        = "\033[0;33m"
yellow       = "\033[1;33m"
light_gray   = "\033[0;37m"
white        = "\033[1;37m"
字背景颜色范围: 40--49     字颜色: 30--39
                40: 黑             30: 黑
                41:红              31: 红
                42:绿              32: 绿
                43:黄              33: 黄
                44:蓝              34: 蓝
                45:紫              35: 紫
                46:深绿            36: 深绿
                47:白色            37: 白色

输出特效格式控制：
\033[0m   关闭所有属性
\033[1m   设置高亮度
\033[2m   设置低亮度
\033[3m   设置斜体
\033[4m   下划线
\033[5m   闪烁
\033[6m   快闪
\033[7m   反显
\033[8m   消隐
\033[30m   --   \033[37m   设置前景色
\033[40m   --   \033[47m   设置背景色

光标位置等的格式控制：
\033[nA   光标上移n行
\033[nB   光标下移n行
\033[nC   光标右移n行
\033[nD   光标左移n行
\033[y;xH 设置光标位置
\033[2J   清屏
\033[K    清除从光标到行尾的内容
\033[s    保存光标位置
\033[u    恢复光标位置
\033[?25l 隐藏光标
\033[?25h 显示光标
\033[y;xf 设置光标位置

printf的格式控制的完整格式：
% - 0 m.n l或h 格式字符

下面对组成格式说明的各项加以说明：
①%：表示格式说明的起始符号，不可缺少。
②-：有-表示左对齐输出，如省略表示右对齐输出。
③0：有0表示指定空位填0,如省略表示指定空位不填。
④m.n：m指域宽，即对应的输出项在输出设备上所占的字符数。N指精度。用于说明输出的实型数的小数位数。为指定n时，隐含的精度为n=6位。
⑤l或h:l对整型指long型，对实型指double型。h用于将整型的格式字符修正为short型。

格式字符:格式字符用以指定输出项的数据类型和输出格式。
①d格式：用来输出十进制整数。有以下几种用法：
    %d：按整型数据的实际长度输出。
    %md：m为指定的输出字段的宽度。如果数据的位数小于m，则左端补以空格，若大于m，则按实际位数输出。
    %ld：输出长整型数据。
②o格式：以无符号八进制形式输出整数。对长整型可以用"%lo"格式输出。同样也可以指定字段宽度用“%mo”格式输出。
③x格式：以无符号十六进制形式输出整数。对长整型可以用"%lx"格式输出。同样也可以指定字段宽度用"%mx"格式输出。
④u格式：以无符号十进制形式输出整数。对长整型可以用"%lu"格式输出。同样也可以指定字段宽度用“%mu”格式输出。
⑤c格式：输出一个字符。
⑥s格式：用来输出一个串。有几中用法
    %s：例如:printf("%s","CHINA")输出"CHINA"字符串（不包括双引号）。
    %ms：输出的字符串占m列，如字符串本身长度大于m，则突破获m的限制,将字符串全部输出。若串长小于m，则左补空格。
    %-ms：如果串长小于m，则在m列范围内，字符串向左靠，右补空格。
    %m.ns：输出占m列，但只取字符串中左端n个字符。这n个字符输出在m列的右侧，左补空格。
    %-m.ns：其中m、n含义同上，n个字符输出在m列范围的左侧，右补空格。如果n>m，则自动取n值，即保证n个字符正常输出。
⑦f格式：用来输出实数（包括单、双精度），以小数形式输出。有以下几种用法：
    %f：不指定宽度，整数部分全部输出并输出6位小数。
    %m.nf：输出共占m列，其中有n位小数，如数值宽度小于m左端补空格。
    %-m.nf：输出共占n列，其中有n位小数，如数值宽度小于m右端补空格。
⑧e格式：以指数形式输出实数。可用以下形式：
    %e：数字部分（又称尾数）输出6位小数，指数部分占5位或4位。
    %m.ne和%-m.ne：m、n和”-”字符含义与前相同。此处n指数据的数字部分的小数位数，m表示整个输出数据所占的宽度。
⑨g格式：自动选f格式或e格式中较短的一种输出，且不输出无意义的零。



*/
// 根据value获取相应的颜色，将包含设置终端颜色的字符串复制给color
void getColor(uint16_t value, char *color, size_t length) {
	// 声明三个颜色数组，用一维数组，但每个奇数位和偶数位组成一个前后景色
	// 后两个数组分别对应程序的启动选项"blackwhite","bluered"
	uint8_t original[] = {8,255,1,255,2,255,3,255,4,255,5,255,6,255,7,255,9,0,10,0,11,0,12,0,13,0,14,0,255,0,255,0};
	uint8_t blackwhite[] = {232,255,234,255,236,255,238,255,240,255,242,255,244,255,246,0,248,0,249,0,250,0,251,0,252,0,253,0,254,0,255,0};
	uint8_t bluered[] = {235,255,63,255,57,255,93,255,129,255,165,255,201,255,200,255,199,255,198,255,197,255,196,255,196,255,196,255,196,255,196,255};
	uint8_t *schemes[] = {original,blackwhite,bluered};
	uint8_t *background = schemes[scheme]+0;
	uint8_t *foreground = schemes[scheme]+1;
	if (value > 0) while (value >>= 1)
	// value不断右移一位，直到值变为0，实现每个二进制一个不同的颜色
	{
		if (background+2<schemes[scheme]+sizeof(original)) {
			background+=2;
			foreground+=2;
		}
	}
	//linux下终端及字体颜色设置语句的字符串
	snprintf(color,length,"\033[38;5;%d;48;5;%dm",*foreground,*background);
}
 
// 绘制数据板,数据板共3×4行，7×4列
void drawBoard(uint16_t board[SIZE][SIZE]) {
	int8_t x,y;
	// \033[m:关闭所有属性
	char color[40], reset[] = "\033[m";
	// \033[H:调整光标位置
	printf("\033[H");
 
	printf("2048.c %17d pts\n\n",score);
 
	//数据板共3×4行，7×4列
	for (y=0;y<SIZE;y++) {
		//首行打印空白
		for (x=0;x<SIZE;x++) {
			getColor(board[x][y],color,40);
			printf("%s",color);
			printf("       ");
			//reset 重置，避免对非数据板部分造成影响
			printf("%s",reset);
		}
		printf("\n");
		//次行打印数字,数字居中
		for (x=0;x<SIZE;x++) {
			getColor(board[x][y],color,40);
			printf("%s",color);
			if (board[x][y]!=0) {
				char s[8];
				//此处注意，是board[x][y]而不是yx
				snprintf(s,8,"%u",board[x][y]);
				int8_t t = 7-strlen(s);
				printf("%*s%s%*s",t-t/2,"",s,t/2,"");
			} else {
				printf("   ·   ");
			}
			printf("%s",reset);
		}
		printf("\n");
		//末行打印空白
		for (x=0;x<SIZE;x++) {
			getColor(board[x][y],color,40);
			printf("%s",color);
			printf("       ");
			printf("%s",reset);
		}
		printf("\n");
	}
	printf("\n");
	printf("        ←,↑,→,↓ or q        \n");
	//疑似回车
	printf("\033[A");
}
 
// 查找一维数组中x左侧待合并数的坐标，stop为检查点
int8_t findTarget(uint16_t array[SIZE],int8_t x,int8_t stop) {
	int8_t t;
	//若x为第一个数，左边无数，直接返回x 
	if (x==0) {
		return x;
	}
	//遍历x左边的坐标
	for(t=x-1;t>=0;t--) {
		//合并算法：
		//1.t处的数不为0且与x处的数不相等，返回t+1
		//2.t处的数不为0且与x处的数相等，返回t
		//3.t处的数为0，根据stop判断是否向前查找，防止多次合并
		if (array[t]!=0) {
			if (array[t]!=array[x]) {
				// merge is not possible, take next position
				return t+1;
			}
			return t;
		} else {
			// we should not slide further, return this one
			if (t==stop) {
				return t;
			}
		}
	}
	// we did not find a
	return x;
}
 
//对一维数组进行移动
bool slideArray(uint16_t array[SIZE]) {
	bool success = false;
	//声明当前位置，待合并的位置，检查点
	int8_t x,t,stop=0;
 
	for (x=0;x<SIZE;x++) {
		if (array[x]!=0) {
			t = findTarget(array,x,stop);
			// 如果待合并的位置与当前位置不相等，进行移动或者合并
			// if target is not original position, then move or merge
			if (t!=x) {
				// 如果待合并的位置不是0,右移检查点stop
				// if target is not zero, set stop to avoid double merge
				if (array[t]!=0) {
					score+=array[t]+array[x];
					stop = t+1;
				}
				array[t]+=array[x];
				array[x]=0;
				success = true;
			}
		}
	}
	return success;
}
 
//旋转数据板，向右旋转90度，这样可以用一个方向的数组移动间接控制四个方向的移动
void rotateBoard(uint16_t board[SIZE][SIZE]) {
	int8_t i,j,n=SIZE;
	uint16_t tmp;
	//环形旋转，先外而内，先左后右
	for (i=0; i<n/2; i++){
		for (j=i; j<n-i-1; j++){
			tmp = board[i][j];
			board[i][j] = board[j][n-i-1];
			board[j][n-i-1] = board[n-i-1][n-j-1];
			board[n-i-1][n-j-1] = board[n-j-1][i];
			board[n-j-1][i] = tmp;
		}
	}
}
 
//向上移动数据板
bool moveUp(uint16_t board[SIZE][SIZE]) {
	bool success = false;
	int8_t x;
	for (x=0;x<SIZE;x++) {
		//对每一列做移动或者合并处理，
		//这里是列而不是行，与前面的输出顺序有关
		success |= slideArray(board[x]);
		//只要有一列成功，就成功
	}
	return success;
}
 
// 左移：向右旋转90度，向上合并，再旋转3个90度
bool moveLeft(uint16_t board[SIZE][SIZE]) {
	bool success;
	rotateBoard(board);
	success = moveUp(board);
	rotateBoard(board);
	rotateBoard(board);
	rotateBoard(board);
	return success;
}
 
// 下移：向右旋转2个90度，向上合并，再旋转2个90度
bool moveDown(uint16_t board[SIZE][SIZE]) {
	bool success;
	rotateBoard(board);
	rotateBoard(board);
	success = moveUp(board);
	rotateBoard(board);
	rotateBoard(board);
	return success;
}
 
// 右移：向右旋转3个90度，向上合并，再旋转1个90度
bool moveRight(uint16_t board[SIZE][SIZE]) {
	bool success;
	rotateBoard(board);
	rotateBoard(board);
	rotateBoard(board);
	success = moveUp(board);
	rotateBoard(board);
	return success;
}
 
bool findPairDown(uint16_t board[SIZE][SIZE]) {
	bool success = false;
	int8_t x,y;
	for (x=0;x<SIZE;x++) {
		for (y=0;y<SIZE-1;y++) {
			if (board[x][y]==board[x][y+1]) return true;
		}
	}
	return success;
}
 
// 计算数据板是否已满
int16_t countEmpty(uint16_t board[SIZE][SIZE]) {
	int8_t x,y;
	int16_t count=0;
	for (x=0;x<SIZE;x++) {
		for (y=0;y<SIZE;y++) {
			if (board[x][y]==0) {
				count++;
			}
		}
	}
	return count;
}
 
// 检查游戏是否结束
bool gameEnded(uint16_t board[SIZE][SIZE]) {
	bool ended = true;
	// 如果有空位，未结束
	if (countEmpty(board)>0) return false;
	// 横向检查，有相等相邻数，未结束
	if (findPairDown(board)) return false;
	rotateBoard(board);
	// 旋转一次，纵向检查，有相等相邻数，未结束
	if (findPairDown(board)) ended = false;
	rotateBoard(board);
	rotateBoard(board);
	rotateBoard(board);
	return ended;
}
 
// 随机重置数据板
void addRandom(uint16_t board[SIZE][SIZE]) {
	// 全局变量，是否已初始化
	static bool initialized = false;
	// x,y 坐标
	int8_t x,y;
	// r 随机位置，len 所有为空的数据板数据长度
	int16_t r,len=0;
	// n 随机数据， list 所有为空的数据板位置
	uint16_t n,list[SIZE*SIZE][2];
 
	if (!initialized) {
		srand(time(NULL));
		initialized = true;
	}
 
	// 找出数据板上所有为空的坐标
	for (x=0;x<SIZE;x++) {
		for (y=0;y<SIZE;y++) {
			if (board[x][y]==0) {
				list[len][0]=x;
				list[len][1]=y;
				len++;
			}
		}
	}
 
	// 如果有为空的情况，才填充数据
	if (len>0) {
		r = rand()%len;
		x = list[r][0];
		y = list[r][1];
		n = ((rand()%10)/9+1)*2;
		board[x][y]=n;
	}
}
 
// 设置输入模式，在行缓冲和无缓冲中切换
void setBufferedInput(bool enable) {
	static bool enabled = true;
	static struct termios old;
	struct termios new;
 
	if (enable && !enabled) {
		// restore the former settings
		tcsetattr(STDIN_FILENO,TCSANOW,&old);
		// set the new state
		enabled = true;
	} else if (!enable && enabled) {
		// get the terminal settings for standard input
		tcgetattr(STDIN_FILENO,&new);
		// we want to keep the old setting to restore them at the end
		old = new;
		// disable canonical mode (buffered i/o) and local echo
		new.c_lflag &=(~ICANON & ~ECHO);
		// set the new settings immediately
		tcsetattr(STDIN_FILENO,TCSANOW,&new);
		// set the new state
		enabled = false;
	}
}
 
int test() {
	uint16_t array[SIZE];
	uint16_t data[] = {
		0,0,0,2,	2,0,0,0,
		0,0,2,2,	4,0,0,0,
		0,2,0,2,	4,0,0,0,
		2,0,0,2,	4,0,0,0,
		2,0,2,0,	4,0,0,0,
		2,2,2,0,	4,2,0,0,
		2,0,2,2,	4,2,0,0,
		2,2,0,2,	4,2,0,0,
		2,2,2,2,	4,4,0,0,
		4,4,2,2,	8,4,0,0,
		2,2,4,4,	4,8,0,0,
		8,0,2,2,	8,4,0,0,
		4,0,2,2,	4,4,0,0
	};
	uint16_t *in,*out;
	uint16_t t,tests;
	uint8_t i;
	bool success = true;
 
	tests = (sizeof(data)/sizeof(data[0]))/(2*SIZE);
	for (t=0;t<tests;t++) {
		in = data+t*2*SIZE;
		out = in + SIZE;
		for (i=0;i<SIZE;i++) {
			array[i] = in[i];
		}
		slideArray(array);
		for (i=0;i<SIZE;i++) {
			if (array[i] != out[i]) {
				success = false;
			}
		}
		if (success==false) {
			for (i=0;i<SIZE;i++) {
				printf("%d ",in[i]);
			}
			printf("=> ");
			for (i=0;i<SIZE;i++) {
				printf("%d ",array[i]);
			}
			printf("expected ");
			for (i=0;i<SIZE;i++) {
				printf("%d ",in[i]);
			}
			printf("=> ");
			for (i=0;i<SIZE;i++) {
				printf("%d ",out[i]);
			}
			printf("\n");
			break;
		}
	}
	if (success) {
		printf("All %u tests executed successfully\n",tests);
	}
	return !success;
}
 
void signal_callback_handler(int signum) {
	printf("         TERMINATED         \n");
	setBufferedInput(true);
	printf("\033[?25h");
	exit(signum);
}
 
int main(int argc, char *argv[]) {
	uint16_t board[SIZE][SIZE];
	char c;
	bool success;
 
	if (argc == 2 && strcmp(argv[1],"test")==0) {
		return test();
	}
	if (argc == 2 && strcmp(argv[1],"blackwhite")==0) {
		scheme = 1;
	}
	if (argc == 2 && strcmp(argv[1],"bluered")==0) {
		scheme = 2;
	}
	
	// 33[?25l 隐藏光标
	// 33[2J 清屏
	// 33[H 设置光标位置
	printf("\033[?25l\033[2J\033[H");
 
	// register signal handler for when ctrl-c is pressed
	signal(SIGINT, signal_callback_handler);
 
	// 将数据清为0
	memset(board,0,sizeof(board));
	// 添加两次随机数,因为初始化时产生2个随机数
	addRandom(board);
	addRandom(board);
	// 绘制数据板
	drawBoard(board);
	// 禁用缓存输入，终端支持按字符读取且不回显
	setBufferedInput(false);
	// 游戏主循环
	while (true) {
		c=getchar();
		switch(c) {
			case 97:	// 'a' key
			case 104:	// 'h' key
			case 68:	// left arrow
				success = moveLeft(board);  break;
			case 100:	// 'd' key
			case 108:	// 'l' key
			case 67:	// right arrow
				success = moveRight(board); break;
			case 119:	// 'w' key
			case 107:	// 'k' key
			case 65:	// up arrow
				success = moveUp(board);    break;
			case 115:	// 's' key
			case 106:	// 'j' key
			case 66:	// down arrow
				success = moveDown(board);  break;
			default: success = false;
		}
		//合并成功，则重新绘制
		if (success) {
			drawBoard(board);
			usleep(150000);
			addRandom(board);
			drawBoard(board);
			if (gameEnded(board)) {
				printf("         GAME OVER          \n");
				break;
			}
		}
		// 如果输入是 q 的话，打开行缓冲，显示光标
		if (c=='q') {
			printf("        QUIT? (y/n)         \n");
			while (true) {
				c=getchar();
				if (c=='y'){
					setBufferedInput(true);
					printf("\033[?25h");
					exit(0);
				}
				else {
					drawBoard(board);
					break;
				}
			}
		}
		if (c=='r') {
			printf("       RESTART? (y/n)       \n");
			while (true) {
				c=getchar();
				if (c=='y'){
					memset(board,0,sizeof(board));
					addRandom(board);
					addRandom(board);
					drawBoard(board);
					break;
				}
				else {
					drawBoard(board);
					break;
				}
			}
		}
	}
	setBufferedInput(true);
 
	printf("\033[?25h");
 
	return EXIT_SUCCESS;
}

//--------------------- 
//作者：月牙湾边 
//来源：CSDN 
//原文：https://blog.csdn.net/yueyawanbian/article/details/40260393 
//版权声明：本文为博主原创文章，转载请附上博文链接！

