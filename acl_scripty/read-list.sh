#!/bin/bash
while read line
do
	setfacl --physical --recursive --set user::rwx,user:root:rwx,group::r-x,group:domain\ users:r-x,group:544:rwx,group:domain\ admins:rwx,other::---,mask::rwx "$line"
	setfacl --physical --recursive --default --set user::rwx,user:root:rwx,group::r-x,group:domain\ users:r-x,group:544:rwx,group:domain\ admins:rwx,other::---,mask::rwx "$line"
	chmod g+s "$line"
	find "$line" -type d -exec chmod g+s {} \;
	chgrp -R domain\ users "$line"
	echo "hotovo $line"
done < write.list
