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
projectName = (libraryName+libraryVersion).tr('.','_').tr(' ','').tr('-','_').gsub(/[^0-9a-z_]/i, '')
frameworkName = libraryName+"Dynamic"
workspace_name = projectName+".xcworkspace"
workspace_path = libraryPath+"/"+workspace_name

puts "Building simulator library"
simulator_build_command = 'xcrun \
xcodebuild \
-workspace '+workspace_path+' \
-scheme '+frameworkName+' \
-quiet \
-configuration Release \
-arch x86_64 -arch i386 \
-derivedDataPath '+libraryPath+'/derived_data \
ONLY_ACTIVE_ARCH=NO \
VALID_ARCHS="i386 x86_64" \
-sdk iphonesimulator10.3 \
&> '+libraryPath+'/buildlog_simulator.txt'
build_result = `#{simulator_build_command}`

puts "Building device library"
simulator_build_command = 'xcrun \
xcodebuild \
-workspace '+workspace_path+' \
-scheme '+frameworkName+' \
-quiet \
-configuration Release \
-arch armv7 -arch arm64 \
-derivedDataPath '+libraryPath+'/derived_data \
ONLY_ACTIVE_ARCH=NO \
VALID_ARCHS="armv7 arm64" \
-sdk iphoneos10.3 \
&> '+libraryPath+'/buildlog_device.txt'
build_result = `#{simulator_build_command}`

puts "Creating universal library folder"
FileUtils.copy_entry './'+libraryPath+'/derived_data/Build/Products/Release-iphoneos/'+frameworkName+'.framework', './'+libraryPath+'/'+frameworkName+'.framework'

puts "Creating universal libarary"
lipo_command = 'lipo \
-create \
-output "./'+libraryPath+'/'+frameworkName+'.framework/'+frameworkName+'" \
"./'+libraryPath+'/derived_data/Build/Products/Release-iphoneos/'+frameworkName+'.framework/'+frameworkName+'" \
"./'+libraryPath+'/derived_data/Build/Products/Release-iphonesimulator/'+frameworkName+'.framework/'+frameworkName+'"'
lipo_result = `#{lipo_command}`
puts "--Done--"
