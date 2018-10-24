#!/bin/bash
setfacl --physical --recursive --set user::rwx,user:root:rwx,group::r-x,group:domain\ users:r-x,group:544:rwx,group:domain\ admins:rwx,other::---,mask::rwx "$1"
setfacl --physical --recursive --default --set user::rwx,user:root:rwx,group::r-x,group:domain\ users:r-x,group:544:rwx,group:domain\ admins:rwx,other::---,mask::rwx "$1"
chmod g+s "$1"
find "$1" -type d -exec chmod g+s {} \;
chgrp -R domain\ users "$1"
