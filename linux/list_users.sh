#!/bin/bash

users=$(cat /etc/passwd | awk -F: '{ print $1 }')

RED="\033[0;31m"
YELLOW="\033[0;33m"
GREEN="\033[0;32m"
BOLD="\033[1m"
NORMAL="\033[0m"

for user in $users
do
    is_sudo=False
    groups=$(groups $user | awk -F: '{ print $2 }')
    if [[ "$groups" == *sudo* ]]; then
        groups="$groups (sudo)"
        is_sudo=True
    fi
    if [[ "$groups" == *wheel* ]]; then
        groups="$groups (wheel)"
        is_sudo=True
    fi
    if [[ "$groups" == *admin* ]]; then
        groups="$groups (admin)"
        is_sudo=True
    fi
    if [[ "$groups" == *adm* ]]; then
        groups="$groups (adm)"
        is_sudo=True
    fi
    if [[ "$groups" == *root* ]]; then
        groups="$groups (root)"
        is_sudo=True
    fi
    if [[ "$groups" == *sys* ]]; then
        groups="$groups (sys)"
        is_sudo=True
    fi

    login_bin=$(cat /etc/passwd | awk -F: '{ print $1,$7 }' | grep "$user " | awk '{ print $2 }')


    message=""

    if [[ "$is_sudo" == "True" ]]; then
        message="${message}${YELLOW}"
    fi

    if [[ "$login_bin" != *"nologin" ]] && [[ "$login_bin" != *"false" ]] && [[ "$login_bin" != *"shutdown" ]] && [[ "$login_bin" != *"halt" ]] && [[ "$login_bin" != *"halt" ]] && [[ "$login_bin" != *"sync" ]]; then
        message="${message}${GREEN}"
    else
        message="${message}${RED}"
    fi

    message="${message}${BOLD}$user${NORMAL} | $groups | $login_bin"
    echo -e $message




done
