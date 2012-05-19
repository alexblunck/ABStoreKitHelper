//
//  ABStoreKitHelper.m
//  Pastry Panic
//
//  Created by Alexander Blunck on 08.05.12.
//  Copyright (c) 2012 Ablfx. All rights reserved.
//

#import "ABStoreKitHelper.h"
#import "NSData+AES256.h"

#define APPNAME @"MyAppName"
#define AESKEY @"RandomKeyHere"

@implementation ABStoreKitHelper

@synthesize delegate=_delegate, productValidated=_productValidated;

//Singleton Setup
+ (id)sharedHelper
{
    static dispatch_once_t pred;
    static ABStoreKitHelper *helper = nil;
    
    dispatch_once(&pred, ^{ helper = [[self alloc] init]; });
    return helper;
}

- (id)init {
    if ((self = [super init])) {                
        
        NSLog(@"ABStoreKitHelper: Started");
        
        productsArray = [NSMutableArray new];
        
        productIdentifiers = [NSSet setWithObjects:@"feature.id's.here", nil];
        
        [[SKPaymentQueue defaultQueue] addTransactionObserver:self];
        
        self.productValidated = NO;
        [self getNewProductData];
    
    }
    return self;
}

-(void) getNewProductData {
    if (!self.productValidated) {
        SKProductsRequest *request = [[SKProductsRequest alloc] initWithProductIdentifiers:productIdentifiers];
        request.delegate = self;
        [request start];
        
        [self performSelector:@selector(getNewProductData) withObject:nil afterDelay:30];
    }
}

-(BOOL) isPurchased:(NSString*)productIdentifier {
    return [self loadBoolForKey:productIdentifier];
}

-(void) buyProduct:(NSString*)productIdentifier {
    
    if (self.productValidated) {
        SKProduct *productToBuy;
        for (SKProduct *product in productsArray) {
            if ([product.productIdentifier isEqualToString:productIdentifier]) {
                productToBuy = product;
            }
        }
        
        SKPayment *payment = [SKPayment paymentWithProduct:productToBuy];
        
        //Check if user is allowed to make payments (e.g. Parental Settings)
        if ([SKPaymentQueue canMakePayments]) {
            [[SKPaymentQueue defaultQueue] addPayment:payment];
        } else {
            if ([self.delegate respondsToSelector:@selector(purchaseError:)]) {
                [self.delegate purchaseError:kPurchaseNotAllowed];
            }
        }
    } else {
        if ([self.delegate respondsToSelector:@selector(purchaseError:)]) {
            [self.delegate purchaseError:kPurchaseGeneralError];
        }
    }
    
}

#pragma mark SKProductsRequestDelegate Methods
-(void) productsRequest:(SKProductsRequest *)request didReceiveResponse:(SKProductsResponse *)response {
    NSLog(@"ABStoreKitHelper: Checking if Product Identifiers are valid");
    for (SKProduct *product in response.products) {
        NSLog(@"ProductIdentifier: %@ Valid!", product.productIdentifier);
        [productsArray addObject:product];
        self.productValidated = YES;
    }
}

#pragma mark SKPaymentTransactionObserver Methods
//Handeling Transactions
-(void) paymentQueue:(SKPaymentQueue *)queue updatedTransactions:(NSArray *)transactions {
    NSLog(@"ABStoreKitHelper: Transaction Update->");
    
    for (SKPaymentTransaction *transaction in transactions) {
        
        NSString *transactionUpdate;
        
        switch (transaction.transactionState) {
            case SKPaymentTransactionStateFailed:
                transactionUpdate = @"FAILED";
                [queue finishTransaction:transaction];
                if ([self.delegate respondsToSelector:@selector(purchaseError:)]) {
                    [self.delegate purchaseError:kPurchaseGeneralError];
                }
                break;
             case SKPaymentTransactionStatePurchased:
                transactionUpdate = @"PURCHASED";
                [queue finishTransaction:transaction];
                [self saveBool:YES withKey:transaction.payment.productIdentifier];
                if ([self.delegate respondsToSelector:@selector(purchaseSucessful:)]) {
                    [self.delegate purchaseSucessful:transaction.payment.productIdentifier];
                }
                break;
             case SKPaymentTransactionStatePurchasing:
                transactionUpdate = @"PURCHASING";
                break;
            case SKPaymentTransactionStateRestored:
                transactionUpdate = @"RESTORED";
                [queue finishTransaction:transaction];
                if ([self.delegate respondsToSelector:@selector(purchaseSucessful:)]) {
                    [self.delegate purchaseSucessful:transaction.payment.productIdentifier];
                }
                break;
            default:
                break;
        }
        
        NSLog(@"ABStoreKitHelper: TransactionState for %@ is %@", transaction.payment.productIdentifier, transactionUpdate);
    }
    
}
-(void) paymentQueue:(SKPaymentQueue *)queue removedTransactions:(NSArray *)transactions {
    NSLog(@"ABStoreKitHelper: removed Transaction form Payment Queue");
}


#pragma mark Data Persistence Methods
-(NSString*) getPath {
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = [paths objectAtIndex:0];
    NSString *fileName = [NSString stringWithFormat:@"%@_ABStoreKitHelper.plist", APPNAME];
    NSString *path = [documentsDirectory stringByAppendingPathComponent:fileName]; 
    return path;
}

-(void) saveData:(NSData *)data withKey:(NSString *)key {
    //Check if file exits, if so init Dictionary with it's content, otherwise allocate new one
    BOOL fileExists = [[NSFileManager defaultManager] fileExistsAtPath:[self getPath]];
    NSMutableDictionary *tempDic;
    if (fileExists == NO) {
        tempDic = [[NSMutableDictionary alloc] init];
    } else {
        tempDic = [[NSMutableDictionary alloc] initWithContentsOfFile:[self getPath]];
    }
    NSData *dataKey = [[NSString stringWithString:AESKEY] dataUsingEncoding:NSUTF8StringEncoding];
    NSData *encryptedData = [data encryptedWithKey:dataKey];
    //Populate Dictionary with to save value/key and write to file
    [tempDic setObject:encryptedData forKey:key];
    [tempDic writeToFile:[self getPath] atomically:YES];
    //Release allocated Dictionary
    [tempDic release];
}

-(NSData*) loadDataForKey:(NSString*)key {
    NSMutableDictionary *tempDic = [[NSMutableDictionary alloc] initWithContentsOfFile:[self getPath]];
    NSData *loadedData = [tempDic objectForKey:key];
    NSData *dataKey = [[NSString stringWithString:AESKEY] dataUsingEncoding:NSUTF8StringEncoding];
    NSData *decryptedData = [loadedData decryptedWithKey:dataKey];
    return decryptedData;
}

-(void) saveBool:(BOOL) boolean withKey:(NSString*) key {
    NSNumber *boolNumber = [NSNumber numberWithBool:boolean];
    NSData *data = [NSKeyedArchiver archivedDataWithRootObject:boolNumber];
    [self saveData:data withKey:key];
}

-(BOOL) loadBoolForKey:(NSString*) key {
    NSData *loadedData = [self loadDataForKey:key];
    NSNumber *boolean;
    if (loadedData != NULL) {
        boolean = [NSKeyedUnarchiver unarchiveObjectWithData:loadedData];
    } else {
        boolean = [NSNumber numberWithBool:NO];
    }
    return [boolean boolValue];
}

@end