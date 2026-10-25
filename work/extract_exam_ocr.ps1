param([string]$SourceDir,[string]$OutputDir)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Runtime.WindowsRuntime
$null = [Windows.Storage.StorageFile,Windows.Storage,ContentType=WindowsRuntime]
$null = [Windows.Storage.FileAccessMode,Windows.Storage,ContentType=WindowsRuntime]
$null = [Windows.Storage.Streams.IRandomAccessStream,Windows.Storage.Streams,ContentType=WindowsRuntime]
$null = [Windows.Graphics.Imaging.BitmapDecoder,Windows.Graphics.Imaging,ContentType=WindowsRuntime]
$null = [Windows.Graphics.Imaging.SoftwareBitmap,Windows.Graphics.Imaging,ContentType=WindowsRuntime]
$null = [Windows.Media.Ocr.OcrEngine,Windows.Foundation,ContentType=WindowsRuntime]
$null = [Windows.Media.Ocr.OcrResult,Windows.Foundation,ContentType=WindowsRuntime]
$null = [Windows.Globalization.Language,Windows.Globalization,ContentType=WindowsRuntime]
$script:taskAdapter = [System.WindowsRuntimeSystemExtensions].GetMethods() | Where-Object { $_.Name -eq 'AsTask' -and $_.IsGenericMethod -and $_.GetParameters().Count -eq 1 -and $_.GetGenericArguments().Count -eq 1 -and $_.GetParameters()[0].ParameterType.Name -eq 'IAsyncOperation`1' } | Select-Object -First 1
function Await($operation,[Type]$resultType) {
    $task=$script:taskAdapter.MakeGenericMethod($resultType).Invoke($null,@($operation))
    $task.Wait()
    return $task.Result
}
$source=(Resolve-Path -LiteralPath $SourceDir).Path
$null=New-Item -ItemType Directory -Force -Path $OutputDir
$destination=(Resolve-Path -LiteralPath $OutputDir).Path
$language=New-Object Windows.Globalization.Language 'zh-Hans-CN'
$engine=[Windows.Media.Ocr.OcrEngine]::TryCreateFromLanguage($language)
if (-not $engine) { throw 'Chinese OCR is unavailable' }
$encoding=New-Object System.Text.UTF8Encoding($false)
foreach ($path in (Get-ChildItem -LiteralPath $source -Filter 'p*.png' -File | Sort-Object Name)) {
    $cachedPath=Join-Path $destination ($path.BaseName+'.json')
    $sourceHash=(Get-FileHash -LiteralPath $path.FullName -Algorithm SHA256).Hash.ToLower()
    if (Test-Path -LiteralPath $cachedPath) {
        $cached=Get-Content -LiteralPath $cachedPath -Raw -Encoding UTF8 | ConvertFrom-Json
        if ($cached.sha256 -eq $sourceHash) { Write-Output ($path.Name+' cached'); continue }
    }
    $file=Await ([Windows.Storage.StorageFile]::GetFileFromPathAsync($path.FullName)) ([Windows.Storage.StorageFile])
    $stream=Await ($file.OpenAsync([Windows.Storage.FileAccessMode]::Read)) ([Windows.Storage.Streams.IRandomAccessStream])
    $decoder=Await ([Windows.Graphics.Imaging.BitmapDecoder]::CreateAsync($stream)) ([Windows.Graphics.Imaging.BitmapDecoder])
    $bitmap=Await ($decoder.GetSoftwareBitmapAsync()) ([Windows.Graphics.Imaging.SoftwareBitmap])
    $result=Await ($engine.RecognizeAsync($bitmap)) ([Windows.Media.Ocr.OcrResult])
    $lines=@(foreach ($line in $result.Lines) {
        @{text=$line.Text;words=@(foreach ($word in $line.Words) {
            @{text=$word.Text;rect=@{x=$word.BoundingRect.X;y=$word.BoundingRect.Y;width=$word.BoundingRect.Width;height=$word.BoundingRect.Height}}
        })}
    })
    $record=@{source=$path.FullName;sha256=(Get-FileHash -LiteralPath $path.FullName -Algorithm SHA256).Hash.ToLower();width=$decoder.PixelWidth;height=$decoder.PixelHeight;engine='Windows.Media.Ocr';language='zh-Hans-CN';review_status='raw_unverified_not_an_answer_key';text=$result.Text;lines=$lines}
    [IO.File]::WriteAllText((Join-Path $destination ($path.BaseName+'.json')),($record | ConvertTo-Json -Depth 9),$encoding)
    [IO.File]::WriteAllText((Join-Path $destination ($path.BaseName+'.txt')),($lines.text -join "`r`n"),$encoding)
    $bitmap.Dispose();$stream.Dispose()
    Write-Output ($path.Name+' lines='+$lines.Count)
}
