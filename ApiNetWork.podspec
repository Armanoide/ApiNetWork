Pod::Spec.new do |s|
  s.name		= 'ApiNetWork'
  s.version          	= '3.0.0'
  s.license 		= { :type => "MIT", :file => "LICENSE" }
  s.platform      	= :ios, '8.0'
  s.summary 		= 'Swift IOS easy vendor to manage network'

  s.homepage 		= 'https://github.com/Armanoide/ApiNetWork'
  s.author 		= { 'Billa Norbert' => 'norbert.billa@gmail.com' }
  s.source 		= { :git => 'https://github.com/Armanoide/ApiNetWork.git', :tag => '3.0.0' }
  s.source_files 	= 'SRC/*.{swift}'
  s.requires_arc 	= true
  s.frameworks 		= 'Foundation'
end
