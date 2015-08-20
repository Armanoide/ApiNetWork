Pod::Spec.new do |s|
  s.name = 'ApiNetwork'
  s.version = '0.0.1'
  s.license = 'MIT'
  s.summary = 'Swift IOS vendor to manage network'
  s.description = <<-DESC
                   Swift IOS vendor to manage network
                  DESC
  s.homepage = 'https://github.com/Armanoide/ApiNetWork'
    s.author = { 'Billa Norbert' => 'norbert.billa@gmail.com' }
  s.source = { :git => 'https://github.com/Armanoide/ApiNetWork.git', :tag => '0.0.1' }
  s.source_files = 'ApiNetwork/src/*.{swift}'
  s.resources = 'ApiNetwork/{en,de,ja,tr,zh-Hans}.lproj'

  s.frameworks = 'Foundation'
end
