// AOSP-inspired trie engine for Dictus. Apache 2.0.
// ObjC++ implementation -- bridges C++ trie engine to ObjC for Swift interop.

#import "AOSPTrieBridge.h"

#include "dictus_trie.h"
#include "dictus_scorer.h"
#include "dictus_proximity.h"

#include <vector>

// ---------- AOSPTrieResult ----------

@implementation AOSPTrieResult
@end

// ---------- AOSPTrieBridge ----------

@implementation AOSPTrieBridge {
    dictus::Trie _trie;
    dictus::Scorer _scorer;
    dictus::ProximityMap _proximityMap;
    BOOL _loaded;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _loaded = NO;
    }
    return self;
}

- (void)dealloc {
    _trie.unload();
}

- (BOOL)loadDictionaryAtPath:(NSString *)path {
    _trie.unload();
    _loaded = NO;

    bool success = _trie.loadMmap([path UTF8String]);
    if (success) {
        _scorer.setProximityMap(&_proximityMap);
        _loaded = YES;
    }
    return success ? YES : NO;
}

- (void)unloadDictionary {
    _trie.unload();
    _loaded = NO;
}

- (BOOL)isLoaded {
    return _loaded;
}

/// Helper: convert NSString to uint16_t buffer.
/// Returns the number of UTF-16 code units written.
static int convertString(NSString *str, uint16_t *buffer, int bufferSize) {
    NSUInteger len = [str length];
    if ((int)len > bufferSize) len = bufferSize;
    [str getCharacters:buffer range:NSMakeRange(0, len)];
    return (int)len;
}

- (nullable AOSPTrieResult *)spellCheck:(NSString *)word maxEditDistance:(float)maxDist {
    if (!_loaded || [word length] == 0) return nil;

    // Convert input word to UTF-16 buffer
    uint16_t inputBuf[256];
    int inputLen = convertString(word, inputBuf, 256);
    if (inputLen == 0) return nil;

    // Run correction
    std::vector<dictus::Candidate> candidates = _scorer.correct(
        _trie, inputBuf, inputLen, maxDist, 5
    );

    if (candidates.empty()) return nil;

    // Check if first result matches the input (word is correct)
    NSString *firstWord = [NSString stringWithUTF8String:candidates[0].word];
    if ([firstWord isEqualToString:word]) return nil;

    // Build result
    AOSPTrieResult *result = [[AOSPTrieResult alloc] init];
    result.correction = firstWord;
    result.score = candidates[0].score;

    NSMutableArray<NSString *> *alts = [NSMutableArray array];
    for (size_t i = 1; i < candidates.size() && i <= 2; i++) {
        NSString *alt = [NSString stringWithUTF8String:candidates[i].word];
        [alts addObject:alt];
    }
    result.alternatives = [alts copy];

    return result;
}

- (BOOL)wordExists:(NSString *)word {
    if (!_loaded || [word length] == 0) return NO;

    uint16_t buf[256];
    int len = convertString(word, buf, 256);
    return _trie.wordExists(buf, len) ? YES : NO;
}

- (NSInteger)getFrequency:(NSString *)word {
    if (!_loaded || [word length] == 0) return 0;

    uint16_t buf[256];
    int len = convertString(word, buf, 256);
    return (NSInteger)_trie.getFrequency(buf, len);
}

- (NSUInteger)wordCount {
    if (!_loaded) return 0;
    return (NSUInteger)_trie.wordCount();
}

- (void)setProximityMapAZERTY {
    _proximityMap.buildAZERTY();
    if (_loaded) {
        _scorer.setProximityMap(&_proximityMap);
    }
}

- (void)setProximityMapQWERTY {
    _proximityMap.buildQWERTY();
    if (_loaded) {
        _scorer.setProximityMap(&_proximityMap);
    }
}

@end
