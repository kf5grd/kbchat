#!/bin/bash

####### -- kbchat.sh -- #######
#
# Written by Samuel Hofius
#
# Private, encrypted chat via KBFS
#
# Usage: ./kbchat.sh <user>
#
# where <user> is the user you're chatting with
#
###############################

# display help if no remote user was entered
if [ -z ${1+x} ]; then
	echo ""
	echo "KBChat - Private, encrypted chat via KBFS"
	echo ""
	echo "Usage: $0 <user>"
	echo ""
	echo "	user [required]:	keybase.io username to chat with"
	echo ""
	exit
fi

# make sure we're not running as root as keybase doesn't allow this
userid=$(id -u)
[ $userid == '0' ] && echo -e "This script cannot run as root.\nExiting..." && exit

# get keybase user
kbuser=$(keybase status |grep "Username" |cut -d":" -f2 |tr -d [:space:])

# write script that will be used for the top pane
cat > /tmp/top_pane_$1.sh << EOF
#!$(which bash)
touch /keybase/private/$kbuser,$1/chat.log
tail -f /keybase/private/$kbuser,$1/chat.log | sed \\
     -e "s/\($kbuser:\)/\o033[31m\o033[1m\1\o033[0m/" \\
     -e "s/\($1:\)/\o033[34m\o033[1m\\1\o033[0m/" \\
     -e "s/\*\(.*\)\*/\o033[1m\\1\o033[0m/"
EOF

# write script that will be used for the bottom pane
cat > /tmp/bottom_pane_$1.sh << EOF
#!$(which bash)
function cleanup {
    rm /tmp/top_pane_$1.sh
    rm /tmp/bottom_pane_$1.sh
    tmux kill-session -t kbchat_$1
}

while true; do
    echo -en "\rMessage: "
    read messg
    [ "\$messg" == '!exit' ] && break

    echo "[\$(TZ=UTC date '+%F %H:%M')] $kbuser: \$messg" >> \\
         /keybase/private/$kbuser,$1/chat.log && \\
         clear
done
cleanup
EOF

chmod +x /tmp/top_pane_$1.sh
chmod +x /tmp/bottom_pane_$1.sh

# set up tmux session
tmux new-session -d -s "kbchat_$1" "/tmp/top_pane_$1.sh"
tmux split-window -v "/tmp/bottom_pane_$1.sh"
tmux resize-pane -D 20
tmux attach-session
