<#
.SYNOPSIS
	Delivers all finished stories in PivotalTracker and outputs the stories as PowerShell objects
.DESCRIPTION
	Uses the "deliver_all_finished" endpoint in the PivotalTracker API.
	The script returns the XML returned by the API as PowerShell objects.
	Example output:
	
Updated 3 finished stories

id            : 18855475
project_id    : 378493
story_type    : feature
url           : http://www.pivotaltracker.com/story/show/18855475
estimate      : 1
current_state : delivered
description   :
name          : Shopper should be able to remove product from shopping cart
requested_by  : Johan Andersson
owned_by      : Johan Andersson
created_at    : 2011/09/19 00:00:00 UTC
updated_at    : 2011/09/26 16:12:25 UTC
labels        : cart,shopping

id            : 18855477
project_id    : 378493
story_type    : feature
url           : http://www.pivotaltracker.com/story/show/18855477
estimate      : 1
current_state : delivered
description   :
name          : Cart manipulation should be AJAXy
requested_by  : Johan Andersson
owned_by      : Johan Andersson
created_at    : 2011/09/19 00:00:00 UTC
updated_at    : 2011/09/26 16:12:25 UTC
labels        : cart,shopping

#>
param( 	
	[parameter(mandatory=$true)]
	[int] $project_id, 
	[parameter(mandatory=$true)]
	[string] $token,
	[bool] $use_ssl = $true 
)

$scheme = "http"
if( $use_ssl ) {
	$scheme = "https"
}

$responseText = curl -s -H "X-TrackerToken: $TOKEN" -X PUT "`"${scheme}://www.pivotaltracker.com/services/v3/projects/${PROJECT_ID}/stories/deliver_all_finished`"" -d '""'
# remove type attributes - they just make our output more complex
$responseText = $responseText -replace "\stype=`"[^`"]+`"",""
$xml = [xml] $responseText
Write-Host "Updated $(($xml.stories.story | measure).Count) finished stories"
$xml.stories.story