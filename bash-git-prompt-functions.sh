# vim: set filetype=bash
# Include file which contains various functions used by bash-git-prompt

function bgp_get_pwd_repository_root(){
	currdir=`pwd`
	currdir_hash=`bgp_hash "$currdir"`

	repo_root=""
	currdir_cache_file="$RUNDIR/cache/directories/$currdir_hash"
	if [ ! -r "$currdir_cache_file" ]; then
		bgp_log "no information known for '$currdir' ($currdir_cache_file does not exist)"

		# No cache information known for current directory - create it.
		mkdir -p "$RUNDIR/cache/directories"

		repo_root=`git rev-parse --show-toplevel 2> /dev/null`
		if [ "$repo_root" = "" ]; then
			# Current pwd is not part of repository - construct empty file
			bgp_log "current directory not part of Git repository"
			touch "$currdir_cache_file"
		else
			bgp_log "current directory part of Git repository at '$repo_root', storing in cache"
			echo "$repo_root" > "$currdir_cache_file"
		fi
	else
		bgp_log "found cache for '$currdir': $currdir_cache_file"

		repo_root=`cat "$currdir_cache_file"`
		if [ "$repo_root" = "" ]; then
			bgp_log "information in cache about '$currdir': not part of Git repository"
		else
			bgp_log "information in cache about '$currdir': part of Git repository at '$repo_root'"
		fi
	fi

	echo "$repo_root"
}		

# Determines if a directory ($1) is local to this system.
function bgp_is_local_directory(){
	LOCAL_FSTYPES="ext2 ext3 ext4"

	dir="$1"
	mountpoint=""
	mountpoint_fs=""
	for mountinfo in $(mount | grep ^/dev | sed "s/ on /|/g" | sed "s/ type /|/g" | sed "s/ (/|(/g"); do 
		this_mountdev=`echo $mountinfo | cut -d "|" -f 1`
		this_mountpoint=`echo $mountinfo | cut -d "|" -f 2`
		this_mountfstype=`echo $mountinfo | cut -d "|" -f 3`

		result=($(echo "$dir" | grep -o "$this_mountpoint"))
		if [[ ${#result} -gt ${#mountpoint} ]]; then
			mountpoint="$result"
			mountpoint_fs="$this_mountfstype"
		fi
	done

	if [ "$mountpoint_fs" = "" ]; then
		# Can't find mount point
		bgp_log "can't figure out whether '$dir' is local to this system"
		echo "yes"
		return
	fi

	for local_fstype in $LOCAL_FSTYPES; do
		if [ "$local_fstype" = "$mountpoint_fs" ]; then
			bgp_log "repository at '$dir' is located on mount point '$mountpoint' which is of local type '$local_fstype'"
			echo "yes"
			return
		fi
	done


	bgp_log "repository at '$dir' is located on mount point '$mountpoint', which is of non-local filesystem type '$mountpoint_fs'"
	echo "no"
}


function bgp_clean_instances(){
	if [ ! -d "$RUNDIR/instances" ]; then
		mkdir -p "$RUNDIR/instances"
	fi

	cd "$RUNDIR/instances" || return
	bgp_log "Cleaning garbage from previous instances:"

	ls | while read instance_pid; do
		proc_cmdline="/proc/$instance_pid/cmdline"
		if [ ! -r "$proc_cmdline" ] || [ "`cat $proc_cmdline | grep bash`" = "" ]; then
			bgp_log "PID $instance_pid no longer active, cleaning up"
			rm -rf "$RUNDIR/instances/$instance_pid"
		else
			bgp_log "PID $instance_pid currently active, not cleaning up"
		fi
	done	
	
	# Back to home dir
	cd
}
	
function bgp_log(){
	echo "`date` -- $BASH_GIT_PROMPT_PID -- $@" >> /tmp/bash-git-prompt.log
}

function bgp_hash(){
	echo $@ | md5sum | awk '{print $1}'
}
