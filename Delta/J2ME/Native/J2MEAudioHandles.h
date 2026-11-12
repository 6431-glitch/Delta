// Opaque IDs never reuse an AVFoundation object's address. Call under the shared lock.
#import <Foundation/Foundation.h>
#include <stdint.h>

@interface DeltaJ2MEAudioHandleLock : NSObject
@end
@implementation DeltaJ2MEAudioHandleLock
@end

static NSMutableDictionary<NSNumber *, id> *deltaAudioHandles;
static int64_t deltaNextAudioHandle = 1;
static BOOL deltaAudioAcceptsPlayers = YES;
static int64_t deltaAudioRegister(id player) {
    if (!player || !deltaAudioAcceptsPlayers || deltaNextAudioHandle == INT64_MAX) return 0;
    if (!deltaAudioHandles) deltaAudioHandles = [NSMutableDictionary new];
    int64_t handle = deltaNextAudioHandle++;
    deltaAudioHandles[@(handle)] = player;
    return handle;
}
static id deltaAudioLookup(int64_t handle, Class type) {
    id player = deltaAudioHandles[@(handle)];
    return [player isKindOfClass:type] ? player : nil;
}
static id deltaAudioTake(int64_t handle, Class type) {
    id player = deltaAudioLookup(handle, type);
    if (player) [deltaAudioHandles removeObjectForKey:@(handle)];
    return player;
}
static void deltaAudioInvalidate(void) {
    deltaAudioAcceptsPlayers = NO;
    [deltaAudioHandles removeAllObjects];
}
