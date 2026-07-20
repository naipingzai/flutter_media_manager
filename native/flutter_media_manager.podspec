Pod::Spec.new do |s|
  s.name             = 'flutter_media_manager'
  s.version          = '1.0.0'
  s.summary          = 'Native C++ library for Flutter Media Manager'
  s.description      = 'SQLite-based media database with FFI bridge for Flutter'
  s.homepage         = 'https://github.com/naipingzai/flutter_media_manager'
  s.license          = { :type => 'MIT', :file => '../LICENSE' }
  s.author           = { 'author' => 'author@example.com' }
  s.source           = { :path => '.' }
  s.platform         = :ios, '13.0'
  s.swift_version    = '5.0'

  s.source_files     = 'src/**/*.{cpp,h}', 'third_party/**/*.{c,h}'
  s.public_header_files = 'src/**/*.h', 'third_party/**/*.h'

  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
    'OTHER_CPLUSPLUSFLAGS' => '-std=c++17 -DSQLITE_THREADSAFE=1 -fvisibility=default',
    'OTHER_LDFLAGS' => '-ObjC',
  }

  s.xcconfig = {
    'HEADER_SEARCH_PATHS' => '"${PODS_TARGET_SRCROOT}/src" "${PODS_TARGET_SRCROOT}/third_party"',
  }
end
