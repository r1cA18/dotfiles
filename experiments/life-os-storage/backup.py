import datetime, hashlib, json, os, shutil, stat
from pathlib import Path
import sys

if len(sys.argv) != 3:
    raise SystemExit('Usage: python3 backup.py <vault> <backup-root>')
source = Path(sys.argv[1]).resolve()
root = Path(sys.argv[2]).resolve()
if not source.is_dir() or root.exists():
    raise SystemExit('Source must be a directory and backup-root must be new')
root.mkdir(parents=True, exist_ok=False, mode=0o700)
target = root / 'vault'
def inventory(base):
    records = {}
    for parent, dirs, files in os.walk(base, followlinks=False):
        for name in sorted(dirs + files):
            p = Path(parent) / name
            key = p.relative_to(base).as_posix()
            s = p.lstat()
            if stat.S_ISLNK(s.st_mode):
                records[key] = {'type': 'symlink', 'target': os.readlink(p)}
            elif stat.S_ISREG(s.st_mode):
                h = hashlib.sha256()
                with p.open('rb') as f:
                    for chunk in iter(lambda: f.read(1024 * 1024), b''):
                        h.update(chunk)
                records[key] = {'type': 'file', 'size': s.st_size, 'sha256': h.hexdigest()}
            elif stat.S_ISDIR(s.st_mode):
                records[key] = {'type': 'directory'}
            else:
                raise RuntimeError('Unsupported filesystem entry: ' + key)
    return records

before = inventory(source)
shutil.copytree(source, target, symlinks=True, copy_function=shutil.copy2)
copied = inventory(target)
after = inventory(source)
verified = before == copied == after
manifest = {'format': 1, 'source_name': source.name, 'snapshot': 'vault', 'verified': verified, 'entries': copied}
(root / 'manifest.json').write_text(json.dumps(manifest, ensure_ascii=False, indent=2))
result = {'backup': str(root), 'snapshot': str(target), 'verified': verified, 'files': sum(v['type'] == 'file' for v in copied.values()), 'bytes': sum(v.get('size', 0) for v in copied.values()), 'symlinks': sum(v['type'] == 'symlink' for v in copied.values())}
print(json.dumps(result))
if not verified:
    raise RuntimeError('Source changed or copy mismatch; do not import until resolved')
