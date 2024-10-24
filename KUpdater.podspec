#
# Be sure to run `pod lib lint KUpdater.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see https://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = 'KUpdater'
  s.version          = '0.1.0'
  s.summary          = 'This package is used in KMM to check for updates.'

# This description is used to generate tags and improve search results.
#   * Think: What does it do? Why did you write it? What is the focus?
#   * Try to keep it short, snappy and to the point.
#   * Write the description between the DESC delimiters below.
#   * Finally, don't worry about the indent, CocoaPods strips it!

  s.description      = 'This package is used in Kotlin multi-platform to check for updates'

  s.homepage         = 'https://github.com/the-best-is-best/KUpdater'
  # s.screenshots     = 'www.example.com/screenshots_1', 'www.example.com/screenshots_2'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'Michelle Raouf' => 'michelle.raouf@outlook.com' }
  s.source           = { :git => 'https://github.com/the-best-is-best/KUpdater.git', :tag => s.version.to_s }
  # s.social_media_url = 'https://twitter.com/<TWITTER_USERNAME>'

  s.ios.deployment_target = '12.0'
  s.swift_version    = '5.5'

  s.source_files = 'KUpdater/Classes/**/*'
  
  # s.resource_bundles = {
  #   'KUpdater' => ['KUpdater/Assets/*.png']
  # }

  # s.public_header_files = 'Pod/Classes/**/*.h'
  # s.frameworks = 'UIKit', 'MapKit'
  # s.dependency 'AFNetworking', '~> 2.3'
end
