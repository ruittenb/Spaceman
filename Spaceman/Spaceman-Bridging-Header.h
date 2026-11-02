//
//  Spaceman-Bridging-Header.h
//  Spaceman
//
//  Created by Sasindu Jayasinghe on 23/11/20.
//

#ifndef Spaceman_Bridging_Header_h
#define Spaceman_Bridging_Header_h

#pragma clang diagnostic ignored "-Wpch-date-time"

#import <Foundation/Foundation.h>

int _CGSDefaultConnection();
CFArrayRef CGSCopyManagedDisplaySpaces(int conn);
id CGSCopyActiveMenuBarDisplayIdentifier(int conn);

// Window-to-space binding APIs (for Mission Control labels)
void CGSAddWindowsToSpaces(int cid, CFArrayRef windows, CFArrayRef spaces);
void CGSRemoveWindowsFromSpaces(int cid, CFArrayRef windows, CFArrayRef spaces);
CFArrayRef CGSCopySpacesForWindows(int cid, int mask, CFArrayRef windows);

static inline NSString *compilationDate(void) {
    struct tm t = {0};
    strptime(__DATE__, "%b %d %Y", &t);
    char buf[9];
    strftime(buf, sizeof(buf), "%Y%m%d", &t);
    return [NSString stringWithUTF8String:buf];
}

#endif /* Spaceman_Bridging_Header_h */
