import re
import os

REFS = {
    "main_swift": "A1A1A10111159973516BB785",
    "service_swift": "A1A1A10211159973516BB785",
    "info_plist": "A1A1A10311159973516BB785",
    "build_main_swift": "A1A1A10411159973516BB785",
    "build_service_swift": "A1A1A10511159973516BB785",
    "build_info_plist": "A1A1A10611159973516BB785",
    "target_xpc": "A1A1A10711159973516BB785",
    "phase_sources_xpc": "A1A1A10811159973516BB785",
    "phase_frameworks_xpc": "A1A1A10911159973516BB785",
    "phase_resources_xpc": "A1A1A10A11159973516BB785",
    "config_debug_xpc": "A1A1A10B11159973516BB785",
    "config_release_xpc": "A1A1A10C11159973516BB785",
    "config_list_xpc": "A1A1A10D11159973516BB785",
    "dep_xpc_app": "A1A1A10E11159973516BB785",
    "proxy_xpc_app": "A1A1A10F11159973516BB785",
    "phase_copy_xpc_app": "A1A1A11011159973516BB785",
    "group_xpc": "A1A1A11111159973516BB785",
    "build_core_xpc": "A1A1A11211159973516BB785",
    "product_xpc": "A1A1A11311159973516BB785",
    "build_xpc_bundle": "A1A1A11411159973516BB785"
}

PACKAGE_CORE_UUID = "38B4793F12BE4C852414ED2F"
APP_TARGET_UUID = "5D68C60BA1C59CB2A79D13F0"
PROJECT_PATH = "MeetingAssistant.xcodeproj/project.pbxproj"

def insert_into_section(content, section_name, lines):
    begin_marker = f"/* Begin {section_name} section */"
    end_marker = f"/* End {section_name} section */"
    
    if begin_marker not in content:
        if section_name == "PBXContainerItemProxy":
            content = content.replace("/* Begin PBXFileReference section */", f"{begin_marker}\n{end_marker}\n/* Begin PBXFileReference section */")
        elif section_name == "PBXTargetDependency":
            content = content.replace("/* Begin PBXVariantGroup section */", f"{begin_marker}\n{end_marker}\n/* Begin PBXVariantGroup section */")
        elif section_name == "PBXCopyFilesBuildPhase":
            content = content.replace("/* Begin PBXFrameworksBuildPhase section */", f"{begin_marker}\n{end_marker}\n/* Begin PBXFrameworksBuildPhase section */")
        else:
            print(f"Warning: Section {section_name} not found and no rule to create it.")
            return content

    return content.replace(end_marker, lines + "\n" + end_marker)

def patch_pbxproj():
    with open(PROJECT_PATH, 'r') as f:
        content = f.read()

    project_object_id = re.search(r'([A-Z0-9]+) /\* Project object \*/', content).group(1)

    # 1. PBXBuildFile
    build_files = f"""\t\t{REFS['build_core_xpc']} /* MeetingAssistantCore in Frameworks */ = {{isa = PBXBuildFile; productRef = {PACKAGE_CORE_UUID} /* MeetingAssistantCore */; }};
\t\t{REFS['build_main_swift']} /* main.swift in Sources */ = {{isa = PBXBuildFile; fileRef = {REFS['main_swift']} /* main.swift */; }};
\t\t{REFS['build_service_swift']} /* MeetingAssistantAIService.swift in Sources */ = {{isa = PBXBuildFile; fileRef = {REFS['service_swift']} /* MeetingAssistantAIService.swift */; }};
\t\t{REFS['build_info_plist']} /* Info.plist in Resources */ = {{isa = PBXBuildFile; fileRef = {REFS['info_plist']} /* Info.plist */; }};
\t\t{REFS['build_xpc_bundle']} /* MeetingAssistantAI.xpc in Embed XPCServices */ = {{isa = PBXBuildFile; fileRef = {REFS['product_xpc']} /* MeetingAssistantAI.xpc */; }};"""
    content = insert_into_section(content, "PBXBuildFile", build_files)

    # 2. PBXFileReference
    file_refs = f"""\t\t{REFS['product_xpc']} /* MeetingAssistantAI.xpc */ = {{isa = PBXFileReference; explicitFileType = wrapper.xpc-service; includeInIndex = 0; path = MeetingAssistantAI.xpc; sourceTree = BUILT_PRODUCTS_DIR; }};
\t\t{REFS['main_swift']} /* main.swift */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = main.swift; sourceTree = "<group>"; }};
\t\t{REFS['service_swift']} /* MeetingAssistantAIService.swift */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = MeetingAssistantAIService.swift; sourceTree = "<group>"; }};
\t\t{REFS['info_plist']} /* Info.plist */ = {{isa = PBXFileReference; lastKnownFileType = text.plist; path = Info.plist; sourceTree = "<group>"; }};"""
    content = insert_into_section(content, "PBXFileReference", file_refs)

    # 3. PBXFrameworksBuildPhase
    frameworks_phase = f"""\t\t{REFS['phase_frameworks_xpc']} /* Frameworks */ = {{
\t\t\tisa = PBXFrameworksBuildPhase;
\t\t\tbuildActionMask = 2147483647;
\t\t\tfiles = (
\t\t\t\t{REFS['build_core_xpc']} /* MeetingAssistantCore in Frameworks */,
\t\t\t);
\t\t\trunOnlyForDeploymentPostprocessing = 0;
\t\t}};"""
    content = insert_into_section(content, "PBXFrameworksBuildPhase", frameworks_phase)

    # 4. PBXGroup
    ai_group = f"""\t\t{REFS['group_xpc']} /* MeetingAssistantAI */ = {{
\t\t\tisa = PBXGroup;
\t\t\tchildren = (
\t\t\t\t{REFS['group_xpc']}_res /* Resources */,
\t\t\t\t{REFS['group_xpc']}_src /* Sources */,
\t\t\t);
\t\t\tpath = MeetingAssistantAI;
\t\t\tsourceTree = "<group>";
\t\t}};
\t\t{REFS['group_xpc']}_res /* Resources */ = {{
\t\t\tisa = PBXGroup;
\t\t\tchildren = (
\t\t\t\t{REFS['info_plist']} /* Info.plist */,
\t\t\t);
\t\t\tpath = Resources;
\t\t\tsourceTree = "<group>";
\t\t}};
\t\t{REFS['group_xpc']}_src /* Sources */ = {{
\t\t\tisa = PBXGroup;
\t\t\tchildren = (
\t\t\t\t{REFS['service_swift']} /* MeetingAssistantAIService.swift */,
\t\t\t\t{REFS['main_swift']} /* main.swift */,
\t\t\t);
\t\t\tpath = Sources;
\t\t\tsourceTree = "<group>";
\t\t}};"""
    content = insert_into_section(content, "PBXGroup", ai_group)
    
    main_group_id = re.search(r'mainGroup = ([A-Z0-9]+)', content).group(1)
    content = re.sub(rf'({main_group_id} = \{{[^}}]+children = \(\n)', rf'\1\t\t\t\t{REFS["group_xpc"]} /* MeetingAssistantAI */,\n', content)
    content = re.sub(r'(Products = \{[^}]+children = \(\n)', rf'\1\t\t\t\t{REFS["product_xpc"]} /* MeetingAssistantAI.xpc */,\n', content)

    # 5. PBXNativeTarget
    xpc_target = f"""\t\t{REFS['target_xpc']} /* MeetingAssistantAI */ = {{
\t\t\tisa = PBXNativeTarget;
\t\t\tbuildConfigurationList = {REFS['config_list_xpc']} /* Build configuration list for PBXNativeTarget "MeetingAssistantAI" */;
\t\t\tbuildPhases = (
\t\t\t\t{REFS['phase_sources_xpc']} /* Sources */,
\t\t\t\t{REFS['phase_resources_xpc']} /* Resources */,
\t\t\t\t{REFS['phase_frameworks_xpc']} /* Frameworks */,
\t\t\t);
\t\t\tbuildRules = (
\t\t\t);
\t\t\tdependencies = (
\t\t\t);
\t\t\tname = MeetingAssistantAI;
\t\t\tproductName = MeetingAssistantAI;
\t\t\tproductReference = {REFS['product_xpc']} /* MeetingAssistantAI.xpc */;
\t\t\tproductType = "com.apple.product-type.xpc-service";
\t\t}};"""
    content = insert_into_section(content, "PBXNativeTarget", xpc_target)
    content = re.sub(r'(targets = \(\n)', rf'\1\t\t\t\t{REFS["target_xpc"]} /* MeetingAssistantAI */,\n', content)

    # 6. Build Phases
    resources_phase = f"""\t\t{REFS['phase_resources_xpc']} /* Resources */ = {{
\t\t\tisa = PBXResourcesBuildPhase;
\t\t\tbuildActionMask = 2147483647;
\t\t\tfiles = (
\t\t\t\t{REFS['build_info_plist']} /* Info.plist in Resources */,
\t\t\t);
\t\t\trunOnlyForDeploymentPostprocessing = 0;
\t\t}};"""
    content = insert_into_section(content, "PBXResourcesBuildPhase", resources_phase)

    sources_phase = f"""\t\t{REFS['phase_sources_xpc']} /* Sources */ = {{
\t\t\tisa = PBXSourcesBuildPhase;
\t\t\tbuildActionMask = 2147483647;
\t\t\tfiles = (
\t\t\t\t{REFS['build_service_swift']} /* MeetingAssistantAIService.swift in Sources */,
\t\t\t\t{REFS['build_main_swift']} /* main.swift in Sources */,
\t\t\t);
\t\t\trunOnlyForDeploymentPostprocessing = 0;
\t\t}};"""
    content = insert_into_section(content, "PBXSourcesBuildPhase", sources_phase)

    # 7. XCBuildConfiguration
    configs = f"""\t\t{REFS['config_debug_xpc']} /* Debug */ = {{
\t\t\tisa = XCBuildConfiguration;
\t\t\tbuildSettings = {{
\t\t\t\tENABLE_HARDENED_RUNTIME = YES;
\t\t\t\tINFOPLIST_FILE = MeetingAssistantAI/Resources/Info.plist;
\t\t\t\tLD_RUNPATH_SEARCH_PATHS = (
\t\t\t\t\t"$(inherited)",
\t\t\t\t\t"@executable_path/../Frameworks",
\t\t\t\t\t"@loader_path/../Frameworks",
\t\t\t\t);
\t\t\t\tPRODUCT_BUNDLE_IDENTIFIER = com.mourato.my-meeting-assistant.ai-service;
\t\t\t\tPRODUCT_NAME = "$(TARGET_NAME)";
\t\t\t\tSDKROOT = macosx;
\t\t\t\tSKIP_INSTALL = YES;
\t\t\t\tSWIFT_VERSION = 6.0;
\t\t\t}};
\t\t\tname = Debug;
\t\t}};
\t\t{REFS['config_release_xpc']} /* Release */ = {{
\t\t\tisa = XCBuildConfiguration;
\t\t\tbuildSettings = {{
\t\t\t\tENABLE_HARDENED_RUNTIME = YES;
\t\t\t\tINFOPLIST_FILE = MeetingAssistantAI/Resources/Info.plist;
\t\t\t\tLD_RUNPATH_SEARCH_PATHS = (
\t\t\t\t\t"$(inherited)",
\t\t\t\t\t"@executable_path/../Frameworks",
\t\t\t\t\t"@loader_path/../Frameworks",
\t\t\t\t);
\t\t\t\tPRODUCT_BUNDLE_IDENTIFIER = com.mourato.my-meeting-assistant.ai-service;
\t\t\t\tPRODUCT_NAME = "$(TARGET_NAME)";
\t\t\t\tSDKROOT = macosx;
\t\t\t\tSKIP_INSTALL = YES;
\t\t\t\tSWIFT_VERSION = 6.0;
\t\t\t}};
\t\t\tname = Release;
\t\t}};"""
    content = insert_into_section(content, "XCBuildConfiguration", configs)

    # 8. XCConfigurationList
    config_list = f"""\t\t{REFS['config_list_xpc']} /* Build configuration list for PBXNativeTarget "MeetingAssistantAI" */ = {{
\t\t\tisa = XCConfigurationList;
\t\t\tbuildConfigurations = (
\t\t\t\t{REFS['config_debug_xpc']} /* Debug */,
\t\t\t\t{REFS['config_release_xpc']} /* Release */,
\t\t\t);
\t\t\tdefaultConfigurationIsVisible = 0;
\t\t\tdefaultConfigurationName = Release;
\t\t}};"""
    content = insert_into_section(content, "XCConfigurationList", config_list)

    # 9. PBXContainerItemProxy
    proxy = f"""\t\t{REFS['proxy_xpc_app']} /* PBXContainerItemProxy */ = {{
\t\t\tisa = PBXContainerItemProxy;
\t\t\tcontainerPortal = {project_object_id} /* Project object */;
\t\t\tproxyType = 1;
\t\t\tremoteGlobalIDString = {REFS['target_xpc']};
\t\t\tremoteInfo = MeetingAssistantAI;
\t\t}};"""
    content = insert_into_section(content, "PBXContainerItemProxy", proxy)

    # 10. PBXTargetDependency
    dep = f"""\t\t{REFS['dep_xpc_app']} /* PBXTargetDependency */ = {{
\t\t\tisa = PBXTargetDependency;
\t\t\ttarget = {REFS['target_xpc']} /* MeetingAssistantAI */;
\t\t\ttargetProxy = {REFS['proxy_xpc_app']} /* PBXContainerItemProxy */;
\t\t}};"""
    content = insert_into_section(content, "PBXTargetDependency", dep)
    
    # Precise injection into MeetingAssistant dependency list
    app_target_pos = content.find(APP_TARGET_UUID)
    if app_target_pos != -1:
        deps_pos = content.find("dependencies = (", app_target_pos)
        if deps_pos != -1:
            eol = content.find("\n", deps_pos)
            content = content[:eol+1] + f"\t\t\t\t{REFS['dep_xpc_app']} /* PBXTargetDependency */,\n" + content[eol+1:]

    # 11. PBXCopyFilesBuildPhase
    copy_phase = f"""\t\t{REFS['phase_copy_xpc_app']} /* Embed XPCServices */ = {{
\t\t\tisa = PBXCopyFilesBuildPhase;
\t\t\tbuildActionMask = 2147483647;
\t\t\tdstPath = "";
\t\t\tdstSubfolderSpec = 13;
\t\t\tfiles = (
\t\t\t\t{REFS['build_xpc_bundle']} /* MeetingAssistantAI.xpc in Embed XPCServices */,
\t\t\t);
\t\t\tname = "Embed XPCServices";
\t\t\trunOnlyForDeploymentPostprocessing = 0;
\t\t}};"""
    content = insert_into_section(content, "PBXCopyFilesBuildPhase", copy_phase)
    
    # Precise injection into MeetingAssistant build phases (at the end)
    if app_target_pos != -1:
        phases_pos = content.find("buildPhases = (", app_target_pos)
        if phases_pos != -1:
            closing_paren = content.find(");", phases_pos)
            if closing_paren != -1:
                content = content[:closing_paren] + f"\t\t\t\t{REFS['phase_copy_xpc_app']} /* Embed XPCServices */,\n" + content[closing_paren:]

    with open(PROJECT_PATH, 'w') as f:
        f.write(content)
    print("Successfully patched project.pbxproj")

if __name__ == "__main__":
    patch_pbxproj()
