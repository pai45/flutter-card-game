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

    $random = [System.Random]::new(824221)
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

# Clean make — short bright noise burst through the net.
Write-MonoWav -Path (Join-Path $OutputDirectory "bb_swish.wav") -Duration 0.28 -Sample {
  param($t, $i, $random)
  $envelope = [Math]::Exp(-22 * $t)
  $noise = ($random.NextDouble() * 2 - 1)
  $band = $noise * (0.55 + 0.45 * [Math]::Sin(2 * [Math]::PI * 2400 * $t))
  $body = [Math]::Sin(2 * [Math]::PI * 320 * $t) * 0.12
  return ($band * 0.6 + $body) * $envelope
}

# Miss — metallic rim clank with a slow ring-out.
Write-MonoWav -Path (Join-Path $OutputDirectory "bb_rim_rattle.wav") -Duration 0.5 -Sample {
  param($t, $i, $random)
  $envelope = [Math]::Exp(-9 * $t)
  $lowRing = [Math]::Sin(2 * [Math]::PI * 190 * $t) * 0.5
  $highRing = [Math]::Sin(2 * [Math]::PI * 760 * $t) * 0.34 * [Math]::Exp(-14 * $t)
  $strike = ($random.NextDouble() * 2 - 1) * 0.4 * [Math]::Exp(-70 * $t)
  return ($lowRing + $highRing + $strike) * $envelope
}

# Block into the glass — dull low thud.
Write-MonoWav -Path (Join-Path $OutputDirectory "bb_backboard.wav") -Duration 0.15 -Sample {
  param($t, $i, $random)
  $envelope = [Math]::Exp(-30 * $t)
  $thud = [Math]::Sin(2 * [Math]::PI * 120 * $t) * 0.7
  $board = [Math]::Sin(2 * [Math]::PI * 480 * $t) * 0.2 * [Math]::Exp(-55 * $t)
  $slap = ($random.NextDouble() * 2 - 1) * 0.3 * [Math]::Exp(-90 * $t)
  return ($thud + $board + $slap) * $envelope
}

# Dunk — deep boom with a rim-rattle tail.
Write-MonoWav -Path (Join-Path $OutputDirectory "bb_dunk_slam.wav") -Duration 0.6 -Sample {
  param($t, $i, $random)
  $boom = [Math]::Sin(2 * [Math]::PI * 70 * $t) * [Math]::Exp(-8 * $t) * 0.85
  $punch = ($random.NextDouble() * 2 - 1) * 0.5 * [Math]::Exp(-60 * $t)
  $rattle = [Math]::Sin(2 * [Math]::PI * 210 * $t) * [Math]::Sin(2 * [Math]::PI * 31 * $t) * 0.3 * [Math]::Exp(-6 * $t)
  return $boom + $punch + $rattle
}

# Half/OT horn — sustained arena buzzer with a hard cut.
Write-MonoWav -Path (Join-Path $OutputDirectory "bb_buzzer.wav") -Duration 0.9 -Sample {
  param($t, $i, $random)
  $attack = [Math]::Min(1, $t * 40)
  $fundamental = [Math]::Sin(2 * [Math]::PI * 435 * $t)
  $square = [Math]::Sign($fundamental) * 0.35 + $fundamental * 0.4
  $fifth = [Math]::Sin(2 * [Math]::PI * 652 * $t) * 0.18
  return ($square + $fifth) * $attack * 0.8
}

# Big-play crowd — shaped noise swell that decays.
Write-MonoWav -Path (Join-Path $OutputDirectory "bb_crowd_roar.wav") -Duration 1.4 -Sample {
  param($t, $i, $random)
  $swell = [Math]::Min(1, $t * 5) * [Math]::Exp(-1.6 * [Math]::Max(0, $t - 0.4))
  $noise = ($random.NextDouble() * 2 - 1)
  $rumble = [Math]::Sin(2 * [Math]::PI * 90 * $t) * 0.15
  $texture = $noise * (0.5 + 0.5 * [Math]::Sin(2 * [Math]::PI * 7 * $t))
  return ($texture * 0.55 + $rumble) * $swell
}

# Hard cut / steal — rising sneaker chirp on hardwood.
Write-MonoWav -Path (Join-Path $OutputDirectory "bb_sneaker_squeak.wav") -Duration 0.09 -Sample {
  param($t, $i, $random)
  $envelope = [Math]::Exp(-28 * $t) * [Math]::Min(1, $t * 220)
  $freq = 1900 + 7800 * $t
  $chirp = [Math]::Sin(2 * [Math]::PI * $freq * $t)
  $grit = ($random.NextDouble() * 2 - 1) * 0.18
  return ($chirp * 0.7 + $grit) * $envelope
}

Write-Host "Basketball SFX written to $OutputDirectory"
