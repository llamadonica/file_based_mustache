// Copyright (c) 2016, Adam Stark. All rights reserved. Use of this source code
// is governed by a BSD-style license that can be found in the LICENSE file.

// TODO: Put public facing types in this file.

library file_based_mustache.base;

import 'dart:async';
import 'dart:io';

import 'package:mustache/mustache.dart' as mustache;

/// Checks if you are awesome. Spoiler: you are.
class TemplateDirectory {
  final Directory directory;

  TemplateDirectory(this.directory);

  static final _iteratorSubdirectory = new RegExp(r'^\{\{#\s*([^\s}]*?)\s*\}\}$');
  static final _iteratorSomeReplacementValue = new RegExp(r'\{\{\s*([^\s}]*?)\s*\}\}');

  Future renderDirectory(Directory output, args) =>_renderDirectory(directory, output, args);

  static Future _renderDirectory(Directory directory, Directory output, args, [List<String> writtenFiles, List<String> writtenDirectories, Map rootMap]) async {
    if (writtenFiles == null) writtenFiles = new List();
    if (rootMap == null) rootMap = args;
    if (writtenDirectories == null) writtenDirectories = new List();

    await for (var item in directory.list()) {
      int pathOffset;
      if (directory.path.endsWith(Platform.pathSeparator)) {
        pathOffset = 0;
      } else {
        pathOffset = 1;
      }
      var relativePath = item.path.substring(directory.path.length + pathOffset);
      final relativePathMatch = _iteratorSubdirectory.firstMatch(relativePath);

      if (relativePathMatch != null) {
        if (item is! Directory) {
          throw new StateError('An optional parameter starting with # must be a directory.');
        }

        var localPath = _getElementFromPath(relativePathMatch.group(1), args);

        if (localPath == null) continue;
        if (localPath is bool && localPath) {
          await _renderDirectory(item, output, args, writtenFiles, writtenDirectories, rootMap);
        } else if (localPath is List) {
          await Future.wait(
              localPath.map((arg) {
                var localMap = new Map.from(arg);
                localMap['_root'] = rootMap;
                return _renderDirectory(item, output, localMap, writtenFiles, writtenDirectories, rootMap);
              }));
        } else {
          throw new ArgumentError();
        }
      } else {
        int firstIndex = 0;
        StringBuffer nameBuffer = new StringBuffer();
        for (var match in _iteratorSomeReplacementValue.allMatches(relativePath)) {
          nameBuffer.write(relativePath.substring(firstIndex, match.start));
          var elementToReplace = _getElementFromPath(match.group(1), args);
          if (elementToReplace == null || elementToReplace == false
              || elementToReplace == ""
              || (elementToReplace is List && elementToReplace.length == 0)
              || (elementToReplace is Map && elementToReplace.length == 0)) {
            print("! Skipping template: ${item.path} because ${match.group(1)} was false-y");
            return;
          }
          nameBuffer.write(elementToReplace);
          firstIndex = match.end;
        }
        nameBuffer.write(relativePath.substring(firstIndex));

        var outputLocation = output.path + Platform.pathSeparator + nameBuffer.toString();

        if (item is Directory) {
          Directory newOutputDirectory = new Directory(outputLocation);
          if (writtenDirectories.contains(outputLocation)) {
            print("! Skipping creation of ($outputLocation)");
          } else {
            writtenDirectories.add(outputLocation);
            print ("${item.path} => ${newOutputDirectory.path}");
            await newOutputDirectory.create();
            await _renderDirectory(item, newOutputDirectory, args, writtenFiles, writtenDirectories, rootMap);
          }
        } else if (item is Link) {
          Link newOutputDirectory = new Link(outputLocation);
          if (writtenFiles.contains(outputLocation)) {
            print("! Skipping creation of ($outputLocation)");
            throw new StateError("Can't create file ($outputLocation} because it already exists");
          } else {
            writtenFiles.add(outputLocation);
            print ("${item.path} => ${newOutputDirectory.path}");
            await newOutputDirectory.create(await item.target());
          }
        } else if (item is File) {
          File newOutputDirectory = new File(outputLocation);
          if (writtenFiles.contains(outputLocation)) {
            print("! Skipping creation of ($outputLocation)");
            throw new StateError("Can't create file ($outputLocation} because it already exists");
          } else {
            writtenFiles.add(outputLocation);
            print ("${item.path} => ${newOutputDirectory.path}");

            var templateString = await item.readAsString();
            var fileTemplate = new mustache.Template(templateString, name: item.path);
            var outputString = fileTemplate.renderString(args);

            await newOutputDirectory.writeAsString(outputString);
          }
        }
      }


    }
  }

  static _getElementFromPath(String path, args) {
    var pathlike = path.split('.');
    var localPath = args;
    {
      bool skipThisPath = false;

      for (var localPathElement in pathlike) {
        if (localPath is! Map || localPath[localPathElement] == null) {
          skipThisPath = true;
          break;
        }
        localPath = localPath[localPathElement];
      }
      if (skipThisPath) localPath = null;
    }
    return localPath;
  }
}
