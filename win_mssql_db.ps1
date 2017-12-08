#!powershell

#Requires -Module Ansible.ModuleUtils.Legacy

$ErrorActionPreference = 'Stop'


$params = Parse-Args -arguments $args -supports_check_mode $false
$check_mode = Get-AnsibleParam -obj $params -name "_ansible_check_mode" -type "bool" -default $false
$diff_mode = Get-AnsibleParam -obj $params -name "_ansible_diff" -type "bool" -default $false

$name = Get-AnsibleParam -obj $params -name "name" -type "str"
$state = Get-AnsibleParam -obj $params -name "state" -type "str" -validateset "absent","present"


$result = @{
    changed = $false
}

if ($diff_mode) {
    $result.diff = @{}
}


function Database-Exists{
    [CmdletBinding()]
    param
    (
        [parameter(Mandatory=$True)]
        [String]
        $database
    )

    $result = Invoke-Sqlcmd -Query "SELECT name FROM master.sys.databases WHERE name = '$database'"

    if($result -eq $null){
        return $false
    }else{
        return $true
    }
}

function Create-Database{
    [CmdletBinding()]
    param
    (
        [parameter(Mandatory=$True)]
        [String]
        $database
    )

    Invoke-Sqlcmd -Query "CREATE Database $database"
    return (Database-Exists -database $database)
}

function Delete-Database{
    [CmdletBinding()]
    param
    (
        [parameter(Mandatory=$True)]
        [String]
        $database
    )

    Invoke-Sqlcmd -Query "ALTER DATABASE $database SET single_user WITH ROLLBACK IMMEDIATE"
    Invoke-Sqlcmd -Query "DROP DATABASE $database"
    return !(Database-Exists -database $database)
}


if($state -eq "present"){
    if(Database-Exists -database $name){
        break
    }else{
        if(Create-Database -database $name){
            $result.changed = $true
        }
    }
}

if($state -eq "absent"){
    if(Database-Exists -database $name){
        if(Delete-Database -database $name){
            $result.changed = $true
        }
    }else{
        break
    }
}

Exit-Json $result