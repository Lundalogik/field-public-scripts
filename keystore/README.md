Keystore - A PKCS based password manager in Powershell
======================================================

## Background
* We are a handful of developers and manage about 20-30 servers.  
Shared secrets are painful and especially when they need to be used in unattended
scripts. 
* We depend heavily on Powershell at RemoteX. We are automating "all the things".  
We are mostly on MS Windows and Microsoft platforms and frameworks, but a very
central part of our automation efforts rely on Hudson/Jenkins CI.  
When trying Powershell and automation, WinRM is the next thing up.
* We love Git and Github.

## A small problem...
If you're on Windows you can't use simple things like SSH keys out of the box.  
Using a number of different datacenters and shared development environments we
needed something that enabled us to share secrets in the team and with our
Hudson CI environment.

## ..a tiny solution
Keystore is a small set of Powershell functions which provides password management
with the following features:

* Each entry is an encrypted username + password identified by a service name
* File storage - just like SSH keys
* Encrypted credentials can easily be shared in a Git repository
* Each set of encrypted credentials are protected by a shared certificate
* Certificates can be self-signed or issued by a trusted CA 
* Implementation uses standard PKCS APIs in .Net Framework - zero dependencies

### Example - Encrypting a set of credentials
    PS> . C:\src\Scripts\keystore\keystore.ps1
    PS> setCredential srv01 foouser barpassword
    # Certificate selector dialog pops up
    PS> ls
    
    
        Directory: C:\temp
    
    
    Mode                LastWriteTime     Length Name
    ----                -------------     ------ ----
    -a---        2012-03-15     14:32        420 87B6400A92EA72EBAA7C2CDDC127D86A75EFB6EA

    PS> cat .\87B6400A92EA72EBAA7C2CDDC127D86A75EFB6EA
    10C689645555D6FEC60917A19E6A7C6E0ED48FA6
    MIIBFAYJKoZIhvcNAQcDoIIBBTCCAQECAQAxgb4wgbsCAQAwJDAQMQ4wDAYDVQQDEwVIZW1tYQIQ2aQ2eBJ416tF05JJiMm7SjANBgkqhkiG9w0BAQEFAAS
    BgL/GPy3fpWJw619XhX966UvSTL1LYdlR7OdWUAZNRtz1g+fVbbuhR0jgwgmcXe+Hp9ACkpOnH4f6ekrVV5d1/r/EkAqO+4dCHpjt35hassMhtgZ2L9cVS+
    YnlY/oHm4mxB2ku8ajNqqUaxxMQm+uDWHQ1bMY0j5IIsEhFUVTDwJ2MDsGCSqGSIb3DQEHATAUBggqhkiG9w0DBwQIwwt79sUq+5qAGIUC3wkFh6H/4+zCs
    0dx5iQxKUdzBcEoQg==

### Example - Retrieving the encrypted credentials as a PSCredential

    PS> getCredential srv01

    UserName       Password
    --------       --------
    foouser        System.Security.SecureString
    
### Example - Retrieving the encrypted credentials as a System.Net.NetworkCredential
    
    PS> (getCredential srv01).GetNetworkCredential()
    
    UserName                                Password                                Domain
    --------                                --------                                ------
    foouser                                 barpassword

### Example - Using the encrypted credentials with Invoke-Command
    
    PS> Invoke-Command -Authentication Basic -Credential (getCredential srv01) -ComputerName srv01 -ScriptBlock { pwd }
    
    Path                                                        PSComputerName
    ----                                                        --------------
    C:\Users\foouser\Documents                                  srv01


Please feel free to use and we'd love to get your feedback and improvements.  
However, this script/tool is provided AS-IS and confers no rights.