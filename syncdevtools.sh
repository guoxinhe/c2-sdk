#!/bin/bash

## sync from San Jose to Beijing

today=`date +%y%m%d`
yesterday=`date -d yesterday +%y%m%d`

rsync -avzHS --stats --delete --delete-after --bwlimit=256 --copy-dest=/group/shared/tools_bj/c2/$yesterday/  blackhole:/c2/local/c2/$today/ /group/shared/tools_bj/c2/$today/ 
rsync -avzHS blackhole:/c2/local/c2/daily /group/shared/tools_bj/c2/ 
rsync -avzHS blackhole:/c2/local/c2/daily-jazz1 /group/shared/tools_bj/c2/ 
rsync -avzHS blackhole:/c2/local/c2/daily-jazz2 /group/shared/tools_bj/c2/ 
rsync -avzHS --stats --delete --delete-after --bwlimit=256 blackhole:/c2/local/c2/kernel/ /group/shared/tools_bj/c2/kernel/
rsync -avzHS --stats --delete --delete-after --bwlimit=256 --exclude=sw_media blackhole:/c2/local/c2/ /group/shared/tools_bj/c2/

echo `date` >> /var/tmp/syncdevtools
mail -s "on dante, sync dante:/group/shared/tools_bj/c2/$today is done" wding@c2micro.com < /dev/null
