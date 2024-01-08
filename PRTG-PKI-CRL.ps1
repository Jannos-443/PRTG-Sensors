<#   
    .SYNOPSIS
    PRTG Sensor script to monitor a certificate revocation list (CRL)

    .DESCRIPTION
    Using Powershell to monitor crl and crl delta status

    Copy this script to the PRTG probe EXEXML scripts folder (${env:ProgramFiles(x86)}\PRTG Network Monitor\Custom Sensors\EXEXML)
    and create a "EXE/Script Advanced. Choose this script from the dropdown and set at least:

    + Scanning Interval: minimum 15 minutes

    .PARAMETER url
    full url of the crl (including http://)

    .PARAMETER IgnoreDeltaCRL
    disable monitoring of delta crl

    .EXAMPLE
    Sample call from PRTG EXE/Script Advanced
    PRTG-PKI-CRL.ps1 -url "http://crl.contoso.com/pki/Contoso%20Europe%20Sub%20CA.crl"

    Changelog:
    08.02.2024 - release

    Author:  Jannos-443
    https://github.com/Jannos-443/PRTG-PKI-CRL

    based on the script from Daniel Wydler
    https://github.com/dwydler/Powershell-Skripte/tree/master/Paessler/PRTG
#>

param(
    [string] $url = "",
    [switch] $IgnoreDeltaCRL = $false
)


#Catch all unhandled Errors
trap {
    $Output = "line:$($_.InvocationInfo.ScriptLineNumber.ToString()) char:$($_.InvocationInfo.OffsetInLine.ToString()) --- message: $($_.Exception.Message.ToString()) --- line: $($_.InvocationInfo.Line.ToString()) "
    $Output = $Output.Replace("<", "")
    $Output = $Output.Replace(">", "")
    $Output = $Output.Replace("#", "")
    Write-Output "<prtg>"
    Write-Output "<error>1</error>"
    Write-Output "<text>$($Output)</text>"
    Write-Output "</prtg>"
    Exit
}

# Error if there's anything going on
$ErrorActionPreference = "Stop"

[string] $xmlOutput = ""

#set match strings                                                                                                                                      
[string] $strOidCommonName = " 06 03 55 04 03 "
[string] $strUtcTime = " 17 0D "

#MAYBE ADD This later to monitor all CA´s automaticly
<#
$domain = "contoso.com"
$domain = "DC=$($domain)"
$domain = $domain.Replace(".", ", DC=")
$DN = "LDAP://CN=CDP, CN=Public Key Services, CN=Services, CN=Configuration, $($domain)"
$DN = $DN.ToString()
$Searcher = $null
$Searcher = New-Object DirectoryServices.DirectorySearcher
$Searcher.SearchRoot = $DN
$Searcher.Filter = '(&(objectCategory=cRLDistributionPoint))'
$Result = $Searcher.FindAll()
$CNs = $Result.Properties.cn
foreach($CN in $CNs)
{
Write-Host ([URI]::EscapeUriString($CN))
}
#>


if (-not ($url -match "^((http:\/\/)?([\da-z\.-]+)\..*\.crl)$")) {
    Write-Output "<prtg>"
    Write-Output " <error>1</error>"
    Write-Output " <text>You must provide a valid crl url (-url)</text>"
    Write-Output "</prtg>"
    Exit
}

#Remove the + in the URL for the delta
if ($url -match "^(.*\+\.crl)$") {
    $url = $url.Replace("+.crl", ".crl")
}

$xmlOutput = "<?xml version=""1.0"" encoding=""utf-8"" standalone=""yes"" ?>`n"
$xmlOutput += "<prtg>`n"
$xmlOutputText = ""

# Get CRL information
[Microsoft.PowerShell.Commands.WebResponseObject] $objCrlFile = Invoke-WebRequest -Uri $url -Method Get -UseBasicParsing:$true 

#Import the CRL file to byte array
try {
    [byte[]] $byCrlBytes = $objCrlFile.Content
}
catch {
    Throw "Invalid CRL format $_.exception.message"
}


#convert crl bytes to hex string                                                                                                                        
$CRLHexString = ($byCrlBytes | ForEach-Object { "{0:X2}" -f $_ }) -join " "


#get the relevent bytes using the match strings                                                                                                         
[System.Array] $saCaNameBytes = ($CRLHexString -split $strOidCommonName)[1] -split " " | ForEach-Object { [Convert]::ToByte("$_", 16) }                                                    
[System.Array] $saThisUpdateBytes = ($CRLHexString -split $strUtcTime)[1] -split " "  | ForEach-Object { [Convert]::ToByte("$_", 16) }                                                     
[System.Array] $saNextUpdateBytes = (($CRLHexString -split $strUtcTime)[2] -split " ")[0..12] | ForEach-Object { [Convert]::ToByte("$_", 16) }                                             

                                                                                                                                                   
#convert data to readable values                                                                                                                        
[string] $strCaName = ($saCaNameBytes[2..($saCaNameBytes[1] + 1)] | ForEach-Object { [char]$_ }) -join ""                                                                               
[DateTime] $dtThisUpdate = [Management.ManagementDateTimeConverter]::ToDateTime(("20" + $(($saThisUpdateBytes | ForEach-Object { [char]$_ }) -join "" -replace "z")) + ".000000+000") 
[DateTime] $dtNextUpdate = [Management.ManagementDateTimeConverter]::ToDateTime(("20" + $(($saNextUpdateBytes | ForEach-Object { [char]$_ }) -join "" -replace "z")) + ".000000+000") 
                                                                                                                                                            
[int]$intIsvalid = [int][bool]::Parse( ($dtNextUpdate -gt (Get-Date) ) )
[int] $intCreatedFor = [math]::truncate( ((Get-Date) - $dtThisUpdate ).TotalHours)
[int] $intExpiration = [math]::truncate( ($dtNextUpdate - (Get-Date) ).TotalHours)

#region: PRTG Output

$xmlOutput += "<result>
<channel>CRL Valid</channel>
<value>$($intIsvalid)</value>
<unit>Custom</unit>
<CustomUnit>Status</CustomUnit>
<valuelookup>prtg.standardlookups.boolean.statetrueok</valuelookup>
</result>"

$xmlOutput += "<result>
<channel>CRL Created before</channel>
<value>$($intCreatedFor)</value>
<unit>Custom</unit>
<CustomUnit>h</CustomUnit>
</result>"

$xmlOutput += "<result>
<channel>CRL Expiration</channel>
<value>$($intExpiration)</value>
<unit>Custom</unit>
<CustomUnit>h</CustomUnit>
<LimitMode>1</LimitMode>
<LimitMinWarning>30</LimitMinWarning>
<LimitMinError>15</LimitMinError>
</result>"

$xmlOutputText += "CA Name: $strCaName" 

#endregion PRTG Output

#region: Delta CRL
if (-not $IgnoreDeltaCRL) {
    $url = "$($url.Replace(".crl","+.crl"))"

    # Abruf der CRL Informationen
    [Microsoft.PowerShell.Commands.WebResponseObject] $objCrlFile = Invoke-WebRequest -Uri $url -Method Get -UseBasicParsing:$true 


    #Import the CRL file to byte array
    try {
        [byte[]] $byCrlBytes = $objCrlFile.Content
    }
    catch {
        Throw "Invalid CRL format $_.exception.message"
    }


    #convert crl bytes to hex string                                                                                                                        
    $CRLHexString = ($byCrlBytes | ForEach-Object { "{0:X2}" -f $_ }) -join " "


    #get the relevent bytes using the match strings                                                                                                         
    [System.Array] $saCaNameBytes = ($CRLHexString -split $strOidCommonName)[1] -split " " | ForEach-Object { [Convert]::ToByte("$_", 16) }                                                    
    [System.Array] $saThisUpdateBytes = ($CRLHexString -split $strUtcTime)[1] -split " "  | ForEach-Object { [Convert]::ToByte("$_", 16) }                                                     
    [System.Array] $saNextUpdateBytes = (($CRLHexString -split $strUtcTime)[2] -split " ")[0..12] | ForEach-Object { [Convert]::ToByte("$_", 16) }                                             

                                                                                                                                                   
    #convert data to readable values                                                                                                                        
    [string] $strCaName = ($saCaNameBytes[2..($saCaNameBytes[1] + 1)] | ForEach-Object { [char]$_ }) -join ""                                                                               
    [DateTime] $dtThisUpdate = [Management.ManagementDateTimeConverter]::ToDateTime(("20" + $(($saThisUpdateBytes | ForEach-Object { [char]$_ }) -join "" -replace "z")) + ".000000+000") 
    [DateTime] $dtNextUpdate = [Management.ManagementDateTimeConverter]::ToDateTime(("20" + $(($saNextUpdateBytes | ForEach-Object { [char]$_ }) -join "" -replace "z")) + ".000000+000") 
                                                                                                                                                            
    [int]$intIsvalid = [int][bool]::Parse( ($dtNextUpdate -gt (Get-Date) ) )
    [int] $intCreatedFor = [math]::truncate( ((Get-Date) - $dtThisUpdate ).TotalHours)
    [int] $intExpiration = [math]::truncate( ($dtNextUpdate - (Get-Date) ).TotalHours)

    #region: PRTG Output

    $xmlOutput += "<result>
    <channel>Delta Valid</channel>
    <value>$($intIsvalid)</value>
    <unit>Custom</unit>
    <CustomUnit>Status</CustomUnit>
    <valuelookup>prtg.standardlookups.boolean.statetrueok</valuelookup>
    </result>"
    
    $xmlOutput += "<result>
    <channel>Delta Created before</channel>
    <value>$($intCreatedFor)</value>
    <unit>Custom</unit>
    <CustomUnit>h</CustomUnit>
    </result>"
    
    $xmlOutput += "<result>
    <channel>Delta Expiration</channel>
    <value>$($intExpiration)</value>
    <unit>Custom</unit>
    <CustomUnit>h</CustomUnit>
    <LimitMode>1</LimitMode>
    <LimitMinWarning>4</LimitMinWarning>
    <LimitMinError>3</LimitMinError>
    </result>"

    #endregion PRTG Output
}
#endregion Delta CRL

$xmlOutputText = $xmlOutputText.Replace("<", "")
$xmlOutputText = $xmlOutputText.Replace(">", "")
$xmlOutputText = $xmlOutputText.Replace("#", "")
$xmlOutput = $xmlOutput + "<text>$($xmlOutputText)</text>"
$xmlOutput += "</prtg>"

#finish Script - Write Output

Write-Output $xmlOutput