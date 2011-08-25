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

#get cookie, form post, form get, etc.
#--------------------------------------------------------------------------
#put here, not in a function,otherwise my system does not work.

form = cgi.FieldStorage()
colors = form.getlist('color');
method = form.getfirst('method', 'empty'); method = cgi.escape(method);
loginuser = form.getfirst('loginuser', 'empty'); loginuser = cgi.escape(loginuser);
loginpswd = form.getfirst('loginpswd', 'empty'); loginpswd = cgi.escape(loginpswd);

a   = form.getfirst('a',   'empty');  a   = cgi.escape(a);
b   = form.getfirst('b',   'empty');  b   = cgi.escape(b);
c   = form.getfirst('c',   'empty');  c   = cgi.escape(c);
d   = form.getfirst('d',   'empty');  d   = cgi.escape(d);
e   = form.getfirst('e',   'empty');  e   = cgi.escape(e);
f   = form.getfirst('f',   'empty');  f   = cgi.escape(f);
g   = form.getfirst('g',   'empty');  g   = cgi.escape(g);
h   = form.getfirst('h',   'empty');  h   = cgi.escape(h);
i   = form.getfirst('i',   'empty');  i   = cgi.escape(i);
j   = form.getfirst('j',   'empty');  j   = cgi.escape(j);
k   = form.getfirst('k',   'empty');  k   = cgi.escape(k);
l   = form.getfirst('l',   'empty');  l   = cgi.escape(l);
m   = form.getfirst('m',   'empty');  m   = cgi.escape(m);
n   = form.getfirst('n',   'empty');  n   = cgi.escape(n);
o   = form.getfirst('o',   'empty');  o   = cgi.escape(o);
p   = form.getfirst('p',   'empty');  p   = cgi.escape(p);
q   = form.getfirst('q',   'empty');  q   = cgi.escape(q);
r   = form.getfirst('r',   'empty');  r   = cgi.escape(r);
s   = form.getfirst('s',   'empty');  s   = cgi.escape(s);
t   = form.getfirst('t',   'empty');  t   = cgi.escape(t);
u   = form.getfirst('u',   'empty');  u   = cgi.escape(u);
v   = form.getfirst('v',   'empty');  v   = cgi.escape(v);
w   = form.getfirst('w',   'empty');  w   = cgi.escape(w);
x   = form.getfirst('x',   'empty');  x   = cgi.escape(x);
y   = form.getfirst('y',   'empty');  y   = cgi.escape(y);
z   = form.getfirst('z',   'empty');  z   = cgi.escape(z);
op  = form.getfirst('op',  'empty');  op  = cgi.escape(op);
act = form.getfirst('act', 'empty');  act = cgi.escape(act);
dbg = form.getfirst('dbg', 'empty');  dbg = cgi.escape(dbg);
flt = form.getfirst('flt', 'empty');  flt = cgi.escape(flt);
mod = form.getfirst('mod', 'empty');  mod = cgi.escape(mod);
opt = form.getfirst('opt', 'empty');  opt = cgi.escape(opt);
thm = form.getfirst('thm', 'empty');  thm = cgi.escape(thm);

cookie = Cookie.SimpleCookie()
string_cookie = os.environ.get('HTTP_COOKIE')
my_error_message = '';
my_error_number = 0;
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
    # Will expire in a year
    cookie['sid']['expires'] = 12 * 30 * 24 * 60 * 60
    cookie['user']['expires'] = 12 * 30 * 24 * 60 * 60
    cookie['pswd']['expires'] = 12 * 30 * 24 * 60 * 60
    cookie['debug']['expires'] = 12 * 30 * 24 * 60 * 60
# If already existent session
else:
    cookie.load(string_cookie)
    sid = cookie['sid'].value
    user= cookie['user'].value
    pswd= cookie['pswd'].value
    debug=cookie['debug'].value
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

def evalute_inputs():
    return 0;
def evalute_action():
    return 0;
def evalute_theme():
    return 0;
def create_links():
    print '|<a href=project.cgi?op=pkg>SDK Package Management</a>';
    print '|<a href=project.cgi?op=get>get test</a>';
    print '|<a href=project.cgi?op=post>post test</a>';
    print '|<a href=project.cgi?op=debug>debug</a>';
    if user == 'guest':
        print '|<a href=project.cgi?op=login>login</a>';
    else:
        print '|<a href=project.cgi?op=logout>logout</a><font color=blue><b>',user,'</b></font>';
    return 0;
def create_html_head():
    print cookie
    print 'Content-Type: text/html\n';
    print '<html><body>';
    create_links();
    print '<hr>';
    return 0;
def create_html_tail():
    print '<hr>';
    create_links();
    print '</body></html>'
    return 0;
def create_html_welcome():
    print '<p><b><font size=+3 color=red>Welcome to this page!</font></b></p>'
    return 0;
def load_user_profile():
    return 0;
def action_debug():
    print '<p> op = ',op,', form method = ',method,'</p>'
    print 'vars:a-g',a,b,c,d,e,f,g,'<br>';
    print 'vars:h-n',h,i,j,k,l,m,n,'<br>';
    print 'vars:o-t',o,p,q,r,s,t,'<br>';
    print 'vars:u-z',u,v,w,x,y,z,'<br>';
    print 'vars:op,act,dbg,flt,mod,opt,thm,method',op,act,dbg,flt,mod,opt,thm,method,'<br>';
    print 'vars:colors,loginuser,loginpswd',colors,loginuser,loginpswd,'<br>';
    print 'The colors list:', colors
    for color in colors:
        print '<p>', cgi.escape(color), '</p>'
    if string_cookie:
        print '<p>Already existent session:<br>['+string_cookie+']<br>cookie printed</p>'
        print '<p>SID, user, pswd,debug =', sid, user, pswd, debug, '</p>'
    else :
        print '<p>first time, no login yet.</p>'
    return 0;

def action_login():
    print "<p>Please login</p>";
    print """\
<form method="post" action="project.cgi?op=loginack">
<input type=hidden name=op value=loginack>
<input type=hidden name=method value=post>
Name: <input type="text" name="loginuser">
Password: <input type="password" name="loginpswd">
<input type="submit" value="Submit">
</form>
        """
    if debug== 'on':
        action_debug();
    return 0;
def action_loginack():
    if my_error_number>0:
        print my_error_message;
        action_login();
        return 0;
    print "Login in correctly!<br>";
    if debug== 'on':
        action_debug();
    return 0;
def action_logout():
    print "Logout success.<br>";
    if debug== 'on':
        action_debug();
    return 0;

def action_get():
    print """\
<form method="get" action="project.cgi?op=getack">
<input type=hidden name=op value=getack>
<input type=hidden name=method value=get>
  Red:<input type="checkbox" name="color" value="red">
Green:<input type="checkbox" name="color" value="green">
 User:<input type="text" name="loginuser">
 Password:<input type="text" name="loginpswd">
<input type="submit" value="Submit">
</form>
    """
    if debug== 'on':
        action_debug();
    return 0;
def action_getack():
    if debug== 'on':
        action_debug();
    return 0;
def action_post():
    print """\
<form method="post" action="project.cgi?op=postack">
<input type=hidden name=op value=postack>
<input type=hidden name=method value=post>
  Red:<input type="checkbox" name="color" value="red">
Green:<input type="checkbox" name="color" value="green">
 User:<input type="text" name="loginuser">
 Password:<input type="text" name="loginpswd">
<input type="submit" value="Submit">
</form>
    """
    if debug== 'on':
        action_debug();
    return 0;
def action_postack():
    if debug== 'on':
        action_debug();
    return 0;


#    
from subprocess import Popen, STDOUT, PIPE
from UserDict import UserDict
default_repository = ":pserver:hguo@cvs.c2micro.com:/cvsroot"
class Build (UserDict):
    def __init__(self, build):
        UserDict.__init__(self)
        
        self['cvs module'] = build['cvs module']
        self['name']       = build['name']
        self['buildcmd']   = build['buildcmd']

        #print 'Read cvs module',self['cvs module'],'<br>';
        try:
            self['env']        = build['env']
        except KeyError:
            pass

        try:
            self['project'] = build['project']
        except KeyError:
            self['project'] = self['cvs module']

        try:
            self['repository'] = build['repository']
        except KeyError:
            self['repository'] = default_repository

        # no validation here for now, but we should
        try:
            self['execs'] = build['execs']
        except KeyError:
            pass

    def fullname(self):
        return ("%s:%s" % (self['project'], self['name']))
    def buildcmd(self):
        return ("%s" % (self['buildcmd']))

def action_listsdkpackage():
    if debug== 'on':
        print '<table border=1  bgcolor=white>';
        print '<tr bgcolor=lightgrey><td>Pkg</td><td>Lic</td><td>package name</td><td>detail</td><td>note</td></tr>';
        for i in (1,2):
            print '<tr>';
            for j in (1,2,3,4,5):
                print '<td><a href=/ title="for test only">',i,j,'</a></td>'
            print '</tr>';
        print '</table>';

    sys.path.append("/home/hguo/build_check_wd")
    conffile='conf/swmconf';
    sys.path.insert(0, "");
    try :
        conf = __import__(conffile);
    except:
        print "Error importing", conffile, ":", sys.exc_info()[:2]
        raise
    del sys.path[0]
    builds = [Build(b) for b in conf.config];


    build_queue = Queue.Queue(len(builds))
    build_number= len(builds);
    print '<br>';
    print 'Debug: total',len(builds), 'items read<br>';

    for b in builds:
        build_queue.put(b);

    print '<table border=1  bgcolor=white>';
    print '<tr bgcolor=lightgrey><td>Index</td><td>Full name and detail</td></tr>';
    i=0;
    while i<build_number:
      print '<tr>';
      try:
        b = build_queue.get();
        print '<td>',i,'</td><td>Full name:',b.fullname();
        print '<br>Module:', b['cvs module']
        print '<br>name:',   b['name']
        print '<br>Cmd:',    b['buildcmd']
        print '<br>env:',    b['env']
        print '<br>project:',    b['project']
        print '<br>repository:',    b['repository']
        print '<br>execs:<br><font color=green>'
        try :
            for test in b['execs'] :
                print '----name:',test['name'],'<br>'
                print '----cmd :',test['cmd']
        except:
            pass
        print '</font>';
        print '</td>';
        print '</tr>';
      except:
        print '</tr>';
        pass
      i=i+1;
    print '</table>';

def dispatch_actions():
    if string_cookie:
       load_user_profile();
    else:
       create_html_welcome();

    if   op ==                'login':
       return action_login();
    elif op ==                'loginack':
       return action_loginack();
    elif op ==                'get':
       return action_get();
    elif op ==                'getack':
       return action_getack();
    elif op ==                'post':
       return action_post();
    elif op ==                'postack':
       return action_postack();
    elif op ==                'debug':
       return action_debug();
    elif op ==                'pkg':
       return action_listsdkpackage();
    elif op ==                'logout':
       return action_logout();
    elif op ==                'c':
       return 0;
    elif op ==                'd':
       return 0;
    elif op ==                'e':
       return 0;
    elif op ==                'f':
       return 0;
    elif op ==                'g':
       return 0;
    elif op ==                'h':
       return 0;
    elif op ==                'i':
       return 0;
    elif op ==                'j':
       return 0;
    elif op ==                'k':
       return 0;
    elif op ==                'l':
       return 0;
    elif op ==                'm':
       return 0;
    elif op ==                'n':
       return 0;
    elif op ==                'o':
       return 0;
    elif op ==                'p':
       return 0;
    elif op ==                'q':
       return 0;
    elif op ==                'r':
       return 0;
    elif op ==                's':
       return 0;
    elif op ==                't':
       return 0;
    elif op ==                'u':
       return 0;
    elif op ==                'v':
       return 0;
    elif op ==                'w':
       return 0;
    elif op ==                'x':
       return 0;
    elif op ==                'y':
       return 0;
    elif op ==                'z':
       return 0;
    else :
       return action_debug();

def main():
    cgitb.enable();
    evalute_inputs();
    evalute_action();
    evalute_theme();
    create_html_head();
    dispatch_actions();
    create_html_tail();

if __name__ == "__main__":
    try:
        main();
    except:
        cgitb.handler();
        pass;

