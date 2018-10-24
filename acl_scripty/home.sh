cd /home/homes
while read line
do
	setfacl --physical --recursive --set user::rwx,user:root:rwx,user:"$line":rwx,group::---,group:domain\ users:---,group:544:rwx,group:domain\ admins:rwx,other::---,mask::rwx "$line"
	setfacl --physical --recursive --default --set user::rwx,user:root:rwx,user:"$line":rwx,group:domain\ users:---,group:544:rwx,group:domain\ admins:rwx,other::---,mask::rwx "$line"
	setfacl --modify other::--x "$line"
	setfacl  --physical --recursive --modify other::r-x,default:other::r-x "$line/public_html"
done < home.list
