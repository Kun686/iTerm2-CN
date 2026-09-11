//
//  iTermApplicationLanguageController.h
//  iTerm2
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NSString *iTermApplicationLanguageIdentifier NS_TYPED_EXTENSIBLE_ENUM;

extern iTermApplicationLanguageIdentifier const iTermApplicationLanguageIdentifierSimplifiedChinese;
extern iTermApplicationLanguageIdentifier const iTermApplicationLanguageIdentifierEnglish;
extern iTermApplicationLanguageIdentifier const iTermApplicationLanguageIdentifierSystem;
extern NSString *const iTermApplicationLanguagePreferenceKey;

@interface iTermApplicationLanguageController : NSObject

@property(class, nonatomic, readonly, copy) NSArray<iTermApplicationLanguageIdentifier> *supportedLanguageIdentifiers;
@property(class, nonatomic, readonly, copy) iTermApplicationLanguageIdentifier selectedLanguageIdentifier;

+ (NSString *)localizedDisplayNameForLanguageIdentifier:(iTermApplicationLanguageIdentifier)identifier;

+ (BOOL)applySavedLanguagePreferenceWithError:(NSError * _Nullable * _Nullable)error;

+ (BOOL)setSelectedLanguageIdentifier:(iTermApplicationLanguageIdentifier)identifier
                             didChange:(BOOL * _Nullable)didChange
                                 error:(NSError * _Nullable * _Nullable)error;

@end

NS_ASSUME_NONNULL_END
