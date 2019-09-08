//
//	The MIT License (MIT)
//
//	Copyright © 2019 Jacopo Filié
//
//	Permission is hereby granted, free of charge, to any person obtaining a copy
//	of this software and associated documentation files (the "Software"), to deal
//	in the Software without restriction, including without limitation the rights
//	to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//	copies of the Software, and to permit persons to whom the Software is
//	furnished to do so, subject to the following conditions:
//
//	The above copyright notice and this permission notice shall be included in all
//	copies or substantial portions of the Software.
//
//	THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//	IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//	FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//	AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//	LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//	OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
//	SOFTWARE.
//

////////////////////////////////////////////////////////////////////////////////////////////////////

#import "JFObjectIdentifier.h"

#import "JFReferences.h"
#import "JFShortcuts.h"

////////////////////////////////////////////////////////////////////////////////////////////////////

NS_ASSUME_NONNULL_BEGIN

////////////////////////////////////////////////////////////////////////////////////////////////////

// =================================================================================================
// MARK: Macros
// =================================================================================================

#define LegacyRegistry NSMutableDictionary<Reference*, NSNumber*>
#define Registry NSMapTable<id<NSObject>, NSNumber*>

#if JF_WEAK_ENABLED
#	define Reference JFWeakReference<id<NSObject>>
#else
#	define Reference JFUnsafeReference<id<NSObject>>
#endif

////////////////////////////////////////////////////////////////////////////////////////////////////

#pragma mark -

// =================================================================================================
// MARK: Constants
// =================================================================================================

static NSTimeInterval kJFObjectIdentifierLegacyImplementationCleanRegistryDelay = 10 /* seconds */;

////////////////////////////////////////////////////////////////////////////////////////////////////

#pragma mark -

@protocol JFObjectIdentifierImplementation <NSObject>

// =================================================================================================
// MARK: Methods - Identifiers
// =================================================================================================

- (void)clearID:(id<NSObject>)object;
- (NSUInteger)getID:(id<NSObject>)object;

@end

////////////////////////////////////////////////////////////////////////////////////////////////////

#pragma mark -

@interface JFObjectIdentifier (/* Private */)

// =================================================================================================
// MARK: Properties - Strategy
// =================================================================================================

@property (strong, nonatomic, readonly) id<JFObjectIdentifierImplementation> implementation;

@end

////////////////////////////////////////////////////////////////////////////////////////////////////

#pragma mark -

API_AVAILABLE(ios(8.0), macos(10.8))
@interface JFObjectIdentifierImplementation : NSObject <JFObjectIdentifierImplementation>

// =================================================================================================
// MARK: Properties - Identifiers
// =================================================================================================

@property (assign, readonly, getter=getAndIncrementNextFreeID) NSUInteger nextFreeID;
@property (strong, nonatomic, readonly) Registry* registry;

@end

////////////////////////////////////////////////////////////////////////////////////////////////////

#pragma mark -

@interface JFObjectIdentifierLegacyImplementation : NSObject <JFObjectIdentifierImplementation>

// =================================================================================================
// MARK: Properties - Identifiers
// =================================================================================================

@property (assign) BOOL needsCleanRegistry;
@property (assign, readonly, getter=getAndIncrementNextFreeID) NSUInteger nextFreeID;
@property (strong, nonatomic, readonly) LegacyRegistry* registry;

// =================================================================================================
// MARK: Methods - Identifiers
// =================================================================================================

- (void)cleanRegistry;
- (void)cleanRegistryIfNeeded;
- (Reference* __nullable)referenceForObject:(id<NSObject>)object;

@end

////////////////////////////////////////////////////////////////////////////////////////////////////

#pragma mark -

@implementation JFObjectIdentifier

// =================================================================================================
// MARK: Fields - Strategy
// =================================================================================================

@synthesize implementation = _implementation;

// =================================================================================================
// MARK: Properties - Memory
// =================================================================================================

+ (JFObjectIdentifier*)sharedInstance
{
	static JFObjectIdentifier* retObj;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		retObj = [JFObjectIdentifier new];
	});
	return retObj;
}

// =================================================================================================
// MARK: Methods - Memory
// =================================================================================================

- (instancetype)init
{
	self = [super init];
	
	id<JFObjectIdentifierImplementation> implementation;
	if(@available(macOS 10.8, *))
		implementation = [JFObjectIdentifierImplementation new];
	else
		implementation = [JFObjectIdentifierLegacyImplementation new];
	
	_implementation = implementation;

	return self;
}

// =================================================================================================
// MARK: Methods - Identifiers
// =================================================================================================

+ (void)clearID:(id<NSObject>)object
{
	[JFObjectIdentifier.sharedInstance clearID:object];
}

+ (NSUInteger)getID:(id<NSObject>)object
{
	return [JFObjectIdentifier.sharedInstance getID:object];
}

- (void)clearID:(id<NSObject>)object
{
	[self.implementation clearID:object];
}

- (NSUInteger)getID:(id<NSObject>)object
{
	return [self.implementation getID:object];
}

@end

////////////////////////////////////////////////////////////////////////////////////////////////////

#pragma mark -

@implementation JFObjectIdentifierImplementation

// =================================================================================================
// MARK: Fields - Identifiers
// =================================================================================================

@synthesize nextFreeID = _nextFreeID;
@synthesize registry = _registry;

// =================================================================================================
// MARK: Properties - Identifiers
// =================================================================================================

- (NSUInteger)getAndIncrementNextFreeID
{
	@synchronized(self)
	{
		return _nextFreeID++;
	}
}

// =================================================================================================
// MARK: Methods - Memory
// =================================================================================================

- (instancetype)init
{
	self = [super init];
	
	_nextFreeID = 0;
	_registry = [Registry mapTableWithKeyOptions:(NSMapTableWeakMemory | NSMapTableObjectPointerPersonality) valueOptions:NSMapTableStrongMemory];
	
	return self;
}

// =================================================================================================
// MARK: Methods - Identifiers
// =================================================================================================

- (void)clearID:(id<NSObject>)object
{
	Registry* registry = self.registry;
	@synchronized(registry)
	{
		[registry removeObjectForKey:object];
	}
}

- (NSUInteger)getID:(id<NSObject>)object
{
	Registry* registry = self.registry;
	@synchronized(registry)
	{
		NSUInteger retVal;
		NSNumber* value = [registry objectForKey:object];
		if(value != nil)
			retVal = [value unsignedIntegerValue];
		else
		{
			retVal = [self getAndIncrementNextFreeID];
			[registry setObject:@(retVal) forKey:object];
		}
		return retVal;
	}
}

@end

////////////////////////////////////////////////////////////////////////////////////////////////////

#pragma mark -

@implementation JFObjectIdentifierLegacyImplementation

// =================================================================================================
// MARK: Fields - Identifiers
// =================================================================================================

@synthesize needsCleanRegistry = _needsCleanRegistry;
@synthesize nextFreeID = _nextFreeID;
@synthesize registry = _registry;

// =================================================================================================
// MARK: Properties - Identifiers
// =================================================================================================

- (BOOL)needsCleanRegistry
{
	@synchronized(self)
	{
		return _needsCleanRegistry;
	}
}

- (void)setNeedsCleanRegistry:(BOOL)needsCleanRegistry
{
	@synchronized(self)
	{
		if(_needsCleanRegistry == needsCleanRegistry)
			return;
		
		_needsCleanRegistry = needsCleanRegistry;
	}
	
	if(!needsCleanRegistry)
		return;
	
#if JF_WEAK_ENABLED
	JFWeakifySelf;
#else
	__typeof(self) __strong weakSelf = self;
#endif
	
	dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(kJFObjectIdentifierLegacyImplementationCleanRegistryDelay * NSEC_PER_SEC)), dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
		[weakSelf cleanRegistryIfNeeded];
	});
}

- (NSUInteger)getAndIncrementNextFreeID
{
	@synchronized(self)
	{
		return _nextFreeID++;
	}
}

// =================================================================================================
// MARK: Methods - Memory
// =================================================================================================

- (instancetype)init
{
	self = [super init];
	
	_needsCleanRegistry = NO;
	_nextFreeID = 0;
	_registry = [LegacyRegistry new];
	
	return self;
}

// =================================================================================================
// MARK: Methods - Identifiers
// =================================================================================================

- (void)cleanRegistry
{
	LegacyRegistry* registry = self.registry;
	@synchronized(registry)
	{
		for(Reference* reference in registry.allKeys)
		{
			if(!reference.object)
				[registry removeObjectForKey:reference];
		}
	}
}

- (void)cleanRegistryIfNeeded
{
	@synchronized(self)
	{
		if(![self needsCleanRegistry])
			return;
		
		self.needsCleanRegistry = NO;
	}
	
	[self cleanRegistry];
}

- (void)clearID:(id<NSObject>)object
{
	LegacyRegistry* registry = self.registry;
	@synchronized(registry)
	{
		Reference* reference = [self referenceForObject:object];
		if(reference)
			[registry removeObjectForKey:reference];
	}
}

- (NSUInteger)getID:(id<NSObject>)object
{
	LegacyRegistry* registry = self.registry;
	@synchronized(registry)
	{
		NSUInteger retVal;
		Reference* reference = [self referenceForObject:object];
		NSNumber* value = (reference ? [registry objectForKey:reference] : nil);
		if(value != nil)
			retVal = [value unsignedIntegerValue];
		else
		{
			retVal = [self getAndIncrementNextFreeID];
			[registry setObject:@(retVal) forKey:(reference ?: [Reference referenceWithObject:object])];
		}
		return retVal;
	}
}

- (Reference* __nullable)referenceForObject:(id<NSObject>)object
{
	Reference* retObj = nil;
	BOOL needsCleanRegistry = NO;
	
	for(Reference* reference in self.registry.allKeys)
	{
		NSObject* referencedObject = reference.object;
		if(!referencedObject)
		{
			needsCleanRegistry = YES;
			continue;
		}
		
		if(referencedObject == object)
		{
			retObj = reference;
			break;
		}
	}
	
	if(needsCleanRegistry)
		self.needsCleanRegistry = YES;
	
	return retObj;
}

@end

////////////////////////////////////////////////////////////////////////////////////////////////////

NS_ASSUME_NONNULL_END

////////////////////////////////////////////////////////////////////////////////////////////////////
