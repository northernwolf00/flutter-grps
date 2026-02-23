// This is a generated file - do not edit.
//
// Generated from geo.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, unused_import

import 'dart:convert' as $convert;
import 'dart:core' as $core;
import 'dart:typed_data' as $typed_data;

@$core.Deprecated('Use locationDescriptor instead')
const Location$json = {
  '1': 'Location',
  '2': [
    {'1': 'user_id', '3': 1, '4': 1, '5': 9, '10': 'userId'},
    {'1': 'lat', '3': 2, '4': 1, '5': 1, '10': 'lat'},
    {'1': 'lng', '3': 3, '4': 1, '5': 1, '10': 'lng'},
    {'1': 'timestamp', '3': 4, '4': 1, '5': 3, '10': 'timestamp'},
  ],
};

/// Descriptor for `Location`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List locationDescriptor = $convert.base64Decode(
    'CghMb2NhdGlvbhIXCgd1c2VyX2lkGAEgASgJUgZ1c2VySWQSEAoDbGF0GAIgASgBUgNsYXQSEA'
    'oDbG5nGAMgASgBUgNsbmcSHAoJdGltZXN0YW1wGAQgASgDUgl0aW1lc3RhbXA=');

@$core.Deprecated('Use uploadSummaryDescriptor instead')
const UploadSummary$json = {
  '1': 'UploadSummary',
  '2': [
    {'1': 'received', '3': 1, '4': 1, '5': 5, '10': 'received'},
  ],
};

/// Descriptor for `UploadSummary`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List uploadSummaryDescriptor = $convert.base64Decode(
    'Cg1VcGxvYWRTdW1tYXJ5EhoKCHJlY2VpdmVkGAEgASgFUghyZWNlaXZlZA==');

