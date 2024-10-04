# Metal to Python API
A quick and simple approach to build a Python wrapper to utilize a Metal computation

(!) IMPORTANT: This solution mimics a SECP256k1 algorithm that does not return valid public keys, it's goal is to demonstrate how a bridge between Python and Metal works


# Installation

First compile the metal source to get a metallib:


  xcrun -sdk macosx metal -fcikernel -c computation.metal -o computation.air;xcrun -sdk macosx metallib computation.air -o computation.metallib


Now build the Swift wrapper

  swift build

You can run several operations on you GPU like that:


Now you need to sign your library to use it in python: 

  openssl genrsa -out developer.key 2048
  openssl req -new -x509 -key developer.key -out developer.crt -days 365 -subj "/CN=developer/O=NickyReinert/C=DE"

Manually import your own code signing certificate to your Access keychain, change it's properties to "Trust always".

List all available certificates

  security find-identity -p codesigning

And sign our library like this:

  codesign -s "1FDBA4034D6CB4AC46F65ED2EB6AC30C7344FF84" --deep --force .build/debug/libWrapper.dylib
