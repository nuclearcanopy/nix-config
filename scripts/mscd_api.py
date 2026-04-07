#!/usr/bin/env python3

from flask import Flask, request, jsonify, Response
import subprocess
import hashlib
import hmac
import os
import json
import select

app = Flask(__name__)

API_HASH = os.environ.get("MSCD_API_HASH", "").strip()

def is_valid_url(url):
    return url.startswith(('http://', 'https://')) or 'youtube.com' in url or 'music.youtube.com' in url

def hash_value(value):
    return hashlib.sha512(value.encode()).hexdigest()

def auth_ok(token):
    if not API_HASH:
        return False
    return hmac.compare_digest(hash_value(token), API_HASH)

@app.route('/download', methods=['POST'])
def download_music():
    auth = request.headers.get('Authorization')
    if not auth_ok(auth or ""):
        return jsonify({'error': 'Unauthorized'}), 401

    data = request.json if request.json else {}
    url = data.get('url') or request.form.get('url')
    command = data.get('command') or request.form.get('command') or 'mscd'
    force = data.get('force') == True or request.form.get('force') == 'true'

    if not url:
        return jsonify({'error': 'Missing URL'}), 400

    if not is_valid_url(url):
        return jsonify({'error': 'Invalid URL'}), 400

    if command not in ['mscd', 'mscd_add', 'mscd_add_a']:
        return jsonify({'error': 'Invalid command'}), 400

    zsh_path = '/run/current-system/sw/bin/zsh'
    if command == 'mscd':
        cmd = [zsh_path, '-c', f'source /etc/nixos/mscd.zsh && mscd "{url}"']
    elif command == 'mscd_add':
        if force:
            cmd = [zsh_path, '-c', f'source /etc/nixos/mscd.zsh && mscd_add --force "{url}"']
        else:
            cmd = [zsh_path, '-c', f'source /etc/nixos/mscd.zsh && mscd_add "{url}"']
    elif command == 'mscd_add_a':
        if force:
            cmd = [zsh_path, '-c', f'source /etc/nixos/mscd.zsh && mscd_add -a --force "{url}"']
        else:
            cmd = [zsh_path, '-c', f'source /etc/nixos/mscd.zsh && mscd_add -a "{url}"']

    def generate():
        yield f"data: {json.dumps({'type': 'start', 'command': command, 'url': url})}\n\n"

        try:
            process = subprocess.Popen(
                cmd,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                text=True,
                bufsize=1
            )

            while True:
                reads = [process.stdout, process.stderr]
                readable, _, _ = select.select(reads, [], [], 0.1)

                for stream in readable:
                    line = stream.readline()
                    if line:
                        stream_type = 'stdout' if stream == process.stdout else 'stderr'
                        yield f"data: {json.dumps({'type': 'output', 'stream': stream_type, 'line': line.rstrip()})}\n\n"

                if process.poll() is not None:
                    for line in process.stdout:
                        yield f"data: {json.dumps({'type': 'output', 'stream': 'stdout', 'line': line.rstrip()})}\n\n"
                    for line in process.stderr:
                        yield f"data: {json.dumps({'type': 'output', 'stream': 'stderr', 'line': line.rstrip()})}\n\n"
                    break

            exit_code = process.returncode
            yield f"data: {json.dumps({'type': 'complete', 'exit_code': exit_code})}\n\n"

        except Exception as e:
            yield f"data: {json.dumps({'type': 'error', 'message': str(e)})}\n\n"

    return Response(generate(), mimetype='text/event-stream', headers={
        'Cache-Control': 'no-cache',
        'X-Accel-Buffering': 'no'
    })

@app.route('/health', methods=['GET'])
def health():
    return jsonify({'status': 'ok'}), 200

@app.route('/', methods=['GET'])
def index():
    return '''<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>MSCD</title>
<style>
*{box-sizing:border-box;margin:0;padding:0}
:root{--bg:#0a0a0f;--surface:#12121a;--border:#1e1e2e;--cyan:#00fff2;--magenta:#ff00ff;--green:#00ff88;--red:#ff3366;--text:#e0e0e0;--dim:#666680}
html{font-size:16px}
body{font-family:'SF Mono','Fira Code','JetBrains Mono',Consolas,monospace;background:var(--bg);color:var(--text);min-height:100vh;min-height:100dvh;padding:12px;padding-top:max(12px,env(safe-area-inset-top));padding-bottom:max(12px,env(safe-area-inset-bottom))}
.container{width:100%;max-width:500px;margin:0 auto}
.header{text-align:center;margin-bottom:20px}
.logo{font-size:2rem;font-weight:700;background:linear-gradient(135deg,var(--cyan),var(--magenta));-webkit-background-clip:text;-webkit-text-fill-color:transparent;background-clip:text;letter-spacing:3px}
.tagline{color:var(--dim);font-size:0.65rem;margin-top:4px;letter-spacing:1px;text-transform:uppercase}
.card{background:var(--surface);border:1px solid var(--border);border-radius:12px;padding:16px;position:relative;overflow:hidden}
.card::before{content:'';position:absolute;top:0;left:0;right:0;height:2px;background:linear-gradient(90deg,var(--cyan),var(--magenta),var(--cyan));opacity:0.7}
.form-group{margin-bottom:14px}
label{display:block;font-size:0.7rem;color:var(--cyan);text-transform:uppercase;letter-spacing:1px;margin-bottom:6px}
input,select{width:100%;padding:14px 12px;background:var(--bg);border:1px solid var(--border);border-radius:8px;color:var(--text);font-family:inherit;font-size:16px;transition:border-color 0.2s,box-shadow 0.2s;-webkit-appearance:none}
input:focus,select:focus{outline:none;border-color:var(--cyan);box-shadow:0 0 0 3px rgba(0,255,242,0.15)}
input::placeholder{color:var(--dim)}
select{cursor:pointer;background-image:url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' width='12' height='12' viewBox='0 0 12 12'%3E%3Cpath fill='%2300fff2' d='M6 8L1 3h10z'/%3E%3C/svg%3E");background-repeat:no-repeat;background-position:right 14px center}
select option{background:var(--bg);color:var(--text)}
.checkbox-group{display:flex;align-items:center;gap:12px;margin:16px 0;min-height:44px}
.checkbox-group input[type="checkbox"]{width:24px;height:24px;accent-color:var(--magenta);cursor:pointer;flex-shrink:0}
.checkbox-group label{margin:0;font-size:0.85rem;color:var(--text);text-transform:none;letter-spacing:0;cursor:pointer;-webkit-tap-highlight-color:transparent}
.btn{width:100%;padding:16px;background:var(--cyan);border:none;color:var(--bg);font-family:inherit;font-size:1rem;font-weight:700;text-transform:uppercase;letter-spacing:2px;cursor:pointer;border-radius:8px;transition:all 0.2s;-webkit-tap-highlight-color:transparent;touch-action:manipulation}
.btn:active{transform:scale(0.98);opacity:0.9}
.btn:disabled{opacity:0.4;cursor:not-allowed;transform:none}
.btn.running{background:transparent;border:2px solid var(--magenta);color:var(--magenta);animation:pulse 1.5s infinite}
@keyframes pulse{0%,100%{box-shadow:0 0 0 0 rgba(255,0,255,0.5)}50%{box-shadow:0 0 15px 3px rgba(255,0,255,0.3)}}
.progress-container{margin-top:16px;display:none}
.progress-container.active{display:block}
.progress-bar{height:4px;background:var(--border);border-radius:2px;overflow:hidden;margin-bottom:12px}
.progress-fill{height:100%;width:0;background:linear-gradient(90deg,var(--cyan),var(--magenta));transition:width 0.3s}
.progress-fill.indeterminate{width:30%;animation:indeterminate 1.2s infinite ease-in-out}
@keyframes indeterminate{0%{transform:translateX(-100%)}100%{transform:translateX(400%)}}
.progress-fill.complete{width:100%;background:var(--green)}
.progress-fill.error{width:100%;background:var(--red)}
.console{background:var(--bg);border:1px solid var(--border);border-radius:8px;padding:12px;max-height:40vh;overflow-y:auto;font-size:0.75rem;line-height:1.5;-webkit-overflow-scrolling:touch}
.console-line{white-space:pre-wrap;word-break:break-word;padding:2px 0}
.console-line.stderr{color:var(--red)}
.console-line.info{color:var(--cyan)}
.console-line.success{color:var(--green)}
.console-line.error{color:var(--red);font-weight:600}
.status{display:flex;align-items:center;gap:8px;margin-bottom:10px;font-size:0.75rem}
.status-dot{width:10px;height:10px;border-radius:50%;background:var(--dim);flex-shrink:0}
.status-dot.running{background:var(--magenta);animation:blink 1s infinite}
.status-dot.complete{background:var(--green)}
.status-dot.error{background:var(--red)}
@keyframes blink{0%,100%{opacity:1}50%{opacity:0.3}}
.status-text{color:var(--dim);text-transform:uppercase;letter-spacing:1px}
.cmd-hint{display:flex;gap:8px;margin-bottom:16px;flex-wrap:wrap}
.cmd-tag{font-size:0.65rem;padding:6px 10px;background:var(--bg);border:1px solid var(--border);border-radius:6px;color:var(--dim)}
.cmd-tag code{color:var(--cyan)}
@media(max-width:380px){.cmd-hint{gap:6px}.cmd-tag{padding:5px 8px;font-size:0.6rem}}
</style>
</head>
<body>
<div class="container">
<div class="header">
<div class="logo">MSCD</div>
<div class="tagline">Music Stream Command Downloader</div>
</div>
<div class="card">
<div class="cmd-hint">
<span class="cmd-tag"><code>mscd</code> direct</span>
<span class="cmd-tag"><code>mscd_add</code> queue</span>
<span class="cmd-tag"><code>mscd_add -a</code> alexandra</span>
</div>
<form id="form">
<div class="form-group">
<label>Password</label>
<input type="password" id="password" placeholder="••••••••" required autocomplete="current-password">
</div>
<div class="form-group">
<label>Command</label>
<select id="command">
<option value="mscd">mscd</option>
<option value="mscd_add">mscd_add</option>
<option value="mscd_add_a">mscd_add -a</option>
</select>
</div>
<div class="form-group">
<label>URL</label>
<input type="text" id="url" placeholder="https://music.youtube.com/watch?v=..." required>
</div>
<div class="checkbox-group">
<input type="checkbox" id="force">
<label for="force">--force (re-download existing)</label>
</div>
<button type="submit" id="btn" class="btn">Execute</button>
</form>
<div class="progress-container" id="progress">
<div class="status">
<div class="status-dot" id="statusDot"></div>
<span class="status-text" id="statusText">Initializing...</span>
</div>
<div class="progress-bar">
<div class="progress-fill" id="progressFill"></div>
</div>
<div class="console" id="console"></div>
</div>
</div>
</div>
<script>
const form=document.getElementById('form');
const btn=document.getElementById('btn');
const progress=document.getElementById('progress');
const console_=document.getElementById('console');
const statusDot=document.getElementById('statusDot');
const statusText=document.getElementById('statusText');
const progressFill=document.getElementById('progressFill');
let running=false;

function log(text,type=''){
const line=document.createElement('div');
line.className='console-line'+(type?' '+type:'');
line.textContent=text;
console_.appendChild(line);
console_.scrollTop=console_.scrollHeight;
}

function setStatus(text,state){
statusText.textContent=text;
statusDot.className='status-dot '+state;
progressFill.className='progress-fill '+(state==='running'?'indeterminate':state);
}

form.onsubmit=async(e)=>{
e.preventDefault();
if(running)return;

const password=document.getElementById('password').value;
const command=document.getElementById('command').value;
const url=document.getElementById('url').value;
const force=document.getElementById('force').checked;

running=true;
btn.disabled=true;
btn.className='btn running';
btn.textContent='Running...';
progress.className='progress-container active';
console_.innerHTML='';
setStatus('Connecting...','running');

try{
const response=await fetch('/download',{
method:'POST',
headers:{'Authorization':password,'Content-Type':'application/json'},
body:JSON.stringify({command,url,force})
});

if(!response.ok){
const err=await response.json();
throw new Error(err.error||'Request failed');
}

const reader=response.body.getReader();
const decoder=new TextDecoder();
let buffer='';

while(true){
const{done,value}=await reader.read();
if(done)break;

buffer+=decoder.decode(value,{stream:true});
const lines=buffer.split('\\n\\n');
buffer=lines.pop()||'';

for(const line of lines){
if(!line.startsWith('data: '))continue;
try{
const data=JSON.parse(line.slice(6));
if(data.type==='start'){
log(`> ${data.command} "${data.url}"`,'info');
setStatus('Downloading...','running');
}else if(data.type==='output'){
log(data.line,data.stream==='stderr'?'stderr':'');
}else if(data.type==='complete'){
if(data.exit_code===0){
setStatus('Complete','complete');
log('\\n✓ Download complete','success');
document.getElementById('url').value='';
}else{
setStatus('Failed','error');
log(`\\n✗ Exit code: ${data.exit_code}`,'error');
}
}else if(data.type==='error'){
setStatus('Error','error');
log(`\\n✗ ${data.message}`,'error');
}
}catch(parseErr){}
}
}
}catch(err){
setStatus('Error','error');
log(`✗ ${err.message}`,'error');
}finally{
running=false;
btn.disabled=false;
btn.className='btn';
btn.textContent='Execute';
}
};
</script>
</body>
</html>'''

if __name__ == '__main__':
    print("Starting MSCD API on http://0.0.0.0:8090")
    app.run(host='0.0.0.0', port=8090, debug=False, threaded=True)
