Set-Alias fromJson .\fromJson.ps1

function assert( [scriptblock] $action ) {
	if( !$pipeline.Process( $_ ) ) {
		throw "Assert failed: $action"
	}
}

function test( [string] $json, [scriptblock[]] $assertions ) {
	$result = $json | fromJson
	$assertions | %{ 
		$assertion = $_
		@( , $result ) | %{ # Trick to set $_ (with array return values preserved) so it can be referenced in assertions
			New-Object psobject -Property @{ Json = $json; Input = $_; Assertion = $assertion; Result = ($assertion.InvokeReturnAsIs() -eq $true) }
		}
	}
}

function testPerformace( [int] $iterations, [string] $json ) {
	$times = @()
	for( $i = 0; $i -lt 5; $i++) {
		$sw = New-Object System.Diagnostics.Stopwatch
		$sw.Start()
		for( $j = 0; $j -lt $iterations; $j++ ) {
			$json | fromJson | Out-Null
		}
		$sw.Stop()
		$times += $sw.ElapsedTicks / $iterations
	}
	new-object psobject -Property @{ Json = $json; Iterations = $iterations; AverageMillisecondsFromJson = [TimeSpan]::FromTicks( ($times | measure -Average).Average ).TotalMilliseconds }
}

test "{""Hello"":""World""}" `
	{ $_.Hello -and $_.Hello -eq "World" }

test "{""Hello"":""World"",""Time"":""is"",""Revision"":7}" `
	{ $_.Hello -and $_.Hello -eq "World" }, `
	   { $_.Time -eq "is" }, `
	   { $_.Revision -eq 7 }
test @"
{Hello:'World',Time:'is',Revision:7,Foo:'Bar',User:'Username',Now:'2012-06-17T13:45:22Z',Amount:1232.32,Test:'Passed'}
"@ `
	{ $_.Hello -eq "World" }, `
	{ $_.Time -eq "is" }, `
	{ $_.Revision -eq 7 }, `
	{ $_.Foo -eq "Bar" }, `
	{ $_.User -eq "Username" }, `
	{ $_.Amount -eq 1232.32 }

test @"
{
   Title: 'Test',
   Link : {Title:'foo', Href:'links/foo'}
}
"@ `
	{ $_.Title -eq "Test" }, `
	{ $_.Link.Title -eq "foo" }, `
	{ $_.Link.Href -eq "links/foo" }

test @"
{
	"DisplayName":"Markus","UserName":"Markus","PasswordHash":"2mSUhtGfjMAjUERxeWN8umBO/0Y=",
	"Note":"","Profile":{"Href":"users/Markus/profile"},"Role":"Admin","Created":"2011-08-18T12:46:26.313Z",
	"Updated":"2012-02-07T08:38:28.447Z","Tags":{"Href":"users/Markus/tags","Title":"Markus"},
	"Status":"Active","Href":"users/Markus","Revision":10}
"@ `
	{ $_.DisplayName -eq "Markus" }, `
	{ $_.Username -eq "Markus" }, `
	{ $_.PasswordHash -eq "2mSUhtGfjMAjUERxeWN8umBO/0Y=" }, `
	{ $_.Note -eq "" }, `
	{ $_.Profile.Href -eq "users/Markus/profile" }, `
	{ $_.Role -eq "Admin" }, `
	{ $_.Created -eq "2011-08-18T12:46:26.313Z" }, `
	{ $_.Updated -eq "2012-02-07T08:38:28.447Z" }, `
	{ $_.Tags.Href -eq "users/Markus/tags" }, `
	{ $_.Tags.Title -eq "Markus" }, `
	{ $_.Status -eq "Active" }, `
	{ $_.Href -eq "users/Markus" }, `
	{ $_.Revision -eq 10 }

test @"
{ Title : 'test',
  One: { Two: { Three: "Four" } },
  Sub  : { Href: 'subHref' },
  Href : 'testHref'
}
"@ `
	{ $_.Href -eq "testHref" }, `
	{ $_.Sub.Href -eq "subHref" }, `
	{ $_.One.Two.Three -eq "Four" }

test @"
{ Title: 'Many items',
  Items: [1,2,3]
}
"@ `
	{ ( $_.Items | measure ).Count -eq 3 }, `
	{ $_.Items[0] -eq 1 }, `
	{ $_.Items[1] -eq 2 }, `
	{ $_.Items[2] -eq 3 }

test "[1,2,3]" `
	{ $_ -is [Array] }, `
	{ $_.Length -eq 3 }, `
	{ $_[0] -eq 1 }, `
	{ $_[1] -eq 2 }, `
	{ $_[2] -eq 3 }

test @"
{"Href":"subscriptions",
 "Link":[
 	{"Href":"subscriptions/EntityAdd"},
	{"Href":"subscriptions/EntityUpdate"},
	{"Href":"subscriptions/EntityDelete"},
	{"Href":"subscriptions/ServerError"},
	{"Href":"subscriptions/Authentication"},
	{"Href":"subscriptions/Management"}]
}
"@ `
	{ $_.Href -eq "subscriptions" }, `
	{ ( $_.Link | measure ).Count -eq 6 }


testPerformace 100 "{""Hello"":""World"",""Time"":""is"",""Revision"":7}"
testPerformace 100 @"
{Hello:'World',Time:'is',Revision:7,Foo:'Bar',User:'Username',Now:'2012-06-17T13:45:22Z',Amount:1232.32,Test:'Passed'}
"@
