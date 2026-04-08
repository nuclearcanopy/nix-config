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
:root{--bg:#000;--surface:#0a0a0a;--border:#1a1a1a;--accent:#fff;--accent-dim:#888;--success:#ccc;--error:#666;--text:#e0e0e0;--dim:#555}
html{font-size:16px}
body{font-family:'SF Mono','Fira Code','JetBrains Mono',Consolas,monospace;background:var(--bg);color:var(--text);min-height:100vh;min-height:100dvh;padding:12px;padding-top:max(12px,env(safe-area-inset-top));padding-bottom:max(12px,env(safe-area-inset-bottom))}
.container{width:100%;max-width:500px;margin:0 auto}
.header{text-align:center;margin-bottom:20px}
.logo{font-size:2rem;font-weight:700;color:var(--accent);letter-spacing:3px}
.tagline{color:var(--dim);font-size:0.65rem;margin-top:4px;letter-spacing:1px;text-transform:uppercase}
.card{background:var(--surface);border:1px solid var(--border);border-radius:12px;padding:16px;position:relative;overflow:hidden}
.card::before{content:'';position:absolute;top:0;left:0;right:0;height:1px;background:linear-gradient(90deg,transparent,var(--accent),transparent);opacity:0.5}
.form-group{margin-bottom:14px}
label{display:block;font-size:0.7rem;color:var(--accent-dim);text-transform:uppercase;letter-spacing:1px;margin-bottom:6px}
input,select{width:100%;padding:14px 12px;background:var(--bg);border:1px solid var(--border);border-radius:8px;color:var(--text);font-family:inherit;font-size:16px;transition:border-color 0.2s,box-shadow 0.2s;-webkit-appearance:none}
input:focus,select:focus{outline:none;border-color:var(--accent);box-shadow:0 0 0 3px rgba(255,255,255,0.1)}
input::placeholder{color:var(--dim)}
select{cursor:pointer;background-image:url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' width='12' height='12' viewBox='0 0 12 12'%3E%3Cpath fill='%23888' d='M6 8L1 3h10z'/%3E%3C/svg%3E");background-repeat:no-repeat;background-position:right 14px center}
select option{background:var(--bg);color:var(--text)}
.checkbox-group{display:flex;align-items:center;gap:12px;margin:16px 0;min-height:44px}
.checkbox-group input[type="checkbox"]{width:24px;height:24px;accent-color:var(--accent);cursor:pointer;flex-shrink:0}
.checkbox-group label{margin:0;font-size:0.85rem;color:var(--text);text-transform:none;letter-spacing:0;cursor:pointer;-webkit-tap-highlight-color:transparent}
.btn{width:100%;padding:16px;background:var(--accent);border:none;color:var(--bg);font-family:inherit;font-size:1rem;font-weight:700;text-transform:uppercase;letter-spacing:2px;cursor:pointer;border-radius:8px;transition:all 0.2s;-webkit-tap-highlight-color:transparent;touch-action:manipulation}
.btn:active{transform:scale(0.98);opacity:0.9}
.btn:disabled{opacity:0.4;cursor:not-allowed;transform:none}
.btn.running{background:transparent;border:2px solid var(--accent-dim);color:var(--accent-dim);animation:pulse 1.5s infinite}
@keyframes pulse{0%,100%{box-shadow:0 0 0 0 rgba(255,255,255,0.3)}50%{box-shadow:0 0 15px 3px rgba(255,255,255,0.15)}}
.progress-container{margin-top:16px;display:none}
.progress-container.active{display:block}
.progress-bar{height:28px;background:var(--border);border-radius:6px;overflow:hidden;margin-bottom:12px;position:relative;animation:bar-breathe 3s ease-in-out infinite}
@keyframes bar-breathe{0%,100%{background:var(--border)}50%{background:#1f1f1f}}
.progress-fill{height:100%;width:0;background:linear-gradient(90deg,var(--accent) 0%,var(--accent) 100%);position:relative;transition:none}
.progress-fill::after{content:'';position:absolute;top:0;left:0;right:0;bottom:0;background:linear-gradient(90deg,transparent 0%,rgba(255,255,255,0.15) 50%,transparent 100%);animation:shimmer 2s infinite;background-size:200% 100%}
@keyframes shimmer{0%{background-position:200% 0}100%{background-position:-200% 0}}
.progress-fill.complete{background:var(--success)}
.progress-fill.complete::after{animation:none;background:none}
.progress-fill.error{background:var(--error)}
.progress-fill.error::after{animation:none;background:none}
.progress-counter{position:absolute;top:0;left:0;right:0;bottom:0;display:flex;align-items:center;justify-content:center;font-size:1rem;font-weight:700;color:var(--accent);mix-blend-mode:difference;pointer-events:none;letter-spacing:2px;font-variant-numeric:tabular-nums;transition:opacity 0.3s ease}
.progress-pct{font-size:0.7rem;color:var(--accent-dim);text-align:right;margin-top:4px;font-variant-numeric:tabular-nums}
.console{background:var(--bg);border:1px solid var(--border);border-radius:8px;padding:12px;max-height:40vh;overflow-y:auto;font-size:0.75rem;line-height:1.5;-webkit-overflow-scrolling:touch}
.console-line{white-space:pre-wrap;word-break:break-word;padding:2px 0}
.console-line.stderr{color:var(--error)}
.console-line.info{color:var(--accent-dim)}
.console-line.success{color:var(--success)}
.console-line.error{color:var(--error);font-weight:600}
.status{display:flex;align-items:center;gap:8px;margin-bottom:10px;font-size:0.75rem}
.status-dot{width:10px;height:10px;border-radius:50%;background:var(--dim);flex-shrink:0;transition:all 0.3s ease}
.status-dot.running{background:var(--accent);animation:pulse-glow 1.5s ease-in-out infinite}
.status-dot.complete{background:var(--success);box-shadow:0 0 8px var(--success)}
.status-dot.error{background:var(--error);box-shadow:0 0 8px var(--error)}
@keyframes pulse-glow{0%,100%{opacity:1;box-shadow:0 0 4px var(--accent)}50%{opacity:0.7;box-shadow:0 0 12px var(--accent)}}
.status-text{transition:opacity 0.2s ease}
.status-text{color:var(--dim);text-transform:uppercase;letter-spacing:1px}
.cmd-hint{display:flex;gap:8px;margin-bottom:16px;flex-wrap:wrap}
.cmd-tag{font-size:0.65rem;padding:6px 10px;background:var(--bg);border:1px solid var(--border);border-radius:6px;color:var(--dim)}
.cmd-tag code{color:var(--accent)}
@media(max-width:380px){.cmd-hint{gap:6px}.cmd-tag{padding:5px 8px;font-size:0.6rem}}
.batch-toggle{display:flex;align-items:center;justify-content:space-between;margin-bottom:6px}
.batch-toggle label{margin:0}
.toggle-btn{background:var(--bg);border:1px solid var(--border);color:var(--dim);padding:6px 12px;border-radius:6px;font-family:inherit;font-size:0.7rem;cursor:pointer;text-transform:uppercase;letter-spacing:1px;transition:all 0.2s}
.toggle-btn.active{background:var(--accent);color:var(--bg);border-color:var(--accent)}
.url-single{display:block}
.url-single.hidden{display:none}
.url-batch{display:none;flex-direction:column;gap:8px}
.url-batch.active{display:flex}
.url-row{display:flex;gap:8px;align-items:center}
.url-row input{flex:1}
.url-row-btn{width:44px;height:44px;border:1px solid var(--border);background:var(--bg);color:var(--dim);border-radius:8px;font-size:1.2rem;cursor:pointer;transition:all 0.2s;flex-shrink:0}
.url-row-btn:hover{border-color:var(--accent);color:var(--accent)}
.url-row-btn.add{color:var(--accent)}
.url-row-btn.remove:hover{border-color:var(--error);color:var(--error)}
.batch-counter{font-size:0.7rem;color:var(--dim);text-align:center;margin-top:8px}
.batch-progress{font-size:0.75rem;color:var(--accent-dim);margin-bottom:8px;text-align:center}
.modal-overlay{position:fixed;top:0;left:0;right:0;bottom:0;background:rgba(0,0,0,0.85);display:none;align-items:center;justify-content:center;z-index:1000;padding:20px;backdrop-filter:blur(4px)}
.modal-overlay.active{display:flex}
.modal{background:var(--surface);border:1px solid var(--border);border-radius:12px;padding:20px;max-width:380px;width:100%;position:relative;animation:modalIn 0.2s ease-out}
@keyframes modalIn{from{opacity:0;transform:scale(0.95)}to{opacity:1;transform:scale(1)}}
.modal::before{content:'';position:absolute;top:0;left:0;right:0;height:1px;background:linear-gradient(90deg,transparent,var(--accent),transparent);border-radius:12px 12px 0 0}
.modal-icon{font-size:2rem;text-align:center;margin-bottom:12px}
.modal-title{font-size:1rem;font-weight:700;text-align:center;margin-bottom:8px;color:var(--text)}
.modal-msg{font-size:0.8rem;color:var(--dim);text-align:center;margin-bottom:16px;line-height:1.5}
.modal-file{font-size:0.7rem;color:var(--accent-dim);background:var(--bg);padding:10px;border-radius:6px;margin-bottom:16px;word-break:break-all;text-align:center}
.modal-btns{display:flex;gap:10px}
.modal-btn{flex:1;padding:14px;border:none;border-radius:8px;font-family:inherit;font-size:0.85rem;font-weight:600;cursor:pointer;transition:all 0.2s;text-transform:uppercase;letter-spacing:1px}
.modal-btn.yes{background:var(--accent);color:var(--bg)}
.modal-btn.yes:active{background:var(--accent-dim)}
.modal-btn.no{background:var(--bg);border:1px solid var(--border);color:var(--dim)}
.modal-btn.no:active{background:var(--border)}
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
<div class="batch-toggle">
<label>URL</label>
<button type="button" class="toggle-btn" id="batchToggle">Batch</button>
</div>
<div class="url-single" id="urlSingle">
<input type="text" id="url" placeholder="https://music.youtube.com/watch?v=...">
</div>
<div class="url-batch" id="urlBatch">
<div class="url-row">
<input type="text" class="batch-url" placeholder="https://music.youtube.com/watch?v=...">
<button type="button" class="url-row-btn add" onclick="addUrlRow()">+</button>
</div>
</div>
<div class="batch-counter" id="batchCounter"></div>
</div>
<div class="checkbox-group">
<input type="checkbox" id="force">
<label for="force">--force (re-download existing)</label>
</div>
<button type="submit" id="btn" class="btn">Execute</button>
</form>
<div class="progress-container" id="progress">
<div class="batch-progress" id="batchProgress"></div>
<div class="status">
<div class="status-dot" id="statusDot"></div>
<span class="status-text" id="statusText">Initializing...</span>
</div>
<div class="progress-bar">
<div class="progress-fill" id="progressFill"></div>
<div class="progress-counter" id="progressCounter"></div>
</div>
<div class="progress-pct" id="progressPct"></div>
<div class="console" id="console"></div>
</div>
</div>
</div>
<div class="modal-overlay" id="dupeModal">
<div class="modal">
<div class="modal-icon">⚠️</div>
<div class="modal-title">File Already Exists</div>
<div class="modal-msg">This track has already been downloaded. Re-download with a new filename?</div>
<div class="modal-file" id="dupeFile"></div>
<div class="modal-btns">
<button class="modal-btn no" id="dupeNo">Skip</button>
<button class="modal-btn yes" id="dupeYes">Re-download</button>
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
const progressPct=document.getElementById('progressPct');
const progressCounter=document.getElementById('progressCounter');
const dupeModal=document.getElementById('dupeModal');
const dupeFile=document.getElementById('dupeFile');
const dupeYes=document.getElementById('dupeYes');
const dupeNo=document.getElementById('dupeNo');
const batchToggle=document.getElementById('batchToggle');
const urlSingle=document.getElementById('urlSingle');
const urlBatch=document.getElementById('urlBatch');
const batchCounter=document.getElementById('batchCounter');
const batchProgress=document.getElementById('batchProgress');
let running=false;
let currentPct=0;
let currentParams=null;
let dupeResolver=null;
let batchMode=false;
let totalItems=1;
let currentItemIndex=0;
let itemSource=''; // 'batch' or 'playlist'

// Smooth progress tracking
let displayedPct=0;
let targetPct=0;
let songStartTime=0;
let lastSongDurations=[];
let estimatedSongDuration=30000; // default 30s estimate
let animationFrame=null;
let lastActivityTime=0;
let isIndeterminate=false;
let indeterminateStartPct=0;

function updateProgressCounter(){
if(totalItems>1){
progressCounter.textContent=`${currentItemIndex+1} / ${totalItems}`;
}else{
progressCounter.textContent=`${Math.round(displayedPct)}%`;
}
}

function startProgressAnimation(){
if(animationFrame)return;
let lastFrameTime=performance.now();
function animate(currentTime){
const deltaTime=(currentTime-lastFrameTime)/16.67; // Normalize to ~60fps
lastFrameTime=currentTime;
const now=Date.now();
if(isIndeterminate){
// During indeterminate phases, slowly creep forward based on estimated time
const elapsed=now-lastActivityTime;
const songBaseStart=(currentItemIndex*100)/totalItems;
const songBaseEnd=((currentItemIndex+1)*100)/totalItems;
const songRange=songBaseEnd-songBaseStart;
// Smoothly creep forward with easing
const indeterminateProgress=Math.min(0.5,elapsed/estimatedSongDuration);
// Use easeOutQuad for natural feel
const eased=1-(1-indeterminateProgress)*(1-indeterminateProgress);
const estimatedPct=indeterminateStartPct+(songRange*eased*0.5);
targetPct=Math.min(estimatedPct,songBaseEnd-2);
}
// Smooth exponential interpolation toward target
const diff=targetPct-displayedPct;
if(Math.abs(diff)>0.01){
// Use exponential easing - always smooth, never snappy
// Lerp factor scales with deltaTime for consistent speed regardless of framerate
const lerpFactor=1-Math.pow(0.85,deltaTime);
displayedPct+=(diff*lerpFactor);
// Clamp very small movements
if(Math.abs(targetPct-displayedPct)<0.01)displayedPct=targetPct;
}else{
displayedPct=targetPct;
}
progressFill.style.width=displayedPct+'%';
updateProgressCounter();
if(running){
animationFrame=requestAnimationFrame(animate);
}else{
animationFrame=null;
}
}
animationFrame=requestAnimationFrame(animate);
}

function stopProgressAnimation(){
if(animationFrame){
cancelAnimationFrame(animationFrame);
animationFrame=null;
}
}

function recordSongComplete(){
if(songStartTime>0){
const duration=Date.now()-songStartTime;
lastSongDurations.push(duration);
if(lastSongDurations.length>5)lastSongDurations.shift();
estimatedSongDuration=lastSongDurations.reduce((a,b)=>a+b,0)/lastSongDurations.length;
}
songStartTime=Date.now();
}

// Small progress bump for processing steps (makes bar feel responsive)
function bumpProgress(amount){
const songBaseEnd=((currentItemIndex+1)*100)/totalItems;
// Don't bump past 95% of current song's range
const maxBump=songBaseEnd-5;
if(targetPct<maxBump){
targetPct=Math.min(targetPct+amount,maxBump);
isIndeterminate=false;
}
lastActivityTime=Date.now();
}

function updateBatchCounter(){
const urls=getUrls();
const count=urls.length;
batchCounter.textContent=count>0?`${count} URL${count>1?'s':''} queued`:'';
}

function toggleBatchMode(){
batchMode=!batchMode;
batchToggle.className='toggle-btn'+(batchMode?' active':'');
urlSingle.className='url-single'+(batchMode?' hidden':'');
urlBatch.className='url-batch'+(batchMode?' active':'');
if(batchMode){
const singleUrl=document.getElementById('url').value;
const firstBatch=urlBatch.querySelector('.batch-url');
if(firstBatch&&singleUrl)firstBatch.value=singleUrl;
}else{
const firstBatch=urlBatch.querySelector('.batch-url');
if(firstBatch)document.getElementById('url').value=firstBatch.value;
}
updateBatchCounter();
}

batchToggle.onclick=toggleBatchMode;

function addUrlRow(){
const row=document.createElement('div');
row.className='url-row';
row.innerHTML=`<input type="text" class="batch-url" placeholder="https://music.youtube.com/watch?v=..."><button type="button" class="url-row-btn remove" onclick="removeUrlRow(this)">−</button>`;
urlBatch.appendChild(row);
row.querySelector('input').focus();
updateBatchCounter();
}

function removeUrlRow(btn){
const rows=urlBatch.querySelectorAll('.url-row');
if(rows.length>1){
btn.parentElement.remove();
updateBatchCounter();
}
}

function getUrls(){
if(!batchMode){
const url=document.getElementById('url').value.trim();
return url?[url]:[];
}
const urls=[];
urlBatch.querySelectorAll('.batch-url').forEach(input=>{
const url=input.value.trim();
if(url)urls.push(url);
});
return urls;
}

urlBatch.addEventListener('input',updateBatchCounter);

function log(text,type=''){
const line=document.createElement('div');
line.className='console-line'+(type?' '+type:'');
line.textContent=text;
console_.appendChild(line);
console_.scrollTop=console_.scrollHeight;
}

function setProgress(pct,info=''){
currentPct=Math.max(currentPct,pct);
let totalPct=currentPct;
if(totalItems>1){
totalPct=((currentItemIndex*100)+currentPct)/totalItems;
}
// Use smooth animation instead of direct set
isIndeterminate=false;
targetPct=totalPct;
progressFill.className='progress-fill';
lastActivityTime=Date.now();
// Info goes below the bar, counter is embedded
progressPct.textContent=info||'';
}

function setStatus(text,state){
statusText.textContent=text;
statusDot.className='status-dot '+state;
if(state==='running'&&currentPct===0){
// Don't use CSS indeterminate - use smooth estimation instead
progressFill.className='progress-fill';
updateProgressCounter();
progressPct.textContent='';
}else if(state==='complete'){
isIndeterminate=false;
targetPct=100;
displayedPct=100;
progressFill.className='progress-fill complete';
progressFill.style.width='100%';
if(totalItems>1){
progressCounter.textContent=`${totalItems} / ${totalItems}`;
progressPct.textContent='Complete!';
}else{
progressCounter.textContent='100%';
progressPct.textContent='Complete!';
}
stopProgressAnimation();
}else if(state==='error'){
isIndeterminate=false;
progressFill.className='progress-fill error';
progressCounter.textContent='ERROR';
progressPct.textContent='';
stopProgressAnimation();
}
}

function parseProgress(line){
const match=line.match(/\[download\]\s+(\d+\.?\d*)%\s+of\s+~?(\S+)(?:\s+at\s+(\S+))?(?:\s+ETA\s+(\S+))?/);
if(match){
const pct=parseFloat(match[1]);
const size=match[2]||'';
const speed=match[3]||'';
const eta=match[4]||'';
let info=size;
if(speed)info+=` @ ${speed}`;
if(eta)info+=` ETA ${eta}`;
return{pct,info};
}
const match100=line.match(/\[download\]\s+100%\s+of\s+~?(\S+)/);
if(match100){
return{pct:100,info:match100[1]};
}
return null;
}

function handleOutputLine(line){
const prog=parseProgress(line);
if(prog){
setProgress(prog.pct,prog.info);
statusText.textContent='Downloading audio...';
return;
}
const indeterminate=()=>{
lastActivityTime=Date.now();
if(!isIndeterminate){
isIndeterminate=true;
indeterminateStartPct=displayedPct;
}
progressFill.className='progress-fill';
progressPct.textContent=''; // Counter is embedded, info goes below
};

// yt-dlp update/version checks
if(line.match(/Updating to version/i)||line.match(/yt-dlp is up to date/i)){
statusText.textContent='Checking yt-dlp version...';bumpProgress(0.5);
}else if(line.match(/Current version/i)&&line.match(/yt-dlp/i)){
statusText.textContent='Verifying yt-dlp...';bumpProgress(0.3);
}else if(line.match(/Latest version/i)){
statusText.textContent='Fetching latest yt-dlp...';bumpProgress(0.3);
}else if(line.match(/Downloading yt-dlp/i)||line.match(/updating.*yt-dlp/i)){
statusText.textContent='Downloading yt-dlp update...';bumpProgress(0.5);
}

// Playlist/channel processing
else if(line.match(/^\[youtube:tab\]/i)){
statusText.textContent='Fetching playlist info...';bumpProgress(1);
}else if(line.match(/^\[youtube:playlist\]/i)){
statusText.textContent='Processing playlist...';bumpProgress(0.5);
}else if(line.match(/^\[youtube:search\]/i)){
statusText.textContent='Searching YouTube...';bumpProgress(0.5);
}else if(line.match(/Downloading item (\d+) of (\d+)/i)){
const m=line.match(/Downloading item (\d+) of (\d+)/i);
const itemNum=parseInt(m[1],10);
const itemTotal=parseInt(m[2],10);
if(itemSource!=='batch'){
if(itemNum>1)recordSongComplete(); // Record timing for previous song
totalItems=itemTotal;
currentItemIndex=itemNum-1;
currentPct=0;
itemSource='playlist';
// Smoothly animate to new song start position
const songStartPct=(currentItemIndex*100)/totalItems;
targetPct=songStartPct;
isIndeterminate=false;
}
statusText.textContent=`Fetching track ${m[1]} of ${m[2]}...`;indeterminate();
}

// Player/JS downloads
else if(line.match(/Downloading.*player.*API.*JSON/i)){
statusText.textContent='Fetching player API...';bumpProgress(0.5);
}else if(line.match(/Downloading.*client.*config/i)){
statusText.textContent='Fetching client config...';bumpProgress(0.3);
}else if(line.match(/Downloading.*player/i)){
statusText.textContent='Downloading player JS...';bumpProgress(0.8);
}else if(line.match(/Downloading (android|ios|web|tv)\s/i)){
const m=line.match(/Downloading (android|ios|web|tv)\s/i);
statusText.textContent=`Fetching ${m[1]} client...`;bumpProgress(0.5);
}else if(line.match(/Downloading iframe API/i)){
statusText.textContent='Downloading iframe API...';bumpProgress(0.3);
}else if(line.match(/Downloading js player/i)){
statusText.textContent='Downloading JS player...';bumpProgress(0.5);
}else if(line.match(/Downloading sign/i)||line.match(/signature/i)){
statusText.textContent='Downloading signature...';bumpProgress(0.3);
}else if(line.match(/Downloading initial data/i)){
statusText.textContent='Fetching initial data...';bumpProgress(0.5);
}else if(line.match(/nsig.*decryption/i)){
statusText.textContent='Decrypting nsig...';bumpProgress(0.3);
}

// Webpage/metadata fetching
else if(line.match(/Downloading webpage/i)){
statusText.textContent='Downloading webpage...';bumpProgress(1);
}else if(line.match(/Downloading.*JSON/i)){
statusText.textContent='Fetching JSON data...';bumpProgress(0.8);
}else if(line.match(/Downloading (API|api)/i)){
statusText.textContent='Fetching API data...';bumpProgress(0.5);
}else if(line.match(/Downloading video info/i)){
statusText.textContent='Fetching video info...';bumpProgress(1);
}else if(line.match(/Downloading m3u8/i)){
statusText.textContent='Fetching HLS manifest...';bumpProgress(0.5);
}else if(line.match(/Downloading MPD/i)||line.match(/Downloading DASH/i)){
statusText.textContent='Fetching DASH manifest...';bumpProgress(0.5);
}else if(line.match(/Downloading (formats|format list)/i)){
statusText.textContent='Fetching format list...';bumpProgress(0.5);
}else if(line.match(/Extracting URL/i)){
statusText.textContent='Extracting URL...';bumpProgress(0.3);
}else if(line.match(/Downloading thumbnail/i)){
statusText.textContent='Downloading thumbnail...';bumpProgress(0.5);
}else if(line.match(/Downloading.*po_token/i)){
statusText.textContent='Fetching PO token...';bumpProgress(0.3);
}else if(line.match(/Downloading.*config/i)){
statusText.textContent='Fetching config...';bumpProgress(0.3);
}

// Single video metadata
else if(line.match(/^\[youtube\]\s+[A-Za-z0-9_-]+:\s*Downloading webpage/i)){
statusText.textContent='Fetching video page...';bumpProgress(0.5);
}else if(line.match(/^\[youtube\]\s+[A-Za-z0-9_-]+:\s*Downloading.*player/i)){
statusText.textContent='Fetching player...';bumpProgress(0.3);
}else if(line.match(/^\[youtube\]\s+[A-Za-z0-9_-]+:\s*Downloading.*client config/i)){
statusText.textContent='Fetching config...';bumpProgress(0.2);
}else if(line.match(/^\[youtube\]\s+[A-Za-z0-9_-]+:\s*Downloading.*API JSON/i)){
statusText.textContent='Fetching API data...';bumpProgress(0.3);
}else if(line.match(/^\[youtube\]\s+[A-Za-z0-9_-]+:\s*Downloading/i)){
statusText.textContent='Fetching video data...';bumpProgress(0.3);
}else if(line.match(/^\[youtube\]\s+Extracting URL/i)){
statusText.textContent='Extracting video URL...';bumpProgress(0.3);
}else if(line.match(/^\[youtube\]/i)&&!line.match(/\[youtube:tab\]/i)){
statusText.textContent='Processing video...';bumpProgress(0.2);
}else if(line.match(/^\[youtube:music\]/i)||line.match(/^\[Music\]/i)){
statusText.textContent='Fetching from YouTube Music...';bumpProgress(0.8);
}

// Generic extractors
else if(line.match(/^\[generic\]/i)){
statusText.textContent='Using generic extractor...';bumpProgress(0.3);
}else if(line.match(/^\[redirect\]/i)){
statusText.textContent='Following redirect...';bumpProgress(0.2);
}

// Cookies
else if(line.match(/^\[Cookies\]/i)||line.match(/Loading cookies/i)){
statusText.textContent='Loading cookies...';bumpProgress(0.2);
}

// Download states
else if(line.match(/^\[download\]\s+Destination:/)){
statusText.textContent='Starting download...';
currentPct=0;
setProgress(0,'Starting...');
}else if(line.match(/^\[download\]\s+Resuming download/i)){
statusText.textContent='Resuming download...';bumpProgress(1);
}else if(line.match(/^\[download\]\s+Downloading video/i)){
statusText.textContent='Downloading video stream...';bumpProgress(0.5);
}else if(line.match(/^\[download\]\s+Downloading audio/i)){
statusText.textContent='Downloading audio stream...';bumpProgress(0.5);
}else if(line.match(/^\[download\]\s+Downloading/i)){
statusText.textContent='Preparing download...';bumpProgress(0.5);
}else if(line.match(/^\[download\]\s+has already been downloaded/i)){
statusText.textContent='Already downloaded!';bumpProgress(2);
}else if(line.match(/\[download\]\s+100%/)){
statusText.textContent='Download complete!';
setProgress(100,'Download done');
}

// Post-processing stages
else if(line.match(/^\[ExtractAudio\]/i)){
statusText.textContent='Extracting audio...';
setProgress(100,'Extracting');
}else if(line.match(/^\[Merger\]/i)){
statusText.textContent='Merging streams...';
setProgress(100,'Merging');
}else if(line.match(/^\[ffmpeg\].*Merging/i)){
statusText.textContent='FFmpeg merging...';
setProgress(100,'Merging');
}else if(line.match(/^\[ffmpeg\].*Converting/i)){
statusText.textContent='FFmpeg converting...';
setProgress(100,'Converting');
}else if(line.match(/^\[ffmpeg\].*Correcting/i)){
statusText.textContent='FFmpeg correcting...';
setProgress(100,'Fixing');
}else if(line.match(/^\[ffmpeg\]/i)){
statusText.textContent='Processing with FFmpeg...';
setProgress(100,'Processing');
}

// Thumbnail processing
else if(line.match(/^\[EmbedThumbnail\]/i)){
statusText.textContent='Embedding thumbnail...';
setProgress(100,'Thumbnail');
}else if(line.match(/^\[ThumbnailsConvertor\]/i)){
statusText.textContent='Converting thumbnail...';
setProgress(100,'Thumbnail');
}

// Metadata
else if(line.match(/^\[Metadata\]/i)){
statusText.textContent='Writing metadata...';
setProgress(100,'Metadata');
}else if(line.match(/^\[mutagen\]/i)){
statusText.textContent='Tagging with mutagen...';
setProgress(100,'Tagging');
}else if(line.match(/Writing video metadata/i)){
statusText.textContent='Writing video tags...';
setProgress(100,'Tags');
}else if(line.match(/Writing video subtitles/i)){
statusText.textContent='Writing subtitles...';
setProgress(100,'Subtitles');
}

// Chapters/SponsorBlock
else if(line.match(/^\[SponsorBlock\]/i)||line.match(/^\[Sponsorblock\]/i)){
statusText.textContent='Processing SponsorBlock...';
setProgress(100,'SponsorBlock');
}else if(line.match(/^\[ModifyChapters\]/i)){
statusText.textContent='Modifying chapters...';
setProgress(100,'Chapters');
}else if(line.match(/^\[Chapters\]/i)){
statusText.textContent='Processing chapters...';
setProgress(100,'Chapters');
}else if(line.match(/^\[SplitChapters\]/i)){
statusText.textContent='Splitting chapters...';
setProgress(100,'Splitting');
}

// Fixups
else if(line.match(/^\[FixupM3u8\]/i)){
statusText.textContent='Fixing M3U8...';
setProgress(100,'Fixing');
}else if(line.match(/^\[FixupDuplicateMoov\]/i)){
statusText.textContent='Fixing duplicate moov...';
setProgress(100,'Fixing');
}else if(line.match(/^\[FixupDuration\]/i)){
statusText.textContent='Fixing duration...';
setProgress(100,'Fixing');
}else if(line.match(/^\[Fixup/i)){
statusText.textContent='Fixing file...';
setProgress(100,'Fixing');
}

// File operations
else if(line.match(/^\[MoveFiles\]/i)){
statusText.textContent='Moving files...';
setProgress(100,'Moving');
}else if(line.match(/^Deleting original file/i)){
statusText.textContent='Cleaning up...';
}else if(line.match(/^\[download\]\s+Deleting/i)){
statusText.textContent='Cleaning up temp files...';
setProgress(100,'Cleanup');
}else if(line.match(/Moving to library/i)||line.match(/Moved.*to/i)){
statusText.textContent='Moving to library...';
setProgress(100,'Organizing');
}else if(line.match(/copying thumbnail/i)){
statusText.textContent='Copying thumbnail...';
setProgress(100,'Thumbnail');
}

// Info messages
else if(line.match(/^\[info\].*format/i)){
statusText.textContent='Selecting format...';bumpProgress(0.5);
}else if(line.match(/^\[info\].*download/i)){
statusText.textContent='Preparing download...';bumpProgress(0.3);
}else if(line.match(/^\[info\]\s*Writing.*playlist metadata/i)){
statusText.textContent='Saving playlist data...';bumpProgress(0.3);
}else if(line.match(/^\[info\]/i)){
statusText.textContent='Processing info...';bumpProgress(0.2);
}

// Playlist finished
else if(line.match(/Finished downloading playlist/i)){
const m=line.match(/playlist:\s*(.+)/);
statusText.textContent=m?`Playlist done: ${m[1]}`:'Playlist downloaded!';
setProgress(100,'Organizing files...');
}

// Debug/verbose - parse actual debug content
else if(line.match(/^\[debug\]/i)){
if(line.match(/format selector/i))statusText.textContent='Selecting format...';
else if(line.match(/extractor/i))statusText.textContent='Loading extractor...';
else if(line.match(/cookie/i))statusText.textContent='Processing cookies...';
else if(line.match(/proxy/i))statusText.textContent='Configuring proxy...';
else if(line.match(/header/i))statusText.textContent='Setting headers...';
else if(line.match(/request/i))statusText.textContent='Preparing request...';
else if(line.match(/response/i))statusText.textContent='Processing response...';
else if(line.match(/redirect/i))statusText.textContent='Following redirect...';
else if(line.match(/download/i))statusText.textContent='Preparing download...';
else if(line.match(/auth/i))statusText.textContent='Authenticating...';
else if(line.match(/config/i))statusText.textContent='Loading config...';
else if(line.match(/cache/i))statusText.textContent='Checking cache...';
else statusText.textContent='Initializing...';
indeterminate();
}

// PostProcessor generic
else if(line.match(/^\[PostProcessor\]/i)){
statusText.textContent='Post-processing...';
setProgress(100,'Processing');
}

// Network/retry
else if(line.match(/Retrying/i)||line.match(/retry/i)){
statusText.textContent='Retrying request...';
}else if(line.match(/rate.?limit/i)||line.match(/429/i)){
statusText.textContent='Rate limited, waiting...';
}else if(line.match(/Sleeping/i)||line.match(/sleep/i)){
statusText.textContent='Waiting...';
}else if(line.match(/Throttled/i)){
statusText.textContent='Throttled, waiting...';
}else if(line.match(/timed? ?out/i)){
statusText.textContent='Request timed out...';
}

// Video info display
else if(line.match(/^\[download\]\s+Downloading video \d+ of \d+/i)){
const m=line.match(/Downloading video (\d+) of (\d+)/i);
const itemNum=parseInt(m[1],10);
const itemTotal=parseInt(m[2],10);
if(itemSource!=='batch'){
if(itemNum>1)recordSongComplete();
totalItems=itemTotal;
currentItemIndex=itemNum-1;
currentPct=0;
itemSource='playlist';
const songStartPct=(currentItemIndex*100)/totalItems;
targetPct=songStartPct;
isIndeterminate=false;
}
statusText.textContent=`Fetching video ${m[1]} of ${m[2]}...`;indeterminate();
}else if(line.match(/Available formats/i)){
statusText.textContent='Listing formats...';bumpProgress(0.3);
}else if(line.match(/Requested format/i)){
statusText.textContent='Format selected...';bumpProgress(0.5);
}

// mscd specific
else if(line.match(/Checking for existing/i)){
statusText.textContent='Checking library...';bumpProgress(0.5);
}else if(line.match(/Already exists/i)){
statusText.textContent='Already in library!';bumpProgress(1);
}else if(line.match(/Adding to queue/i)||line.match(/Queued/i)){
statusText.textContent='Adding to queue...';bumpProgress(0.5);
}else if(line.match(/Scanning library/i)){
statusText.textContent='Scanning library...';bumpProgress(0.5);
}else if(line.match(/Updating database/i)){
statusText.textContent='Updating database...';bumpProgress(0.5);
}else if(line.match(/navidrome/i)){
statusText.textContent='Updating Navidrome...';bumpProgress(0.5);
}else if(line.match(/beets/i)&&line.match(/import/i)){
statusText.textContent='Running beets import...';bumpProgress(1);
}else if(line.match(/tagging/i)){
statusText.textContent='Tagging files...';bumpProgress(0.5);
}

// curl progress (yt-dlp update download)
else if(line.match(/^\s*\d+\s+[\d.]+[KMG]?\s+\d+\s+[\d.]+[KMG]?/)||line.match(/% Total.*% Received/)){
statusText.textContent='Updating yt-dlp...';
}

// yt-dlp version/path info
else if(line.match(/^\/.*yt-dlp$/)||line.match(/^\d{4}\.\d{2}\.\d{2}$/)){
statusText.textContent='Checking yt-dlp...';bumpProgress(0.2);
}

// mscd initialization DEBUG messages
else if(line.match(/^\[DEBUG\]\s*Added URL to/i)){
statusText.textContent='URL queued';bumpProgress(0.3);
}else if(line.match(/^\[DEBUG\]\s*Using python/i)){
statusText.textContent='Initializing Python...';bumpProgress(0.2);
}else if(line.match(/^\[DEBUG\]\s*mutagen version/i)){
statusText.textContent='Loading mutagen...';bumpProgress(0.2);
}else if(line.match(/^\[DEBUG\]\s*Starting mscd_album/i)){
statusText.textContent='Starting album download...';bumpProgress(0.5);
}else if(line.match(/^\[DEBUG\]\s*Temporary directory/i)){
statusText.textContent='Creating temp directory...';bumpProgress(0.2);
}

// Playlist extraction
else if(line.match(/Extracting URL/i)){
statusText.textContent='Extracting URL...';bumpProgress(0.3);
}else if(line.match(/Redownloading playlist API/i)){
statusText.textContent='Fetching playlist data...';bumpProgress(0.5);
}else if(line.match(/^\[download\]\s*Downloading playlist:/i)){
const m=line.match(/Downloading playlist:\s*(.+)/);
statusText.textContent=m?`Loading: ${m[1]}`:'Loading playlist...';bumpProgress(0.5);
}else if(line.match(/Playlist.*Downloading \d+ items/i)){
const m=line.match(/Downloading (\d+) items/i);
statusText.textContent=m?`Found ${m[1]} tracks`:'Found tracks';bumpProgress(0.5);
}

// Playlist thumbnails
else if(line.match(/Downloading playlist thumbnail/i)){
statusText.textContent='Fetching playlist art...';bumpProgress(0.3);
}else if(line.match(/Playlist Thumbnail.*does not exist/i)){
statusText.textContent='No playlist art found';
}else if(line.match(/Writing playlist thumbnail/i)){
statusText.textContent='Saving playlist art...';bumpProgress(0.3);
}else if(line.match(/Writing playlist metadata/i)){
statusText.textContent='Saving playlist info...';bumpProgress(0.3);
}

// Warnings
else if(line.match(/^WARNING:/i)){
if(line.match(/YouTube Music is not directly supported/i)){
statusText.textContent='Redirecting to YouTube...';
}else if(line.match(/Download.*failed/i)){
statusText.textContent='Retrying download...';
}else{
statusText.textContent='Warning received...';
}
}

// JS challenges
else if(line.match(/\[jsc:deno\]/i)||line.match(/Solving JS challenges/i)){
statusText.textContent='Solving JS challenge...';bumpProgress(0.5);
}

// Format selection
else if(line.match(/Downloading \d+ format/i)){
const m=line.match(/Downloading (\d+) format/i);
statusText.textContent=m?`Selected ${m[1]} format(s)`:'Format selected';bumpProgress(0.3);
}

// Video thumbnails
else if(line.match(/Downloading video thumbnail/i)){
statusText.textContent='Fetching thumbnail...';bumpProgress(0.3);
}else if(line.match(/Writing video thumbnail/i)){
statusText.textContent='Saving thumbnail...';bumpProgress(0.3);
}else if(line.match(/Writing video metadata/i)){
statusText.textContent='Saving video info...';bumpProgress(0.3);
}

// mscd DEBUG messages (uppercase)
else if(line.match(/^\[DEBUG:resolve_artist\]/)){
if(line.match(/From info\.json/i)){
const m=line.match(/From info\.json:\s*'([^']+)'/);
statusText.textContent=m?`Found: ${m[1]}`:'Resolving artist...';
}else{
statusText.textContent='Resolving artist...';
}
}else if(line.match(/^\[DEBUG\]\s*Resolved album artist/i)){
const m=line.match(/Resolved album artist:\s*(.+)/);
statusText.textContent=m?`Artist: ${m[1]}`:'Artist resolved';bumpProgress(0.3);
}else if(line.match(/^\[DEBUG\]\s*Resolved album name/i)){
const m=line.match(/Resolved album name:\s*(.+)/);
statusText.textContent=m?`Album: ${m[1]}`:'Album resolved';bumpProgress(0.3);
}else if(line.match(/^\[DEBUG\]\s*Resolved album year/i)){
const m=line.match(/Resolved album year:\s*"?(\d+)"?/);
statusText.textContent=m?`Year: ${m[1]}`:'Year resolved';bumpProgress(0.2);
}else if(line.match(/^\[DEBUG\]\s*Album destination/i)){
statusText.textContent='Setting destination...';bumpProgress(0.3);
}else if(line.match(/^\[DEBUG\]\s*Cropping thumbnails/i)){
statusText.textContent='Cropping album art...';bumpProgress(0.5);
}else if(line.match(/^\[DEBUG\]\s*File:/i)){
const m=line.match(/File:\s*\d+\s*-\s*[^-]+-\s*[^-]+-\s*(.+)\.opus/i);
if(m){
statusText.textContent=`Track: ${m[1]}`;
}else{
const m2=line.match(/File:\s*(.+)/);
statusText.textContent=m2?`Processing: ${m2[1].split('/').pop()}`:'Processing track...';
}
bumpProgress(0.2);
}else if(line.match(/^\[DEBUG\]\s*→/)){
const m=line.match(/→\s*\d+\s*-\s*(.+)\.opus/i);
statusText.textContent=m?`Renamed: ${m[1]}`:'Renaming...';bumpProgress(0.1);
}else if(line.match(/^\[DEBUG\]\s+artist=/i)){
statusText.textContent='Setting tags...';
}

// write_metadata debug
else if(line.match(/^\[DEBUG:write_metadata\]\s*Calling python/i)){
const m=line.match(/with (\d+) args/);
statusText.textContent=m?`Tagging ${Math.floor(parseInt(m[1])/11)} tracks...`:'Writing metadata...';bumpProgress(0.5);
}else if(line.match(/^\[DEBUG:write_metadata\]\s*First arg/i)){
statusText.textContent='Starting metadata write...';
}else if(line.match(/^\[DEBUG:write_metadata\]\s*Python exit code:\s*0/i)){
statusText.textContent='Metadata written!';bumpProgress(0.5);
}else if(line.match(/^\[DEBUG:write_metadata\]/i)){
statusText.textContent='Writing metadata...';
}

// Python processing
else if(line.match(/^\[DEBUG:python\]\s*Processing:/i)){
const m=line.match(/Processing:\s*.+\/([^\/]+)$/);
statusText.textContent=m?`Tagging: ${m[1]}`:'Tagging track...';bumpProgress(0.2);
}else if(line.match(/^\[DEBUG:python\]\s*Tags to write/i)){
statusText.textContent='Writing tags...';
}else if(line.match(/^\[DEBUG:python\]\s*Thumbnail:/i)){
statusText.textContent='Embedding artwork...';
}else if(line.match(/^\[DEBUG:python\]\s*SUCCESS/i)){
statusText.textContent='Track tagged!';bumpProgress(0.3);
}else if(line.match(/^\[DEBUG:python\]/i)){
statusText.textContent='Python processing...';
}

// Verification
else if(line.match(/^\[DEBUG\]\s*Verifying:/i)){
const m=line.match(/Verifying:\s*(.+)/);
statusText.textContent=m?`Verifying: ${m[1]}`:'Verifying tags...';bumpProgress(0.1);
}

// Tag verification output
else if(line.match(/^\s+(album|artist|albumartist|title|date|genre|tracknumber):\s*\[/)){
// Tag verification line - just keep current status
}

// Final done
else if(line.match(/^\[DEBUG\]\s*Done!/i)){
statusText.textContent='All done!';bumpProgress(1);
}else if(line.match(/^✓\s*Download complete/i)){
statusText.textContent='Download complete!';
}

// Separator lines
else if(line.match(/^-{10,}$/)){
// Separator line, ignore
}

// Generic DEBUG fallback
else if(line.match(/^\[DEBUG\]/i)){
statusText.textContent='Processing...';bumpProgress(0.1);
}

return null;
}

function showDupeModal(filename){
return new Promise((resolve)=>{
dupeFile.textContent=filename||'(unknown file)';
dupeModal.className='modal-overlay active';
dupeResolver=resolve;
});
}

function hideDupeModal(){
dupeModal.className='modal-overlay';
dupeResolver=null;
}

dupeYes.onclick=()=>{
if(dupeResolver)dupeResolver(true);
hideDupeModal();
};

dupeNo.onclick=()=>{
if(dupeResolver)dupeResolver(false);
hideDupeModal();
};

async function runDownload(params,clearConsole=true){
const{password,command,url,force,_batch}=params;
currentParams=params;
if(!_batch||clearConsole){
running=true;
btn.disabled=true;
btn.className='btn running';
btn.textContent=_batch?'Batch...':'Running...';
}
progress.className='progress-container active';
if(clearConsole)console_.innerHTML='';
currentPct=0;
if(!_batch){
totalItems=1;
currentItemIndex=0;
itemSource='';
displayedPct=0;
targetPct=0;
lastSongDurations=[];
}else{
// For batch/playlist transitions, smoothly move to next song start position
const songStartPct=(currentItemIndex*100)/totalItems;
targetPct=songStartPct;
}
isIndeterminate=false;
songStartTime=Date.now();
lastActivityTime=Date.now();
let startPct=0;
if(totalItems>1)startPct=(currentItemIndex*100)/totalItems;
if(!_batch)displayedPct=startPct;
targetPct=startPct;
progressFill.style.width=displayedPct+'%';
updateProgressCounter();
setStatus('Connecting...','running');
startProgressAnimation();

let dupeDetected=false;
let dupeFilename='';

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
setStatus('Initializing yt-dlp...','running');
}else if(data.type==='output'){
log(data.line,data.stream==='stderr'?'stderr':'');
handleOutputLine(data.line);
const dupeMatch=data.line.match(/\[download\]\s+(.+)\s+has already been downloaded/i);
if(dupeMatch&&!force){
dupeDetected=true;
dupeFilename=dupeMatch[1];
}
}else if(data.type==='complete'){
if(dupeDetected){
setStatus('Duplicate found','running');
statusDot.className='status-dot';
log('\\n⚠ File already exists','info');
const retry=await showDupeModal(dupeFilename);
if(retry){
log('\\n↻ Retrying with --force...','info');
await runDownload({...params,force:true},false);
return;
}else{
setStatus('Skipped','complete');
log('\\n○ Skipped duplicate','info');
}
}else if(data.exit_code===0){
setStatus('Complete','complete');
log('\\n✓ Download complete','success');
if(!params._batch)document.getElementById('url').value='';
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
if(!params._batch){
running=false;
btn.disabled=false;
btn.className='btn';
btn.textContent='Execute';
}
}
}

form.onsubmit=async(e)=>{
e.preventDefault();
if(running)return;
const password=document.getElementById('password').value;
const command=document.getElementById('command').value;
const force=document.getElementById('force').checked;
const urls=getUrls();

if(urls.length===0){
alert('Please enter at least one URL');
return;
}

if(urls.length===1){
batchProgress.textContent='';
totalItems=1;
currentItemIndex=0;
itemSource='';
await runDownload({password,command,url:urls[0],force});
}else{
let completed=0;
let failed=0;
running=true;
btn.disabled=true;
btn.className='btn running';
btn.textContent='Batch...';
totalItems=urls.length;
itemSource='batch';
for(let i=0;i<urls.length;i++){
currentItemIndex=i;
currentPct=0;
batchProgress.textContent='';
const isLast=i===urls.length-1;
const clearConsole=i===0;
try{
await runDownload({password,command,url:urls[i],force,_batch:true},clearConsole);
completed++;
}catch(err){
failed++;
}
if(!isLast){
log('\\n────────────────────────────────\\n','info');
}
}
batchProgress.textContent=`Batch complete: ${completed} done${failed>0?`, ${failed} failed`:''}`;
totalItems=1;
currentItemIndex=0;
itemSource='';
running=false;
btn.disabled=false;
btn.className='btn';
btn.textContent='Execute';
if(completed===urls.length){
urlBatch.querySelectorAll('.batch-url').forEach((input,i)=>{if(i>0)input.parentElement.remove();else input.value='';});
document.getElementById('url').value='';
updateBatchCounter();
}
}
};
</script>
</body>
</html>'''

if __name__ == '__main__':
    print("Starting MSCD API on http://0.0.0.0:8090")
    app.run(host='0.0.0.0', port=8090, debug=False, threaded=True)
