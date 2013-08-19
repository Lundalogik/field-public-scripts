param( 
	[parameter( mandatory=$true, ValueFromPipelineByPropertyName=$true)]
	[int] $id,
	[string] $trackerToken = $env:PivotalTrackerToken,
	[int] $projectId = $env:PivotalTrackerProject 
)

if(!$trackerToken) {
	throw "Missing tracker token"
}
if(!$projectId) {
	throw "Missing tracker project"
}

$body = '{\"current_state\":\"delivered\"}'
curl -v -X PUT -H "X-TrackerToken: $trackerToken" -H "Content-Type: application/json" -d $body "https://www.pivotaltracker.com/services/v5/projects/$projectId/stories/$id"