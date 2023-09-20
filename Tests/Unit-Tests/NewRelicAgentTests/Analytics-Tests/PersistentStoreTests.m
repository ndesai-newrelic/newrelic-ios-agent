//
//  PersistentStoreTests.m
//  Agent_Tests
//
//  Created by Steve Malsam on 9/6/23.
//  Copyright © 2023 New Relic. All rights reserved.
//

#import <XCTest/XCTest.h>

#import "PersistentEventStore.h"

#import "NRMAMobileEvent.h"
#import "NRMACustomEvent.h"
#import "NRMARequestEvent.h"
#import "NRMAInteractionEvent.h"

#import "BlockAttributeValidator.h"

@interface TestEvent : NRMAMobileEvent <NSCoding>
- (instancetype) initWithTimestamp:(NSTimeInterval)timestamp
       sessionElapsedTimeInSeconds:(NSTimeInterval)sessionElapsedTimeSeconds
            withAttributeValidator:(__nullable id<AttributeValidatorProtocol>) attributeValidator;
@end

@implementation TestEvent
- (nonnull instancetype) initWithTimestamp:(NSTimeInterval)timestamp
               sessionElapsedTimeInSeconds:(NSTimeInterval)sessionElapsedTimeSeconds
                    withAttributeValidator:(__nullable id<AttributeValidatorProtocol>) attributeValidator {
    self = [super initWithTimestamp:timestamp
        sessionElapsedTimeInSeconds:sessionElapsedTimeSeconds
             withAttributeValidator:attributeValidator];
    if (self) {

    }
    
    return self;
}

- (void)encodeWithCoder:(nonnull NSCoder *)coder {
    [coder encodeDouble:self.timestamp forKey:@"Timestamp"];
    [coder encodeDouble:self.sessionElapsedTimeSeconds forKey:@"SessionElapsedTimeInSeconds"];
    [coder encodeObject:self.eventType forKey:@"EventType"];
    [coder encodeObject:self.attributes forKey:@"Attributes"];
}

- (nullable instancetype)initWithCoder:(nonnull NSCoder *)coder {
    self = [super init];
    if(self) {
        self.timestamp = [coder decodeDoubleForKey:@"Timestamp"];
        self.sessionElapsedTimeSeconds = [coder decodeDoubleForKey:@"SessionElapsedTimeInSeconds"];
        self.eventType = [coder decodeObjectForKey:@"EventType"];
        self.attributes = [coder decodeObjectForKey:@"Attributes"];
    }
    
    return self;
}

@end

@interface PersistentStoreTests : XCTestCase
@end

@implementation PersistentStoreTests {
    BlockAttributeValidator *agreeableAttributeValidator;
}

static NSString *testFilename = @"fbstest_tempStore";



- (void)setUp {
    if(agreeableAttributeValidator == nil) {
        agreeableAttributeValidator = [[BlockAttributeValidator alloc] initWithNameValidator:^BOOL(NSString *) {
            return YES;
        } valueValidator:^BOOL(id) {
            return YES;
        } andEventTypeValidator:^BOOL(NSString *) {
            return YES;
        }];
    }
    
    NSFileManager *fileManager = [NSFileManager defaultManager];
    if([fileManager fileExistsAtPath:testFilename]) {
        [fileManager removeItemAtPath:testFilename error:nil];
    }
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    NSFileManager *fileManager = [NSFileManager defaultManager];
    if([fileManager fileExistsAtPath:testFilename]) {
        [fileManager removeItemAtPath:testFilename error:nil];
    }
}

- (void)testStoresObject {
    // Given
    PersistentEventStore *sut = [[PersistentEventStore alloc] initWithFilename:testFilename
                                                     andMinimumDelay:1];
    
    TestEvent *testEvent = [[TestEvent alloc] initWithTimestamp:10
                                            sessionElapsedTimeInSeconds:50
                                                 withAttributeValidator:nil];
    
    // When
    [sut setObject:testEvent forKey:@"aKey"];
    
    // Then
    TestEvent *retrievedEvent = [sut objectForKey:@"aKey"];
    XCTAssertEqual(testEvent, retrievedEvent);
}

- (void)testWritesObjectToFile {
    // Given
    PersistentEventStore *sut = [[PersistentEventStore alloc] initWithFilename:testFilename
                                                     andMinimumDelay:1];

    TestEvent *testEvent = [[TestEvent alloc] initWithTimestamp:10
                                            sessionElapsedTimeInSeconds:50
                                                 withAttributeValidator:nil];
    
    [testEvent addAttribute:@"AnAttribute" value:@1];
    [testEvent addAttribute:@"AnotherAttribute" value:@NO];
    [testEvent addAttribute:@"AThirdAttribute" value:@"Attribute"];

    // When
    [sut setObject:testEvent forKey:@"aKey"];


    // Then
    NSFileManager *fileManager = [NSFileManager defaultManager];
    
    XCTAssertTrue([fileManager fileExistsAtPath:testFilename]);
    
    NSData *retrievedData = [NSData dataWithContentsOfFile:testFilename];
    NSError *error = nil;
    NSMutableDictionary *retrievedDictionary = [NSKeyedUnarchiver unarchiveTopLevelObjectWithData:retrievedData
                                                                                            error:&error];
    XCTAssertNil(error, "Error testing file written: %@", [error localizedDescription]);
    XCTAssertEqual([retrievedDictionary count], 1);
    
    PersistentEventStore *anotherOne = [[PersistentEventStore alloc] initWithFilename:testFilename
                                                            andMinimumDelay:1];
    [anotherOne load:&error];
    XCTAssertNil(error, "Error loading previous events: %@", [error localizedDescription]);
    TestEvent *anotherEvent = [anotherOne objectForKey:@"aKey"];
    XCTAssertNotNil(anotherEvent);
    XCTAssertEqual(anotherEvent.timestamp, testEvent.timestamp);
    XCTAssertEqual(anotherEvent.sessionElapsedTimeSeconds, testEvent.sessionElapsedTimeSeconds);
    XCTAssertEqual([anotherEvent.attributes count], [testEvent.attributes count]);
}

- (void)testStoreReturnsNoIfFileDoesNotExist {
    PersistentEventStore *sut = [[PersistentEventStore alloc] initWithFilename:@"FileDoesNotExist"
                                                     andMinimumDelay:1];
    NSError *error = nil;
    XCTAssertFalse([sut load:&error]);
}

- (void)testStoreHandlesDifferentTypesOfEvents {
    // Given
    PersistentEventStore *originalStore = [[PersistentEventStore alloc] initWithFilename:testFilename
                                                     andMinimumDelay:1];
    NSError *error = nil;

    // When
    NRMACustomEvent *customEvent = [self createCustomEvent];
    NRMARequestEvent *requestEvent = [self createRequestEvent];
    NRMAInteractionEvent *interactionEvent = [self createInteractionEvent];

    [originalStore setObject:customEvent forKey:@"Custom Event"];
    [originalStore setObject:requestEvent forKey:@"Request Event"];
    [originalStore setObject:interactionEvent forKey:@"Interaction Event"];
    sleep(1);

    // Then
//    NSFileManager *fileManager = [NSFileManager defaultManager];
//
//    XCTAssertTrue([fileManager fileExistsAtPath:testFilename]);
//
//    NSData *retrievedData = [NSData dataWithContentsOfFile:testFilename];
//    NSError *error = nil;
//    NSMutableDictionary *retrievedDictionary = [NSKeyedUnarchiver unarchiveTopLevelObjectWithData:retrievedData
//                                                                                            error:&error];
    
    PersistentEventStore *anotherOne = [[PersistentEventStore alloc] initWithFilename:testFilename
                                                            andMinimumDelay:1];

    [anotherOne load:&error];

    XCTAssertNil(error, @"There was a problem loading the previous events into the new thing");

    NRMACustomEvent *retrievedCustom = [anotherOne objectForKey:@"Custom Event"];
    XCTAssertNotNil(retrievedCustom);
    XCTAssertEqual(retrievedCustom.timestamp, customEvent.timestamp);
    XCTAssertEqual(retrievedCustom.sessionElapsedTimeSeconds, customEvent.sessionElapsedTimeSeconds);
    XCTAssertEqualObjects(retrievedCustom.eventType, customEvent.eventType);

    NRMARequestEvent *retrievedRequest = [anotherOne objectForKey:@"Request Event"];
    XCTAssertNotNil(retrievedRequest);
    XCTAssertEqual(retrievedRequest.timestamp, requestEvent.timestamp);
    XCTAssertEqual(retrievedRequest.sessionElapsedTimeSeconds, requestEvent.sessionElapsedTimeSeconds);
    XCTAssertEqualObjects(retrievedRequest.eventType, requestEvent.eventType);
}

- (void)testEventRemoval {
    // Given
    PersistentEventStore *sut =  [[PersistentEventStore alloc] initWithFilename:testFilename
                                                      andMinimumDelay:1];
    
    NSError *error = nil;
    
    NRMACustomEvent *customEvent = [self createCustomEvent];
    NRMARequestEvent *requestEvent = [self createRequestEvent];
    NRMAInteractionEvent *interactionEvent = [self createInteractionEvent];

    [sut setObject:customEvent forKey:@"Custom Event"];
    [sut setObject:requestEvent forKey:@"Request Event"];
    [sut setObject:interactionEvent forKey:@"Interaction Event"];
    sleep(1);
    
    // When
    [sut removeObjectForKey:@"Request Event"];
    
    
    // Then
    XCTAssertNil([sut objectForKey:@"Request Event"]);
    
    PersistentEventStore *anotherOne = [[PersistentEventStore alloc] initWithFilename:testFilename
                                                            andMinimumDelay:1];

    [anotherOne load:&error];
    
    XCTAssertNil([anotherOne objectForKey:@"Request Event"]);
}

- (void)testClearAllEvents {
    // Given
    PersistentEventStore *sut =  [[PersistentEventStore alloc] initWithFilename:testFilename
                                                      andMinimumDelay:1];
    
    NSError *error = nil;
    
    NRMACustomEvent *customEvent = [self createCustomEvent];
    NRMARequestEvent *requestEvent = [self createRequestEvent];
    NRMAInteractionEvent *interactionEvent = [self createInteractionEvent];

    [sut setObject:customEvent forKey:@"Custom Event"];
    [sut setObject:requestEvent forKey:@"Request Event"];
    [sut setObject:interactionEvent forKey:@"Interaction Event"];
    sleep(1);
    
    // When
    [sut clearAll];
    
    // Then
    XCTAssertNil([sut objectForKey:@"Custom Event"]);
    XCTAssertNil([sut objectForKey:@"Request Event"]);
    XCTAssertNil([sut objectForKey:@"Interaction Event"]);
    
    PersistentEventStore *anotherOne = [[PersistentEventStore alloc] initWithFilename:testFilename
                                                            andMinimumDelay:1];

    [anotherOne load:&error];
    
    XCTAssertNil([anotherOne objectForKey:@"Custom Event"]);
    XCTAssertNil([anotherOne objectForKey:@"Request Event"]);
    XCTAssertNil([anotherOne objectForKey:@"Interaction Event"]);
}

- (NRMACustomEvent *)createCustomEvent {
    NSTimeInterval timestamp = arc4random() % 100;
    NSTimeInterval elapsedTime = arc4random() % 50;
    NSString *eventType = @"New Event";

    return [[NRMACustomEvent alloc] initWithEventType:eventType
                                            timestamp:timestamp
                          sessionElapsedTimeInSeconds:elapsedTime
                               withAttributeValidator:agreeableAttributeValidator];
}

- (NRMARequestEvent *)createRequestEvent {
    NSTimeInterval timestamp = arc4random() % 100;
    NSTimeInterval elapsedTime = arc4random() % 50;
    NRMAPayload* payload = [[NRMAPayload alloc] initWithTimestamp:timestamp accountID:@"1" appID:@"1" traceID:@"1" parentID:@"1" trustedAccountKey:@"1"];

    return [[NRMARequestEvent alloc] initWithTimestamp:timestamp
                           sessionElapsedTimeInSeconds:elapsedTime
                                               payload:payload
                                withAttributeValidator:agreeableAttributeValidator];
}

- (NRMAInteractionEvent *)createInteractionEvent {
    NSTimeInterval timestamp = arc4random() % 100;
    NSTimeInterval elapsedTime = arc4random() % 50;
    NSString *name = @"Interaction";
    NSString *category = @"Category";

    return [[NRMAInteractionEvent alloc] initWithTimestamp:timestamp
                               sessionElapsedTimeInSeconds:elapsedTime
                                                      name:name
                                                  category:category
                                    withAttributeValidator:agreeableAttributeValidator];
}

@end
