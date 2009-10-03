//
//  APMetaProvider.m
//  MetaZ
//
//  Created by Brian Olsen on 23/09/09.
//  Copyright 2009 Maven-Group. All rights reserved.
//

#import "APDataProvider.h"
#import "APWriteManager.h"

@interface APDataProvider (Private)

- (NSString *)launchPath;

@end

@implementation APDataProvider

- (id)init
{
    self = [super init];
    if(self)
    {
        writes = [[NSMutableArray alloc] init];
        types = [[NSArray alloc] initWithObjects:
            @"public.mpeg-4", @"com.apple.quicktime-movie",
            @"com.apple.protected-mpeg-4-video", nil];
        tags = [[MZTag allKnownTags] retain];
        NSArray* readmapkeys = [NSArray arrayWithObjects:
            @"©nam", @"©ART", @"©day", @"com.apple.iTunes;iTunEXTC", @"©gen",
            @"©alb", @"aART", @"purd", @"desc",
            @"ldes",
            //@"stik",
            @"tvsh", @"tven",
            @"tvsn", @"tves", @"tvnn", @"purl",
            @"egid", @"catg", @"keyw", @"rtng",
            @"pcst", @"cprt", @"©grp", @"©too",
            @"©cmt", @"pgap", @"cpil", @"sonm",
            @"soar", @"soaa", @"soal",
            @"sosn", nil];
        NSArray* readmapvalues = [NSArray arrayWithObjects:
            MZTitleTagIdent, MZArtistTagIdent, MZDateTagIdent, MZRatingTagIdent, MZGenreTagIdent,
            MZAlbumTagIdent, MZAlbumArtistTagIdent, MZPurchaseDateTagIdent, MZShortDescriptionTagIdent,
            MZLongDescriptionTagIdent,
            //MZVideoTypeTagIdent,
            MZTVShowTagIdent, MZTVEpisodeIDTagIdent,
            MZTVSeasonTagIdent, MZTVEpisodeTagIdent, MZTVNetworkTagIdent, MZFeedURLTagIdent,
            MZEpisodeURLTagIdent, MZCategoryTagIdent, MZKeywordTagIdent, MZAdvisoryTagIdent,
            MZPodcastTagIdent, MZCopyrightTagIdent, MZGroupingTagIdent, MZEncodingToolTagIdent,
            MZCommentTagIdent, MZGaplessTagIdent, MZCompilationTagIdent, MZSortTitleTagIdent,
            MZSortArtistTagIdent, MZSortAlbumArtistTagIdent, MZSortAlbumTagIdent,
            MZSortTVShowTagIdent,nil];
        read_mapping = [[NSDictionary alloc]
            initWithObjects:readmapvalues
                    forKeys:readmapkeys];


        NSArray* writemapkeys = [NSArray arrayWithObjects:
            MZTitleTagIdent, MZArtistTagIdent, MZDateTagIdent, MZRatingTagIdent, MZGenreTagIdent,
            MZAlbumTagIdent, MZAlbumArtistTagIdent, MZPurchaseDateTagIdent, MZShortDescriptionTagIdent,
            //MZLongDescriptionTagIdent, MZVideoTypeTagIdent,
            MZTVShowTagIdent, MZTVEpisodeIDTagIdent,
            MZTVSeasonTagIdent, MZTVEpisodeTagIdent, MZTVNetworkTagIdent, MZFeedURLTagIdent,
            MZEpisodeURLTagIdent, MZCategoryTagIdent, MZKeywordTagIdent, MZAdvisoryTagIdent,
            MZPodcastTagIdent, MZCopyrightTagIdent, MZGroupingTagIdent, MZEncodingToolTagIdent,
            MZCommentTagIdent, MZGaplessTagIdent, MZCompilationTagIdent,
            nil];
            //MZSortTitleTagIdent, MZSortArtistTagIdent, MZSortAlbumArtistTagIdent,
            //MZSortAlbumTagIdent, MZSortTVShowTagIdent,nil];
        NSArray* writemapvalues = [NSArray arrayWithObjects:
            @"title", @"artist", @"year", @"contentRating", @"genre",
            @"album", @"albumArtist", @"purchaseDate", @"description",
            //@"ldes", @"stik",
            @"TVShowName", @"TVEpisode",
            @"TVSeasonNum", @"TVEpisodeNum", @"TVNetwork", @"podcastURL",
            @"podcastGUID",@"category", @"keyword", @"advisory",
            @"podcastFlag", @"copyright", @"grouping", @"encodingTool",
            @"comment", @"gapless", @"compilation",
            nil];
            //@"sonm", @"soar", @"soaa",
            //@"soal", @"sosn", nil];
        write_mapping = [[NSDictionary alloc]
            initWithObjects:writemapvalues
                    forKeys:writemapkeys];

    }
    return self;
}

- (void)dealloc
{
    [writes release];
    [types release];
    [tags release];
    [read_mapping release];
    [write_mapping release];
    [super dealloc];
}

- (NSString *)identifier
{
    return @"org.maven-group.MetaZ.AtomicParsleyPlugin";
}

-(NSArray *)types
{
    return types;
}

-(NSArray *)providedTags
{
    return tags;
}

- (MetaLoaded *)loadFromFile:(NSString *)fileName
{
    NSTask* task = [[NSTask alloc] init];
    [task setLaunchPath:[self launchPath]];
    [task setArguments:[NSArray arrayWithObjects:fileName, @"-t", nil]];
    NSPipe* out = [NSPipe pipe];
    [task setStandardOutput:out];
    [task launch];
    
    NSData* data = [[out fileHandleForReading] readDataToEndOfFile];
    [task waitUntilExit];
    [task release];
    NSString* str = [[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] autorelease];
    NSArray* atoms = [str componentsSeparatedByString:@"Atom \""];
    
    NSMutableDictionary* dict = [NSMutableDictionary dictionaryWithCapacity:[atoms count]];
    for(NSString* atom in atoms)
    {
        NSRange split = [atom rangeOfString:@"\" contains: "];
        if(split.location == NSNotFound)
            continue;
        NSString* type = [atom substringToIndex:split.location];
        NSString* content = [[atom substringFromIndex:split.location+split.length] 
                stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        [dict setObject:content forKey:type];
    }
    
    NSMutableDictionary* retdict = [NSMutableDictionary dictionaryWithCapacity:[tags count]];
    // Initialize a null value for all known keys
    for(MZTag* tag in tags)
        [retdict setObject:[NSNull null] forKey:[tag identifier]];

    // Store real parsed values using a simple key -> key mapping
    for(NSString* map in [read_mapping allKeys])
    {
        id value = [dict objectForKey:map];
        if(value)
            [retdict setObject:value forKey:[read_mapping objectForKey:map]];
    }
    
    // Special video type handling (stik)
    NSString* stik = [dict objectForKey:@"stik"];
    if(stik)
    {
        MZVideoType stikNo = MZUnsetVideoType;
        if([stik isEqualToString:@"Movie"])
            stikNo = MZMovieVideoType;
        else if([stik isEqualToString:@"Normal"])
            stikNo = MZNormalVideoType;
        else if([stik isEqualToString:@"Audiobook"])
            stikNo = MZAudiobookVideoType;
        else if([stik isEqualToString:@"Whacked Bookmark"])
            stikNo = MZWhackedBookmarkVideoType;
        else if([stik isEqualToString:@"Music Video"])
            stikNo = MZMusicVideoType;
        else if([stik isEqualToString:@"Short Film"])
            stikNo = MZShortFilmVideoType;
        else if([stik isEqualToString:@"TV Show"])
            stikNo = MZTVShowVideoType;
        else if([stik isEqualToString:@"Booklet"])
            stikNo = MZBookletVideoType;
        if(stikNo!=MZUnsetVideoType)
        {
            MZTag* tag = [MZTag tagForIdentifier:MZVideoTypeTagIdent];
            [retdict setObject:[tag nullConvertValueToObject:&stikNo]
                        forKey:MZVideoTypeTagIdent];
        }
    }
    
    // Special image handling
    NSString* covr = [dict objectForKey:@"covr"];
    if(covr)
    {
        task = [[NSTask alloc] init];
        [task setLaunchPath:[self launchPath]];
        NSString* file = NSTemporaryDirectory();
        if(!file)
            file = @"/tmp";
        
        file = [file stringByAppendingPathComponent:
            [NSString stringWithFormat:@"MetaZImage_%@",
                [[NSProcessInfo processInfo] globallyUniqueString]]];
        [task setArguments:[NSArray arrayWithObjects:fileName, @"-e", file, nil]];
        [task launch];
        [task waitUntilExit];
        [task release];
        
        file = [file stringByAppendingString:@"_artwork_1"];
        
        NSFileManager* mgr = [NSFileManager defaultManager];
        BOOL isDir;
        if([mgr fileExistsAtPath:[file stringByAppendingString:@".png"] isDirectory:&isDir] && !isDir)
        {
            NSData* data = [NSData dataWithContentsOfFile:[file stringByAppendingString:@".png"]];
            [retdict setObject:data forKey:MZPictureTagIdent];
            [mgr removeItemAtPath:[file stringByAppendingString:@".png"] error:NULL];
        }
        else if([mgr fileExistsAtPath:[file stringByAppendingString:@".jpg"] isDirectory:&isDir] && !isDir)
        {
            NSData* data = [NSData dataWithContentsOfFile:[file stringByAppendingString:@".jpg"]];
            [retdict setObject:data forKey:MZPictureTagIdent];
            [mgr removeItemAtPath:[file stringByAppendingString:@".jpg"] error:NULL];
        }
    }
    
    // Special handling for cast, directors, producers and screenwriters
    NSString* iTunMOVIStr = [dict objectForKey:@"com.apple.iTunes;iTunMOVI"];
    if(iTunMOVIStr)
    {
        NSDictionary* iTunMOVI = [iTunMOVIStr propertyList];
        NSArray* value = [iTunMOVI objectForKey:@"cast"];
        if(value)
        {
            value = [value arrayByPerformingSelector:@selector(objectForKey:) withObject:@"name"];
            [retdict setObject:[value componentsJoinedByString:@", "] forKey:MZActorsTagIdent];
        }

        value = [iTunMOVI objectForKey:@"directors"];
        if(value)
        {
            value = [value arrayByPerformingSelector:@selector(objectForKey:) withObject:@"name"];
            [retdict setObject:[value componentsJoinedByString:@", "] forKey:MZDirectorTagIdent];
        }

        value = [iTunMOVI objectForKey:@"producers"];
        if(value)
        {
            value = [value arrayByPerformingSelector:@selector(objectForKey:) withObject:@"name"];
            [retdict setObject:[value componentsJoinedByString:@", "] forKey:MZProducerTagIdent];
        }

        value = [iTunMOVI objectForKey:@"screenwriters"];
        if(value)
        {
            value = [value arrayByPerformingSelector:@selector(objectForKey:) withObject:@"name"];
            [retdict setObject:[value componentsJoinedByString:@", "] forKey:MZScreenwriterTagIdent];
        }
    }
    
    // Special handling of track
    NSString* trkn = [dict objectForKey:@"trkn"];
    if(trkn)
    {
        // TODO
    }
    
    // Special handling of disc num
    NSString* disk = [dict objectForKey:@"disk"];
    if(disk)
    {
        // TODO
    }
        
    [retdict setObject:[fileName lastPathComponent] forKey:MZFileNameTagIdent];
    return [MetaLoaded metaWithOwner:self filename:fileName dictionary:retdict];
}

void sortTags(NSMutableArray* args, NSDictionary* changes, NSString* tag, NSString* sortType)
{
    id value = [changes objectForKey:tag];
    if(value == [NSNull null])
        value = @"";
    if(value)
    {
        [args addObject:@"--sortOrder"];
        [args addObject:sortType];
        [args addObject:value];
    }
}


-(id<MZDataWriteController>)saveChanges:(MetaEdits *)data
          delegate:(id<MZDataWriteDelegate>)delegate;
{
    NSMutableArray* args = [NSMutableArray array];
    [args addObject:[data loadedFileName]];
    
    [args addObject:@"--output"];
    [args addObject:[data savedTempFileName]];
    
    NSDictionary* changes = [data changes];
    for(NSString* key in [changes allKeys])
    {
        id value = [changes objectForKey:key];
        if(value == [NSNull null])
            value = @"";
        NSString* map = [write_mapping objectForKey:key];
        if(map)
        {
            [args addObject:[@"--" stringByAppendingString:map]];
            [args addObject:value];
        }
    }
    
    id stikNo = [changes objectForKey:MZVideoTypeTagIdent];
    if(stikNo)
    {
        MZVideoType stik;
        MZTag* tag = [MZTag tagForIdentifier:MZVideoTypeTagIdent];
        [tag nullConvertObject:stikNo toValue:&stik];
        NSString* stikStr = nil;
        switch (stik) {
            case MZUnsetVideoType:
                stikStr = @"";
                break;
            case MZMovieVideoType:
                stikStr = @"Movie";
                break;
            case MZNormalVideoType:
                stikStr = @"Normal";
                break;
            case MZAudiobookVideoType:
                stikStr = @"Audiobook";
                break;
            case MZWhackedBookmarkVideoType:
                stikStr = @"Whacked Bookmark";
                break;
            case MZMusicVideoType:
                stikStr = @"Music Video";
                break;
            case MZShortFilmVideoType:
                stikStr = @"Short Film";
                break;
            case MZTVShowVideoType:
                stikStr = @"TV Show";
                break;
            case MZBookletVideoType:
                stikStr = @"Booklet";
                break;
        }
        if(stikStr)
        {
            [args addObject:@"--stik"];
            [args addObject:stikStr];
        }
    }
    
    // Sort tags
    sortTags(args, changes, MZSortTitleTagIdent, @"name");
    sortTags(args, changes, MZSortArtistTagIdent, @"artist");
    sortTags(args, changes, MZSortAlbumArtistTagIdent, @"albumartist");
    sortTags(args, changes, MZSortAlbumTagIdent, @"album");
    sortTags(args, changes, MZSortTVShowTagIdent, @"show");
    sortTags(args, changes, MZSortComposerTagIdent, @"composer");
    
    id pictureObj = [changes objectForKey:MZPictureTagIdent];
    NSString* pictureFile = nil;
    if(pictureObj == [NSNull null])
    {
        [args addObject:@"--artwork"];
        [args addObject:@"REMOVE_ALL"];
    }
    else if(pictureObj)
    {
        NSData* picture = pictureObj;
        pictureFile = NSTemporaryDirectory();
        if(!pictureFile)
            pictureFile = @"/tmp";
        
        pictureFile = [pictureFile stringByAppendingPathComponent:
            [NSString stringWithFormat:@"MetaZImage_%@.png",
                [[NSProcessInfo processInfo] globallyUniqueString]]];
                
        //NSData *imageData = [picture TIFFRepresentation];
        NSBitmapImageRep* imageRep = [NSBitmapImageRep imageRepWithData:picture];
        picture = [imageRep representationUsingType:NSPNGFileType properties:[NSDictionary dictionary]];
        if([picture writeToFile:pictureFile atomically:NO])
        {
            [args addObject:@"--artwork"];
            [args addObject:@"REMOVE_ALL"];
            [args addObject:@"--artwork"];
            [args addObject:pictureFile];
        }
        else
        {
            NSLog(@"Failed to write image to temp '%@'", pictureFile);
            pictureFile = nil;
        }
    }

    NSTask* task = [[[NSTask alloc] init] autorelease];
    [task setLaunchPath:[self launchPath]];
    [task setArguments:args];
    
    APWriteManager* manager = [APWriteManager
            managerWithTask:task
                   delegate:delegate
                      edits:data
                pictureFile:pictureFile];
    [manager launch];
    [writes addObject:manager];
    
    return manager;
}

- (NSString *)launchPath
{
    NSBundle* myBundle = [NSBundle bundleForClass:[self class]];
    return [myBundle pathForResource:@"AtomicParsley32" ofType:nil];
}

@end
