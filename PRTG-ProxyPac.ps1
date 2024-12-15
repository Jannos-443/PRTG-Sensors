<#
    .SYNOPSIS
    PRTG Sensor script to monitor Proxy PAC result and syntax

    .DESCRIPTION
    Using powershell this script validates a proxy pac result.
    
    You can use the -Test_URL parameter to define a URL, -ProxyPacUrl to define the PAC file and -MatchResult with a regex String to validate the output against.

    .PARAMETER MatchResult
    Regular expression to match the returned PAC Result 
    e.g. "^(PROXY proxy.europe.contoso.com:8080)$" or "^(DIRECT)$"

    Example2: ^(Test123.*|ServiceTest)$ excludes "ServiceTest" and every Service starting with "Test123"

    #https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_regular_expressions?view=powershell-7.1

    .PARAMETER Test_HOST
    Set the Host to verify the PAC against
    -Test_HOST "google.com"

    .PARAMETER Test_URL
    Set the URL to verify the PAC against
    -Test_URL "https://login.microsoft.com"

    .PARAMETER PacTester_Path
    Path to the pactester.exe from https://github.com/manugarg/pacparser
    -PacTester_Path "C:\temp\pacparser\pactester.exe"

    .PARAMETER ProxyPacUrl
    Use this parameter to set http/https path to the proxy pac
    -ProxyPacUrl "http://pac.europe.contoso.com/proxy.pac?location=DE_HAMBURG_Server"

    .EXAMPLE
    Sample call from PRTG EXE/Script Advanced
    -ProxyPacUrl "http://pac.europe.contoso.com/proxy.pac" -Test_URL "https://login.microsoft.com" -MatchResult "^(PROXY proxy.europe.contoso.com:8080)$"
    
    Download and put pactester.exe in a directory for example: C:\Program Files (x86)\PRTG Network Monitor\Custom Sensors\EXEXML\pacparser\pactester.exe

    .NOTES
    Version:        1.00
    Author:         Jannos-443
    URL:            https://github.com/Jannos-443/
    Creation Date:  21.08.2024

    This script is based on https://github.com/manugarg/pacparser - https://pacparser.manugarg.com/
#>
param(
    [string]$ProxyPacUrl = "",
    [string]$Test_URL = "https://login.microsoftonline.com",
    [string]$Test_HOST = "",
    [string]$MatchResult = "^(DIRECT)$",
    [string]$PacTester_Path = "C:\Program Files (x86)\PRTG Network Monitor\Custom Sensors\EXEXML\pacparser\pactester.exe" # "C:\temp\pacparser\pactester.exe"
)

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

# Validate Parameter
if (-not (Test-Path -Path $PacTester_Path)) {
    $Output = "pactester.exe not found (-PacTester_Path `"YourFilePath`") || $($PacTester_Path)"
    $Output = $Output.Replace("<", "")
    $Output = $Output.Replace(">", "")
    $Output = $Output.Replace("#", "")
    Write-Output "<prtg>"
    Write-Output "<error>1</error>"
    Write-Output "<text>$($Output)</text>"
    Write-Output "</prtg>"
    Exit
}

if ($ProxyPacUrl -eq "") {
    $output = "ProxyPacUrl Variable is empty"
    Write-Output "<prtg>"
    Write-Output "<error>1</error>"
    Write-Output "<text>$($Output)</text>"
    Write-Output "</prtg>"
    Exit
}

if (($Test_URL -eq "") -and ($Test_HOST -eq "")) {
    $output = "Test_URL and Test_Host Variables are empty"
    Write-Output "<prtg>"
    Write-Output "<error>1</error>"
    Write-Output "<text>$($Output)</text>"
    Write-Output "</prtg>"
    Exit
}

if ($MatchResult -eq "") {
    $output = "MatchResult Variable is empty"
    Write-Output "<prtg>"
    Write-Output "<error>1</error>"
    Write-Output "<text>$($Output)</text>"
    Write-Output "</prtg>"
    Exit
}


# Create TMP Files
$Tmp_ProxyPacFile = (New-TemporaryFile).FullName
$Tmp_std_output_path = (New-TemporaryFile).FullName
$Tmp_err_output_path = (New-TemporaryFile).FullName

# Download PAC File
Invoke-WebRequest -Uri $ProxyPacUrl -OutFile $Tmp_ProxyPacFile

#Check URL
if (($null -ne $Test_URL) -and ($Test_URL -ne "")) {
    $proc = start-process -FilePath $pactester_path -ArgumentList "-p $Tmp_ProxyPacFile -u $Test_URL" -Wait -passthru -RedirectStandardOutput $Tmp_std_output_path -RedirectStandardError $Tmp_err_output_path
}

#Check Host
elseif (($null -ne $Test_HOST) -and ($Test_HOST -ne "")) {
    $proc = start-process -FilePath $pactester_path -ArgumentList "-p $Tmp_ProxyPacFile -h $Test_HOST" -Wait -passthru -RedirectStandardOutput $Tmp_std_output_path -RedirectStandardError $Tmp_err_output_path
}

else {

}

if ($proc.ExitCode -ne 0) {
    try {
        $Output = Get-Content -Path $Tmp_err_output_path
        $Output = $Output.Trim()
    }
    catch {
        $Output = "no error output found"
    }
    $Output = $Output.Replace("<", "")
    $Output = $Output.Replace(">", "")
    $Output = $Output.Replace("#", "")
    Write-Output "<prtg>"
    Write-Output "<error>1</error>"
    Write-Output "<text>Error $($proc.ExitCode) - $($Output)</text>"
    Write-Output "</prtg>"
    Exit
}

$std_output = Get-Content -Path $Tmp_std_output_path
$std_output = $std_output.Trim()

if ($std_output -match $MatchResult) {
    $prtg_result = 0
}
else {
    $prtg_result = 1
}
if($Test_URL -ne ""){
    $xmloutputtxt = "PAC= $($ProxyPacUrl) -- URL/HOST= $($Test_URL) -- OUTPUT=$($std_output)"
}
else{
    $xmloutputtxt = "PAC= $($ProxyPacUrl) -- URL/HOST= $($Test_HOST) -- OUTPUT=$($std_output)"
}

$xmloutputtxt = $xmloutputtxt.Replace("<", "")
$xmloutputtxt = $xmloutputtxt.Replace(">", "")
$xmloutputtxt = $xmloutputtxt.Replace("#", "")

if ($xmloutputtxt.Length -le 600) {
    $xmloutputtxt = $xmloutputtxt.Substring(0, $xmloutputtxt.Length)
}
else {
    $xmloutputtxt = $xmloutputtxt.Substring(0, 600)
}

if ($null -ne $Tmp_std_output_path) {
    $null = Remove-Item -Path $Tmp_std_output_path -ErrorAction SilentlyContinue
}
if ($null -ne $Tmp_err_output_path) {
    $null = Remove-Item -Path $Tmp_err_output_path -ErrorAction SilentlyContinue
}
if ($null -ne $Tmp_ProxyPacFile) {
    $null = Remove-Item -Path $Tmp_ProxyPacFile -ErrorAction SilentlyContinue
}

$xmloutput = "<prtg>"

$xmloutput += "<text>$($xmloutputtxt)</text>"

$xmloutput += "<result>
<channel>Error</channel>
<value>$($prtg_result)</value>
<unit>count</unit>
<limitmode>1</limitmode>
<LimitMaxError>0</LimitMaxError>
</result>"

$xmloutput += "</prtg>"

Write-Output $xmloutput
