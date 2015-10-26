#AvoidDefaultTrueValueSwitchParameter 
**Severity Level: Warning**


##Description

Switch Parameters Should Not Default To True


##How to Fix

Please change the default value of the switch parameter to be false.

##Example

Wrong：    

    Param
    (      …
        $Param1,
        [switch]
        $Switch=$True
    )

Correct:    

    Param
    (      …
        $Param1,
        [switch]
        $Switch=$False
    )
