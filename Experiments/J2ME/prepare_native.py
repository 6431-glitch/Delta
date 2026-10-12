#!/usr/bin/env python3
"""Generate two small, asserted patches without modifying the pinned native engine."""
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
audio = '#include "J2MESession.h"\n' + audio
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
(out / 'j2me_audio.m').write_text(audio)
