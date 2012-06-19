param( 
	[parameter(mandatory= $true, valuefrompipeline= $true)]
	$inputObject
)
begin {
	$isArray = $false
	$json = ""
	function toJson( $obj ) {
		$props = $inputobject | gm -MemberType Properties | select -expandproperty Name
		"{"
		$firstProp = $true
		$props | %{
			if( !$firstProp ) {
				","
			}
			$collection = [scriptblock]::Create("`$inputObject.$_").Invoke()
			if( $collection.Count -gt 0 ) {
				"""$_"":"
			}
			if( $collection.Count -gt 1 ) {
				"["
				$firstItem = $true
				$collection | ?{ $_ } | %{
					Write-Host "Array value: $_"
					if( !$firstItem ) { "," }
					$firstItem = $false
					toJson $_
				}
				"]"
			} elseif( $collection.Count -eq 1 ) {
				$val = $collection | select -First 1
                if($val){
    				$type = $val.GetType()
    				if( $type -eq [DateTime] ) {
    					"""$($val.ToString('s'))Z"""
    				} elseif( $type.BaseType -eq [ValueType] ) {
    					$val
    				} else {
    					""""
    					$val.ToString()
    					""""
    				}
                }else{
                    "null"
                }
			}
			if( $firstProp ) { $firstProp = $false }
		}
		"}"
	}
}
process {
	$jsonString = [String]::Join( "", (toJson $inputObject))
	if( $json.Length -and !$isArray ) {
		$json = "[$json,$jsonString"
		$isArray = $true
	} elseif( $json.Length -and $isArray ) {
		$json += ",$jsonString"
	} else {
		$json = $jsonString
	}
}
end {
	if( $isArray ) {
		Write-Output "$json]"
	} else {
		Write-Output $json
	}
}