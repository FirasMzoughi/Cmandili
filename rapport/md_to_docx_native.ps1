param(
    [string]$MdPath = "c:\Users\firas\OneDrive\Desktop\cmandili\rapport\chapitre_3_realisation.md",
    [string]$DocxPath = "c:\Users\firas\OneDrive\Desktop\cmandili\rapport\chapitre_3_realisation.docx"
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path $MdPath)) {
    Write-Output "Fichier Markdown introuvable: $MdPath"
    exit 1
}

$md = [System.IO.File]::ReadAllText($MdPath, [System.Text.Encoding]::UTF8)
$lines = $md -split "`r?`n"

function EscapeXml {
    param([string]$s)
    if ($null -eq $s) { return "" }
    return $s.Replace('&','&amp;').Replace('<','&lt;').Replace('>','&gt;').Replace('"','&quot;').Replace("'",'&apos;')
}

# Construction des paragraphes OOXML
$body = New-Object System.Text.StringBuilder

function Add-Paragraph {
    param(
        [System.Text.StringBuilder]$sb,
        [string]$styleId,
        [array]$runs
    )
    [void]$sb.Append('<w:p>')
    if ($styleId) {
        [void]$sb.Append('<w:pPr><w:pStyle w:val="' + $styleId + '"/></w:pPr>')
    }
    foreach ($run in $runs) {
        [void]$sb.Append('<w:r>')
        if ($run.Bold) { [void]$sb.Append('<w:rPr><w:b/></w:rPr>') }
        elseif ($run.Mono) { [void]$sb.Append('<w:rPr><w:rFonts w:ascii="Consolas" w:hAnsi="Consolas"/></w:rPr>') }
        [void]$sb.Append('<w:t xml:space="preserve">' + (EscapeXml $run.Text) + '</w:t>')
        [void]$sb.Append('</w:r>')
    }
    [void]$sb.Append('</w:p>')
}

function Parse-Inline {
    param([string]$text)
    # Supprime les backticks comme simple litteral
    $text = $text -replace '`([^`]+)`', '$1'
    $runs = @()
    $regex = [regex]'\*\*([^\*]+)\*\*'
    $lastIndex = 0
    $m = $regex.Match($text)
    if (-not $m.Success) {
        $runs += @{ Text = $text; Bold = $false }
        return ,$runs
    }
    while ($m.Success) {
        if ($m.Index -gt $lastIndex) {
            $runs += @{ Text = $text.Substring($lastIndex, $m.Index - $lastIndex); Bold = $false }
        }
        $runs += @{ Text = $m.Groups[1].Value; Bold = $true }
        $lastIndex = $m.Index + $m.Length
        $m = $m.NextMatch()
    }
    if ($lastIndex -lt $text.Length) {
        $runs += @{ Text = $text.Substring($lastIndex); Bold = $false }
    }
    return ,$runs
}

function Add-Table {
    param(
        [System.Text.StringBuilder]$sb,
        [array]$rows
    )
    if (-not $rows -or $rows.Count -eq 0) { return }
    $dataRows = @()
    foreach ($r in $rows) {
        if ($r -match '^\s*\|[\s:\-\|]+\|\s*$') { continue }
        $dataRows += ,$r
    }
    if ($dataRows.Count -eq 0) { return }

    $parsed = @()
    foreach ($r in $dataRows) {
        $clean = $r.Trim()
        if ($clean.StartsWith('|')) { $clean = $clean.Substring(1) }
        if ($clean.EndsWith('|')) { $clean = $clean.Substring(0, $clean.Length - 1) }
        $cells = $clean.Split('|') | ForEach-Object { $_.Trim() }
        $parsed += ,$cells
    }
    $colCount = $parsed[0].Count

    [void]$sb.Append('<w:tbl>')
    [void]$sb.Append('<w:tblPr><w:tblStyle w:val="TableGrid"/><w:tblW w:w="5000" w:type="pct"/><w:tblBorders><w:top w:val="single" w:sz="4" w:space="0" w:color="auto"/><w:left w:val="single" w:sz="4" w:space="0" w:color="auto"/><w:bottom w:val="single" w:sz="4" w:space="0" w:color="auto"/><w:right w:val="single" w:sz="4" w:space="0" w:color="auto"/><w:insideH w:val="single" w:sz="4" w:space="0" w:color="auto"/><w:insideV w:val="single" w:sz="4" w:space="0" w:color="auto"/></w:tblBorders></w:tblPr>')
    [void]$sb.Append('<w:tblGrid>')
    for ($i = 0; $i -lt $colCount; $i++) { [void]$sb.Append('<w:gridCol/>') }
    [void]$sb.Append('</w:tblGrid>')

    for ($i = 0; $i -lt $parsed.Count; $i++) {
        [void]$sb.Append('<w:tr>')
        foreach ($cell in $parsed[$i]) {
            [void]$sb.Append('<w:tc>')
            [void]$sb.Append('<w:tcPr><w:tcW w:w="0" w:type="auto"/></w:tcPr>')
            $runs = Parse-Inline $cell
            [void]$sb.Append('<w:p>')
            foreach ($run in $runs) {
                [void]$sb.Append('<w:r>')
                if ($run.Bold -or $i -eq 0) { [void]$sb.Append('<w:rPr><w:b/></w:rPr>') }
                [void]$sb.Append('<w:t xml:space="preserve">' + (EscapeXml $run.Text) + '</w:t>')
                [void]$sb.Append('</w:r>')
            }
            [void]$sb.Append('</w:p>')
            [void]$sb.Append('</w:tc>')
        }
        [void]$sb.Append('</w:tr>')
    }
    [void]$sb.Append('</w:tbl>')
    # Paragraphe vide apres le tableau
    [void]$sb.Append('<w:p/>')
}

$inTable = $false
$tableRows = @()
$inCode = $false

foreach ($line in $lines) {

    if ($line -match '^```') {
        $inCode = -not $inCode
        continue
    }
    if ($inCode) {
        $runs = @(@{ Text = $line; Mono = $true })
        Add-Paragraph -sb $body -styleId $null -runs $runs
        continue
    }

    if ($line -match '^\s*\|.*\|\s*$') {
        $tableRows += $line
        $inTable = $true
        continue
    } elseif ($inTable) {
        Add-Table -sb $body -rows $tableRows
        $tableRows = @()
        $inTable = $false
    }

    if ($line -match '^# (.+)$') {
        $runs = Parse-Inline $Matches[1]
        Add-Paragraph -sb $body -styleId "Heading1" -runs $runs
    } elseif ($line -match '^## (.+)$') {
        $runs = Parse-Inline $Matches[1]
        Add-Paragraph -sb $body -styleId "Heading2" -runs $runs
    } elseif ($line -match '^### (.+)$') {
        $runs = Parse-Inline $Matches[1]
        Add-Paragraph -sb $body -styleId "Heading3" -runs $runs
    } elseif ($line -match '^#### (.+)$') {
        $runs = Parse-Inline $Matches[1]
        Add-Paragraph -sb $body -styleId "Heading4" -runs $runs
    } elseif ($line -match '^\- (.+)$') {
        $runs = Parse-Inline ("• " + $Matches[1])
        Add-Paragraph -sb $body -styleId "ListBullet" -runs $runs
    } elseif ($line -match '^\d+\. (.+)$') {
        $runs = Parse-Inline $line
        Add-Paragraph -sb $body -styleId $null -runs $runs
    } elseif ($line.Trim() -eq "") {
        Add-Paragraph -sb $body -styleId $null -runs @()
    } else {
        $runs = Parse-Inline $line
        Add-Paragraph -sb $body -styleId $null -runs $runs
    }
}

if ($inTable) {
    Add-Table -sb $body -rows $tableRows
}

# ===== Fichiers OOXML =====

$documentXml = @'
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
<w:body>
__BODY__
<w:sectPr><w:pgSz w:w="12240" w:h="15840"/><w:pgMar w:top="1440" w:right="1440" w:bottom="1440" w:left="1440" w:header="720" w:footer="720" w:gutter="0"/></w:sectPr>
</w:body>
</w:document>
'@

$documentXml = $documentXml.Replace('__BODY__', $body.ToString())

$stylesXml = @'
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:styles xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
<w:docDefaults>
<w:rPrDefault><w:rPr><w:rFonts w:ascii="Calibri" w:hAnsi="Calibri" w:cs="Calibri"/><w:sz w:val="22"/><w:szCs w:val="22"/><w:lang w:val="fr-FR"/></w:rPr></w:rPrDefault>
<w:pPrDefault><w:pPr><w:spacing w:after="160" w:line="276" w:lineRule="auto"/></w:pPr></w:pPrDefault>
</w:docDefaults>
<w:style w:type="paragraph" w:default="1" w:styleId="Normal"><w:name w:val="Normal"/><w:qFormat/></w:style>
<w:style w:type="paragraph" w:styleId="Heading1"><w:name w:val="heading 1"/><w:basedOn w:val="Normal"/><w:next w:val="Normal"/><w:qFormat/><w:pPr><w:keepNext/><w:spacing w:before="360" w:after="200"/><w:outlineLvl w:val="0"/></w:pPr><w:rPr><w:b/><w:sz w:val="44"/><w:szCs w:val="44"/></w:rPr></w:style>
<w:style w:type="paragraph" w:styleId="Heading2"><w:name w:val="heading 2"/><w:basedOn w:val="Normal"/><w:next w:val="Normal"/><w:qFormat/><w:pPr><w:keepNext/><w:spacing w:before="320" w:after="160"/><w:outlineLvl w:val="1"/></w:pPr><w:rPr><w:b/><w:sz w:val="32"/><w:szCs w:val="32"/><w:color w:val="1F3864"/></w:rPr></w:style>
<w:style w:type="paragraph" w:styleId="Heading3"><w:name w:val="heading 3"/><w:basedOn w:val="Normal"/><w:next w:val="Normal"/><w:qFormat/><w:pPr><w:keepNext/><w:spacing w:before="240" w:after="120"/><w:outlineLvl w:val="2"/></w:pPr><w:rPr><w:b/><w:sz w:val="26"/><w:szCs w:val="26"/><w:color w:val="2E74B5"/></w:rPr></w:style>
<w:style w:type="paragraph" w:styleId="Heading4"><w:name w:val="heading 4"/><w:basedOn w:val="Normal"/><w:next w:val="Normal"/><w:qFormat/><w:pPr><w:keepNext/><w:spacing w:before="200" w:after="100"/><w:outlineLvl w:val="3"/></w:pPr><w:rPr><w:b/><w:i/><w:sz w:val="24"/><w:szCs w:val="24"/><w:color w:val="2E74B5"/></w:rPr></w:style>
<w:style w:type="paragraph" w:styleId="ListBullet"><w:name w:val="List Bullet"/><w:basedOn w:val="Normal"/><w:qFormat/><w:pPr><w:ind w:left="360"/></w:pPr></w:style>
<w:style w:type="table" w:styleId="TableGrid"><w:name w:val="Table Grid"/><w:basedOn w:val="TableNormal"/><w:tblPr><w:tblBorders><w:top w:val="single" w:sz="4" w:space="0" w:color="auto"/><w:left w:val="single" w:sz="4" w:space="0" w:color="auto"/><w:bottom w:val="single" w:sz="4" w:space="0" w:color="auto"/><w:right w:val="single" w:sz="4" w:space="0" w:color="auto"/><w:insideH w:val="single" w:sz="4" w:space="0" w:color="auto"/><w:insideV w:val="single" w:sz="4" w:space="0" w:color="auto"/></w:tblBorders></w:tblPr></w:style>
<w:style w:type="table" w:default="1" w:styleId="TableNormal"><w:name w:val="Normal Table"/><w:uiPriority w:val="99"/><w:semiHidden/><w:unhideWhenUsed/><w:tblPr><w:tblInd w:w="0" w:type="dxa"/><w:tblCellMar><w:top w:w="0" w:type="dxa"/><w:left w:w="108" w:type="dxa"/><w:bottom w:w="0" w:type="dxa"/><w:right w:w="108" w:type="dxa"/></w:tblCellMar></w:tblPr></w:style>
</w:styles>
'@

$contentTypesXml = @'
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
<Default Extension="xml" ContentType="application/xml"/>
<Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>
<Override PartName="/word/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.styles+xml"/>
<Override PartName="/docProps/core.xml" ContentType="application/vnd.openxmlformats-package.core-properties+xml"/>
<Override PartName="/docProps/app.xml" ContentType="application/vnd.openxmlformats-officedocument.extended-properties+xml"/>
</Types>
'@

$rootRelsXml = @'
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>
<Relationship Id="rId2" Type="http://schemas.openxmlformats.org/package/2006/relationships/metadata/core-properties" Target="docProps/core.xml"/>
<Relationship Id="rId3" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/extended-properties" Target="docProps/app.xml"/>
</Relationships>
'@

$docRelsXml = @'
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>
</Relationships>
'@

$coreXml = @'
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<cp:coreProperties xmlns:cp="http://schemas.openxmlformats.org/package/2006/metadata/core-properties" xmlns:dc="http://purl.org/dc/elements/1.1/" xmlns:dcterms="http://purl.org/dc/terms/" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
<dc:title>Chapitre 3 - Realisation et mise en oeuvre</dc:title>
<dc:creator>Firas Mzoughi</dc:creator>
<cp:lastModifiedBy>Firas Mzoughi</cp:lastModifiedBy>
</cp:coreProperties>
'@

$appXml = @'
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Properties xmlns="http://schemas.openxmlformats.org/officeDocument/2006/extended-properties" xmlns:vt="http://schemas.openxmlformats.org/officeDocument/2006/docPropsVTypes">
<Application>Claude Code</Application>
</Properties>
'@

# ===== Construction du ZIP =====

if (Test-Path $DocxPath) { Remove-Item $DocxPath -Force }

Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem

$zipStream = [System.IO.File]::Open($DocxPath, [System.IO.FileMode]::Create)
$zip = New-Object System.IO.Compression.ZipArchive($zipStream, [System.IO.Compression.ZipArchiveMode]::Create)

function Add-ZipEntry {
    param($archive, [string]$entryName, [string]$content)
    $entry = $archive.CreateEntry($entryName, [System.IO.Compression.CompressionLevel]::Optimal)
    $writer = New-Object System.IO.StreamWriter($entry.Open(), [System.Text.UTF8Encoding]::new($false))
    $writer.Write($content)
    $writer.Dispose()
}

Add-ZipEntry $zip "[Content_Types].xml" $contentTypesXml
Add-ZipEntry $zip "_rels/.rels" $rootRelsXml
Add-ZipEntry $zip "word/_rels/document.xml.rels" $docRelsXml
Add-ZipEntry $zip "word/document.xml" $documentXml
Add-ZipEntry $zip "word/styles.xml" $stylesXml
Add-ZipEntry $zip "docProps/core.xml" $coreXml
Add-ZipEntry $zip "docProps/app.xml" $appXml

$zip.Dispose()
$zipStream.Dispose()

$fi = Get-Item $DocxPath
Write-Output ("DOCX genere: " + $DocxPath + " (" + $fi.Length + " octets)")
