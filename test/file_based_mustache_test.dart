// Copyright (c) 2016, <your name>. All rights reserved. Use of this source code
// is governed by a BSD-style license that can be found in the LICENSE file.

library file_based_mustache.test;

import 'dart:io';

import 'package:file_based_mustache/file_based_mustache.dart';
import 'package:test/test.dart';

void main() {
  group('A group of tests', () {
    TemplateDirectory skeleton;
    Map data = {
      'foo': 'bar',
      'bar': 'foo',
      'world': 'world',
      //'this_file_will_not_be_created': 'this file will now be created',
      'paths': [
        {'name': 'foo'},
        {'name': 'bar'},
        {'name': 'baz'}
      ]
    };

    setUp(() {
      skeleton = new TemplateDirectory(new Directory('test' +
          Platform.pathSeparator +
          'data' +
          Platform.pathSeparator +
          'skel'));
    });

    test('First Test', () async {
      await skeleton.renderDirectory(
          new Directory('test' +
              Platform.pathSeparator +
              'data' +
              Platform.pathSeparator +
              'out'),
          data);
      expect(true, isTrue);
    });
  });
}
