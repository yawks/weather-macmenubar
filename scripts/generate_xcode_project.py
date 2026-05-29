import hashlib
import plistlib
import sys
from pathlib import Path


def make_id(text: str, prefix: str) -> str:
    digest = hashlib.md5(text.encode("utf-8")).hexdigest()[:24].upper()
    return f"{prefix}{digest}"


def build_pbxproj(root_dir: Path, project_dir: Path) -> str:
    source_files = [
        root_dir / "WeatherBar" / "App" / "PopoverPanel.swift",
        root_dir / "WeatherBar" / "App" / "StatusBarController.swift",
        root_dir / "WeatherBar" / "App" / "WeatherBarApp.swift",
        root_dir / "WeatherBar" / "Models" / "WeatherModels.swift",
        root_dir / "WeatherBar" / "Services" / "LocationService.swift",
        root_dir / "WeatherBar" / "Services" / "OpenWeatherMapProvider.swift",
        root_dir / "WeatherBar" / "Services" / "WeatherIconMapper.swift",
        root_dir / "WeatherBar" / "Services" / "WeatherManager.swift",
        root_dir / "WeatherBar" / "Services" / "WeatherProvider.swift",
        root_dir / "WeatherBar" / "Views" / "MainWeatherView.swift",
        root_dir / "WeatherBar" / "Views" / "SettingsView.swift",
        root_dir / "WeatherBar" / "Views" / "WeatherChartView.swift",
    ]

    file_refs = {}
    build_files = {}
    for source in source_files:
        rel_path = source.relative_to(root_dir).as_posix()
        file_ref_id = make_id(rel_path, "A")
        build_file_id = make_id(rel_path + ":build", "B")
        file_refs[rel_path] = file_ref_id
        build_files[rel_path] = build_file_id

    project_id = "C0000000"
    main_group_id = "C0000001"
    product_group_id = "C0000002"
    product_file_id = "C0000003"
    target_id = "C0000004"
    project_config_list_id = "C0000005"
    target_config_list_id = "C0000006"
    debug_config_id = "C0000007"
    release_config_id = "C0000008"
    app_group_id = "C0000009"
    model_group_id = "C0000010"
    service_group_id = "C0000011"
    view_group_id = "C0000012"
    resource_group_id = "C0000013"

    app_group_children = [
        f"{file_refs[rel_path]} /* {rel_path} */"
        for rel_path in sorted(file_refs)
        if "/App/" in rel_path
    ]
    model_group_children = [
        f"{file_refs[rel_path]} /* {rel_path} */"
        for rel_path in sorted(file_refs)
        if "/Models/" in rel_path
    ]
    service_group_children = [
        f"{file_refs[rel_path]} /* {rel_path} */"
        for rel_path in sorted(file_refs)
        if "/Services/" in rel_path
    ]
    view_group_children = [
        f"{file_refs[rel_path]} /* {rel_path} */"
        for rel_path in sorted(file_refs)
        if "/Views/" in rel_path
    ]

    lines = [
        "// !$*UTF8*$!",
        "{",
        "\tarchiveVersion = 1;",
        "\tclasses = {",
        "\t};",
        "\tobjectVersion = 54;",
        "\tobjects = {",
        "",
    ]

    lines.append("\t\t/* Begin PBXBuildFile section */")
    for rel_path in sorted(build_files):
        build_id = build_files[rel_path]
        file_id = file_refs[rel_path]
        lines.append(f"\t\t{build_id} /* {rel_path} in Sources */ = {{isa = PBXBuildFile; fileRef = {file_id} /* {rel_path} */; }};")
    lines.append("\t\t/* End PBXBuildFile section */")
    lines.append("")

    lines.append("\t\t/* Begin PBXFileReference section */")
    for rel_path in sorted(file_refs):
        file_id = file_refs[rel_path]
        lines.append(
            f"\t\t{file_id} /* {rel_path} */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = {rel_path}; sourceTree = \"<group>\"; }};"
        )
    lines.append(
        '\t\tA1000001 /* Info.plist */ = {isa = PBXFileReference; lastKnownFileType = text.plist.xml; path = "Info.plist"; sourceTree = "<group>"; };'
    )
    lines.append("\t\t/* End PBXFileReference section */")
    lines.append("")

    lines.append("\t\t/* Begin PBXGroup section */")
    lines.append("\t\tC0000001 /* Products */ = {")
    lines.append("\t\t\tchildren = (")
    lines.append("\t\t\t\tC0000002 /* WeatherBar.app */,")
    lines.append("\t\t\t);")
    lines.append("\t\t\tname = Products;")
    lines.append("\t\t\tpath = \"\";")
    lines.append("\t\t\tsourceTree = \"<group>\";")
    lines.append("\t\t};")

    lines.append("\t\tC0000002 /* WeatherBar */ = {")
    lines.append("\t\t\tchildren = (")
    lines.append("\t\t\t\tC0000003 /* App */,")
    lines.append("\t\t\t\tC0000004 /* Models */,")
    lines.append("\t\t\t\tC0000005 /* Services */,")
    lines.append("\t\t\t\tC0000006 /* Views */,")
    lines.append("\t\t\t\tC0000007 /* Resources */,")
    lines.append("\t\t\t);")
    lines.append("\t\t\tname = WeatherBar;")
    lines.append("\t\t\tpath = \".\";")
    lines.append("\t\t\tsourceTree = \"<group>\";")
    lines.append("\t\t};")

    lines.append("\t\tC0000003 /* App */ = {")
    lines.append("\t\t\tchildren = (")
    lines.extend(f"\t\t\t\t{entry}," for entry in app_group_children)
    lines.append("\t\t\t);")
    lines.append("\t\t\tname = App;")
    lines.append("\t\t\tpath = \"WeatherBar/App\";")
    lines.append("\t\t\tsourceTree = \"<group>\";")
    lines.append("\t\t};")

    lines.append("\t\tC0000004 /* Models */ = {")
    lines.append("\t\t\tchildren = (")
    lines.extend(f"\t\t\t\t{entry}," for entry in model_group_children)
    lines.append("\t\t\t);")
    lines.append("\t\t\tname = Models;")
    lines.append("\t\t\tpath = \"WeatherBar/Models\";")
    lines.append("\t\t\tsourceTree = \"<group>\";")
    lines.append("\t\t};")

    lines.append("\t\tC0000005 /* Services */ = {")
    lines.append("\t\t\tchildren = (")
    lines.extend(f"\t\t\t\t{entry}," for entry in service_group_children)
    lines.append("\t\t\t);")
    lines.append("\t\t\tname = Services;")
    lines.append("\t\t\tpath = \"WeatherBar/Services\";")
    lines.append("\t\t\tsourceTree = \"<group>\";")
    lines.append("\t\t};")

    lines.append("\t\tC0000006 /* Views */ = {")
    lines.append("\t\t\tchildren = (")
    lines.extend(f"\t\t\t\t{entry}," for entry in view_group_children)
    lines.append("\t\t\t);")
    lines.append("\t\t\tname = Views;")
    lines.append("\t\t\tpath = \"WeatherBar/Views\";")
    lines.append("\t\t\tsourceTree = \"<group>\";")
    lines.append("\t\t};")

    lines.append("\t\tC0000007 /* Resources */ = {")
    lines.append("\t\t\tchildren = (")
    lines.append("\t\t\t\tA1000001 /* Info.plist */,")
    lines.append("\t\t\t);")
    lines.append("\t\t\tname = Resources;")
    lines.append("\t\t\tpath = \".\";")
    lines.append("\t\t\tsourceTree = \"<group>\";")
    lines.append("\t\t};")
    lines.append("\t\t/* End PBXGroup section */")
    lines.append("")

    lines.append("\t\t/* Begin PBXNativeTarget section */")
    lines.append("\t\tC0000004 /* WeatherBar */ = {")
    lines.append("\t\t\tbuildConfigurationList = C0000006 /* Build configuration list for PBXNativeTarget \"WeatherBar\" */;")
    lines.append("\t\t\tbuildPhases = (")
    lines.append("\t\t\t\tD0000001 /* Sources */,")
    lines.append("\t\t\t\tD0000002 /* Frameworks */,")
    lines.append("\t\t\t\tD0000003 /* Resources */,")
    lines.append("\t\t\t);")
    lines.append("\t\t\tbuildRules = (")
    lines.append("\t\t\t);")
    lines.append("\t\t\tdependencies = (")
    lines.append("\t\t\t);")
    lines.append("\t\t\tname = WeatherBar;")
    lines.append("\t\t\tproductName = WeatherBar;")
    lines.append("\t\t\tproductReference = C0000002 /* WeatherBar.app */;")
    lines.append("\t\t\tproductType = \"com.apple.product-type.application\";")
    lines.append("\t\t};")
    lines.append("\t\t/* End PBXNativeTarget section */")
    lines.append("")

    lines.append("\t\t/* Begin PBXSourcesBuildPhase section */")
    lines.append("\t\tD0000001 /* Sources */ = {")
    lines.append("\t\t\tbuildActionMask = 2147483647;")
    lines.append("\t\t\trunOnlyForDeploymentPostprocessing = 0;")
    lines.append("\t\t\tfiles = (")
    for rel_path in sorted(build_files):
        build_id = build_files[rel_path]
        lines.append(f"\t\t\t\t{build_id} /* {rel_path} in Sources */,")
    lines.append("\t\t\t);")
    lines.append("\t\t\tname = Sources;")
    lines.append("\t\t};")
    lines.append("\t\t/* End PBXSourcesBuildPhase section */")
    lines.append("")

    lines.append("\t\t/* Begin PBXFrameworksBuildPhase section */")
    lines.append("\t\tD0000002 /* Frameworks */ = {")
    lines.append("\t\t\tbuildActionMask = 2147483647;")
    lines.append("\t\t\trunOnlyForDeploymentPostprocessing = 0;")
    lines.append("\t\t\tfiles = (")
    lines.append("\t\t\t);")
    lines.append("\t\t\tname = Frameworks;")
    lines.append("\t\t};")
    lines.append("\t\t/* End PBXFrameworksBuildPhase section */")
    lines.append("")

    lines.append("\t\t/* Begin PBXResourcesBuildPhase section */")
    lines.append("\t\tD0000003 /* Resources */ = {")
    lines.append("\t\t\tbuildActionMask = 2147483647;")
    lines.append("\t\t\trunOnlyForDeploymentPostprocessing = 0;")
    lines.append("\t\t\tfiles = (")
    lines.append("\t\t\t);")
    lines.append("\t\t\tname = Resources;")
    lines.append("\t\t};")
    lines.append("\t\t/* End PBXResourcesBuildPhase section */")
    lines.append("")

    lines.append("\t\t/* Begin XCConfigurationList section */")
    lines.append("\t\tC0000006 /* Build configuration list for PBXNativeTarget \"WeatherBar\" */ = {")
    lines.append("\t\t\tbuildConfigurations = (")
    lines.append("\t\t\t\tC0000007 /* Debug */,")
    lines.append("\t\t\t\tC0000008 /* Release */,")
    lines.append("\t\t\t);")
    lines.append("\t\t\tdefaultConfigurationIsVisible = 0;")
    lines.append("\t\t\tdefaultConfigurationName = Release;")
    lines.append("\t\t};")
    lines.append("\t\tC0000005 /* Build configuration list for PBXProject \"WeatherBar\" */ = {")
    lines.append("\t\t\tbuildConfigurations = (")
    lines.append("\t\t\t\tC0000007 /* Debug */,")
    lines.append("\t\t\t\tC0000008 /* Release */,")
    lines.append("\t\t\t);")
    lines.append("\t\t\tdefaultConfigurationIsVisible = 0;")
    lines.append("\t\t\tdefaultConfigurationName = Release;")
    lines.append("\t\t};")
    lines.append("\t\t/* End XCConfigurationList section */")
    lines.append("")

    lines.append("\t\t/* Begin XCBuildConfiguration section */")
    lines.append("\t\tC0000007 /* Debug */ = {")
    lines.append("\t\t\tbuildSettings = {")
    lines.append("\t\t\t\tALWAYS_SEARCH_USER_PATHS = NO;")
    lines.append("\t\t\t\tCLANG_ENABLE_MODULES = YES;")
    lines.append("\t\t\t\tCODE_SIGN_IDENTITY = \"-\";")
    lines.append("\t\t\t\tCODE_SIGN_STYLE = Automatic;")
    lines.append("\t\t\t\tCOMBINE_HIDPI_IMAGES = YES;")
    lines.append("\t\t\t\tGENERATE_INFOPLIST_FILE = NO;")
    lines.append("\t\t\t\tINFOPLIST_FILE = Info.plist;")
    lines.append("\t\t\t\tLD_RUNPATH_SEARCH_PATHS = \"$(inherited) @executable_path/../Frameworks\";")
    lines.append("\t\t\t\tMACOSX_DEPLOYMENT_TARGET = 13.0;")
    lines.append("\t\t\t\tMARKETING_VERSION = 1.0;")
    lines.append("\t\t\t\tPRODUCT_BUNDLE_IDENTIFIER = com.local.WeatherBar;")
    lines.append("\t\t\t\tPRODUCT_NAME = \"$(TARGET_NAME)\";")
    lines.append("\t\t\t\tSDKROOT = macosx;")
    lines.append("\t\t\t\tSWIFT_COMPILATION_MODE = singlefile;")
    lines.append("\t\t\t\tSWIFT_EMIT_LOC_STRINGS = YES;")
    lines.append("\t\t\t\tSWIFT_OPTIMIZATION_LEVEL = \"-Onone\";")
    lines.append("\t\t\t\tSWIFT_VERSION = 6.0;")
    lines.append("\t\t\t};")
    lines.append("\t\t\tname = Debug;")
    lines.append("\t\t};")
    lines.append("\t\tC0000008 /* Release */ = {")
    lines.append("\t\t\tbuildSettings = {")
    lines.append("\t\t\t\tALWAYS_SEARCH_USER_PATHS = NO;")
    lines.append("\t\t\t\tCLANG_ENABLE_MODULES = YES;")
    lines.append("\t\t\t\tCODE_SIGN_IDENTITY = \"-\";")
    lines.append("\t\t\t\tCODE_SIGN_STYLE = Automatic;")
    lines.append("\t\t\t\tCOMBINE_HIDPI_IMAGES = YES;")
    lines.append("\t\t\t\tGENERATE_INFOPLIST_FILE = NO;")
    lines.append("\t\t\t\tINFOPLIST_FILE = Info.plist;")
    lines.append("\t\t\t\tLD_RUNPATH_SEARCH_PATHS = \"$(inherited) @executable_path/../Frameworks\";")
    lines.append("\t\t\t\tMACOSX_DEPLOYMENT_TARGET = 13.0;")
    lines.append("\t\t\t\tMARKETING_VERSION = 1.0;")
    lines.append("\t\t\t\tPRODUCT_BUNDLE_IDENTIFIER = com.local.WeatherBar;")
    lines.append("\t\t\t\tPRODUCT_NAME = \"$(TARGET_NAME)\";")
    lines.append("\t\t\t\tSDKROOT = macosx;")
    lines.append("\t\t\t\tSWIFT_COMPILATION_MODE = wholemodule;")
    lines.append("\t\t\t\tSWIFT_EMIT_LOC_STRINGS = YES;")
    lines.append("\t\t\t\tSWIFT_OPTIMIZATION_LEVEL = \"-O\";")
    lines.append("\t\t\t\tSWIFT_VERSION = 6.0;")
    lines.append("\t\t\t};")
    lines.append("\t\t\tname = Release;")
    lines.append("\t\t};")
    lines.append("\t\t/* End XCBuildConfiguration section */")
    lines.append("")

    lines.append("\t\t/* Begin PBXProject section */")
    lines.append("\t\tattributes = {")
    lines.append("\t\t\tLastUpgradeCheck = 1500;")
    lines.append("\t\t\tORGANIZATIONNAME = WeatherBar;")
    lines.append("\t\t};")
    lines.append("\t\tbuildConfigurationList = C0000005 /* Build configuration list for PBXProject \"WeatherBar\" */;")
    lines.append("\t\tcompatibilityVersion = \"Xcode 14.0\";")
    lines.append("\t\tdevelopmentRegion = en;")
    lines.append("\t\thasScannedForEncodings = 0;")
    lines.append("\t\tknownRegions = (")
    lines.append("\t\t\ten,")
    lines.append("\t\t\t);")
    lines.append("\t\tmainGroup = C0000002 /* WeatherBar */;")
    lines.append("\t\tproductRefGroup = C0000001 /* Products */;")
    lines.append("\t\tprojectDirPath = \"\";")
    lines.append("\t\tprojectRoot = \"\";")
    lines.append("\t\ttargets = (")
    lines.append("\t\t\tC0000004 /* WeatherBar */,")
    lines.append("\t\t\t);")
    lines.append("\t\t};")
    lines.append("\t\t/* End PBXProject section */")
    lines.append("")

    lines.append("\t\tC0000000 /* Project object */ = {")
    lines.append("\t\t\tisa = PBXProject;")
    lines.append("\t\t\tbuildConfigurationList = C0000005 /* Build configuration list for PBXProject \"WeatherBar\" */;")
    lines.append("\t\t\tcompatibilityVersion = \"Xcode 14.0\";")
    lines.append("\t\t\tdevelopmentRegion = en;")
    lines.append("\t\t\thasScannedForEncodings = 0;")
    lines.append("\t\t\tknownRegions = (")
    lines.append("\t\t\t\ten,")
    lines.append("\t\t\t);")
    lines.append("\t\t\tmainGroup = C0000002 /* WeatherBar */;")
    lines.append("\t\t\tproductRefGroup = C0000001 /* Products */;")
    lines.append("\t\t\ttargets = (")
    lines.append("\t\t\t\tC0000004 /* WeatherBar */,")
    lines.append("\t\t\t);")
    lines.append("\t\t};")
    lines.append("\t};")
    lines.append("\trootObject = C0000000 /* Project object */;")
    lines.append("};")
    return "\n".join(lines) + "\n"


def write_project_files(output_project: Path, root_dir: Path) -> None:
    output_project = output_project.resolve()
    root_dir = root_dir.resolve()

    output_project.mkdir(parents=True, exist_ok=True)
    (output_project / "project.xcworkspace").mkdir(parents=True, exist_ok=True)
    (output_project / "xcshareddata").mkdir(parents=True, exist_ok=True)
    (output_project / "xcshareddata" / "xcschemes").mkdir(parents=True, exist_ok=True)

    (output_project / "project.xcworkspace" / "contents.xcworkspacedata").write_text(
        "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n"
        "<Workspace\n"
        "   version = \"1.0\">\n"
        "   <FileRef\n"
        "      location = \"self:WeatherBar.xcodeproj\">\n"
        "   </FileRef>\n"
        "</Workspace>\n"
    )

    (output_project / "xcshareddata" / "xcschemes" / "WeatherBar.xcscheme").write_text(
        "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n"
        "<Scheme\n"
        "   LastUpgradeVersion = \"1500\"\n"
        "   version = \"1.7\">\n"
        "   <BuildAction\n"
        "      parallelizeBuildables = \"YES\"\n"
        "      buildImplicitDependencies = \"YES\">\n"
        "      <BuildActionEntries>\n"
        "         <BuildActionEntry\n"
        "            buildForTesting = \"NO\"\n"
        "            buildForRunning = \"YES\"\n"
        "            buildForProfiling = \"YES\"\n"
        "            buildForArchiving = \"YES\"\n"
        "            buildForAnalyzing = \"YES\">\n"
        "            <BuildableReference\n"
        "               BuildableIdentifier = \"primary\"\n"
        "               BlueprintIdentifier = \"C0000004\"\n"
        "               BuildableName = \"WeatherBar.app\"\n"
        "               BlueprintName = \"WeatherBar\"\n"
        "               ReferencedContainer = \"container:WeatherBar.xcodeproj\">\n"
        "            </BuildableReference>\n"
        "         </BuildActionEntry>\n"
        "      </BuildActionEntries>\n"
        "   </BuildAction>\n"
        "   <LaunchAction\n"
        "      buildConfiguration = \"Debug\"\n"
        "      selectedDebuggerIdentifier = \"Xcode.DebuggerFoundation.Debugger.LLDB\"\n"
        "      selectedLauncherIdentifier = \"Xcode.DebuggerFoundation.Launcher.LLDB\"\n"
        "      launchStyle = \"0\"\n"
        "      useCustomWorkingDirectory = \"NO\"\n"
        "      ignoresPersistentStateOnLaunch = \"NO\"\n"
        "      debugDocumentVersioning = \"YES\"\n"
        "      debugServiceExtension = \"internal\"\n"
        "      allowLocationSimulation = \"YES\">\n"
        "      <BuildableProductRunnable\n"
        "         runnableDebuggingMode = \"0\">\n"
        "         <BuildableReference\n"
        "            BuildableIdentifier = \"primary\"\n"
        "            BlueprintIdentifier = \"C0000004\"\n"
        "            BuildableName = \"WeatherBar.app\"\n"
        "            BlueprintName = \"WeatherBar\"\n"
        "            ReferencedContainer = \"container:WeatherBar.xcodeproj\">\n"
        "         </BuildableReference>\n"
        "      </BuildableProductRunnable>\n"
        "   </LaunchAction>\n"
        "</Scheme>\n"
    )

    info_plist = root_dir / "Info.plist"
    plist_data = {
        "CFBundleDevelopmentRegion": "en",
        "CFBundleExecutable": "$(EXECUTABLE_NAME)",
        "CFBundleIdentifier": "com.local.WeatherBar",
        "CFBundleInfoDictionaryVersion": "6.0",
        "CFBundleName": "$(PRODUCT_NAME)",
        "CFBundlePackageType": "APPL",
        "CFBundleShortVersionString": "1.0",
        "CFBundleVersion": "1",
        "LSMinimumSystemVersion": "13.0",
        "LSUIElement": True,
        "NSPrincipalClass": "NSApplication",
    }
    with info_plist.open("wb") as fh:
        plistlib.dump(plist_data, fh)

    (output_project / "project.pbxproj").write_text(build_pbxproj(root_dir, output_project))


if __name__ == "__main__":
    if len(sys.argv) != 3:
        raise SystemExit("Usage: generate_xcode_project.py <output-project> <root-dir>")

    write_project_files(Path(sys.argv[1]), Path(sys.argv[2]))
