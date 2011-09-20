#!/usr/bin/env python

import sha, time, Cookie, os, cgitb, cgi
import sys
import cPickle
import shutil
import tempfile
import re
import calendar
import fcntl
import signal
import string
import pprint
import getopt
import threading
import Queue
import random
import stat
import traceback
import inspect
from subprocess import Popen, STDOUT, PIPE
from UserDict import UserDict


#get cookie, form post, form get, etc.
#--------------------------------------------------------------------------
#put here, not in a function,otherwise my system does not work.
home_link = 'project.cgi'
home_fold = '/var/www/html/build'
db_path='/home/hguo'
db_file='sdk/c2liclist'
db_list=[];

form      = cgi.FieldStorage()
method    = form.getfirst('method', 'empty');       method = cgi.escape(method);
loginuser = form.getfirst('loginuser', 'empty'); loginuser = cgi.escape(loginuser);
loginpswd = form.getfirst('loginpswd', 'empty'); loginpswd = cgi.escape(loginpswd);
op  = form.getfirst('op',  'empty');  op  = cgi.escape(op);
ord = form.getfirst('ord', 'empty');  ord = cgi.escape(ord);
rvs = form.getfirst('rvs', 'empty');  rvs = cgi.escape(rvs);
prj = form.getfirst('prj', 'empty');  prj = cgi.escape(prj);
mod = form.getfirst('mod', 'empty');  mod = cgi.escape(mod);
thm = form.getfirst('thm', 'empty');  thm = cgi.escape(thm);
dbg = form.getfirst('dbg', 'empty');  dbg = cgi.escape(dbg);
hrf = '';
cookie = Cookie.SimpleCookie()
string_cookie = os.environ.get('HTTP_COOKIE')
sid =sha.new(repr(time.time())).hexdigest()
user='guest'
pswd='empty'
debug='off'
lastorder=ord
my_error_message = '';
my_error_number = 0;


def evalute_cookie():
    global form
    global method
    global loginuser
    global loginpswd
    global op
    global ord
    global rvs
    global prj
    global mod
    global thm
    global dbg
    global hrf
    global cookie
    global string_cookie
    global sid
    global user
    global pswd
    global debug
    global lastorder
    global my_error_message
    global my_error_number

    # If new session
    if not string_cookie:
        # The sid will be a hash of the server time
        sid = sha.new(repr(time.time())).hexdigest()
        user='guest'
        pswd='empty'
        debug='off'
        # Set the sid in the cookie
        cookie['sid'] = sid
        cookie['user'] = user
        cookie['pswd'] = pswd
        cookie['debug'] = debug
        cookie['lastorder'] = ord
        # Will expire in a year
        cookie['sid']['expires'] = 12 * 30 * 24 * 60 * 60
        cookie['user']['expires'] = 12 * 30 * 24 * 60 * 60
        cookie['pswd']['expires'] = 12 * 30 * 24 * 60 * 60
        cookie['lastorder']['expires'] = 12 * 30 * 24 * 60 * 60
    # If already existent session
    else:
        cookie.load(string_cookie)
	try:
            sid = cookie['sid'].value
        except KeyError:
            sid = sha.new(repr(time.time())).hexdigest()
	try:
            user= cookie['user'].value
        except KeyError:
            user='guest'
	try:
            pswd= cookie['pswd'].value
        except KeyError:
            pswd='empty'
	try:
            debug=cookie['debug'].value
        except KeyError:
            debug='off'
	try:
            lastorder=cookie['lastorder'].value
        except KeyError:
            lastorder=ord
        if op == 'loginack' and loginuser <> 'empty' and  method == 'post':
            if loginpswd <> '123456':
                loginpswd='fail';
                my_error_number=my_error_number+1;
                my_error_message=my_error_message+'bad password, always is 123456<br>';
            if os.path.exists('/home/'+loginuser):
                pass
            else:
                my_error_number=my_error_number+1;
                my_error_message=my_error_message+'bad user name<br>';
            if my_error_number == 0:
                user=loginuser
                pswd=loginpswd
                cookie['user'] = user
                cookie['pswd'] = pswd
                cookie['user']['expires'] = 12 * 30 * 24 * 60 * 60
                cookie['pswd']['expires'] = 12 * 30 * 24 * 60 * 60
        elif op == 'logout' :
            user='guest'
            pswd='empty'
            cookie['user'] = user
            cookie['pswd'] = pswd
            cookie['user']['expires'] = 12 * 30 * 24 * 60 * 60
            cookie['pswd']['expires'] = 12 * 30 * 24 * 60 * 60
        elif op == 'debug':
            if dbg == 'empty':
                if debug == 'on':
                    dbg='off';
                elif debug == 'off':
                    dbg='on';
        if dbg == 'on':
            debug='on';
            cookie['debug'] = debug
            cookie['debug']['expires'] = 12 * 30 * 24 * 60 * 60
        elif dbg == 'off':
            debug='off';
            cookie['debug'] = debug
            cookie['debug']['expires'] = 12 * 30 * 24 * 60 * 60
        #if ord != 'empty':
        cookie['lastorder'] = ord
        cookie['lastorder']['expires'] = 12 * 30 * 24 * 60 * 60

        if (op=='liclist') or (op=='liclistall'):
             if (ord=='empty') : 
                 rvs='False';
                 lastorder='empty';
             elif (ord!=lastorder) :
                 rvs='False';
             else:
                 if rvs== 'False':
                    rvs = 'True';
                 else:
                    rvs = 'False';
        if (rvs!='False') and (rvs!='True'):
            rvs = 'False';
                    
        
def evalute_inputs():
    return 0;
def evalute_action():
    return 0;
def evalute_theme():
    return 0;
def load_user_profile():
    return 0;

def create_html_links():
    print """
        | <a href=http://10.16.13.195/build/build.cgi>195 build</a>
        | <a href=http://10.16.13.196/build/build.cgi>196 build</a>"""
    print '|<a href=%s?op=liclist>License</a>' % (home_link)
    print '|<a href=%s?op=liclistall>Detail License</a>' % (home_link);
    if user == 'guest':
        print '|<a href=%s?op=login>login</a>' % (home_link);
    else:
        print '|<a href=%s?op=logout>logout</a>' % (home_link);
        print '<font color=blue><b>',user,'</b></font>';
    print '|<a href=%s?op=debug>debug</a>' % (home_link);
    print "|<a href='###' onclick=\"openShutManager(this,"
    print "'cgidebuginfo',false,'cgi debug off','cgi debug on')\">cgi debug info</a>" 

    return 0;
def create_html_css(theme='default'):
    print """\
        <style type="text/css">
        <!--/* <![CDATA[ */
    """

    print """\
        <!--

        .tbhide      {background: white;  }
        .trhide   {padding: .3em; }

        .tbbig {background: white;  border-collapse: collapse; font-family: Arial }

        .trtitle   {background: #DDDDDD; font-weight:bold}
        .treven    {background: #F8FFFF; }
        .trodd     {background: #FFFFFF; }

        .tdbig    {padding-left: .2em; padding-right: .2em;border: 1px #00C000 solid; }
        .basic    {padding-left: .2em; padding-right: .2em;border: 1px #00C000 solid; background: #40ff40; font-weight:bold}
        .premium  {padding-left: .2em; padding-right: .2em;border: 1px #00C000 solid; background: #ffff00; font-weight:bold}
        .advanced {padding-left: .2em; padding-right: .2em;border: 1px #00C000 solid; background: #ff4040; font-weight:bold}
        .disabled {padding-left: .2em; padding-right: .2em;border: 1px #00C000 solid; background: #0000FF; font-weight:bold}
        -->
        """
    print """\
        /* ]]> */-->
        </style>
    """

def create_html_javascript():
    java_text="""
    <script type="text/javascript">
    function openShutManager(oSourceObj,oTargetObj,shutAble,oOpenTip,oShutTip){
        var sourceObj = typeof oSourceObj == "string" ? document.getElementById(oSourceObj) : oSourceObj;
        var targetObj = typeof oTargetObj == "string" ? document.getElementById(oTargetObj) : oTargetObj;
        var openTip = oOpenTip || "";
        var shutTip = oShutTip || "";
        if(targetObj.style.display!="none"){
           if(shutAble) return;
           targetObj.style.display="none";
           if(openTip  &&  shutTip){
            sourceObj.innerHTML = shutTip;
           }
        } else {
           targetObj.style.display="block";
           if(openTip  &&  shutTip){
            sourceObj.innerHTML = openTip;
           }
        }
    }
    </script>
    """
    print java_text

def create_html_welcome():
    print '<p><b><font size=+3 color=red>Welcome to this page!</font></b></p>'
    print '<p><b><font size=+2 color=blue>login for more ops</font></b></p>'
    return 0;

def create_html_debug(ison='auto'):
    if (ison=='auto'):
        if debug== 'on':
            print "<p id='cgidebuginfo' style='display:'>" 
        else:
            print "<p id='cgidebuginfo' style='display:none'>"
    elif (ison=='on'):
        print "<p id='cgidebuginfo' style='display:'>" 
    else:
        print "<p id='cgidebuginfo' style='display:none'>"
    print '<br>vars: op'    , op
    print '<br>vars: ord lastord rvs:' , ord,lastorder, rvs
    print '<br>vars: prj'   ,prj
    print '<br>vars: mod'   ,mod
    print '<br>vars: thm'   ,thm
    print '<br>vars: dbg'   ,dbg
    print '<br>vars: method',method
    print '<br>vars: loginuser=%s,loginpswd=%s' %(loginuser,loginpswd) 
    if string_cookie:
        print '<br>Already existed session:'
        print '<br>['+string_cookie+']'
        print '<br>cookie printed'
        print '<br>SID=%s, user=%s, pswd=%s,debug=%s' %(sid, user, pswd, debug)
    else :
        print '<br>first time, no login yet.'
    print '</p>';
    return 0;

def create_html_head(dbgdisplay='auto'):
    print cookie
    print 'Content-Type: text/html\n';
    print '<html>';
    print '<title>C2 data process webpage</title>'
    global thm;
    create_html_css(thm);
    print '<body>';
    create_html_javascript();
    create_html_links();
    print '<hr>';

    if not string_cookie:
       create_html_welcome();

    create_html_debug(ison=dbgdisplay);
    return 0;
def create_html_tail():
    print '<hr>';
    create_html_links();
    print '</body></html>'
    return 0;

def action_login():
    create_html_head();
    print "<p>Please login</p>";
    print """\
    <form method="post" action="%s?op=loginack">
    <input type=hidden name=op value=loginack>
    <input type=hidden name=method value=post>
    Name: <input type="text" name="loginuser">
    Password: <input type="password" name="loginpswd">
    <input type="submit" value="Submit">
    </form>
        """ % (home_link)
    create_html_tail();
    return 0;
def action_loginack():
    create_html_head();
    if my_error_number>0:
        print my_error_message;
        action_login();
        return 0;
    print "Login in correctly!<br>";
    create_html_tail();
    return 0;
def action_logout():
    create_html_head();
    print "Logout success.<br>";
    create_html_tail();
    return 0;

class C2liclist (UserDict):
    def __init__(self, build):
        UserDict.__init__(self)

        self['component'  ] = build['component'  ]
        self['release'    ] = build['release'    ]
        self['version'    ] = build['version'    ]
        self['description'] = build['description']
        self['url'        ] = build['url'        ]
        self['license'    ] = build['license'    ]
        self['licurl'     ] = build['licurl'     ]

        try:
            self['repository' ] = build['repository' ]
            self['repo_nr']=len(build['repository'])
        except KeyError:
            self['repo_nr']=0
            pass

        try:
            self['tag']    = build['tag']
        except KeyError:
            self['tag']='';
            pass
        try:
            self['type']    = build['type']
        except KeyError:
            self['type']='source';
            pass
        try:
            self['subcomp']    = build['subcomp']
        except KeyError:
            self['subcomp']='';
            pass

        try:
            self['package'    ] = build['package'    ]
            self['pckg_nr']=len(build['package'])
        except KeyError:
            self['pckg_nr']=0
            pass

        try:
            self['history']    = build['history']
            self['history'].sort(lambda x,y: cmp(x['date'], y['date']) or cmp(x['event'],y['event']), reverse=True )
            self['hist_nr']=len(build['history'])
        except KeyError:
            self['hist_nr']=0
            pass

    def fullname(self):
        return "%s-%s:%s" % (self['component'],self['subcomp'], self['version'])
    def list_element_webhead(self):
        
        print "<table class=tbhide> <tr><td class=trhide>"
        print "|<a href=%s?op=savecfg&rvs=%s&ord=%s>Save as config file</a>" % (home_link,rvs,ord)
        print "|<a href=%s?op=savexml&rvs=%s&ord=%s>Save as xml    file</a>" % (home_link,rvs,ord)
        print "|<a href=%s?op=savexls&rvs=%s&ord=%s>Save as excel  file</a>" % (home_link,rvs,ord)
        print "|<a href=%s?op=licrepo>license repository</a> " % (home_link)
        print "</td></tr></table>"

        print "<table class=tbbig> <tr class=trtitle >"
        print "    <td class=tdbig>                                 id               </td>"
        print "    <td class=tdbig><a href=%s?op=%s&rvs=%s&ord=component  >component    </a></td>" % (home_link,op,rvs)
        print "    <td class=tdbig><a href=%s?op=%s&rvs=%s&ord=subcomp    >sub-component</a></td>" % (home_link,op,rvs)
        print "    <td class=tdbig><a href=%s?op=%s&rvs=%s&ord=version    >version      </a></td>" % (home_link,op,rvs)
        print "    <td class=tdbig><a href=%s?op=%s&rvs=%s&ord=type       >type         </a></td>" % (home_link,op,rvs)
        print "    <td class=tdbig><a href=%s?op=%s&rvs=%s&ord=release    >release      </a></td>" % (home_link,op,rvs)
        print "    <td class=tdbig><a href=%s?op=%s&rvs=%s&ord=license    >license      </a></td>" % (home_link,op,rvs)
        print "    <td class=tdbig><a href=%s?op=%s&rvs=%s&ord=description>description  </a></td>" % (home_link,op,rvs)
        print "</tr>"
        pass
    def list_element_webtail(self):
        table_tail="""</table>
                   """
        print table_tail
        pass
    def list_element_webdetail(self,idx=-1,display='none'):
        if (idx % 2) == 1:
            print "<tr class=trodd>"
        else :
            print "<tr class=treven>"
        print "    <td class=tdbig> %d </td>" % idx
        print "    <td class=tdbig> %s </td>" % self['component']
        print "    <td class=tdbig> %s </td>" % self['subcomp']
        print "    <td class=tdbig> %s </td>" % self['version']
        print "    <td class=tdbig> %s </td>" % self['type']
        print "    <td class=%s> %s </td>" % (self['release'],self['release'])
        print "    <td class=tdbig> %s </td>" % self['license']
        print "    <td class=tdbig> %s      " % self['description']
        
        ahint='more'
        if display != 'none':
           ahint='less'
        print "<a href='###' onclick=\"openShutManager(this,"
        print "'more%d',false,'less','more')\">%s</a>" % (idx,ahint)
        print "<p id='more%d' style='display:%s'>" % (idx, display)

        print "    <b>url        :</b> %s " % self['url']
        print "    <br><b>license url:</b> %s " % self['licurl']
        if self['repo_nr'] > 0 :
            print "    <br> <b>repository:</b>  "
            for his in self['repository']:
                print "    <br> &nbsp; &nbsp; %s " % his['item']
        if self['pckg_nr'] > 0 :
            for his in self['package']:
                print "    <br><b>package:</b>%s " % his['name']
                print "    <br> &nbsp; &nbsp; %s " % his['type']
                print "    <br> &nbsp; &nbsp; %s " % his['cmd']

        if self['hist_nr'] > 0 :
            for his in self['history']:
                print "    <br><b>history:</b>%s " % his['date']
                print "    <br> &nbsp; &nbsp; %s " % his['event']
                print "    <br> &nbsp; &nbsp; %s " % his['log']
        print "    <br><b>tag:</b> %s " % self['tag']
        print "</p>"
        print "    </td>"
        print "</tr>"
        pass
    def list_element_tofilehead(self,fd,idx=-1):
        fd.write('#saved by python script\n');
        string="#list order: %s, order reverse=%s\n" %(ord,rvs);   fd.write(string);
        fd.write('config = [\n');
    def list_element_tofiletail(self,fd,idx=-1):
        fd.write("  #-------------------------------------------------------\n");
        fd.write('  ]\n');
    def list_element_tofile(self,fd,idx=-1):
        fd.write("       #-------------------------------------------------------\n");
        string="       { 'index'        : '%d',\n" %(idx                 );    fd.write(string);
        string="         'component'    : '%s',\n" %(self['component'   ]);    fd.write(string);
        string="         'subcomp'      : '%s',\n" %(self['subcomp'     ]);    fd.write(string);
        string="         'version'      : '%s',\n" %(self['version'     ]);    fd.write(string);
        string="         'type'         : '%s',\n" %(self['type'        ]);    fd.write(string);
        string="         'release'      : '%s',\n" %(self['release'     ]);    fd.write(string);
        string="         'license'      : '%s',\n" %(self['license'     ]);    fd.write(string);
        string="         'description'  : '%s',\n" %(self['description' ]);    fd.write(string);
        #string="        'repository'   : '%s',\n" %(self['repository'  ]);    fd.write(string);
        string="         'url'          : '%s',\n" %(self['url'         ]);    fd.write(string);
        string="         'licurl'       : '%s',\n" %(self['licurl'      ]);    fd.write(string);
        string="         'tag'          : '%s',\n" %(self['tag'         ]);    fd.write(string);

        if self['repo_nr'] > 0 :
            string="         'repository'   : [\n";                            fd.write(string);
            for his in self['repository']:
                string="               { 'item' :'%s',\n" %(his['item']);      fd.write(string);
                string="               },\n";                                  fd.write(string);
            string="           ],\n";                                          fd.write(string);
        if self['pckg_nr'] > 0 :
            string="         'package'      : [\n";                            fd.write(string);
            for his in self['package']:
                string="               { 'name' :'%s',\n" %(his['name']);      fd.write(string);
		string="                 'type' :'%s',\n" %(his['type']);      fd.write(string);
		string="                 'cmd'  :'%s',\n" %(his['cmd']);       fd.write(string);
                string="               },\n";                                  fd.write(string);
            string="           ],\n";                                          fd.write(string);

        if self['hist_nr'] > 0 :
            string="         'history'      : [\n";                            fd.write(string);
            for his in self['history']:
                string="               { 'date' :'%s',\n" %(his['date']);      fd.write(string);
                string="                 'event':'%s',\n" %(his['event']);     fd.write(string);
                string="                 'log'  :'%s',\n" %(his['log']);       fd.write(string);
                string="               },\n";                                  fd.write(string);
            string="           ],\n";                                          fd.write(string);

        fd.write( "       },\n\n");
        pass
    def list_element_toxlsxmlfile(self,fd,idx=-1):
        sid=23
        if   self['release']=='basic'      : sid=24;
        elif self['release']=='premium'    : sid=25;
        elif self['release']=='advanced'   : sid=26;
        elif self['release']=='disabled'   : sid=27;
        string="""
   <Row ss:Height="17.25">
    <Cell ss:StyleID="s23"><Data ss:Type="Number">%d</Data></Cell>
    <Cell ss:StyleID="s23"><Data ss:Type="String">%s</Data></Cell>
    <Cell ss:StyleID="s23"><Data ss:Type="String">%s</Data></Cell>
    <Cell ss:StyleID="s23"><Data ss:Type="String">%s</Data></Cell>
    <Cell ss:StyleID="s23"><Data ss:Type="String">%s</Data></Cell>
    <Cell ss:StyleID="s%d"><Data ss:Type="String">%s</Data></Cell>
    <Cell ss:StyleID="s23"><Data ss:Type="String">%s</Data></Cell>
    <Cell ss:StyleID="s23"><Data ss:Type="String">%s</Data></Cell>
   </Row>""" % (idx,
                self['component'   ],\
                self['subcomp'     ],\
                self['version'     ],\
                self['type'        ],\
            sid,self['release'     ],\
                self['license'     ],\
                self['description' ] )
        if (fd != 0) and (string!=''):
            try:
                fd.write(string);
            except:
                print "Error: can not write to file"
        pass
def dbf_update_database():
    global db_path, db_file, db_list
    sys.path.append(db_path)
    sys.path.insert(0, "");
    try :
        conf = __import__(db_file);
    except:
        print "Error importing", db_file, ":", sys.exc_info()[:2]
        raise
    del sys.path[0]
    db_list = [C2liclist(b) for b in conf.config];

    myreverse=False
    if (rvs=='True'):
        myreverse=True;
    if ord == 'component':
        db_list.sort(lambda x,y: cmp(x['component'],y['component']) or \
                  cmp(x['subcomp'], y['subcomp']) or \
                  cmp(x['type'], y['type']) or \
                  cmp(x['release'], y['release']), reverse=myreverse )
    elif ord == 'subcomp':
        db_list.sort(lambda x,y: cmp(x['subcomp'],y['subcomp']) or \
                  cmp(x['component'], y['component']) or \
                  cmp(x['type'], y['type']) or \
                  cmp(x['release'], y['release']), reverse=myreverse )
    elif ord == 'type':
        db_list.sort(lambda x,y: cmp(x['type'],y['type']) or \
                  cmp(x['component'], y['component']) or \
                  cmp(x['subcomp'], y['subcomp']) or \
                  cmp(x['release'], y['release']), reverse=myreverse )
    elif ord == 'release':
        db_list.sort(lambda x,y: cmp(x['release'], y['release']) or \
                  cmp(x['component'], y['component']) or \
                  cmp(x['subcomp'], y['subcomp']) or \
                  cmp(x['type'],y['type']), reverse=myreverse )
    elif ord == 'version':
        db_list.sort(lambda x,y: cmp(x['version'],y['version']) or \
                  cmp(x['component'], y['component']) or \
                  cmp(x['subcomp'], y['subcomp']) or \
                  cmp(x['release'], y['release']), reverse=myreverse )
    elif ord == 'license':
        db_list.sort(lambda x,y: cmp(x['license'],y['license']) or \
                  cmp(x['component'], y['component']) or \
                  cmp(x['subcomp'], y['subcomp']) or \
                  cmp(x['release'], y['release']), reverse=myreverse )
    elif ord == 'description':
        db_list.sort(lambda x,y: cmp(x['description'],y['description']) or \
                  cmp(x['component'], y['component']) or \
                  cmp(x['subcomp'], y['subcomp']) or \
                  cmp(x['release'], y['release']), reverse=myreverse )
    else:
        pass

    return 0


class MSExcelxml (UserDict):
    def __init__(self, path):
        UserDict.__init__(self)
        self['path']=path
        try:
            self['fd']=open(path, "w")
        except:
            print "Can not open file %s for writting" %path
            self['fd']=0
            pass
    def close(self):
        if self['fd'] != 0:
            try:
                self['fd'].close()
            except:
                print "Can not close file %s for saving" %self['path']
                pass
            self['fd']=0
            os.chmod(self['path'], 0666)

    def writes(self,str=''):
        if (self['fd'] != 0) and (str!=''):
            try:
                self['fd'].write(str);
            except:
                print "Error: can not write to %s"  %self['path']
        return 0;
    def save_xls_head(self):
        string="""<?xml version="1.0"?>
<?mso-application progid="Excel.Sheet"?>"""
        self.writes(string);
        return 0;
        
    def save_xls_workbook_head(self):
        string="""
<Workbook xmlns="urn:schemas-microsoft-com:office:spreadsheet"
 xmlns:o="urn:schemas-microsoft-com:office:office"
 xmlns:x="urn:schemas-microsoft-com:office:excel"
 xmlns:ss="urn:schemas-microsoft-com:office:spreadsheet"
 xmlns:html="http://www.w3.org/TR/REC-html40">
 <DocumentProperties xmlns="urn:schemas-microsoft-com:office:office">
  <Created>1996-12-17T01:32:42Z</Created>
  <LastSaved>2011-09-09T01:57:17Z</LastSaved>
  <Version>11.5606</Version>
 </DocumentProperties>
 <OfficeDocumentSettings xmlns="urn:schemas-microsoft-com:office:office">
  <RemovePersonalInformation/>
 </OfficeDocumentSettings>
 <ExcelWorkbook xmlns="urn:schemas-microsoft-com:office:excel">
  <WindowHeight>4530</WindowHeight>
  <WindowWidth>8505</WindowWidth>
  <WindowTopX>480</WindowTopX>
  <WindowTopY>120</WindowTopY>
  <AcceptLabelsInFormulas/>
  <ProtectStructure>False</ProtectStructure>
  <ProtectWindows>False</ProtectWindows>
 </ExcelWorkbook>"""
        self.writes(string);
        return 0;
    def save_xls_workbook_tail(self):
        string="""
</Workbook>"""
        self.writes(string);
        return 0;
    def save_xls_workbook_style_cell_bfi(self,id='s22',color='#00FF00', fontcolor='NULL', fontbold='NULL'):
        xmlfb=''
        xmlfc=''
        if fontbold!='NULL':
            xmlfb=' ss:Bold="1"'
        if fontcolor!='NULL':
            xmlfc=' ss:Color="%s"' % fontcolor
        string="""
  <Style ss:ID="%s">
   <Borders>
    <Border ss:Position="Bottom" ss:LineStyle="Continuous" ss:Weight="1"
     ss:Color="#008000"/>
    <Border ss:Position="Left" ss:LineStyle="Continuous" ss:Weight="1"
     ss:Color="#008000"/>
    <Border ss:Position="Right" ss:LineStyle="Continuous" ss:Weight="1"
     ss:Color="#008000"/>
    <Border ss:Position="Top" ss:LineStyle="Continuous" ss:Weight="1"
     ss:Color="#008000"/>
   </Borders>
   <Font ss:FontName="Arial Unicode MS" x:CharSet="134" x:Family="Swiss"
    ss:Size="12"%s%s/>
   <Interior ss:Color="%s" ss:Pattern="Solid"/>
  </Style>""" %(id, xmlfc, xmlfb, color)
        self.writes(string);
        return 0;
    def save_xls_workbook_styles(self):
        string="""
 <Styles>
  <Style ss:ID="Default" ss:Name="Normal">
   <Alignment ss:Vertical="Bottom"/>
   <Borders/>
   <Font ss:FontName="Arial Unicode MS" x:CharSet="134" ss:Size="12"/>
   <Interior/>
   <NumberFormat/>
   <Protection/>
  </Style>
  <Style ss:ID="s21">
   <Interior ss:Color="#FFFFFF" ss:Pattern="Solid"/>
  </Style>"""
        self.writes(string);
        self.save_xls_workbook_style_cell_bfi(id='s22',color='#C0C0C0',fontbold='1')
        self.save_xls_workbook_style_cell_bfi(id='s23',color='#FFFFFF')
        self.save_xls_workbook_style_cell_bfi(id='s24',color='#00FF00',fontbold='1')
        self.save_xls_workbook_style_cell_bfi(id='s25',color='#FFFF00',fontbold='1')
        self.save_xls_workbook_style_cell_bfi(id='s26',color='#FF0000',fontbold='1')
        self.save_xls_workbook_style_cell_bfi(id='s27',color='#0000FF',fontbold='1',fontcolor='#FFFFFF')
        string="""
 </Styles>"""
        self.writes(string);
        return 0;
    def save_xls_workbook_worksheet_blank(self,name="Seet1"):
        string="""
 <Worksheet ss:Name="%s">
  <Table ss:ExpandedColumnCount="0" ss:ExpandedRowCount="0" x:FullColumns="1"
   x:FullRows="1" ss:DefaultColumnWidth="54" ss:DefaultRowHeight="14.25"/>
  <WorksheetOptions xmlns="urn:schemas-microsoft-com:office:excel">
   <ProtectObjects>False</ProtectObjects>
   <ProtectScenarios>False</ProtectScenarios>
  </WorksheetOptions>
 </Worksheet>""" % name
        self.writes(string);
        return 0;

    def save_xls_workbook_worksheet_head(self):
        build_number= len(db_list) + 8;
        string="""
 <Worksheet ss:Name="c2license">
  <Table ss:ExpandedColumnCount="8" ss:ExpandedRowCount="%d" x:FullColumns="1"
   x:FullRows="1" ss:StyleID="s21" ss:DefaultColumnWidth="54"
   ss:DefaultRowHeight="14.25">
   <Column ss:Index="2" ss:StyleID="s21" ss:AutoFitWidth="0" ss:Width="96.75"/>
   <Column ss:StyleID="s21" ss:AutoFitWidth="0" ss:Width="159.75"/>
   <Column ss:Index="6" ss:StyleID="s21" ss:AutoFitWidth="0" ss:Width="66"/>
   <Column ss:StyleID="s21" ss:AutoFitWidth="0" ss:Width="72"/>
   <Column ss:StyleID="s21" ss:AutoFitWidth="0" ss:Width="339.75"/>
   <Row ss:Index="2" ss:Height="17.25">
    <Cell ss:StyleID="s22"><Data ss:Type="String">index</Data></Cell>
    <Cell ss:StyleID="s22"><Data ss:Type="String">component</Data></Cell>
    <Cell ss:StyleID="s22"><Data ss:Type="String">sub-component</Data></Cell>
    <Cell ss:StyleID="s22"><Data ss:Type="String">version</Data></Cell>
    <Cell ss:StyleID="s22"><Data ss:Type="String">type</Data></Cell>
    <Cell ss:StyleID="s22"><Data ss:Type="String">release</Data></Cell>
    <Cell ss:StyleID="s22"><Data ss:Type="String">license</Data></Cell>
    <Cell ss:StyleID="s22"><Data ss:Type="String">description</Data></Cell>
   </Row>"""  % build_number
        self.writes(string);
        return 0;
    def save_xls_workbook_worksheet_tail(self):
        string="""
   <Row ss:Height="17.25">
    <Cell ss:StyleID="s23"/>
    <Cell ss:StyleID="s23"/>
    <Cell ss:StyleID="s23"/>
    <Cell ss:StyleID="s23"/>
    <Cell ss:StyleID="s23"/>
    <Cell ss:StyleID="s23"/>
    <Cell ss:StyleID="s23"/>
    <Cell ss:StyleID="s23"/>
   </Row>
  </Table>
  <WorksheetOptions xmlns="urn:schemas-microsoft-com:office:excel">
   <Print>
    <ValidPrinterInfo/>
    <PaperSizeIndex>9</PaperSizeIndex>
    <HorizontalResolution>600</HorizontalResolution>
    <VerticalResolution>600</VerticalResolution>
   </Print>
   <Selected/>
   <Panes>
    <Pane>
     <Number>3</Number>
     <ActiveRow>31</ActiveRow>
     <ActiveCol>3</ActiveCol>
    </Pane>
   </Panes>
   <ProtectObjects>False</ProtectObjects>
   <ProtectScenarios>False</ProtectScenarios>
  </WorksheetOptions>
 </Worksheet>"""
        self.writes(string);
        return 0;
    def save_xls_workbook_worksheet(self):
        db_queue = Queue.Queue(len(db_list))
        build_number= len(db_list);
        for b in db_list:
            db_queue.put(b);
 
        i=0;
        while i<build_number:
          try:
            b = db_queue.get();
            b.list_element_toxlsxmlfile(fd=self['fd'],idx=i+1);
          except:
            pass
          i=i+1;
        return 0;
    def saveas_xlsxml(self):
        self.save_xls_head();
        self.save_xls_workbook_head();
        self.save_xls_workbook_styles();
        self.save_xls_workbook_worksheet_head();
        self.save_xls_workbook_worksheet();
        self.save_xls_workbook_worksheet_tail();
        self.save_xls_workbook_worksheet_blank(name='Sheet2');
        self.save_xls_workbook_worksheet_blank(name='Sheet3');
        self.save_xls_workbook_tail();
        return 0;
def dbf_savecfg():
    global db_path, db_file, db_list

    db_queue = Queue.Queue(len(db_list))
    build_number= len(db_list);
    for b in db_list:
        db_queue.put(b);

    print "<a href=apache/run.pid>run pid</a>";
    fp_run=home_fold+'/apache/run.pid';
    open(fp_run, "w").write(str(os.getpid()))
    os.chmod(fp_run, 0777)

    print "| <a href=apache/out.txt>out xml(download as txt)</a>";
    newlog_name = home_fold+'/apache/out.txt'
    newlog = open(newlog_name, "w")

    b=db_list[0];
    b.list_element_tofilehead(fd=newlog);
    i=0;
    while i<build_number:
      try:
        b = db_queue.get();
        b.list_element_tofile(fd=newlog,idx=i+1);
      except:
        pass
      i=i+1;

    b=db_list[0];
    b.list_element_tofiletail(fd=newlog);
    newlog.close()
    os.chmod(newlog_name, 0777)

    return 0;
def dbf_listall(display='none'):
    global db_path, db_file, db_list
    db_queue = Queue.Queue(len(db_list))
    build_number= len(db_list);
    for b in db_list:
        db_queue.put(b);
    b=db_list[0];
    b.list_element_webhead();
    i=0;
    while i<build_number:
      try:
        b = db_queue.get();
        b.list_element_webdetail(idx=i+1,display=display);
      except:
        pass
      i=i+1;
    b=db_list[0];
    b.list_element_webtail();
def action_liclist():
    create_html_head();
    dbf_update_database();
    dbf_listall();
    create_html_tail();
    pass
def action_liclistall():
    create_html_head();
    dbf_update_database();
    dbf_listall(display='block');
    create_html_tail();
    pass
def action_licrepo():
    create_html_head();
    print "<p>The config file is still not commited to repository server yet.</p>"
    print "<a href='conf/c2liclist.py'>Click here download the config file</a>"
    print "<br>"

    os.system("ls -clrt / >/dev/null");

    fi,fo,fe=os.popen3("ls -clrt /")
    for i in fe.readlines():
       print "error: %s <br>" % i
    for i in fo.readlines():
        print "myresult: %s <br>" %i

    f=os.popen("ls -l /")
    for i in f.readlines():
        print "myresult: %s <br>" %i

    import commands
    x=commands.getoutput("echo current path is: ")
    print x
    print commands.getoutput("pwd")

    create_html_tail();
    pass
def action_savexls():
    create_html_head();
    print "<p>File saved.</p>"
    print "<br><a href='apache/c2license.xls'>Click here download the config file</a>"
    dbf_update_database();
    xml=MSExcelxml(home_fold+'/apache/c2license.xls');
    xml.saveas_xlsxml();
    xml.close();
    create_html_tail();
    pass
def action_savecfg():
    create_html_head();
    dbf_update_database();
    dbf_savecfg();
    create_html_tail();
    pass
def action_debug():
    create_html_head(dbgdisplay='on');
    create_html_tail();
    pass
def action_tobedone():
    create_html_head(dbgdisplay='on');
    print '<p>This operation <font color=blue><b>',op,'</b></font> is in <font color=red><b>To Be Done</b></font> stage</p>';
    create_html_tail();
    pass

def dispatch_actions():
    if   op == 'login'      : return action_login();
    elif op == 'loginack'   : return action_loginack();
    elif op == 'logout'     : return action_logout();
    elif op == 'liclist'    : return action_liclist();
    elif op == 'liclistall' : return action_liclistall();
    elif op == 'licrepo'    : return action_licrepo();
    elif op == 'savecfg'    : return action_savecfg();
    elif op == 'savexls'    : return action_savexls();
    elif op == 'debug'      : return action_debug();
    else                    : return action_tobedone();

def main():
    cgitb.enable();
    evalute_inputs();
    evalute_cookie();
    evalute_action();
    evalute_theme();
    load_user_profile();
    dispatch_actions();

if __name__ == "__main__":
    try:
        main();
    except:
        cgitb.handler();
        pass;

