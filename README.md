# PRTG-PKI-CRL.PS1

<!-- ABOUT THE PROJECT -->
### About The Project
Project Owner: Jannos-443

PRTG Sensor script to monitor a certificate revocation list (CRL)

Free and open source: [MIT License](https://github.com/Jannos-443/PRTG-PKI-CRL/blob/master/LICENSE)

Sensor is a Updated Fork from https://github.com/dwydler/Powershell-Skripte/tree/master/Paessler/PRTG

<!-- GETTING STARTED -->
1. Place `# PRTG-PKI-CRL.ps1` under `C:\Program Files (x86)\PRTG Network Monitor\Custom Sensors\EXEXML`

2. Create new sensor

   | Settings | Value |
   | --- | --- |
   | EXE/Script Advanced | PRTG-PKI-CRL.ps1 |
   | Parameters | -url "http://crl.usertrust.com/USERTrustRSACertificationAuthority.crl" |
   | Scanning Interval | 15 minutes |


## Usage

### check status auf crl and delta crl if available

```powershell
-url "http://crl.usertrust.com/USERTrustRSACertificationAuthority.crl"
```

### check status of crl only

```powershell
-url "http://crl.usertrust.com/USERTrustRSACertificationAuthority.crl" -IgnoreDeltaCRL
```

### check status of crl and error if delta crl could not be fetched

```powershell
-url "http://crl.usertrust.com/USERTrustRSACertificationAuthority.crl" -ErrorOnMissingDelta
```

![Image](media/ok.png)