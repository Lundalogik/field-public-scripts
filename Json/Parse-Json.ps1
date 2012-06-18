param( 
	[parameter(mandatory= $true, valuefrompipeline= $true)]
	[string] $inputObject
)
process {
	$state = "ARRAY"
	$hasDecimalPoint = $false
	$propertyValue = $null
	$lastState = $state
	$propertyName = $null
	$currentObject = $null
	$objectStack = New-Object System.Collections.Stack

	$whiteSpace = @( " ", "`t", "`r", "`n" )
	function invalidChar {
		throw "...$($inputObject.Substring([Math]::Max(0, $charIndex-10), 10)) <<< Error: Invalid char '$char' at position $charIndex in state $state"
	}
	
	for( $charIndex = 0; $charIndex -lt $inputObject.Length; $charIndex++ ) {
		#if( $lastState -ne $state ) { Write-Host "`r`n$state" }
		#$lastState = $state
		$char = $inputObject.Chars($charIndex)
		#Write-Host -NoNewline $char
		switch ( $state ) {
			"ARRAY_START" {
				$newArray = New-Object System.Collections.ArrayList
				if( $currentObject -ne $null ) {
					$currentObject | Add-Member -MemberType NoteProperty -Name $propertyName -Value $newArray
					$objectStack.Push( $currentObject )
				}
				$currentObject = $newArray
				if( $whiteSpace -contains $char ) {
					$state = "VALUE_START"
				} elseif( $char -eq """" -or $char -eq "'" ) {
					$propertyValue = ""
					$state = "VALUE_STRING"
				} elseif( $char -eq "[" ) {
					$state = "ARRAY_START"
				} elseif( $char -eq "{" ) {
					$state = "OBJECT_START"
				} else {
					$propertyValue = $char
					$hasDecimalPoint = $false
					$state = "VALUE_NUMERIC"
				}
			}
			"ARRAY" {
				switch( $char ) {
					"{" { $state = "OBJECT_START" }
					"[" { $state = "ARRAY_START" }
				}
			}
			"OBJECT_START" {
				if( $char -eq "[" ) {
					$state = "ARRAY_START"
				} else {
					$newObject = New-Object psobject
					if( $currentObject -is [System.Collections.ArrayList] ) {
						$currentObject.Add( $newObject ) | Out-Null
					} elseif( $currentObject -ne $null ) {
						$currentObject | Add-Member -MemberType NoteProperty -Name $propertyName -Value $newObject
					}
					if( $currentObject -is [System.Collections.ArrayList] -or $currentObject -ne $null ) {
						$objectStack.Push( $currentObject )
					}
					$currentObject = $newObject
					
					if( $char -ne "'" -and $char -ne """" -and $whiteSpace -notcontains $char ) { 
						$propertyName = $char
					} else {
						$propertyName = ""
					}
					$state = "PROPERTY"
				}
			}
			"PROPERTY_START" {
				if( $char -ne "'" -and $char -ne """" -and $whiteSpace -notcontains $char ) { 
					$propertyName = $char
				} else {
					$propertyName = ""
				}
				$state = "PROPERTY"
			}
			"PROPERTY" {
				if( $char -eq ":" ) {
					$state = "VALUE_START"
				} elseif( $char -ne "'" -and $char -ne """" -and $whiteSpace -notcontains $char ) {
					$propertyName += $char
				}
			}
			"VALUE_START" {
				if( $whiteSpace -contains $char ) {
					$state = "VALUE_START"
				} elseif( $char -eq """" -or $char -eq "'" ) {
					$propertyValue = ""
					$state = "VALUE_STRING"
				} elseif( $char -eq "[" ) {
					$state = "ARRAY_START"
				} elseif( $char -eq "{" ) {
					$state = "OBJECT_START"
				} else {
					$propertyValue = $char
					$hasDecimalPoint = $false
					$state = "VALUE_NUMERIC"
				}
			}
			"VALUE_NUMERIC" {
				if( $char -eq "}" -or $char -eq "]" -or $char -eq "," ) {
					if( $hasDecimalPoint ) { $propertyValue = [decimal]::Parse( $propertyValue, [System.Globalization.CultureInfo]::InvariantCulture ) }
					else { $propertyValue = [int]::Parse( $propertyValue, [System.Globalization.CultureInfo]::InvariantCulture  ) }

					if( $currentObject -is [System.Collections.ArrayList] ) {
						$currentObject.Add( $propertyValue ) | Out-Null
						$nextState = "VALUE_START"
					} else {
						$currentObject | Add-Member -MemberType NoteProperty -Name $propertyName -Value $propertyValue
						$nextState = "PROPERTY_START"
					}
					$propertyName = $null
					if( $char -eq "}" -or $char -eq "]" ) {
						$nextState = "OBJECT_END"
					} 
					$state = $nextState
				} else {
					if( $char -eq "." ) { $hasDecimalPoint = $true }
					$propertyValue += $char
				}
			}
			"VALUE_STRING" {
				if( $char -eq """" -or $char -eq "'" ) {
					if( $currentObject -is [System.Collections.ArrayList] ) {
						$currentObject.Add( $propertyValue ) | Out-Null
					} else {
						$currentObject | Add-Member -MemberType NoteProperty -Name $propertyName -Value $propertyValue
						$propertyName = $null
					}
					$state = "VALUE_END"
				} else {
					$propertyValue += $char
				}
			}
			"VALUE_END" {
				if( $char -eq "]" -or $char -eq "}" ) {
					$state = "OBJECT_END"
					if( $charIndex -eq $inputObject.Length - 1 -and $objectStack.Count -gt 0 ) {
						$currentObject = $objectStack.Pop()
					}
				} elseif( $char -eq "," ) { 
					if( $currentObject -is [System.Collections.ArrayList] ) {
						$state = "VALUE_START"
					} else {
						$state = "PROPERTY_START"
					}
				} elseif( $whiteSpace -notcontains $char ) { 
					invalidChar 
				}
			}
			"OBJECT_END" {
				if( $objectStack.Count -gt 0 ) {
					$currentObject = $objectStack.Pop()
					if( $char -eq "," ) {
						if( $currentObject -is [System.Collections.ArrayList] ) {
							$state = "VALUE_START"
						} else {
							$state = "PROPERTY_START"
						}
					} else {
						$state = "VALUE_END"
					}
				} elseif( $whiteSpace -notcontains $char ) {
					invalidChar
				}
			}
		}
	}
	if( $objectStack.Count -ne 0 ) {
		throw "...$($inputObject.Substring([Math]::Max(0, $inputObject.Length-10), 10)) <<< Error: Invalid JSON data. Missing $($objectStack.Count) closing brackets '}'."
	}

	$currentObject
}