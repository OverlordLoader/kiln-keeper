#!/usr/bin/env python3
"""Generate KilnKeeper.xcodeproj/project.pbxproj deterministically.

Hand-writing 24-hex object IDs is error-prone, so IDs are derived from a
counter. The output is a standard Xcode project: one iOS application target
named "KilnKeeper", portrait-only, iOS 17+, plus the
Google Mobile Ads Swift package (rewarded + interstitial ads).
"""
from pathlib import Path

OUT = Path(__file__).resolve().parent.parent / "KilnKeeper.xcodeproj" / "project.pbxproj"

# Google Mobile Ads via Swift Package Manager. Pinned to the 11.x line
# (upToNextMajorVersion from 11.0.0) because its API surface is the one the
# AdsManager was written against; bumping to 12.x is a future option.
GMA_REPO = "https://github.com/googleads/swift-package-manager-google-mobile-ads.git"
GMA_MIN_VERSION = "11.0.0"

SOURCES = [
    ("KilnKeeperApp.swift", "KilnKeeper"),
    ("ContentView.swift", "KilnKeeper"),
    ("Game/Models.swift", "Game"),
    ("Game/GameState.swift", "Game"),
    ("Game/Haptics.swift", "Game"),
    ("Game/SoundManager.swift", "Game"),
    ("Game/Palette.swift", "Game"),
    ("Game/StoreManager.swift", "Game"),
    ("Game/AdsManager.swift", "Game"),
    ("Game/GlassRenderer.swift", "Game"),
    ("Game/KilnScene.swift", "Game"),
    ("Views/KilnView.swift", "Views"),
    ("Views/InventoryView.swift", "Views"),
    ("Views/UpgradeView.swift", "Views"),
    ("Views/SettingsView.swift", "Views"),
    ("Views/AwaySummaryView.swift", "Views"),
]

# Non-source resources copied into the app bundle.
RESOURCES = [
    ("Assets.xcassets", "folder.assetcatalog"),
    ("PrivacyInfo.xcprivacy", "text.plist.xml"),
]

_counter = [0]


def nid():
    _counter[0] += 1
    return f"{_counter[0]:024X}"


build_files = {s: nid() for s, _ in SOURCES}
file_refs = {s: nid() for s, _ in SOURCES}
info_plist_ref = nid()
app_ref = nid()
res_build_files = {r: nid() for r, _ in RESOURCES}
res_file_refs = {r: nid() for r, _ in RESOURCES}

# Swift Package Manager: Google Mobile Ads
gma_pkg_ref = nid()        # XCRemoteSwiftPackageReference
gma_product_dep = nid()    # XCSwiftPackageProductDependency
gma_build_file = nid()     # PBXBuildFile (GoogleMobileAds in Frameworks)

main_group = nid()
kilnkeeper_group = nid()
game_group = nid()
views_group = nid()
products_group = nid()

sources_phase = nid()
frameworks_phase = nid()
resources_phase = nid()

native_target = nid()
project = nid()

proj_debug = nid()
proj_release = nid()
tgt_debug = nid()
tgt_release = nid()
proj_config_list = nid()
tgt_config_list = nid()


def q(s):
    return s


lines = []
A = lines.append

A("// !$*UTF8*$!")
A("{")
A("\tarchiveVersion = 1;")
A("\tclasses = {")
A("\t};")
A("\tobjectVersion = 60;")
A("\tobjects = {")

# --- PBXBuildFile ---
A("")
A("/* Begin PBXBuildFile section */")
for s, _ in SOURCES:
    name = s.split("/")[-1]
    A(f"\t\t{build_files[s]} /* {name} in Sources */ = {{isa = PBXBuildFile; fileRef = {file_refs[s]} /* {name} */; }};")
A(f"\t\t{gma_build_file} /* GoogleMobileAds in Frameworks */ = {{isa = PBXBuildFile; productRef = {gma_product_dep} /* GoogleMobileAds */; }};")
for r, _ in RESOURCES:
    A(f"\t\t{res_build_files[r]} /* {r} in Resources */ = {{isa = PBXBuildFile; fileRef = {res_file_refs[r]} /* {r} */; }};")
A("/* End PBXBuildFile section */")

# --- PBXFileReference ---
A("")
A("/* Begin PBXFileReference section */")
for s, _ in SOURCES:
    name = s.split("/")[-1]
    A(f"\t\t{file_refs[s]} /* {name} */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = {name}; sourceTree = \"<group>\"; }};")
A(f"\t\t{info_plist_ref} /* Info.plist */ = {{isa = PBXFileReference; lastKnownFileType = text.plist.xml; path = Info.plist; sourceTree = \"<group>\"; }};")
for r, ftype in RESOURCES:
    A(f"\t\t{res_file_refs[r]} /* {r} */ = {{isa = PBXFileReference; lastKnownFileType = {ftype}; path = {r}; sourceTree = \"<group>\"; }};")
A(f"\t\t{app_ref} /* KilnKeeper.app */ = {{isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = KilnKeeper.app; sourceTree = BUILT_PRODUCTS_DIR; }};")
A("/* End PBXFileReference section */")

# --- PBXFrameworksBuildPhase ---
A("")
A("/* Begin PBXFrameworksBuildPhase section */")
A(f"\t\t{frameworks_phase} /* Frameworks */ = {{")
A("\t\t\tisa = PBXFrameworksBuildPhase;")
A("\t\t\tbuildActionMask = 2147483647;")
A("\t\t\tfiles = (")
A(f"\t\t\t\t{gma_build_file} /* GoogleMobileAds in Frameworks */,")
A("\t\t\t);")
A("\t\t\trunOnlyForDeploymentPostprocessing = 0;")
A("\t\t};")
A("/* End PBXFrameworksBuildPhase section */")

# --- PBXGroup ---
A("")
A("/* Begin PBXGroup section */")
A(f"\t\t{main_group} = {{")
A("\t\t\tisa = PBXGroup;")
A("\t\t\tchildren = (")
A(f"\t\t\t\t{kilnkeeper_group} /* KilnKeeper */,")
A(f"\t\t\t\t{products_group} /* Products */,")
A("\t\t\t);")
A("\t\t\tsourceTree = \"<group>\";")
A("\t\t};")
kilnkeeper_children = (
    [file_refs["KilnKeeperApp.swift"],
     file_refs["ContentView.swift"],
     info_plist_ref]
    + [res_file_refs[r] for r, _ in RESOURCES]
    + [game_group, views_group]
)
A(f"\t\t{kilnkeeper_group} /* KilnKeeper */ = {{")
A("\t\t\tisa = PBXGroup;")
A("\t\t\tchildren = (")
for c in kilnkeeper_children:
    A(f"\t\t\t\t{c},")
A("\t\t\t);")
A('\t\t\tpath = KilnKeeper;')
A("\t\t\tsourceTree = \"<group>\";")
A("\t\t};")
A(f"\t\t{game_group} /* Game */ = {{")
A("\t\t\tisa = PBXGroup;")
A("\t\t\tchildren = (")
for s, g in SOURCES:
    if g == "Game":
        A(f"\t\t\t\t{file_refs[s]},")
A("\t\t\t);")
A('\t\t\tpath = Game;')
A("\t\t\tsourceTree = \"<group>\";")
A("\t\t};")
A(f"\t\t{views_group} /* Views */ = {{")
A("\t\t\tisa = PBXGroup;")
A("\t\t\tchildren = (")
for s, g in SOURCES:
    if g == "Views":
        A(f"\t\t\t\t{file_refs[s]},")
A("\t\t\t);")
A('\t\t\tpath = Views;')
A("\t\t\tsourceTree = \"<group>\";")
A("\t\t};")
A(f"\t\t{products_group} /* Products */ = {{")
A("\t\t\tisa = PBXGroup;")
A("\t\t\tchildren = (")
A(f"\t\t\t\t{app_ref} /* KilnKeeper.app */,")
A("\t\t\t);")
A("\t\t\tname = Products;")
A("\t\t\tsourceTree = \"<group>\";")
A("\t\t};")
A("/* End PBXGroup section */")

# --- PBXNativeTarget ---
A("")
A("/* Begin PBXNativeTarget section */")
A(f"\t\t{native_target} /* KilnKeeper */ = {{")
A("\t\t\tisa = PBXNativeTarget;")
A("\t\t\tbuildConfigurationList = " + tgt_config_list + " /* Build configuration list for PBXNativeTarget \"KilnKeeper\" */;")
A("\t\t\tbuildPhases = (")
A(f"\t\t\t\t{sources_phase} /* Sources */,")
A(f"\t\t\t\t{frameworks_phase} /* Frameworks */,")
A(f"\t\t\t\t{resources_phase} /* Resources */,")
A("\t\t\t);")
A("\t\t\tbuildRules = (")
A("\t\t\t);")
A("\t\t\tdependencies = (")
A("\t\t\t);")
A('\t\t\tname = KilnKeeper;')
A("\t\t\tproductName = KilnKeeper;")
A(f"\t\t\tproductReference = {app_ref} /* KilnKeeper.app */;")
A('\t\t\tproductType = "com.apple.product-type.application";')
A("\t\t};")
A("/* End PBXNativeTarget section */")

# --- PBXProject ---
A("")
A("/* Begin PBXProject section */")
A(f"\t\t{project} /* Project object */ = {{")
A("\t\t\tisa = PBXProject;")
A("\t\t\tattributes = {")
A("\t\t\t\tLastSwiftUpdateCheck = 1600;")
A("\t\t\t\tLastUpgradeCheck = 1600;")
A("\t\t\t\tTargetAttributes = {")
A(f"\t\t\t\t\t{native_target} = {{")
A("\t\t\t\t\t\tCreatedOnToolsVersion = 16.0;")
A("\t\t\t\t\t};")
A("\t\t\t\t};")
A("\t\t\t};")
A("\t\t\tbuildConfigurationList = " + proj_config_list + " /* Build configuration list for PBXProject \"KilnKeeper\" */;")
A("\t\t\tcompatibilityVersion = \"Xcode 16.0\";")
A("\t\t\tdevelopmentRegion = en;")
A("\t\t\thasScannedForEncodings = 0;")
A("\t\t\tknownRegions = (")
A("\t\t\t\ten,")
A("\t\t\t\tBase,")
A("\t\t\t);")
A("\t\t\tmainGroup = " + main_group + ";")
A("\t\t\tpackageReferences = (")
A(f"\t\t\t\t{gma_pkg_ref} /* XCRemoteSwiftPackageReference \"swift-package-manager-google-mobile-ads\" */,")
A("\t\t\t);")
A("\t\t\tproductRefGroup = " + products_group + " /* Products */;")
A("\t\t\tprojectDirPath = \"\";")
A("\t\t\tprojectRoot = \"\";")
A("\t\t\ttargets = (")
A(f"\t\t\t\t{native_target} /* KilnKeeper */,")
A("\t\t\t);")
A("\t\t};")
A("/* End PBXProject section */")

# --- PBXResourcesBuildPhase ---
A("")
A("/* Begin PBXResourcesBuildPhase section */")
A(f"\t\t{resources_phase} /* Resources */ = {{")
A("\t\t\tisa = PBXResourcesBuildPhase;")
A("\t\t\tbuildActionMask = 2147483647;")
A("\t\t\tfiles = (")
for r, _ in RESOURCES:
    A(f"\t\t\t\t{res_build_files[r]} /* {r} in Resources */,")
A("\t\t\t);")
A("\t\t\trunOnlyForDeploymentPostprocessing = 0;")
A("\t\t};")
A("/* End PBXResourcesBuildPhase section */")

# --- PBXSourcesBuildPhase ---
A("")
A("/* Begin PBXSourcesBuildPhase section */")
A(f"\t\t{sources_phase} /* Sources */ = {{")
A("\t\t\tisa = PBXSourcesBuildPhase;")
A("\t\t\tbuildActionMask = 2147483647;")
A("\t\t\tfiles = (")
for s, _ in SOURCES:
    name = s.split("/")[-1]
    A(f"\t\t\t\t{build_files[s]} /* {name} in Sources */,")
A("\t\t\t);")
A("\t\t\trunOnlyForDeploymentPostprocessing = 0;")
A("\t\t};")
A("/* End PBXSourcesBuildPhase section */")

# --- XCRemoteSwiftPackageReference + XCSwiftPackageProductDependency ---
A("")
A("/* Begin XCRemoteSwiftPackageReference section */")
A(f"\t\t{gma_pkg_ref} /* XCRemoteSwiftPackageReference \"swift-package-manager-google-mobile-ads\" */ = {{")
A("\t\t\tisa = XCRemoteSwiftPackageReference;")
A(f"\t\t\trepositoryURL = \"{GMA_REPO}\";")
A("\t\t\trequirement = {")
A("\t\t\t\tkind = upToNextMajorVersion;")
A(f"\t\t\t\tminimumVersion = {GMA_MIN_VERSION};")
A("\t\t\t};")
A("\t\t};")
A("/* End XCRemoteSwiftPackageReference section */")
A("")
A("/* Begin XCSwiftPackageProductDependency section */")
A(f"\t\t{gma_product_dep} /* GoogleMobileAds */ = {{")
A("\t\t\tisa = XCSwiftPackageProductDependency;")
A(f"\t\t\tpackage = {gma_pkg_ref} /* XCRemoteSwiftPackageReference \"swift-package-manager-google-mobile-ads\" */;")
A("\t\t\tproductName = GoogleMobileAds;")
A("\t\t};")
A("/* End XCSwiftPackageProductDependency section */")

# --- XCBuildConfiguration ---
A("")
A("/* Begin XCBuildConfiguration section */")
A(f"\t\t{proj_debug} /* Debug */ = {{")
A("\t\t\tisa = XCBuildConfiguration;")
A("\t\t\tbuildSettings = {")
A("\t\t\t\tALWAYS_SEARCH_USER_PATHS = NO;")
A("\t\t\t\tCLANG_ANALYZER_NONNULL = YES;")
A("\t\t\t\tCLANG_CXX_LANGUAGE_STANDARD = \"gnu++20\";")
A("\t\t\t\tCOPY_PHASE_STRIP = NO;")
A("\t\t\t\tDEBUG_INFORMATION_FORMAT = dwarf;")
A("\t\t\t\tENABLE_STRICT_OBJC_MSGSEND = YES;")
A("\t\t\t\tGCC_C_LANGUAGE_STANDARD = gnu17;")
A("\t\t\t\tMTL_ENABLE_DEBUG_INFO = INCLUDE_SOURCE;")
A("\t\t\t\tMTL_FAST_MATH = YES;")
A("\t\t\t\tONLY_ACTIVE_ARCH = YES;")
A("\t\t\t\tSDKROOT = iphoneos;")
A("\t\t\t\tSWIFT_ACTIVE_COMPILATION_CONDITIONS = DEBUG;")
A("\t\t\t\tSWIFT_OPTIMIZATION_LEVEL = \"-Onone\";")
A("\t\t\t};")
A("\t\t\tname = Debug;")
A("\t\t};")
A(f"\t\t{proj_release} /* Release */ = {{")
A("\t\t\tisa = XCBuildConfiguration;")
A("\t\t\tbuildSettings = {")
A("\t\t\t\tALWAYS_SEARCH_USER_PATHS = NO;")
A("\t\t\t\tCLANG_ANALYZER_NONNULL = YES;")
A("\t\t\t\tCLANG_CXX_LANGUAGE_STANDARD = \"gnu++20\";")
A("\t\t\t\tCOPY_PHASE_STRIP = NO;")
A("\t\t\t\tDEBUG_INFORMATION_FORMAT = \"dwarf-with-dsym\";")
A("\t\t\t\tENABLE_STRICT_OBJC_MSGSEND = YES;")
A("\t\t\t\tGCC_C_LANGUAGE_STANDARD = gnu17;")
A("\t\t\t\tMTL_ENABLE_DEBUG_INFO = NO;")
A("\t\t\t\tMTL_FAST_MATH = YES;")
A("\t\t\t\tSDKROOT = iphoneos;")
A("\t\t\t\tSWIFT_COMPILATION_MODE = wholemodule;")
A("\t\t\t\tSWIFT_OPTIMIZATION_LEVEL = \"-O\";")
A("\t\t\t};")
A("\t\t\tname = Release;")
A("\t\t};")

target_common = [
    'ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;',
    'CODE_SIGN_STYLE = Automatic;',
    'CURRENT_PROJECT_VERSION = 1;',
    'DEVELOPMENT_TEAM = "";',
    'GENERATE_INFOPLIST_FILE = NO;',
    'INFOPLIST_FILE = "KilnKeeper/Info.plist";',
    'INFOPLIST_KEY_CFBundleDisplayName = Kiln Keeper;',
    'INFOPLIST_KEY_LSRequiresIPhoneOS = YES;',
    'INFOPLIST_KEY_UIDeviceFamily = "1,2";',
    'INFOPLIST_KEY_UISupportedInterfaceOrientations = "UIInterfaceOrientationPortrait";',
    'IPHONEOS_DEPLOYMENT_TARGET = 17.0;',
    'MARKETING_VERSION = 1.0;',
    'PRODUCT_BUNDLE_IDENTIFIER = app.kilnkeeper.game;',
    'PRODUCT_NAME = "$(TARGET_NAME)";',
    'SDKROOT = iphoneos;',
    'SWIFT_EMIT_LOC_STRINGS = YES;',
    'SWIFT_VERSION = 5.0;',
    'TARGETED_DEVICE_FAMILY = "1,2";',
]
A(f"\t\t{tgt_debug} /* Debug */ = {{")
A("\t\t\tisa = XCBuildConfiguration;")
A("\t\t\tbuildSettings = {")
for s in target_common:
    A(f"\t\t\t\t{s}")
A("\t\t\t\tDEBUG_INFORMATION_FORMAT = dwarf;")
A("\t\t\t\tENABLE_TESTABILITY = YES;")
A("\t\t\t\tGCC_OPTIMIZATION_LEVEL = 0;")
A("\t\t\t\tMTL_ENABLE_DEBUG_INFO = INCLUDE_SOURCE;")
A("\t\t\t\tONLY_ACTIVE_ARCH = YES;")
A("\t\t\t\tSWIFT_ACTIVE_COMPILATION_CONDITIONS = DEBUG;")
A("\t\t\t\tSWIFT_OPTIMIZATION_LEVEL = \"-Onone\";")
A("\t\t\t};")
A("\t\t\tname = Debug;")
A("\t\t};")
A(f"\t\t{tgt_release} /* Release */ = {{")
A("\t\t\tisa = XCBuildConfiguration;")
A("\t\t\tbuildSettings = {")
for s in target_common:
    A(f"\t\t\t\t{s}")
A("\t\t\t\tCOPY_PHASE_STRIP = NO;")
A("\t\t\t\tDEBUG_INFORMATION_FORMAT = \"dwarf-with-dsym\";")
A("\t\t\t\tGCC_OPTIMIZATION_LEVEL = s;")
A("\t\t\t\tMTL_ENABLE_DEBUG_INFO = NO;")
A("\t\t\t\tSWIFT_COMPILATION_MODE = wholemodule;")
A("\t\t\t\tSWIFT_OPTIMIZATION_LEVEL = \"-O\";")
A("\t\t\t\tVALIDATE_PRODUCT = YES;")
A("\t\t\t};")
A("\t\t\tname = Release;")
A("\t\t};")
A("/* End XCBuildConfiguration section */")

# --- XCConfigurationList ---
A("")
A("/* Begin XCConfigurationList section */")
A(f"\t\t{proj_config_list} /* Build configuration list for PBXProject \"KilnKeeper\" */ = {{")
A("\t\t\tisa = XCConfigurationList;")
A("\t\t\tbuildConfigurations = (")
A(f"\t\t\t\t{proj_debug} /* Debug */,")
A(f"\t\t\t\t{proj_release} /* Release */,")
A("\t\t\t);")
A("\t\t\tdefaultConfigurationIsVisible = 0;")
A("\t\t\tdefaultConfigurationName = Release;")
A("\t\t};")
A(f"\t\t{tgt_config_list} /* Build configuration list for PBXNativeTarget \"KilnKeeper\" */ = {{")
A("\t\t\tisa = XCConfigurationList;")
A("\t\t\tbuildConfigurations = (")
A(f"\t\t\t\t{tgt_debug} /* Debug */,")
A(f"\t\t\t\t{tgt_release} /* Release */,")
A("\t\t\t);")
A("\t\t\tdefaultConfigurationIsVisible = 0;")
A("\t\t\tdefaultConfigurationName = Release;")
A("\t\t};")
A("/* End XCConfigurationList section */")

A("\t};")
A(f"\trootObject = {project} /* Project object */;")
A("}")

OUT.parent.mkdir(parents=True, exist_ok=True)
OUT.write_text("\n".join(lines) + "\n")
print(f"wrote {OUT} ({OUT.stat().st_size} bytes)")
