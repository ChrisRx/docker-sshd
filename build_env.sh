#!/bin/bash

copy_command() {
    for c in $1;  do
            mkdir -p $2`dirname $c` > /dev/null 2>&1
            cp -v $c $2$c
            ldd $c > /dev/null
            if [ "$?" = 0 ] ; then
                    LIBS=`ldd $c | grep "=> /" | awk '{ print $3 }'`
                    for l in $LIBS; do
                            mkdir $2`dirname $l` > /dev/null 2>&1
                            cp $l $2$l
                    done
            fi
    done
}

create_chroot() {
    D=$1
    mkdir -p $D

    mkdir -p $D/dev/
    mknod -m 666 $D/dev/null c 1 3
    mknod -m 666 $D/dev/tty c 5 0
    mknod -m 666 $D/dev/zero c 1 5
    mknod -m 666 $D/dev/random c 1 8

    chown root:root $D
    chmod 0755 $D


    # Setup minimal bash environment
    mkdir -p $D/bin
    cp -v /bin/bash $D/bin

    mkdir -p $D/lib/
    mkdir -p $D/lib64/
    mkdir -p $D/lib/x86_64-linux-gnu/
    cp -v /lib/x86_64-linux-gnu/{libncurses.so.5,libtinfo.so.5,libdl.so.2,libc.so.6} $D/lib/

    cp -v /lib64/ld-linux-x86-64.so.2 $D/lib64/
    cp -va /lib/x86_64-linux-gnu/libnss_files* $D/lib/x86_64-linux-gnu/
}

create_user() {
    USERNAME=$1
    SSH_USER_GROUP=$2
    CHROOT_DIR=$3
    PUBKEY=$4

    # Ensure directory exists before creating user
    mkdir -p $CHROOT_DIR/home/$USERNAME/.ssh

    # Set long random password at creation. SSH won't do pubkey auth if the account has
    # no password.
    PW=$(head -c 32 /dev/urandom | base64)
    useradd -s /bin/bash -d /home/$USERNAME -M -g $SSH_USER_GROUP -p $PW $USERNAME
    unset PW

    echo $PUBKEY >> $CHROOT_DIR/home/$USERNAME/.ssh/authorized_keys
    unset PUBKEY

    # Set the ownership
    chown $USERNAME:$SSH_USER_GROUP $CHROOT_DIR/home/$USERNAME

    # Remove other jailed users access
    chmod go-rwx -R $CHROOT_DIR/home/$USERNAME

    mkdir -p $CHROOT_DIR/etc
    cp -vf /etc/{passwd,group} $CHROOT_DIR/etc/
}

CHROOT_DIR=/jails
SSH_USER_GROUP=ssh-users
ALLOWED_COMMANDS="/usr/bin/rsync /bin/ls /usr/bin/vi /bin/mkdir"
USERS_FILE=/tmp/users.txt

# Create minimal chroot
create_chroot $CHROOT_DIR

# Copy commands
copy_command "$ALLOWED_COMMANDS" $CHROOT_DIR

# Setup group for sshd
groupadd $SSH_USER_GROUP

# Setup pubkey auth in sshd
cat << EOF >> /etc/ssh/sshd_config
Match Group $SSH_USER_GROUP
ChrootDirectory $CHROOT_DIR
AuthorizedKeysFile $CHROOT_DIR/home/%u/.ssh/authorized_keys
EOF

#Setup users from file
while read p; do
    USERNAME=$(cut -d ',' -f1 <<< $p)
    PUBKEY=$(cut -d ',' -f2 <<< $p)
    create_user $USERNAME $SSH_USER_GROUP $CHROOT_DIR "$PUBKEY"
done < $USERS_FILE
