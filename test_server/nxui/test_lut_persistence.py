#!/usr/bin/env python3
"""Exercise LUT lifecycle with fake tools; never access camera memory."""
import os
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[2]
STOCK = 'VIEW4 0x810fd100 0x81101e00 0x81106b00 0x81115200'

def main():
    with tempfile.TemporaryDirectory(prefix='lut-persist-') as tmp:
        base = Path(tmp)
        d = base/'installed'; sd = base/'sd'; state = sd/'lut/state'; pref = d/'nxui-state'
        tools = d/'lut'; tools.mkdir(parents=True)
        (sd/'looks').mkdir(parents=True)
        for name in ['warm','cool']:
            (sd/f'looks/{name}.bin').write_bytes(bytes(19712))
        model = base/'version'; model.write_text('NX500\n1.12\n')
        boot = base/'boot'; boot.write_text('boot-one\n')
        reg = base/'registry'; reg.write_text(STOCK)
        calls = base/'calls'; calls.touch()
        bak = sd/'nxwa_regtab_20261018'; bak.mkdir()
        def executable(p, text):
            p.write_text('#!/bin/sh\n'+text); p.chmod(0o755)
        executable(d/'busybox', '''case "$1" in
pidof) exit 0;;
sync) exit 0;;
esac
exec "$@"
''')
        executable(tools/'nx_slotwrite.arm', '''echo "slot $*" >> "$CALLS"
case "$1" in
read) printf 'new-backup' > "$3"; echo 'SLOT dumped';;
write) [ "${FAIL_WRITE:-0}" = 0 ] || exit 1; echo 'READBACK ok';;
restore) echo 'READBACK ok';;
esac
''')
        executable(tools/'nx_regtabwrite.arm', '''echo "reg $*" >> "$CALLS"
case "$1" in
view-status|status) cat "$REG"; exit;;
view-set) echo 'VIEW4 0x81119f00 0x81119f00 0x81119f00 0x81119f00' > "$REG";;
view-restore) printf '%s' "$STOCK" > "$REG";;
still-set) echo 'fresh' > "$BAK/still6_orig.bin";;
bv-set) echo 'fresh' > "$BAK/bv12_orig.bin";;
esac
echo 'READBACK ok'
''')
        executable(base/'sleep', 'if [ -n "${DELAYED_LOOKS:-}" ] && [ -d "$DELAYED_LOOKS" ]; then mv "$DELAYED_LOOKS" "$TARGET_LOOKS"; fi\nexit 0\n')
        script = base/'lut.sh'
        source = (ROOT/'scripts/lut.sh').read_text().replace('/opt/usr/nx-ks',str(d)).replace('/mnt/mmc',str(sd)).replace('/tmp/metol-lut.lock',str(base/'lock')).replace('/etc/version.info',str(model)).replace('/proc/sys/kernel/random/boot_id',str(boot))
        script.write_text(source)
        env = dict(os.environ, CALLS=str(calls), REG=str(reg), BAK=str(bak), STOCK=STOCK, PATH=str(base)+':'+os.environ['PATH'])
        def run(*args, ok=True, extra=None):
            result = subprocess.run(['sh',str(script),*args],env=env| (extra or {}),capture_output=True,text=True,timeout=5)
            assert (result.returncode==0)==ok,(args,result.stdout,result.stderr)
            return result.stdout
        (sd/'nxui').mkdir()
        (sd/'nxui/saved-lut').write_text('stale-card-selection\n')
        run('boot'); assert calls.read_text()==''  # no saved look, no hardware access
        run('apply','warm')
        assert (pref/'saved-lut').read_text()=='warm\n'
        assert (pref/'last-lut').read_text()=='warm\n'
        run('apply','cool',ok=False,extra={'FAIL_WRITE':'1'})
        assert (pref/'saved-lut').read_text()=='warm\n'
        # Resume with unchanged boot ID, stale touched, and patched pointers must reapply.
        calls.write_text('');run('boot')
        assert 'slot write' in calls.read_text()
        assert 'slot read' not in calls.read_text()  # preserve original backups
        # Same ID but factory pointers: refresh backups instead of stale restore.
        reg.write_text(STOCK);calls.write_text('');run('boot')
        assert 'slot read' in calls.read_text() and 'slot write' in calls.read_text()
        # A newer manual operation must cancel a pending restore under the lock.
        calls.write_text('');run('restore-saved','outdated')
        assert calls.read_text()==''

        # New boot must discard old RAM/registry backups before reapplying.
        boot.write_text('boot-two\n');reg.write_text(STOCK)
        (state/'a18_orig.bin').write_text('stale')
        (bak/'still6_orig.bin').write_text('stale')
        # Simulate card/LUT directory appearing only after the first wait.
        (sd/'looks').rename(sd/'looks-waiting')
        run('boot',extra={'DELAYED_LOOKS':str(sd/'looks-waiting'),'TARGET_LOOKS':str(sd/'looks')})
        assert 'RESULT 0' in (sd/'lut/boot-r5.log').read_text()
        assert 'card=absent' in (pref/'boot.log').read_text()
        assert (state/'current').read_text()=='warm\n'
        assert (state/'a18_orig.bin').read_text()=='new-backup'
        assert (bak/'still6_orig.bin').read_text()=='fresh\n'
        assert calls.read_text().count('slot restore')==0
        run('off');assert not (pref/'saved-lut').exists()
        boot.write_text('boot-three\n');reg.write_text(STOCK)
        before=calls.read_text();run('boot');assert calls.read_text()==before
        run('apply','cool');(sd/'looks/cool.bin').unlink()
        boot.write_text('boot-four\n');reg.write_text(STOCK);calls.write_text('')
        run('boot',ok=False)
        assert 'slot write' not in calls.read_text()
        # Unsupported firmware and invalid names never write memory.
        model.write_text('NX1\n1.41\n');calls.write_text('')
        run('boot');run('apply','warm',ok=False);assert calls.read_text()==''
        model.write_text('NX500\n1.12\n')
        run('apply','../warm',ok=False);assert 'slot write' not in calls.read_text()
        (base/'lock').mkdir();run('apply','warm',ok=False);(base/'lock').rmdir()
        # Camera not ready: timeout without writes and keep saved preference.
        boot.write_text('boot-five\n');reg.write_text('not-ready');calls.write_text('')
        run('boot',ok=False)
        assert 'slot write' not in calls.read_text()
        assert 'timed out' in (sd/'lut/boot-r5.log').read_text()
        print('PASS: internal persistence, delayed card readiness, boot diagnostics, successful/failed apply, boot restore, fresh backups, off, missing file, model guard, name validation, lock, readiness timeout')

if __name__=='__main__': main()
