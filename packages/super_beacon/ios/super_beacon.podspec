Pod::Spec.new do |s|
  s.name             = 'super_beacon'
  s.version          = '0.0.1'
  s.summary          = 'Configurable iBeacon monitoring for Flutter hosts.'
  s.description      = <<-DESC
Configurable iBeacon region monitoring and event delivery for Flutter hosts.
                       DESC
  s.homepage         = 'https://github.com/LinXunFeng/flutter_super_beacon'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Contributors' => 'opensource@example.invalid' }
  s.source           = { :path => '.' }
  s.source_files     = 'Classes/**/*'
  s.dependency 'Flutter'
  s.platform         = :ios, '13.0'
  s.frameworks       = 'CoreBluetooth', 'CoreLocation', 'UserNotifications'
  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
    'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386'
  }
  s.swift_version = '5.0'
end
