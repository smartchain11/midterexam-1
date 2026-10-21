Add-Type -AssemblyName System.Drawing

$width = 2700
$height = 2220
$outputDirectory = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\docs'))
$bitmap = [System.Drawing.Bitmap]::new($width, $height)
$bitmap.SetResolution(180, 180)
$graphics = [System.Drawing.Graphics]::FromImage($bitmap)
$graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
$graphics.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit
$graphics.Clear([System.Drawing.Color]::White)
$svg = [System.Text.StringBuilder]::new()
$null = $svg.AppendLine('<svg xmlns="http://www.w3.org/2000/svg" width="2700" height="2220" viewBox="0 0 2700 2220" role="img" aria-labelledby="title description">')
$null = $svg.AppendLine('<title id="title">Scholarship monitoring system UML use-case diagram</title><desc id="description">Scholar on the left, Scholarship Staff on the right, and use cases inside the system boundary between them. Dashed arrows show mandatory include and conditional extend relationships.</desc>')
$null = $svg.AppendLine('<defs><marker id="arrow" markerWidth="10" markerHeight="10" refX="9" refY="5" orient="auto" markerUnits="userSpaceOnUse"><path d="M1 1 L9 5 L1 9" fill="none" stroke="#40554b" stroke-width="2"/></marker></defs><rect width="2700" height="2220" fill="white"/>')

function Add-Line {
  param([object[]]$Points, [switch]$Dashed, [switch]$Arrow, [string]$Color = '#40554b', [float]$Weight = 2.8)
  $pen = [System.Drawing.Pen]::new([System.Drawing.ColorTranslator]::FromHtml($Color), $Weight)
  if ($Dashed) { $pen.DashPattern = [float[]]@(6, 4) }
  $drawingPoints = [System.Drawing.PointF[]]@($Points | ForEach-Object { [System.Drawing.PointF]::new([float]$_[0], [float]$_[1]) })
  $graphics.DrawLines($pen, $drawingPoints)
  if ($Arrow) {
    $end = $drawingPoints[-1]
    $previous = $drawingPoints[-2]
    $angle = [Math]::Atan2($end.Y - $previous.Y, $end.X - $previous.X)
    foreach ($offset in @(-0.45, 0.45)) {
      $x = $end.X - 17 * [Math]::Cos($angle + $offset)
      $y = $end.Y - 17 * [Math]::Sin($angle + $offset)
      $graphics.DrawLine($pen, $end.X, $end.Y, [float]$x, [float]$y)
    }
  }
  $coordinates = ($Points | ForEach-Object { '{0},{1}' -f $_[0], $_[1] }) -join ' '
  $dashAttribute = if ($Dashed) { ' stroke-dasharray="17 11"' } else { '' }
  $arrowAttribute = if ($Arrow) { ' marker-end="url(#arrow)"' } else { '' }
  $null = $svg.AppendLine("<polyline points=`"$coordinates`" fill=`"none`" stroke=`"$Color`" stroke-width=`"$Weight`"$dashAttribute$arrowAttribute/>")
  $pen.Dispose()
}

function Add-Text {
  param([string]$Text, [float]$X, [float]$Y, [float]$Width, [float]$Height, [float]$Size = 27, [switch]$Bold, [string]$Color = '#203b34')
  $style = if ($Bold) { [System.Drawing.FontStyle]::Bold } else { [System.Drawing.FontStyle]::Regular }
  $font = [System.Drawing.Font]::new('Arial', $Size, $style, [System.Drawing.GraphicsUnit]::Pixel)
  $brush = [System.Drawing.SolidBrush]::new([System.Drawing.ColorTranslator]::FromHtml($Color))
  $format = [System.Drawing.StringFormat]::new()
  $format.Alignment = [System.Drawing.StringAlignment]::Center
  $format.LineAlignment = [System.Drawing.StringAlignment]::Center
  $graphics.DrawString($Text, $font, $brush, [System.Drawing.RectangleF]::new($X, $Y, $Width, $Height), $format)
  $lines = $Text -split "`n"
  $center = $X + $Width / 2
  $lineHeight = $Size * 1.2
  $start = $Y + $Height / 2 - (($lines.Count - 1) * $lineHeight) / 2 + $Size * 0.34
  $weightAttribute = if ($Bold) { ' font-weight="700"' } else { '' }
  $null = $svg.AppendLine("<text font-family=`"Arial, sans-serif`" font-size=`"$Size`" fill=`"$Color`" text-anchor=`"middle`"$weightAttribute>")
  for ($i = 0; $i -lt $lines.Count; $i++) {
    $encoded = [System.Security.SecurityElement]::Escape($lines[$i])
    $baseline = $start + $i * $lineHeight
    $null = $svg.AppendLine("<tspan x=`"$center`" y=`"$baseline`">$encoded</tspan>")
  }
  $null = $svg.AppendLine('</text>')
  $format.Dispose()
  $brush.Dispose()
  $font.Dispose()
}

function Add-UseCase {
  param([string]$Text, [float]$X, [float]$CenterY, [float]$Width = 470, [float]$Height = 110, [float]$Size = 27, [string]$Fill = '#f7faf8')
  $top = $CenterY - $Height / 2
  $brush = [System.Drawing.SolidBrush]::new([System.Drawing.ColorTranslator]::FromHtml($Fill))
  $pen = [System.Drawing.Pen]::new([System.Drawing.ColorTranslator]::FromHtml('#264b39'), 2.8)
  $graphics.FillEllipse($brush, $X, $top, $Width, $Height)
  $graphics.DrawEllipse($pen, $X, $top, $Width, $Height)
  $centerX = $X + $Width / 2
  $rx = $Width / 2
  $ry = $Height / 2
  $null = $svg.AppendLine("<ellipse cx=`"$centerX`" cy=`"$CenterY`" rx=`"$rx`" ry=`"$ry`" fill=`"$Fill`" stroke=`"#264b39`" stroke-width=`"2.8`"/>")
  Add-Text -Text $Text -X ($X + 25) -Y ($top + 6) -Width ($Width - 50) -Height ($Height - 12) -Size $Size
  $brush.Dispose()
  $pen.Dispose()
}

function Add-Actor {
  param([float]$CenterX, [string]$Name)
  $pen = [System.Drawing.Pen]::new([System.Drawing.ColorTranslator]::FromHtml('#203b34'), 4.5)
  $graphics.DrawEllipse($pen, ($CenterX - 31), 874, 62, 62)
  $null = $svg.AppendLine("<circle cx=`"$CenterX`" cy=`"905`" r=`"31`" fill=`"white`" stroke=`"#203b34`" stroke-width=`"4.5`"/>")
  Add-Line -Points @(@($CenterX,936),@($CenterX,1040)) -Weight 4.5 -Color '#203b34'
  Add-Line -Points @(@(($CenterX-64),975),@($CenterX,951),@(($CenterX+64),975)) -Weight 4.5 -Color '#203b34'
  Add-Line -Points @(@(($CenterX-51),1110),@($CenterX,1040),@(($CenterX+51),1110)) -Weight 4.5 -Color '#203b34'
  Add-Text -Text $Name -X ($CenterX-155) -Y 1130 -Width 310 -Height 95 -Size 29 -Bold
  $pen.Dispose()
}

Add-Text -Text 'UML USE-CASE DIAGRAM' -X 400 -Y 35 -Width 1900 -Height 65 -Size 45 -Bold
Add-Text -Text 'ADSSU Scholarship Monitoring and Academic Compliance' -X 400 -Y 103 -Width 1900 -Height 45 -Size 29 -Color '#61756a'

$boundaryPen = [System.Drawing.Pen]::new([System.Drawing.ColorTranslator]::FromHtml('#264b39'), 3.5)
$graphics.DrawRectangle($boundaryPen, 410, 200, 1880, 1840)
$null = $svg.AppendLine('<rect x="410" y="200" width="1880" height="1840" fill="none" stroke="#264b39" stroke-width="3.5"/>')
$boundaryPen.Dispose()
Add-Text -Text 'Student Scholarship Monitoring and Academic Compliance System' -X 470 -Y 216 -Width 1760 -Height 58 -Size 30 -Bold

Add-Line -Points @(@(244,975),@(335,975))
Add-Line -Points @(@(335,360),@(335,1950))
Add-Line -Points @(@(2456,975),@(2365,975))
Add-Line -Points @(@(2365,360),@(2365,1950))
foreach ($y in @(500,720,940,1160)) { Add-Line -Points @(@(335,$y),@(475,$y)) }
foreach ($y in @(500,700,900,1130,1330,1510)) { Add-Line -Points @(@(2225,$y),@(2365,$y)) }
foreach ($y in @(360,1690,1820,1950)) {
  Add-Line -Points @(@(335,$y),@(1115,$y))
  Add-Line -Points @(@(1585,$y),@(2365,$y))
}

Add-Line -Points @(@(945,720),@(1115,720)) -Dashed -Arrow
Add-Line -Points @(@(945,940),@(1010,940),@(1010,810),@(1350,810),@(1350,775)) -Dashed -Arrow
Add-Line -Points @(@(1755,1130),@(1670,1130),@(1670,1260),@(1585,1260)) -Dashed -Arrow
Add-Line -Points @(@(1755,1330),@(1670,1330),@(1670,1260),@(1585,1260)) -Dashed -Arrow
Add-Line -Points @(@(1585,980),@(1755,900)) -Dashed -Arrow

Add-UseCase -Text 'UC01  Sign In' -X 1115 -CenterY 360 -Height 105 -Fill '#ffffff'
Add-UseCase -Text "UC12  Register Student Account`n& Confirm Email" -X 475 -CenterY 500 -Height 130
Add-UseCase -Text 'UC03  Submit Grades' -X 475 -CenterY 720
Add-UseCase -Text 'UC04  Correct and Resubmit' -X 475 -CenterY 940 -Size 26
Add-UseCase -Text "UC05  View Own Status`nand History" -X 475 -CenterY 1160 -Height 125

Add-UseCase -Text "Validate Summary`n(required field and input checks)" -X 1115 -CenterY 720 -Size 24 -Fill '#edf3ef'
Add-UseCase -Text "Return Evidence`n[if evidence is unacceptable]" -X 1115 -CenterY 980 -Height 120 -Size 24 -Fill '#fffaf0'
Add-UseCase -Text "Record Audit Event`n(actor, timestamp and result)" -X 1115 -CenterY 1260 -Size 24 -Fill '#edf3ef'

Add-UseCase -Text "UC02  Register Scholar`nand Assign Policy" -X 1755 -CenterY 500 -Height 125
Add-UseCase -Text "UC13  Approve Initial`nScholarship Assignment" -X 1755 -CenterY 700 -Height 125
Add-UseCase -Text "UC06  Review Evidence`nExtension point:`nevidence found unacceptable" -X 1755 -CenterY 900 -Height 150 -Size 23
Add-UseCase -Text 'UC07  Evaluate Compliance' -X 1755 -CenterY 1130 -Size 26
Add-UseCase -Text 'UC08  Decide Renewal' -X 1755 -CenterY 1330
Add-UseCase -Text 'UC11  View Decision History' -X 1755 -CenterY 1510 -Size 25

Add-UseCase -Text 'UC09  View Dashboard' -X 1115 -CenterY 1690 -Height 95 -Fill '#ffffff'
Add-UseCase -Text 'UC10  Search and Filter' -X 1115 -CenterY 1820 -Height 95 -Fill '#ffffff'
Add-UseCase -Text "UC14  Browse Scholarship`nDirectory (reference only)" -X 1115 -CenterY 1950 -Height 110 -Size 25 -Fill '#ffffff'

Add-Text -Text '<<include>>' -X 942 -Y 666 -Width 176 -Height 40 -Size 22
Add-Text -Text '<<include>>' -X 1085 -Y 824 -Width 195 -Height 40 -Size 22
Add-Text -Text '<<include>>' -X 1582 -Y 1080 -Width 176 -Height 40 -Size 22
Add-Text -Text '<<include>>' -X 1582 -Y 1340 -Width 176 -Height 40 -Size 22
Add-Text -Text '<<extend>>' -X 1577 -Y 848 -Width 190 -Height 40 -Size 22

Add-Actor -CenterX 180 -Name 'Scholar'
Add-Actor -CenterX 2520 -Name "Scholarship`nStaff"

Add-Text -Text 'Solid lines: actor associations   |   Dashed arrows: include / extend relationships' -X 410 -Y 2070 -Width 1880 -Height 45 -Size 23 -Color '#61756a'
Add-Text -Text 'Authentication is a precondition for protected goals. Directory browsing is public and informational.' -X 350 -Y 2120 -Width 2000 -Height 45 -Size 22 -Color '#61756a'

$null = $svg.AppendLine('</svg>')
$pngPath = Join-Path $outputDirectory 'use-case-diagram.png'
$svgPath = Join-Path $outputDirectory 'use-case-diagram.svg'
$bitmap.Save($pngPath, [System.Drawing.Imaging.ImageFormat]::Png)
[System.IO.File]::WriteAllText($svgPath, $svg.ToString(), [System.Text.UTF8Encoding]::new($false))
$graphics.Dispose()
$bitmap.Dispose()
Write-Output "Created $pngPath"
Write-Output "Created $svgPath"
