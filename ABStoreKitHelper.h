//
//  ABStoreKitHelper.h
//  Pastry Panic
//
//  Created by Alexander Blunck on 08.05.12.
//  Copyright (c) 2012 Ablfx. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "StoreKit/StoreKit.h"

typedef enum {kPurchaseNotAllowed, kPurchaseGeneralError}_purchaseErrorCodes;

@protocol ABStoreKitHelperDelegate <NSObject>
@optional
-(void) purchaseSucessful:(NSString*)productIdentifier;
-(void) purchaseError:(_purchaseErrorCodes)errorCode;
@end

@interface ABStoreKitHelper : NSObject <SKProductsRequestDelegate, SKPaymentTransactionObserver> {
    @private
    NSSet *productIdentifiers;
    NSMutableArray *productsArray;
}

@property (nonatomic, weak) id <ABStoreKitHelperDelegate> delegate;
@property (nonatomic) BOOL productValidated;

//Call this once in the app delegate to set up everything
+ (id) sharedHelper;

//Use this method to check if product has already been purchased
-(BOOL) isPurchased:(NSString*)productIdentifier;

//Perform Buy request (be sure to implement delegate methods)
-(void) buyProduct:(NSString*)productIdentifier;

@end
