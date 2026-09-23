function Move-HuduArticleCompany {
    <#
    .SYNOPSIS
    Move a Knowledge Base Article to a different company

    .DESCRIPTION
    Uses Hudu API to update an article's company_id via PUT /api/v1/articles/{id}

    .PARAMETER HuduBaseURL
    Optional Hudu base URL. When provided, it is applied with New-HuduBaseURL before the request.

    .PARAMETER ArticleId
    Id of the article to move

    .PARAMETER CompanyId
    Destination company id

    .PARAMETER FolderId
    Optional destination-company folder id. When omitted, the article is moved
    to the root of the destination company's Knowledge Base.

    .EXAMPLE
    Move-HuduArticleCompany -ArticleId 1 -CompanyId 20

    .EXAMPLE
    Move-HuduArticleCompany -HuduBaseURL https://demo.huducloud.com -ArticleId 1 -CompanyId 20

    .EXAMPLE
    Move-HuduArticleCompany -ArticleId 1 -CompanyId 20 -FolderId 5
    #>
    [CmdletBinding(SupportsShouldProcess)]
    Param (
        [Parameter()]
        [Alias('BaseURL')]
        [String]$HuduBaseURL,

        [Alias('article_id', 'id')]
        [Parameter(Mandatory = $true)]
        [ValidateRange(1, [int]::MaxValue)]
        [Int]$ArticleId,

        [Alias('company_id')]
        [Parameter(Mandatory = $true)]
        [ValidateRange(1, [int]::MaxValue)]
        [Int]$CompanyId,

        [Alias('folder_id')]
        [ValidateRange(1, [int]::MaxValue)]
        [Nullable[int]]$FolderId
    )

    if ($HuduBaseURL) {
        New-HuduBaseURL -BaseURL $HuduBaseURL
    }

    $DestinationFolderId = $null
    if ($PSBoundParameters.ContainsKey('FolderId')) {
        $Folder = Get-HuduFolders -Id $FolderId
        if (-not $Folder) {
            throw "Destination folder $FolderId could not be found."
        }
        if ([int]$Folder.company_id -ne $CompanyId) {
            throw "Destination folder $FolderId does not belong to company $CompanyId."
        }
        $DestinationFolderId = $FolderId
    }

    # Hudu rejects a company change while folder_id still references a folder
    # owned by the source company. Explicitly clear it unless a validated
    # destination-company folder was supplied.
    $Article = [ordered]@{
        article = [ordered]@{
            company_id = $CompanyId
            folder_id  = $DestinationFolderId
        }
    }
    $JSON = $Article | ConvertTo-Json -Depth 10

    if ($PSCmdlet.ShouldProcess("Article ID: $ArticleId", "Move to company $CompanyId")) {
        $Result = Invoke-HuduRequest -Method put -Resource "/api/v1/articles/$ArticleId" -Body $JSON

        # Invoke-HuduRequest returns $null after a failed retry, so verify the
        # persisted state instead of silently reporting a successful move.
        $VerificationResponse = Get-HuduArticles -Id $ArticleId
        $MovedArticle = $VerificationResponse.article
        if (-not $MovedArticle) {
            $MovedArticle = $VerificationResponse
        }

        if (-not $MovedArticle -or [int]$MovedArticle.company_id -ne $CompanyId) {
            throw "Article $ArticleId did not move to company $CompanyId."
        }
        if ($null -eq $DestinationFolderId) {
            if ($null -ne $MovedArticle.folder_id) {
                throw "Article $ArticleId moved to company $CompanyId but folder_id was not cleared."
            }
        } elseif ([int]$MovedArticle.folder_id -ne $DestinationFolderId) {
            throw "Article $ArticleId moved to company $CompanyId but not to folder $DestinationFolderId."
        }

        if ($null -ne $Result) {
            $Result
        } else {
            $MovedArticle
        }
    }
}
