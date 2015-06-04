#!/bin/bash

# Download MaciASL/iasl5 and UEFIExtract
# Copy iasl and UEFIExtract to the App
# Copy UefiTableExtract.app to Applications folder

cd "$(dirname  $0)"

echo "Searching tools..."
TOOL=$(which iasl)
if [ -x "$TOOL" ]; then
   echo "Using $TOOL."
else
   echo ""
   echo ""
   echo "iasl not found!"
   while true
   do
      read -p "Download and install iasl now? (y/n): " choice
      case "$choice" in
 	  [yY]* ) { 
 	             curl -L -O https://bitbucket.org/RehabMan/os-x-maciasl-patchmatic/downloads/RehabMan-MaciASL-2015-0107.zip
                 unzip RehabMan-MaciASL-2015-0107.zip -d RehabMan-MaciASL-2015-0107
                 cp ./RehabMan-MaciASL-2015-0107/MaciASL.app/Contents/MacOS/iasl5 ./UefiTableExtract.app/Contents/MacOS/iasl
              }
             break;;
 	  [nN]* ) break;;
 	   * ) echo "Try again...";;
      esac
   done
   
   TOOL=./UefiTableExtract.app/Contents/MacOS/iasl
   if [ -x "$TOOL" ]; then
       echo "Using $TOOL."
   else
       echo ""
       echo "ERROR: iasl not installed!"
       echo ""
   fi   
fi 

TOOL=$(which UEFIExtract)
if [ -x "$TOOL" ]; then
   echo "Using $TOOL."
else
   echo ""
   echo ""
   echo "UEFIExtract not found!"
   while true
   do
      read -p "Download and install UEFIExtract now? (y/n): " choice
      case "$choice" in
 	  [yY]* ) { 
 	             curl -L -O https://github.com/LongSoft/UEFITool/releases/download/0.20.5/UEFIExtract_0.10.1_osx.zip
                 unzip UEFIExtract_0.10.1_osx.zip -d UEFIExtract_0.10.1
                 cp ./UEFIExtract_0.10.1/UEFIExtract ./UefiTableExtract.app/Contents/MacOS/UEFIExtract
              }
             break;;
 	  [nN]* ) break;;
 	   * ) echo "Try again...";;
      esac
   done
   
   TOOL=./UefiTableExtract.app/Contents/MacOS/UEFIExtract
   if [ -x "$TOOL" ]; then
       echo "Using $TOOL."
   else
       echo ""
       echo "ERROR: UEFIExtract not installed!"
       echo ""
   fi   
fi 

echo ""
echo "Copy UefiTableExtract to Applications"
echo ""
cp -rf ./UefiTableExtract.app /Applications
echo "All done..."
