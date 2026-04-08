# Local SSD paths for fast access (synced to NAS periodically)
MUSIC_BASE="/home/homeserver/Navidrome/music/Web"
MUSIC_BASE_BOUGHT="/home/homeserver/Navidrome/music/Bought"
# NAS paths for sync operations
MUSIC_BASE_NAS="/mnt/nas/Navidrome/music/Web"
MUSIC_BASE_BOUGHT_NAS="/mnt/nas/Navidrome/music/Bought"

URLS_FILE="/var/lib/navidrome/data/urls/urls.txt"
URLS_FILE_ALEXANDRA="/var/lib/navidrome/data/urls/urls_alexandra.txt"
MSCD_COOKIES="/home/homeserver/Navidrome/cookies.txt"
MSCD_ARCHIVE="/var/lib/navidrome/data/mscd_archive.txt"

mkdir -p ~/.local/bin
curl -L https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp -o ~/.local/bin/yt-dlp
chmod +x ~/.local/bin/yt-dlp
export PATH="$HOME/.local/bin:$PATH"

which yt-dlp
yt-dlp --version

export LC_ALL="${LC_ALL:-C.UTF-8}"

MSCD_GENRE_DEFAULT="Web"

# Trigger sync to NAS (runs async in background)
mscd_sync() {
  echo "[SYNC] Triggering sync to NAS..."
  if command -v systemctl &>/dev/null; then
    # Try to trigger the systemd service (will fail gracefully if not available)
    systemctl start navidrome-sync-to-nas.service --no-block 2>/dev/null || {
      # Fallback: direct rsync if systemd service isn't available
      echo "[SYNC] Systemd service not available, running direct rsync..."
      rsync -av --update /home/homeserver/Navidrome/music/ /mnt/nas/Navidrome/music/ &
    }
  fi
}

# Pull music library from NAS to local SSD (initial setup/recovery)
mscd_pull() {
  echo "[SYNC] Pulling music library from NAS to local SSD..."
  if command -v systemctl &>/dev/null; then
    systemctl start navidrome-sync-from-nas.service 2>/dev/null || {
      echo "[SYNC] Systemd service not available, running direct rsync..."
      mkdir -p /home/homeserver/Navidrome/music
      rsync -av --progress /mnt/nas/Navidrome/music/ /home/homeserver/Navidrome/music/
      [[ -f /mnt/nas/Navidrome/cookies.txt ]] && cp /mnt/nas/Navidrome/cookies.txt /home/homeserver/Navidrome/cookies.txt
    }
  else
    mkdir -p /home/homeserver/Navidrome/music
    rsync -av --progress /mnt/nas/Navidrome/music/ /home/homeserver/Navidrome/music/
    [[ -f /mnt/nas/Navidrome/cookies.txt ]] && cp /mnt/nas/Navidrome/cookies.txt /home/homeserver/Navidrome/cookies.txt
  fi
  echo "[SYNC] Pull complete!"
}

if command -v python3 &>/dev/null; then
  MSCD_PYTHON=python3
elif command -v python &>/dev/null; then
  MSCD_PYTHON=python
else
  MSCD_PYTHON=$(head -1 "$(command -v yt-dlp)" 2>/dev/null | sed 's/^#!//' | tr -d ' ')
  [[ -z "$MSCD_PYTHON" || ! -x "$MSCD_PYTHON" ]] && echo "[ERROR] No python found!" && MSCD_PYTHON=python3
fi


normalize_text() {
  printf '%s' "$1" | "$MSCD_PYTHON" -c "
import sys, unicodedata

t = sys.stdin.read()

out = []
for c in t:
    cp = ord(c)
    if 0xFF01 <= cp <= 0xFF5E:
        out.append(chr(cp - 0xFEE0))
    else:
        out.append(c)
t = ''.join(out)

for c in '\u2018\u2019\u201a\u201b\u0060\u00b4':
    t = t.replace(c, \"'\")

for c in '\u0022\u201c\u201d\u201e\u201f\u2033\u2036\u02ba\u301d\u301e\u301f':
    t = t.replace(c, '')

for c in '\u2013\u2014':
    t = t.replace(c, '-')

import re
t = re.sub(r'[\u00a0\u2000-\u200a\u202f\u205f]', ' ', t)

t = re.sub(r'[\u200b-\u200d\ufeff]', '', t)

sys.stdout.write(t)
"
}

sanitize() {
  local text
  text=$(normalize_text "$1")
  text="${text//\"/}"
  printf '%s' "$text" \
    | sed 's/[[:space:]]\+/ /g; s/^[[:space:]_-]\+//; s/[[:space:]_-]\+$//'
}

get_tags() {
  local file="$1"
  shift
  local tags_csv="${(j:,:)@}"

  local output
  output=$(ffprobe -v error \
    -show_entries "format_tags=$tags_csv" \
    -of default=noprint_wrappers=1 \
    "$file" 2>/dev/null)

  local tag
  for tag in "$@"; do
    local val=""
    val=$(echo "$output" | grep -i "^TAG:${tag}=" | head -n1 | cut -d= -f2-)
    typeset -g "TAG_${tag}=$val"
  done
}

read_info_json() {
  local audio_file="$1" field="$2"
  local base="${audio_file%.*}"
  local json_file="${base}.info.json"
  [[ -f "$json_file" ]] || return
  "$MSCD_PYTHON" -c "
import json, sys
try:
    d = json.load(open(sys.argv[1]))
    v = d.get(sys.argv[2], '')
    if v: print(v)
except: pass
" "$json_file" "$field" 2>/dev/null
}


resolve_artist() {
  local file="$1"
  get_tags "$file" artist uploader creator

  echo "[DEBUG:resolve_artist] File tags: artist='$TAG_artist' uploader='$TAG_uploader' creator='$TAG_creator'" >&2

  local raw="${TAG_artist:-${TAG_uploader:-${TAG_creator:-}}}"

  if [[ -z "$raw" ]]; then
    echo "[DEBUG:resolve_artist] No artist in file tags, checking info.json..." >&2
    raw=$(read_info_json "$file" "artist")
    [[ -z "$raw" ]] && raw=$(read_info_json "$file" "uploader")
    [[ -z "$raw" ]] && raw=$(read_info_json "$file" "creator")
    [[ -z "$raw" ]] && raw=$(read_info_json "$file" "channel")
    echo "[DEBUG:resolve_artist] From info.json: '$raw'" >&2
  fi

  [[ -z "$raw" ]] && echo "Unknown Artist" && return

  raw="${raw% - Topic}"
  raw=$(normalize_text "$raw")
  echo "$raw"
}

resolve_album() {
  local file="$1"
  get_tags "$file" album
  local raw="$TAG_album"
  [[ -z "$raw" ]] && raw=$(read_info_json "$file" "album")
  [[ -z "$raw" ]] && return
  normalize_text "$raw"
}

resolve_title() {
  local file="$1"
  get_tags "$file" title
  local raw="$TAG_title"
  if [[ -z "$raw" ]]; then
    raw=$(read_info_json "$file" "track")
    [[ -z "$raw" ]] && raw=$(read_info_json "$file" "title")
  fi
  [[ -z "$raw" ]] && return
  normalize_text "$raw"
}

resolve_year() {
  local file="$1"
  get_tags "$file" date year
  local raw="${TAG_date:-$TAG_year}"
  if [[ -z "$raw" ]]; then
    raw=$(read_info_json "$file" "release_year")
    [[ -z "$raw" ]] && raw=$(read_info_json "$file" "upload_date")
  fi
  [[ -z "$raw" ]] && return
  raw="${raw[1,4]}"
  [[ "$raw" =~ ^[0-9]{4}$ ]] && echo "$raw"
}


unique_filename() {
  local path="$1"
  [[ ! -f "$path" ]] && printf '%s' "$path" && return

  local dir="${path%/*}"
  local fullname="${path##*/}"
  local ext="${fullname##*.}"
  local base="${fullname%.*}"

  local n=2
  local new_path
  while true; do
    new_path="$dir/${base}_(${n}).$ext"
    [[ ! -f "$new_path" ]] && printf '%s' "$new_path" && return
    ((n++))
  done
}

crop_thumbnail() {
  local input="$1" output="$2"
  ffmpeg -y -i "$input" -vf "crop='min(iw,ih)':'min(iw,ih)':'(iw-min(iw,ih))/2':'(ih-min(iw,ih))/2'" "$output" 2>/dev/null
}

find_thumbnail() {
  local audio_file="$1"
  local base="${audio_file%.*}"
  local thumb
  for thumb in "${base}".png "${base}".jpg "${base}".webp; do
    [[ -f "$thumb" ]] && printf '%s' "$thumb" && return
  done
}

clean_artist() {
  local artist
  artist=$(normalize_text "$1")
  artist="${artist//\"/}"

  setopt local_options extendedglob
  artist="${artist//[[:space:]][[:space:]]#/ }"
  artist="${artist%%, *}"
  printf '%s' "$artist"
}

song_exists() {
  local artist="$1" title="$2"
  [[ -z "$title" ]] && return 1

  local match_title match_artist
  match_title=$("$MSCD_PYTHON" -c "
import sys, re, unicodedata
t = sys.argv[1].lower()
t = ''.join(c for c in unicodedata.normalize('NFD', t) if unicodedata.category(c) != 'Mn')
t = re.sub(r'[^a-z0-9 ]', '', t)
t = ' '.join(t.split())
print(t)
" "$title")

  match_artist=$("$MSCD_PYTHON" -c "
import sys, re, unicodedata
t = sys.argv[1].lower()
t = ''.join(c for c in unicodedata.normalize('NFD', t) if unicodedata.category(c) != 'Mn')
t = re.sub(r'[^a-z0-9 ]', '', t)
t = ' '.join(t.split())
print(t)
" "$artist")

  [[ -z "$match_title" ]] && return 1

  # Check both local SSD and NAS for duplicates
  local dir found
  for dir in "$MUSIC_BASE" "$MUSIC_BASE_BOUGHT" "$MUSIC_BASE_NAS" "$MUSIC_BASE_BOUGHT_NAS"; do
    [[ -d "$dir" ]] || continue
    found=$("$MSCD_PYTHON" -c "
import os, sys, re, unicodedata

def norm(s):
    s = s.lower()
    s = ''.join(c for c in unicodedata.normalize('NFD', s) if unicodedata.category(c) != 'Mn')
    s = re.sub(r'[^a-z0-9 ]', '', s)
    return ' '.join(s.split())

target_title = sys.argv[1]
target_artist = sys.argv[2]
search_dir = sys.argv[3]

for root, dirs, files in os.walk(search_dir):
    path_norm = norm(root)
    if target_artist and target_artist not in path_norm:
        continue
    for f in files:
        name = os.path.splitext(f)[0]
        name = re.sub(r'^\d+\s*-\s*', '', name)
        if norm(name) == target_title:
            print(os.path.join(root, f))
            sys.exit(0)
sys.exit(1)
" "$match_title" "$match_artist" "$dir" 2>/dev/null)

    if [[ $? -eq 0 && -n "$found" ]]; then
      echo "[SKIP] Already exists: $found"
      return 0
    fi
  done
  return 1
}

write_metadata() {
  echo "[DEBUG:write_metadata] Calling $MSCD_PYTHON with ${#@} args" >&2
  echo "[DEBUG:write_metadata] First arg (file): $1" >&2
  "$MSCD_PYTHON" - "$@" 2>&1 << 'PYEOF'
import sys, base64, traceback


def dequote(v):
    if v is None:
        return ''
    v = str(v)
    v = v.replace('\r',' ').replace('\n',' ').strip()
    if len(v) >= 2 and ((v[0] == v[-1] == '"') or (v[0] == v[-1] == "'")):
        v = v[1:-1].strip()
    if len(v) >= 2 and v[0] in '\u201c\u201d\u201e\u201f\u2033\u02ba\uff02' and v[-1] in '\u201c\u201d\u201e\u201f\u2033\u02ba\uff02':
        v = v[1:-1].strip()
    for c in '"\u201c\u201d\u201e\u201f\u2033\u2036\u02ba\u301d\u301e\u301f\uff02':
        v = v.replace(c, '')
    v = ' '.join(v.split())
    return v


def vorbis_key_map(k: str) -> str:
    km = {
        'artist': 'ARTIST',
        'album_artist': 'ALBUMARTIST',
        'albumartist': 'ALBUMARTIST',
        'album': 'ALBUM',
        'title': 'TITLE',
        'tracknumber': 'TRACKNUMBER',
        'track': 'TRACKNUMBER',
        'date': 'DATE',
        'year': 'DATE',
        'genre': 'GENRE',
        'compilation': 'COMPILATION',
        'comment': 'COMMENT',
    }
    return km.get(k.strip().lower(), k.strip())


def make_thumbnail_ogg(path: str) -> str:
    from mutagen.flac import Picture
    data = open(path,'rb').read()
    mime = 'image/png' if data[:8] == b"\x89PNG\r\n\x1a\n" else ('image/jpeg' if data[:2] == b"\xff\xd8" else 'image/png')
    pic = Picture()
    pic.type = 3
    pic.mime = mime
    pic.data = data
    return base64.b64encode(pic.write()).decode('ascii')


def existing_ogg_picture(f):
    pics = f.get('metadata_block_picture', [])
    return pics[0] if pics else None


def make_thumbnail_mp4(path: str):
    from mutagen.mp4 import MP4Cover
    data = open(path,'rb').read()
    fmt = MP4Cover.FORMAT_PNG if data[:8] == b"\x89PNG\r\n\x1a\n" else (MP4Cover.FORMAT_JPEG if data[:2] == b"\xff\xd8" else MP4Cover.FORMAT_PNG)
    return MP4Cover(data, imageformat=fmt)


def existing_mp4_cover(f):
    covr = f.get('covr', [])
    return covr[0] if covr else None


def process_file(filepath, tags, thumb_path=None):
    print(f"[DEBUG:python] Processing: {filepath}")
    print(f"[DEBUG:python] Tags to write: {tags}")
    print(f"[DEBUG:python] Thumbnail: {thumb_path}")

    ext = filepath.rsplit('.', 1)[-1].lower()

    try:
        if ext in ('opus','ogg'):
            if ext == 'opus':
                from mutagen.oggopus import OggOpus as Ogg
            else:
                from mutagen.oggvorbis import OggVorbis as Ogg

            f = Ogg(filepath)
            old_pic = None if thumb_path else existing_ogg_picture(f)

            f.delete(); f.save(); f = Ogg(filepath)

            for k,v in (tags or {}).items():
                kk = vorbis_key_map(k)
                vv = dequote(v)
                if vv != '':
                    f[kk] = [vv]

            if thumb_path:
                f['metadata_block_picture'] = [make_thumbnail_ogg(thumb_path)]
            elif old_pic:
                f['metadata_block_picture'] = [old_pic]

            f.save()
            print('[DEBUG:python] SUCCESS')

        elif ext in ('m4a','mp4','aac'):
            from mutagen.mp4 import MP4
            f = MP4(filepath)
            old_covr = None if thumb_path else existing_mp4_cover(f)

            f.delete(); f.save(); f = MP4(filepath)

            tag_map = {
                'artist': '\xa9ART',
                'album_artist': 'aART',
                'album': '\xa9alb',
                'title': '\xa9nam',
                'date': '\xa9day',
                'year': '\xa9day',
                'tracknumber': 'trkn',
                'genre': '\xa9gen',
                'compilation': 'cpil',
                'comment': '\xa9cmt',
            }

            for k,v in (tags or {}).items():
                k2 = str(k).strip().lower()
                key = tag_map.get(k2)
                if not key:
                    continue
                vv = dequote(v)
                if key == 'trkn':
                    try:
                        f[key] = [(int(vv), 0)]
                    except Exception:
                        pass
                elif key == 'cpil':
                    f[key] = (vv == '1')
                else:
                    if vv != '':
                        f[key] = [vv]

            if thumb_path:
                f['covr'] = [make_thumbnail_mp4(thumb_path)]
            elif old_covr:
                f['covr'] = [old_covr]

            f.save()
            print('[DEBUG:python] SUCCESS')

        else:
            import subprocess, shutil, tempfile
            tmp = tempfile.mktemp(suffix='.'+ext)
            cmd = ['ffmpeg','-y','-i',filepath,'-map','0','-c','copy','-map_metadata','-1']
            for k,v in (tags or {}).items():
                cmd += ['-metadata', f"{k}={dequote(v)}"]
            cmd.append(tmp)
            subprocess.run(cmd, check=True, capture_output=True)
            shutil.move(tmp, filepath)
            print('[DEBUG:python] SUCCESS')

    except Exception as e:
        print(f"[DEBUG:python] ERROR: {e}")
        traceback.print_exc()


args = sys.argv[1:]
current_file = None
current_tags = {}
current_thumb = None

for arg in args:
    if arg == '---':
        if current_file:
            process_file(current_file, current_tags, current_thumb)
        current_file, current_tags, current_thumb = None, {}, None
        continue

    if arg.startswith('_thumbnail='):
        current_thumb = arg.split('=',1)[1]
        continue

    if current_file and '=' in arg:
        k,v = arg.split('=',1)
        current_tags[k] = v
        continue

    if current_file:
        process_file(current_file, current_tags, current_thumb)
    current_file, current_tags, current_thumb = arg, {}, None

if current_file:
    process_file(current_file, current_tags, current_thumb)
PYEOF
  local rc=$?
  echo "[DEBUG:write_metadata] Python exit code: $rc" >&2
}


mscd() {
  if [[ -z "$1" ]]; then
    echo "Usage: mscd <URL>"
    return 1
  fi

  if ! command -v "$MSCD_PYTHON" &>/dev/null; then
    echo "[ERROR] Python not found at '$MSCD_PYTHON'!"
    return 1
  fi
  echo "[DEBUG] Using python: $MSCD_PYTHON ($("$MSCD_PYTHON" --version 2>&1))"

  "$MSCD_PYTHON" -c "import mutagen; print(f'[DEBUG] mutagen version: {mutagen.version_string}')" 2>&1 || {
    echo "[ERROR] mutagen not available in $MSCD_PYTHON!"
    return 1
  }

  local url
  url=$(printf '%s' "$1" | tr -d '\r' | sed 's/^\xEF\xBB\xBF//')

  if [[ "$url" != https* ]]; then
    case "$url" in
      ttp*)                  url="h$url" ;;
      tps://*)               url="ht$url" ;;
      ps://*)                url="htt$url" ;;
      s://*)                 url="http$url" ;;
      ://*)                  url="https$url" ;;
      //*)                   url="https:$url" ;;
      /*)                    url="https:/$url" ;;
      music.youtube.com/*)   url="https://$url" ;;
      usic.youtube.com/*)    url="https://m$url" ;;
      sic.youtube.com/*)     url="https://mu$url" ;;
      ic.youtube.com/*)      url="https://mus$url" ;;
      c.youtube.com/*)       url="https://musi$url" ;;
      .youtube.com/*)        url="https://music$url" ;;
      youtube.com/*)         url="https://$url" ;;
      outube.com/*)          url="https://y$url" ;;
      utube.com/*)           url="https://yo$url" ;;
      tube.com/*)            url="https://you$url" ;;
      ube.com/*)             url="https://yout$url" ;;
      be.com/*)              url="https://youtu$url" ;;
      e.com/*)               url="https://youtub$url" ;;
      .com/*)                url="https://youtube$url" ;;
      *)                     url="https://$url" ;;
    esac
    echo "[DEBUG] Fixed URL to: $url"
  fi

  if [[ "$url" == *"playlist"* || "$url" == *"list="* || "$url" == *"/browse/MPRE"* || "$url" == *"/album/"* ]]; then
    mscd_album "$url"
  else
    mscd_single "$url"
  fi
}

mscd_add() {
  mscd_add_h "$@"
}


mscd_single_from_tmp() {
  local file="$1"
  local ext="${file##*.}"

  echo "[DEBUG] ===== ALL TAGS IN SOURCE FILE ====="
  ffprobe -v error -show_entries format_tags -of default=noprint_wrappers=1 "$file"
  echo "[DEBUG] ===== END ALL TAGS ====="

  local json_file="${file%.*}.info.json"
  if [[ -f "$json_file" ]]; then
    echo "[DEBUG] info.json found"
    echo "[DEBUG] info.json key fields:"
    "$MSCD_PYTHON" -c "
import json, sys
d = json.load(open(sys.argv[1]))
for k in ('artist', 'uploader', 'creator', 'channel', 'album', 'track', 'title', 'release_year', 'upload_date'):
    print(f'  {k}: {d.get(k, \"(not set)\")}')
" "$json_file" 2>&1
  else
    echo "[DEBUG] WARNING: No info.json found"
  fi

  local raw_artist
  raw_artist=$(resolve_artist "$file")

  local album_artist
  album_artist=$(clean_artist "$raw_artist")
  [[ -z "$album_artist" ]] && album_artist="Unknown Artist"
  echo "[DEBUG] Final resolved artist: '$album_artist' (routing to Global as single)"

  local title
  title=$(resolve_title "$file")
  [[ -z "$title" ]] && title=$(basename "$file" ".$ext")
  local title_ascii
  title_ascii=$(sanitize "$title")
  [[ -z "$title_ascii" ]] && title_ascii="Unknown Title"

  local title_file="${title_ascii//\//-}"
  title_file="${title_file//\"/}"

  if [[ -z "$FORCE_DOWNLOAD" ]] && song_exists "$album_artist" "$title_ascii"; then
    echo "[DEBUG] Skipping single (already exists)"
    return 0
  fi

  local dest="$MUSIC_BASE/Global"
  mkdir -p "$dest"

  local final_path
  final_path=$(unique_filename "$dest/$title_file.$ext")
  echo "[DEBUG] Final path: $final_path"
  cp "$file" "$final_path"

  local thumb cropped_thumb=""
  thumb=$(find_thumbnail "$file")
  if [[ -n "$thumb" ]]; then
    cropped_thumb="${file%.*}_cropped.png"
    crop_thumbnail "$thumb" "$cropped_thumb"
    echo "[DEBUG] Cropped thumbnail"
  fi

  local -a meta_args=(
    "$final_path"
    "artist=$album_artist"
    "album=Global"
    "album_artist=Various Artists"
    "title=$title_ascii"
    "genre=$MSCD_GENRE_DEFAULT"
    "compilation=1"
    "date=2020"
  )
  [[ -n "$cropped_thumb" && -f "$cropped_thumb" ]] && meta_args+=("_thumbnail=$cropped_thumb")

  write_metadata "${meta_args[@]}"
  echo "[DEBUG] Written: $final_path"
}

mscd_album() {
  if [[ -z "$1" ]]; then
    echo "Usage: mscd <URL>"
    return 1
  fi

  echo "[DEBUG] Starting mscd_album for URL: $1"

  local tmpdir
  tmpdir=$(mktemp -d)
  echo "[DEBUG] Temporary directory: $tmpdir"

  local -a archive_flag=() cookies_flag=()
  [[ -n "$MSCD_ARCHIVE" && -z "$FORCE_DOWNLOAD" ]] && archive_flag=(--download-archive "$MSCD_ARCHIVE")
  [[ -n "$MSCD_COOKIES" && -f "$MSCD_COOKIES" ]] && cookies_flag=(--cookies "$MSCD_COOKIES")

  yt-dlp -f bestaudio \
    --extract-audio \
    --add-metadata \
    --write-thumbnail \
    --write-info-json \
    --convert-thumbnails png \
    --ignore-errors \
    --extractor-args "youtube:player_client=default" \
    "${cookies_flag[@]}" \
    "${archive_flag[@]}" \
    -o "$tmpdir/%(playlist_index)02d - %(artist)s - %(album)s - %(title)s.%(ext)s" \
    "$1"

  setopt local_options nullglob

  local -a all_files
  all_files=("$tmpdir"/*.opus "$tmpdir"/*.m4a "$tmpdir"/*.webm "$tmpdir"/*.ogg)

  if (( ${#all_files[@]} <= 1 )); then
    echo "[DEBUG] Only ${#all_files[@]} track(s) found, treating as single"
    if (( ${#all_files[@]} == 1 )); then
      mscd_single_from_tmp "${all_files[1]}"
    else
      echo "[DEBUG] No audio files found!"
    fi
    rm -rf "$tmpdir"
    echo "[DEBUG] Done!"
    return
  fi

  local album_artist="" file

  for file in "${all_files[@]}"; do
    get_tags "$file" album_artist
    [[ -n "$TAG_album_artist" ]] && album_artist="$TAG_album_artist" && break
  done

  if [[ -z "$album_artist" ]]; then
    for file in "${all_files[@]}"; do
      album_artist=$(read_info_json "$file" "album_artist")
      [[ -n "$album_artist" ]] && break
    done
  fi

  if [[ -z "$album_artist" ]]; then
    local -A artist_count
    local art primary
    for file in "${all_files[@]}"; do
      art=$(resolve_artist "$file")
      [[ -z "$art" || "$art" == "Unknown Artist" ]] && continue

      primary="${art%%[Ff]eat.*}"
      primary="${primary%%[Ff]eaturing*}"
      primary="${primary## }"
      primary="${primary%% }"
      [[ -z "$primary" ]] && continue
      ((artist_count["$primary"]++))
    done

    local max=0 k
    for k in "${(@k)artist_count}"; do
      if (( artist_count[$k] > max )); then
        max=${artist_count[$k]}
        album_artist="$k"
      fi
    done
  fi

  album_artist=$(clean_artist "${album_artist:-Unknown Artist}")
  [[ -z "$album_artist" ]] && album_artist="Unknown Artist"
  echo "[DEBUG] Resolved album artist: $album_artist"

  local album_name=""
  for file in "${all_files[@]}"; do
    album_name=$(resolve_album "$file")
    [[ -n "$album_name" ]] && break
  done
  [[ -z "$album_name" ]] && album_name="Unknown Album"
  echo "[DEBUG] Resolved album name: $album_name"

  local -A year_count
  local y
  for file in "${all_files[@]}"; do
    y=$(resolve_year "$file")
    [[ -z "$y" ]] && continue
    ((year_count["$y"]++))
  done

  local album_year="" max_count=0
  for y in "${(@k)year_count}"; do
    if (( year_count[$y] > max_count )); then
      max_count=${year_count[$y]}
      album_year=$y
    fi
  done

  [[ -n "$album_year" ]] && echo "[DEBUG] Resolved album year: $album_year" \
    || echo "[DEBUG] No album year found"

  local artist_dir album_dir dest
  artist_dir=$(sanitize "$album_artist")
  [[ -z "$artist_dir" ]] && artist_dir="Unknown_Artist"
  artist_dir="${artist_dir//\//-}"
  artist_dir="${artist_dir//\"/}"

  album_dir=$(sanitize "$album_name")
  [[ -z "$album_dir" ]] && album_dir="Unknown_Album"
  album_dir="${album_dir//\//-}"
  album_dir="${album_dir//\"/}"

  dest="$MUSIC_BASE/$artist_dir/$album_dir"
  mkdir -p "$dest"
  echo "[DEBUG] Album destination: $dest"

  echo "[DEBUG] Cropping thumbnails to 1:1..."
  local thumb cropped
  for file in "${all_files[@]}"; do
    thumb=$(find_thumbnail "$file")
    if [[ -n "$thumb" ]]; then
      cropped="${file%.*}_cropped.png"
      crop_thumbnail "$thumb" "$cropped"
    fi
  done

  local -a batch_meta_args final_paths
  local ext filebase track_number track_padded title title_ascii title_file final_path

  for file in "${all_files[@]}"; do
    echo "---------------------------------------------------"
    echo "[DEBUG] File: ${file:t}"

    ext="${file##*.}"
    filebase="${file:t}"
    track_number="${filebase%% -*}"

track_number="${filebase%% -*}"
track_number="${track_number//[^0-9]/}"

if [[ -n "$track_number" ]]; then
  local _tn_stripped="${track_number##0}"
  track_number="${_tn_stripped:-0}"
fi

if [[ -z "$track_number" || "$track_number" == "0" ]]; then
  track_number=$(read_info_json "$file" "playlist_index")
  track_number="${track_number//[^0-9]/}"
  if [[ -n "$track_number" ]]; then
    local _tn2="${track_number##0}"
    track_number="${_tn2:-0}"
  fi
fi

if [[ -z "$track_number" || "$track_number" == "0" ]]; then
  ((++__mscd_track_fallback))
  track_number="$__mscd_track_fallback"
fi
    printf -v track_padded "%02d" "$track_number"

    title=$(resolve_title "$file")
    [[ -z "$title" ]] && title="${filebase%.*}"

    title_ascii=$(sanitize "$title")
    [[ -z "$title_ascii" ]] && title_ascii="Unknown_Title"
    title_file="${title_ascii//\//-}"
    title_file="${title_file//\"/}"

    if [[ -z "$FORCE_DOWNLOAD" ]] && song_exists "$album_artist" "$title_ascii"; then
      echo "[DEBUG] Skipping track $track_padded (already exists)"
      continue
    fi

    final_path=$(unique_filename "$dest/$track_padded - $title_file.$ext")
    final_paths+=("$final_path")
    echo "[DEBUG] → ${final_path##*/}"
    echo "[DEBUG]   artist='$album_artist' album='$album_name' title='$title_ascii'"

    cp "$file" "$final_path"

    batch_meta_args+=(
      "$final_path"
      "artist=$album_artist"
      "album_artist=$album_artist"
      "title=$title_ascii"
      "album=$album_name"
      "genre=$MSCD_GENRE_DEFAULT"
      "tracknumber=$track_number"
    )

    [[ -n "$album_year" ]] && batch_meta_args+=("date=$album_year" "year=$album_year")

    cropped="${file%.*}_cropped.png"
    [[ -f "$cropped" ]] && batch_meta_args+=("_thumbnail=$cropped")

    batch_meta_args+=("---")
  done

  write_metadata "${batch_meta_args[@]}"

  for final_path in "${final_paths[@]}"; do
    echo "[DEBUG] Verifying: ${final_path:t}"
    "$MSCD_PYTHON" -c "
import sys
try:
    ext = sys.argv[1].rsplit('.', 1)[-1].lower()
    if ext == 'opus':
        from mutagen.oggopus import OggOpus; f = OggOpus(sys.argv[1])
    elif ext in ('m4a', 'mp4'):
        from mutagen.mp4 import MP4; f = MP4(sys.argv[1])
    elif ext == 'ogg':
        from mutagen.oggvorbis import OggVorbis; f = OggVorbis(sys.argv[1])
    else:
        print('  (skipped verify for .' + ext + ')'); sys.exit(0)
    for k, v in sorted(f.items()):
        if k not in ('metadata_block_picture', 'covr'):
            print(f'  {k}: {v}')
except Exception as e:
    print(f'  verify error: {e}')
" "$final_path" 2>&1
  done

  rm -rf "$tmpdir"
  echo "[DEBUG] Done!"
  mscd_sync
}

mscd_single() {
  if [[ -z "$1" ]]; then
    echo "Usage: mscd_single <URL>"
    return 1
  fi

  echo "[DEBUG] Starting mscd_single for URL: $1"

  local tmpdir
  tmpdir=$(mktemp -d)
  echo "[DEBUG] Temporary directory: $tmpdir"

  local -a archive_flag=() cookies_flag=()
  [[ -n "$MSCD_ARCHIVE" && -z "$FORCE_DOWNLOAD" ]] && archive_flag=(--download-archive "$MSCD_ARCHIVE")
  [[ -n "$MSCD_COOKIES" && -f "$MSCD_COOKIES" ]] && cookies_flag=(--cookies "$MSCD_COOKIES")

  yt-dlp -f bestaudio \
    --extract-audio \
    --add-metadata \
    --write-thumbnail \
    --write-info-json \
    --convert-thumbnails png \
    --no-playlist \
    --ignore-errors \
    --extractor-args "youtube:player_client=default" \
    "${cookies_flag[@]}" \
    "${archive_flag[@]}" \
    -o "$tmpdir/%(title)s.%(ext)s" \
    "$1"

  setopt local_options nullglob

  echo "[DEBUG] Files in tmpdir:"
  ls -la "$tmpdir"/ 2>&1

  local file
  for file in "$tmpdir"/*.opus "$tmpdir"/*.m4a "$tmpdir"/*.webm "$tmpdir"/*.ogg; do
    mscd_single_from_tmp "$file"
  done

  rm -rf "$tmpdir"
  echo "[DEBUG] Done!"
  mscd_sync
}

mscd_add_h() {
  if [[ -z "$1" ]]; then
    echo "Usage: mscd_add <URL> [-a] [--force]"
    echo "  -a        Save URL to urls_alexandra.txt instead of urls.txt"
    echo "  --force   Re-download even if URL already saved"
    return 1
  fi

  local url="" force=false alexandra=false arg
  for arg in "$@"; do
    case "$arg" in
      --force|-f) force=true ;;
      -a)         alexandra=true ;;
      *)          [[ -z "$url" ]] && url="$arg" ;;
    esac
  done

  if [[ -z "$url" ]]; then
    echo "[ERROR] No URL provided"
    return 1
  fi

  local target_file="$URLS_FILE"
  $alexandra && target_file="$URLS_FILE_ALEXANDRA"

  if $force || ! grep -Fxq "$url" "$target_file" 2>/dev/null; then
    echo "$url" >> "$target_file"
    echo "[DEBUG] Added URL to $target_file"
  else
    echo "[DEBUG] URL already exists in $target_file"
  fi

  if $force; then
    FORCE_DOWNLOAD=1 mscd "$url"
  else
    mscd "$url"
  fi
}

mscd_cleanup() {
  local base="${1:-$MUSIC_BASE}"
  echo "[CLEANUP] Scanning for quoted directory names in: $base"

  local count=0
  local dir clean_name target

  find "$base" -mindepth 1 -maxdepth 2 -type d -name '*"*' | sort -r | while IFS= read -r dir; do
    clean_name=$(basename "$dir" | tr -d '"')
    clean_name=$("$MSCD_PYTHON" -c "
import sys
t = sys.argv[1]
for c in '\u0022\u201c\u201d\u201e\u201f\u2033\u2036\u02ba\u301d\u301e\u301f\uff02':
    t = t.replace(c, '')
t = ' '.join(t.split())  # collapse whitespace
print(t)
" "$clean_name")

    target="$(dirname "$dir")/$clean_name"

    if [[ "$dir" == "$target" ]]; then
      continue
    fi

    if [[ -d "$target" ]]; then
      echo "[CLEANUP] Merging: $(basename "$dir") → $clean_name"
      cp -rn "$dir"/* "$target"/ 2>/dev/null
      rm -rf "$dir"
    else
      echo "[CLEANUP] Renaming: $(basename "$dir") → $clean_name"
      mv "$dir" "$target"
    fi
    ((count++))
  done

  echo "[CLEANUP] Fixed $count directories"
}

batch_mscd() {
  if [[ -z "$1" ]]; then
    echo "Usage: batch_mscd <file.txt>"
    echo "  Downloads every URL in the file, one per line"
    return 1
  fi

  local file="$1"
  if [[ ! -f "$file" ]]; then
    echo "[ERROR] File not found: $file"
    return 1
  fi

  local total=0 success=0 failed=0
  local line url

  total=$(grep -cve '^\s*$' -e '^\s*#' "$file" 2>/dev/null || echo 0)
  echo "[BATCH] Starting batch download: $total URLs from $file"
  echo "========================================================="

  local i=0
  while IFS= read -r line || [[ -n "$line" ]]; do
    url="${line%%#*}"
    url="${url#"${url%%[! ]*}"}"
    url="${url%"${url##*[! ]}"}"
    [[ -z "$url" ]] && continue

    ((i++))
    echo ""
    echo "========================================================="
    echo "[BATCH] ($i/$total) $url"
    echo "========================================================="

    if mscd "$url"; then
      ((success++))
    else
      ((failed++))
      echo "[BATCH] FAILED: $url"
    fi

  done < "$file"

  echo ""
  echo "========================================================="
  echo "[BATCH] Complete: $success succeeded, $failed failed (of $total)"
  echo "========================================================="
}
