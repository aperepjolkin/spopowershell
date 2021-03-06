
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
		if ($theArray[$leftPos].DeletedDate.CompareTo($theArray[$rightPos].DeletedDate) -ge 0)
		#if ($theArray[$leftPos].DeletedDate.CompareTo($theArray[$rightPos].DeletedDate) -le 0)
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
$theLimitedArray = New-Object Collections.ArrayList

function limitRecycleBinItemsCount($arrayToLimit,$dateLimit)
{
   $tcount = 0
   foreach($item2 in $arrayToLimit) {
    $itemFormatedDateLimit = $item2.DeletedDate.ToString('yyyy-MM-dd HH:mm:ss')
		   if ($itemFormatedDateLimit -ge $dateLimit) {
		       $theLimitedArray.Add($item2)
		   }
    }  	
}

$User = "name.surname@domain.onmicrosoft.com"
$siteUrl ="https://domain.sharepoint.com/sites/sitecollection"


$Password = Read-Host -Prompt "Enter password" -AsSecureString 
$userWhoDeletedFiles = Read-Host -Prompt "Enter user in format name.surname who deleted the files"
#$startDate = Read-Host -Prompt "Enter start date in format YYYY-MM-DD"
$startDate = "2015-09-03 00:00:00"
#$endDate = Read-Host -Prompt "Enter end date in format YYYY-MM-DD"
$endDate = "2015-09-04 23:59:59"
#$isSearchForAll = Read-Host -Prompt "Do you want to search all records?Enter 'y' or 'n'"
#$isSearchForAll = 'y'
$csvFileName = "c:\temp\report.csv"

$ctx = New-Object Microsoft.SharePoint.Client.ClientContext($siteUrl) 
$credentials = New-Object Microsoft.SharePoint.Client.SharePointOnlineCredentials($User, $Password) 
$ctx.Credentials = $credentials

 try {
    #Get RecycleBin
	$rb=$ctx.Site.RecycleBin
	$ctx.Load($rb)
	$ctx.ExecuteQuery()
	
	#$PeopleManager = New-Object Microsoft.SharePoint.Client.UserProfiles.PeopleManager($ctx)
	#$ctx.Load($PeopleManager)
	#Load recycle bin to array
    $theArray = @($rb)
	#Sort array recycle bin items with sorting algorithm 'Merge'
    $tempArray = New-Object Object[] $theArray.Count
	mergesorter $theArray $tempArray 0 ($theArray.Count - 1)

	Write-Host "Array items: `t" $theArray.Count
	Write-Host "Iterations: `t" $global:counter
	#Limit recycle bin items count to date
    limitRecycleBinItemsCount $theArray $startDate 
	#Sort limited array recycle bin items with sorting algorithm 'Merge'
	$tempArray2 = New-Object Object[] $theLimitedArray.Count
	mergesorter $theLimitedArray $tempArray2 0 ($theLimitedArray.Count - 1)
	Write-Host "Limited Array items: `t" $theLimitedArray.Count

	$Target = @()
	$csvReport = @()

	foreach($item in $theLimitedArray) {
		  #Format item deleted date
		  $itemFormatedDate = $item.DeletedDate.ToString('yyyy-MM-dd HH:mm:ss')
		  #Chceck if otem deleted date is greather then search filtre start dat
		   if ($itemFormatedDate -ge $startDate) {
		   #Check if item deleted is between start date and end date (timestamp)
		      if ($itemFormatedDate -ge $startDate -and $itemFormatedDate -le $endDate){
			    $t = "unknown"
				$dirName = $item.DirName
				$ctx.Load($item.DeletedBy)
				$ctx.ExecuteQuery()
				$splitDelimited = $item.DeletedBy.LoginName.split("|")
				$atDelimited = $splitDelimited[2].split("@")
				#Check the user who deleted items
				if ( $atDelimited[0].ToString() -eq $userWhoDeletedFiles){
				    $details = @{ 
						DeletedItem = $item;
						DeletedItemID = $item.Id;
					    DeletedItemTitle = $item.Title;               
					    DeletedBy = $atDelimited[0].ToString(); 
						DeletedDate = $item.DeletedDate;
						DeletedPath = $item.DirName;
						DeletedItemType = $item.ItemType
        			}                           
        			$csvReport += New-Object PSObject -Property $details 
			   			Write-Host "Deleted item:" $item.Title, "by " $atDelimited[0].ToString(), "Deleted Date: " $item.DeletedDate, "Location: "  $item.DirName, "Item type: " $item.ItemType	
				  }		
				$TargetObject = New-Object PSObject -Property @{
		            DirName = $dirName
				}
				$Target += $TargetObject
			  }
		    }
			else { 
			  #stop
			  break
			}

	 }
	    #Report output to CSV file
	  	$csvReport | sort-object -property @{Expression="DeletedItemType";Descending=$true}, @{Expression="DeletedDate";Descending=$true}, @{Expression="DeletedPath";Descending=$false} | export-csv -Path $csvFileName -NoTypeInformation -Encoding UTF8
	    #Sort selected items that were deleted by user. Folders first, then files, Deleted dates descending order and item path to build a hierarhy
	  	$csvReport | sort-object -property @{Expression="DeletedItemType";Descending=$true}, @{Expression="DeletedDate";Descending=$true}, @{Expression="DeletedPath";Descending=$false} | ForEach-Object {
	       Write-Host " Deleted Item Type: " $_."DeletedItemType"  "Title: " $_."DeletedItemTitle" "Deleted by: " $_."DeletedBy" "Deleted Date: " $_."DeletedDate" "Location: "  $_.DirName
		    $_.DeletedItem.Restore()
		 	$ctx.ExecuteQuery()
		   Write-Host "Item was restored"
	   	}
	  	$Target | Group-Object DirName | %{
	    	New-Object psobject -Property @{
	        	DirName = $_.Name
	        	Count = $_.Group.Count
			}
		}
 }
 catch [System.Exception] { 
        write-host -f red $_.Exception.ToString()    
}  
 Write-Host "Done"
 $ctx.Dispose()