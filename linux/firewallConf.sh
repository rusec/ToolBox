#!/usr/bin/env bash

function ufw-custom {
        if ! ufw_loc="$(type -p "ufw")" || [ -z "$ufw_loc" ]; then
                printf "\nUFW is not installed yet.\n\n"
        elif [ "$1" = "enable" ]; then
                sudo ufw allow in to any port 22
                sudo ufw allow in to any port 53
                sudo ufw allow in to any port 80
                sudo ufw allow in to any port 443
		sudo ufw deny in to any port 4444
		sudo ufw deny in to any port 9001
                echo ""
                sudo ufw reload
                echo ""
                sudo ufw status numbered
        elif [ "$1" = "disable" ]; then
                sudo ufw delete allow in on tun0 to any port 36892
                sudo ufw delete allow in on tun0 to any port 23976
                sudo ufw delete allow in on tun0 to any port 19827
                echo ""
                sudo ufw reload
                echo ""
                sudo ufw status numbered
        else
                echo ""
                sudo ufw status numbered
                printf "Use 'ufw-custom enable' or 'ufw-custom disable'.\n\n"
        fi
}
export -f ufw-custom
