require 'securerandom'
require 'fileutils'
require 'open-uri'
require 'xcodeproj'
require 'json'

puts ""

libraryName = ARGV[0]
libraryVersion = ARGV[1]
git_url = ARGV[2]

if !libraryName || !libraryVersion
   puts "./makeDynamic.sh PodName PodVersion [git upload url]"
   exit(1)
end

puts "Making dynamic librarty for "+libraryName+" ["+libraryVersion+"]"

# Directory

libraryRootDir = URI::encode(libraryName)
libraryVersionDir = URI::encode(libraryVersion)
libraryPath = libraryRootDir+"/"+libraryVersionDir

if File.exists?(libraryPath)
  puts "Recreating folder "+libraryPath+" for library"
  FileUtils.rm_r libraryPath
  FileUtils.mkdir_p libraryPath
else
  puts "Creating folder "+libraryPath+" for library"
  FileUtils.mkdir_p libraryPath unless File.exists?(libraryPath)
end

# Xcode project

projectName = (libraryName+libraryVersion).tr('.','_').tr(' ','').tr('-','_').gsub(/[^0-9a-z_]/i, '')
project_path = libraryPath+"/"+projectName+".xcodeproj"

# Creating project

puts "Creating xcode project "+projectName+" for library"
project = Xcodeproj::Project.new(project_path)
project.save

# Creating target

puts "Creating framework target in project"
frameworkName = libraryName+"Dynamic"
framework_target = project.new_target(:framework, frameworkName, :ios, '8.0')
framework_target.add_system_framework("UIKit")
project.save

# Creating Info.plist

puts "Creating Info.plist"

info_plist_path = libraryPath+"/Info.plist"
File.write(info_plist_path, '''
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  	<key>CFBundleDevelopmentRegion</key>
  	<string>en</string>
  	<key>CFBundleExecutable</key>
  	<string>$(EXECUTABLE_NAME)</string>
  	<key>CFBundleIdentifier</key>
  	<string>com.dynamic.'+frameworkName+'</string>
  	<key>CFBundleInfoDictionaryVersion</key>
  	<string>6.0</string>
  	<key>CFBundleName</key>
  	<string>$(PRODUCT_NAME)</string>
  	<key>CFBundlePackageType</key>
  	<string>FMWK</string>
  	<key>CFBundleShortVersionString</key>
  	<string>1.0</string>
  	<key>CFBundleVersion</key>
  	<string>$(CURRENT_PROJECT_VERSION)</string>
  	<key>NSPrincipalClass</key>
  	<string></string>
</dict>
</plist>
''')

info_plist = project.new_file("./Info.plist")
framework_target.add_file_references([info_plist])
for build_configuration in framework_target.build_configurations
  build_configuration.build_settings['INFOPLIST_FILE']='Info.plist'
  build_configuration.build_settings['SWIFT_VERSION']='3.0'
end
project.save


# Creating Framework header

puts "Creating framework header"
header_file_name = frameworkName+".h"
header_file_path = libraryPath+"/"+header_file_name
File.write(header_file_path, '
#import <UIKit/UIKit.h>

FOUNDATION_EXPORT double '+frameworkName+'VersionNumber;
FOUNDATION_EXPORT const unsigned char '+frameworkName+'VersionString[];
')

header_file = project.new_file(header_file_name)
framework_target.add_file_references([header_file])
framework_target.headers_build_phase.files[-1].settings = { "ATTRIBUTES" => ["Public"] }
project.save

# Creating podfile

puts "Creating Podfile"
podfile_name = "Podfile"
podfile_path = libraryPath+"/"+podfile_name
File.write(podfile_path, '''
platform :ios, \'8.0\'
inhibit_all_warnings!

use_frameworks!

target \''+frameworkName+'\' do
  pod \''+libraryName+'\', \''+libraryVersion+'\'
end
''')

# Running pod install
puts "Running 'pod install'"
command = 'pod install '+'--project-directory="'+'./'+libraryPath+'"'
result = `#{command}`
puts "--Done--"

puts "Reading headers"
# Add library headers to current project
workspace_name = projectName+".xcworkspace"
workspace_path = libraryPath+"/"+workspace_name
workspace =  Xcodeproj::Workspace.new_from_xcworkspace(workspace_path)

for project_file in workspace.file_references
  if File.basename(project_file.path,".xcodeproj") == "Pods"
    puts "Found Pods project: "+libraryPath+"/"+project_file.path
    pods_project = Xcodeproj::Project.open(libraryPath+"/"+project_file.path)
  end
end

puts "Looking for framework files"
library_group = pods_project['Pods'][libraryName]
frameworks_group = library_group['Frameworks']
framework_group = frameworks_group.children[0]
framework_header_folder = framework_group.real_path+"Headers"

puts "Adding headers to library project"
for library_header_file in framework_header_folder.children
  header_file = project.new_file(library_header_file)
  framework_target.add_file_references([header_file])
  framework_target.headers_build_phase.files[-1].settings = { "ATTRIBUTES" => ["Public"] }
  project.save
end

puts "Updating library header file"
header_file_string = "#import <UIKit/UIKit.h>\n"

for library_header_file in framework_header_folder.children
  header_file_string += "#import \""+library_header_file.basename.to_s+"\"\n"
end

header_file_string += "FOUNDATION_EXPORT double "+frameworkName+"VersionNumber;\n"
header_file_string += "FOUNDATION_EXPORT const unsigned char "+frameworkName+"VersionString[];\n"

File.write(header_file_path, header_file_string)

# Running pod install
puts "Running 'pod install' second time"
command = 'pod install '+'--project-directory="'+'./'+libraryPath+'"'
result = `#{command}`
puts "--Done--"

# Update pods path

project = Xcodeproj::Project.open(project_path)
frameworkName = libraryName+"Dynamic"

# Make scheme shared
puts "Making scheme shared"
project.recreate_user_schemes(true)
Xcodeproj::XCScheme.share_scheme(project_path, frameworkName)

# Build libraryPath
libary_build_command = 'ruby buildLib.rb '+libraryName+' '+libraryVersion
library_build_result = `#{libary_build_command}`
puts library_build_result

puts "Cleanup"
FileUtils.rm_r './'+libraryPath+'/buildlog_device.txt'
FileUtils.rm_r './'+libraryPath+'/buildlog_simulator.txt'
FileUtils.rm_r './'+libraryPath+'/derived_data'
FileUtils.rm_r './'+libraryPath+'/Podfile'
FileUtils.rm_r './'+libraryPath+'/Pods'
FileUtils.rm_r './'+libraryPath+'/Podfile.lock'
FileUtils.rm_r './'+libraryPath+'/'+projectName+".xcodeproj"
FileUtils.rm_r './'+libraryPath+'/'+projectName+".xcworkspace"
FileUtils.rm_r './'+libraryPath+'/Info.plist'
FileUtils.rm_r './'+libraryPath+'/'+header_file_name

puts "Loading podspec"
podspecs_command = 'pod spec which '+libraryName+' --show-all'
all_podspecs = `#{podspecs_command}`

for podspec_path in all_podspecs.split("\n")
  if podspec_path.include? libraryName+"/"+libraryVersion
    podspec_file = file = File.read(podspec_path)
  end
end

puts "Reading to JSON"
data_hash = JSON.parse(podspec_file)
if git_url
  data_hash["source"] = {"git": git_url,"tag": libraryVersion}
end
data_hash["vendored_frameworks"] = [frameworkName+'.framework']
data_hash["preserve_paths"] = [frameworkName+'.framework']
data_hash["source_files"] = nil
data_hash["name"] = frameworkName
data_hash["platforms"] = {'ios':'8.0'}

File.open("./"+libraryPath+"/"+frameworkName+".podspec.json","w") do |f|
  f.write(JSON.pretty_generate(data_hash))
end

puts "Running podspec lint quick"
puts
pod_lint_quick_command = 'pod spec lint --quick ./'+libraryPath+"/"+frameworkName+".podspec.json"
lint_result = `#{pod_lint_quick_command}`
puts lint_result

if git_url
  puts "Uploading to git"
  git_init_command = 'git init; \
  git remote add origin '+git_url+'; \
  git add -A; \
  git commit -m "Uploading library '+frameworkName+' with version '+libraryVersion+'"; \
  git tag -a '+libraryVersion+' -m ""; \
  git push -u origin master; \
  git push origin --tags'
  puts git_init_command
  Dir.chdir('./'+libraryPath){
    exec(git_init_command)
  }

end

puts
puts 'Done'
puts
