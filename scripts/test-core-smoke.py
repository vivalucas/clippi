#!/usr/bin/env python3
"""Exercise the built core through its public FFI with generated media.

Run after cargo build --release. Requires ffmpeg and ffprobe on PATH.
"""
import ctypes
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import threading

ROOT = Path(__file__).resolve().parents[1]
SUFFIX = 'dylib' if sys.platform == 'darwin' else 'so'
lib = ctypes.CDLL(str(ROOT / f'core/target/release/libclippi_core.{SUFFIX}'))
callback_type = ctypes.CFUNCTYPE(None, ctypes.c_char_p)
lib.clippi_run_task.argtypes = [ctypes.c_char_p, callback_type]
lib.clippi_run_task.restype = ctypes.c_uint64
lib.clippi_cancel_task.argtypes = [ctypes.c_uint64]


def probe(path):
    return json.loads(subprocess.check_output([
        'ffprobe', '-v', 'error', '-show_streams', '-show_format', '-of', 'json', str(path)]))


with tempfile.TemporaryDirectory(prefix='clippi-smoke-') as directory:
    directory = Path(directory)
    source = directory / 'portrait.mp4'
    subprocess.run(['ffmpeg', '-v', 'error', '-f', 'lavfi', '-i',
                    'testsrc2=size=180x320:rate=24', '-f', 'lavfi', '-i',
                    'sine=frequency=440', '-t', '2', '-c:v', 'libx264',
                    '-c:a', 'aac', str(source)], check=True)

    def run(name, operation, extension='mp4', input_path=source, expected='completed'):
        output = directory / f'{name}.{extension}'
        finished = threading.Event()
        terminal = []

        @callback_type
        def callback(raw):
            event = json.loads(raw)
            if event['state'] in ('completed', 'failed', 'cancelled'):
                terminal.append(event)
                finished.set()

        config = dict(input_path=str(input_path), output_path=str(output), operation=operation,
                      video_codec='libx264', audio_codec='aac')
        task = lib.clippi_run_task(json.dumps(config).encode(), callback)
        assert task and finished.wait(30), f'{name}: timeout'
        assert terminal[-1]['state'] == expected, (name, terminal)
        if expected == 'completed':
            result = probe(output)
            assert float(result['format']['duration']) > 0, name
        else:
            result = None
        print(f'PASS {name}')
        return output, result

    _, scaled = run('portrait-scale', {'Scale': {'width': 1280, 'height': 720}})
    video = next(s for s in scaled['streams'] if s['codec_type'] == 'video')
    assert abs(video['width'] / video['height'] - 180 / 320) < .005
    assert video['width'] % 2 == video['height'] % 2 == 0
    _, trimmed = run('precise-trim', {'Trim': {'start': .5, 'end': 1.5, 'fast_mode': False}})
    assert abs(float(trimmed['format']['duration']) - 1) < .15
    run('fast-trim', {'Trim': {'start': 0, 'end': 1, 'fast_mode': True}})
    webm, _ = run('convert-webm', {'Convert': {'format': 'webm'}}, 'webm')
    run('scale-webm', {'Scale': {'width': 640, 'height': 480}}, 'webm', webm)
    run('trim-webm', {'Trim': {'start': .25, 'end': 1, 'fast_mode': False}}, 'webm', webm)
    _, audio = run('extract-audio', {'ExtractAudio': {'format': 'mp3'}}, 'mp3')
    assert all(s['codec_type'] == 'audio' for s in audio['streams'])
    _, silent = run('remove-audio', 'RemoveAudio')
    assert all(s['codec_type'] != 'audio' for s in silent['streams'])
    _, rotated = run('rotate', {'Transform': {'rotation_degrees': 90, 'flip_horizontal': False, 'flip_vertical': False}})
    video = next(s for s in rotated['streams'] if s['codec_type'] == 'video')
    assert (video['width'], video['height']) == (320, 180)
    run('invalid-source', 'RemoveAudio', input_path=directory / 'missing.mp4', expected='failed')
    # Existing output must remain byte-for-byte unchanged.
    existing = directory / 'remove-audio.mp4'
    original = existing.read_bytes()
    run('remove-audio', 'RemoveAudio', expected='failed')
    assert existing.read_bytes() == original
print('All 11 FFI smoke cases passed.')
