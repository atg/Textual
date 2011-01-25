// Created by Satoshi Nakagawa <psychs AT limechat DOT net> <http://github.com/psychs/limechat>
// Modifications by Codeux Software <support AT codeux DOT com> <https://github.com/codeux/Textual>
// You can redistribute it and/or modify it under the new BSD license.

#define KInternetEventClass	1196773964
#define KAEGetURL			1196773964

@interface NSTextView (NSTextViewCompatibility)
- (void)setAutomaticSpellingCorrectionEnabled:(BOOL)v;
- (BOOL)isAutomaticSpellingCorrectionEnabled;
- (void)setAutomaticDashSubstitutionEnabled:(BOOL)v;
- (BOOL)isAutomaticDashSubstitutionEnabled;
- (void)setAutomaticDataDetectionEnabled:(BOOL)v;
- (BOOL)isAutomaticDataDetectionEnabled;
- (void)setAutomaticTextReplacementEnabled:(BOOL)v;
- (BOOL)isAutomaticTextReplacementEnabled;
@end

@interface MasterController (Private)
- (void)setColumnLayout;
- (void)registerKeyHandlers;
- (void)registerSparkleFeed:(NSNotification *)note;
@end

@implementation MasterController

@synthesize addrMenu;
@synthesize chanMenu;
@synthesize channelMenu;
@synthesize chatBox;
@synthesize completionStatus;
@synthesize extrac;
@synthesize fieldEditor;
@synthesize formattingMenu;
@synthesize growl;
@synthesize infoSplitter;
@synthesize inputHistory;
@synthesize leftTreeBase;
@synthesize logBase;
@synthesize logMenu;
@synthesize memberList;
@synthesize memberMenu;
@synthesize menu;
@synthesize rightTreeBase;
@synthesize rootSplitter;
@synthesize serverMenu;
@synthesize terminating;
@synthesize text;
@synthesize tree;
@synthesize treeMenu;
@synthesize treeScrollView;
@synthesize treeSplitter;
@synthesize urlMenu;
@synthesize viewTheme;
@synthesize WelcomeSheetDisplay;
@synthesize window;
@synthesize world;

- (void)dealloc
{
	[completionStatus release];
	[extrac release];
	[fieldEditor release];
	[growl release];
	[inputHistory release];
	[viewTheme release];
	[WelcomeSheetDisplay release];
	[world release];	
	
	[super dealloc];
}

#pragma mark -
#pragma mark NSApplication Delegate

- (void)awakeFromNib
{
	[window makeMainWindow];
	
	[Preferences initPreferences];
	
	[[ViewTheme invokeInBackgroundThread] createUserDirectory:NO];
	
	[TXNSNotificationCenter() addObserver:self selector:@selector(themeDidChange:) name:ThemeDidChangeNotification object:nil];
	[TXNSNotificationCenter() addObserver:self selector:@selector(themeStyleDidChange:) name:ThemeStyleDidChangeNotification object:nil];
	[TXNSNotificationCenter() addObserver:self selector:@selector(transparencyDidChange:) name:TransparencyDidChangeNotification object:nil];
	[TXNSNotificationCenter() addObserver:self selector:@selector(themeEnableRightMenu:) name:ThemeSelectedChannelNotification object:nil];
	[TXNSNotificationCenter() addObserver:self selector:@selector(themeDisableRightMenu:) name:ThemeSelectedConsoleNotification object:nil];
	[TXNSNotificationCenter() addObserver:self selector:@selector(inputHistorySchemeChanged:) name:InputHistoryGlobalSchemeNotification object:nil];
	
	NSNotificationCenter *wsnc = [TXNSWorkspace() notificationCenter];
	NSAppleEventManager *em = [NSAppleEventManager sharedAppleEventManager];
	
	[wsnc addObserver:self selector:@selector(computerWillSleep:) name:NSWorkspaceWillSleepNotification object:nil];
	[wsnc addObserver:self selector:@selector(computerDidWakeUp:) name:NSWorkspaceDidWakeNotification object:nil];
	[wsnc addObserver:self selector:@selector(computerWillPowerOff:) name:NSWorkspaceWillPowerOffNotification object:nil];
	
	[em setEventHandler:self andSelector:@selector(handleURLEvent:withReplyEvent:) forEventClass:KInternetEventClass andEventID:KAEGetURL];
	
	rootSplitter.fixedViewIndex = 1;
	infoSplitter.fixedViewIndex = 1;
	
	fieldEditor = [[FieldEditorTextView alloc] initWithFrame:NSZeroRect];
	[fieldEditor setFieldEditor:YES];
	fieldEditor.pasteDelegate = self;
	
	[fieldEditor setContinuousSpellCheckingEnabled:[Preferences spellCheckEnabled]];
	[fieldEditor setGrammarCheckingEnabled:[Preferences grammarCheckEnabled]];
	[fieldEditor setSmartInsertDeleteEnabled:[Preferences smartInsertDeleteEnabled]];
	[fieldEditor setAutomaticQuoteSubstitutionEnabled:[Preferences quoteSubstitutionEnabled]];
	[fieldEditor setAutomaticLinkDetectionEnabled:[Preferences linkDetectionEnabled]];
	
	if ([fieldEditor respondsToSelector:@selector(setAutomaticSpellingCorrectionEnabled:)]) {
		[fieldEditor setAutomaticSpellingCorrectionEnabled:[Preferences spellingCorrectionEnabled]];
	}
	
	if ([fieldEditor respondsToSelector:@selector(setAutomaticDashSubstitutionEnabled:)]) {
		[fieldEditor setAutomaticDashSubstitutionEnabled:[Preferences dashSubstitutionEnabled]];
	}
	
	if ([fieldEditor respondsToSelector:@selector(setAutomaticDataDetectionEnabled:)]) {
		[fieldEditor setAutomaticDataDetectionEnabled:[Preferences dataDetectionEnabled]];
	}
	
	if ([fieldEditor respondsToSelector:@selector(setAutomaticTextReplacementEnabled:)]) {
		[fieldEditor setAutomaticTextReplacementEnabled:[Preferences textReplacementEnabled]];
	}
	
	[text setFocusRingType:NSFocusRingTypeNone];
	
	viewTheme = [ViewTheme new];
	viewTheme.name = [Preferences themeName];
	
	tree.theme = viewTheme.other;
	
	memberList.theme = viewTheme.other;
	MemberListViewCell *cell = [MemberListViewCell initWithTheme:viewTheme.other];
	[[[memberList tableColumns] safeObjectAtIndex:0] setDataCell:cell];
	
	[self loadWindowState];
	[self setColumnLayout];
	
	[window setAlphaValue:[Preferences themeTransparency]];
	[window setBackgroundColor:viewTheme.other.underlyingWindowColor];
	
	[rootSplitter setDividerColor:viewTheme.other.underlyingWindowColor];
	[infoSplitter setDividerColor:viewTheme.other.underlyingWindowColor];
	[treeSplitter setDividerColor:viewTheme.other.underlyingWindowColor];
	
	[LanguagePreferences setThemeForLocalization:viewTheme.path];
	
	IRCWorldConfig *seed = [[[IRCWorldConfig alloc] initWithDictionary:[Preferences loadWorld]] autorelease];
	
	extrac = [IRCExtras new];
	
	world = [IRCWorld new];
	world.window = window;
	world.growl = growl;
	world.tree = tree;
	world.extrac = extrac;
	world.text = text;
	world.logBase = logBase;
	world.chatBox = chatBox;
	world.fieldEditor = fieldEditor;
	world.memberList = memberList;
	world.treeMenu = treeMenu;
	world.logMenu = logMenu;
	world.urlMenu = urlMenu;
	world.addrMenu = addrMenu;
	world.chanMenu = chanMenu;
	world.memberMenu = memberMenu;
	world.viewTheme = viewTheme;
	world.menuController = menu;
	
	[world setServerMenuItem:serverMenu];
	[world setChannelMenuItem:channelMenu];
	
	[world setup:seed];
	
	extrac.world = world;
	
	tree.dataSource = world;
	tree.delegate = world;
	tree.responderDelegate = world;
	[tree reloadData];
	
	[world setupTree];
	
	menu.world = world;
	menu.window = window;
	menu.tree = tree;
	menu.memberList = memberList;
	menu.text = text;
	menu.master = self;
	
	memberList.target = menu;
	memberList.keyDelegate = world;
	memberList.dropDelegate = world;
	
	[memberList setDoubleAction:@selector(memberListDoubleClicked:)];
	
	growl = [GrowlController new];
	growl.owner = world;
	world.growl = growl;
	
	[growl registerToGrowl];
	
	if ([Preferences inputHistoryIsChannelSpecific] == NO) {
		inputHistory = [InputHistory new];
	}
	
	[self registerKeyHandlers];
	
	[[NSBundle invokeInBackgroundThread] loadBundlesIntoMemory:world];
	
	[viewTheme validateFilePathExistanceAndReload:YES];
}

#ifdef IS_TRIAL_BINARY

- (void)showTrialPeroidIntroDialog
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	
	BOOL suppCheck = [TXNSUserDefaults() boolForKey:@"Preferences.prompts.trial_period_info"];
	
	if (suppCheck == NO) {
		NSAlert *alert = [NSAlert alertWithMessageText:TXTLS(@"TRIAL_BUILD_INTRO_DIALOG_TITLE")
										 defaultButton:TXTLS(@"OK_BUTTON")
									   alternateButton:nil
										   otherButton:nil
							 informativeTextWithFormat:TXTLS(@"TRIAL_BUILD_INTRO_DIALOG_MESSAGE")];
		
		[alert runModal];
		
		[TXNSUserDefaults() setBool:YES forKey:@"Preferences.prompts.trial_period_info"];
	}
	
	[pool release];
}

#endif

- (void)applicationDidFinishLaunching:(NSNotification *)note
{
	[window makeFirstResponder:text];
	[window makeKeyAndOrderFront:nil];
	
	if (world.clients.count < 1) {
		WelcomeSheetDisplay = [WelcomeSheet new];
		WelcomeSheetDisplay.delegate = self;
		WelcomeSheetDisplay.window = window;
		[WelcomeSheetDisplay show];
	} else {
		[world autoConnectAfterWakeup:NO];	
	}
	
#ifdef IS_TRIAL_BINARY
	[[self invokeInBackgroundThread] showTrialPeroidIntroDialog];
#endif
	
}

- (void)applicationDidBecomeActive:(NSNotification *)note
{
	id sel = world.selected;
    
	if (sel) {
		[sel resetState];
		
		[world updateIcon];
	}
	
	[tree setNeedsDisplay];
}

- (void)applicationDidResignActive:(NSNotification *)note
{
	[tree setNeedsDisplay];
}

- (BOOL)applicationShouldHandleReopen:(NSApplication *)sender hasVisibleWindows:(BOOL)flag
{
	[window makeKeyAndOrderFront:nil];
	
	[text focus];
	
	return YES;
}

- (void)applicationDidReceiveHotKey:(id)sender
{
	if ([window isVisible] == NO || [NSApp isActive] == NO) {
		if (world.clients.count < 1) {
			[NSApp activateIgnoringOtherApps:YES];
			
			[window makeKeyAndOrderFront:nil];
			
			[text focus];
		}
	} else {
		[NSApp hide:nil];
	}
}

- (BOOL)queryTerminate
{
	if (terminating) {
		return YES;
	}
	
	if ([Preferences confirmQuit]) {
		NSInteger result = NSRunAlertPanel(TXTLS(@"WANT_QUIT_TITLE"), 
										   TXTLS(@"WANT_QUIT_MESSAGE"), 
										   TXTLS(@"QUIT_BUTTON"), 
										   TXTLS(@"CANCEL_BUTTON"), nil);
		
		if (result != NSAlertDefaultReturn) {
			return NO;
		}
	}
	
	return YES;
}

- (NSApplicationTerminateReply)applicationShouldTerminate:(NSApplication *)sender
{
	if ([self queryTerminate]) {
		return NSTerminateNow;
	} else {
		return NSTerminateCancel;
	}
}

- (void)applicationWillTerminate:(NSNotification *)note
{
	NSAppleEventManager *em = [NSAppleEventManager sharedAppleEventManager];
	
	[em removeEventHandlerForEventClass:KInternetEventClass andEventID:KAEGetURL];
	
	[Preferences setSpellCheckEnabled:[fieldEditor isContinuousSpellCheckingEnabled]];
	[Preferences setGrammarCheckEnabled:[fieldEditor isGrammarCheckingEnabled]];
	[Preferences setSmartInsertDeleteEnabled:[fieldEditor smartInsertDeleteEnabled]];
	[Preferences setQuoteSubstitutionEnabled:[fieldEditor isAutomaticQuoteSubstitutionEnabled]];
	[Preferences setLinkDetectionEnabled:[fieldEditor isAutomaticLinkDetectionEnabled]];
	
	if ([fieldEditor respondsToSelector:@selector(isAutomaticSpellingCorrectionEnabled)]) {
		[Preferences setSpellingCorrectionEnabled:[fieldEditor isAutomaticSpellingCorrectionEnabled]];
	}
	
	if ([fieldEditor respondsToSelector:@selector(isAutomaticDashSubstitutionEnabled)]) {
		[Preferences setDashSubstitutionEnabled:[fieldEditor isAutomaticDashSubstitutionEnabled]];
	}
	
	if ([fieldEditor respondsToSelector:@selector(isAutomaticDataDetectionEnabled)]) {
		[Preferences setDataDetectionEnabled:[fieldEditor isAutomaticDataDetectionEnabled]];
	}
	
	if ([fieldEditor respondsToSelector:@selector(isAutomaticSpellingCorrectionEnabled)]) {
		[Preferences setTextReplacementEnabled:[fieldEditor isAutomaticTextReplacementEnabled]];
	}
	
	[world save];
	[world terminate];
	[menu terminate];
	
	if ([Preferences isUpgradedFromVersion100] == YES) {
		[TXNSUserDefaults() removeObjectForKey:@"SUHasLaunchedBefore"];
	}
	
	[self saveWindowState];
}

#pragma mark -
#pragma mark NSWorkspace Notifications

- (void)handleURLEvent:(NSAppleEventDescriptor *)event withReplyEvent:(NSAppleEventDescriptor *)replyEvent
{
	NSString *url = [[event descriptorAtIndex:1] stringValue];
	
	if ([url hasPrefix:@"irc://"]) {
		url = [url safeSubstringFromIndex:6];
		
		NSArray *chunks = nil;
		
		NSInteger port = 6667;
		
		NSString *server = nil;
		NSString *channel = nil;
		
		if ([url contains:@"/"]) {
			chunks = [url componentsSeparatedByString:@"/"];
			
			server = [chunks safeObjectAtIndex:0];
			channel = [chunks safeObjectAtIndex:1];
			
			if ([channel hasPrefix:@"#"] == NO) {
				channel = [@"#" stringByAppendingString:channel];
			}
			
			if ([channel contains:@","]) {
				chunks = [channel componentsSeparatedByString:@","];
				
				channel = [chunks safeObjectAtIndex:0];
			}
		} else {
			server = url;
		}
		
		if ([server contains:@":"]) {
			chunks = [server componentsSeparatedByString:@":"];
			
			server = [chunks safeObjectAtIndex:0];
			port = [[chunks safeObjectAtIndex:1] integerValue];
		}
		
		[world createConnection:[NSString stringWithFormat:@"%@ %i", server, port] chan:channel];
	}
}

- (void)computerWillSleep:(NSNotification *)note
{
	[world prepareForSleep];
}

- (void)computerDidWakeUp:(NSNotification *)note
{
	[world autoConnectAfterWakeup:YES];
}

- (void)computerWillPowerOff:(NSNotification *)note
{
	terminating = YES;
	
	[NSApp terminate:nil];
}

- (BOOL)applicationShouldOpenUntitledFile:(NSApplication *)sender
{
	[window makeKeyAndOrderFront:nil];
	
	[text focus];
	
	return YES;
}

#pragma mark -
#pragma mark NSWindow Delegate

- (id)windowWillReturnFieldEditor:(NSWindow *)sender toObject:(id)client
{
	if (client == text) {
		NSMenu *fMenu = [fieldEditor menu];
		
		if ([fMenu indexOfItem:formattingMenu] < 1) {
			[fMenu addItem:[NSMenuItem separatorItem]];
			[fMenu addItem:formattingMenu];
			
			[fieldEditor setMenu:fMenu];
		}
		
		return fieldEditor;
	} else {
		return nil;
	}
}

- (void)insertCrazyColorCharIntoTextBox:(id)sender
{
	NSRange selectedTextRange = [[text currentEditor] selectedRange];
	if (selectedTextRange.location == NSNotFound) return;
	
	NSString *selectedText = [[text stringValue] safeSubstringWithRange:selectedTextRange];
	
	NSInteger charCountIndex = 0;
	NSMutableArray *charRanges = [NSMutableArray new];
	
	while (1 == 1) {
		if (charCountIndex >= [selectedText length]) break;
		
		NSRange charRange = NSMakeRange(charCountIndex, 1);
		NSString *charValue = [selectedText safeSubstringWithRange:charRange];
		
		NSInteger firstColor = ((arc4random() % 15) + 1);
		NSInteger secondColor = ((arc4random() % 15) + 1);
		
		if (firstColor % 2 == 0) {
			charValue = [charValue lowercaseString];
		} else {
			charValue = [charValue uppercaseString];
		}
		
		charValue = [NSString stringWithFormat:@"▤%i,%i%@▤", firstColor, secondColor, charValue];
		
		[charRanges addObject:charValue];
		
		charCountIndex++;
	}
	
	selectedText = [charRanges componentsJoinedByString:nil];
	[charRanges release];
	
	[text setStringValue:[[text stringValue] stringByReplacingCharactersInRange:selectedTextRange withString:selectedText]];
	[text focus];
}

- (IBAction)insertColorCharIntoTextBox:(id)sender
{
	NSRange selectedTextRange = [[text currentEditor] selectedRange];
	if (selectedTextRange.location == NSNotFound) return;
	
	NSString *selectedText = [[text stringValue] safeSubstringWithRange:selectedTextRange];
	
	if ([sender tag] == 100) { // rainbow text
		NSInteger charCountIndex = 0;
		NSInteger rainbowArrayIndex = 0;
		
		NSMutableArray *rainbowRanges = [NSMutableArray new];
		NSArray *colorCodes = [NSArray arrayWithObjects:@"4", @"7", @"8", @"3", @"12", @"2", @"6", nil];
		
		while (1 == 1) {
			if (charCountIndex >= [selectedText length]) break;
			
			NSRange charRange = NSMakeRange(charCountIndex, 1);
			NSString *charValue = [selectedText safeSubstringWithRange:charRange];
			
			if ([charValue isEqualToString:@" "]) {
				[rainbowRanges addObject:@" "];
				charCountIndex++;
				continue;
			}
			
			if (rainbowArrayIndex > 6) rainbowArrayIndex = 0;
			
			NSInteger colorChar = [[colorCodes safeObjectAtIndex:rainbowArrayIndex] integerValue];
			charValue = [NSString stringWithFormat:@"▤%i%@▤", colorChar, charValue];
			
			[rainbowRanges addObject:charValue];
			
			charCountIndex++;
			rainbowArrayIndex++;
		}
		
		selectedText = [rainbowRanges componentsJoinedByString:nil];
		[rainbowRanges release];
	} else {
		selectedText = [NSString stringWithFormat:@"▤%i%@▤", [sender tag], selectedText];
	}
	
	[text setStringValue:[[text stringValue] stringByReplacingCharactersInRange:selectedTextRange withString:selectedText]];
	[text focus];
}

- (IBAction)insertBoldCharIntoTextBox:(id)sender
{
	NSRange selectedTextRange = [[text currentEditor] selectedRange];
	if (selectedTextRange.location == NSNotFound) return;
	
	NSString *selectedText = [[text stringValue] safeSubstringWithRange:selectedTextRange];
	selectedText = [NSString stringWithFormat:@"▥%@▥", selectedText];
	
	[text setStringValue:[[text stringValue] stringByReplacingCharactersInRange:selectedTextRange withString:selectedText]];
	[text focus];
}

- (IBAction)insertItalicCharIntoTextBox:(id)sender
{
	NSRange selectedTextRange = [[text currentEditor] selectedRange];
	if (selectedTextRange.location == NSNotFound) return;
	
	NSString *selectedText = [[text stringValue] safeSubstringWithRange:selectedTextRange];
	selectedText = [NSString stringWithFormat:@"▧%@▧", selectedText];
	
	[text setStringValue:[[text stringValue] stringByReplacingCharactersInRange:selectedTextRange withString:selectedText]];
	[text focus];
}

- (IBAction)insertUnderlineCharIntoTextBox:(id)sender
{
	NSRange selectedTextRange = [[text currentEditor] selectedRange];
	if (selectedTextRange.location == NSNotFound) return;
	
	NSString *selectedText = [[text stringValue] safeSubstringWithRange:selectedTextRange];
	selectedText = [NSString stringWithFormat:@"▨%@▨", selectedText];
	
	[text setStringValue:[[text stringValue] stringByReplacingCharactersInRange:selectedTextRange withString:selectedText]];
	[text focus];
}

#pragma mark -
#pragma mark FieldEditorTextView Delegate

- (BOOL)fieldEditorTextViewPaste:(id)sender;
{
	NSString *s = [[NSPasteboard generalPasteboard] stringContent];
	if (NSStringIsEmpty(s)) return NO;
	
	if ([[window firstResponder] isKindOfClass:[NSTextView class]] == NO) {
		[world focusInputText];
	}
	
	return NO;
}

#pragma mark -
#pragma mark Utilities

- (void)sendText:(NSString *)command
{
	NSString *s = [text stringValue];
	NSString *os = s;
	
	s = [s stringWithASCIIFormatting];
	
	[text setStringValue:@""];
	
	if ([Preferences inputHistoryIsChannelSpecific]) {
		if (world.selected.currentInputHistory && NSStringIsEmpty(world.selected.currentInputHistory) == NO) {
			world.selected.currentInputHistory = nil;
		}
	}
	
	if (NSStringIsEmpty(s) == NO) {
		if ([world inputText:s command:command]) {
			[inputHistory add:os];
		}
	}
	
	[text focus];
	
	if (completionStatus) {
		[completionStatus clear];
	}
}

- (void)textEntered:(id)sender
{
	[self sendText:IRCCI_PRIVMSG];
}

- (void)setColumnLayout
{
	infoSplitter.hidden = YES;
	infoSplitter.inverted = YES;
	
	[leftTreeBase addSubview:treeScrollView];
	
	if (treeSplitter.position < 1) treeSplitter.position = 130;
	
	treeScrollView.frame = leftTreeBase.bounds;
}

#pragma mark -
#pragma mark Root Splitter Console Toggle

- (void)themeEnableRightMenu:(NSNotification *)note 
{
	rootSplitter.hidden = NO;
	rootSplitter.inverted = NO;
}

- (void)themeDisableRightMenu:(NSNotification *)note 
{
	rootSplitter.hidden = YES;
	rootSplitter.inverted = YES;
	
	if (rootSplitter.position < 10) {
		rootSplitter.position = 130;
	}
}

#pragma mark -
#pragma mark Preferences

- (void)loadWindowState
{
	NSDictionary *dic = [Preferences loadWindowStateWithName:@"MainWindow"];
	
	rootSplitter.position = 130;
	
	if (dic) {
		NSInteger x = [dic intForKey:@"x"];
		NSInteger y = [dic intForKey:@"y"];
		NSInteger w = [dic intForKey:@"w"];
		NSInteger h = [dic intForKey:@"h"];
		
		id spellCheckingValue = [dic objectForKey:@"SpellChecking"];
		
		[window setFrame:NSMakeRect(x, y, w, h) display:YES animate:menu.isInFullScreenMode];
		
		infoSplitter.position = [dic intForKey:@"info"];
		treeSplitter.position = [dic intForKey:@"tree"];
		
		if (spellCheckingValue) {
			[fieldEditor setContinuousSpellCheckingEnabled:[spellCheckingValue boolValue]];
		}
	} else {
		NSScreen *screen = [NSScreen mainScreen];
		
		if (screen) {
			NSRect rect = [screen visibleFrame];
			
			NSPoint p = NSMakePoint((rect.origin.x + (rect.size.width / 2)), 
									(rect.origin.y + (rect.size.height / 2)));
			
			NSInteger w = 1024;
			NSInteger h = 768;
			
			rect = NSMakeRect((p.x - (w / 2)), (p.y - (h / 2)), w, h);
			
			[window setFrame:rect display:YES animate:menu.isInFullScreenMode];
		}
		
		infoSplitter.position = 250;
		treeSplitter.position = 140;
	}
}

- (void)saveWindowState
{
	NSMutableDictionary *dic = [NSMutableDictionary dictionary];
	
	if (menu.isInFullScreenMode) {
		[self loadWindowState];
	}
	
	NSRect rect = window.frame;
	
	[dic setInt:rect.origin.x forKey:@"x"];
	[dic setInt:rect.origin.y forKey:@"y"];
	[dic setInt:rect.size.width forKey:@"w"];
	[dic setInt:rect.size.height forKey:@"h"];
	
	[dic setInt:infoSplitter.position forKey:@"info"];
	[dic setInt:treeSplitter.position forKey:@"tree"];
	
	[dic setBool:[fieldEditor isContinuousSpellCheckingEnabled] forKey:@"SpellChecking"];
	
	[Preferences saveWindowState:dic name:@"MainWindow"];
	[Preferences sync];
}

- (void)themeOverrideAlertSheetCallback:(NSAlert *)alert returnCode:(int)returnCode contextInfo:(void *)contextInfo
{	
	[TXNSUserDefaults() setBool:[[alert suppressionButton] state] forKey:@"Preferences.prompts.theme_override_info"];
}

- (void)themeDidChange:(NSNotification *)note
{
	[world reloadTheme];
	
	[self setColumnLayout];
	
	[rootSplitter setDividerColor:viewTheme.other.underlyingWindowColor];
	[infoSplitter setDividerColor:viewTheme.other.underlyingWindowColor];
	[treeSplitter setDividerColor:viewTheme.other.underlyingWindowColor];
	
	// ====================================================== //
	
	NSMutableString *sf = [NSMutableString string];
	
	if (viewTheme.other.nicknameFormat) {
		[sf appendString:TXTLS(@"THEME_CHANGE_OVERRIDE_PROMPT_NICKNAME_FORMAT")];
		[sf appendString:@"\n"];
	}
	
	if (viewTheme.other.timestampFormat) {
		[sf appendString:TXTLS(@"THEME_CHANGE_OVERRIDE_PROMPT_TIMESTAMP_FORMAT")];
		[sf appendString:@"\n"];
	}
	
	if (viewTheme.other.overrideChannelFont) {
		[sf appendString:TXTLS(@"THEME_CHANGE_OVERRIDE_PROMPT_CHANNEL_FONT")];
		[sf appendString:@"\n"];
	}
	
	if (viewTheme.other.overrideMessageIndentWrap) {
		[sf appendString:TXTLS(@"THEME_CHANGE_OVERRIDE_PROMPT_INDENT_WRAPPED")];
		[sf appendString:@"\n"];
	}
	
	sf = (NSMutableString *)[sf trim];
	
	if (NSStringIsEmpty(sf) == NO) {		
		BOOL suppCheck = [TXNSUserDefaults() boolForKey:@"Preferences.prompts.theme_override_info"];
		
		if (suppCheck == NO) {
			NSAlert *alert = [[[NSAlert alloc] init] autorelease];
			
			NSArray *kindAndName = [ViewTheme extractFileName:[Preferences themeName]];
			NSString *fname = [kindAndName safeObjectAtIndex:1];
			
			[alert addButtonWithTitle:TXTLS(@"OK_BUTTON")];
			[alert setMessageText:TXTLS(@"THEME_CHANGE_OVERRIDE_PROMPT_TITLE")];
			[alert setInformativeText:[NSString stringWithFormat:TXTLS(@"THEME_CHANGE_OVERRIDE_PROMPT_MESSAGE"), fname, sf]];
			
			[alert setShowsSuppressionButton:YES];
			[[alert suppressionButton] setTitle:TXTLS(@"SUPPRESSION_BUTTON_DEFAULT_TITLE")];
			
			[alert setAlertStyle:NSInformationalAlertStyle];
			
			[alert beginSheetModalForWindow:[NSApp keyWindow] modalDelegate:self didEndSelector:@selector(themeOverrideAlertSheetCallback:returnCode:contextInfo:) contextInfo:nil];
		}
	}
}

- (void)themeStyleDidChange:(NSNotification *)note
{
	[world updateThemeStyle];
}

- (void)transparencyDidChange:(NSNotification *)note
{
	[window setAlphaValue:[Preferences themeTransparency]];
}

- (void)inputHistorySchemeChanged:(NSNotification *)note
{
	if (inputHistory) {
		[inputHistory release];
		inputHistory = nil;
	}
	
	for (IRCClient *c in world.clients) {
		if (c.inputHistory) {
			[c.inputHistory release];
			c.inputHistory = nil;
		}
		
		if (c.currentInputHistory) {
			[c.currentInputHistory release];
			c.currentInputHistory = nil;
		}
		
		if ([Preferences inputHistoryIsChannelSpecific]) {
			c.inputHistory = [InputHistory new];
			c.currentInputHistory = nil;
		}
		
		for (IRCChannel *u in c.channels) {
			if (u.inputHistory) {
				[u.inputHistory release];
				u.inputHistory = nil;
			}
			
			if (u.currentInputHistory) {
				[u.currentInputHistory release];
				u.currentInputHistory = nil;
			}
			
			if ([Preferences inputHistoryIsChannelSpecific]) {
				u.inputHistory = [InputHistory new];
				u.currentInputHistory = nil;
			}
		}
	}
	
	if ([Preferences inputHistoryIsChannelSpecific] == NO) {
		inputHistory = [InputHistory new];
	}
}

#pragma mark -
#pragma mark Nick Completion

- (void)completeNick:(BOOL)forward
{
	IRCClient *client = [world selectedClient];
	IRCChannel *channel = [world selectedChannel];
	
	if (client == nil) return;
	
	if ([window firstResponder] != [window fieldEditor:NO forObject:text]) {
		[world focusInputText];
	}
	
	NSText *fe = [window fieldEditor:YES forObject:text];
	if (fe == nil) return;
	
	NSRange selectedRange = [fe selectedRange];
	if (selectedRange.location == NSNotFound) return;
	
	if (completionStatus == nil) {
		completionStatus = [NickCompletionStatus new];
	}
	
	NickCompletionStatus *status = completionStatus;
	
	NSString *s = text.stringValue;
	
	if ([status.text isEqualToString:s]
		&& status.range.location != NSNotFound
		&& NSMaxRange(status.range) == selectedRange.location
		&& selectedRange.length == 0) {
		
		selectedRange = status.range;
	}
	
	BOOL head = YES;
	
	NSString *pre = [s safeSubstringToIndex:selectedRange.location];
	NSString *sel = [s safeSubstringWithRange:selectedRange];
	
	for (NSInteger i = (pre.length - 1); i >= 0; --i) {
		UniChar c = [pre characterAtIndex:i];
		
		if (c == ' ') {
			++i;
			
			if (i == pre.length) return;
			
			head = NO;
			pre = [pre safeSubstringFromIndex:i];
			
			break;
		}
	}
	
	if (NSStringIsEmpty(pre)) return;
	
	BOOL channelMode = NO;
	BOOL commandMode = NO;
	
	UniChar c = [pre characterAtIndex:0];
	
	if (head && c == '/') {
		commandMode = YES;
		
		pre = [pre safeSubstringFromIndex:1];
		
		if (NSStringIsEmpty(pre)) return;
	} else if (c == '@') {
		if (channel == nil) return;
		
		pre = [pre safeSubstringFromIndex:1];
		
		if (NSStringIsEmpty(pre)) return;
	} else if (c == '#') {
		channelMode = YES;
		
		if (NSStringIsEmpty(pre)) return;
	}
	
	NSString *current = [pre stringByAppendingString:sel];
	
	NSInteger len = current.length;
	
	for (NSInteger i = 0; i < len; ++i) {
		UniChar c = [current characterAtIndex:i];
		
		if (c != ' ' && c != ':') {
			;
		} else {
			current = [current safeSubstringToIndex:i];
			break;
		}
	}
	
	if (NSStringIsEmpty(current)) return;
	
	NSString *lowerPre = [pre lowercaseString];
	NSString *lowerCurrent = [current lowercaseString];
	
	NSArray *lowerChoices;
	NSMutableArray *choices;
	
	if (commandMode) {
		choices = [NSMutableArray array];
		
		NSArray *resourceFiles = [TXNSFileManager() contentsOfDirectoryAtPath:[Preferences whereScriptsPath] error:NULL];
		
		for (NSString *command in [[Preferences commandIndexList] allKeys]) {
			[choices addObject:[command lowercaseString]];
		}
		
		for (NSString *command in [[world bundlesForUserInput] allKeys]) {
			NSString *cmdl = [command lowercaseString];
			
			if ([choices containsObject:cmdl] == NO) {
				[choices addObject:cmdl];
			}
		}
		
		for (NSString *file in resourceFiles) {
			if ([file hasSuffix:@".scpt"]) {
				NSString *cmdl = [[file safeSubstringToIndex:([file length] - 5)] lowercaseString];
				
				if ([choices containsObject:cmdl] == NO) {
					[choices addObject:cmdl];
				}
			}
		}
		
		lowerChoices = choices;
	} else if (channelMode) {
		NSMutableArray *channels = [NSMutableArray array];
		NSMutableArray *lowerChannels = [NSMutableArray array];
		
		IRCClient *u = [world selectedClient];
		
		for (IRCChannel *c in u.channels) {
			[channels addObject:c.name];
			[lowerChannels addObject:[c.name lowercaseString]];
		}
		
		choices = channels;
		lowerChoices = lowerChannels;
	} else {
		NSMutableArray *users = [channel.members mutableCopy];
		[users sortUsingSelector:@selector(compareUsingWeights:)];
		
		NSMutableArray *nicks = [NSMutableArray array];
		NSMutableArray *lowerNicks = [NSMutableArray array];
		
		for (IRCUser *m in users) {
			[nicks addObject:m.nick];
			[lowerNicks addObject:[m.nick lowercaseString]];
		}
		
		choices = nicks;
		lowerChoices = lowerNicks;
		
		[users release];
	}
	
	NSMutableArray *currentChoices = [NSMutableArray array];
	NSMutableArray *currentLowerChoices = [NSMutableArray array];
	
	NSInteger i = 0;
	
	for (NSString *s in lowerChoices) {
		if ([s hasPrefix:lowerPre]) {
			[currentLowerChoices addObject:s];
			[currentChoices addObject:[choices safeObjectAtIndex:i]];
		}
		
		++i;
	}
	
	if (currentChoices.count < 1) return;
	
	NSString *t = nil;
	
	NSUInteger index = [currentLowerChoices indexOfObject:lowerCurrent];
	
	if (index == NSNotFound) {
		t = [currentChoices safeObjectAtIndex:0];
	} else {
		if (forward) {
			++index;
			
			if (currentChoices.count <= index) {
				index = 0;
			}
		} else {
			if (index == 0) {
				index = (currentChoices.count - 1);
			} else {
				--index;
			}
		}
		
		t = [currentChoices safeObjectAtIndex:index];
	}
	
	[[NSSpellChecker sharedSpellChecker] ignoreWord:t inSpellDocumentWithTag:[fieldEditor spellCheckerDocumentTag]];
	
	if ((commandMode || channelMode) || head == NO) {
		t = [t stringByAppendingString:@" "];
	} else {
		if (NSStringIsEmpty([Preferences completionSuffix]) == NO) {
			t = [t stringByAppendingString:[Preferences completionSuffix]];
		}
	}
	
	NSRange r = selectedRange;
	
	r.location -= pre.length;
	r.length += pre.length;
	
	[fe replaceCharactersInRange:r withString:t];
	[fe scrollRangeToVisible:fe.selectedRange];
	
	r.location += t.length;
	r.length = 0;
	
	fe.selectedRange = r;
	
	if (currentChoices.count == 1) {
		[status clear];
	} else {
		selectedRange.length = (t.length - pre.length);
		
		status.text = text.stringValue;
		status.range = selectedRange;
	}
}

#pragma mark -
#pragma mark Keyboard Navigation

typedef enum {
	MOVE_UP,
	MOVE_DOWN,
	MOVE_LEFT,
	MOVE_RIGHT,
	MOVE_ALL,
	MOVE_ACTIVE,
	MOVE_UNREAD,
} MoveKind;

- (void)move:(MoveKind)dir target:(MoveKind)target
{
	if (dir == MOVE_UP || dir == MOVE_DOWN) {
		id sel = world.selected;
		if (sel == nil) return;
		
		NSInteger n = [tree rowForItem:sel];
		if (n < 0) return;
		
		NSInteger start = n;
		
		NSInteger count = [tree numberOfRows];
		if (count <= 1) return;
		
		while (1) {
			if (dir == MOVE_UP) {
				--n;
				if (n < 0) n = (count - 1);
			} else {
				++n;
				if (count <= n) n = 0;
			}
			
			if (n == start) break;
			
			id i = [tree itemAtRow:n];
			
			if (i) {
				if (target == MOVE_ACTIVE) {
					if ([i isClient] == NO && [i isActive]) {
						[world select:i];
						break;
					}
				} else if (target == MOVE_UNREAD) {
					if ([i isUnread]) {
						[world select:i];
						break;
					}
				} else {
					[world select:i];
					break;
				}
			}
		}
	} else if (dir == MOVE_LEFT || dir == MOVE_RIGHT) {
		IRCClient *client = [world selectedClient];
		if (client == nil) return;
		
		NSUInteger pos = [world.clients indexOfObjectIdenticalTo:client];
		if (pos == NSNotFound) return;
		
		NSInteger n = pos;
		NSInteger start = n;
		
		NSInteger count = world.clients.count;
		if (count <= 1) return;
		
		while (1) {
			if (dir == MOVE_LEFT) {
				--n;
				if (n < 0) n = (count - 1);
			} else {
				++n;
				if (count <= n) n = 0;
			}
			
			if (n == start) break;
			
			client = [world.clients safeObjectAtIndex:n];
			
			if (client) {
				if (target == MOVE_ACTIVE) {
					if (client.isLoggedIn) {
						id t = ((client.lastSelectedChannel) ?: (id)client);
						
						[world select:t];
						
						break;
					}
				} else {
					id t = ((client.lastSelectedChannel) ?: (id)client);
					
					[world select:t];
					
					break;
				}
			}
		}
	}
}

- (void)selectPreviousChannel:(NSEvent *)e
{
	[self move:MOVE_UP target:MOVE_ALL];
}

- (void)selectNextChannel:(NSEvent *)e
{
	[self move:MOVE_DOWN target:MOVE_ALL];
}

- (void)selectPreviousUnreadChannel:(NSEvent *)e
{
	[self move:MOVE_UP target:MOVE_UNREAD];
}

- (void)selectNextUnreadChannel:(NSEvent *)e
{
	[self move:MOVE_DOWN target:MOVE_UNREAD];
}

- (void)selectPreviousActiveChannel:(NSEvent *)e
{
	[self move:MOVE_UP target:MOVE_ACTIVE];
}

- (void)selectNextActiveChannel:(NSEvent *)e
{
	[self move:MOVE_DOWN target:MOVE_ACTIVE];
}

- (void)selectPreviousServer:(NSEvent *)e
{
	[self move:MOVE_LEFT target:MOVE_ALL];
}

- (void)selectNextServer:(NSEvent *)e
{
	[self move:MOVE_RIGHT target:MOVE_ALL];
}

- (void)selectPreviousActiveServer:(NSEvent *)e
{
	[self move:MOVE_LEFT target:MOVE_ACTIVE];
}

- (void)selectNextActiveServer:(NSEvent *)e
{
	[self move:MOVE_RIGHT target:MOVE_ACTIVE];
}

- (void)selectPreviousSelection:(NSEvent *)e
{
	[world selectPreviousItem];
}

- (void)selectNextSelection:(NSEvent *)e
{
	[self move:MOVE_DOWN target:MOVE_ALL];
}

- (void)tab:(NSEvent *)e
{
	switch ([Preferences tabAction]) {
		case TAB_COMPLETE_NICK:
			[self completeNick:YES];
			break;
		case TAB_UNREAD:
			[self move:MOVE_DOWN target:MOVE_UNREAD];
			break;
		default:
			break;
	}
}

- (void)shiftTab:(NSEvent *)e
{
	switch ([Preferences tabAction]) {
		case TAB_COMPLETE_NICK:
			[self completeNick:NO];
			break;
		case TAB_UNREAD:
			[self move:MOVE_UP target:MOVE_UNREAD];
			break;
		default:
			break;
	}
}

- (void)sendMsgAction:(NSEvent *)e
{
	[self sendText:IRCCI_ACTION];
}

- (void)inputHistoryUp:(NSEvent *)e
{
	NSString *s = [inputHistory up:[text stringValue]];
	
	if (s) {
		[text setStringValue:s];
		[world focusInputText];
	}
}

- (void)inputHistoryDown:(NSEvent *)e
{
	NSString *s = [inputHistory down:[text stringValue]];
	
	if (s) {
		[text setStringValue:s];
		[world focusInputText];
	}
}

- (void)handler:(SEL)sel code:(NSInteger)keyCode mods:(NSUInteger)mods
{
	[window registerKeyHandler:sel key:keyCode modifiers:mods];
}

- (void)inputHandler:(SEL)sel code:(NSInteger)keyCode mods:(NSUInteger)mods
{
	[fieldEditor registerKeyHandler:sel key:keyCode modifiers:mods];
}

- (void)handler:(SEL)sel char:(UniChar)c mods:(NSUInteger)mods
{
	[window registerKeyHandler:sel character:c modifiers:mods];
}

- (void)registerKeyHandlers
{
	[window setKeyHandlerTarget:self];
	[fieldEditor setKeyHandlerTarget:self];
	
	[self handler:@selector(tab:) code:KEY_TAB mods:0];
	[self handler:@selector(shiftTab:) code:KEY_TAB mods:NSShiftKeyMask];
	
	[self handler:@selector(sendMsgAction:) code:KEY_ENTER mods:NSControlKeyMask];
	[self handler:@selector(sendMsgAction:) code:KEY_RETURN mods:NSControlKeyMask];
	
	[self handler:@selector(inputHistoryUp:) char:'p' mods:NSControlKeyMask];
	[self handler:@selector(inputHistoryDown:) char:'n' mods:NSControlKeyMask];
	
	[self handler:@selector(insertCrazyColorCharIntoTextBox:) char:'c' mods:(NSControlKeyMask|NSShiftKeyMask|NSAlternateKeyMask|NSCommandKeyMask)];
	
	[self inputHandler:@selector(inputHistoryUp:) code:KEY_UP mods:0];
	[self inputHandler:@selector(inputHistoryUp:) code:KEY_UP mods:NSAlternateKeyMask];
	
	[self inputHandler:@selector(inputHistoryDown:) code:KEY_DOWN mods:0];
	[self inputHandler:@selector(inputHistoryDown:) code:KEY_DOWN mods:NSAlternateKeyMask];
}

#pragma mark -
#pragma mark WelcomeSheet Delegate

- (void)WelcomeSheet:(WelcomeSheet *)sender onOK:(NSDictionary *)config
{
	NSString *host = [config objectForKey:@"host"];
	NSString *name = host;
	
	NSString *nick = [config objectForKey:@"nick"];
	NSString *user = [[nick lowercaseString] safeUsername];
	NSString *realName = nick;
	
	NSMutableArray *channels = [NSMutableArray array];
	
	for (NSString *s in [config objectForKey:@"channels"]) {
		[channels addObject:[NSDictionary dictionaryWithObjectsAndKeys: s, @"name", 
							 [NSNumber numberWithBool:YES], @"auto_join", 
							 [NSNumber numberWithBool:YES], @"growl", nil]];
	}
	
	NSMutableDictionary *dic = [NSMutableDictionary dictionary];
	
	[dic setObject:host forKey:@"host"];
	[dic setObject:name forKey:@"name"];
	[dic setObject:nick forKey:@"nick"];
	[dic setObject:user forKey:@"username"];
	[dic setObject:realName forKey:@"realname"];
	[dic setObject:channels forKey:@"channels"];
	[dic setObject:[config objectForKey:@"autoConnect"] forKey:@"auto_connect"];
	[dic setObject:[NSNumber numberWithLong:NSUTF8StringEncoding] forKey:@"encoding"];
	
	[window makeKeyAndOrderFront:nil];
	
	IRCClientConfig *c = [[[IRCClientConfig alloc] initWithDictionary:dic] autorelease];
	IRCClient *u = [world createClient:c reload:YES];
	
	[world save];
	
	if (c.autoConnect) {
		[u connect];
	}
}

- (void)WelcomeSheetWillClose:(WelcomeSheet *)sender
{
	[WelcomeSheetDisplay autorelease];
	WelcomeSheetDisplay = nil;
}

@end