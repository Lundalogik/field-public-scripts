PivotalTracker API Powershell Scripts
===

Here is a set of scripts that can be used to access the Pivotal Tracker API using Powershell v3.0 or later.

These scripts are only covering a small set of all the operations found in the API. For extending the scripts, please take a look at the [documentation](https://www.pivotaltracker.com/help/api/rest/v5).

The setup
---
You will need to have Powershell v3.0 installed, cURL in your path and your API token (found at the end of your PivotalTracker profile page) and a project id.

    PS> Setup-Tracker.ps1 
    Token []: abcdef
    Default project ID []: 1234
    Token: abcdef
    Default project: 1234
    Save?: y
    Please wait while updating environment on user level...
    Done!

Getting stories
---
Using the Find-TrackerStories.ps1 script you can get a list of Powershell objects of the [returned search result](https://www.pivotaltracker.com/help/api/rest/v5#Stories).

Example:

    PS> Find-TrackerStories.ps1 -filter label:test -limit 10 -offset 2 -withState Delivered
    url             : https://www.pivotaltracker.com/story/show/1234
    project_id      : 1234
    story_type      : feature
    labels          : {@{project_id=1234; id=123; kind=label; name=planning; created_at=2012-12-11T12:11:23Z; updated_at=2012-12-11T12:11:23Z}}
    description     : description of the story
    estimate        : 2
    id              : 1234
    kind            : story
    owned_by_id     : 1234
    name            : The name of the story
    created_at      : 2013-08-19T07:59:01Z
    requested_by_id : 12345
    current_state   : delivered
    updated_at      : 2013-08-19T18:43:33Z


Getting stories from Git commits
---
If you are using the [Git commit hook](http://pivotallabs.com/level-up-your-development-workflow-with-github-pivotal-tracker/) with Pivotal Tracker you can use git log to find stories that you have fixed or finished using the Git commit message syntax.

Example:

    PS> Get-FinishedStoriesFromGitCommits.ps1 -sinceCommit 4dca0ec

    Date    : 2013-08-19 17:15:50
	Author  : Johan Andersson
	Commit  : 7db8dde
	Stories : @{id=1234}
	Subject : [Fixes #1234] ...strange cast exceptions HierarchyLink-Link from background thread

	Date    : 2013-08-16 17:48:55
	Author  : Johan Andersson
	Commit  : da8505c
	Stories : @{id=2345}
	Subject : [Fixes #2345] Makes create/update usage quantity commands set the creator/updater

	Date    : 2013-08-16 15:48:07
	Author  : Johan Andersson
	Commit  : 91e2b2d
	Stories : @{id=3456}
	Subject : [Fixes #3456] Fixes bug with exception when right-clicking on new

	Date    : 2013-08-16 10:35:37
	Author  : Johan Andersson
	Commit  : 9924120
	Stories : @{id=56789}
	Subject : Implements copy work order menu option in ShellApp/ old windows client [Finishes #56789]

Updating the state of a story
---

Use the Start-TrackerStory.ps1 and Deliver-TrackerStory.ps1 to change the state of a story.

Example:
    
    PS> Get-TrackerStory.ps1 1234567 | Deliver-TrackerStory.ps1
    url             : https://www.pivotaltracker.com/story/show/1234
    project_id      : 1234
    story_type      : feature
    labels          : {@{project_id=1234; id=123; kind=label; name=planning; created_at=2012-12-11T12:11:23Z; updated_at=2012-12-11T12:11:23Z}}
    description     : description of the story
    estimate        : 2
    id              : 1234
    kind            : story
    owned_by_id     : 1234
    name            : The name of the story
    created_at      : 2013-08-19T07:59:01Z
    requested_by_id : 12345
    current_state   : delivered
    updated_at      : 2013-08-19T18:43:33Z

Since the id parameter of the scripts uses the ValueFromPipelineByPropertyName binding you can use the scripts together with Find-TrackerStories or Get-FinishedStoriesFromGitCommits.ps1.

Example which delivers all finished stories found in Git commit messages since commit 4dca0ec:

    PS> Get-FinishedStoriesFromGitCommits.ps1 -sinceCommit 4dca0ec | Select -ExpandProperty Stories | Deliver-TrackerStory.ps1