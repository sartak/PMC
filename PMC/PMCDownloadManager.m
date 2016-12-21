//
//  PMCDownloadManager.m
//  PMC
//
//  Created by Shawn Moore on 7/19/16.
//  Copyright © 2016 RPGlanguage. All rights reserved.
//

#import "PMCDownloadManager.h"
#import "PMCHTTPClient.h"

@implementation PMCDownloadManager

+(NSDirectoryEnumerator *)mediaEnumerator {
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSURL *documentsURL = [fileManager URLsForDirectory:NSCachesDirectory inDomains:NSUserDomainMask][0];
    NSURL *subdirURL = [documentsURL URLByAppendingPathComponent:@"downloaded"];
    
    NSDirectoryEnumerator *enumerator = [fileManager enumeratorAtURL:subdirURL includingPropertiesForKeys:@[NSURLNameKey] options:NSDirectoryEnumerationSkipsSubdirectoryDescendants errorHandler:nil];

    return enumerator;
}

+(unsigned long long)appDiskSpace {
    unsigned long long used = 0;
    NSDirectoryEnumerator *enumerator = [self mediaEnumerator];
    NSFileManager *fileManager = [NSFileManager defaultManager];
    
    for (NSURL *url in enumerator) {
        used += [[fileManager attributesOfItemAtPath:[url path] error:nil] fileSize];
    }
    return used;
}

+(unsigned long long)freeDiskSpace {
    unsigned long long totalSpace = 0;
    unsigned long long totalFreeSpace = 0;
    NSError *error = nil;
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSDictionary *dictionary = [[NSFileManager defaultManager] attributesOfFileSystemForPath:[paths lastObject] error: &error];
    
    if (dictionary) {
        NSNumber *fileSystemSizeInBytes = [dictionary objectForKey: NSFileSystemSize];
        NSNumber *freeFileSystemSizeInBytes = [dictionary objectForKey:NSFileSystemFreeSize];
        totalSpace = [fileSystemSizeInBytes unsignedLongLongValue];
        totalFreeSpace = [freeFileSystemSizeInBytes unsignedLongLongValue];
    } else {
        NSLog(@"Error Obtaining System Memory Info: Domain = %@, Code = %ld", [error domain], (long)[error code]);
    }
    
    return totalFreeSpace;
}

+(NSArray *)downloadedMedia {
    NSMutableArray *media = [NSMutableArray array];
    NSDirectoryEnumerator *enumerator = [self mediaEnumerator];
    
    for (NSURL *url in enumerator) {
        if ([[url pathExtension] isEqualToString:@"json"]) {
            NSDictionary *metadata = [self metadataForMetadataURL:url];
            
            // make sure the sibling media file does exist
            NSURL *mediaFile = [PMCDownloadManager URLForDownloadedMedia:metadata mustExist:YES];
            if (!mediaFile) {
                [self deleteDownloadedMedia:metadata];
                continue;
            }
            
            [media addObject:metadata];
        }
    }
    
    return [media copy];
}

+(NSArray *)downloadingMedia {
    NSMutableArray *media = [NSMutableArray array];
    [[PMCHTTPClient sharedClient].currentlyDownloading enumerateKeysAndObjectsUsingBlock:^(NSString *key, NSDictionary *value, BOOL *stop) {
        NSDictionary *record = value[@"media"];
        [media addObject:record];
    }];
    return [media copy];
}

+(NSURL *)URLForDownloadedMedia:(NSDictionary *)media mustExist:(BOOL)mustExist {
    NSString *fileName = [NSString stringWithFormat:@"%@.%@", media[@"id"], media[@"extension"]];
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSURL *documentsURL = [fileManager URLsForDirectory:NSCachesDirectory inDomains:NSUserDomainMask][0];
    NSURL *subdirURL = [documentsURL URLByAppendingPathComponent:@"downloaded"];
    NSURL *fileURL = [subdirURL URLByAppendingPathComponent:fileName];
    
    if (mustExist && ![fileManager fileExistsAtPath:fileURL.path]) {
        return nil;
    }
    
    return fileURL;
}

+(NSURL *)URLForDownloadedMediaMetadata:(NSString *)mediaId mustExist:(BOOL)mustExist {
    NSString *fileName = [NSString stringWithFormat:@"%@.json", mediaId];
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSURL *documentsURL = [fileManager URLsForDirectory:NSCachesDirectory inDomains:NSUserDomainMask][0];
    NSURL *subdirURL = [documentsURL URLByAppendingPathComponent:@"downloaded"];
    NSURL *fileURL = [subdirURL URLByAppendingPathComponent:fileName];
    
    if (mustExist && ![fileManager fileExistsAtPath:fileURL.path]) {
        return nil;
    }
    
    return fileURL;
}

+(void)deleteDownloadedMedia:(NSDictionary *)media {
    NSURL *fileURL = [self URLForDownloadedMedia:media mustExist:YES];
    NSURL *metadataURL = [self URLForDownloadedMediaMetadata:media[@"id"] mustExist:YES];
    
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSError *error;
    
    if (fileURL) {
        [fileManager removeItemAtURL:fileURL error:&error];
    }
    
    if (metadataURL) {
        [fileManager removeItemAtURL:metadataURL error:&error];
    }
}

+(NSDictionary *)metadataForMetadataURL:(NSURL *)url {
    NSError *error = nil;

    if (!url) {
        return nil;
    }

    NSData *contents = [NSData dataWithContentsOfFile:url.path options:0 error:&error];
    
    if (error) {
        NSLog(@"Error reading file %@: %@", url.path, error);
        return nil;
    }
    
    id json = [NSJSONSerialization JSONObjectWithData:contents options:0 error:&error];
    if (error) {
        NSLog(@"Error loading file %@: %@", url.path, error);
        return nil;
    }
    
    return json;
}

+(NSDictionary *)metadataForDownloadedMedia:(NSString *)mediaId {
    return [self metadataForMetadataURL:[self URLForDownloadedMediaMetadata:mediaId mustExist:YES]];
}

+(void)saveMetadataForDownloadedMedia:(NSDictionary *)media {
    NSURL *url = [self URLForDownloadedMediaMetadata:media[@"id"] mustExist:NO];
    NSError *error = nil;
    
    NSData *json = [NSJSONSerialization dataWithJSONObject:media options:0 error:&error];
    if (error) {
        NSLog(@"Error serializing JSON %@: %@", url.path, error);
        return;
    }
    
    [json writeToFile:url.path atomically:YES];
}

+(void)updateMetadataForMedia:(NSDictionary *)media {
    NSURL *url = [self URLForDownloadedMediaMetadata:media[@"id"] mustExist:YES];
    if (url) {
        [self saveMetadataForDownloadedMedia:media];
    }
}

+(NSMutableDictionary *)failedDownloads {
    static dispatch_once_t onceToken;
    static NSMutableDictionary *failedDownloads;
    dispatch_once(&onceToken, ^{
        failedDownloads = [NSMutableDictionary dictionary];
    });
    return failedDownloads;
}

+(NSArray *)failedDownloadMedia {
    NSMutableDictionary *failed = [self failedDownloads];
    NSMutableArray *records = [NSMutableArray array];
    [failed enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
        [records addObject:obj[@"media"]];
    }];
    return [records sortedArrayUsingDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:@"id" ascending:YES]]];
}

+(void)clearFailedDownloadForMedia:(NSDictionary *)media {
    NSMutableDictionary *failed = [self failedDownloads];
    [failed removeObjectForKey:media[@"id"]];
}

+(void)downloadFailedForMedia:(NSDictionary *)media withReason:(NSString *)reason {
    NSMutableDictionary *failed = [self failedDownloads];
    failed[media[@"id"]] = @{
                             @"media": media,
                             @"reason": reason,
                             };
}

+(NSString *)reasonForFailedDownloadOfMedia:(NSDictionary *)media {
    NSMutableDictionary *failed = [self failedDownloads];
    return failed[media[@"id"]][@"reason"];
}

@end
