. "$psscriptroot\..\lib\core.ps1"

describe "config" -Tag 'Scoop' {
    BeforeAll {
        $json = '{ "one": 1, "two": [ { "a": "a" }, "b", 2 ], "three": { "four": 4 }, "five": true, "six": false, "seven": "\/Date(1529917395805)\/", "eight": "2019-03-18T15:22:09.3930000+00:00" }'
    }

    it "converts JSON to PSObject" {
        $obj = ConvertFrom-Json $json

        $obj.one | Should -BeExactly 1
        $obj.two[0].a | Should -Be "a"
        $obj.two[1] | Should -Be "b"
        $obj.two[2] | Should -BeExactly 2
        $obj.three.four | Should -BeExactly 4
        $obj.five | Should -BeTrue
        $obj.six | Should -BeFalse
        $obj.seven | Should -BeOfType [System.DateTime]
        if($PSVersionTable.PSVersion.Major -lt 6) {
            $obj.eight | Should -BeOfType [System.String]
        } else {
            $obj.eight | Should -BeOfType [System.DateTime]
        }
    }

    it "load_config should return PSObject" {
        mock Get-Content { $json }
        mock Test-Path { $true }
        (load_cfg 'file') | Should -Not -BeNullOrEmpty
        (load_cfg 'file') | Should -BeOfType [System.Management.Automation.PSObject]
        (load_cfg 'file').one | Should -BeExactly 1

    }

    it "get_config should return exactly the same values" {
        $scoopConfig = ConvertFrom-Json $json
        get_config 'does_not_exist' 'default' | Should -Be 'default'

        get_config 'one' | Should -BeExactly 1
        (get_config 'two')[0].a | Should -Be "a"
        (get_config 'two')[1] | Should -Be "b"
        (get_config 'two')[2] | Should -BeExactly 2
        (get_config 'three').four | Should -BeExactly 4
        get_config 'five' | Should -BeTrue
        get_config 'six' | Should -BeFalse
        get_config 'seven' | Should -BeOfType [System.DateTime]
        if($PSVersionTable.PSVersion.Major -lt 6) {
            get_config 'eight' | Should -BeOfType [System.String]
        } else {
            get_config 'eight' | Should -BeOfType [System.DateTime]
        }
    }
}
