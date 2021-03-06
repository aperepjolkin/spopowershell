
# Paths to SDK. Please verify location on your computer.
Add-Type -Path "c:\Program Files\Common Files\microsoft shared\Web Server Extensions\15\ISAPI\Microsoft.SharePoint.Client.dll" 
Add-Type -Path "c:\Program Files\Common Files\microsoft shared\Web Server Extensions\15\ISAPI\Microsoft.SharePoint.Client.Runtime.dll"
Add-Type -Path "c:\Program Files\Common Files\microsoft shared\Web Server Extensions\15\ISAPI\Microsoft.SharePoint.Client.UserProfiles.dll" 





$global:counter = 0

# Merges two sorted halves of a subarray
# $theArray is an array of comparable objects
# $tempArray is an array to place the merged result
# $leftPos is the left-most index of the subarray
# $rightPos is the index of the start of the second half
# $rightEnd is the right-most index of the subarray
function merge($theArray, $tempArray, [int] $leftPos, [int] $rightPos, [int] $rightEnd)
{
	$leftEnd = $rightPos - 1
	$tmpPos = $leftPos
	$numElements = $rightEnd - $leftPos + 1
	
	# Main loop
	while (($leftPos -le $leftEnd) -and ($rightPos -le $rightEnd))
	{
		$global:counter++
		if ($theArray[$leftPos].DeletedDate.CompareTo($theArray[$rightPos].DeletedDate) -le 0)
		{
			$tempArray[$tmpPos++] = $theArray[$leftPos++]
		}
		else
		{
			$tempArray[$tmpPos++] = $theArray[$rightPos++]
		}
	}
	
	while ($leftPos -le $leftEnd)
	{
		$tempArray[$tmpPos++] = $theArray[$leftPos++]
	}
	
	while ($rightPos -le $rightEnd)
	{
		$tempArray[$tmpPos++] = $theArray[$rightPos++]
	}
	
	# Copy $tempArray back
	for ($i = 0; $i -lt $numElements; $i++, $rightEnd--)
	{
		$theArray[$rightEnd] = $tempArray[$rightEnd]
	}
}

# Makes recursive calls
# $theArray is an array of comparable objects
# $tempArray is an array to place the merged result
# $left is the left-most index of the subarray
# $right is the right-most index of the subarray
function mergesorter( $theArray, $tempArray, [int] $left, [int] $right )
{
	if ($left -lt $right)
	{
		[int] $center = [Math]::Floor(($left + $right) / 2)
		mergesorter $theArray $tempArray $left $center
		mergesorter $theArray $tempArray ($center + 1) $right
		merge $theArray $tempArray $left ($center + 1) $right
	}
}

$theArray = @()


$User = Read-Host -Prompt "Enter user you.name@yourtenant.onmicrosoft.com"
$siteUrl = Read-Host -Prompt "Enter site url"
$Password = Read-Host -Prompt "Enter password" -AsSecureString 

$startDate = Read-Host -Prompt "Enter start date in format YYYY-MM-DD"
$endDate = Read-Host -Prompt "Enter end date in format YYYY-MM-DD"
$isSearchForAll = Read-Host -Prompt "Do you want to search all records?Enter 'y' or 'n'"

if ($isSearchForAll -eq 'n') {
  $searchByUserName = Read-Host -Prompt "Enter user name in format 'Name Surname'"
}

$ctx = New-Object Microsoft.SharePoint.Client.ClientContext($siteUrl) 
$credentials = New-Object Microsoft.SharePoint.Client.SharePointOnlineCredentials($User, $Password) 

$ctx.Credentials = $credentials

try {
	$rb=$ctx.Site.RecycleBin
	$ctx.Load($rb)
	$ctx.ExecuteQuery()
	
	$PeopleManager = New-Object Microsoft.SharePoint.Client.UserProfiles.PeopleManager($ctx)
	$ctx.Load($PeopleManager)
 
    $theArray = @($rb)
    $tempArray = New-Object Object[] $theArray.Count
	mergesorter $theArray $tempArray 0 ($theArray.Count - 1)

	Write-Host "Array items: `t" $theArray.Count
	Write-Host "Iterations: `t" $global:counter
	

	$Target = @()
	
	foreach($item in $theArray) {
	$ctx.Load($item.DeletedBy)
		  $ctx.ExecuteQuery()
		  $userProfile = $PeopleManager.GetPropertiesFor($item.DeletedBy.LoginName)
		  $ctx.Load($userProfile)
		  $ctx.ExecuteQuery()
	      if ($isSearchForAll -eq 'y') {
		  $itemFormatedDate = $item.DeletedDate.ToString('yyyy-MM-dd')
		   if ($itemFormatedDate -le $endDate) {
		      if ($itemFormatedDate -ge $startDate -and $itemFormatedDate -le $endDate)
              {
			     #Write-Host "Deleted item:" $item.Title, "by " $userProfile.DisplayName, "Deleted Date: " $item.DeletedDate, "Location: "  $item.DirName

				  $TargetObject = New-Object PSObject -Property @{
		            UserName =  $userProfile.DisplayName;
				  }
				  $Target += $TargetObject
			  }
		    }
			else
			{ 
			  #stop
			  break
			}
		 }
	  	 else {
	        if ( $userProfile.DisplayName -eq $searchByUserName){
			    Write-Host "Deleted item:" $item.Title, "by " $userProfile.DisplayName, "Deleted Date: " $item.DeletedDate, "Location: "  $item.DirName
			}
	     }
	 }
	 
	 $Target | Group-Object UserName | %{
	    New-Object psobject -Property @{
	        UserName = $_.Name
	        Count = $_.Group.Count
    }
}
	 
 }
 catch [System.Exception] { 
        write-host -f red $_.Exception.ToString()    
}  
 
 $ctx.Dispose()