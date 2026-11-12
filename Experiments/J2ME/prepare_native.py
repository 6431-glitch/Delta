#!/usr/bin/env python3
"""Generate asserted pause and audio ownership overlays without changing the pinned engine."""
from pathlib import Path
root = Path(__file__).resolve().parent
vendor = root / 'JarBox/J2MEEmulator'
out = root / 'Generated'
out.mkdir(exist_ok=True)
for filename in ['interpreter.c', 'jvm_util.c']:
    source = (vendor / 'minijvm/jvm' / filename).read_text()
    if filename == 'interpreter.c':
        old = 'offset < 0 && thrd_info->suspend_count'
        assert source.count(old) == 1
        source = source.replace(old, 'offset < 0 && (thrd_info->suspend_count || delta_j2me_is_paused())')
    else:
        old = 'if (threadInfo->suspend_count && !threadInfo->no_pause)'
        assert source.count(old) == 1
        source = source.replace(old, 'if ((threadInfo->suspend_count || delta_j2me_is_paused()) && !threadInfo->no_pause)')
        old = 'while (threadInfo->suspend_count)'
        assert source.count(old) == 1
        source = source.replace(old, 'while (threadInfo->suspend_count || (delta_j2me_is_paused() && !threadInfo->is_stop))')
    (out / filename).write_text('#include "J2MESession.h"\n' + source)
# Audio overlay: remember only players that were actually running.
audio = (vendor / 'NativeBridge/j2me_audio.m').read_text()
audio = '#include "J2MESession.h"\n#include "J2MEAudioHandles.h"\n' + audio
needle = 'void j2me_audio_stop_all(void) {'
assert audio.count(needle) == 1
audio = audio.replace(needle, '''static NSMutableSet *deltaPausedAudio;
static NSMutableSet *deltaPausedMIDI;
void delta_j2me_audio_pause(int paused) {
    @synchronized ([AVAudioSession class]) {
        if (paused) {
            if (deltaPausedAudio) return;
            deltaPausedAudio = [NSMutableSet new]; deltaPausedMIDI = [NSMutableSet new];
            for (AVAudioPlayer *p in g_active_audio_players) if (p.playing) { [deltaPausedAudio addObject:p]; [p pause]; }
            for (AVMIDIPlayer *p in g_active_midi_players) if (p.playing) { [deltaPausedMIDI addObject:p]; [p stop]; }
        } else {
            for (AVAudioPlayer *p in deltaPausedAudio) if ([g_active_audio_players containsObject:p]) [p play];
            for (AVMIDIPlayer *p in deltaPausedMIDI) if ([g_active_midi_players containsObject:p]) [p play:nil];
            deltaPausedAudio = nil; deltaPausedMIDI = nil;
        }
    }
}
void j2me_audio_stop_all(void) {
    @synchronized ([AVAudioSession class]) { deltaPausedAudio = nil; deltaPausedMIDI = nil; }
''')
# A native call already in flight at a safe point must not start audio after pausing.
audio = audio.replace('[player play];', 'if (!delta_j2me_is_paused()) [player play];')
# Java long values are opaque IDs; ARC and the registry own the players.
import re
audio = audio.replace('@synchronized ([AVAudioSession class])', '@synchronized ([DeltaJ2MEAudioHandleLock class])')
audio = audio.replace('CFRetain((__bridge CFTypeRef)player);', '')
audio = audio.replace('CFRelease((__bridge CFTypeRef)player);', '')
audio = audio.replace('CFRelease((__bridge CFTypeRef)p);', '')
audio = audio.replace('(s64)(intptr_t)(__bridge void *)player', 'deltaAudioRegister(player)')
for kind in ['AVAudioPlayer', 'AVMIDIPlayer']:
    audio = audio.replace(f'(__bridge {kind} *)(void *)(intptr_t)handle', f'deltaAudioLookup(handle, [{kind} class])')
# Missing/stale IDs are no-ops, including untracking from Foundation sets.
audio = re.sub(r'    if \(handle\) \{\n        (AV(?:Audio|MIDI)Player \*player = deltaAudioLookup[^\n]+;)', r'    \1\n    if (player) {', audio)
# Close consumes a handle once. No subsequent native call can dereference it.
for method, kind in [('n_audioClose', 'AVAudioPlayer'), ('n_audioMidiClose', 'AVMIDIPlayer')]:
    start = audio.index('static s32 ' + method + '(')
    end = audio.index('\nstatic s32 ', start + 1)
    block = audio[start:end].replace('deltaAudioLookup(handle', 'deltaAudioTake(handle')
    if kind == 'AVMIDIPlayer':
        block = block.replace('[player stop];', 'dispatch_async(dispatch_get_main_queue(), ^{ [player stop]; });\n        [deltaPausedMIDI removeObject:player];')
    else:
        block = block.replace('[player stop];', '[player stop];\n        [deltaPausedAudio removeObject:player];')
    audio = audio[:start] + block + audio[end:]
# No lock is held while waiting for the main queue. The block owns MIDI snapshots
# until their stop and final release on the main thread.
audio = audio.replace('dispatch_sync(dispatch_get_main_queue()', 'dispatch_async(dispatch_get_main_queue()')
audio = audio.replace('NSSet *midiSnapshot = nil;', 'NSSet *midiSnapshot = nil;')
audio = audio.replace('if (g_active_audio_players) {', 'deltaAudioInvalidate();\n        if (g_active_audio_players) {', 1)
# Do not retain players created after session teardown.
audio = audio.replace('track_audio_player(player);\n    env->push_long(runtime->stack, deltaAudioRegister(player));',
    's64 token = deltaAudioRegister(player);\n    if (token) track_audio_player(player);\n    env->push_long(runtime->stack, token);')
audio = audio.replace('track_midi_player(player);\n    env->push_long(runtime->stack, deltaAudioRegister(player));',
    's64 token = deltaAudioRegister(player);\n    if (token) track_midi_player(player);\n    else dispatch_async(dispatch_get_main_queue(), ^{ [player stop]; });\n    env->push_long(runtime->stack, token);')
# Serialize lookups and player operations with close, pause and cleanup.
pattern = r'(static s32 n_audio\w+\([^\n]+\) \{)(.*?)(\n\})'
audio, count = re.subn(pattern, lambda m: m[1] + '\n    @synchronized ([DeltaJ2MEAudioHandleLock class]) {' + m[2] + '\n    }' + m[3], audio, flags=re.S)
assert count == 13, count
audio = audio.replace('void j2me_audio_reg_natives(MiniJVM *jvm) {',
    'void j2me_audio_reg_natives(MiniJVM *jvm) {\n    @synchronized ([DeltaJ2MEAudioHandleLock class]) { deltaAudioAcceptsPlayers = YES; }')
assert '__bridge' not in audio and 'CFRelease' not in audio
(out / 'j2me_audio.m').write_text(audio)
