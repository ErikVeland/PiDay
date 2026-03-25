#!/usr/bin/env ruby

require 'rubygems'
require 'xcodeproj'

ROOT = File.expand_path('..', __dir__)
PROJECT_PATH = File.join(ROOT, 'PiDay.xcodeproj')

APP_TARGET_NAME = 'PiDay'
WATCH_APP_TARGET_NAME = 'PiDayWatchApp'
WATCH_EXTENSION_TARGET_NAME = 'PiDayWatchExtension'

WATCH_APP_BUNDLE_ID = 'academy.glasscode.piday.watchkitapp'
WATCH_APP_PRODUCT_NAME = 'PiDayWatchApp'

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

def reset_copy_phase(target, name, destination, path = nil)
  phase = target.copy_files_build_phases.find { |candidate| candidate.name == name } ||
    target.new_copy_files_build_phase(name)
  phase.symbol_dst_subfolder_spec = destination
  phase.dst_path = path if path
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

# Remove legacy extension target if it somehow still exists
legacy_ext = project.targets.find { |t| t.name == WATCH_EXTENSION_TARGET_NAME }
legacy_ext.remove_from_project if legacy_ext

watch_app = project.targets.find { |target| target.name == WATCH_APP_TARGET_NAME }
abort("Missing target #{WATCH_APP_TARGET_NAME}") unless watch_app

# Ensure correct product type for a modern single-target watchOS app
watch_app.product_type = 'com.apple.product-type.application'
watch_app.product_reference.path = "#{WATCH_APP_PRODUCT_NAME}.app"
watch_app.product_reference.explicit_file_type = 'wrapper.application'

configure_build_settings(
  watch_app,
  'PRODUCT_BUNDLE_IDENTIFIER' => WATCH_APP_BUNDLE_ID,
  'PRODUCT_NAME' => WATCH_APP_PRODUCT_NAME,
  'ASSETCATALOG_COMPILER_APPICON_NAME' => 'AppIcon',
  'ASSETCATALOG_COMPILER_INCLUDE_ALL_APPICON_ASSETS' => 'YES',
  'LSApplicationCategoryType' => 'public.app-category.education',
  'CODE_SIGN_STYLE' => 'Automatic',
  'DEVELOPMENT_TEAM' => '54WU29TRTY',
  'GENERATE_INFOPLIST_FILE' => 'YES'
)

watch_app.build_configurations.each do |config|
  config.build_settings['INFOPLIST_KEY_WKApplication'] = 'YES'
  config.build_settings['INFOPLIST_KEY_WKCompanionAppBundleIdentifier'] = 'academy.glasscode.piday'
end

# Clean up dependencies and phases
remove_invalid_dependencies(watch_app)

remove_invalid_dependencies(ios_app)
# Remove any existing watch-app dependency so we can re-add it cleanly.
ios_app.dependencies.dup.each do |dependency|
  dependency.remove_from_project if dependency.target&.name == WATCH_APP_TARGET_NAME
end

# WHY two-step approach: in xcodeproj 1.27 add_dependency returns nil (changed
# from earlier versions that returned the PBXTargetDependency). Calling
# platform_filters= on the return value of add_dependency would crash with
# "undefined method for NilClass". Instead we call add_dependency first and
# then find the newly added dependency inside ios_app.dependencies, which is
# always a live PBXTargetDependency that responds to platform_filters=.
ios_app.add_dependency(watch_app)
new_dependency = ios_app.dependencies.find { |d| d.target&.name == WATCH_APP_TARGET_NAME }
abort('Could not find watch dependency after add_dependency') unless new_dependency
new_dependency.platform_filters = ['ios']

ios_embed_phase = reset_copy_phase(
  ios_app,
  'Embed Watch Content',
  :wrapper,
  'Watch'
)
build_file = ios_embed_phase.add_file_reference(watch_app.product_reference, true)
build_file.settings = { 'ATTRIBUTES' => ['RemoveHeadersOnCopy'] }
# WHY: Mac Catalyst apps cannot include watchOS apps. Adding this filter ensures
# the Watch App is only embedded when building for iOS, preventing codesign
# failures on the Mac Catalyst path.
build_file.platform_filters = ['ios']

# Ensure target attributes are set so Xcode recognizes the signing style for all targets.
project.root_object.attributes['TargetAttributes'] ||= {}
project.targets.each do |target|
  project.root_object.attributes['TargetAttributes'][target.uuid] = {
    'DevelopmentTeam' => '54WU29TRTY',
    'ProvisioningStyle' => 'Automatic'
  }
end

project.save
