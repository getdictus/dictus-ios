// AOSP-inspired trie engine for Dictus. Apache 2.0.
// ObjC bridge header -- exposes C++ trie engine to Swift via bridging header.
// No C++ types leak into this header so it can be imported from Swift.

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Result from spell check. nil means word is correctly spelled.
@interface AOSPTrieResult : NSObject
@property (nonatomic, copy) NSString *correction;
@property (nonatomic, copy) NSArray<NSString *> *alternatives;
@property (nonatomic) float score;
@end

@interface AOSPTrieBridge : NSObject

- (BOOL)loadDictionaryAtPath:(NSString *)path;
- (void)unloadDictionary;
- (BOOL)isLoaded;

/// Returns nil if word is correctly spelled or not found.
/// Returns AOSPTrieResult with best correction, up to 2 alternatives, and score.
- (nullable AOSPTrieResult *)spellCheck:(NSString *)word maxEditDistance:(float)maxDist;

/// Check if word exists in dictionary.
- (BOOL)wordExists:(NSString *)word;

/// Get frequency of word (0 if not found).
- (NSInteger)getFrequency:(NSString *)word;

/// Word count from the loaded dictionary header.
- (NSUInteger)wordCount;

/// Set keyboard layout for proximity scoring.
- (void)setProximityMapAZERTY;
- (void)setProximityMapQWERTY;

@end

NS_ASSUME_NONNULL_END
