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

$story = curl -s -X GET -H "X-TrackerToken: $trackerToken" "https://www.pivotaltracker.com/services/v5/projects/$projectId/stories/$id"
$story | Out-String | ConvertFrom-Json