param(
  [string]$ProjectRoot = (Split-Path -Parent $PSScriptRoot)
)

Add-Type -AssemblyName System.Drawing

$targets = [ordered]@{
  'mipmap-mdpi' = 48
  'mipmap-hdpi' = 72
  'mipmap-xhdpi' = 96
  'mipmap-xxhdpi' = 144
  'mipmap-xxxhdpi' = 192
}

foreach ($entry in $targets.GetEnumerator()) {
  $size = [int]$entry.Value
  $bitmap = New-Object System.Drawing.Bitmap($size, $size)
  $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
  $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
  $graphics.Clear([System.Drawing.ColorTranslator]::FromHtml('#0D111A'))

  $cyan = [System.Drawing.ColorTranslator]::FromHtml('#5CDFFF')
  $deepBlue = [System.Drawing.ColorTranslator]::FromHtml('#00285E')
  $white = [System.Drawing.ColorTranslator]::FromHtml('#F5F7FA')
  $orange = [System.Drawing.ColorTranslator]::FromHtml('#FF7A18')
  $yellow = [System.Drawing.ColorTranslator]::FromHtml('#FFC400')
  $red = [System.Drawing.ColorTranslator]::FromHtml('#E62D2D')

  $margin = $size * 0.085
  $ringWidth = [Math]::Max(2, $size * 0.045)
  $graphics.FillEllipse(
    (New-Object System.Drawing.SolidBrush($deepBlue)),
    $margin,
    $margin,
    $size - 2 * $margin,
    $size - 2 * $margin
  )
  $graphics.DrawEllipse(
    (New-Object System.Drawing.Pen($cyan, $ringWidth)),
    $margin,
    $margin,
    $size - 2 * $margin,
    $size - 2 * $margin
  )

  for ($index = 0; $index -lt 6; $index++) {
    $angle = (-150 + $index * 24) * [Math]::PI / 180
    $dotX = $size * 0.5 + [Math]::Cos($angle) * $size * 0.345
    $dotY = $size * 0.5 + [Math]::Sin($angle) * $size * 0.345
    $dotRadius = if ($index -eq 5) { $size * 0.035 } else { $size * 0.022 }
    $dotColor = if ($index -eq 5) { $yellow } else { $cyan }
    $graphics.FillEllipse(
      (New-Object System.Drawing.SolidBrush($dotColor)),
      $dotX - $dotRadius,
      $dotY - $dotRadius,
      $dotRadius * 2,
      $dotRadius * 2
    )
  }

  $monogramPen = New-Object System.Drawing.Pen($white, ([Math]::Max(3, $size * 0.10)))
  $monogramPen.StartCap = [System.Drawing.Drawing2D.LineCap]::Square
  $monogramPen.EndCap = [System.Drawing.Drawing2D.LineCap]::Square
  $graphics.DrawLine($monogramPen, $size * .32, $size * .68, $size * .32, $size * .31)
  $graphics.DrawLine($monogramPen, $size * .32, $size * .32, $size * .53, $size * .32)
  $graphics.DrawLine($monogramPen, $size * .32, $size * .48, $size * .48, $size * .48)
  $graphics.DrawEllipse(
    (New-Object System.Drawing.Pen($orange, ([Math]::Max(3, $size * .085)))),
    $size * .48,
    $size * .42,
    $size * .25,
    $size * .25
  )

  $ballRadius = $size * .075
  $ballX = $size * .64
  $ballY = $size * .27
  $graphics.FillEllipse(
    (New-Object System.Drawing.SolidBrush($red)),
    $ballX - $ballRadius,
    $ballY - $ballRadius,
    $ballRadius * 2,
    $ballRadius * 2
  )
  $graphics.DrawArc(
    (New-Object System.Drawing.Pen($white, ([Math]::Max(1, $size * .012)))),
    $ballX - $ballRadius * .55,
    $ballY - $ballRadius * .8,
    $ballRadius * 1.1,
    $ballRadius * 1.6,
    -42,
    84
  )

  $destination = Join-Path $ProjectRoot "android\app\src\main\res\$($entry.Key)\ic_launcher.png"
  $bitmap.Save($destination, [System.Drawing.Imaging.ImageFormat]::Png)
  $graphics.Dispose()
  $bitmap.Dispose()
}

Write-Output "Generated five original Final Over launcher icons."
