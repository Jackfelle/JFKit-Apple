//
//	The MIT License (MIT)
//
//	Copyright © 2015-2016 Jacopo Filié
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



#import "JFPreprocessorMacros.h"
#import "JFTypes.h"



#if JF_IOS || JF_MACOS
@class JFAlertsController;
#endif
@class JFErrorsManager;
@class JFWindowController;



#if JF_MACOS
@interface JFAppDelegate : NSObject <NSApplicationDelegate>
#else
@interface JFAppDelegate : UIResponder <UIApplicationDelegate>
#endif

#pragma mark Properties

// Errors
@property (strong, nonatomic, readonly)	JFErrorsManager*	errorsManager;

// Relationships
@property (strong, nonatomic, readonly)	JFWindowController*	windowController;

// User interface
#if JF_IOS || JF_MACOS
@property (strong, nonatomic, readonly)				JFAlertsController*	alertsController;
#endif
@property (strong, nonatomic)			IBOutlet	JFWindow*			window;


#pragma mark Methods

// Errors management
- (JFErrorsManager*)	createErrorsManager;

// User interface management
- (JFWindowController*)	createControllerForWindow:(JFWindow*)window;

#if JF_MACOS
// Protocol implementation (NSApplicationDelegate)
- (void)	applicationDidBecomeActive:(NSNotification*)notification;
- (void)	applicationDidFinishLaunching:(NSNotification*)notification;
- (void)	applicationDidHide:(NSNotification*)notification;
- (void)	applicationDidResignActive:(NSNotification*)notification;
- (void)	applicationDidUnhide:(NSNotification*)notification;
- (void)	applicationWillBecomeActive:(NSNotification*)notification;
- (void)	applicationWillHide:(NSNotification*)notification;
- (void)	applicationWillResignActive:(NSNotification*)notification;
- (void)	applicationWillTerminate:(NSNotification*)notification;
- (void)	applicationWillUnhide:(NSNotification*)notification;
#endif

#if !JF_MACOS
// Protocol implementation (UIApplicationDelegate)
- (BOOL)	application:(UIApplication*)application didFinishLaunchingWithOptions:(NSDictionary<UIApplicationLaunchOptionsKey, id>*)launchOptions;
- (void)	applicationDidBecomeActive:(UIApplication*)application;
- (void)	applicationDidEnterBackground:(UIApplication*)application;
- (void)	applicationDidReceiveMemoryWarning:(UIApplication*)application;
- (void)	applicationWillEnterForeground:(UIApplication*)application;
- (void)	applicationWillResignActive:(UIApplication*)application;
- (void)	applicationWillTerminate:(UIApplication*)application;
#endif

@end
