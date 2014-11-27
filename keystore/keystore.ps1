# PKCS based password management 
# Password are stored by hostname and service (the latter is optional).
# A password store is a directory consisting of encrypted files and a thumbprint 
# file identifying the certificate used to encrypt/decrypt the credentials
#
# Usage: dot-source this file 
#
# MakeCert.exe is required to make self-signed certificates.
#
# The following examples assumes $PWD is the directory containing the key files.
#
# To add a credential:
# set-key myserver
# set-key "myserver:winrm" username password
# To retrieve a credential:
# get-key myserver
# get-key "myserver:winrm"
#
# To export a cert to a PFX:
# export-certificate <thumbprint>
# To select a cert:
# select-certificate
#
# Use 'get-help get-key' and 'get-help set-key' for more options.
[System.Reflection.Assembly]::LoadWithPartialName("System.Security") | out-null

function getAvailableCerts() {
	ls -Recurse cert:
}

filter SHA {
	$sha1 = new-object System.Security.Cryptography.SHA1Managed
	$utf8 = [System.Text.Encoding]::UTF8
	$str = new-object System.Text.StringBuilder

	$hash = $sha1.ComputeHash( $utf8.GetBytes( $_ ) )
	foreach ( $b in $hash ) { [void] $str.Append( $b.ToString( "X2" ) ) }
	$str.ToString()
}

function PKCSEncrypt( 
	[parameter(mandatory=$true)] 
	[string] $stringToEncrypt, 
	[parameter(mandatory=$true)] 
	[System.Security.Cryptography.X509Certificates.X509Certificate2] $cert)
{
    $passbytes = [Text.Encoding]::UTF8.GetBytes($stringToEncrypt)
    $content = New-Object Security.Cryptography.Pkcs.ContentInfo -argumentList (,$passbytes)
    $env = New-Object Security.Cryptography.Pkcs.EnvelopedCms $content
    $env.Encrypt((new-object System.Security.Cryptography.Pkcs.CmsRecipient($cert)))

    [Convert]::Tobase64String($env.Encode())
}

function PKCSDecrypt( 
	[parameter(mandatory=$true)] 
	[string] $EncryptedString, 
	[parameter(mandatory=$true)] 
	[System.Security.Cryptography.X509Certificates.X509Certificate2] $cert)
{
    $encodedBytes = [Convert]::Frombase64String($EncryptedString)
    $env = New-Object Security.Cryptography.Pkcs.EnvelopedCms
    $env.Decode($encodedBytes)
    try {
    	$env.Decrypt($cert)
	} catch {
		throw "Failed to decrypt the credential using the given certificate."
	}
    $enc = New-Object System.Text.ASCIIEncoding

    $enc.GetString($env.ContentInfo.Content)
}

function selectCertificate() {
	$startInfo = Get-Process -id $PID | select -ExpandProperty StartInfo
	if( $null -ne $startInfo -and $startInfo.Arguments -imatch "-noninteractive" ) {
		throw "Cannot select certificate interactively when PowerShell is executed with -NonInteractive"
	}
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

	if( $cert.GetType().Name -eq "String" ) {
		$cert = getAvailableCerts | ?{ $_.Subject -match $cert } | select -first 1
	}
	sc -Encoding Ascii -Path (keyFilePath $store $keyName) -Value @( $cert.Thumbprint, (PKCSEncrypt "${username}:${password}" $cert) )
	$cred = getCredential -keyName $keyName -store $store
	if( $cred ) {
		$networkcredential = $cred.GetNetworkCredential()
	} else {
		$networkcredential = $null
	}

	if( !$networkcredential -or $networkcredential.Username -ne $username -or $networkcredential.Password -ne $password ) {
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
		$cert = getAvailableCerts | ?{ $_.Thumbprint -eq $keyData[0] } | select -first 1
		if(!$cert) {
			throw ("Cannot find the requested certificate: {0}" -f $keyData[0])
		}
		$username,$password = (PKCSDecrypt $keyData[1] $cert).Split(":")
		if($username -and $password) {
			new-object System.Management.Automation.PSCredential( $Username, (ConvertTo-SecureString -AsPlainText -Force -String $Password) )
		}
	}
}	

function newCert($commonName = (Read-Host -Prompt "Enter common name for certificate to be created")) {
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

function exportCertificate {
	param( 
		[parameter(mandatory=$true, valuefrompipelinebypropertyname=$true,parametersetname="Thumbprint")]
		[string] $thumbprint,
		[parameter(mandatory=$true, valuefrompipeline=$true, parametersetname="Certificate")]
		[System.Security.Cryptography.X509Certificates.X509Certificate2] $certificate,
		[parameter(mandatory=$true)]
		[string] $Path,
		[string] $Password
	)
	if( !$certificate -and $thumbprint ) {
		$certificate = getAvailableCerts | ?{ $_.thumbprint -eq $thumbprint } | select -First 1
	}
	if( !$certificate ) {
		throw "No cert found or no cert specified"
	}
	$certBytes = $certificate.Export( [System.Security.Cryptography.X509Certificates.X509ContentType]::Pfx, $Password )
	sc -Path $Path -Value $certBytes -Encoding byte
	gi $Path
}

set-alias Get-Key getCredential
set-alias Set-Key setCredential 
set-alias Remove-Key removeCredential 
set-alias New-Certificate newCert
set-alias Select-Certificate selectCertificate
set-alias Export-Certificate exportCertificate
set-alias Get-RandomString randomPassword