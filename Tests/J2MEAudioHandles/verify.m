#import "J2MEAudioHandles.h"
#include <assert.h>
int main(void) {
    @autoreleasepool {
        __weak NSObject *weakPlayer;
        int64_t first;
        @autoreleasepool {
            NSObject *player = [NSObject new]; weakPlayer = player;
            first = deltaAudioRegister(player);
        }
        assert(weakPlayer != nil);
        @autoreleasepool {
            id lease = deltaAudioTake(first, [NSObject class]);
            assert(lease != nil);
            assert(deltaAudioTake(first, [NSObject class]) == nil);
            assert(deltaAudioLookup(first, [NSObject class]) == nil);
        }
        assert(weakPlayer == nil);
        int64_t second = deltaAudioRegister([NSObject new]);
        assert(second > first);
        deltaAudioInvalidate();
        assert(deltaAudioTake(second, [NSObject class]) == nil);
        assert(deltaAudioRegister([NSObject new]) == 0);
        deltaAudioAcceptsPlayers = YES;
        int64_t third = deltaAudioRegister([NSObject new]);
        assert(third > second);
        assert(deltaAudioLookup(first, [NSObject class]) == nil);
        dispatch_apply(1000, dispatch_get_global_queue(QOS_CLASS_DEFAULT, 0), ^(size_t i) {
            @autoreleasepool {
                @synchronized ([DeltaJ2MEAudioHandleLock class]) {
                    if (i % 3 == 0) deltaAudioTake(third, [NSObject class]);
                    else if (i % 3 == 1) deltaAudioLookup(third, [NSObject class]);
                    else deltaAudioInvalidate();
                }
            }
        });
        assert(deltaAudioLookup(third, [NSObject class]) == nil);
        puts("Audio handles: duplicate close, stale lookup, ARC lifetime, teardown, late create, token uniqueness and concurrent cleanup passed.");
    }
}
