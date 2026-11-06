import subprocess as sp, json, time, pathlib, statistics
root='/home/ihti/Projects/poly-shell'
base=['quickshell','ipc','--path',root+'/shell','call']
def ipc(target, method, *args):
    out=sp.check_output(base+[target,method,*args],text=True,timeout=5).strip()
    return json.loads(out) if out else None
def config(code):
    out=sp.check_output(['hyprctl','eval',code],text=True,timeout=5).strip()
    if out!='ok': raise RuntimeError(out)
def gpu():
    total=0; seen=set()
    for fd in pathlib.Path('/proc/6336/fdinfo').glob('*'):
        import re
        try:
            m=re.search(r'drm-engine-gfx:\s*(\d+) ns',fd.read_text())
            if m:
                client=re.search(r'drm-client-id:\s*(\d+)',fd.read_text())
                if client and client[1] not in seen: total+=int(m[1]); seen.add(client[1])
        except OSError: pass
    return total
modes=[('glass-original','hl.config({render={new_render_scheduling=true},decoration={active_opacity=0.94,inactive_opacity=0.96,blur={enabled=true,passes=2}}})'),('glass-blur-off','hl.config({render={new_render_scheduling=true},decoration={active_opacity=0.94,inactive_opacity=0.96,blur={enabled=false,passes=2}}})')]
results=[]
try:
    for name,code in modes:
        config(code); time.sleep(.5)
        for page,target in [('launcher','launcher-eDP-1'),('calendar','bar-popup-eDP-1'),('quick-settings','quick-settings-eDP-1')]:
            gaps=[]; start=time.monotonic(); before=gpu()
            for _ in range(3):
                ipc(target,'startMotionTrace')
                ipc('shell','toggleQuickSettings') if page=='quick-settings' else ipc('shell','toggleBarPanel',page)
                time.sleep(.55)
                trace=ipc(target,'stopMotionTrace')
                moving=[f for f in trace if 0<f['progress']<1]
                gaps.extend(b['ms']-a['ms'] for a,b in zip(moving,moving[1:]))
                ipc('shell','closeQuickSettings' if page=='quick-settings' else 'closeBarPanel');time.sleep(.3)
            duration=time.monotonic()-start; after=gpu(); gaps.sort()
            r=dict(mode=name,page=page,frames=len(gaps),p95=gaps[int((len(gaps)-1)*.95)] if gaps else None,max=max(gaps,default=0),over25=sum(x>25 for x in gaps),hyprGpu=round((after-before)/duration/1e7,2))
            results.append(r); print(json.dumps(r),flush=True)
finally:
    ipc('shell','closeBarPanel');ipc('shell','closeQuickSettings');config(modes[0][1])
    pathlib.Path('/tmp/poly-lag-blur.json').write_text(json.dumps(results,indent=2))  # NOSONAR
