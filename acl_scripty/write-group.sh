#!/bin/bash
#do parametru jako prvni cestu, jako druhe nazev skupiny, ./write-group.sh cluster1 cluster
setfacl --physical --recursive --set user::rwx,user:root:rwx,group::r-x,group:domain\ users:r-x,group:544:rwx,group:domain\ admins:rwx,group:"$2":rwx,other::---,mask::rwx "$1"
setfacl --physical --recursive --default --set user::rwx,user:root:rwx,group::r-x,group:domain\ users:r-x,group:544:rwx,group:domain\ admins:rwx,group:"$2":rwx,other::---,mask::rwx "$1"
chmod g+s "$1"
find "$1" -type d -exec chmod g+s {} \;
chgrp -R domain\ users "$1"
