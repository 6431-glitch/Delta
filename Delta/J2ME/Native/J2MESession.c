#include "J2MESession.h"
#define jvm_bridge_destroy delta_vendor_destroy
#include "../../../Experiments/J2ME/JarBox/J2MEEmulator/NativeBridge/jvm_bridge.c"
#undef jvm_bridge_destroy
static atomic_int delta_paused = 0;
int delta_j2me_is_paused(void) { return atomic_load(&delta_paused); }
void delta_j2me_set_paused(int paused) { atomic_store(&delta_paused, paused != 0); }
void delta_j2me_set_property(const char *key, const char *value) {
    if (g_jvm) sys_properties_set_c(g_jvm, key, value);
}
const char *delta_j2me_get_property(const char *key) {
    if (!g_jvm) return "";
    Utf8String *name = utf8_create_c(key);
    Utf8String *value = hashtable_get(g_jvm->sys_prop, name);
    utf8_destroy(name);
    return value ? utf8_cstr(value) : "";
}

void jvm_bridge_destroy(void) {
    // Also reset state after failed initialization (where the vendor has no VM).
    atomic_store(&delta_paused, 0);
    delta_vendor_destroy();
    atomic_store(&g_jvm_stop_requested, 0);
}
