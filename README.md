# ubuntu20-NFS-kerberos
This container attempts to simplify the NFS Kerberos setup experience while providing a way to securely mount to NFS using NFSv4, LDAP for identity mapping and Kerberos for ticket exchange, authentication an over the wire encryption using krb5p.

**What you'll need**

To use this container, you'll need:
- an existing KDC (and access to create/modify keytab files; can be AD or non-AD)
- an existing NFS server that supports NFSv4 (such as NetApp ONTAP)
- an exisitng LDAP server (can be AD, OpenLDAP, etc)
- a valid DNS server (usually AD includes DNS and KDC and has ability to serve LDAP)
- network access from containers to the above

**Container file information**

The container file will leverage configuration files that you can customize for your infrastructure, as well as a keytab file that can be shared across multiple containers or be created for each individual container if you prefer. 

Here is the list of files I have in my container folder:

`-rw-r--r--. 1 root root   90 Dec 21 23:51 auto.home`  << optional if you want autofs functionality; configures home directory paths<BR>
`-rw-r--r--. 1 root root   91 Dec 21 23:51 auto.master` << optional if you want autofs functionality; specifies auto.home<BR>
`-rw-r--r--. 1 root root 3814 Dec 21 23:51 bashrc` << runs the configure-nfs-ubuntu.sh script on login to container<BR>
`-rwxr-xr-x. 1 root root  214 Dec 22 00:24 configure-nfs-ubuntu.sh` << starts/restarts some necessary services for NFS to ensure the work on container start (there's probably better ways to do this)<BR>
`-rw-r--r--. 1 root root 1181 Dec 21 23:51 dockerfile.ubuntu.ntap` << dockerfile<BR>
`-rw-r--r--. 1 root root   87 Dec 21 23:51 idmapd-ubuntu.conf.ntap` << IDmap config file for NFSv4 configuration<BR>
`-rw-r--r--. 1 root root  776 Dec 21 23:51 krb5.conf.ntap` << krb5 realm info<BR>
`-rw-r--r--. 1 root root  336 Dec 21 23:52 nsswitch.conf` << search order for users/groups (with SSSD added)<BR>
`-rw-r--r--. 1 root root   91 Dec 21 23:52 resolv.conf` << DNS info; can also be controlled via docker run; in some cases, will get overwritten by the host<BR>
`-rw-r--r-- 1 root root  559 Jan 24 19:58 run_in_sssd_container` << This is the script to allow the container to use SSSD for nfsidmap
`-rw-------. 1 root root  665 Dec 22 00:11 sssd.conf.ntap-ldap` << SSSD config for LDAP; uses a Kerberos SPN for binds<BR>
`-rw-------. 1 root root  279 Dec 21 23:52 ubuntu-container.keytab` << pre-configured keytab file; can be shared across containers <BR>

For keytab management, you can use any preferred utilities. I found some useful tools and added them to this blog post:

https://whyistheinternetbroken.wordpress.com/2021/12/23/its-a-kerberos-khristmas/

This also allows you to set up a way to rotate keytab files for the containers to maintain better overall security.

The dockerfile is located in this repository, along with sample config files. 

The container file does the following:

- Uses the latest Ubuntu build
- adds the `/etc/krb5.conf.d` location from the host
- copies the config files listed above
- Runs apt update and the following: `sudo apt-get update && sudo apt-get autoremove && sudo apt-get install -qq -y curl krb5-user nfs4-acl-tools autofs sssd* ntp -sss packagekit` to include the necessary tools to run the container properly
- Runs the bash script on startup

**Example of working container**

Once that container is started, this is what a working container would look like:

`$ sudo docker exec -it twosigma bash`<BR>
` system message bus already started; not starting.`<BR>
`rpcbind: another rpcbind is already running. Aborting`<BR>
` Stopping NFS common utilities    [ OK ]`<BR>
` Starting NFS common utilities    [ OK ]`<BR>
` Starting automount...            [ OK ]`<BR>
         
` root@f78dc9d468af:/# id student1`<BR>
` uid=1301(student1) gid=1101(group1) groups=1101(group1),1203(group3),48(apache-group),1210(group10),1220(sharedgroup)`<BR>

` root@f78dc9d468af:/# ksu student1 -n student1`<BR>
` WARNING: Your password may be exposed if you enter it here and are logged`<BR>
 `         in remotely using an unsecure (non-encrypted) channel.`<BR>
` Kerberos password for student1@NTAP: :`<BR>
` Changing uid to student1 (1301)`<BR>
         
` student1@f78dc9d468af:/$ klist`<BR>
` Ticket cache: FILE:/tmp/krb5cc_1301.8wEE0d9y`<BR>
` Default principal: student1@NTAP`<BR>
         
` Valid starting     Expires            Service principal`<BR>
` 01/11/22 11:55:51  01/11/22 12:55:51  krbtgt/NTAP.LOCAL@NTAP`<BR>
`        renew until 01/18/22 11:55:51`<BR>
` 01/11/22 11:55:51  01/11/22 12:55:51  nfs/demo.ntap.local@NTAP`<BR>
`         renew until 01/18/22 11:55:51`<BR>
         
` student1@f78dc9d468af:/$ cd ~`<BR>
` student1@f78dc9d468af:~$ ls -la`<BR>
` total 8`<BR>
` drwx------ 2 root     root       4096 Jan  4  2021 .`<BR>
` drwxr-xr-x 3 root     root          0 Jan 11 11:55 ..`<br>
` -rwx------ 1 student1 4294967294 3728 Jan 10 17:10 .bash_history`<BR>
` -rwx---r-x 1 student1 4294967294    0 Nov 13  2020 student1.txt`<BR>
` -rwx---r-x 1 nobody   4294967294    0 Nov 13  2020 test.txt`<BR>

**Host requirements**

For the most part, the containers can run standalone and won't require host changes. However, I've found that the containers share some of the host's kernelspace stuff.

- If you don't override DNS on the container run, the containers will share the resolv.conf of the host, which can break things if they're different
- The NFS IDmap cache will share the host's ID map by default. Thanks to a workaround provided by mikedanese, there's a way to deal with this. On the container host, go to the /etc/request-key.d/id_resolver.conf file and comment out the existing line and replace it with:
`         create	id_resolver	*	*	/usr/bin/run_in_sssd_container /usr/sbin/nfsidmap -t 600 %k %d`
- Changes to the dockerfile, the configure-nfs.sh script and the addition of run_in_sssd_container script were made on 1/24/2022
- In addition, the host's NFSv4 ID domain seems to be shared with the containers. By default, if you don't set the ID domain in idmapd.conf, the DNS name is used. If that DNS name is different on the host than the containers and NFS server (even if the case is different), then the users and groups won't map properly.
- The host doesn't seem to require RPCGSSD to run.

**Considerations for running the container**
         
This container only works when you use --privileged during the run. 
         
For example:
`$ sudo docker run --rm -it --privileged --name ubuntu-krb -d kerberos/ubuntu-krb bash`
         
Running in privileged mode is needed to be able to run mount commands/run autofs.
         
Alternately, you can provide NFS volume access using a PVC. With NetApp storage, you can leverage NetApp Trident to do that.
         
https://netapp-trident.readthedocs.io/en/stable-v21.07/introduction.html
         
**Comments?**

If you have suggestions/tips/comments, feel free to email whyistheinternetbroken@gmail.com or request to merge changes to this repo.

**Where to find more information**

For information on LDAP with NetApp ONTAP, see:
https://www.netapp.com/us/media/tr-4835.pdf

For information on NFS with NetApp ONTAP, see:
https://www.netapp.com/pdf.html?item=/media/10720-tr-4067.pdf

For information on NFS Kerberos with NetApp ONTAP:
https://www.netapp.com/pdf.html?item=/media/19384-tr-4616.pdf

