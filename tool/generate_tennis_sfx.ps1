param(
  [string]$OutputDirectory = "assets/audio"
)

$sampleRate = 44100

function Write-MonoWav {
  param(
    [string]$Path,
    [double]$Duration,
    [scriptblock]$Sample
  )

  $sampleCount = [int]($sampleRate * $Duration)
  $dataLength = $sampleCount * 2
  $stream = [System.IO.File]::Open($Path, [System.IO.FileMode]::Create)
  $writer = [System.IO.BinaryWriter]::new($stream)
  try {
    $writer.Write([System.Text.Encoding]::ASCII.GetBytes("RIFF"))
    $writer.Write([int](36 + $dataLength))
    $writer.Write([System.Text.Encoding]::ASCII.GetBytes("WAVE"))
    $writer.Write([System.Text.Encoding]::ASCII.GetBytes("fmt "))
    $writer.Write([int]16)
    $writer.Write([int16]1)
    $writer.Write([int16]1)
    $writer.Write([int]$sampleRate)
    $writer.Write([int]($sampleRate * 2))
    $writer.Write([int16]2)
    $writer.Write([int16]16)
    $writer.Write([System.Text.Encoding]::ASCII.GetBytes("data"))
    $writer.Write([int]$dataLength)

    $random = [System.Random]::new(710115)
    for ($i = 0; $i -lt $sampleCount; $i++) {
      $time = $i / $sampleRate
      $value = & $Sample $time $i $random
      $value = [Math]::Max(-1, [Math]::Min(1, $value))
      $writer.Write([int16]($value * 32767))
    }
  }
  finally {
    $writer.Dispose()
    $stream.Dispose()
  }
}

New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null

Write-MonoWav -Path (Join-Path $OutputDirectory "tennis_contact.wav") -Duration 0.12 -Sample {
  param($t, $i, $random)
  $envelope = [Math]::Exp(-34 * $t)
  $body = [Math]::Sin(2 * [Math]::PI * 205 * $t) * 0.72
  $string = [Math]::Sin(2 * [Math]::PI * 1040 * $t) * 0.18
  $noise = ($random.NextDouble() * 2 - 1) * 0.22
  return ($body + $string + $noise) * $envelope
}

Write-MonoWav -Path (Join-Path $OutputDirectory "tennis_bounce.wav") -Duration 0.075 -Sample {
  param($t, $i, $random)
  $envelope = [Math]::Exp(-58 * $t)
  $tone = [Math]::Sin(2 * [Math]::PI * 610 * $t) * 0.48
  $click = ($random.NextDouble() * 2 - 1) * 0.46
  return ($tone + $click) * $envelope
}

Write-MonoWav -Path (Join-Path $OutputDirectory "tennis_net.wav") -Duration 0.19 -Sample {
  param($t, $i, $random)
  $envelope = [Math]::Exp(-18 * $t)
  $rattle = [Math]::Sin(2 * [Math]::PI * 780 * $t) * [Math]::Sin(2 * [Math]::PI * 43 * $t)
  $wire = [Math]::Sin(2 * [Math]::PI * 1310 * $t) * 0.24
  $noise = ($random.NextDouble() * 2 - 1) * 0.16
  return ($rattle * 0.46 + $wire + $noise) * $envelope
}
