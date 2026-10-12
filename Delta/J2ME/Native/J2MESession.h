#ifndef DELTA_J2ME_SESSION_H
#define DELTA_J2ME_SESSION_H
// Pause is independent of miniJVM's collector suspension counter.
int delta_j2me_is_paused(void);
void delta_j2me_set_paused(int paused);
// Call property functions only on the JVM owner thread, before run/after run.
void delta_j2me_set_property(const char *key, const char *value);
const char *delta_j2me_get_property(const char *key);
void delta_j2me_audio_pause(int paused);
#endif
