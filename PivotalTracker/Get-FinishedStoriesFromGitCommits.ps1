param(
	[parameter(mandatory=$true)]
	$sinceCommit
)
$commits = git log --pretty=format:"%h(==)%an(==)%ai(==)%s" -i --grep "\[Fi" "${sinceCommit}.."
$storyinfo = $commits | %{
	$commit = $_.Split("(==)", [StringSplitOptions]::RemoveEmptyEntries)
	$subject = $commit[3]
	$storyids = $subject | select-string "(?<=#)\d+" -AllMatches | select -ExpandProperty Matches | select -ExpandProperty Value
	New-Object psobject -Property @{ `
		"Commit" = $commit[0]; `
		"Author" = $commit[1]; 
		"Date" = [DateTime]::Parse( $commit[2] );
		"Subject" = $subject;
		"Stories" = $storyids | %{ New-Object psobject -Property @{ "id" = $_ } } }
}

$storyinfo
