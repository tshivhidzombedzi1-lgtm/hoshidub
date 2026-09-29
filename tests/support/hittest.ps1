param([string]$hwnd, [string]$points)
Add-Type @"
using System; using System.Runtime.InteropServices;
public class W { [DllImport("user32.dll")] public static extern IntPtr SendMessage(IntPtr h, int m, IntPtr w, IntPtr l); }
"@
$h = [IntPtr][Int64]$hwnd
foreach ($p in $points.Split(';')) {
  $n, $x, $y = $p.Split(',')
  $l = (([int]$y -band 0xFFFF) -shl 16) -bor ([int]$x -band 0xFFFF)
  $r = [W]::SendMessage($h, 0x84, [IntPtr]::Zero, [IntPtr]$l)
  $name = @{1='CLIENT (clickable)'; 2='CAPTION (title bar!)'; 20='CLOSE'; 8='MIN'; 9='MAX'}[[int]$r]
  "{0,-14} -> {1} {2}" -f $n, [int]$r, $name
}
