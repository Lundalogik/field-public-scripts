<#

Welcome to an episode of Fun with functions and pipelines!
==========================================================

By dot-sourcing this file your PowerShell prompt will be powered up with
a couple of functions that examplifies what one can do by passing functions
and objects along the pipeline.

Example usage
=============
What website has the fastest response time? Google or bing?

PS> { "http://google.com", "http://bing.com" | getUrlSilent | totalMilliseconds } | repeatTimes 10 |
 averageOf Result -property TotalMilliseconds | ft -autosize

  Average Result
  ------- ------
121,92222 http://google.com
166,99781 http://bing.com

The answer is Google of course!

Are we sure? Let's repeat the test twice with a little delay between each run.

PS> { { "http://google.com", "http://bing.com" | getUrlSilent | totalMilliseconds } | repeatTimes 10
 | averageOf Result -property TotalMilliseconds } | repeatTimes 2 -delayBetween 2000 | ft -autosize

  Average Result
  ------- ------
119,90257 http://google.com
167,51829 http://bing.com
 115,2785 http://google.com
164,53711 http://bing.com

Yes, the answer is still Google.

So, how would you use "averageOf" to get the average of the average?

#>

function repeatTimes {
	param( [int]$times, [int]$delayBetween = 0 )
	process {
		$f = $_
		1..$times | %{
			&$f
			if( $delayBetween ) {
				sleep -milliseconds $delayBetween
			}
		}
	}
}

function averageOf {
	param( $group, $property )
	begin {
		$acc = @()
	}
	process {
		$acc += $_
	}
	end {
		$acc | group $group | %{ 
			new-object psobject -property @{ 
				$group = $_.Name; 
				Average = $_.Group | measure -Average $property | select -ExpandProperty Average 
			}
		}
	}
}

function totalMilliseconds {
	process {
		$sw = [System.Diagnostics.Stopwatch]::StartNew()
		new-object psobject -property @{ 
			Result = & $_; 
			TotalMilliseconds = $sw.Elapsed.TotalMilliseconds 
		}
	}
}

function getUrlSilent {
	process { 
		[scriptblock]::Create("curl -s $_ | out-null; ""$_""")
	}
}