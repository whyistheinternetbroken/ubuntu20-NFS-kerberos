# ubuntu20-NFS-kerberos
This container attempts to simplify the NFS Kerberos setup experience while providing a way to securely mount to NFS using NFSv4, LDAP for identity mapping and Kerberos for ticket exchange, authentication an over the wire encryption using krb5p.

**What you'll need**

To use this container, you'll need:
- an existing KDC (and access to create/modify keytab files; can be AD or non-AD)
- an existing NFS server that supports NFSv4 (such as NetApp ONTAP)
- an exisitng LDAP server (can be AD, OpenLDAP, etc)
- a valid DNS server (usually AD includes DNS and KDC and has ability to serve LDAP)
- network access from containers to the above

_Note: container host will also need to resolve usernames and NFSv4 ID domains for NFSv4 to work properly._

**Container file information**

The container file will leverage configuration files that you can customize for your infrastructure, as well as a keytab file that can be shared across multiple containers or be created for each individual container if you prefer. 

Here is the list of files I have in my container folder:

-rw-r--r--. 1 root root   90 Dec 21 23:51 auto.home  << optional if you want autofs functionality; configures home directory paths
-rw-r--r--. 1 root root   91 Dec 21 23:51 auto.master << optional if you want autofs functionality; specifies auto.home
-rw-r--r--. 1 root root 3814 Dec 21 23:51 bashrc << runs the configure-nfs-ubuntu.sh script on login to container
-rwxr-xr-x. 1 root root  214 Dec 22 00:24 configure-nfs-ubuntu.sh << starts/restarts some necessary services for NFS to ensure the work on container start (there's probably better ways to do this)
-rw-r--r--. 1 root root 1181 Dec 21 23:51 dockerfile.ubuntu.ntap << dockerfile
-rw-r--r--. 1 root root   87 Dec 21 23:51 idmapd-ubuntu.conf.ntap << IDmap config file for NFSv4 configuration
-rw-r--r--. 1 root root  776 Dec 21 23:51 krb5.conf.ntap << krb5 realm info
-rw-r--r--. 1 root root  336 Dec 21 23:52 nsswitch.conf << search order for users/groups (with SSSD added)
-rw-r--r--. 1 root root   91 Dec 21 23:52 resolv.conf << DNS info; can also be controlled via docker run; in some cases, will get overwritten by the host
-rw-------. 1 root root  665 Dec 22 00:11 sssd.conf.ntap-ldap << SSSD config for LDAP; uses a Kerberos SPN for binds
-rw-------. 1 root root  279 Dec 21 23:52 ubuntu-container.keytab << pre-configured keytab file; can be shared across containers 

For keytab management, you can use any preferred utilities. I found some useful tools and added them to this blog post:

https://whyistheinternetbroken.wordpress.com/2021/12/23/its-a-kerberos-khristmas/

This also allows you to set up a way to rotate keytab files for the containers to maintain better overall security.

The dockerfile is located in this repository, along with sample config files. 

The container file does the following:

- Uses the latest Ubuntu build
- adds the /etc/krb5.conf.d location from the host
- copies the config files listed above
- Runs apt update and the following: "sudo apt-get update && sudo apt-get autoremove && sudo apt-get install -qq -y curl krb5-user nfs4-acl-tools autofs sssd* ntp -sss packagekit" to include the necessary tools to run the container properly
- Runs the bash script on startup

**Example of working container**

Once that container is started, this is what a working container would look like:

$ sudo docker exec -it twosigma bash
 * system message bus already started; not starting.
rpcbind: another rpcbind is already running. Aborting
 * Stopping NFS common utilities                                                                                                                      [ OK ]
 * Starting NFS common utilities                                                                                                                      [ OK ]
 * Starting automount...                                                                                                                              [ OK ]
root@f78dc9d468af:/# id student1
uid=1301(student1) gid=1101(group1) groups=1101(group1),1203(group3),48(apache-group),1210(group10),1220(sharedgroup)
root@f78dc9d468af:/# ksu student1 -n student1
WARNING: Your password may be exposed if you enter it here and are logged
         in remotely using an unsecure (non-encrypted) channel.
Kerberos password for student1@NTAP.LOCAL: :
Changing uid to student1 (1301)
student1@f78dc9d468af:/$ klist
Ticket cache: FILE:/tmp/krb5cc_1301.8wEE0d9y
Default principal: student1@NTAP.LOCAL

Valid starting     Expires            Service principal
01/11/22 11:55:51  01/11/22 12:55:51  krbtgt/NTAP.LOCAL@NTAP.LOCAL
        renew until 01/18/22 11:55:51
01/11/22 11:55:51  01/11/22 12:55:51  nfs/demo.ntap.local@NTAP.LOCAL
        renew until 01/18/22 11:55:51
student1@f78dc9d468af:/$ cd ~
student1@f78dc9d468af:~$ ls -la
total 8
drwx------ 2 root     root       4096 Jan  4  2021 .
drwxr-xr-x 3 root     root          0 Jan 11 11:55 ..
-rwx------ 1 student1 4294967294 3728 Jan 10 17:10 .bash_history
-rwx---r-x 1 student1 4294967294    0 Nov 13  2020 student1.txt
-rwx---r-x 1 nobody   4294967294    0 Nov 13  2020 test.txt

**Host requirements**

For the most part, the containers can run standalone and won't require host changes. However, I've found that the containers share some of the host's kernelspace stuff.

- If you don't override DNS on the container run, the containers will share the resolv.conf of the host, which can break things if they're different
- If you use NFSv4.x, the containers seem to want to share the same nfsidmap cache. If the host can't resolve usernames properly, then the containers won't map NFSv4 names properly - even if the container can find the users. I haven't figured out a workaround for that, so either add the user and group names to the host's local passwd and group files or configure the host to use the same LDAP server as the containers.
- In addition, the host's NFSv4 ID domain seems to be shared with the containers. By default, if you don't set the ID domain in idmapd.conf, the DNS name is used. If that DNS name is different on the host than the containers and NFS server (even if the case is different), then the users and groups won't map properly.
- The host doesn't seem to require RPCGSSD to run.

**Comments?**

If you have suggestions/tips/comments, feel free to email whyistheinternetbroken@gmail.com or request to merge changes to this repo.

**Where to find more information**

For information on LDAP with NetApp ONTAP, see:
https://www.netapp.com/us/media/tr-4835.pdf

For information on NFS with NetApp ONTAP, see:
https://www.netapp.com/pdf.html?item=/media/10720-tr-4067.pdf

For information on NFS Kerberos with NetApp ONTAP:
https://www.netapp.com/pdf.html?item=/media/19384-tr-4616.pdf

