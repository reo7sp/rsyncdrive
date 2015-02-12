#!/bin/bash

# The MIT License (MIT)
#
# Copyright (c) 2015 Reo_SP
#
# Permission is hereby granted, free of charge, to any person obtaining a copy of
# this software and associated documentation files (the "Software"), to deal in
# the Software without restriction, including without limitation the rights to
# use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of
# the Software, and to permit persons to whom the Software is furnished to do so,
# subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
# FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
# COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
# IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
# CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.



##############
### config ###
##############

localpath=   # path without "/" on the end

remoteuser=   # username
remotehost=   # domain or ip
remotepath=   # path without "/" on the end
sshport=22   # port

makebackup=1   # boolean. 0 or 1
backuppath=   # path without "/" on the end



##############
### script ###
##############

# prepare some vars
remote=$remoteuser@$remotehost:$remotepath
local=$(realpath $localpath)
rsyncargs=(-rlptzhue "ssh -p $sshport" --partial --exclude-from=$local/exclude.txt --include-from=$local/include.txt --delete-after --info=progress2)

# print prompt
echo "Select option:"
echo "(1) Pull"
echo "(2) Push"
echo "(3) Pull than push"
echo "(4) Push than pull"
echo
echo -n "> "
read option

# ssh auth
echo; echo ":: Authenticating..."
ssh-add -l > /dev/null
if [ $? != 0 ]
then
	ssh-add ~/.ssh/id_rsa
fi

# prepare filters
echo; echo ":: Building filters..."
rm -f $local/exclude.txt
touch $local/exclude.txt
rm -f $local/include.txt
touch $local/include.txt
prepdlocal=$(echo $local | sed -e 's/[]\/$*.^|[]/\\&/g')\\/

# exclude all entries in .gitignore files
find $local -name ".gitignore" | while read file
do
	cat $file | while read line
	do
		if [[ $line == "" ]]
		then
			echo >> /dev/null
		elif [[ $line == \#* ]]
		then
			echo >> /dev/null
		elif [[ $line == !* ]]
		then
			echo $(dirname $file)/${line:1} | tr -s / | sed "s/$prepdlocal//g" >> $local/include.txt
		else
			echo $(dirname $file)/$line | tr -s / | sed "s/$prepdlocal//g" >> $local/exclude.txt
		fi
	done
done

# exclude all .git dirs
find $local -name ".git" | while read dir
do
	echo $dir | tr -s / | sed "s/$prepdlocal//g" >> $local/exclude.txt
done

# exclude service files and dirs
echo "exclude.txt" >> $local/exclude.txt
echo "include.txt" >> $local/exclude.txt
echo ".git" >> $local/exclude.txt

# backup
if [ $makebackup != 0 ]
then
	echo; echo ":: Making backup..."
	rsync "${rsyncargs[@]}" $local/ $backuppath
	cat $local/exclude.txt > $backuppath/.gitignore
	cat $local/include.txt | while read line
	do
		echo !$line >> $backuppath/.gitignore
	done
	git -C $backuppath init &> /dev/null
	git -C $backuppath add -A &> /dev/null
	git -C $backuppath commit -m "$(date)" &> /dev/null
fi

# sync
echo; echo ":: Syncing..."
case $option in
	1 )
		rsync "${rsyncargs[@]}" $remote/ $local
		;;
	2 )
		rsync "${rsyncargs[@]}" $local/ $remote
		;;
	3 )
		rsync "${rsyncargs[@]}" $remote/ $local
		rsync "${rsyncargs[@]}" $local/ $remote
		;;
	4 )
		rsync "${rsyncargs[@]}" $local/ $remote
		rsync "${rsyncargs[@]}" $remote/ $local
		;;
esac

exit
