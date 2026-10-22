import hashlib,io,json,os,pathlib,re,tarfile,urllib.request
sha=os.environ['SOURCE_SHA'];assert re.fullmatch('[0-9a-f]{40}',sha)
url='https://codeload.github.com/loveliiivelaugh/solidcraft-maintained/tar.gz/'+sha
with urllib.request.urlopen(url,timeout=90) as r:data=r.read(192*1024*1024+1)
assert len(data)<=192*1024*1024
root=pathlib.Path('/var/lib/solidcraft/source');root.mkdir(parents=True,exist_ok=True)
with tarfile.open(fileobj=io.BytesIO(data),mode='r:gz') as archive:
 total=0
 for entry in archive:
  parts=pathlib.PurePosixPath(entry.name).parts
  assert parts and '..' not in parts and not entry.name.startswith('/')
  if not entry.isfile():continue
  assert entry.size<=32*1024*1024
  total+=entry.size;assert total<=512*1024*1024
  dest=root.joinpath(*parts[1:]);dest.parent.mkdir(parents=True,exist_ok=True)
  with dest.open('wb') as output:output.write(archive.extractfile(entry).read())
  dest.chmod(0o755 if entry.mode&0o111 else 0o644)
print(json.dumps({'source_commit':sha,'source_archive_sha256':hashlib.sha256(data).hexdigest(),'expanded_bytes':total}))
