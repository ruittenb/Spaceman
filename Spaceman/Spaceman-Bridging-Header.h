//
//  Spaceman-Bridging-Header.h
//  Spaceman
//
//  Created by Sasindu Jayasinghe on 23/11/20.
//

#ifndef Spaceman_Bridging_Header_h
#define Spaceman_Bridging_Header_h

#import <Foundation/Foundation.h>

int _CGSDefaultConnection();
CFArrayRef CGSCopyManagedDisplaySpaces(int conn);
id CGSCopyActiveMenuBarDisplayIdentifier(int conn);

static inline NSString *compilationDate(void) {
    struct tm t = {0};
    strptime(__DATE__, "%b %d %Y", &t);
    char buf[9];
    strftime(buf, sizeof(buf), "%Y%m%d", &t);
    return [NSString stringWithUTF8String:buf];
}

#endif /* Spaceman_Bridging_Header_h */
