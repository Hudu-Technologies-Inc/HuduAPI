---
external help file: HuduAPI-help.xml
Module Name: HuduAPI
online version:
schema: 2.0.0
---

# Move-HuduArticleCompany

## SYNOPSIS
Move a Knowledge Base Article to a different company

## SYNTAX

```
Move-HuduArticleCompany [[-HuduBaseURL] <String>] [-ArticleId] <Int32> [-CompanyId] <Int32>
 [[-FolderId] <Nullable`1>] [-ProgressAction <ActionPreference>] [-WhatIf] [-Confirm] [<CommonParameters>]
```

## DESCRIPTION
Uses Hudu API to update an article's company_id via PUT /api/v1/articles/{id}

When FolderId is omitted, the article is moved to the root of the destination
company's Knowledge Base. A supplied FolderId must belong to the destination
company.

## EXAMPLES

### EXAMPLE 1
```
Move-HuduArticleCompany -ArticleId 1 -CompanyId 20
```

### EXAMPLE 2
```
Move-HuduArticleCompany -HuduBaseURL https://demo.huducloud.com -ArticleId 1 -CompanyId 20
```

### EXAMPLE 3
```
Move-HuduArticleCompany -ArticleId 1 -CompanyId 20 -FolderId 5
```

## PARAMETERS

### -HuduBaseURL
Optional Hudu base URL.
When provided, it is applied with New-HuduBaseURL before the request.

```yaml
Type: String
Parameter Sets: (All)
Aliases: BaseURL

Required: False
Position: 1
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -ArticleId
Id of the article to move

```yaml
Type: Int32
Parameter Sets: (All)
Aliases: article_id, id

Required: True
Position: 2
Default value: 0
Accept pipeline input: False
Accept wildcard characters: False
```

### -CompanyId
Destination company id

```yaml
Type: Int32
Parameter Sets: (All)
Aliases: company_id

Required: True
Position: 3
Default value: 0
Accept pipeline input: False
Accept wildcard characters: False
```

### -FolderId
Optional destination-company folder id.
When omitted, the article is moved to the root of the destination company's Knowledge Base.

```yaml
Type: Nullable`1
Parameter Sets: (All)
Aliases: folder_id

Required: False
Position: 4
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -WhatIf
Shows what would happen if the cmdlet runs.
The cmdlet is not run.

```yaml
Type: SwitchParameter
Parameter Sets: (All)
Aliases: wi

Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Confirm
Prompts you for confirmation before running the cmdlet.

```yaml
Type: SwitchParameter
Parameter Sets: (All)
Aliases: cf

Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -ProgressAction
{{ Fill ProgressAction Description }}

```yaml
Type: ActionPreference
Parameter Sets: (All)
Aliases: proga

Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### CommonParameters
This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable, -InformationAction, -InformationVariable, -OutVariable, -OutBuffer, -PipelineVariable, -Verbose, -WarningAction, and -WarningVariable. For more information, see [about_CommonParameters](http://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

## OUTPUTS

## NOTES

## RELATED LINKS
