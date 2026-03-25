#!/usr/bin/env ruby

require 'rubygems'
require 'xcodeproj'

ROOT = File.expand_path('..', __dir__)
PROJECT_PATH = File.join(ROOT, 'PiDay.xcodeproj')

APP_TARGET_NAME = 'PiDay'
WATCH_APP_TARGET_NAME = 'PiDayWatchApp'
WATCH_EXTENSION_TARGET_NAME = 'PiDayWatchExtension'

WATCH_APP_BUNDLE_ID = 'academy.glasscode.piday.watchkitapp'
WATCH_EXTENSION_BUNDLE_ID = 'academy.glasscode.piday.watchkitapp.watchkitextension'
IOS_APP_BUNDLE_ID = 'academy.glasscode.piday'

WATCH_APP_PRODUCT_NAME = 'PiDay Watch App'
WATCH_EXTENSION_PRODUCT_NAME = 'PiDay Watch Extension'

WATCH_APP_ICON_RESOURCES = [
  'PiDayWatchAppIcon/icon.json',
  'PiDayWatchAppIcon/Assets/π.png'
].freeze

WATCH_EXTENSION_SOURCES = [
  'PiDayWatchExtension/PiDayWatchApp.swift',
  'PiDayWatchExtension/WatchAppModel.swift',
  'PiDayWatchExtension/WatchRootView.swift',
  'PiDay/Core/Domain/DateFormatOption.swift',
  'PiDay/Core/Domain/PiMatch.swift',
  'PiDay/Core/Domain/SearchFormatPreference.swift',
  'PiDay/Core/Data/DateStringGenerator.swift',
  'PiDay/Core/Data/PiIndexPayload.swift',
  'PiDay/Core/Repository/DefaultPiRepository.swift',
  'PiDay/Core/Repository/PiRepository.swift',
  'PiDay/Core/Repository/PiStore.swift',
  'PiDay/Core/Repository/PiLiveLookupService.swift',
  'PiDay/Design/PiPalette.swift'
].freeze

WATCH_EXTENSION_RESOURCES = [
  'PiDay/Resources/pi_2026_2035_index.json'
].freeze

def ensure_file_ref(project, relative_path)
  parent_path = File.dirname(relative_path)
  group = parent_path == '.' ? project.main_group : project.main_group.find_subpath(parent_path, true)
  basename = File.basename(relative_path)
  ref = group.children.find { |child| child.path == basename }
  return ref if ref

  group.new_reference(basename)
end

def ensure_root_relative_ref(project, relative_path)
  ref = project.main_group.children.find { |child| child.path == relative_path }
  return ref if ref

  project.main_group.new_reference(relative_path)
end

def remove_target_if_present(project, name)
  target = project.targets.find { |candidate| candidate.name == name }
  target&.remove_from_project
end

def configure_build_settings(target, overrides)
  target.build_configurations.each do |config|
    overrides.each do |key, value|
      config.build_settings[key] = value
    end
  end
end

def reset_phase_files(phase)
  phase.files_references.dup.each do |file_ref|
    phase.remove_file_reference(file_ref)
  end
end

def reset_copy_phase(target, name, destination)
  phase = target.copy_files_build_phases.find { |candidate| candidate.name == name } ||
    target.new_copy_files_build_phase(name)
  phase.symbol_dst_subfolder_spec = destination
  reset_phase_files(phase)
  phase
end

def remove_invalid_dependencies(target)
  target.dependencies.dup.each do |dependency|
    dependency.remove_from_project if dependency.target.nil?
  end
end

project = Xcodeproj::Project.open(PROJECT_PATH)

ios_app = project.targets.find { |target| target.name == APP_TARGET_NAME }
abort("Missing target #{APP_TARGET_NAME}") unless ios_app

remove_target_if_present(project, WATCH_EXTENSION_TARGET_NAME)

watch_app = project.targets.find { |target| target.name == WATCH_APP_TARGET_NAME }
abort("Missing target #{WATCH_APP_TARGET_NAME}") unless watch_app

watch_app.product_type = Xcodeproj::Constants::PRODUCT_TYPE_UTI[:watch2_app]
watch_app.product_reference.path = "#{WATCH_APP_PRODUCT_NAME}.app"
watch_app.product_reference.explicit_file_type = 'wrapper.application'

configure_build_settings(
  watch_app,
  'PRODUCT_BUNDLE_IDENTIFIER' => WATCH_APP_BUNDLE_ID,
  'PRODUCT_NAME' => WATCH_APP_PRODUCT_NAME,
  'ASSETCATALOG_COMPILER_APPICON_NAME' => 'AppIcon',
  'ASSETCATALOG_COMPILER_INCLUDE_ALL_APPICON_ASSETS' => 'YES',
  'CODE_SIGN_STYLE' => 'Automatic',
  'DEVELOPMENT_TEAM' => '54WU29TRTY',
  'GENERATE_INFOPLIST_FILE' => 'NO'
)

watch_app.build_configurations.each do |config|
  config.build_settings.delete('INFOPLIST_KEY_WKApplication')
  config.build_settings.delete('INFOPLIST_KEY_WKCompanionAppBundleIdentifier')
  config.build_settings['INFOPLIST_FILE'] = 'PiDayWatchApp/Info.plist'
end

reset_phase_files(watch_app.source_build_phase)
reset_phase_files(watch_app.resources_build_phase)
watch_app.add_resources(WATCH_APP_ICON_RESOURCES.map { |path| ensure_file_ref(project, path) })

watch_extension = project.new_target(
  :watch2_extension,
  WATCH_EXTENSION_TARGET_NAME,
  :watchos,
  '10.0',
  project.products_group,
  :swift,
  WATCH_EXTENSION_PRODUCT_NAME
)

watch_extension.product_reference.path = "#{WATCH_EXTENSION_PRODUCT_NAME}.appex"

configure_build_settings(
  watch_extension,
  'PRODUCT_BUNDLE_IDENTIFIER' => WATCH_EXTENSION_BUNDLE_ID,
  'PRODUCT_NAME' => WATCH_EXTENSION_PRODUCT_NAME,
  'CODE_SIGN_STYLE' => 'Automatic',
  'DEVELOPMENT_TEAM' => '54WU29TRTY',
  'GENERATE_INFOPLIST_FILE' => 'NO'
)

# Xcode 26's watch simulator installer rejects the extension when the build
# uses a generated plist, so force the hand-written WatchKit extension plist.
watch_extension.build_configurations.each do |config|
  config.build_settings['INFOPLIST_FILE'] = 'PiDayWatchExtension/Info.plist'
end

reset_phase_files(watch_extension.source_build_phase)
reset_phase_files(watch_extension.resources_build_phase)
watch_extension.add_file_references(WATCH_EXTENSION_SOURCES.map { |path| ensure_file_ref(project, path) })
watch_extension.add_resources(WATCH_EXTENSION_RESOURCES.map { |path| ensure_root_relative_ref(project, path) })

remove_invalid_dependencies(watch_app)
watch_app.dependencies.dup.each do |dependency|
  dependency.remove_from_project if dependency.target&.name == WATCH_EXTENSION_TARGET_NAME
end
watch_app.add_dependency(watch_extension)

watch_embed_phase = reset_copy_phase(
  watch_app,
  'Embed Foundation Extensions',
  :plug_ins
)
build_file = watch_embed_phase.add_file_reference(watch_extension.product_reference, true)
build_file.settings = { 'ATTRIBUTES' => ['RemoveHeadersOnCopy'] }

remove_invalid_dependencies(ios_app)
ios_app.dependencies.dup.each do |dependency|
  dependency.remove_from_project if dependency.target&.name == WATCH_APP_TARGET_NAME
end
ios_app.add_dependency(watch_app)

ios_embed_phase = reset_copy_phase(
  ios_app,
  'Embed Watch Content',
  :wrapper
)
build_file = ios_embed_phase.add_file_reference(watch_app.product_reference, true)
build_file.settings = { 'ATTRIBUTES' => ['RemoveHeadersOnCopy'] }

project.save
