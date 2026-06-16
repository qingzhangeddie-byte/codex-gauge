#import <Foundation/Foundation.h>

typedef void *IOReportSubscriptionRef;
typedef CFDictionaryRef IOReportSampleRef;
typedef int (^IOReportIterateBlock)(IOReportSampleRef channel);

extern CFMutableDictionaryRef IOReportCopyChannelsInGroup(CFStringRef group, CFStringRef subgroup, uint64_t a, uint64_t b, uint64_t c);
extern IOReportSubscriptionRef IOReportCreateSubscription(void *allocator, CFMutableDictionaryRef desiredChannels, CFMutableDictionaryRef *subscribedChannels, uint64_t channelID, CFTypeRef options);
extern CFDictionaryRef IOReportCreateSamples(IOReportSubscriptionRef subscription, CFMutableDictionaryRef channels, CFTypeRef options);
extern void IOReportIterate(CFDictionaryRef samples, IOReportIterateBlock block);
extern CFStringRef IOReportChannelGetGroup(IOReportSampleRef channel);
extern CFStringRef IOReportChannelGetSubGroup(IOReportSampleRef channel);
extern CFStringRef IOReportChannelGetChannelName(IOReportSampleRef channel);
extern int64_t IOReportSimpleGetIntegerValue(IOReportSampleRef channel, int index);

static BOOL cfStringEquals(CFStringRef value, NSString *expected) {
    if (value == NULL) {
        return NO;
    }
    return CFStringCompare(value, (__bridge CFStringRef)expected, 0) == kCFCompareEqualTo;
}

static void writePayload(NSDictionary *payload) {
    NSError *error = nil;
    NSData *data = [NSJSONSerialization dataWithJSONObject:payload options:0 error:&error];
    if (data == nil) {
        fputs("{\"ok\":false,\"temperature_c\":null,\"source\":\"IOReport\",\"error\":\"JSON encode failed\"}\n", stdout);
        return;
    }
    fwrite(data.bytes, 1, data.length, stdout);
    fputc('\n', stdout);
}

static NSDictionary *unavailablePayload(NSString *message) {
    return @{
        @"ok": @NO,
        @"temperature_c": [NSNull null],
        @"source": @"IOReport",
        @"error": message
    };
}

static NSDictionary *readSSDTemperaturePayload(void) {
    NSArray<NSString *> *subgroups = @[@"MSP0", @"MSP1"];
    NSMutableOrderedSet<NSString *> *sources = [NSMutableOrderedSet orderedSet];
    __block NSInteger highestTemperature = NSIntegerMin;

    for (NSString *subgroup in subgroups) {
        CFMutableDictionaryRef channels = IOReportCopyChannelsInGroup(CFSTR("ANS2"), (__bridge CFStringRef)subgroup, 0, 0, 0);
        if (channels == NULL) {
            continue;
        }

        CFMutableDictionaryRef subscribedChannels = NULL;
        IOReportSubscriptionRef subscription = IOReportCreateSubscription(NULL, channels, &subscribedChannels, 0, NULL);
        if (subscription == NULL) {
            CFRelease(channels);
            if (subscribedChannels != NULL) {
                CFRelease(subscribedChannels);
            }
            continue;
        }

        CFMutableDictionaryRef sampleChannels = subscribedChannels != NULL ? subscribedChannels : channels;
        CFDictionaryRef samples = IOReportCreateSamples(subscription, sampleChannels, NULL);
        if (samples != NULL) {
            IOReportIterate(samples, ^int(IOReportSampleRef channel) {
                CFStringRef groupName = IOReportChannelGetGroup(channel);
                CFStringRef subgroupName = IOReportChannelGetSubGroup(channel);
                CFStringRef channelName = IOReportChannelGetChannelName(channel);
                if (!cfStringEquals(groupName, @"ANS2") || !cfStringEquals(channelName, @"Temperature(0)")) {
                    return 0;
                }
                if (!cfStringEquals(subgroupName, @"MSP0") && !cfStringEquals(subgroupName, @"MSP1")) {
                    return 0;
                }

                int64_t rawValue = IOReportSimpleGetIntegerValue(channel, 0);
                if (rawValue >= 0 && rawValue <= 120) {
                    NSInteger value = (NSInteger)rawValue;
                    highestTemperature = MAX(highestTemperature, value);
                    NSString *subgroupLabel = (__bridge NSString *)subgroupName;
                    if (subgroupLabel.length > 0) {
                        [sources addObject:subgroupLabel];
                    }
                }
                return 0;
            });
            CFRelease(samples);
        }

        if (subscribedChannels != NULL) {
            CFRelease(subscribedChannels);
        }
        CFRelease(subscription);
        CFRelease(channels);
    }

    if (highestTemperature == NSIntegerMin) {
        return unavailablePayload(@"SSD sensor unavailable");
    }

    NSString *source = sources.count > 0
        ? [NSString stringWithFormat:@"IOReport ANS2 %@", [[sources array] componentsJoinedByString:@"/"]]
        : @"IOReport ANS2";
    return @{
        @"ok": @YES,
        @"temperature_c": @(highestTemperature),
        @"source": source,
        @"error": [NSNull null]
    };
}

int main(int argc, const char *argv[]) {
    @autoreleasepool {
        writePayload(readSSDTemperaturePayload());
    }
    return 0;
}
