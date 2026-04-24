param(
    [string]$MdPath = "c:\Users\firas\OneDrive\Desktop\cmandili\rapport\chapitre_3_realisation.md",
    [string]$DocxPath = "c:\Users\firas\OneDrive\Desktop\cmandili\rapport\chapitre_3_realisation.docx"
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path $MdPath)) {
    Write-Output "Fichier Markdown introuvable: $MdPath"
    exit 1
}

$md = Get-Content -Path $MdPath -Raw -Encoding UTF8

try {
    $word = New-Object -ComObject Word.Application
} catch {
    Write-Output "ERREUR: Word n'est pas installe ou COM indisponible. $($_.Exception.Message)"
    exit 2
}

$word.Visible = $false
$doc = $word.Documents.Add()
$sel = $word.Selection

# Police de base
$sel.Font.Name = "Calibri"
$sel.Font.Size = 11

function Clean-Inline {
    param([string]$text)
    $t = $text
    $t = $t -replace '\*\*([^\*]+)\*\*', '$1'
    $t = $t -replace '`([^`]+)`', '$1'
    return $t
}

$lines = $md -split "`r?`n"

$inTable = $false
$tableRows = @()
$inCodeBlock = $false

function Flush-Table {
    param($selRef, $docRef, $rowsRef)
    if (-not $rowsRef -or $rowsRef.Count -eq 0) { return }
    $rows = $rowsRef | Where-Object { $_ -notmatch '^\s*\|[\s:\-\|]+\|\s*$' }
    if ($rows.Count -eq 0) { return }
    $parsed = @()
    foreach ($r in $rows) {
        $cells = $r.Trim().Trim('|').Split('|') | ForEach-Object { $_.Trim() }
        $parsed += ,$cells
    }
    $rowCount = $parsed.Count
    $colCount = $parsed[0].Count
    $rng = $selRef.Range
    $table = $docRef.Tables.Add($rng, $rowCount, $colCount)
    $table.Borders.Enable = $true
    for ($i = 0; $i -lt $rowCount; $i++) {
        for ($j = 0; $j -lt $colCount; $j++) {
            $cellText = Clean-Inline $parsed[$i][$j]
            $table.Cell($i + 1, $j + 1).Range.Text = $cellText
        }
    }
    # Entete en gras
    for ($j = 1; $j -le $colCount; $j++) {
        $table.Cell(1, $j).Range.Font.Bold = $true
    }
    $selRef.EndKey(6) | Out-Null  # wdStory = 6
    $selRef.TypeParagraph()
}

foreach ($line in $lines) {

    if ($line -match '^```') {
        $inCodeBlock = -not $inCodeBlock
        continue
    }
    if ($inCodeBlock) {
        $sel.Font.Name = "Consolas"
        $sel.Font.Size = 10
        $sel.TypeText($line)
        $sel.TypeParagraph()
        $sel.Font.Name = "Calibri"
        $sel.Font.Size = 11
        continue
    }

    if ($line -match '^\s*\|.*\|\s*$') {
        $tableRows += $line
        $inTable = $true
        continue
    } elseif ($inTable) {
        Flush-Table -selRef $sel -docRef $doc -rowsRef $tableRows
        $tableRows = @()
        $inTable = $false
    }

    if ($line -match '^# (.+)') {
        $sel.Style = $doc.Styles.Item("Titre 1")
        $sel.TypeText((Clean-Inline $Matches[1]))
        $sel.TypeParagraph()
        $sel.Style = $doc.Styles.Item("Normal")
    } elseif ($line -match '^## (.+)') {
        $sel.Style = $doc.Styles.Item("Titre 2")
        $sel.TypeText((Clean-Inline $Matches[1]))
        $sel.TypeParagraph()
        $sel.Style = $doc.Styles.Item("Normal")
    } elseif ($line -match '^### (.+)') {
        $sel.Style = $doc.Styles.Item("Titre 3")
        $sel.TypeText((Clean-Inline $Matches[1]))
        $sel.TypeParagraph()
        $sel.Style = $doc.Styles.Item("Normal")
    } elseif ($line -match '^#### (.+)') {
        $sel.Style = $doc.Styles.Item("Titre 4")
        $sel.TypeText((Clean-Inline $Matches[1]))
        $sel.TypeParagraph()
        $sel.Style = $doc.Styles.Item("Normal")
    } elseif ($line -match '^\- (.+)') {
        $sel.Range.ListFormat.ApplyBulletDefault()
        $sel.TypeText((Clean-Inline $Matches[1]))
        $sel.TypeParagraph()
        $sel.Range.ListFormat.RemoveNumbers()
    } elseif ($line -match '^(\d+)\. (.+)') {
        $sel.TypeText((Clean-Inline ($Matches[1] + ". " + $Matches[2])))
        $sel.TypeParagraph()
    } elseif ($line.Trim() -eq "") {
        $sel.TypeParagraph()
    } else {
        # Gerer le gras en ligne
        $text = $line
        $regex = [regex]'\*\*([^\*]+)\*\*'
        $lastIndex = 0
        $mObj = $regex.Match($text)
        if ($mObj.Success) {
            while ($mObj.Success) {
                $before = $text.Substring($lastIndex, $mObj.Index - $lastIndex)
                if ($before.Length -gt 0) {
                    $sel.Font.Bold = $false
                    $sel.TypeText((Clean-Inline $before))
                }
                $sel.Font.Bold = $true
                $sel.TypeText($mObj.Groups[1].Value)
                $sel.Font.Bold = $false
                $lastIndex = $mObj.Index + $mObj.Length
                $mObj = $mObj.NextMatch()
            }
            if ($lastIndex -lt $text.Length) {
                $rest = $text.Substring($lastIndex)
                $sel.TypeText((Clean-Inline $rest))
            }
            $sel.TypeParagraph()
        } else {
            $sel.TypeText((Clean-Inline $text))
            $sel.TypeParagraph()
        }
    }
}

# Vider une table en fin de fichier
if ($inTable) {
    Flush-Table -selRef $sel -docRef $doc -rowsRef $tableRows
}

# wdFormatDocumentDefault = 16
$doc.SaveAs([ref]$DocxPath, [ref]16)
$doc.Close()
$word.Quit()
[System.Runtime.Interopservices.Marshal]::ReleaseComObject($sel) | Out-Null
[System.Runtime.Interopservices.Marshal]::ReleaseComObject($doc) | Out-Null
[System.Runtime.Interopservices.Marshal]::ReleaseComObject($word) | Out-Null

Write-Output "DOCX genere: $DocxPath"
