<#
.SYNOPSIS
PRTG Sensor script to monitor Paket loss, Jitter and Latency with the Network Assessment Tool

.DESCRIPTION
Using Microsoft Teams Assessment Tool to monitor the network quality to microsoft teams.
Can be used to verify that the WAN connection has good quality.

.PARAMETER prtgpush
Use this parameter to enable PRTG HTTP/S Push
-prtgpush

.PARAMETER prtgserveruri
Use this parameter to enable specify the prtg push url
-prtgpush "http://prtg:5050/yourGUIDfromSensor"

.PARAMETER NetworkAssessmentPath
Path to the NetworkAssessmentTool Folder, default is "C:\Program Files (x86)\Microsoft Teams Network Assessment Tool\"
-NetworkAssessmentPath "C:\temp\Microsoft Teams Network Assessment Tool\"

.PARAMETER process_timout_untill_kill
time to wait to kill the NetworkAssessmentTool Process, just in case the process does not run fine

.PARAMETER debug
enable debug output for troubleshooting

.PARAMETER CustomRelayIP
use to force the usage of a Custom Relay IP
-CustomRelayIP "52.114.249.112"

.PARAMETER CustomRelayFQDN
use to force the usage of a Custom Relay FQDN
-CustomRelayIP "worldaz.tr.teams.microsoft.com"

.PARAMETER CustomMediaDuration
use to change the call length for testing
-CustomMediaDuration 60

.EXAMPLE
1. Download Microsoft Network Assessment Tool -> https://www.microsoft.com/en-us/download/details.aspx?id=103017
2. Sample call from PRTG EXE/Script Advanced
-CustomRelayIP "52.114.249.112" -CustomMediaDuration 60

.NOTES
Version:        1.00
Author:         Jannos-443
URL:            https://github.com/Jannos-443/
Creation Date:  25.10.2024

This script is based on https://www.msxfaq.de/teams/admin/microsoft_teams_network_assessment_tool.htm from frank@carius.de

# https://www.microsoft.com/en-us/download/details.aspx?id=103017
Microsoft's recommended values for maximum Latency, Jitter and Packet loss are as follows:  
Metric                        |  Target
Latency (one way)             |  < 30ms
Latency (RTT)	               |  < 60ms
Burst packet loss	            |  <1% during any 200 ms interval
Packet loss	                  |  <0.1% during any 15s interval
Packet inter-arrival Jitter   |  <15ms during any 15s interval
Packet reorder                |  <0.01% out-of-order packets


Parameter to edit in NetworkAssessmentTool.exe.config
   <add key="MediaDuration" value="30"/>
   <add key="Relay.FQDN" value="worldaz.tr.teams.microsoft.com"/>
   <add key="Relay.IP" value=""/>

#>
param (
   [switch]$prtgpush = $false,
   [string]$prtgserveruri = "",
   [string]$NetworkAssessmentPath = "C:\Program Files (x86)\Microsoft Teams Network Assessment Tool\",
   [int]$process_timout_untill_kill = 600,
   [switch]$debug = $false,
   [string]$CustomRelayIP = "",
   [string]$CustomRelayFQDN = "",
   [string]$CustomMediaDuration = ""
)

#Catch all unhandled Errors
trap {
   $Output = "line:$($_.InvocationInfo.ScriptLineNumber.ToString()) char:$($_.InvocationInfo.OffsetInLine.ToString()) --- message: $($_.Exception.Message.ToString()) --- line: $($_.InvocationInfo.Line.ToString()) "
   $Output = $Output.Replace("<", "")
   $Output = $Output.Replace(">", "")
   $Output = $Output.Replace("#", "")
   Write-Output "<prtg>"
   Write-Output "<error>1</error>"
   Write-Output "<text>$Output</text>"
   Write-Output "</prtg>"
   Exit
}

if (-not (Test-Path -Path "$($NetworkAssessmentPath)NetworkAssessmentTool.exe")) {
   Write-Output "<prtg>"
   Write-Output " <error>1</error>"
   Write-Output " <text>Error - $($NetworkAssessmentPath)NetworkAssessmentTool.exe not found!</text>"
   Write-Output "</prtg>"
   Exit
}

if (-not (Test-Path -Path "$($NetworkAssessmentPath)NetworkAssessmentTool.exe.config")) {
   Write-Output "<prtg>"
   Write-Output " <error>1</error>"
   Write-Output " <text>Error - $($NetworkAssessmentPath)NetworkAssessmentTool.exe.config not found!</text>"
   Write-Output "</prtg>"
   Exit
}

#Remove Old files
Get-ChildItem -Path "$env:LOCALAPPDATA\Microsoft Teams Network Assessment Tool" -Filter "*.csv" -ErrorAction SilentlyContinue | Remove-Item -ErrorAction SilentlyContinue
Get-ChildItem -Path "$env:LOCALAPPDATA\Microsoft Teams Network Assessment Tool" -Filter "*.txt" -ErrorAction SilentlyContinue | Remove-Item -ErrorAction SilentlyContinue

$content = Get-Content -Path "$($NetworkAssessmentPath)NetworkAssessmentTool.exe.config" -Raw
if ($CustomRelayIP) {
   if ($content -notlike "<add key=`"Relay.IP`" value=`"$($CustomRelayIP)`"/>") {
      $content = $content -replace '<add key="Relay\.IP" value="\S*"\/>', "<add key=`"Relay.IP`" value=`"$($CustomRelayIP)`"/>"
      Out-File -FilePath "$($NetworkAssessmentPath)NetworkAssessmentTool.exe.config" -Encoding utf8 -InputObject $content
   }
}
if ($CustomRelayFQDN) {
   if ($content -notlike "<add key=`"Relay.FQDN`" value=`"$($CustomRelayFQDN)`"/>") {
   $content = $content -replace '<add key="Relay\.FQDN" value="\S*"\/>', "<add key=`"Relay.FQDN`" value=`"$($CustomRelayFQDN)`"/>"
   Out-File -FilePath "$($NetworkAssessmentPath)NetworkAssessmentTool.exe.config" -Encoding utf8 -InputObject $content
   }
}
if ($CustomMediaDuration) {
   if ($content -notlike "<add key=`"MediaDuration`" value=`"$($CustomMediaDuration)`"/>") {
   $content = $content -replace '<add key="MediaDuration" value="\d*"\/>', "<add key=`"MediaDuration`" value=`"$($CustomMediaDuration)`"/>"
   Out-File -FilePath "$($NetworkAssessmentPath)NetworkAssessmentTool.exe.config" -Encoding utf8 -InputObject $content
   }
}


if ($debug) {
   write-host "Execute Assessment tool"
}
$Time = 0
if ($debug) {
   $Process = Start-Process -FilePath ($NetworkAssessmentPath + "NetworkAssessmentTool.exe") -NoNewWindow -workingDirectory $NetworkAssessmentPath -ArgumentList "/qualitycheck"
}
else {
   $Process = Start-Process -FilePath ($NetworkAssessmentPath + "NetworkAssessmentTool.exe") -workingDirectory $NetworkAssessmentPath -ArgumentList "/qualitycheck"
}


Start-Sleep -Seconds 1
While (Get-Process -Name NetworkAssessmentTool -ErrorAction SilentlyContinue) {
   if ($Time -gt $process_timout_untill_kill) {
      Stop-Process -Name NetworkAssessmentTool -ErrorAction SilentlyContinue

      $Output = "process timeout! killed the process $($Process.ProcessName) ($($Process.Id))"
      $Output = $Output.Replace("<", "")
      $Output = $Output.Replace(">", "")
      $Output = $Output.Replace("#", "")
      Write-Output "<prtg>"
      Write-Output " <error>1</error>"
      Write-Output " <text>Error, $($output)</text>"
      Write-Output "</prtg>"
      Exit
   }
   else {

      Write-Host "process still running waiting another 10s"
      
      Start-Sleep -Seconds 10
      $Time += 10
   }
}
if ($debug) {
   write-host "Parsing Result CSV"
}
$result_csv = Get-ChildItem -Path "$env:LOCALAPPDATA\Microsoft Teams Network Assessment Tool" -Filter "*.csv" | Select-Object -First 1

$result = Import-Csv $result_csv.fullname -Delimiter ","

if (($result | Measure-Object).count -eq 0) {
   Write-Output "<prtg>"
   Write-Output " <error>1</error>"
   Write-Output " <text>Error, CSV File is empty. Try Put a Relay. FQDN or Relay.IP into the NetworkAssessmentTool.exe.config (worldaz.tr.teams.microsoft.com)</text>"
   Write-Output "</prtg>"
   Exit
}

if ($debug) {
   write-host "Calculating results"
}

$PacketLossRate = ($result | ForEach-Object { $_."LossRate-%".replace(",", ".") } | Measure-Object -Average -Maximum)
$AverageJitterInMs = ($result | ForEach-Object { $_."AverageJitter-Ms".replace(",", ".") } | Measure-Object -Average -Maximum)
$AverageLatencyInMs = ($result | ForEach-Object { $_."AverageLatency-Ms".replace(",", ".") } | Measure-Object -Average -Maximum)

if ($debug) {
   write-host " PacketLossRate      (avg): $($PacketLossRate.Average)"
   write-host " AverageJitter-Ms    (avg): $($AverageJitterInMs.Average)"
   write-host " AverageLatency-Ms   (avg): $($AverageLatencyInMs.Average)"
}
 
$prtgresult = '<?xml version="1.0" encoding="UTF-8" ?>
      <prtg>
         <result>
            <channel>Packet loss rate avg</channel>
            <value>' + [math]::Round($PacketLossRate.Average, 2) + '</value>
            <float>1</float>
            <unit>percent</unit>
         </result>
         <result>
            <channel>Packet loss rate max</channel>
            <value>' + [math]::Round($PacketLossRate.Maximum, 2) + '</value>
            <float>1</float>
            <unit>percent</unit>
         </result>
         <result>
            <channel>Jitter avg</channel>
            <value>' + [math]::Round($AverageJitterInMs.Average, 2) + '</value>
            <float>1</float>
            <unit>Custom</unit>
            <customunit>Milliseconds</customunit>
         </result>
         <result>
            <channel>Jitter max</channel>
            <value>' + [math]::Round($AverageJitterInMs.Maximum, 2) + '</value>
            <float>1</float>
            <unit>Custom</unit>
            <customunit>Milliseconds</customunit>
         </result>
         <result>
            <channel>Latency avg</channel>
            <value>' + [math]::Round($AverageLatencyInMs.Average, 2) + '</value>
            <float>1</float>
            <unit>Custom</unit>
            <customunit>Milliseconds</customunit>
         </result>
         <result>
            <channel>Latency max</channel>
            <value>' + [math]::Round($AverageLatencyInMs.Maximum, 2) + '</value>
            <float>1</float>
            <unit>Custom</unit>
            <customunit>Milliseconds</customunit>
         </result>
      </prtg>'

Write-Output $prtgresult
#$prtgresult | out-file result.xml

if ($prtgpush) {
   write-host "Post Result to PRTG-Server"
   try {
      $Answer = Invoke-RestMethod `
         -method "GET" `
         -URI ($prtgserveruri + "?content=$prtgresult")
      if ($answer."Matching Sensors" -eq "1") {
         write-host "Found 1 Sensors  OK"
      }
      else {
         write-Warning "Invalid reply"
         $answer
         #         exit 1
      }
   }
   catch {
      write-Warning "Unable to invoke-Restmethod  $($_.Exception.Message)"
   }
}

if ($debug) {
   write-host "Assessment:End"
}