// Copyright (c) 2022, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert';
import 'dart:io';

Future<Object?> downloadJson(String uri) async {
  final client = HttpClient();
  try {
    final request = await client.getUrl(Uri.parse(uri));
    final response = await request.close();

    return response
        .transform(utf8.decoder)
        .transform(const JsonDecoder())
        .single;
  } finally {
    client.close();
  }
}
