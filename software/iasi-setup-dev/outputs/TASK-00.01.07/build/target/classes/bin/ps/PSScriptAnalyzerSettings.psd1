@{
    # These warnings are accepted project conventions:
    # - Write-Host is used for intentional interactive, color-coded status output.
    # - Plain-text password parameters are part of the existing ISO-generation interface.
    # - Some parameters are retained for callback signatures or backwards compatibility.
    # - Plural nouns are used intentionally for functions that handle collections.
    # - State-changing functions are internal workflow steps, not interactive cmdlets.
    ExcludeRules = @(
        'PSAvoidUsingWriteHost',
        'PSAvoidUsingPlainTextForPassword',
        'PSAvoidUsingUsernameAndPasswordParams',
        'PSReviewUnusedParameter',
        'PSUseSingularNouns',
        'PSUseShouldProcessForStateChangingFunctions',
        'PSUseApprovedVerbs'
    )
}







