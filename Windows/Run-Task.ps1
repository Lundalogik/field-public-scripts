param( $taskName )
schtasks /run /tn $taskName | Out-Null
