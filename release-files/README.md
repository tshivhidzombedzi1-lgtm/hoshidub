# Built files for the website

`Hoshidub-Setup-0.1.0.exe` (the signed Windows installer, built 2026-09-30 12:31 from commit 1d26d56, licence server = hoshidub.com) is stored here in two pieces, because GitHub doesn't accept files over 100 MB. A normal `git pull` brings them along; no GitHub Release login needed.

Join them back into the installer:

    # Linux / the Hostinger server
    cat Hoshidub-Setup-0.1.0.exe.part0 Hoshidub-Setup-0.1.0.exe.part1 > Hoshidub-Setup-0.1.0.exe

    # Windows
    copy /b Hoshidub-Setup-0.1.0.exe.part0 + Hoshidub-Setup-0.1.0.exe.part1 Hoshidub-Setup-0.1.0.exe

Check it's identical to the original:

    sha256sum Hoshidub-Setup-0.1.0.exe
    a8ecdbac73e275554b1d4a5539eec86f5d978804ef249feb852288297e76fc32   (115,387,979 bytes)

Then put it at `public_html/downloads/Hoshidub-Setup-0.1.0.exe`, same name, replacing the old one.

The voice engine parts (runtime pack v2: manifest.json + runtime.zip.001-008, 3.1 GB) are too big for the repo; they're in GitHub Release v0.1.0 and in `dist/runtime` on the owner's PC.
