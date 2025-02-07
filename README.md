# Fuselibs

[![AppVeyor build status](https://img.shields.io/appveyor/ci/fusetools/fuselibs-public/master.svg?logo=appveyor&logoColor=silver&style=flat-square)](https://ci.appveyor.com/project/fusetools/fuselibs-public/branch/master)
[![Travis CI build status](https://img.shields.io/travis/fuse-open/fuselibs/master.svg?style=flat-square)](https://travis-ci.org/fuse-open/fuselibs)
[![NPM package](https://img.shields.io/npm/v/@fuse-open/fuselibs.svg?style=flat-square)](https://www.npmjs.com/package/@fuse-open/fuselibs)
[![License: MIT](https://img.shields.io/github/license/fuse-open/fuselibs.svg?style=flat-square)](LICENSE.txt)
[![Slack](https://img.shields.io/badge/chat-on%20slack-blue.svg?style=flat-square)](https://slackcommunity.fusetools.com/)

Fuselibs is a collection of [Uno](https://fuseopen.com/docs/uno/uno-lang) libraries that provide
the UI framework used to build [Fuse](https://fuseopen.com/) apps.

## Install

```
npm install @fuse-open/fuselibs
```

## Requirements

In order to use Uno and Fuselibs, the following software must be installed:

### Windows

* VCRedist 2010: [x86](https://www.microsoft.com/en-us/download/details.aspx?id=5555), [x64](https://www.microsoft.com/en-US/Download/confirmation.aspx?id=14632)
* [VCRedist 2013](https://www.microsoft.com/en-gb/download/details.aspx?id=40784)

### macOS

* [Mono](https://www.mono-project.com/download/)
* [Xcode](https://developer.apple.com/xcode/)
* [CMake](https://cmake.org/)

### Android

* Android SDK and NDK

These dependencies can be acquired by installing [android-build-tools](https://www.npmjs.com/package/android-build-tools).

## How do I build and test?

```
npm install
npm run build
npm run test
```

You can run the local `uno` directly using `node_modules/.bin/uno`. This
is useful when you want to test apps using your local fuselibs build
environment.

You can run the manual testing app using one of the following commands:

```
npm run android
npm run dotnet
npm run ios
npm run native
```

## Contributing

Please read [CONTRIBUTING.md](CONTRIBUTING.md) for details on our code of
conduct, and the process for submitting pull requests to us.

### Reporting issues

Please report issues [here](https://github.com/fuse-open/fuselibs/issues).
