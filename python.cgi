#!/usr/bin/env python

home_link='project.cgi'

def create_html_links():
    print '|<a href=%s?op=liclist>License</a>' % (home_link)
    print '|<a href=%s?op=liclistall>Detail License</a>' % (home_link);
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


def create_html_head(dbgdisplay='auto'):
    print 'Content-Type: text/html\n';
    print '<html>';
    print '<title>C2 data process webpage</title>'
    print '<body>';
    create_html_links();
    print '<hr>';
    create_html_welcome();
    return 0;
def create_html_tail():
    print '<hr>';
    create_html_links();
    print '</body></html>'
    return 0;


def main():
    create_html_head(dbgdisplay='on');
    create_html_tail();

if __name__ == "__main__":
    try:
        main();
    except:
        cgitb.handler();
        pass;

