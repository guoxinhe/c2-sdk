#!/bin/sh

cd /home/hguo/maintree-jazz2l
export CVSROOT=:pserver:hguo@cvs.c2micro.com:/cvsroot
BRANCH="jazz2l-SDK-0_5-1_Branch"
LISTFILE=sdk_content-jazz2l-SDK-0_5-1_Branch
CONTENT=`cat $LISTFILE`

cvslog=cvs.log
progresslog=progress.log
# update all SDK codes
>$cvslog
>$progresslog
echo "Create Branch"    >>$progresslog
for i in $CONTENT; do
    echo "branching $i"    >>$cvslog
    echo "`date` branching $i"    >>$progresslog
    cvs -q co -AP $i    >>$cvslog
    #cvs -q update -CAPd $i
    cvs -q tag -b $BRANCH $i    >>$cvslog
done
echo "branch done"    >>$progresslog

SENDTO=hguo@c2micro.com,rhine@c2micro.com,jsun@c2micro.com,weli@c2micro.com,mxia@c2micro.com,robinlee@c2micro.com,ruishengfu@c2micro.com,wdiao@c2micro.com,mingliu@c2micro.com
mail_title="Branch $BRANCH from maintree done"
echo $mail_title  >branch_email.txt

echo ""  >>branch_email.txt
echo "Contents of branched module"  >>branch_email.txt
cat $LISTFILE >>branch_email.txt

echo ""  >>branch_email.txt
echo "Progress of branched module"  >>branch_email.txt
cat $progresslog >>branch_email.txt

cat <<-EMAIL_BODY >>branch_email.txt

Regards,
`whoami` on `hostname`
`date`
	EMAIL_BODY

cat branch_email.txt | mail -s "$mail_title" $SENDTO

CONTENT=`cat sdk_content`
echo "CVS update"
for i in $CONTENT; do
    echo "updating $i"    >>$cvslog
    echo "`date` updating $i"    >>$progresslog
    cvs -q update -CAPd -r $BRANCH $i    >>$cvslog
done
echo "update done"   >>$progresslog


