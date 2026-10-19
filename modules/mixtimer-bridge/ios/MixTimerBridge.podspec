Pod::Spec.new do |s|
  s.name           = 'MixTimerBridge'
  s.version        = '1.0.0'
  s.summary        = 'Start/stop the MixTimer engine from the app screen'
  s.description    = 'Calls the engine that lives in the app target (targets/widget/_shared) by its Objective-C name.'
  s.author         = 'resttimer-app'
  s.homepage       = 'https://github.com/resttimer-app/rest-timer'
  s.license        = 'MIT'
  s.platforms      = { :ios => '16.4' }
  s.source         = { git: '' }
  s.static_framework = true

  s.dependency 'ExpoModulesCore'

  s.source_files = '**/*.{h,m,swift}'
end
