require 'xcodeproj'

flavor = ENV.fetch('APP_FLAVOR')
abort 'Unknown flavor' unless %w[popi popistudio].include?(flavor)
project = Xcodeproj::Project.open('ios/Runner.xcodeproj')
runner = project.targets.find { |target| target.name == 'Runner' }
config = runner.build_configurations.find { |item| item.name == "Release-#{flavor}" }
abort 'Bundle ID mismatch' unless config.build_settings['PRODUCT_BUNDLE_IDENTIFIER'] == ENV.fetch('IOS_BUNDLE_ID')
config.build_settings.merge!(
  'CODE_SIGN_STYLE' => 'Manual',
  'CODE_SIGN_IDENTITY' => 'Apple Distribution',
  'DEVELOPMENT_TEAM' => ENV.fetch('IOS_TEAM_ID'),
  'PROVISIONING_PROFILE_SPECIFIER' => ENV.fetch('IOS_RESOLVED_PROFILE_NAME')
)
project.save
