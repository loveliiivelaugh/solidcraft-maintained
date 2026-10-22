import hashlib,io,json,os,pathlib,re,tarfile,urllib.request,subprocess
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

# Preserve real commit identity without checking out source or running Git hooks/filters.
# The bounded archive above remains the only materialized working-tree input.
env={'PATH':'/usr/bin:/bin','HOME':'/var/lib/solidcraft/home','GIT_CONFIG_NOSYSTEM':'1','GIT_CONFIG_GLOBAL':'/dev/null','GIT_TERMINAL_PROMPT':'0'}
def git(*args):
 return subprocess.check_output(['git','-c','core.hooksPath=/dev/null','-c','core.fsmonitor=false','-c','credential.helper=','-c','protocol.file.allow=never','-C',str(root),*args],env=env,text=True).strip()
git('init','--template=')
git('config','core.hooksPath','/dev/null');git('config','core.fsmonitor','false');git('config','credential.helper','')
git('remote','add','origin','https://github.com/loveliiivelaugh/solidcraft-maintained.git')
git('fetch','--filter=blob:none','--depth=1','--no-tags','origin',sha)
git('update-ref','HEAD',sha);git('read-tree',sha)
assert git('rev-parse','HEAD')==sha
print(json.dumps({'git_source_commit':sha,'git_checkout_executed':False,'hooks_disabled':True}))
