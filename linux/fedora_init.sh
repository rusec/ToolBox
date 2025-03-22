

if [ "$EUID" -ne 0 ]; then
    echo "Please run as root"
    exit
fi

# Lock system
systemctl disable sshd
systemctl stop sshd

# install rbash
sudo ln /bin/bash /bin/rbash

# Lock users

users=$(cat /etc/passwd | awk -F: '{ print $1 }')
for user in $users
do
    # remove crontab entries
    crontab -u $user -r

    if [[ "$user" != "root" ]] && [[ "$user" != "sysadmin" ]] && [[ ]]; then
        old_shell=$(getent passwd $user | cut -d: -f7)
        # check if they can login
        if [[ "$old_shell" == *"nologin" ]] || [[ "$old_shell" == *"false" ]] || [[ "$old_shell" == *"shutdown" ]] || [[ "$old_shell" == *"halt" ]] || [[ "$old_shell" == *"sync" ]]; then
            echo "User $user is already locked"
            continue
        fi


        usermod -L $user
        usermod -s /bin/false $user
        # Check if the user has a home directory
        echo "User $user has been locked and rbash has been set as their shell. Old shell was: $old_shell"
    fi
done

echo "All users except root and sysadmin have been locked and rbash has been set as their shell."


# install packages

sudo dnf install -y git
cd /tmp
sudo dnf install -y python3
git clone https://github.com/rusec/toolbox.git

# install linpeas and resrict to root
cd /tmp
curl -L https://github.com/peass-ng/PEASS-ng/releases/latest/download/linpeas.sh -o linpeas.sh
chmod +x linpeas.sh
mv linpeas.sh /usr/local/bin/linpeas
chown root:root /usr/local/bin/linpeas
chmod 700 /usr/local/bin/linpeas
echo "linpeas installed and restricted to root"

# install lynis
cd /opt
git clone https://github.com/CISOfy/lynis
chown -R root:root lynis
cd lynis
chmod +x lynis
sudo ./lynis audit system
sudo ./lynis update info
