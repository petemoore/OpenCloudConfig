# OpenCloudConfig

## Windows Server 2012 R2 (build instance)

    Invoke-Expression (New-Object Net.WebClient).DownloadString('https://raw.githubusercontent.com/MozRelOps/OpenCloudConfig/master/userdata/win2012.ps1')

## Windows 10 (test instance)

    Invoke-Expression (New-Object Net.WebClient).DownloadString('https://raw.githubusercontent.com/MozRelOps/OpenCloudConfig/master/userdata/win10-64.ps1')

## Windows 7 (test instance)

    Invoke-Expression (New-Object Net.WebClient).DownloadString('https://raw.githubusercontent.com/MozRelOps/OpenCloudConfig/master/userdata/win7-32.ps1')

### Or as AWS EC2 userdata:

    <powershell>
    $config = 'win2012.ps1'
    $repo = 'MozRelOps/OpenCloudConfig'
    $url = ('https://raw.githubusercontent.com/{0}/master/userdata/{1}' -f $repo, $config)
    Invoke-Expression (New-Object Net.WebClient).DownloadString($url)
    </powershell>
    <persist>true</persist>
    <runAsLocalSystem>true</runAsLocalSystem>
    <secrets>
      <rootGpgKey>
    -----BEGIN PGP PRIVATE KEY BLOCK-----
    Replace with your key.
    Generate a key and ascii representation needed here, with the following commands:
    echo Key-Type: 1> gpg-gen-key.options
    echo Key-Length: 4096>> gpg-gen-key.options
    echo Subkey-Type: 1>> gpg-gen-key.options
    echo Subkey-Length: 4096>> gpg-gen-key.options
    echo Name-Real: windows-userdata>> gpg-gen-key.options
    echo Name-Email: windows-userdata@example.com>> gpg-gen-key.options
    echo Expire-Date: 0>> gpg-gen-key.options
    gpg --batch --gen-key gpg-gen-key.options
    gpg --export-secret-key -a windows-userdata > private.key
    -----END PGP PRIVATE KEY BLOCK-----
      </rootGpgKey>
    </secrets>
