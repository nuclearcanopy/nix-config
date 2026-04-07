#!/usr/bin/env python3

from flask import Flask, request, jsonify
import subprocess
import hashlib
import hmac
import os

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
        return jsonify({'error': 'Unauthorized - invalid password'}), 401

    data = request.json if request.json else {}
    url = data.get('url') or request.form.get('url')
    command = data.get('command') or request.form.get('command') or 'mscd'
    force = data.get('force') == True or request.form.get('force') == 'true'

    if not url:
        return jsonify({'error': 'Missing URL parameter'}), 400

    if not is_valid_url(url):
        return jsonify({'error': 'Invalid URL'}), 400

    if command not in ['mscd', 'mscd_add', 'mscd_add_a']:
        return jsonify({'error': 'Invalid command. Use: mscd, mscd_add, or mscd_add_a'}), 400

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

    try:
        result = subprocess.Popen(
            cmd,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True
        )

        return jsonify({
            'status': 'started',
            'message': f'Download started: {command} "{url}"',
            'url': url,
            'command': command,
            'force': force
        }), 202

    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/health', methods=['GET'])
def health():
    return jsonify({'status': 'ok'}), 200

@app.route('/', methods=['GET'])
def index():
    return '''
    <!DOCTYPE html>
    <html>
    <head>
        <title>MSCD Music Downloader</title>
        <style>
            body {
                font-family: Arial, sans-serif;
                max-width: 600px;
                margin: 50px auto;
                padding: 20px;
                background: #f5f5f5;
            }
            .container {
                background: white;
                padding: 30px;
                border-radius: 8px;
                box-shadow: 0 2px 4px rgba(0,0,0,0.1);
            }
            h1 { color: #333; margin-top: 0; }
            label { display: block; margin-top: 15px; font-weight: bold; color: #555; }
            input[type="text"], input[type="password"], select {
                width: 100%;
                padding: 10px;
                margin: 5px 0 15px 0;
                border: 1px solid #ddd;
                border-radius: 4px;
                box-sizing: border-box;
            }
            select { cursor: pointer; }
            button {
                width: 100%;
                padding: 12px 20px;
                background: #007bff;
                color: white;
                border: none;
                cursor: pointer;
                border-radius: 4px;
                font-size: 16px;
                margin-top: 10px;
            }
            button:hover { background: #0056b3; }
            .checkbox {
                margin: 15px 0;
                display: flex;
                align-items: center;
            }
            .checkbox input { width: auto; margin-right: 8px; }
            #result {
                margin-top: 20px;
                padding: 15px;
                border-radius: 4px;
                display: none;
            }
            .success {
                background: #d4edda;
                border: 1px solid #c3e6cb;
                color: #155724;
                display: block;
            }
            .error {
                background: #f8d7da;
                border: 1px solid #f5c6cb;
                color: #721c24;
                display: block;
            }
            .info {
                background: #e7f3ff;
                padding: 15px;
                border-radius: 4px;
                margin-bottom: 20px;
                border-left: 4px solid #007bff;
            }
            .info h3 { margin-top: 0; }
            code {
                background: #f4f4f4;
                padding: 2px 6px;
                border-radius: 3px;
                font-family: monospace;
            }
        </style>
    </head>
    <body>
        <div class="container">
            <h1>MSCD Music Downloader</h1>

            <div class="info">
                <h3>Commands:</h3>
                <p><code>mscd</code> - Direct download to library</p>
                <p><code>mscd_add</code> - Add to queue and download</p>
                <p><code>mscd_add -a</code> - Add to Alexandra's queue</p>
            </div>

            <form id="downloadForm">
                <label>Password:</label>
                <input type="password" id="password" placeholder="Enter API password" required>

                <label>Command:</label>
                <select id="command">
                    <option value="mscd">mscd (direct download)</option>
                    <option value="mscd_add">mscd_add (queue)</option>
                    <option value="mscd_add_a">mscd_add -a (Alexandra's queue)</option>
                </select>

                <label>Music URL:</label>
                <input type="text" id="url" placeholder="https://youtube.com/watch?v=..." required>

                <div class="checkbox">
                    <input type="checkbox" id="force">
                    <label for="force">Force re-download (--force)</label>
                </div>

                <button type="submit">Download Music</button>
            </form>

            <div id="result"></div>
        </div>

        <script>
            document.getElementById('downloadForm').onsubmit = async (e) => {
                e.preventDefault();

                const password = document.getElementById('password').value;
                const command = document.getElementById('command').value;
                const url = document.getElementById('url').value;
                const force = document.getElementById('force').checked;

                const resultDiv = document.getElementById('result');
                resultDiv.textContent = 'Processing download...';
                resultDiv.className = '';
                resultDiv.style.display = 'block';

                try {
                    const response = await fetch('/download', {
                        method: 'POST',
                        headers: {
                            'Authorization': password,
                            'Content-Type': 'application/json'
                        },
                        body: JSON.stringify({ command, url, force })
                    });

                    const data = await response.json();

                    if (response.ok) {
                        resultDiv.textContent = data.message;
                        resultDiv.className = 'success';
                        document.getElementById('url').value = '';
                    } else {
                        resultDiv.textContent = 'Error: ' + data.error;
                        resultDiv.className = 'error';
                    }
                } catch (error) {
                    resultDiv.textContent = 'Error: ' + error.message;
                    resultDiv.className = 'error';
                }
            };
        </script>
    </body>
    </html>
    '''

if __name__ == '__main__':
    # Run on all interfaces, port 8090
    print("Starting MSCD API on http://0.0.0.0:8090")
    print("Change API_PASSWORD in the script before using in production!")
    app.run(host='0.0.0.0', port=8090, debug=False)
