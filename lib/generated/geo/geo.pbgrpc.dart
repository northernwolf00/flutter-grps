// This is a generated file - do not edit.
//
// Generated from geo.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names

import 'dart:async' as $async;
import 'dart:core' as $core;

import 'package:grpc/service_api.dart' as $grpc;
import 'package:protobuf/protobuf.dart' as $pb;

import 'geo.pb.dart' as $0;

export 'geo.pb.dart';

@$pb.GrpcServiceName('geo.GeoService')
class GeoServiceClient extends $grpc.Client {
  /// The hostname for this service.
  static const $core.String defaultHost = '';

  /// OAuth scopes needed for the client.
  static const $core.List<$core.String> oauthScopes = [
    '',
  ];

  GeoServiceClient(super.channel, {super.options, super.interceptors});

  $grpc.ResponseFuture<$0.UploadSummary> uploadLocations($async.Stream<$0.Location> request, {$grpc.CallOptions? options,}) {
    return $createStreamingCall(_$uploadLocations, request, options: options).single;
  }

    // method descriptors

  static final _$uploadLocations = $grpc.ClientMethod<$0.Location, $0.UploadSummary>(
      '/geo.GeoService/UploadLocations',
      ($0.Location value) => value.writeToBuffer(),
      $0.UploadSummary.fromBuffer);
}

@$pb.GrpcServiceName('geo.GeoService')
abstract class GeoServiceBase extends $grpc.Service {
  $core.String get $name => 'geo.GeoService';

  GeoServiceBase() {
    $addMethod($grpc.ServiceMethod<$0.Location, $0.UploadSummary>(
        'UploadLocations',
        uploadLocations,
        true,
        false,
        ($core.List<$core.int> value) => $0.Location.fromBuffer(value),
        ($0.UploadSummary value) => value.writeToBuffer()));
  }

  $async.Future<$0.UploadSummary> uploadLocations($grpc.ServiceCall call, $async.Stream<$0.Location> request);

}
