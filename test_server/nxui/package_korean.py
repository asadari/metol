#!/usr/bin/env python3
"""Create the Korean SD-card installation archive after building nxui.arm."""
from pathlib import Path
import hashlib
import json
import zipfile

ROOT = Path(__file__).resolve().parents[2]
TARGET = ROOT / 'release/Metol-KO-NX500-20261023-r5.zip'

def main():
    binary = (ROOT/'scripts/nxui/nxui.arm').read_bytes()
    assert binary[:4] == b'\x7fELF' and '저장 후 닫기'.encode() in binary
    results = json.loads((ROOT/'test_server/nxui/out/korean-display-results.json').read_text())
    assert len(results)==3 and all(r['result']=='PASS' for r in results)
    files = {str(p.relative_to(ROOT)):p for p in (ROOT/'scripts').rglob('*') if p.is_file() and p.name!='.DS_Store'}
    # LUT runtime reads /mnt/mmc/looks, outside the installed scripts tree.
    looks = sorted((ROOT/'looks').glob('*.bin'))
    assert looks, 'LUT library missing'
    for p in looks:
        assert p.stat().st_size == 19712, f'Invalid native LUT size: {p}'
        files[str(p.relative_to(ROOT))] = p
    for name in ['info.tg','nx_cs.adj','install.sh','README_KO.md','LICENSE','ATTRIBUTION.md']:
        files[name]=ROOT/name
    records = {name:hashlib.sha256(p.read_bytes()).hexdigest() for name,p in sorted(files.items())}
    TARGET.parent.mkdir(exist_ok=True)
    with zipfile.ZipFile(TARGET,'w',zipfile.ZIP_DEFLATED) as archive:
        for name,p in sorted(files.items()):
            data=p.read_bytes()
            item=zipfile.ZipInfo(name)
            item.compress_type=zipfile.ZIP_DEFLATED
            executable=data.startswith((b'#!',b'\x7fELF')) or p.suffix in ('.sh','.arm')
            item.external_attr=(0o100755 if executable else 0o100644)<<16
            archive.writestr(item,data)
        archive.writestr('SHA256SUMS',''.join(f'{digest}  {name}\n' for name,digest in records.items()))
    with zipfile.ZipFile(TARGET) as archive:
        assert archive.testzip() is None
        for name,digest in records.items():
            assert hashlib.sha256(archive.read(name)).hexdigest()==digest,name
    digest=hashlib.sha256(TARGET.read_bytes()).hexdigest()
    TARGET.with_suffix('.zip.sha256').write_text(f'{digest}  {TARGET.name}\n')
    print(f'{TARGET}\n{TARGET.stat().st_size:,} bytes; {len(files)} files; manifest verified\nSHA256 {digest}')

if __name__=='__main__': main()
