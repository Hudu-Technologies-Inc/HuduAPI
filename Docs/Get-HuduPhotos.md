---
external help file: HuduAPI-help.xml
Module Name: HuduAPI
online version:
schema: 2.0.0
---

# Get-HuduPhotos

## SYNOPSIS
Get a list of photos or a single photo, optionally downloading files.

## SYNTAX

```
Get-HuduPhotos [[-Id] <Int32>] [[-CompanyId] <Int32>] [[-Photoable_Type] <String>] [[-Photoable_Id] <Int32>]
 [[-FolderId] <Int32>] [[-Archived] <Boolean>] [[-createdBefore] <DateTime>] [[-createdAfter] <DateTime>]
 [[-UpdatedBefore] <DateTime>] [[-UpdatedAfter] <DateTime>] [-Download] [[-OutDir] <String>]
 [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

## DESCRIPTION
Calls Hudu API to retrieve photos.
Supports filtering
If -Download is specified with -Id (single) or without (list), downloads photo files using /photos/{id}?download=true.

## EXAMPLES

### EXAMPLE 1
```
Get-HuduPhotos -CompanyId 123
```

### EXAMPLE 2
```
Get-HuduPhotos -Photoable_Type Asset -Photoable_Id 456 -Download -OutDir "$env:TEMP\photos"
```

### EXAMPLE 3
```
Get-HuduPhotos -Id 999 -Download
```

## PARAMETERS

### -Id
ID of the Photo to retrieve (or download if -Download is specified).

```yaml
Type: Int32
Parameter Sets: (All)
Aliases:

Required: False
Position: 1
Default value: 0
Accept pipeline input: False
Accept wildcard characters: False
```

### -CompanyId
Filter by company ID.

```yaml
Type: Int32
Parameter Sets: (All)
Aliases:

Required: False
Position: 2
Default value: 0
Accept pipeline input: False
Accept wildcard characters: False
```

### -Photoable_Type
Filter by photoable type (Company, Asset, Article, etc).

```yaml
Type: String
Parameter Sets: (All)
Aliases: uploadabletype, recordtype, PhotoableType, uploadable_type, record_type

Required: False
Position: 3
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Photoable_Id
Filter by photoable record ID.

```yaml
Type: Int32
Parameter Sets: (All)
Aliases: record_id, uploadable_id, recordid, PhotoableId, uploadableid

Required: False
Position: 4
Default value: 0
Accept pipeline input: False
Accept wildcard characters: False
```

### -FolderId
Filter by folder ID.

```yaml
Type: Int32
Parameter Sets: (All)
Aliases:

Required: False
Position: 5
Default value: 0
Accept pipeline input: False
Accept wildcard characters: False
```

### -Archived
$true = only archived, $false = only non-archived, $null = omit param (API defaults to non-archived only).

```yaml
Type: Boolean
Parameter Sets: (All)
Aliases:

Required: False
Position: 6
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -createdBefore
{{ Fill createdBefore Description }}

```yaml
Type: DateTime
Parameter Sets: (All)
Aliases:

Required: False
Position: 7
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -createdAfter
{{ Fill createdAfter Description }}

```yaml
Type: DateTime
Parameter Sets: (All)
Aliases:

Required: False
Position: 8
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -UpdatedBefore
{{ Fill UpdatedBefore Description }}

```yaml
Type: DateTime
Parameter Sets: (All)
Aliases:

Required: False
Position: 9
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -UpdatedAfter
{{ Fill UpdatedAfter Description }}

```yaml
Type: DateTime
Parameter Sets: (All)
Aliases:

Required: False
Position: 10
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Download
If specified, downloads photo file(s) to OutDir.

```yaml
Type: SwitchParameter
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: False
Accept pipeline input: False
Accept wildcard characters: False
```

### -OutDir
Directory to download photos into.
Default current directory.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 11
Default value: .
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
