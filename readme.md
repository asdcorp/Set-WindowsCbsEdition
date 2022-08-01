Set-WindowsCbsEdition
=====================
A PowerShell script to change the edition of Windows on a machine running lower
edition without any respect to the EditionMatrix.

Usage
-----
```
Set-WindowsCbsEdition.ps1 [-SetEdition Edition] [-GetTargetEditions] [-StageCurrent]
```

Parameters explanation:
 * `SetEdition` - Set edition to the provided one
 * `GetTargetEditions` - Get a list of target editions for the system
 * `StageCurrent` - Sets the script to stage the current edition instead of removing it

After a successful edition switch the script will immediately reboot the machine.

License
-------
The project is licensed under the terms of the GNU General Public License v3.0
