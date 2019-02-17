#!/bin/bash

# Download MaciASL/iasl62 and UEFIExtract NE
# Copy iasl and UEFIExtract to the App
# Copy UefiTableExtract.app to Applications folder

IASL_VERSION=iasl62
IASL_URL=https://github.com/acidanthera/MaciASL/raw/master/Dist/${IASL_VERSION}

UEFIEXTRACT_VERSION=UEFIExtract_NE_A55_mac
UEFIEXTRACT_URL=https://github.com/LongSoft/UEFITool/releases/download/A55/${UEFIEXTRACT_VERSION}.zip


directory=$(dirname  "$0")
cd "$directory"

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
      read -p "Download and install $IASL_VERSION now? (y/n): " choice
      case "$choice" in
 	     [yY]* ) { 
                 curl -L -O $IASL_URL
                 mv ./${IASL_VERSION} ./UefiTableExtract.app/Contents/MacOS/iasl
                 chmod +x ./UefiTableExtract.app/Contents/MacOS/iasl
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
      read -p "Download and install $UEFIEXTRACT_VERSION now? (y/n): " choice
      case "$choice" in
 	     [yY]* ) { 
                 curl -L -O $UEFIEXTRACT_URL
                 unzip ./${UEFIEXTRACT_VERSION}.zip -d ./${UEFIEXTRACT_VERSION}
                 cp ./${UEFIEXTRACT_VERSION}/UEFIExtract ./UefiTableExtract.app/Contents/MacOS/UEFIExtract
                 chmod +x ./UefiTableExtract.app/Contents/MacOS/UEFIExtract
                 rm ./${UEFIEXTRACT_VERSION}.zip
                 rm -R ./${UEFIEXTRACT_VERSION}
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
installed=FALSE
while true
do
   read -p "Copy UefiTableExtract to Applications? (y/n): " choice
   case "$choice" in
      [yY]* ) { 
         cp -rf ./UefiTableExtract.app /Applications
         installed=TRUE
      }
      break;;
      [nN]* ) break;;
      * ) echo "Try again...";;
   esac
done

if [ "$installed" == "TRUE" ]; then
   while true
   do
      echo ""
      read -p "Delete $directory ? (y/n): " choice
      case "$choice" in
         [yY]* ) { 
            cd ../
            rm -R "$directory"
         }
         break;;
         [nN]* ) break;;
         * ) echo "Try again...";;
      esac
    done
fi


echo ""
echo "All done..."

# Game Over
#tput clear
osascript -e 'quit app "Terminal"'

