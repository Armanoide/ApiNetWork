Pod::Spec.new do |s|
  s.name		= 'ApiNetWork'
  s.version          	= '2.0.1'
  s.license 		= { :type => "MIT", :file => "LICENSE" }
  s.platform      	= :ios, "7.0"
  s.summary 		= 'Swift IOS vendor to manage network'

  s.homepage 		= 'https://github.com/Armanoide/ApiNetWork'
  s.author 		= { 'Billa Norbert' => 'norbert.billa@gmail.com' }
  s.source 		= { :git => 'https://github.com/Armanoide/ApiNetWork.git', :tag => 'V2.0.1' }
  s.source_files 	= 'SRC/*.{swift}'
  s.requires_arc 	= true
  s.frameworks 		= 'Foundation'
end
