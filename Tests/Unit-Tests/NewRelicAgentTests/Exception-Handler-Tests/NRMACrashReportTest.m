//
//  NRMACrashReportTest.m
//  NewRelicAgent
//
//  Created by Bryce Buchanan on 6/14/16.
//  Copyright © 2023 New Relic. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "NewRelicInternalUtils.h"
#import "NRMACrashReport.h"
#import "NRMACrashDataWriter.h"

 #import "NRMAExceptionDataCollectionWrapper.h"
 #import "PLCrashTestThread.h"
 #import "PLCrashReport.h"
 #import "PLCrashReporter.h"
 #import "PLCrashFrameWalker.h"

 #import "NRMAUncaughtExceptionHandler.h"
 #import "NRMAExceptionHandlerManager.h"
 #import "NRMAExceptionHandlerStartupManager.h"
 #import "NewRelicAgentInternal.h"
 #import "NRMACrashDataUploader.h"

 #import "NRMACrashReportFileManager.h"

 #if __has_include(<CrashReporter/CrashReporter.h>)
 #import <CrashReporter/CrashReporter.h>
 #import <CrashReporter/PLCrashReporter.h>
 #else
 #import "CrashReporter.h"
 #import "PLCrashReporter.h"
 #endif

@interface NRMACrashReportTest : XCTestCase

@end

@implementation NRMACrashReportTest

- (void)setUp {
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

- (void) testOSName {
    // This is an example of a functional test case.
    // Use XCTAssert and related functions to verify your tests produce the correct results.
    NRMACrashReport* report = [[NRMACrashReport alloc] initWithUUID:@"asdf"
                                                    buildIdentifier:@"blah"
                                                          timestamp:@1
                                                           appToken:@"token"
                                                          accountId:@213
                                                            agentId:@1123
                                                         deviceInfo:nil
                                                            appInfo:nil
                                                          exception:nil
                                                            threads:nil
                                                          libraries:nil
                                                    activityHistory:nil
                                                  sessionAttributes:nil
                                                    AnalyticsEvents:nil];

#if TARGET_OS_TV
    XCTAssertTrue([[report JSONObject][kNRMA_CR_platformKey] isEqualToString:NRMA_OSNAME_TVOS]);
#else
    XCTAssertTrue([[report JSONObject][kNRMA_CR_platformKey] isEqualToString:NRMA_OSNAME_IOS]);
#endif

}

- (void) testCrashReport {


    NRMACrashReport_DeviceInfo* deviceInfo = [[NRMACrashReport_DeviceInfo alloc] initWithMemoryUsage:@(1)
                                                                                         orientation:@(5)
                                                                                       networkStatus:@"WIFI"
                                                                                           diskUsage:@[]
                                                                                           osVersion:@"13"
                                                                                          deviceName:@"TestDevice"
                                                                                             osBuild:@"testOSBuild"
                                                                                        architecture:@"test_arch"
                                                                                         modelNumber:@"iphone@test"
                                                                                          deviceUuid:@"device_uuid"];

    NRMACrashReport_AppInfo* appInfo = [[NRMACrashReport_AppInfo alloc] initWithAppName:@"test_app"
                                                                         appVersion:@"testAppVersion"
                                                                               appBuild:@"testAppBuild"
                                                                               bundleId:@"com.test.bundleId"
                                                                            processPath:@"test/path"
                                                                            processName:@"test_process_name"
                                                                              processId:@(1)
                                                                          parentProcess:@"/test/process/parent"
                                                                        parentProcessId:@(0)];


    NRMACrashReport_SignalInfo* sigInfo = [[NRMACrashReport_SignalInfo alloc] initWithFaultAddress:@"testAddr"
                                                                                        signalCode:@"test_sig_code"
                                                                                        signalName:@"SIG_NAME"];
    NRMACrashReport_Exception* exception = [[NRMACrashReport_Exception alloc] initWithName:@"test_exception"
                                                                                     cause:@"test_cause"
                                                                                signalInfo:sigInfo];




    NRMACrashReport_Stack* stack = [[NRMACrashReport_Stack alloc] initWithInstructionPointer:@"0x12345678" symbol:nil];

    NRMACrashReport_Thread* thread = [[NRMACrashReport_Thread alloc] initWithCrashed:true
                                                                           registers:@{@"rax":@"0x51125343"}
                                                                    threadNumber:@(1)
                                                                            threadId:@"thread 1"
                                                                        priority:@(1)
                                                                               stack:[@[stack] mutableCopy]];

    NRMACrashReport_Library* library = [[NRMACrashReport_Library alloc] initWithBaseAddress:@"0x0555"
                                                                                  imageName:@"testImage"
                                                                                  imageSize:@(5345345)
                                                                                  imageUuid:@"imgUUID"
                                                                                   codeType:[[NRMACrashReport_CodeType alloc] initWithArch:@"arm64"
                                                                                                                              typeEncoding:@"encoding"]];
    
    

    NRMACrashReport* report = [[NRMACrashReport alloc] initWithUUID:@"asdf"
                                                    buildIdentifier:@"blah"
                                                          timestamp:@1
                                                           appToken:@"token"
                                                          accountId:@213
                                                            agentId:@1123
                                                         deviceInfo:deviceInfo
                                                            appInfo:appInfo
                                                          exception:exception
                                                            threads:[@[thread] mutableCopy]
                                                          libraries:[@[library] mutableCopy]
													activityHistory:@[@"uiTestActivity"]
                                                  sessionAttributes:@{@"session":@"attribute"}
                                                    AnalyticsEvents:@[@{@"eventType":@"testEvent"}]];

    XCTAssertNoThrow([report JSONObject]);
}
-(void) testCrashDataWriter {

     NSError *error;
     PLCrashReporter *reporter = [[PLCrashReporter alloc] initWithConfiguration: [PLCrashReporterConfig defaultConfiguration]];
     NSData *reportData = [reporter generateLiveReportAndReturnError: &error];
     XCTAssertNotNil(reportData, @"Failed to generate live report: %@", error);

     PLCrashReport *report = [[PLCrashReport alloc] initWithData: reportData error: &error];
     XCTAssertNotNil(report, @"Could not parse geneated live report: %@", error);

     XCTAssertEqualObjects([[report signalInfo] name], @"SIGTRAP", @"Incorrect signal name");
     XCTAssertEqualObjects([[report signalInfo] code], @"TRAP_TRACE", @"Incorrect signal code");

     XCTAssertNoThrow([NRMACrashDataWriter writeCrashReport:report withMetaData:Nil sessionAttributes:Nil analyticsEvents:Nil], @"should not throw exception even with missing data.");

 }

 -(void) testExceptionHandlerManager {
     NRMAExceptionHandlerStartupManager* exceptionHandlerStartupManager = [[NRMAExceptionHandlerStartupManager alloc] init];
     NRMACrashDataUploader* uploader = [[NRMACrashDataUploader alloc] initWithCrashCollectorURL:nil
                                                                               applicationToken:@"token"
                                                                          connectionInformation:[NRMAAgentConfiguration connectionInformation]
                                                                                         useSSL:YES];

     XCTAssertNoThrow([exceptionHandlerStartupManager startExceptionHandler:uploader]);

     NRMACrashDataUploader* badUploader = [[NRMACrashDataUploader alloc] initWithCrashCollectorURL:nil
                                                                               applicationToken:nil
                                                                          connectionInformation:[NRMAAgentConfiguration connectionInformation]
                                                                                         useSSL:YES];


     XCTAssertNoThrow([exceptionHandlerStartupManager startExceptionHandler:badUploader], @"missing application token should not throw exception");

 }

 -(void) testNRMACrashReportFileManager{
     PLCrashReporter *reporter = [[PLCrashReporter alloc] initWithConfiguration: [PLCrashReporterConfig defaultConfiguration]];
     NRMAExceptionHandlerStartupManager* exceptionHandlerStartupManager = [[NRMAExceptionHandlerStartupManager alloc] init];
     NRMACrashDataUploader* uploader = [[NRMACrashDataUploader alloc] initWithCrashCollectorURL:@"google.com"
                                                                               applicationToken:@"token"
                                                                          connectionInformation:[NRMAAgentConfiguration connectionInformation]
                                                                                         useSSL:YES];

     [exceptionHandlerStartupManager startExceptionHandler:uploader];


     NRMACrashReportFileManager* fileManager = [[NRMACrashReportFileManager alloc] init];
     NRMACrashReportFileManager* fileManagerWithReporter = [[NRMACrashReportFileManager alloc] initWithCrashReporter:reporter];

     XCTAssertNoThrow([fileManagerWithReporter processReportsWithSessionAttributes:nil analyticsEvents:nil], @"missing attributes and events should not cause exception");
     XCTAssertNoThrow([fileManager processReportsWithSessionAttributes:nil analyticsEvents:nil], @"missing attributes and events should not cause exception");
 }

@end