# PKCS based password management 
# Password are stored by hostname and service (the latter is optional).
# A password store is a directory consisting of encrypted files and a thumbprint 
# file identifying the certificate used to encrypt/decrypt the credentials
#
# Usage: dot-source this file 
#
# MakeCert.exe is required to make self-signed certificates.
# All certificates are assumed to exist in cert:\currentuser\my.
#
# The following examples assumes $PWD is the directory containing the key files.
#
# To add a credential:
# setCredential myserver
# setCredential "myserver:winrm" username password
# To retrieve a credential:
# getCredential myserver
# getCredential "myserver:winrm"
#
# Reminder: To export a cert from store to file
# $cert = (gi cert:\CurrentUser\My\1234CERTHASH123412341234ETC ).Export( [System.Security.Cryptography.X509Certificates.X509ContentType]::Pfx, "chosenCertPass" )
# sc -Path "certfile.pfx" -Value $cert -Encoding byte
#
# Use 'get-help getCredential' and 'get-help setCredential' for more options.
[System.Reflection.Assembly]::LoadWithPartialName("System.Security") | out-null

function getAvailableCerts() {
	ls cert:\CurrentUser\My
}

filter SHA {
	$sha1 = new-object System.Security.Cryptography.SHA1Managed
	$utf8 = [System.Text.Encoding]::UTF8
	$str = new-object System.Text.StringBuilder

	$hash = $sha1.ComputeHash( $utf8.GetBytes( $_ ) )
	foreach ( $b in $hash ) { [void] $str.Append( $b.ToString( "X2" ) ) }
	$str.ToString()
}

function PKCSEncrypt($stringToEncrypt, $cert)
{
    $passbytes = [Text.Encoding]::UTF8.GetBytes($stringToEncrypt)
    $content = New-Object Security.Cryptography.Pkcs.ContentInfo -argumentList (,$passbytes)
    $env = New-Object Security.Cryptography.Pkcs.EnvelopedCms $content
    $env.Encrypt((new-object System.Security.Cryptography.Pkcs.CmsRecipient($cert)))

    [Convert]::Tobase64String($env.Encode())
}

function PKCSDecrypt($EncryptedString, $cert)
{
    $encodedBytes = [Convert]::Frombase64String($EncryptedString)
    $env = New-Object Security.Cryptography.Pkcs.EnvelopedCms
    $env.Decode($encodedBytes)
    $env.Decrypt($cert)
    $enc = New-Object System.Text.ASCIIEncoding

    $enc.GetString($env.ContentInfo.Content)
}

function selectCertificate() {
	$collection = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2Collection 
	getAvailableCerts | ?{ $_.HasPrivateKey } | %{ $collection.Add($_) } | Out-Null 
	$cert = [System.Security.Cryptography.x509Certificates.X509Certificate2UI]::SelectFromCollection( $collection, "Choose encryption key", "Select a certificate to encrypt your data with or click cancel to make a self signed certificate", 0) 
	if(!$cert) {
		Write-Host "No certificate selected. Creating a self-signed certificate.."
		$cert = newCert
	}
	$cert
}

function setCredential {
	param(
		[parameter(mandatory=$true,position=0)]
		[string] $keyName, 
		[parameter(mandatory=$true,position=1,parametersetname="UsernamePassword")]
		[string] $username,
		[parameter(mandatory=$true,position=2,parametersetname="UsernamePassword")]
		[string] $password,
		[parameter(mandatory=$true,position=1,parametersetname="PSCredential")]
		[System.Management.Automation.PSCredential] $credential,
		$cert,
		$store = (gi .)
	)
	if( $cert -eq $null ) {
		$cert = selectCertificate
	}
	if( $credential -ne $null ) {
		$networkcredential = $credential.GetNetworkCredential()
		$username = $networkcredential.Username
		$password = $networkcredential.Password
	}
	if( !($username -and $password) ) {
		throw "Must specify credential or non-empty username+password"
		return
	}
	sc -Encoding Ascii -Path (keyFilePath $store $keyName) -Value @( $cert.Thumbprint, (PKCSEncrypt "${username}:${password}" $cert) )
	$cred = (getCredential -keyName $keyName -store $store).GetNetworkCredential()
	if( $cred.Username -ne $username -or $cred.Password -ne $password ) {
		throw "Failed to encrypt credential"
	}
}

function removeCredential {
	param( 
		[parameter(mandatory=$true)]
		[string] $keyName, 
		$store = (gi .)
	)
	$keyFile = keyFilePath $store $keyName
	if( Test-Path -PathType Leaf $keyFile ) {
		rm $keyFile -Confirm
	}
}

function keyFilePath( $store, $keyName ) {
	Join-Path $store ($keyName | sha)
}

function getCredential {
	param( 
		[parameter(mandatory=$true)]
		[string] $keyName, 
		$store = (gi .)
	)
	$keyFile = keyFilePath $store $keyName
	if( Test-Path -PathType Leaf $keyFile ) {
		$keyData = gc -Encoding Ascii -Path $keyFile
		$username,$password = (PKCSDecrypt $keyData[1] (getAvailableCerts | ?{ $_.Thumbprint -eq $keyData[0] })).Split(":")
		new-object System.Management.Automation.PSCredential( $Username, (ConvertTo-SecureString -AsPlainText -Force -String $Password) )
	}
}	

function newCert() {
	$commonName = Read-Host -Prompt "Enter common name for certificate to be created"
	$subject = "CN=$commonName"
	$cert = getAvailableCerts | ?{ $_.Subject -eq $subject } | select -First 1
	if( $cert -ne $null ) {
		Write-Host "Using existing certificate with subject $($cert.Subject) thumbprint $($cert.Thumbprint)"
	} else {
		if( (get-command makecert -ErrorAction SilentlyContinue) -eq $null ) {
			$makeCertPath = ls "${env:ProgramFiles(x86)}\Microsoft SDKs\Windows\*\bin\makecert.exe" | select -ExpandProperty Fullname -last 1
			set-alias makecert $makeCertPath
		}

		makecert -r -pe -sky Exchange -n $subject -ss My | Out-Host
		Write-Host "Created certificate."
		$cert = getAvailableCerts | ?{ $_.Subject -eq $subject } | select -First 1
	}
	$cert | select * | Out-Host
	$cert
}

function randomPassword( $length = 25 ) {
	$characters = 'abcdefghkmnprstuvwxyzABCDEFGHKLMNPRSTUVWXYZ123456789-,.!'
	# select random characters
	$random = 1..$length | ForEach-Object { Get-Random -Maximum $characters.length }
	# output random pwd
	$private:ofs=""
	[String]$characters[$random]
}
