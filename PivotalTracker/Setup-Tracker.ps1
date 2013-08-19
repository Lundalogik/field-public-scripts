param( 
	[string] $trackerToken = $env:PivotalTrackerToken,
	[int] $projectId = $env:PivotalTrackerProject 
)

$readToken = Read-Host "Token [$trackerToken]"
if( !$readToken -and $trackerToken ) {
	$readToken = $trackerToken
}
$readProject = Read-Host "Default project ID [$projectId]"
if( !$readProject -and $projectId ) {
	$readProject = $projectId
}

Write-Host "Token: $readToken"
Write-Host "Default project: $readProject"

if( (Read-Host -Prompt "Save?" ) -imatch "y" ) {
	$env:PivotalTrackerToken = $readToken
	$env:PivotalTrackerProject = $readProject
	Write-Host "Please wait while updating environment on user level..."
	[Environment]::SetEnvironmentVariable( "PivotalTrackerToken", $readToken, [EnvironmentVariableTarget]::User )
	[Environment]::SetEnvironmentVariable( "PivotalTrackerProject", $readProject, [EnvironmentVariableTarget]::User )
	Write-Host "Done!"
} else {
	Write-Host "Aborting!"
}