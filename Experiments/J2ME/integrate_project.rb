# Idempotent Xcode project wiring. Run from repository root with ruby.
require 'xcodeproj'
project = Xcodeproj::Project.open('Delta.xcodeproj')
delta = project.targets.find { |t| t.name == 'Delta' }
native = project.targets.find { |t| t.name == 'J2MENative' } || project.new_target(:static_library, 'J2MENative', :ios, '15.0')
base = 'Experiments/J2ME/JarBox/J2MEEmulator'
system('python3', 'Experiments/J2ME/prepare_native.py') || abort('Native overlays failed')
headers = ['', '/minijvm/jvm', '/minijvm/utils', '/minijvm/utils/sljit', '/minijvm/utils/https', '/minijvm/utils/https/mbedtls/include', '/NativeBridge/m3g/inc', '/NativeBridge/m3g', '/SupportingFiles'].map { |p| "$(SRCROOT)/#{base}#{p}" }
headers += ['$(SRCROOT)/Delta/J2ME/Native', "$(SRCROOT)/#{base}/NativeBridge"]
replaced = ["#{base}/minijvm/jvm/interpreter.c", "#{base}/minijvm/jvm/jvm_util.c", "#{base}/NativeBridge/jvm_bridge.c", "#{base}/NativeBridge/j2me_audio.m"]
native.source_build_phase.files.to_a.each { |f| f.remove_from_project if replaced.include?(f.file_ref.path) }
exceptions = File.read('Experiments/J2ME/JarBox/J2MEEmulator.xcodeproj/project.pbxproj').scan(/\s+(NativeBridge\/m3g\/src\/[^,]+),/).flatten
native_group = project.main_group.find_subpath('J2MENative Sources', true)
paths = Dir.glob("#{base}/**/*.{c,m,mm,cpp}") + Dir.glob("Delta/J2ME/Native/*.{c,m}") + Dir.glob("Experiments/J2ME/Generated/*.{c,m}")
paths.sort.each do |path|
 next if replaced.include?(path)
 next if exceptions.include?(path.delete_prefix(base + '/'))
 ref = project.files.find { |f| f.path == path } || native_group.new_file(path)
 native.source_build_phase.add_file_reference(ref, true)
end
phase = native.shell_script_build_phases.find { |p| p.name == 'Generate J2ME overlays' } || native.new_shell_script_build_phase('Generate J2ME overlays')
phase.shell_script = '/usr/bin/python3 "$SRCROOT/Experiments/J2ME/prepare_native.py"'
phase.input_paths = ['$(SRCROOT)/Experiments/J2ME/prepare_native.py'] + ['minijvm/jvm/interpreter.c', 'minijvm/jvm/jvm_util.c', 'NativeBridge/j2me_audio.m'].map { |p| "$(SRCROOT)/#{base}/#{p}" }
phase.output_paths = ['interpreter.c', 'jvm_util.c', 'j2me_audio.m'].map { |p| "$(SRCROOT)/Experiments/J2ME/Generated/#{p}" }
native.build_phases.delete(phase)
native.build_phases.insert(0, phase)
native.build_configurations.each do |config|
 config.build_settings.merge!({'HEADER_SEARCH_PATHS' => headers, 'GCC_C_LANGUAGE_STANDARD' => 'gnu11', 'OTHER_CFLAGS' => ['-Wno-implicit-function-declaration', '-DM3G_TARGET_GENERIC', '-DGLES_SILENCE_DEPRECATION', '-Wno-pointer-to-int-cast', '-Wno-int-to-void-pointer-cast', '-Wno-incompatible-pointer-types', '-Wno-int-conversion'], 'CLANG_ENABLE_OBJC_ARC' => 'YES', 'SKIP_INSTALL' => 'YES'})
end
delta.add_dependency(native) unless delta.dependencies.any? { |d| d.target == native }
delta.frameworks_build_phase.add_file_reference(native.product_reference, true)
delta.build_configurations.each do |config|
 old = config.build_settings['HEADER_SEARCH_PATHS'] || ['$(inherited)']
 config.build_settings['HEADER_SEARCH_PATHS'] = (Array(old) + headers).uniq
end
group = project.main_group.find_subpath('J2ME Integration', true)
Dir.glob('Delta/J2ME/*.swift').sort.each do |path|
 ref = project.files.find { |f| f.path == path } || group.new_file(path)
 delta.source_build_phase.add_file_reference(ref, true)
end
Dir.glob('Delta/J2ME/Resources/*').sort.each do |path|
 ref = project.files.find { |f| f.path == path } || group.new_file(path)
 delta.resources_build_phase.add_file_reference(ref, true)
end
%w[OpenGLES AudioToolbox AVFoundation UIKit QuartzCore].each do |name|
 ref = project.files.find { |f| f.path == "System/Library/Frameworks/#{name}.framework" } || project.frameworks_group.new_file("System/Library/Frameworks/#{name}.framework", :sdk_root)
 delta.frameworks_build_phase.add_file_reference(ref, true)
end
project.save
