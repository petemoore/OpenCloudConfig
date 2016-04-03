<#
This Source Code Form is subject to the terms of the Mozilla Public
License, v. 2.0. If a copy of the MPL was not distributed with this
file, You can obtain one at http://mozilla.org/MPL/2.0/.
#>
Configuration CompilerToolChainConfig {
  Import-DscResource -ModuleName PSDesiredStateConfiguration
  # log folder for installation logs
  File LogFolder {
    Type = 'Directory'
    DestinationPath = ('{0}\log' -f $env:SystemDrive)
    Ensure = 'Present'
  }
  File ToolsFolder {
    Type = 'Directory'
    DestinationPath = ('{0}\tools' -f $env:SystemDrive)
    Ensure = 'Present'
  }

  Chocolatey VCRedist2010Install {
    Ensure = 'Present'
    Package = 'vcredist2010'
    Version = '10.0.40219.1'
  }
  Chocolatey WindowsSdkInstall {
    Ensure = 'Present'
    Package = 'windows-sdk-8.1'
    Version = '8.100.26654.0'
  }

  Script ShPath {
    DependsOn = @('[Script]MozillaBuildInstall')
    GetScript = { @{ Result = ($env:PATH.Contains(('{0}\mozilla-build\msys\bin' -f $env:SystemDrive))) } }
    SetScript = {
      [Environment]::SetEnvironmentVariable('PATH', ('{0};{1}\mozilla-build\msys\bin' -f $env:PATH, $env:SystemDrive), 'Machine')
    }
    TestScript = { if ($env:PATH.Contains(('{0}\mozilla-build\msys\bin' -f $env:SystemDrive))) { $true } else { $false } }
  }
  Script AutoconfPath {
    DependsOn = @('[Script]MozillaBuildInstall')
    GetScript = { @{ Result = ($env:PATH.Contains(('{0}\mozilla-build\msys\local\bin' -f $env:SystemDrive))) } }
    SetScript = {
      [Environment]::SetEnvironmentVariable('PATH', ('{0};{1}\mozilla-build\msys\local\bin' -f $env:PATH, $env:SystemDrive), 'Machine')
    }
    TestScript = { if ($env:PATH.Contains(('{0}\mozilla-build\msys\local\bin' -f $env:SystemDrive))) { $true } else { $false } }
  }

  Script MercurialSymbolicLink {
    DependsOn = @('[Script]MercurialInstall', '[Script]MozillaBuildInstall')
    GetScript = { @{ Result = (Test-Path -Path ('{0}\mozilla-build\hg' -f $env:SystemDrive) -ErrorAction SilentlyContinue) } }
    SetScript = {
      if ($PSVersionTable.PSVersion.Major -gt 4) {
        New-Item -ItemType SymbolicLink -Path ('{0}\mozilla-build' -f $env:SystemDrive) -Name 'hg' -Target ('{0}\Mercurial' -f $env:ProgramFiles)
      } else {
        & cmd @('/c', 'mklink', '/D', ('{0}\mozilla-build\hg' -f $env:SystemDrive), ('{0}\Mercurial' -f $env:ProgramFiles))
      }
    }
    TestScript = { (Test-Path -Path ('{0}\mozilla-build\hg' -f $env:SystemDrive) -ErrorAction SilentlyContinue) }
  }
  Script MercurialPath {
    DependsOn = @('[Script]MercurialSymbolicLink')
    GetScript = { @{ Result = ($env:PATH.Contains(('{0}\mozilla-build\hg' -f $env:SystemDrive))) } }
    SetScript = {
      [Environment]::SetEnvironmentVariable('PATH', ('{0};{1}\mozilla-build\hg' -f $env:PATH, $env:SystemDrive), 'Machine')
    }
    TestScript = { if ($env:PATH.Contains(('{0}\mozilla-build\hg' -f $env:SystemDrive))) { $true } else { $false } }
  }
  File MercurialCertFolder {
    DependsOn = '[Script]MercurialSymbolicLink'
    Type = 'Directory'
    DestinationPath = ('{0}\mozilla-build\hg\hgrc.d' -f $env:SystemDrive)
    Ensure = 'Present'
  }
  Script MercurialConfigure {
    DependsOn = '[File]MercurialCertFolder'
    GetScript = { @{ Result = ((Test-Path -Path ('{0}\mozilla-build\hg\mercurial.ini' -f $env:SystemDrive) -ErrorAction SilentlyContinue) -and (Test-Path -Path ('{0}\mozilla-build\hg\hgrc.d\cacert.pem' -f $env:SystemDrive) -ErrorAction SilentlyContinue)) } }
    SetScript = {
      (New-Object Net.WebClient).DownloadFile('https://raw.githubusercontent.com/MozRelOps/OpenCloudConfig/master/userdata/Configuration/Mercurial/mercurial.ini', ('{0}\mozilla-build\hg\mercurial.ini' -f $env:SystemDrive))
      Unblock-File -Path ('{0}\mozilla-build\hg\mercurial.ini' -f $env:SystemDrive)
    }
    TestScript = { if ((Test-Path -Path ('{0}\mozilla-build\hg\mercurial.ini' -f $env:SystemDrive) -ErrorAction SilentlyContinue) -and (Test-Path -Path ('{0}\mozilla-build\hg\hgrc.d\cacert.pem' -f $env:SystemDrive) -ErrorAction SilentlyContinue)) { $true } else { $false } }
  }
  File MozillaRepositoriesFolder {
    Type = 'Directory'
    DestinationPath = ('{0}\builds\hg-shared' -f $env:SystemDrive)
    Ensure = 'Present'
  }
  Script MozillaRepositoriesCache {
    DependsOn = @('[Script]MercurialConfigure', '[File]MozillaRepositoriesFolder')
    GetScript = { @{ Result = $false } }
    SetScript = {
      $repos = @{
        'https://hg.mozilla.org/build/mozharness' = ('{0}\builds\hg-shared\build\mozharness' -f $env:SystemDrive);
        'https://hg.mozilla.org/build/tools' = ('{0}\builds\hg-shared\build\tools' -f $env:SystemDrive);
        'https://hg.mozilla.org/integration/mozilla-inbound' = ('{0}\builds\hg-shared\integration\mozilla-inbound' -f $env:SystemDrive);
        'https://hg.mozilla.org/integration/fx-team' = ('{0}\builds\hg-shared\integration\fx-team' -f $env:SystemDrive);
        'https://hg.mozilla.org/mozilla-central' = ('{0}\builds\hg-shared\mozilla-central' -f $env:SystemDrive);
        ('{0}\builds\hg-shared\mozilla-central' -f $env:SystemDrive) = ('{0}\builds\hg-shared\try' -f $env:SystemDrive)
      }
      foreach ($repo in $repos.GetEnumerator()) {
        if (Test-Path -Path ('{0}\.hg' -f $repo.Value) -PathType Container -ErrorAction SilentlyContinue) {
          Start-Process ('{0}\mozilla-build\hg\hg.exe' -f $env:SystemDrive) -ArgumentList @('pull', '-R', $repo.Value) -Wait -NoNewWindow -PassThru -RedirectStandardOutput ('{0}\log\{1}.hg-pull-{2}.stdout.log' -f $env:SystemDrive, [DateTime]::Now.ToString("yyyyMMddHHmmss"), (Split-Path $repo.Value -Leaf)) -RedirectStandardError ('{0}\log\{1}.hg-pull-{2}.stderr.log' -f $env:SystemDrive, [DateTime]::Now.ToString("yyyyMMddHHmmss"), (Split-Path $repo.Value -Leaf))
        } else {
          Start-Process ('{0}\mozilla-build\hg\hg.exe' -f $env:SystemDrive) -ArgumentList @('clone', '-U', $repo.Name, $repo.Value) -Wait -NoNewWindow -PassThru -RedirectStandardOutput ('{0}\log\{1}.hg-clone-{2}.stdout.log' -f $env:SystemDrive, [DateTime]::Now.ToString("yyyyMMddHHmmss"), (Split-Path $repo.Value -Leaf)) -RedirectStandardError ('{0}\log\{1}.hg-clone-{2}.stderr.log' -f $env:SystemDrive, [DateTime]::Now.ToString("yyyyMMddHHmmss"), (Split-Path $repo.Value -Leaf))
        }
      }
    }
    TestScript = { $false }
  }

  Script PythonTwoSevenDownload {
    GetScript = { @{ Result = (Test-Path -Path ('{0}\Temp\python-2.7.11.amd64.msi' -f $env:SystemRoot) -ErrorAction SilentlyContinue) } }
    SetScript = {
      (New-Object Net.WebClient).DownloadFile('https://www.python.org/ftp/python/2.7.11/python-2.7.11.amd64.msi', ('{0}\Temp\python-2.7.11.amd64.msi' -f $env:SystemRoot))
      Unblock-File -Path ('{0}\Temp\python-2.7.11.amd64.msi' -f $env:SystemRoot)
    }
    TestScript = { if (Test-Path -Path ('{0}\Temp\python-2.7.11.amd64.msi' -f $env:SystemRoot) -ErrorAction SilentlyContinue) { $true } else { $false } }
  }
  Package PythonTwoSevenInstall {
    DependsOn = @('[Script]PythonTwoSevenDownload', '[File]LogFolder')
    Name = 'Python 2.7.11 (64-bit)'
    Path = ('{0}\Temp\python-2.7.11.amd64.msi' -f $env:SystemRoot)
    ProductId = '16E52445-1392-469F-9ADB-FC03AF00CD62'
    Ensure = 'Present'
    LogPath = ('{0}\log\{1}.python-2.7.11.amd64.msi.log' -f $env:SystemDrive, [DateTime]::Now.ToString("yyyyMMddHHmmss"))
  }
  Script PythonTwoSevenSymbolicLink {
    DependsOn = @('[Package]PythonTwoSevenInstall')
    GetScript = { @{ Result = (Test-Path -Path ('{0}\Python27\python2.7.exe' -f $env:SystemDrive) -ErrorAction SilentlyContinue) } }
    SetScript = {
      if ($PSVersionTable.PSVersion.Major -gt 4) {
        New-Item -ItemType SymbolicLink -Path ('{0}\Python27' -f $env:SystemDrive) -Name 'python2.7.exe' -Target ('{0}\Python27\python.exe' -f $env:SystemDrive)
      } else {
        & cmd @('/c', 'mklink', ('{0}\Python27\python2.7.exe' -f $env:SystemDrive), ('{0}\Python27\python.exe' -f $env:SystemDrive))
      }
    }
    TestScript = { if (Test-Path -Path ('{0}\Python27\python2.7.exe' -f $env:SystemDrive) -ErrorAction SilentlyContinue) { $true } else { $false } }
  }
  Script PythonTwoSevenPath {
    DependsOn = @('[Package]PythonTwoSevenInstall')
    GetScript = { @{ Result = ($env:PATH.Contains(('{0}\Python27;{0}\Python27\Scripts' -f $env:SystemDrive))) } }
    SetScript = {
      [Environment]::SetEnvironmentVariable('PATH', ('{0};{1}\Python27;{1}\Python27\Scripts' -f $env:PATH, $env:SystemDrive), 'Machine')
    }
    TestScript = { if ($env:PATH.Contains(('{0}\Python27;{0}\Python27\Scripts' -f $env:SystemDrive))) { $true } else { $false } }
  }
  File MozillaBuildPythonRemove {
    DependsOn = @('[Package]PythonTwoSevenInstall', '[Script]MozillaBuildInstall')
    Force = $true
    Type = 'Directory'
    DestinationPath = ('{0}\mozilla-build\python' -f $env:SystemDrive)
    Ensure = 'Absent'
  }
  Script MozillaBuildPythonSymbolicLink {
    DependsOn = @('[File]MozillaBuildPythonRemove')
    GetScript = { @{ Result = (Test-Path -Path ('{0}\mozilla-build\Python27' -f $env:SystemDrive) -ErrorAction SilentlyContinue) } }
    SetScript = {
      if ($PSVersionTable.PSVersion.Major -gt 4) {
        New-Item -ItemType SymbolicLink -Path ('{0}\mozilla-build' -f $env:SystemDrive) -Name 'Python27' -Target ('{0}\Python27' -f $env:SystemDrive)
      } else {
        & cmd @('/c', 'mklink', '/D', ('{0}\mozilla-build\Python27' -f $env:SystemDrive), ('{0}\Python27' -f $env:SystemDrive))
      }
    }
    TestScript = { (Test-Path -Path ('{0}\mozilla-build\Python27' -f $env:SystemDrive) -ErrorAction SilentlyContinue) }
  }

  # ugly hacks to deal with mozharness configs hardcoded buildbot paths to virtualenv.py
  File MozillaBuildBuildBotVirtualEnv {
    DependsOn = @('[Script]MozillaBuildInstall')
    Type = 'Directory'
    DestinationPath = ('{0}\mozilla-build\buildbotve' -f $env:SystemDrive)
    Ensure = 'Present'
  }
  Script MozillaBuildBuildBotVirtualEnvScript {
    DependsOn = @('[File]MozillaBuildBuildBotVirtualEnv')
    GetScript = { @{ Result = (Test-Path -Path ('{0}\mozilla-build\buildbotve\virtualenv.py' -f $env:SystemDrive) -ErrorAction SilentlyContinue) } }
    SetScript = {
      (New-Object Net.WebClient).DownloadFile('https://hg.mozilla.org/mozilla-central/raw-file/78babd21215d/python/virtualenv/virtualenv.py', ('{0}\mozilla-build\buildbotve\virtualenv.py' -f $env:SystemDrive))
      Unblock-File -Path ('{0}\mozilla-build\buildbotve\virtualenv.py' -f $env:SystemDrive)
    }
    TestScript = { (Test-Path -Path ('{0}\mozilla-build\buildbotve\virtualenv.py' -f $env:SystemDrive) -ErrorAction SilentlyContinue) }
  }
  # end ugly hacks to deal with mozharness configs hardcoded buildbot paths to virtualenv.py

  Script PythonModules {
    DependsOn = @('[Package]PythonTwoSevenInstall', '[Script]PythonTwoSevenPath')
    GetScript = { @{ Result = $false } }
    SetScript = {
      $modules = Invoke-WebRequest -Uri 'https://raw.githubusercontent.com/MozRelOps/OpenCloudConfig/master/userdata/Manifest/python-modules.json' -UseBasicParsing | ConvertFrom-Json
      foreach ($module in $modules) {
        Start-Process ('{0}\Python27\python.exe' -f $env:SystemDrive) -ArgumentList @('-m', 'pip', 'install', '--upgrade', ('{0}=={1}' -f $module.module, $module.version)) -Wait -NoNewWindow -PassThru -RedirectStandardOutput ('{0}\log\{1}.python-pip-upgrade-{2}-{3}.stdout.log' -f $env:SystemDrive, [DateTime]::Now.ToString("yyyyMMddHHmmss"), $module.module, $module.version) -RedirectStandardError ('{0}\log\{1}.python-pip-upgrade-{2}-{3}.stderr.log' -f $env:SystemDrive, [DateTime]::Now.ToString("yyyyMMddHHmmss"), $module.module, $module.version)
      }
    }
    TestScript = { $false }
  }
  Script ToolToolInstall {
    DependsOn = @('[Package]PythonTwoSevenInstall', '[Script]PythonModules')
    GetScript = { @{ Result = (Test-Path -Path ('{0}\mozilla-build\tooltool.py' -f $env:SystemDrive) -ErrorAction SilentlyContinue) } }
    SetScript = {
      (New-Object Net.WebClient).DownloadFile('https://raw.githubusercontent.com/mozilla/build-tooltool/master/tooltool.py', ('{0}\mozilla-build\tooltool.py' -f $env:SystemDrive))
      Unblock-File -Path ('{0}\mozilla-build\tooltool.py' -f $env:SystemDrive)
    }
    TestScript = { if (Test-Path -Path ('{0}\mozilla-build\tooltool.py' -f $env:SystemDrive) -ErrorAction SilentlyContinue) { $true } else { $false } }
  }
}