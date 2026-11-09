# Define script arguments
[CmdletBinding()]
param (
    [Parameter(Mandatory = $true)]
    [String]
    $JsonString,

    [Parameter(Mandatory = $false)]
    [String]
    $Key = "",

    [Parameter(Mandatory = $false, ValueFromRemainingArguments = $true)]
    [string[]]
    $Remaining
)

function Get-JsonObject {
    param (
        [Parameter(Mandatory = $true)]
        [String]
        $JsonString
    )

    $json = ConvertFrom-Json -InputObject $JsonString -AsHashtable
    return $json
}

function Get-JsonString {
    param (
        [Parameter(Mandatory = $true)]
        [hashtable]
        $JsonObject
    )

    $string = ConvertTo-Json -InputObject $JsonObject -Compress -Depth 100
    return $string
}

function Get-FlattenedJsonObject {
    param (
        [Parameter(Mandatory = $true)]
        [hashtable]
        $JsonObject,

        [Parameter(Mandatory = $false)]
        [String]
        $Key = ""
    )

    $jsonObjectFlattened = @{}
    foreach ($currentItem in $JsonObject.GetEnumerator()) {
        # Get current key definition
        $currentKey = $Key -eq "" ? "$($currentItem.Name)" : "${Key}_$($currentItem.Name)"

        # Handle nested object
        if ($currentItem.Value.GetType().Name -eq "OrderedHashtable") {
            $nestedObjectFlattened = Get-FlattenedJsonObject -JsonObject $currentItem.Value -Key $currentKey
            $jsonObjectFlattened += $nestedObjectFlattened
        }
        # Handle nested list
        elseif ($currentItem.Value.GetType().Name -eq "Object[]") {
            # Remove null values
            $currentItem.Value = $currentItem.Value.Where({ $null -ne $_ })

            $nestedObjectFlattened = Get-FlattenedJsonList -JsonObject $currentItem.Value -Key $currentKey
            $jsonObjectFlattened += $nestedObjectFlattened
        }
        # Handle simple value
        else {
            $jsonObjectFlattened.Add($currentKey, $currentItem.Value)
        }
    }
    return $jsonObjectFlattened
}

function Get-FlattenedJsonList {
    param (
        [Parameter(Mandatory = $true)]
        [AllowEmptyCollection()]
        [array]
        $JsonObject,

        [Parameter(Mandatory = $false)]
        [String]
        $Key = ""
    )

    $jsonObjectFlattened = @{}
    for ($index = 0; $index -lt $JsonObject.Count; $index++) {
        # Get current key definition
        $currentKey = $Key -eq "" ? "${index}" : "${Key}_${index}"

        # Handle nested object
        if ($JsonObject[$index].GetType().Name -eq "OrderedHashtable") {
            $nestedObjectFlattened = Get-FlattenedJsonObject -JsonObject $JsonObject[$index] -Key $currentKey
            $jsonObjectFlattened += $nestedObjectFlattened
        }
        # Handle nested list
        elseif ($JsonObject[$index].GetType().Name -eq "Object[]") {
            # Remove null values
            $JsonObject[$index] = $JsonObject[$index].Where({ $null -ne $_ })

            $nestedObjectFlattened = Get-FlattenedJsonList -JsonObject $JsonObject[$index] -Key $currentKey
            $jsonObjectFlattened += $nestedObjectFlattened
        }
        # Handle simple value
        else {
            $jsonObjectFlattened.Add($currentKey, $JsonObject[$index])
        }
    }
    return $jsonObjectFlattened
}

function Get-FlattenedJson {
    param (
        [Parameter(Mandatory = $true)]
        [String]
        $JsonString,

        [Parameter(Mandatory = $false)]
        [String]
        $Key = ""
    )

    # Convert string to json object
    $rootString = "{ `"root`": $($JsonString) }"
    $JsonObject = Get-JsonObject -JsonString $rootString

    # Flatten json object
    $jsonObjectFlattened = @{}
    if ($null -eq $JsonObject.root) {
        $jsonObjectFlattened = @{}
    }
    elseif ($JsonObject.root.GetType().Name -eq "OrderedHashtable") {
        $jsonObjectFlattened = Get-FlattenedJsonObject -JsonObject $JsonObject.root -Key $Key
    }
    elseif ($JsonObject.root.GetType().Name -eq "Object[]") {
        $jsonObjectFlattened = Get-FlattenedJsonList -JsonObject $JsonObject.root -Key $Key
    }

    # Convert object to json string
    $jsonStringFlattened = Get-JsonString -JsonObject $jsonObjectFlattened
    return $jsonStringFlattened
}

$JsonStringFlattened = Get-FlattenedJson -JsonString $JsonString -Key $Key

return $JsonStringFlattened
