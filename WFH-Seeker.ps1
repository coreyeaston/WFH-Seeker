<#
    .SYNOPSIS
    Retrieves job listings on Seek in the Work from home "location" and finds matching keywords

    .DESCRIPTION
    The WFH-Seeker.ps1 script retrieves job listings from seek.com.au in the ICT classification, between 80-200k, sorted in date listed order and with the location of Work from home

    .INPUTS
    None. You can't pipe objects to WFH-Seeker.ps1.

    .OUTPUTS
    A single JobDetails.csv file will be created in the scripts directory

    .EXAMPLE
    PS> .\WFH-Seeker.ps1

    .EXAMPLE
    PS> ./WFH-Seeker.ps1
#>



#Requires -Modules PowerHTML

$jobs = @()

#Seek seems to have a bug where you can't go past page 27
$totalPages = 27

For ($page = 1 ; $page -le $totalPages ; $page++)
{
    $jobs += (invoke-webrequest -Uri "https://www.seek.com.au/jobs-in-information-communication-technology?page=$($page)&salaryrange=80000-200000&salarytype=annual&sortmode=ListedDate&where=Work%20from%20home").Links | Where-Object { $_.outerHTML -like '*jobTitle*' } | Select-Object href
}

$JobDetails = @()

#To load a specific job listing un-comment the below, for testing
# $jobs = new-object psobject
# $jobs | add-member noteproperty href "/job/68780202?type=standout"

ForEach ($_ in $jobs)
    {
        #Job listings are turned in the format of "/job/68780202?type=standout" OR "/job/68780202?type=standard" - Split from the ? and return just data before the ?
        $listing = Invoke-WebRequest -Uri "https://www.seek.com.au$($_.href.Split('?')[0])" | ConvertFrom-Html

        #Select the HTML nodes of type List, Paragraph and Strong, Filter for our keyword, select only unique records and then return just the raw data (InnerText)
        $WorkFromHome = ($listing.SelectNodes('//li | //p | //strong') | Where-Object { $_.InnerText -like "*work from home*" } | Select-Object -unique).InnerText

        $Work_From_Home = ($listing.SelectNodes('//li | //p | //strong') | Where-Object { $_.InnerText -like "*work-from-home*" } | Select-Object -unique).InnerText

        $WFH = ($listing.SelectNodes('//li | //p | //strong') | Where-Object { $_.InnerText -like "*wfh*" } | Select-Object -unique).InnerText

        $Remote = ($listing.SelectNodes('//li | //p | //strong') | Where-Object { $_.InnerText -like "*remote*" } | Select-Object -unique).InnerText

        $FlexibleWorking = ($listing.SelectNodes('//li | //p | //strong') | Where-Object { $_.InnerText -like "*flexible working*" } | Select-Object -unique).InnerText

        $DaysFromHome = ($listing.SelectNodes('//li | //p | //strong') | Where-Object { $_.InnerText -like "*days from home*" } | Select-Object -unique).InnerText

        #Accounts for matching multiple key words
        $temp_obj = @()

        $temp_obj += $WorkFromHome
        $temp_obj += $WFH
        $temp_obj += $Remote
        $temp_obj += $FlexibleWorking
        $temp_obj += $Work_From_Home
        $temp_obj += $DaysFromHome

        #Removes duplicate if the keywords are in the same block of data, Eg "WFH/remote 2 days a week" would be matched twice for containg both WFH and remote
        $temp_obj = $temp_obj | Select-Object -Unique

        $obj = [PSCustomObject]@{
            Job_Title = ($listing.SelectNodes('//h1'))[0].InnerText
            Company = ($listing.SelectNodes('//span') | Where-Object { $_.OuterHtml -like "*advertiser-name*" }).InnerText
            URL = "https://www.seek.com.au$($_.href.Split('?')[0])"
            "Contains_work from home" = if($null -ne $WorkFromHome) {"X"}
            "Contains_work-from-home" = if($null -ne $Work_From_Home) {"X"}
            "Contains_wfh" = if($null -ne $WFH) {"X"}
            "Contains_remote" = if($null -ne $Remote) {"X"}
            "Contains_flexible working" = if($null -ne $FlexibleWorking) {"X"}
            "Contains_days from home" = if($null -ne $DaysFromHome) {"X"}
            #Combines the array of matched words into one column for our csv, seperate by a hyphen
            Details = $temp_obj -join ' - '
            }

        $JobDetails += $obj
    }

#Export to CSV
$JobDetails | Export-Csv -NoTypeInformation JobDetails.csv

