# generate-icon.ps1
# Gera o AppIcon 1024x1024 do WakeHere usando System.Drawing (.NET)
# Lua crescente + ZZZ em cascata + pin de destino

Add-Type -AssemblyName System.Drawing

$size    = 1024
$outPath = Join-Path $PSScriptRoot "..\App\Assets.xcassets\AppIcon.appiconset\AppIcon-1024.png"
$outPath = [System.IO.Path]::GetFullPath($outPath)

$bmp = New-Object System.Drawing.Bitmap($size, $size, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
$g   = [System.Drawing.Graphics]::FromImage($bmp)
$g.SmoothingMode    = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
$g.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit

# ── 1. FUNDO — gradiente linear diagonal ──────────────────────────
$gradBg = New-Object System.Drawing.Drawing2D.LinearGradientBrush(
    (New-Object System.Drawing.Point(0,    0)),
    (New-Object System.Drawing.Point($size,$size)),
    [System.Drawing.Color]::FromArgb(255, 11,  26, 46),   # #0b1a2e
    [System.Drawing.Color]::FromArgb(255, 14,  42, 58)    # #0e2a3a
)
# ponto intermediário
$blend = New-Object System.Drawing.Drawing2D.ColorBlend
$blend.Colors    = @(
    [System.Drawing.Color]::FromArgb(255, 11, 26, 46),
    [System.Drawing.Color]::FromArgb(255, 16, 32, 53),
    [System.Drawing.Color]::FromArgb(255, 14, 42, 58)
)
$blend.Positions = @(0.0, 0.55, 1.0)
$gradBg.InterpolationColors = $blend
$g.FillRectangle($gradBg, 0, 0, $size, $size)
$gradBg.Dispose()

# ── 2. ESTRELINHAS ────────────────────────────────────────────────
$stars = @(
    @(768, 152,  9, 128),
    @(888, 272,  7,  97),
    @(664, 100,  6,  82),
    @(836, 440,  8,  71),
    @(136, 188,  8,  71),
    @(240, 120,  6,  56),
    @(920, 540,  5,  51),
    @(100, 420,  5,  46)
)
foreach ($s in $stars) {
    $x,$y,$r,$a = $s
    $sb = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb($a, 255,255,255))
    $g.FillEllipse($sb, ($x - $r), ($y - $r), ($r*2), ($r*2))
    $sb.Dispose()
}

# ── 3. AURA DA LUA ────────────────────────────────────────────────
$auraCx = 370; $auraCy = 390; $auraR = 340
$auraPath = New-Object System.Drawing.Drawing2D.GraphicsPath
$auraPath.AddEllipse(($auraCx - $auraR), ($auraCy - $auraR), ($auraR*2), ($auraR*2))
$auraGrad = New-Object System.Drawing.Drawing2D.PathGradientBrush($auraPath)
$auraGrad.CenterColor    = [System.Drawing.Color]::FromArgb(36, 240, 216, 64)   # #f0d840 36%
$auraGrad.SurroundColors = @([System.Drawing.Color]::FromArgb(0,  240, 216, 64))
$g.FillEllipse($auraGrad, ($auraCx-$auraR), ($auraCy-$auraR), ($auraR*2), ($auraR*2))
$auraGrad.Dispose()
$auraPath.Dispose()

# ── 4. LUA CRESCENTE ─────────────────────────────────────────────
# Técnica: desenha a lua cheia com gradiente, depois cobre com o "bite" (círculo de fundo)
$moonCx = 370; $moonCy = 390; $moonR = 256
$moonPath = New-Object System.Drawing.Drawing2D.GraphicsPath
$moonPath.AddEllipse(($moonCx-$moonR), ($moonCy-$moonR), ($moonR*2), ($moonR*2))
$moonGrad = New-Object System.Drawing.Drawing2D.PathGradientBrush($moonPath)
$moonGrad.CenterPoint    = New-Object System.Drawing.PointF(($moonCx - 60), ($moonCy - 80))
$moonGrad.CenterColor    = [System.Drawing.Color]::FromArgb(255, 255, 253, 224)  # #fffde0
$moonGrad.SurroundColors = @([System.Drawing.Color]::FromArgb(255, 232, 200, 32)) # #e8c820
$g.FillEllipse($moonGrad, ($moonCx-$moonR), ($moonCy-$moonR), ($moonR*2), ($moonR*2))
$moonGrad.Dispose()
$moonPath.Dispose()

# "bite" — sobrepõe com a cor do fundo para criar o efeito crescente
# usamos o mesmo gradiente de fundo no circulo de corte
$biteCx = 476; $biteCy = 318; $biteR = 206
$biteGrad = New-Object System.Drawing.Drawing2D.LinearGradientBrush(
    (New-Object System.Drawing.Point(0, 0)),
    (New-Object System.Drawing.Point($size, $size)),
    [System.Drawing.Color]::FromArgb(255, 11, 26, 46),
    [System.Drawing.Color]::FromArgb(255, 14, 42, 58)
)
$biteBlend = New-Object System.Drawing.Drawing2D.ColorBlend
$biteBlend.Colors    = @(
    [System.Drawing.Color]::FromArgb(255, 11, 26, 46),
    [System.Drawing.Color]::FromArgb(255, 16, 32, 53),
    [System.Drawing.Color]::FromArgb(255, 14, 42, 58)
)
$biteBlend.Positions = @(0.0, 0.55, 1.0)
$biteGrad.InterpolationColors = $biteBlend
$g.FillEllipse($biteGrad, ($biteCx-$biteR), ($biteCy-$biteR), ($biteR*2), ($biteR*2))
$biteGrad.Dispose()

# ── 5. ZZZ EM CASCATA ────────────────────────────────────────────
# Cada Z: 3 linhas (topo, diagonal, base). Tamanhos e opacidades decrescentes.
function Draw-Z($g, $x, $y, $w, $h, $sw, $alpha) {
    $pen = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb($alpha, 255,255,255), $sw)
    $pen.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
    $pen.EndCap   = [System.Drawing.Drawing2D.LineCap]::Round
    # topo
    $g.DrawLine($pen, $x,      $y,      $x+$w,  $y)
    # diagonal
    $g.DrawLine($pen, $x+$w,   $y,      $x,     $y+$h)
    # base
    $g.DrawLine($pen, $x,      $y+$h,   $x+$w,  $y+$h)
    $pen.Dispose()
}

# Z grande  (100% opacidade → alpha 245)
Draw-Z $g  562  444  136  120   36  245
# Z médio   (68% opacidade → alpha 173)
Draw-Z $g  668  296   96   88   28  173
# Z pequeno (38% opacidade → alpha  97)
Draw-Z $g  746  176   62   58   22   97

# ── 6. PIN DE DESTINO ─────────────────────────────────────────────
# Sombra do pin
$shadowBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(56, 0,0,0))
$g.FillEllipse($shadowBrush, (668-68), (882-26), 136, 52)
$shadowBrush.Dispose()

# Corpo do pin — GraphicsPath em forma de teardrop
$pinX = 668; $pinTop = 664; $pinBot = 964; $pinW = 116
$pinPath = New-Object System.Drawing.Drawing2D.GraphicsPath
# Construção via Bezier: ponto do topo → lados curvados → ponta inferior
# Simplificado: elipse superior + triângulo inferior
$circR = 108   # raio do circulo do pin
$circCy = $pinTop + $circR
$pinPath.AddEllipse(($pinX - $circR), ($pinTop), ($circR*2), ($circR*2))
$pinPath.AddPolygon(@(
    (New-Object System.Drawing.PointF(($pinX - 48), ($circCy + 60))),
    (New-Object System.Drawing.PointF(($pinX + 48), ($circCy + 60))),
    (New-Object System.Drawing.PointF($pinX,         $pinBot))
))
$pinBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(255, 255, 59, 48))  # #ff3b30
$g.FillPath($pinBrush, $pinPath)
$pinBrush.Dispose()
$pinPath.Dispose()

# Brilho do pin (gradiente diagonal de branco transparente)
$pinSheen = New-Object System.Drawing.Drawing2D.LinearGradientBrush(
    (New-Object System.Drawing.Point(556, 656)),
    (New-Object System.Drawing.Point(780, 960)),
    [System.Drawing.Color]::FromArgb(89, 255,255,255),
    [System.Drawing.Color]::FromArgb(0,  255, 59, 48)
)
$pinSheenPath = New-Object System.Drawing.Drawing2D.GraphicsPath
$pinSheenPath.AddEllipse(($pinX - $circR), $pinTop, ($circR*2), ($circR*2))
$pinSheenPath.AddPolygon(@(
    (New-Object System.Drawing.PointF(($pinX - 48), ($circCy + 60))),
    (New-Object System.Drawing.PointF(($pinX + 48), ($circCy + 60))),
    (New-Object System.Drawing.PointF($pinX,         $pinBot))
))
$g.FillPath($pinSheen, $pinSheenPath)
$pinSheen.Dispose()
$pinSheenPath.Dispose()

# Ponto branco central
$dotR = 40
$dotBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::White)
$g.FillEllipse($dotBrush, ($pinX - $dotR), (776 - $dotR), ($dotR*2), ($dotR*2))
$dotBrush.Dispose()

# ── 7. SALVAR ─────────────────────────────────────────────────────
$g.Dispose()
$bmp.Save($outPath, [System.Drawing.Imaging.ImageFormat]::Png)
$bmp.Dispose()

Write-Host "✅ Ícone salvo em: $outPath"
