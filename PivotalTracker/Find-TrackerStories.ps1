param( 
	[string] $filter,
	[int] $limit = 100,
	[int] $offset = 0,
	[string] $withState,
	[string] $trackerToken = $env:PivotalTrackerToken,
	[int] $projectId = $env:PivotalTrackerProject 
)

if(!$trackerToken) {
	throw "Missing tracker token"
}
if(!$projectId) {
	throw "Missing tracker project"
}

$query = "limit=$limit&offset=$offset"
if( $withState ) {
	$query += "&with_state=$($withState.ToLower())"
}
if( $filter ) {
	$query += "&filter=$($filter.Replace(' ', '%20'))"
}
$tmpFile = [System.IO.Path]::GetTempFileName()
curl -s -o $tmpFile -X GET -H "Accept: application/json; charset=iso-8859-1" -H "X-TrackerToken: $trackerToken" "https://www.pivotaltracker.com/services/v5/projects/$projectId/stories?$query"
$story = gc -Encoding UTF8 $tmpFile | Out-String
rm $tmpFile
$story | ConvertFrom-Json