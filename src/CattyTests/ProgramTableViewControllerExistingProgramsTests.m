/**
 *  Copyright (C) 2010-2014 The Catrobat Team
 *  (http://developer.catrobat.org/credits)
 *
 *  This program is free software: you can redistribute it and/or modify
 *  it under the terms of the GNU Affero General Public License as
 *  published by the Free Software Foundation, either version 3 of the
 *  License, or (at your option) any later version.
 *
 *  An additional term exception under section 7 of the GNU Affero
 *  General Public License, version 3, is available at
 *  (http://developer.catrobat.org/license_additional_term)
 *
 *  This program is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 *  GNU Affero General Public License for more details.
 *
 *  You should have received a copy of the GNU Affero General Public License
 *  along with this program.  If not, see http://www.gnu.org/licenses/.
 */

// NOTE: needed for ProgramTableViewController.h to make some non-public methods that are needed for testing
// visible for this class
#define CATTY_TESTS 1

#import "ProgramTableViewControllerExistingProgramsTests.h"
#import "ProgramTableViewController+UnitTestingExtensions.h"
#import "Program.h"
#import "ProgramDefines.h"
#import "AppDelegate.h"
#import "FileManager.h"
#import "Util.h"
#import "ProgramLoadingInfo.h"
#import "CatrobatImageCell.h"
#import "DarkBlueGradientImageCell.h"
#import "CellTagDefines.h"
#import "Parser.h"
#import "SpriteObject.h"
#import "Brick.h"
#import "Script.h"
#import "ActionSheetAlertViewTags.h"
#import "MyProgramsViewController.h"
#import "LanguageTranslationDefines.h"

@interface ProgramTableViewControllerExistingProgramsTests ()
@property (nonatomic, strong) ProgramTableViewController *programTableViewController;
@property (nonatomic, strong) FileManager *fileManager;
@end

@implementation ProgramTableViewControllerExistingProgramsTests

- (void)setUp
{
    [super setUp];
    if (! [self.fileManager directoryExists:[Program basePath]]) {
        [self.fileManager createDirectory:[Program basePath]];
    }
    self.programTableViewController.delegate = nil; // no delegate needed for our tests
    [Util activateTestMode:YES];
}

- (void)tearDown
{
    self.programTableViewController = nil;
    self.fileManager = nil;
    [super tearDown];
}

#pragma mark - Tests for all existing programs
// existing programs like Whack a mole, ...
- (void)testExistingProgramsIfFolderExists
{
    NSString *basePath = [Program basePath];
    NSError *error;
    NSArray *programNames = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:basePath error:&error];
    NSLogError(error);

    for (NSString *programName in programNames) {
        // exclude .DS_Store folder on MACOSX simulator and new program
        if ([programName isEqualToString:@".DS_Store"] || [programName isEqualToString:kGeneralNewDefaultProgramName])
            continue;

        ProgramLoadingInfo *loadingInfo = [[ProgramLoadingInfo alloc] init];
        loadingInfo.basePath = [NSString stringWithFormat:@"%@%@/", [Program basePath], programName];
        loadingInfo.visibleName = programName;
        NSLog(@"Project name: %@", programName);
        self.programTableViewController.delegate = nil; // no delegate needed for this test
        self.programTableViewController.program = [Program programWithLoadingInfo:loadingInfo];
        [self.programTableViewController viewDidLoad];
        [self.programTableViewController viewWillAppear:NO];
        XCTAssertTrue([self.fileManager directoryExists:loadingInfo.basePath], @"The ProgramTableViewController did not create the project folder for the project %@", programName);
        self.programTableViewController = nil; // unload program table view controller
    }
}

- (void)testExistingProgramsObjectCells
{
    NSString *basePath = [Program basePath];
    NSError *error;
    NSArray *programNames = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:basePath error:&error];
    NSLogError(error);

    for (NSString *programName in programNames) {
        // exclude .DS_Store folder on MACOSX simulator and new program
        if ([programName isEqualToString:@".DS_Store"] || [programName isEqualToString:kGeneralNewDefaultProgramName])
            continue;

        ProgramLoadingInfo *loadingInfo = [[ProgramLoadingInfo alloc] init];
        loadingInfo.basePath = [NSString stringWithFormat:@"%@%@/", [Program basePath], programName];
        loadingInfo.visibleName = programName;
        NSLog(@"Project name: %@", programName);
        Program *program = [self loadProgram:loadingInfo];
        XCTAssertNotNil(program, @"Could not create program");
        if (! program) {
            NSLog(@"Loading program %@ failed", programName);
            continue;
        }

        self.programTableViewController.delegate = nil; // no delegate needed for this test
        self.programTableViewController.program = [Program programWithLoadingInfo:loadingInfo];
        [self.programTableViewController performSelectorOnMainThread:@selector(view) withObject:nil waitUntilDone:YES];
        [self.programTableViewController viewDidLoad];
        [self.programTableViewController viewWillAppear:NO];

        // test background object cell
        NSIndexPath *indexPath = [NSIndexPath indexPathForRow:kBackgroundObjectIndex inSection:kBackgroundSectionIndex];
        UITableViewCell *cell = [self.programTableViewController tableView:self.programTableViewController.tableView cellForRowAtIndexPath:indexPath];
        NSString *backgroundObjectCellTitle = nil;
        if ([cell conformsToProtocol:@protocol(CatrobatImageCell)]) {
            UITableViewCell <CatrobatImageCell>* imageCell = (UITableViewCell <CatrobatImageCell>*)cell;
            backgroundObjectCellTitle = imageCell.titleLabel.text;
        }
        XCTAssertTrue(([backgroundObjectCellTitle isEqualToString:kUILabelTextBackground]
                       || [backgroundObjectCellTitle isEqualToString:@"Background"]),
                      @"The ProgramTableViewController did not create the background object cell correctly.");

        NSUInteger objectCounter = 0;
        NSLog(@"Program: %@", program.header.programName);
        NSLog(@"Number of objects: %lu", (unsigned long)[program numberOfTotalObjects]);
        for (SpriteObject *object in program.objectList) {
            if (! objectCounter) {
                ++objectCounter;
                continue; // first object is background
            }

            indexPath = [NSIndexPath indexPathForRow:(objectCounter-1) inSection:kObjectSectionIndex];
            NSLog(@"%@", [indexPath description]);
            cell = [self.programTableViewController tableView:self.programTableViewController.tableView cellForRowAtIndexPath:indexPath];
            NSString *objectCellTitle = nil;
            if ([cell conformsToProtocol:@protocol(CatrobatImageCell)]) {
                UITableViewCell <CatrobatImageCell>* imageCell = (UITableViewCell <CatrobatImageCell>*)cell;
                objectCellTitle = imageCell.titleLabel.text;
            }
            NSLog(@"Name for object cell %@ - should be: %@", objectCellTitle, object.name);
            XCTAssertNotNil(object.name, @"Name of SpriteObject is nil, testing an empty string...");
            XCTAssertTrue([objectCellTitle isEqualToString:object.name], @"Wrong name for object cell %@ in program %@. Should be: %@", objectCellTitle, program.header.programName, object.name);
            ++objectCounter;
        }
        self.programTableViewController = nil; // unload program table view controller
    }
}

- (void)testExistingProgramsNumberOfSections
{
    NSString *basePath = [Program basePath];
    NSError *error;
    NSArray *programNames = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:basePath error:&error];
    NSLogError(error);

    for (NSString *programName in programNames) {
        // exclude .DS_Store folder on MACOSX simulator and new program
        if ([programName isEqualToString:@".DS_Store"] || [programName isEqualToString:kGeneralNewDefaultProgramName])
            continue;

        ProgramLoadingInfo *loadingInfo = [[ProgramLoadingInfo alloc] init];
        loadingInfo.basePath = [NSString stringWithFormat:@"%@%@/", [Program basePath], programName];
        loadingInfo.visibleName = programName;
        NSLog(@"Project name: %@", programName);

        self.programTableViewController.delegate = nil; // no delegate needed for this test
        self.programTableViewController.program = [Program programWithLoadingInfo:loadingInfo];
        [self.programTableViewController performSelectorOnMainThread:@selector(view) withObject:nil waitUntilDone:YES];
        [self.programTableViewController viewDidLoad];
        [self.programTableViewController viewWillAppear:NO];

        NSInteger numberOfSections = (NSInteger)[self.programTableViewController numberOfSectionsInTableView:self.programTableViewController.tableView];
        XCTAssertEqual(numberOfSections, kNumberOfSectionsInProgramTableViewController, @"Wrong number of sections in ProgramTableViewController for program: %@", programName);
        self.programTableViewController = nil; // unload program table view controller
    }
}

- (void)testExistingProgramsNumberOfBackgroundRows
{
    NSString *basePath = [Program basePath];
    NSError *error;
    NSArray *programNames = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:basePath error:&error];
    NSLogError(error);

    for (NSString *programName in programNames) {
        // exclude .DS_Store folder on MACOSX simulator and new program
        if ([programName isEqualToString:@".DS_Store"] || [programName isEqualToString:kGeneralNewDefaultProgramName])
            continue;

        ProgramLoadingInfo *loadingInfo = [[ProgramLoadingInfo alloc] init];
        loadingInfo.basePath = [NSString stringWithFormat:@"%@%@/", [Program basePath], programName];
        loadingInfo.visibleName = programName;
        NSLog(@"Project name: %@", programName);

        self.programTableViewController.delegate = nil; // no delegate needed for this test
        self.programTableViewController.program = [Program programWithLoadingInfo:loadingInfo];
        [self.programTableViewController performSelectorOnMainThread:@selector(view) withObject:nil waitUntilDone:YES];
        [self.programTableViewController viewDidLoad];
        [self.programTableViewController viewWillAppear:NO];

        NSInteger numberOfBackgroundRows = (NSInteger)[self.programTableViewController tableView:self.programTableViewController.tableView numberOfRowsInSection:kBackgroundSectionIndex];
        XCTAssertEqual(numberOfBackgroundRows, kBackgroundObjects, @"Wrong number of background rows in ProgramTableViewController for program: %@", programName);
        self.programTableViewController = nil; // unload program table view controller
    }
}

- (void)testExistingProgramsNumberOfObjectRows
{
    NSString *basePath = [Program basePath];
    NSError *error;
    NSArray *programNames = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:basePath error:&error];
    NSLogError(error);

    for (NSString *programName in programNames) {
        // exclude .DS_Store folder on MACOSX simulator and new program
        if ([programName isEqualToString:@".DS_Store"] || [programName isEqualToString:kGeneralNewDefaultProgramName])
            continue;

        ProgramLoadingInfo *loadingInfo = [[ProgramLoadingInfo alloc] init];
        loadingInfo.basePath = [NSString stringWithFormat:@"%@%@/", [Program basePath], programName];
        loadingInfo.visibleName = programName;
        NSLog(@"Project name: %@", programName);
        Program *program = [self loadProgram:loadingInfo];
        XCTAssertNotNil(program, @"Could not create program");
        if (! program) {
            NSLog(@"Loading program %@ failed", programName);
            continue;
        }

        self.programTableViewController.delegate = nil; // no delegate needed for this test
        self.programTableViewController.program = [Program programWithLoadingInfo:loadingInfo];
        [self.programTableViewController performSelectorOnMainThread:@selector(view) withObject:nil waitUntilDone:YES];
        [self.programTableViewController viewDidLoad];
        [self.programTableViewController viewWillAppear:NO];

        NSUInteger numberOfObjectRows = (NSUInteger)[self.programTableViewController tableView:self.programTableViewController.tableView numberOfRowsInSection:kObjectSectionIndex];
        XCTAssertEqual(numberOfObjectRows, [program numberOfNormalObjects], @"Wrong number of object rows in ProgramTableViewController for program: %@", program.header.programName);
        self.programTableViewController = nil; // unload program table view controller
    }
}

- (void)testExistingProgramsTestRemoveBackgroundObjectTestMustFail
{
    NSString *basePath = [Program basePath];
    NSError *error;
    NSArray *programNames = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:basePath error:&error];
    NSLogError(error);

    for (NSString *programName in programNames) {
        // exclude .DS_Store folder on MACOSX simulator and new program
        if ([programName isEqualToString:@".DS_Store"] || [programName isEqualToString:kGeneralNewDefaultProgramName])
            continue;

        ProgramLoadingInfo *loadingInfo = [[ProgramLoadingInfo alloc] init];
        loadingInfo.basePath = [NSString stringWithFormat:@"%@%@/", [Program basePath], programName];
        loadingInfo.visibleName = programName;
        NSLog(@"Project name: %@", programName);

        self.programTableViewController.delegate = nil; // no delegate needed for this test
        self.programTableViewController.program = [Program programWithLoadingInfo:loadingInfo];
        [self.programTableViewController performSelectorOnMainThread:@selector(view) withObject:nil waitUntilDone:YES];
        [self.programTableViewController viewDidLoad];
        [self.programTableViewController viewWillAppear:NO];

        NSIndexPath *indexPath = [NSIndexPath indexPathForRow:kBackgroundObjectIndex inSection:kBackgroundSectionIndex];
        BOOL result = [self.programTableViewController tableView:self.programTableViewController.tableView canEditRowAtIndexPath:indexPath];
        XCTAssertFalse(result, @"ProgramTableViewController permits removing background cell in program %@", programName);
        self.programTableViewController = nil; // unload program table view controller
    }
}

#pragma mark - getters and setters
- (ProgramTableViewController*)programTableViewController
{
    // lazy instantiation
    if (! _programTableViewController) {
        UIStoryboard *storyboard = [UIStoryboard storyboardWithName:@"iPhone" bundle:[NSBundle mainBundle]];
        _programTableViewController = [storyboard instantiateViewControllerWithIdentifier:@"ProgramTableViewController"];
        [_programTableViewController performSelectorOnMainThread:@selector(view) withObject:nil waitUntilDone:YES];
    }
    return _programTableViewController;
}

- (FileManager*)fileManager
{
    if (! _fileManager)
        _fileManager = ((AppDelegate*)[UIApplication sharedApplication].delegate).fileManager;
    return _fileManager;
}

#pragma mark - helpers
- (Program*)loadProgram:(ProgramLoadingInfo*)loadingInfo
{
    NSDebug(@"Try to load project '%@'", loadingInfo.visibleName);
    NSDebug(@"Path: %@", loadingInfo.basePath);
    NSString *xmlPath = [NSString stringWithFormat:@"%@", loadingInfo.basePath];
    NSDebug(@"XML-Path: %@", xmlPath);
    Program *program = [[[Parser alloc] init] generateObjectForProgramWithPath:[xmlPath stringByAppendingFormat:@"%@", kProgramCodeFileName]];

    if (! program)
        return nil;

    NSDebug(@"ProjectResolution: width/height:  %f / %f", program.header.screenWidth.floatValue, program.header.screenHeight.floatValue);

    // setting effect
    for (SpriteObject *sprite in program.objectList)
    {
        //sprite.spriteManagerDelegate = self;
        //sprite.broadcastWaitDelegate = self.broadcastWaitHandler;
        for (Script *script in sprite.scriptList) {
            for (Brick *brick in script.brickList) {
                brick.object = sprite;
            }
        }
    }
    [Util setLastProgram:program.header.programName];
    return program;
}

+ (void)removeProject:(NSString*)projectPath
{
    FileManager *fileManager = ((AppDelegate*)[UIApplication sharedApplication].delegate).fileManager;
    if ([fileManager directoryExists:projectPath])
        [fileManager deleteDirectory:projectPath];
    [Util setLastProgram:nil];
}

@end
