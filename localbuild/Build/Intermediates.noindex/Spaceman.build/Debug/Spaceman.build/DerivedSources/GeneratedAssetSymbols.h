#import <Foundation/Foundation.h>

#if __has_attribute(swift_private)
#define AC_SWIFT_PRIVATE __attribute__((swift_private))
#else
#define AC_SWIFT_PRIVATE
#endif

/// The resource bundle ID.
static NSString * const ACBundleID AC_SWIFT_PRIVATE = @"dev.ruittenb.Spaceman";

/// The "AccentColor" asset catalog color resource.
static NSString * const ACColorNameAccentColor AC_SWIFT_PRIVATE = @"AccentColor";

/// The "SpaceIconBorderedNumInactive" asset catalog image resource.
static NSString * const ACImageNameSpaceIconBorderedNumInactive AC_SWIFT_PRIVATE = @"SpaceIconBorderedNumInactive";

/// The "SpaceIconNamedFullActive" asset catalog image resource.
static NSString * const ACImageNameSpaceIconNamedFullActive AC_SWIFT_PRIVATE = @"SpaceIconNamedFullActive";

/// The "SpaceIconNamedFullInactive" asset catalog image resource.
static NSString * const ACImageNameSpaceIconNamedFullInactive AC_SWIFT_PRIVATE = @"SpaceIconNamedFullInactive";

/// The "SpaceIconNamedNormalActive" asset catalog image resource.
static NSString * const ACImageNameSpaceIconNamedNormalActive AC_SWIFT_PRIVATE = @"SpaceIconNamedNormalActive";

/// The "SpaceIconNamedNormalInactive" asset catalog image resource.
static NSString * const ACImageNameSpaceIconNamedNormalInactive AC_SWIFT_PRIVATE = @"SpaceIconNamedNormalInactive";

/// The "SpaceIconNumFullActive" asset catalog image resource.
static NSString * const ACImageNameSpaceIconNumFullActive AC_SWIFT_PRIVATE = @"SpaceIconNumFullActive";

/// The "SpaceIconNumFullInactive" asset catalog image resource.
static NSString * const ACImageNameSpaceIconNumFullInactive AC_SWIFT_PRIVATE = @"SpaceIconNumFullInactive";

/// The "SpaceIconNumNormalActive" asset catalog image resource.
static NSString * const ACImageNameSpaceIconNumNormalActive AC_SWIFT_PRIVATE = @"SpaceIconNumNormalActive";

/// The "SpaceIconNumNormalInactive" asset catalog image resource.
static NSString * const ACImageNameSpaceIconNumNormalInactive AC_SWIFT_PRIVATE = @"SpaceIconNumNormalInactive";

#undef AC_SWIFT_PRIVATE
