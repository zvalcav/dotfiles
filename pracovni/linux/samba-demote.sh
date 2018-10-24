#!/bin/bash

samba-tool fsmo show

echo

for role in $(ldbsearch --cross-ncs -H /var/lib/samba/private/sam.ldb '(fsmoroleowner=*)' | grep 'dn:' | sed 's|dn: ||')
do
	ldbsearch --cross-ncs -H /var/lib/samba/private/sam.ldb -b "$role" -s base fsmoroleowner
done
