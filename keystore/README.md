Keystore - A PKCS based password manager in Powershell
======================================================

* We are a handful of developers and manage about 20-30 servers.  
Shared secrets are painful and especially when they need to be used in unattended
scripts. 
* We depend heavily on Powershell at RemoteX. We are automating "all the things".  
We are mostly on MS Windows and Microsoft platforms and frameworks, but a very
central part of our automation efforts rely on Hudson/Jenkins CI.  
When trying Powershell and automation, WinRM is the next thing up.
* We love Git and Github.

If you're on Windows you can't use simple things like SSH keys out of the box.  
Using a number of different datacenters and shared development environments we
needed something that enabled us to share secrets in the team and with our
Hudson CI environment.

Keystore is a small set of Powershell functions which provides password management
with the following features:

* Each entry is an encrypted username + password identified by a service name
* File storage - just like SSH keys
* Encrypted credentials can easily be shared in a Git repository
* Each set of encrypted credentials are protected by a shared certificate
* Certificates can be self-signed or issued by a trusted CA 
* Implementation uses standard PKCS APIs in .Net Framework - zero dependencies


Please feel free to use and we'd love to get your feedback.  
However, this script/tool is provided AS-IS and confers no rights.