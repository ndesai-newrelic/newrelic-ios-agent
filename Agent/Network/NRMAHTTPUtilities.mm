//
//  NRMANetworkUtilites.m
//  NewRelicAgent
//
//  Created on 8/28/14.
//  Copyright © 2023 New Relic. All rights reserved.
//

#include <iostream>
#include <sstream>

#include <Connectivity/Facade.hpp>

#import "NRMABase64.h"
#import "NRMAHTTPUtilities.h"
#import "NRMAHarvestController.h"
#import "NRMAFlags.h"
#import "NRMAPayloadContainer+cppInterface.h"
#import "NRMAAssociate.h"
#import "NRMANetworkFacade.h"
#import "NRMAPayloadContainer.h"
#import "NRMAMetric.h"
#import "NRMATaskQueue.h"
#import "NRConstants.h"
#import "NRMATraceContext.h"
#import "W3CTraceParent.h"
#import "W3CTraceState.h"

@implementation NRMAHTTPUtilities
+ (NSMutableURLRequest*) addCrossProcessIdentifier:(NSURLRequest*)request {

    NSMutableURLRequest* mutableRequest = [self makeMutable:request];

    NSString* xprocess = [NRMAHarvestController configuration].cross_process_id;

    if (xprocess.length) {
        [mutableRequest setValue:xprocess
              forHTTPHeaderField:NEW_RELIC_CROSS_PROCESS_ID_HEADER_KEY];
    }

    return mutableRequest;
}

+ (NSMutableURLRequest*) makeMutable:(NSURLRequest*)request {
    __autoreleasing NSMutableURLRequest* mutableRequest = nil;
    if ([request isKindOfClass:[NSMutableURLRequest class]]) {
        mutableRequest = (NSMutableURLRequest*)request;
    } else {
        // A copy is retained.
        mutableRequest = [request mutableCopy];
    }
    return mutableRequest;
}


+ (NSMutableURLRequest*) addConnectivityHeaderAndPayload:(NSURLRequest*)request {
    NSMutableURLRequest* mutableRequest = [NRMAHTTPUtilities makeMutable:request];
    [NRMAHTTPUtilities attachPayload:[NRMAHTTPUtilities addConnectivityHeader:mutableRequest]
                                  to:mutableRequest];
    return mutableRequest;

}

+ (NRMAPayloadContainer*) addConnectivityHeader:(NSMutableURLRequest*)request {

    if(![NRMAFlags shouldEnableDistributedTracing]) { return nil; }
    
    NRMAPayloadContainer *payloadContainer = [NRMAHTTPUtilities generatePayload];
    if(payloadContainer == nil) { return nil; }
    
    NSDictionary<NSString*, NSString*> *connectivityHeaders = [NRMAHTTPUtilities generateConnectivityHeadersWithPayload:payloadContainer];
    
    if(connectivityHeaders[NEW_RELIC_DISTRIBUTED_TRACING_HEADER_KEY].length) {
        [request setValue:connectivityHeaders[NEW_RELIC_DISTRIBUTED_TRACING_HEADER_KEY]
       forHTTPHeaderField:NEW_RELIC_DISTRIBUTED_TRACING_HEADER_KEY];
    }
    
    BOOL dtError = false;
    if(connectivityHeaders[W3C_DISTRIBUTED_TRACING_PARENT_HEADER_KEY].length) {
        [request setValue:connectivityHeaders[W3C_DISTRIBUTED_TRACING_PARENT_HEADER_KEY]
       forHTTPHeaderField:W3C_DISTRIBUTED_TRACING_PARENT_HEADER_KEY];
    } else {
        dtError = true;
    }
    
    if(connectivityHeaders[W3C_DISTRIBUTED_TRACING_STATE_HEADER_KEY].length) {
        [request setValue:connectivityHeaders[W3C_DISTRIBUTED_TRACING_STATE_HEADER_KEY]
       forHTTPHeaderField:W3C_DISTRIBUTED_TRACING_STATE_HEADER_KEY];
    } else {
        dtError = true;
    }
        
    if (dtError) {
        [NRMATaskQueue queue:[[NRMAMetric alloc] initWithName:kNRSupportabilityDistributedTracing@"/Create/Exception"
                           value:@1
                       scope:@""]];
    } else {
        [NRMATaskQueue queue:[[NRMAMetric alloc] initWithName:kNRSupportabilityDistributedTracing@"/Create/Success"
                           value:@1
                       scope:@""]];
    }
        
    return payloadContainer;
}

+ (NRMAPayloadContainer *) generatePayload {
    std::unique_ptr<NewRelic::Connectivity::Payload> payload = nullptr;
    payload = NewRelic::Connectivity::Facade::getInstance().startTrip();
    
    if(payload == nullptr) { return nil; }
    payload->setDistributedTracing(true);
    return [[NRMAPayloadContainer alloc] initWithPayload:std::move(payload)];
}

+ (NSDictionary<NSString*, NSString*> *) generateConnectivityHeadersWithPayload:(NRMAPayloadContainer*)payloadContainer {
    NSString *payloadHeader;
    const std::unique_ptr<NewRelic::Connectivity::Payload>& payload = [payloadContainer getReference];
    
    if(payload != nullptr) {
        auto json = payload->toJSON();
        std::stringstream s;
        s << json;
        
        payloadHeader = [NSString stringWithCString:s.str().c_str()
                                           encoding:NSUTF8StringEncoding];
    }
    
    NRMATraceContext *traceContext = [[NRMATraceContext alloc] initWithPayload:payload];
    NSString *traceParent = [W3CTraceParent headerFromContext:traceContext];
    NSString *traceState = [W3CTraceState headerFromContext:traceContext];
    NSString *encodedPayloadHeader = [NRMABase64 encodeFromData:[payloadHeader dataUsingEncoding:NSUTF8StringEncoding]];
    
    return @{NEW_RELIC_DISTRIBUTED_TRACING_HEADER_KEY:encodedPayloadHeader,
             W3C_DISTRIBUTED_TRACING_PARENT_HEADER_KEY:traceParent,
             W3C_DISTRIBUTED_TRACING_STATE_HEADER_KEY:traceState};
}

+ (void) attachPayload:(NRMAPayloadContainer*)payload to:(id)object {
    [NRMAAssociate attach:payload to:object with:kNRMA_ASSOCIATED_PAYLOAD_KEY];
}

+ (std::unique_ptr<NewRelic::Connectivity::Payload>) retrievePayload:(id)object {
    id associatedObject = [NRMAAssociate retrieveFrom:object
                                    with:kNRMA_ASSOCIATED_PAYLOAD_KEY];

    [NRMAAssociate removeFrom:object
                         with:kNRMA_ASSOCIATED_PAYLOAD_KEY];

    if ([associatedObject isKindOfClass:[NRMAPayloadContainer class]]) {

        return [((NRMAPayloadContainer* )associatedObject) pullPayload];
    }

    return std::unique_ptr<NewRelic::Connectivity::Payload>(nullptr);
}

@end