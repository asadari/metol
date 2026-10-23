#!/usr/bin/env python3
"""Subset static NotoSansCJKkr-Regular.otf for NXUI (pip install fonttools).

Source: https://github.com/notofonts/noto-cjk/tree/main/Sans/OTF/Korean
Usage: python3 make_korean_font.py /path/to/NotoSansCJKkr-Regular.otf
The font is renamed under the SIL OFL; see fonts-ko/OFL-NotoSansCJK.txt.
"""
from pathlib import Path
import sys
from fontTools import subset
from fontTools.ttLib import TTFont
from make_font_subset import gb2312_chars

ROOT = Path(__file__).resolve().parents[2]
DEST = ROOT / 'scripts/nxui/fonts-ko/NXUI_KO.otf'

def main():
    font = TTFont(sys.argv[1])
    # Full modern Hangul and Jamo allow user-defined Korean LUT names, too.
    points = set(range(0x20, 0x7f)) | set(range(0xac00, 0xd7a4))
    points |= set(range(0x1100, 0x1200)) | set(range(0x3130, 0x3190))
    # Retain punctuation and CJK for existing user recipe libraries.
    points |= set(range(0x2000, 0x2070)) | set(range(0x3000, 0x3040))
    points |= set(map(ord, gb2312_chars())) | set(map(ord, '◀▶‹›·…'))
    options = subset.Options()
    options.name_IDs = ['*']
    options.layout_features = ['*']
    worker = subset.Subsetter(options=options)
    worker.populate(unicodes=points)
    worker.subset(font)
    for record in font['name'].names:
        if record.nameID in (1, 3, 4, 6, 16):
            record.string = 'NXUI_KO'
    if 'CFF ' in font:
        cff = font['CFF '].cff
        cff.fontNames = ['NXUI_KO']
        cff.topDictIndex[0].FamilyName = 'NXUI_KO'
        cff.topDictIndex[0].FullName = 'NXUI_KO'
    DEST.parent.mkdir(parents=True, exist_ok=True)
    font.save(DEST)
    print(f'{DEST}: {DEST.stat().st_size:,} bytes')

if __name__ == '__main__':
    main()
