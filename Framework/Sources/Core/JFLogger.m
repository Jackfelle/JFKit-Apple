//
//	The MIT License (MIT)
//
//	Copyright © 2015-2018 Jacopo Filié
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

#import "JFLogger.h"

#import <pthread/pthread.h>

#import "JFShortcuts.h"
#import "JFStrings.h"

////////////////////////////////////////////////////////////////////////////////////////////////////

NS_ASSUME_NONNULL_BEGIN

////////////////////////////////////////////////////////////////////////////////////////////////////

@interface JFLogger ()

// =================================================================================================
// MARK: Methods - Data management
// =================================================================================================

- (NSString*)dateStringFromDate:(NSDate*)date;
- (NSURL*)fileURLForDate:(NSDate*)date;
- (NSString*)timeStringFromDate:(NSDate*)date;

// =================================================================================================
// MARK: Methods - File system management
// =================================================================================================

- (BOOL)createFileAtURL:(NSURL*)fileURL currentDate:(NSDate*)currentDate;
- (BOOL)validateFileCreationDate:(NSDate*)creationDate currentDate:(NSDate*)currentDate;

// =================================================================================================
// MARK: Methods - Service management
// =================================================================================================

- (void)logToConsole:(NSString*)message currentDate:(NSDate*)currentDate;
- (void)logToFile:(NSString*)message currentDate:(NSDate*)currentDate;

@end

////////////////////////////////////////////////////////////////////////////////////////////////////

#pragma mark -

@implementation JFLogger

// =================================================================================================
// MARK: Properties - Data
// =================================================================================================

@synthesize dateFormatter	= _dateFormatter;
@synthesize format			= _format;
@synthesize outputFilter	= _outputFilter;
@synthesize severityFilter	= _severityFilter;
@synthesize timeFormatter	= _timeFormatter;

// =================================================================================================
// MARK: Properties - File system
// =================================================================================================

@synthesize fileName	= _fileName;
@synthesize rotation	= _rotation;

// =================================================================================================
// MARK: Properties accessors - Data
// =================================================================================================

+ (NSURL*)defaultDirectoryURL
{
	static NSURL* retObj = nil;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		NSError* error = nil;
		NSURL* url = [[NSFileManager defaultManager] URLForDirectory:NSApplicationSupportDirectory inDomain:NSUserDomainMask appropriateForURL:nil create:YES error:&error];
		NSAssert(url, @"Failed to load application support directory due to error '%@'.", error.description);
		
#if JF_MACOS
		NSString* domain = AppInfoIdentifier;
		NSAssert(domain, @"Bundle identifier not found!");
		url = [url URLByAppendingPathComponent:domain];
#endif
		
		retObj = [url URLByAppendingPathComponent:@"Logs"];
	});
	return retObj;
}

- (NSDateFormatter*)dateFormatter
{
	@synchronized(self)
	{
		if(!_dateFormatter)
		{
			NSDateFormatter* dateFormatter = [NSDateFormatter new];
			dateFormatter.dateFormat = @"yyyy/MM/dd";
			dateFormatter.locale = [NSLocale currentLocale];
			dateFormatter.timeZone = [NSTimeZone defaultTimeZone];
			_dateFormatter = dateFormatter;
		}
		return _dateFormatter;
	}
}

- (void)setDateFormatter:(NSDateFormatter* __nullable)dateFormatter
{
	@synchronized(self)
	{
		_dateFormatter = dateFormatter;
	}
}

- (NSString*)format
{
	@synchronized(self)
	{
		return [_format copy];
	}
}

- (void)setFormat:(NSString* __nullable)format
{
	if(!format)
		format = JFEmptyString;
	
	@synchronized(self)
	{
		_format = [format copy];
	}
}

- (NSDateFormatter*)timeFormatter
{
	@synchronized(self)
	{
		if(!_timeFormatter)
		{
			NSDateFormatter* timeFormatter = [NSDateFormatter new];
			timeFormatter.dateFormat = @"HH:mm:ss.SSS";
			timeFormatter.locale = [NSLocale currentLocale];
			timeFormatter.timeZone = [NSTimeZone defaultTimeZone];
			_timeFormatter = timeFormatter;
		}
		return _timeFormatter;
	}
}

- (void)setTimeFormatter:(NSDateFormatter* __nullable)timeFormatter
{
	@synchronized(self)
	{
		_timeFormatter = timeFormatter;
	}
}

// =================================================================================================
// MARK: Properties accessors - File system
// =================================================================================================

- (NSString*)fileName
{
	@synchronized(self)
	{
		if(!_fileName)
			_fileName = @"Log.log";
		return [_fileName copy];
	}
}

- (void)setFileName:(NSString* __nullable)fileName
{
	@synchronized(self)
	{
		_fileName = [fileName copy];
	}
}

// =================================================================================================
// MARK: Methods - Memory management
// =================================================================================================

- (instancetype)init
{
	self = [super init];
	if(self)
	{
		_outputFilter = JFLoggerOutputAll;
		_rotation = JFLoggerRotationNone;
#if DEBUG
		_severityFilter = JFLoggerSeverityDebug;
#else
		_severityFilter = JFLoggerSeverityInfo;
#endif
	}
	return self;
}

// =================================================================================================
// MARK: Methods - Data management
// =================================================================================================

+ (NSString*)stringFromTags:(JFLoggerTags)tags
{
	if(tags == JFLoggerTagsNone)
		return JFEmptyString;
	
	// Prepares the temporary buffer.
	NSMutableArray* tagStrings = [NSMutableArray arrayWithCapacity:13];
	
	// Inserts each requested hashtag.
	if(tags & JFLoggerTagsAttention)	[tagStrings addObject:@"#Attention"];
	if(tags & JFLoggerTagsClue)			[tagStrings addObject:@"#Clue"];
	if(tags & JFLoggerTagsComment)		[tagStrings addObject:@"#Comment"];
	if(tags & JFLoggerTagsCritical)		[tagStrings addObject:@"#Critical"];
	if(tags & JFLoggerTagsDeveloper)	[tagStrings addObject:@"#Developer"];
	if(tags & JFLoggerTagsError)		[tagStrings addObject:@"#Error"];
	if(tags & JFLoggerTagsFileSystem)	[tagStrings addObject:@"#FileSystem"];
	if(tags & JFLoggerTagsHardware)		[tagStrings addObject:@"#Hardware"];
	if(tags & JFLoggerTagsMarker)		[tagStrings addObject:@"#Marker"];
	if(tags & JFLoggerTagsNetwork)		[tagStrings addObject:@"#Network"];
	if(tags & JFLoggerTagsSecurity)		[tagStrings addObject:@"#Security"];
	if(tags & JFLoggerTagsSystem)		[tagStrings addObject:@"#System"];
	if(tags & JFLoggerTagsUser)			[tagStrings addObject:@"#User"];
	
	return [tagStrings componentsJoinedByString:@" "];
}

- (NSString*)dateStringFromDate:(NSDate*)date
{
	return [self stringFromDate:date formatter:self.dateFormatter];
}

- (NSString*)stringFromDate:(NSDate*)date formatter:(NSDateFormatter*)formatter
{
	// NSDateFormatter is thread safe only in iOS 7.0 or later and on macOS 10.9 or later. On macOS, only the 64-bit architecture implementation is thread safe.
	
#if JF_IOS
	BOOL threadSafe = YES;
#else
	BOOL threadSafe = NO;
#	if JF_ARCH64
	if(@available(macOS 10.9, *))
		threadSafe = YES;
#	endif
#endif
	
	if(threadSafe)
		return [formatter stringFromDate:date];
	
	@synchronized(formatter)
	{
		return [formatter stringFromDate:date];
	}
}

- (NSString*)stringFromTags:(JFLoggerTags)tags
{
	return [self.class stringFromTags:tags];
}

- (NSURL*)fileURLForDate:(NSDate*)date
{
	NSURL* folderURL = [self.class defaultDirectoryURL];
	NSString* fileName = self.fileName;
	
	NSCalendarUnit component = 0;
	BOOL shouldAppendSuffix = YES;
	switch(self.rotation)
	{
		case JFLoggerRotationHour:
		{
			component = NSCalendarUnitHour;
			break;
		}
		case JFLoggerRotationDay:
		{
			component = NSCalendarUnitDay;
			break;
		}
		case JFLoggerRotationWeek:
		{
			component = NSCalendarUnitWeekOfMonth;
			break;
		}
		case JFLoggerRotationMonth:
		{
			component = NSCalendarUnitMonth;
			break;
		}
		default:
		{
			shouldAppendSuffix = NO;
			break;
		}
	}

	if(shouldAppendSuffix)
	{
		NSString* extension = fileName.pathExtension;
		NSString* suffix = JFStringFromNSInteger([NSCalendar.currentCalendar component:component fromDate:date]);
		fileName = [fileName.stringByDeletingPathExtension stringByAppendingFormat:@"-%@.%@", suffix, extension];
	}
	
	return [folderURL URLByAppendingPathComponent:fileName];
}

- (NSString*)timeStringFromDate:(NSDate*)date
{
	return [self stringFromDate:date formatter:self.timeFormatter];
}

// =================================================================================================
// MARK: Methods - File system management
// =================================================================================================

- (BOOL)createFileAtURL:(NSURL*)fileURL currentDate:(NSDate*)currentDate
{
	NSFileManager* fileManager = [NSFileManager defaultManager];
	NSString* filePath = fileURL.path;
	
	// Checks if the log file exists.
	BOOL fileExists = [fileManager fileExistsAtPath:filePath];
	if(fileExists)
	{
		// Reads the creation date of the existing log file and check if it's still valid. If the file attributes are not readable, it assumes that the log file is still valid.
		NSError* error = nil;
		NSDictionary* attributes = [fileManager attributesOfItemAtPath:filePath error:&error];
		if(!attributes)
		{
			NSString* errorString = (error ? [NSString stringWithFormat:@" due to error '%@'", error.description] : JFEmptyString);
			NSString* tagsString = [self stringFromTags:(JFLoggerTags)(JFLoggerTagsError | JFLoggerTagsFileSystem)];
			NSLog(@"%@: could not read attributes of log file at path '%@'%@. The existing file will be considered still valid. %@", ClassName, filePath, errorString, tagsString);
			return YES;
		}
		
		// If the creation date is not found, it assumes that the log file is still valid.
		NSDate* creationDate = [attributes objectForKey:NSFileCreationDate];
		if(!creationDate)
		{
			NSString* tagsString = [self stringFromTags:(JFLoggerTags)(JFLoggerTagsError | JFLoggerTagsFileSystem)];
			NSLog(@"%@: could not read creation date of log file at path '%@'. The existing file will be considered still valid. %@", ClassName, filePath, tagsString);
			return YES;
		}
		
		// If the log file is not valid anymore, it goes on with the method and replaces it with a new empty one.
		if([self validateFileCreationDate:creationDate currentDate:currentDate])
			return YES;
	}
	else
	{
		NSString* folderPath = filePath.stringByDeletingLastPathComponent;
		
		// Checks if the parent folder of the log file exists.
		if(![fileManager fileExistsAtPath:folderPath])
		{
			// Creates the parent folder.
			NSError* error = nil;
			if(![fileManager createDirectoryAtPath:folderPath withIntermediateDirectories:YES attributes:nil error:&error])
			{
				NSString* errorString = (error ? [NSString stringWithFormat:@" due to error '%@'", error.description] : JFEmptyString);
				NSString* tagsString = [self stringFromTags:(JFLoggerTags)(JFLoggerTagsError | JFLoggerTagsFileSystem)];
				NSLog(@"%@: could not create logs folder at path '%@'%@. %@", ClassName, folderPath, errorString, tagsString);
				return NO;
			}
		}
	}
	
	// Creates the empty log file.
	NSError* error = nil;
	if(![NSData.data writeToFile:filePath options:NSDataWritingAtomic error:&error])
	{
		NSString* errorString = (error ? [NSString stringWithFormat:@" due to error '%@'", [error description]] : JFEmptyString);
		NSString* tagsString = [self stringFromTags:(JFLoggerTags)(JFLoggerTagsError | JFLoggerTagsFileSystem)];
		NSLog(@"%@: could not create log file at path '%@'%@. %@", ClassName, filePath, errorString, tagsString);
		return fileExists;
	}
	
	return YES;
}

- (BOOL)validateFileCreationDate:(NSDate*)creationDate currentDate:(NSDate*)currentDate
{
	NSCalendar* calendar = [NSCalendar currentCalendar];
	NSCalendarUnit components = (NSCalendarUnitEra | NSCalendarUnitYear | NSCalendarUnitMonth | NSCalendarUnitWeekOfMonth | NSCalendarUnitDay | NSCalendarUnitHour);
	
	NSDateComponents* creationDateComponents = [calendar components:components fromDate:creationDate];
	NSDateComponents* currentDateComponents = [calendar components:components fromDate:currentDate];

	if((creationDateComponents.era != currentDateComponents.era) || (creationDateComponents.year != currentDateComponents.year))
		return NO;
	
	switch(self.rotation)
	{
		case JFLoggerRotationHour:
		{
			if(creationDateComponents.hour != currentDateComponents.hour)
				return NO;
		}
		case JFLoggerRotationDay:
		{
			if(creationDateComponents.day != currentDateComponents.day)
				return NO;
		}
		case JFLoggerRotationWeek:
		{
			if(creationDateComponents.weekOfMonth != currentDateComponents.weekOfMonth)
				return NO;
		}
		case JFLoggerRotationMonth:
		{
			if(creationDateComponents.month != currentDateComponents.month)
				return NO;
		}
		default:
			return YES;
	}
}

// =================================================================================================
// MARK: Methods - Service management
// =================================================================================================

- (void)log:(NSString*)message output:(JFLoggerOutput)output severity:(JFLoggerSeverity)severity
{
	[self log:message output:output severity:severity tags:JFLoggerTagsNone];
}

- (void)log:(NSString*)message output:(JFLoggerOutput)output severity:(JFLoggerSeverity)severity tags:(JFLoggerTags)tags
{
	// Filters by severity.
	if(severity > self.severityFilter)
		return;
	
	// Filters by output.
	JFLoggerOutput outputFilter = self.outputFilter;
	BOOL shouldLogToConsole = (output & JFLoggerOutputConsole) && (outputFilter & JFLoggerOutputConsole);
	BOOL shouldLogToFile = (output & JFLoggerOutputFile) && (outputFilter & JFLoggerOutputFile);
	if(!shouldLogToConsole && !shouldLogToFile)
		return;
	
	// Appends tags.
	NSString* tagsString = [self stringFromTags:tags];
	if(!JFStringIsNullOrEmpty(tagsString))
		message = [message stringByAppendingFormat:@" %@", tagsString];
	
	// Prepares the current date.
	NSDate* currentDate = NSDate.date;
	
	// Logs to console if needed.
	if(shouldLogToConsole)
		[self logToConsole:message currentDate:currentDate];
	
	if(!shouldLogToFile)
		return;

	// TODO: use the format string.
	
	// Gets the current thread ID.
	mach_port_t threadID = pthread_mach_thread_np(pthread_self());
	
	// Gets the current date as a string.
	NSString* dateString = [self dateStringFromDate:currentDate];
	NSString* timeString = [self timeStringFromDate:currentDate];

	// Prepares the log string.
	message = [NSString stringWithFormat:@"%@ %@ [%x] %@\n", dateString, timeString, threadID, message];
	
	// Logs to file.
	[self logToFile:message currentDate:currentDate];
}

- (void)log:(NSString*)message severity:(JFLoggerSeverity)severity
{
	[self log:message output:JFLoggerOutputAll severity:severity tags:JFLoggerTagsNone];
}

- (void)log:(NSString*)message severity:(JFLoggerSeverity)severity tags:(JFLoggerTags)tags
{
	[self log:message output:JFLoggerOutputAll severity:severity tags:tags];
}

- (void)logToConsole:(NSString*)message currentDate:(NSDate*)currentDate
{
	NSLog(@"%@", message);
}

- (void)logToFile:(NSString*)message currentDate:(NSDate*)currentDate
{
	// Prepares the data to be written.
	NSData* data = [message dataUsingEncoding:NSUTF8StringEncoding];
	if(!data)
	{
		NSString* tagsString = [self stringFromTags:(JFLoggerTags)(JFLoggerTagsError | JFLoggerTagsUser)];
		NSLog(@"%@: failed to create data from log message '%@'. %@", ClassName, message, tagsString);
		return;
	}
	
	NSURL* fileURL = [self fileURLForDate:currentDate];
	
	@synchronized(self)
	{
		// Tries to append the data to the log file (NSFileHandle is NOT thread safe).
		if(![self createFileAtURL:fileURL currentDate:currentDate])
		{
			NSString* tagsString = [self stringFromTags:(JFLoggerTags)(JFLoggerTagsError | JFLoggerTagsFileSystem)];
			NSLog(@"%@: failed to create the log file at path '%@'. %@", ClassName, fileURL.path, tagsString);
			return;
		}
		
		// Opens the file.
		NSError* error = nil;
		NSFileHandle* fileHandle = [NSFileHandle fileHandleForWritingToURL:fileURL error:&error];
		if(!fileHandle)
		{
			NSString* errorString = (error ? [NSString stringWithFormat:@" due to error '%@'", error.description] : JFEmptyString);
			NSString* tagsString = [self stringFromTags:(JFLoggerTags)(JFLoggerTagsError | JFLoggerTagsFileSystem)];
			NSLog(@"%@: could not open the log file at path '%@'%@. %@", ClassName, fileURL.path, errorString, tagsString);
			return;
		}
		
		// Goes to the end of the file, appends the new message and closes the file.
		[fileHandle seekToEndOfFile];
		[fileHandle writeData:data];
		[fileHandle closeFile];
	}
}

// =================================================================================================
// MARK: Methods - Service management (Convenience)
// =================================================================================================

- (void)logAlert:(NSString*)message tags:(JFLoggerTags)tags
{
	[self log:message output:JFLoggerOutputAll severity:JFLoggerSeverityAlert tags:tags];
}

- (void)logCritical:(NSString*)message tags:(JFLoggerTags)tags
{
	[self log:message output:JFLoggerOutputAll severity:JFLoggerSeverityCritical tags:tags];
}

- (void)logDebug:(NSString*)message tags:(JFLoggerTags)tags
{
	[self log:message output:JFLoggerOutputAll severity:JFLoggerSeverityDebug tags:tags];
}

- (void)logEmergency:(NSString*)message tags:(JFLoggerTags)tags
{
	[self log:message output:JFLoggerOutputAll severity:JFLoggerSeverityEmergency tags:tags];
}

- (void)logError:(NSString*)message tags:(JFLoggerTags)tags
{
	[self log:message output:JFLoggerOutputAll severity:JFLoggerSeverityError tags:tags];
}

- (void)logInfo:(NSString*)message tags:(JFLoggerTags)tags
{
	[self log:message output:JFLoggerOutputAll severity:JFLoggerSeverityInfo tags:tags];
}

- (void)logNotice:(NSString*)message tags:(JFLoggerTags)tags
{
	[self log:message output:JFLoggerOutputAll severity:JFLoggerSeverityNotice tags:tags];
}

- (void)logWarning:(NSString*)message tags:(JFLoggerTags)tags
{
	[self log:message output:JFLoggerOutputAll severity:JFLoggerSeverityWarning tags:tags];
}

@end

////////////////////////////////////////////////////////////////////////////////////////////////////

NS_ASSUME_NONNULL_END

////////////////////////////////////////////////////////////////////////////////////////////////////
