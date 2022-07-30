<#
Set-WindowsCbsEdition
Copyright (C) 2022 Gamers Against Weed

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <https://www.gnu.org/licenses/>.
#>

<#
.SYNOPSIS
	Changes the current Windows edition

.DESCRIPTION
	Changes the current Windows edition to an edition provided in the parameter. Use the -GetTargetEditions parameter to retrieve the list of possible target editions for the system.

.LINK
	https://github.com/Gamers-Against-Weed/Set-WindowsCbsEdition

.PARAMETER SetEdition
	Provides desired edition to change to.

.PARAMETER GetTargetEditions
	Get target editions for the upgrade.

.PARAMETER StageCurrent
	Sets the script to stage the current edition instead of removing it.
#>

#Requires -RunAsAdministrator

Param (
    [Parameter()]
    [String]$SetEdition,

    [Parameter()]
    [Switch]$GetTargetEditions,

    [Parameter()]
    [Switch]$StageCurrent
)

function Get-AssemblyIdentity {
	param (
		[String]$PackageName
	)

	$PackageName = [String]$PackageName
	$packageData = ($PackageName -split '~')

	if($packageData[3] -eq '') {
		$packageData[3] = 'neutral'
	}

	Return "<assemblyIdentity name=`"$($packageData[0])`" version=`"$($packageData[4])`" processorArchitecture=`"$($packageData[2])`" publicKeyToken=`"$($packageData[1])`" language=`"$($packageData[3])`" />"
}

function Write-UpgradeCandidates {
	param (
		[HashTable]$InstallCandidates
	)

	$editionCount = 0
	Write-Host 'Editions that can be upgraded to:'
	foreach($candidate in $InstallCandidates.Keys) {
		Write-Host "Target Edition : $candidate"
		$editionCount = $editionCount + 1
	}

	if($editionCount -eq 0) {
		Write-Host '(no editions are available)'
	}
}

function Write-UpgradeXml {
	param (
        [Array]$RemovalCandidates,
        [Array]$InstallCandidates,
        [Boolean]$Stage
    )

	$removeAction = 'remove'
	if($Stage) {
		$removeAction = 'stage'
	}

	Write-Output '<?xml version="1.0"?>'
	Write-Output '<unattend xmlns="urn:schemas-microsoft-com:unattend">'
	Write-Output '<servicing>'

	foreach($package in $InstallCandidates) {
		Write-Output '<package action="install">'
		Write-Output (Get-AssemblyIdentity -PackageName $package)
		Write-Output '</package>'
	}

	foreach($package in $RemovalCandidates) {
		Write-Output "<package action=`"$removeAction`">"
		Write-Output (Get-AssemblyIdentity -PackageName $package)
		Write-Output '</package>'
	}

	Write-Output '</servicing>'
	Write-Output '</unattend>'
}

function Write-Usage {
	Get-Help $PSCommandPath -detailed
}

$getTargetsParam = $GetTargetEditions.IsPresent
$stageCurrentParam = $StageCurrent.IsPresent

if($SetEdition -eq '' -and ($false -eq $getTargetsParam)) {
	Write-Usage
	Exit 1
}

$removalCandidates = @();
$installCandidates = @{};

$packages = Get-ChildItem -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\Packages' | select Name | where name -Match '^.*\\Microsoft-Windows-.*Edition~'
foreach($package in $packages) {
	$state = (Get-ItemProperty -Path "Registry::$($package.Name)").CurrentState
	$packageName = ($package.Name -split '\\')[-1]
	$packageEdition = (($packageName -split 'Edition~')[0] -split 'Microsoft-Windows-')[-1]

	if($state -eq 0x40) {
		if($null -eq $installCandidates[$packageEdition]) {
			$installCandidates[$packageEdition] = @()
		}

		if($false -eq ($packageName -in $installCandidates[$packageEdition])) {
			$installCandidates[$packageEdition] = $installCandidates[$packageEdition] + @($packageName)
		}
	}

	if((($state -eq 0x50) -or ($state -eq 0x70)) -and ($false -eq ($packageName -in $removalCandidates))) {
		$removalCandidates = $removalCandidates + @($packageName)
	}
}

if($getTargetsParam) {
	Write-UpgradeCandidates -InstallCandidates $installCandidates
	Exit
}

if($false -eq ($SetEdition -in $installCandidates.Keys)) {
	Write-Error "The system cannot be upgraded to `"$SetEdition`""
	Exit 1
}

$xmlPath = $Env:Temp+'\CbsUpgrade.xml'

Write-UpgradeXml -RemovalCandidates $removalCandidates `
	-InstallCandidates $installCandidates[$SetEdition] `
	-Stage $stageCurrentParam >$xmlPath

Write-Host 'Starting the upgrade process. This may take a while...'

Use-WindowsUnattend -UnattendPath $xmlPath -NoRestart -Online -ErrorAction Stop
Remove-Item -Path $xmlPath -Force
Restart-Computer
